import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/ui.dart';
import '../../shell/state/shell_controller.dart';
import '../data/creative_models.dart';
import '../data/market_repository.dart';
import '../state/market_controller.dart';
import 'creative_widgets.dart';
import 'marketplace_editor.dart';
import 'market_forms.dart';
import 'market_order_page.dart';
import 'market_management.dart';

final _listingProvider = FutureProvider.autoDispose
    .family<MarketListing, String>(
      (ref, id) => ref.watch(marketRepositoryProvider).listing(id),
    );

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});
  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  String _view = 'discover', _sellerTab = 'listings', _returnView = 'discover';
  String? _selected, _order;
  MarketListing? _editing;
  bool _initialized = false;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['listingId'] != null) {
        _selected = '${args['listingId']}';
        _view = 'detail';
      }
    }
  }

  void _back() => setState(() {
    _view = ['seller', 'orders', 'moderation'].contains(_view)
        ? 'discover'
        : _returnView;
    _returnView = 'discover';
    _selected = null;
    _order = null;
  });
  void _open(MarketListing w) => setState(() {
    _returnView = _view;
    _selected = w.id;
    _view = 'detail';
  });
  void _openOrder(String id) => setState(() {
    _returnView = _view == 'detail' ? 'orders' : _view;
    _order = id;
    _view = 'order';
  });
  void _edit([MarketListing? w]) => setState(() {
    _returnView = 'seller';
    _editing = w;
    _view = 'editor';
  });
  Future<void> _favorite(MarketListing w) async {
    final result = await ref.read(commerceProvider.notifier).favorite(w.id);
    if (mounted && !result.success) AppToast.showError(context, result.error);
  }

  Future<void> _checkout(MarketListing w) async {
    final order = await showAppDrawer<MarketOrder>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MarketCheckout(listing: w),
    );
    if (mounted && order != null) _openOrder(order.id);
  }

  Future<void> _share(MarketListing w) async {
    final route = Uri(path: '/market', queryParameters: {'listingId': w.id});
    final uri = Uri.base.replace(fragment: '$route');
    await Clipboard.setData(
      ClipboardData(text: '${w.title} · ${w.author}\n$uri'),
    );
    if (mounted) AppToast.showSuccess(context, '作品链接已复制');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commerceProvider);
    final controller = ref.read(commerceProvider.notifier);
    final role = ref.watch(shellControllerProvider.select((s) => s.user.role));
    if (_view == 'editor') {
      return MarketplaceEditor(initial: _editing, onClose: _back);
    }
    Widget content;
    if (_view == 'order') {
      content = MarketOrderPage(orderId: _order!, onBack: _back);
    } else if (_view == 'moderation') {
      content = MarketModerationPage(
        onBack: () => setState(() => _view = 'discover'),
      );
    } else if (_view == 'detail' && _selected != null) {
      final w = state.listings.where((l) => l.id == _selected).firstOrNull;
      content = w != null
          ? _detail(w)
          : ref
                .watch(_listingProvider(_selected!))
                .when(
                  loading: () => const Center(child: AppLoadingIndicator()),
                  error: (e, _) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppErrorState(
                        title: '作品暂时无法查看',
                        description: '$e'.replaceFirst('Bad state: ', ''),
                        onRetry: () =>
                            ref.invalidate(_listingProvider(_selected!)),
                      ),
                      AppButton(label: '返回集市', onTap: _back),
                    ],
                  ),
                  data: _detail,
                );
    } else {
      content = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            CreativeHeading(
              title: _view == 'seller'
                  ? '创作者工作台'
                  : _view == 'orders'
                  ? '我的订单'
                  : '集市',
              subtitle: _view == 'seller'
                  ? '管理发布、交付与售后'
                  : _view == 'orders'
                  ? '交易进展、数字交付与售后记录'
                  : '发现创作 · 数字授权与实物作品',
              onBack: _view == 'discover'
                  ? null
                  : () => setState(() => _view = 'discover'),
              actions: [
                if (_view == 'discover') ...[
                  AppButton(
                    label: '我的订单',
                    variant: AppButtonVariant.secondary,
                    onTap: () => setState(() => _view = 'orders'),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: '创作者工作台',
                    variant: AppButtonVariant.secondary,
                    onTap: () => setState(() => _view = 'seller'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_view == 'orders')
                  AppButton(
                    label: '收货地址',
                    variant: AppButtonVariant.secondary,
                    onTap: () => showAppDrawer(
                      context: context,
                      builder: (_) => const MarketAddressBook(),
                    ),
                  ),
                if (_view != 'orders')
                  AppButton(
                    label: '发布作品',
                    icon: Icons.add,
                    onTap: () => _edit(),
                  ),
              ],
            ),
            if (state.error.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: AppNotice(
                      message: state.error,
                      tone: AppTone.warning,
                    ),
                  ),
                  AppButton(
                    label: '重试',
                    variant: AppButtonVariant.secondary,
                    onTap: controller.load,
                  ),
                ],
              ),
            if (state.loading && !state.loaded)
              const Expanded(child: Center(child: AppLoadingIndicator()))
            else if (_view == 'orders')
              Expanded(
                child: MarketOrderList(
                  orders: state.orders,
                  seller: false,
                  onSelect: _openOrder,
                ),
              )
            else if (_view == 'seller') ...[
              Row(
                children: [
                  AppSegmented<String>(
                    value: _sellerTab,
                    segments: const [
                      AppSegment(value: 'listings', label: '我的发布'),
                      AppSegment(value: 'orders', label: '卖出的订单'),
                    ],
                    onChanged: (v) => setState(() => _sellerTab = v),
                  ),
                  const Spacer(),
                  AppIconButton(
                    icon: Icons.refresh,
                    semanticLabel: '刷新工作台',
                    onTap: controller.load,
                  ),
                ],
              ),
              Expanded(
                child: _sellerTab == 'orders'
                    ? MarketOrderList(
                        orders: state.orders,
                        seller: true,
                        onSelect: _openOrder,
                      )
                    : MarketSellerListings(onEdit: _edit, onDetail: _open),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: AppSegmented<String>(
                      value: state.kind,
                      segments: const [
                        AppSegment(value: '', label: '发现作品'),
                        AppSegment(value: 'digital', label: '数字授权'),
                        AppSegment(value: 'physical', label: '实物作品'),
                        AppSegment(value: 'showcase', label: '创作分享'),
                      ],
                      onChanged: (v) => controller.filter(kind: v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 200,
                    child: AppSearchField(
                      controller: _search,
                      hint: '搜索作品或作者',
                      onChanged: (v) => controller.filter(keyword: v),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: CreativeSubjectFilter(
                      value: state.subject,
                      onChanged: (v) => controller.filter(subject: v),
                    ),
                  ),
                  AppChip(
                    label: '我的收藏',
                    selected: state.savedOnly,
                    onTap: () => controller.filter(savedOnly: !state.savedOnly),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: AppSelect<String>(
                      value: state.sort,
                      options: const [
                        AppSelectOption(value: 'newest', label: '最近发布'),
                        AppSelectOption(value: 'priceAsc', label: '价格从低到高'),
                        AppSelectOption(value: 'priceDesc', label: '价格从高到低'),
                      ],
                      onChanged: (v) => controller.filter(sort: v),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${controller.visible.length} 件作品',
                    style: AppText.caption12,
                  ),
                  const Spacer(),
                  if (role == 'principal' || role == 'admin')
                    AppButton(
                      label: '集市审核',
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.secondary,
                      onTap: () => setState(() => _view = 'moderation'),
                    ),
                  const SizedBox(width: 12),
                  Text('演示交易 · 无真实资金流转', style: AppText.caption12),
                ],
              ),
              Expanded(
                child: controller.visible.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppEmptyState(
                              title: '没有匹配的作品',
                              description: '试试其他科目或交易方式。',
                            ),
                            AppButton(
                              label: '清除筛选',
                              variant: AppButtonVariant.secondary,
                              onTap: () {
                                _search.clear();
                                controller.clearFilters();
                              },
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (_, size) => GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: size.maxWidth >= 880 ? 3 : 2,
                                mainAxisExtent: 348,
                                mainAxisSpacing: 18,
                                crossAxisSpacing: 18,
                              ),
                          itemCount: controller.visible.length,
                          itemBuilder: (_, i) => _card(controller.visible[i]),
                        ),
                      ),
              ),
            ],
          ],
        ),
      );
    }
    return PopScope(
      canPop: _view == 'discover',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: content,
    );
  }

  Widget _card(MarketListing w) => AppCard(
    padding: EdgeInsets.zero,
    onTap: () => _open(w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: AppImage(src: w.cover, height: 220, fit: BoxFit.cover),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      w.title,
                      style: AppText.title16,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(w.priceLabel, style: AppText.number(size: 16)),
                ],
              ),
              Row(
                children: [
                  AppAvatar(name: w.author, size: 24),
                  const SizedBox(width: 8),
                  Expanded(child: Text(w.author, style: AppText.body13)),
                  AppIconButton(
                    icon: w.favorite ? Icons.favorite : Icons.favorite_border,
                    semanticLabel: w.favorite ? '取消收藏作品' : '收藏作品',
                    filled: false,
                    size: AppButtonSize.sm,
                    onTap: () => _favorite(w),
                  ),
                ],
              ),
              Text(
                '${w.subject} · ${w.kind.label}${w.kind == MarketKind.physical
                    ? w.stock > 0
                          ? ' · 余 ${w.stock} 件'
                          : ' · 已售罄'
                    : ''}',
                style: AppText.caption12,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _detail(MarketListing w) {
    final state = ref.watch(commerceProvider);
    final pending = state.orders
        .where(
          (o) =>
              o.buyer &&
              o.listing.id == w.id &&
              o.status == MarketOrderStatus.pendingPayment,
        )
        .firstOrNull;
    final purchased = state.orders
        .where(
          (o) =>
              o.buyer &&
              o.listing.id == w.id &&
              o.status == MarketOrderStatus.completed,
        )
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          CreativeHeading(
            title: '作品详情',
            subtitle: '集市 / ${w.subject} / ${w.kind.label}',
            onBack: _back,
            actions: [
              if (w.status == MarketPublication.published)
                AppButton(
                  label: '分享作品',
                  icon: Icons.ios_share,
                  variant: AppButtonVariant.secondary,
                  onTap: () => _share(w),
                ),
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                Expanded(
                  flex: 6,
                  child: AppCard(
                    padding: const EdgeInsets.all(24),
                    color: AppColors.surfaceSubtle,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: AppImage(src: w.cover, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: ListView(
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 16,
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                AppTag.subject(w.subject),
                                AppTag(label: w.kind.label),
                                if (w.status != MarketPublication.published)
                                  AppTag(label: w.status.label),
                              ],
                            ),
                            Text(w.title, style: AppText.title24),
                            Row(
                              children: [
                                AppAvatar(name: w.author, size: 32),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    w.author,
                                    style: AppText.body14Strong,
                                  ),
                                ),
                              ],
                            ),
                            Text(w.description, style: AppText.body14),
                            const Divider(color: AppColors.line),
                            if (w.kind == MarketKind.digital) ...[
                              Text(w.license.label, style: AppText.title16),
                              Text(w.terms, style: AppText.body14),
                              Text(
                                '付款后交付 ${w.deliveryCount} 份文件 · 非独占授权',
                                style: AppText.body13,
                              ),
                            ] else if (w.kind == MarketKind.physical) ...[
                              Text('作品规格', style: AppText.title16),
                              Text(w.specification, style: AppText.body14),
                              Text(
                                '库存 ${w.stock} 件 · 运费 ${marketMoney(w.shippingCents)}\n付款后 ${w.dispatchDays} 天内发货',
                                style: AppText.body13,
                              ),
                              Text(
                                '购买实物不包含著作权转让或商业使用授权。',
                                style: AppText.body13,
                              ),
                            ] else
                              Text('用于创作交流，作者保留作品相关权利。', style: AppText.body14),
                            if (w.rightsNote.isNotEmpty)
                              Text(
                                '作者权属说明：${w.rightsNote}',
                                style: AppText.body13,
                              ),
                            Text(
                              w.priceLabel,
                              style: AppText.displayNumber(size: 32),
                            ),
                            if (w.mine)
                              AppButton(
                                label: '管理这件作品',
                                onTap: () => setState(() {
                                  _view = 'seller';
                                  _sellerTab = 'listings';
                                }),
                              )
                            else if (pending != null)
                              AppButton(
                                label: '继续付款',
                                onTap: () => _openOrder(pending.id),
                              )
                            else if (w.kind == MarketKind.digital &&
                                purchased != null)
                              AppButton(
                                label: '查看已购订单',
                                onTap: () => _openOrder(purchased.id),
                              )
                            else if (w.forSale)
                              AppButton(
                                label: w.kind == MarketKind.physical
                                    ? w.stock > 0
                                          ? '购买实物作品'
                                          : '暂时售罄'
                                    : '购买使用许可',
                                onTap: w.purchasable && !state.busy
                                    ? () => _checkout(w)
                                    : null,
                              ),
                            if (w.status == MarketPublication.published)
                              AppButton(
                                label: w.favorite ? '已收藏' : '收藏作品',
                                variant: AppButtonVariant.secondary,
                                icon: w.favorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                onTap: state.busy ? null : () => _favorite(w),
                              ),
                            if (w.forSale)
                              Text('演示交易 · 不收取真实款项', style: AppText.caption12),
                            if (!w.mine &&
                                w.status == MarketPublication.published)
                              AppButton(
                                label: '举报作品或权属问题',
                                variant: AppButtonVariant.secondary,
                                size: AppButtonSize.sm,
                                onTap: () => showMarketForm(
                                  context,
                                  title: '举报作品',
                                  explanation: '请说明涉及的内容、权属或交易问题，平台审核后处理。',
                                  fields: const [
                                    MarketFormField(
                                      'reason',
                                      '举报说明（至少 5 字）',
                                      lines: 4,
                                    ),
                                  ],
                                  save: (body) => ref
                                      .read(commerceProvider.notifier)
                                      .report(w.id, '${body['reason']}'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppCard(
                        title: '购买者评价 · ${w.reviews.length}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 14,
                          children: [
                            if (w.reviews.isEmpty)
                              Text('还没有购买者评价', style: AppText.body13),
                            for (final r in w.reviews)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 6,
                                children: [
                                  Text(
                                    '${r['name']} · ${r['rating']} / 5',
                                    style: AppText.body14Strong,
                                  ),
                                  Text(
                                    '${r['content']}',
                                    style: AppText.body14,
                                  ),
                                  Text(
                                    '${r['time']}',
                                    style: AppText.caption12,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
