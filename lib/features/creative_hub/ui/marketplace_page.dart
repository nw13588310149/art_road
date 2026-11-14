import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/creative_models.dart';
import '../data/creative_repository.dart';
import '../state/creative_controllers.dart';
import 'creative_widgets.dart';
import 'marketplace_editor.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});
  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  String? _selected;
  bool _creating = false, _orders = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketplaceProvider);
    final controller = ref.read(marketplaceProvider.notifier);
    final work = state.items.where((item) => item.id == _selected).firstOrNull;
    if (_creating) {
      return MarketplaceEditor(
        onClose: () => setState(() => _creating = false),
      );
    }
    if (_orders) return _orderList();
    if (work != null) return _detail(work);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          CreativeHeading(
            title: '集市',
            subtitle: '让好作品被看见，也让创作拥有更多可能。',
            actions: [
              AppButton(
                label: '我的订单',
                variant: AppButtonVariant.secondary,
                onTap: () => setState(() => _orders = true),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: '发布作品',
                icon: Icons.add,
                onTap: () => setState(() => _creating = true),
              ),
            ],
          ),
          Row(
            children: [
              AppSegmented<String>(
                value: state.view,
                onChanged: (value) => controller.filter(view: value),
                segments: const [
                  AppSegment(value: 'all', label: '发现作品'),
                  AppSegment(value: 'sale', label: '可购买'),
                  AppSegment(value: 'saved', label: '我的收藏'),
                  AppSegment(value: 'mine', label: '我的发布'),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 210,
                child: AppSearchField(
                  hint: '搜索作品或作者',
                  onChanged: (value) => controller.filter(keyword: value),
                ),
              ),
            ],
          ),
          CreativeSubjectFilter(
            value: state.subject,
            onChanged: (value) => controller.filter(subject: value),
          ),
          Expanded(
            child: state.loading
                ? const Center(child: AppLoadingIndicator())
                : state.error.isNotEmpty
                ? AppErrorState(
                    title: '集市加载失败',
                    description: state.error,
                    onRetry: controller.load,
                  )
                : controller.visible.isEmpty
                ? const AppEmptyState(
                    title: '还没有匹配的作品',
                    description: '换个关键词，或分享自己的创作。',
                  )
                : LayoutBuilder(
                    builder: (context, size) => GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: size.maxWidth >= 880 ? 3 : 2,
                        mainAxisExtent: 334,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                      ),
                      itemCount: controller.visible.length,
                      itemBuilder: (context, index) =>
                          _card(controller.visible[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(MarketListing work) => AppCard(
    padding: EdgeInsets.zero,
    onTap: () => setState(() => _selected = work.id),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: AppImage(src: work.cover, height: 220, fit: BoxFit.cover),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      work.title,
                      style: AppText.title16,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    work.priceLabel,
                    style: AppText.number(size: work.forSale ? 16 : 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  AppAvatar(name: work.author, size: 24),
                  const SizedBox(width: 8),
                  Expanded(child: Text(work.author, style: AppText.body13)),
                  AppIconButton(
                    icon: work.favorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    semanticLabel: work.favorite ? '取消收藏作品' : '收藏作品',
                    filled: false,
                    size: AppButtonSize.sm,
                    onTap: () => _favorite(work),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                work.forSale
                    ? '${work.subject} · ${work.license.label}'
                    : '${work.subject} · 创作分享',
                style: AppText.caption12,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _favorite(MarketListing work) async {
    final error = await ref
        .read(marketplaceProvider.notifier)
        .favorite(work.id);
    if (mounted && error != null) AppToast.showError(context, error);
  }

  Future<void> _buy(MarketListing work) async {
    final confirmed = await showAppConfirm(
      context: context,
      title: '确认演示订单',
      message:
          '《${work.title}》\n${work.license.label} · ${work.priceLabel}\n\n${work.license.description}\n\n本次为演示购买，不收取真实款项。',
      confirmLabel: '确认演示购买',
    );
    if (!confirmed || !mounted) return;
    final error = await ref.read(marketplaceProvider.notifier).buy(work.id);
    if (!mounted) return;
    if (error != null) {
      AppToast.showError(context, error);
    } else {
      ref.invalidate(marketOrdersProvider);
      AppToast.showSuccess(context, '演示订单已完成，可在我的订单中查看');
    }
  }

  Future<void> _remove(MarketListing work) async {
    final confirmed = await showAppConfirm(
      context: context,
      title: '撤下作品',
      message: '撤下后不再出现在集市中，已完成的订单仍可查看。',
      danger: true,
      confirmLabel: '撤下',
    );
    if (!confirmed || !mounted) return;
    final error = await ref
        .read(marketplaceProvider.notifier)
        .action(
          () => ref
              .read(creativeRepositoryProvider)
              .remove('market/listings', work.id),
        );
    if (!mounted) return;
    if (error != null) {
      AppToast.showError(context, error);
    } else {
      setState(() => _selected = null);
    }
  }

  Widget _detail(MarketListing work) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        CreativeHeading(
          title: '作品详情',
          subtitle: '集市 / ${work.subject}',
          onBack: () => setState(() => _selected = null),
          actions: [
            AppButton(
              label: work.favorite ? '已收藏' : '收藏作品',
              variant: AppButtonVariant.secondary,
              icon: work.favorite ? Icons.favorite : Icons.favorite_border,
              onTap: () => _favorite(work),
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
                  padding: const EdgeInsets.all(20),
                  color: AppColors.surfaceSubtle,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: AppImage(src: work.cover, fit: BoxFit.contain),
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
                        children: [
                          AppTag.subject(work.subject),
                          const SizedBox(height: 16),
                          Text(work.title, style: AppText.title24),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              AppAvatar(name: work.author, size: 36),
                              const SizedBox(width: 10),
                              Text(work.author, style: AppText.body14Strong),
                            ],
                          ),
                          const Divider(height: 32, color: AppColors.line),
                          Text('创作说明', style: AppText.title16),
                          const SizedBox(height: 10),
                          Text(work.description, style: AppText.body14),
                          const Divider(height: 32, color: AppColors.line),
                          Text(
                            work.forSale ? '数字作品使用许可' : '作品展示',
                            style: AppText.title16,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            work.forSale ? work.license.label : '作者保留作品的相关权利',
                            style: AppText.body14Strong,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            work.forSale
                                ? work.license.description
                                : '这份作品用于创作交流，当前未开放购买。',
                            style: AppText.body13,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            work.priceLabel,
                            style: AppText.displayNumber(size: 32),
                          ),
                          const SizedBox(height: 16),
                          if (work.mine)
                            AppButton(
                              label: '撤下作品',
                              variant: AppButtonVariant.secondary,
                              onTap: () => _remove(work),
                            )
                          else if (work.purchased)
                            AppButton(
                              label: '查看我的订单',
                              onTap: () => setState(() => _orders = true),
                            )
                          else if (work.forSale)
                            AppButton(
                              label: '购买使用许可',
                              loading: ref.watch(
                                marketplaceProvider.select((s) => s.busy),
                              ),
                              onTap: () => _buy(work),
                            ),
                          if (work.forSale) ...[
                            const SizedBox(height: 12),
                            Text('演示交易 · 不收取真实款项', style: AppText.caption12),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _orderList() {
    final orders = ref.watch(marketOrdersProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          CreativeHeading(
            title: '我的订单',
            subtitle: '已获得的数字作品使用许可 · 演示交易',
            onBack: () => setState(() => _orders = false),
          ),
          Expanded(
            child: orders.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (error, _) => AppErrorState(
                title: '订单加载失败',
                onRetry: () => ref.invalidate(marketOrdersProvider),
              ),
              data: (items) => items.isEmpty
                  ? const AppEmptyState(
                      title: '还没有订单',
                      description: '购买完成后，作品和许可说明会保存在这里。',
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final order = items[index];
                        final work = order.listing;
                        return AppCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppImage(
                                src: work.cover,
                                width: 128,
                                height: 146,
                                fit: BoxFit.cover,
                                borderRadius: AppRadius.br8,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 8,
                                  children: [
                                    Text(work.title, style: AppText.title20),
                                    Text(
                                      '${work.author} · ${work.license.label}',
                                      style: AppText.body14,
                                    ),
                                    Text(
                                      work.license.description,
                                      style: AppText.body13,
                                    ),
                                    Text(
                                      '${order.id} · ${order.time}',
                                      style: AppText.caption12,
                                    ),
                                    AppButton(
                                      label: '查看数字作品',
                                      size: AppButtonSize.sm,
                                      variant: AppButtonVariant.secondary,
                                      onTap: () => openReadingResource(
                                        context,
                                        ReadingResource(
                                          id: work.id,
                                          title: work.title,
                                          kind: 'images',
                                          cover: work.cover,
                                          pages: [work.cover],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    work.priceLabel,
                                    style: AppText.number(size: 20),
                                  ),
                                  const SizedBox(height: 8),
                                  const AppTag(label: '演示订单已完成'),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
