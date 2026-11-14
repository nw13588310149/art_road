import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/ui.dart';
import '../data/creative_models.dart';
import '../state/market_controller.dart';
import 'creative_widgets.dart';
import 'market_forms.dart';

class MarketSellerListings extends ConsumerStatefulWidget {
  const MarketSellerListings({
    required this.onEdit,
    required this.onDetail,
    super.key,
  });
  final ValueChanged<MarketListing> onEdit, onDetail;
  @override
  ConsumerState<MarketSellerListings> createState() =>
      _MarketSellerListingsState();
}

class _MarketSellerListingsState extends ConsumerState<MarketSellerListings> {
  String _status = '';
  Future<void> _action(MarketListing w, String action) async {
    final title = switch (action) {
      'submit' => '提交审核',
      'withdraw' => '下架作品',
      _ => '归档作品',
    };
    if (!await showAppConfirm(
          context: context,
          title: title,
          message: action == 'submit'
              ? '提交后等待平台审核，通过后公开展示。'
              : '作品将不再公开展示，已有订单和交付记录仍然保留。',
          danger: action != 'submit',
          confirmLabel: title,
        ) ||
        !mounted) {
      return;
    }
    final result = await ref
        .read(commerceProvider.notifier)
        .listingAction(w.id, action);
    if (mounted && !result.success) AppToast.showError(context, result.error);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commerceProvider);
    final mine = state.listings
        .where(
          (l) =>
              l.mine &&
              (_status.isEmpty
                  ? l.status != MarketPublication.archived
                  : l.status.key == _status),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip(
              label: '全部在管作品',
              selected: _status.isEmpty,
              onTap: () => setState(() => _status = ''),
            ),
            for (final s in MarketPublication.values)
              AppChip(
                label: s.label,
                selected: _status == s.key,
                onTap: () => setState(() => _status = s.key),
              ),
          ],
        ),
        Expanded(
          child: mine.isEmpty
              ? const AppEmptyState(
                  title: '这里还没有作品',
                  description: '发布作品后，可在这里管理草稿、审核状态和上架内容。',
                )
              : ListView.separated(
                  itemCount: mine.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final w = mine[i];
                    return AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppImage(
                            src: w.cover,
                            width: 100,
                            height: 124,
                            fit: BoxFit.cover,
                            borderRadius: AppRadius.br8,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 10,
                              children: [
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(w.title, style: AppText.title16),
                                    AppTag(label: w.status.label),
                                  ],
                                ),
                                Text(
                                  '${w.kind.label} · ${w.subject}${w.forSale ? ' · ${w.priceLabel}' : ''}${w.kind == MarketKind.physical ? ' · 库存 ${w.stock}' : ''}',
                                  style: AppText.body13,
                                ),
                                if (w.reviewNote.isNotEmpty)
                                  Text(
                                    '审核反馈：${w.reviewNote}',
                                    style: AppText.body13,
                                  ),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    AppButton(
                                      label: '查看作品',
                                      size: AppButtonSize.sm,
                                      variant: AppButtonVariant.secondary,
                                      onTap: () => widget.onDetail(w),
                                    ),
                                    if (w.editable)
                                      AppButton(
                                        label: '编辑',
                                        size: AppButtonSize.sm,
                                        variant: AppButtonVariant.secondary,
                                        onTap: state.busy
                                            ? null
                                            : () => widget.onEdit(w),
                                      ),
                                    if (w.editable)
                                      AppButton(
                                        label: '提交审核',
                                        size: AppButtonSize.sm,
                                        onTap: state.busy
                                            ? null
                                            : () => _action(w, 'submit'),
                                      ),
                                    if ([
                                      MarketPublication.published,
                                      MarketPublication.pending,
                                    ].contains(w.status))
                                      AppButton(
                                        label:
                                            w.status ==
                                                MarketPublication.pending
                                            ? '撤回审核'
                                            : '下架',
                                        size: AppButtonSize.sm,
                                        variant: AppButtonVariant.secondary,
                                        onTap: state.busy
                                            ? null
                                            : () => _action(w, 'withdraw'),
                                      ),
                                    if (w.editable)
                                      AppButton(
                                        label: '归档',
                                        size: AppButtonSize.sm,
                                        variant: AppButtonVariant.secondary,
                                        onTap: state.busy
                                            ? null
                                            : () => _action(w, 'remove'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class MarketOrderList extends StatefulWidget {
  const MarketOrderList({
    required this.orders,
    required this.seller,
    required this.onSelect,
    super.key,
  });
  final List<MarketOrder> orders;
  final bool seller;
  final ValueChanged<String> onSelect;
  @override
  State<MarketOrderList> createState() => _MarketOrderListState();
}

class _MarketOrderListState extends State<MarketOrderList> {
  String _status = '', _keyword = '';
  @override
  Widget build(BuildContext context) {
    final orders = widget.orders
        .where(
          (o) =>
              (widget.seller ? o.seller : o.buyer) &&
              (_status.isEmpty ||
                  (_status == 'after'
                      ? o.status.afterSale
                      : o.status.key == _status)) &&
              '${o.id} ${o.listing.title} ${o.buyerName}'.contains(
                _keyword.trim(),
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in {
                    '': '全部',
                    'pending_payment': '待付款',
                    'awaiting_shipment': '待发货',
                    'shipped': '待收货',
                    'after': '售后',
                    'completed': '已完成',
                  }.entries)
                    AppChip(
                      label: e.value,
                      selected: _status == e.key,
                      onTap: () => setState(() => _status = e.key),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 190,
              child: AppSearchField(
                hint: '搜索作品、订单',
                onChanged: (v) => setState(() => _keyword = v),
              ),
            ),
          ],
        ),
        Expanded(
          child: orders.isEmpty
              ? const AppEmptyState(
                  title: '暂无匹配的订单',
                  description: '订单创建后会记录在这里，也可切换状态或调整搜索。',
                )
              : ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final o = orders[i];
                    return AppCard(
                      onTap: () => widget.onSelect(o.id),
                      child: Row(
                        children: [
                          AppImage(
                            src: o.listing.cover,
                            width: 80,
                            height: 96,
                            fit: BoxFit.cover,
                            borderRadius: AppRadius.br8,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [
                                Text(o.listing.title, style: AppText.title16),
                                Text(
                                  '${o.listing.kind.label} · ${widget.seller ? '买家 ${o.buyerName}' : o.listing.author}',
                                  style: AppText.body13,
                                ),
                                Text(
                                  '${o.id} · ${o.time}',
                                  style: AppText.caption12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            spacing: 10,
                            children: [
                              Text(
                                marketMoney(o.totalCents),
                                style: AppText.number(size: 20),
                              ),
                              AppTag(label: o.status.label),
                              Text('查看订单 →', style: AppText.caption12),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class MarketModerationPage extends ConsumerWidget {
  const MarketModerationPage({required this.onBack, super.key});
  final VoidCallback onBack;
  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    String id,
    bool approve, {
    bool caseReview = false,
  }) async {
    final done = await showMarketForm(
      context,
      title: caseReview ? '处理平台申请' : '作品审核',
      explanation: caseReview
          ? (approve
                ? '支持申请：举报作品将下架，订单争议将完成模拟退款。'
                : '不支持申请：保留当前作品或订单状态，并将处理理由记录在案。')
          : (approve
                ? '确认作品说明、权属和交易信息完整后，作品将公开展示。'
                : '说明需要补充或修改的内容，作者可修改后再次提交。'),
      confirmLabel: caseReview
          ? '确认处理'
          : approve
          ? '通过审核'
          : '退回修改',
      fields: const [MarketFormField('note', '处理依据（至少 5 字）', lines: 4)],
      save: (body) => caseReview
          ? ref
                .read(commerceProvider.notifier)
                .resolveCase(id, uphold: approve, note: '${body['note']}')
          : ref
                .read(commerceProvider.notifier)
                .moderate(id, approve: approve, note: '${body['note']}'),
    );
    if (done) ref.invalidate(marketModerationProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketModerationProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          CreativeHeading(
            title: '集市审核',
            subtitle: '发布审核、作品举报与交易争议',
            onBack: onBack,
            actions: [
              AppIconButton(
                icon: Icons.refresh,
                semanticLabel: '刷新审核队列',
                onTap: () => ref.invalidate(marketModerationProvider),
              ),
            ],
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => AppErrorState(
                title: '审核队列加载失败',
                description: '$e',
                onRetry: () => ref.invalidate(marketModerationProvider),
              ),
              data: (data) => ListView(
                children: [
                  Text(
                    '待审核作品 · ${data.listings.length}',
                    style: AppText.title20,
                  ),
                  const SizedBox(height: 16),
                  if (data.listings.isEmpty)
                    AppCard(child: Text('当前没有待审核作品', style: AppText.body14)),
                  for (final w in data.listings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppImage(
                              src: w.cover,
                              width: 130,
                              height: 160,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(w.title, style: AppText.title16),
                                  Text(
                                    '${w.author} · ${w.subject} · ${w.kind.label} · ${w.priceLabel}',
                                    style: AppText.body13,
                                  ),
                                  Text(w.description, style: AppText.body14),
                                  Text(
                                    w.kind == MarketKind.digital
                                        ? '${w.terms}\n交付文件 ${w.deliveryCount} 份'
                                        : '${w.specification} · 库存 ${w.stock}',
                                    style: AppText.body13,
                                  ),
                                  if (w.rightsNote.isNotEmpty)
                                    Text(
                                      '权属说明：${w.rightsNote}',
                                      style: AppText.body13,
                                    ),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      AppButton(
                                        label: '通过审核',
                                        onTap: () =>
                                            _review(context, ref, w.id, true),
                                      ),
                                      AppButton(
                                        label: '退回修改',
                                        variant: AppButtonVariant.secondary,
                                        onTap: () =>
                                            _review(context, ref, w.id, false),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    '举报与争议 · ${data.cases.where((c) => c['status'] == 'open').length} 待处理',
                    style: AppText.title20,
                  ),
                  const SizedBox(height: 16),
                  if (data.cases.isEmpty)
                    AppCard(child: Text('当前没有举报或交易争议', style: AppText.body14)),
                  for (final c in data.cases.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12,
                          children: [
                            Text(
                              '${c['kind'] == 'dispute' ? '交易争议' : '作品举报'} · ${c['orderId'] ?? c['listingId']}',
                              style: AppText.title16,
                            ),
                            Text(
                              '${c['title']} · 申请人 ${c['reporter']}',
                              style: AppText.body14Strong,
                            ),
                            Text('${c['reason']}', style: AppText.body14),
                            AppButton(
                              label: '查看相关记录',
                              variant: AppButtonVariant.secondary,
                              size: AppButtonSize.sm,
                              onTap: () => showAppDrawer(
                                context: context,
                                builder: (_) => _CaseEvidence(caseData: c),
                              ),
                            ),
                            Text(
                              '${c['time']} · ${c['status'] == 'open' ? '待处理' : '已处理'}',
                              style: AppText.caption12,
                            ),
                            if (c['status'] == 'open')
                              Wrap(
                                spacing: 12,
                                children: [
                                  AppButton(
                                    label: '支持申请',
                                    onTap: () => _review(
                                      context,
                                      ref,
                                      '${c['id']}',
                                      true,
                                      caseReview: true,
                                    ),
                                  ),
                                  AppButton(
                                    label: '不支持申请',
                                    variant: AppButtonVariant.secondary,
                                    onTap: () => _review(
                                      context,
                                      ref,
                                      '${c['id']}',
                                      false,
                                      caseReview: true,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                '处理意见：${c['note'] ?? ''}',
                                style: AppText.body13,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseEvidence extends StatelessWidget {
  const _CaseEvidence({required this.caseData});
  final CreativeJson caseData;
  @override
  Widget build(BuildContext context) {
    final w = MarketListing.fromJson(creativeMap(caseData['listing']));
    final o = caseData['order'] is Map
        ? MarketOrder.fromJson(creativeMap(caseData['order']))
        : null;
    return AppDrawer(
      title: '申请相关记录',
      width: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          AppImage(src: w.cover, height: 220, fit: BoxFit.contain),
          Text(w.title, style: AppText.title20),
          Text(
            '${w.author} · ${w.kind.label} · ${w.status.label}',
            style: AppText.body13,
          ),
          Text(w.description, style: AppText.body14),
          Text(w.rightsNote, style: AppText.body13),
          if (o != null) ...[
            const Divider(color: AppColors.line),
            Text('订单 ${o.id}', style: AppText.title16),
            Text(
              '${o.buyerName} · ${o.status.label} · ${marketMoney(o.totalCents)}',
              style: AppText.body14Strong,
            ),
            Text(
              o.listing.kind == MarketKind.digital
                  ? o.listing.terms
                  : o.listing.specification,
              style: AppText.body13,
            ),
            if (o.afterSale.isNotEmpty)
              Text(
                '售后申请：${o.afterSale['reason']}\n卖家回复：${o.afterSale['decisionNote'] ?? '暂无'}',
                style: AppText.body14,
              ),
            for (final e in o.events.reversed)
              Text(
                '${e['label']}\n${e['time']} · ${e['actor']}\n${e['note'] ?? ''}',
                style: AppText.body13,
              ),
          ],
        ],
      ),
    );
  }
}
