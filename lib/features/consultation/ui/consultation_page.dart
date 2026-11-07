import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../state/consultation_controller.dart';
import '../state/consultation_detail_state.dart';
import '../state/consultation_state.dart';

class ConsultationPage extends ConsumerStatefulWidget {
  const ConsultationPage({super.key});

  @override
  ConsumerState<ConsultationPage> createState() => _ConsultationPageState();
}

class _ConsultationPageState extends ConsumerState<ConsultationPage> {
  ConsultationCategory _category = ConsultationCategory.all;

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final args = _parseArgs(ModalRoute.of(context)?.settings.arguments);
    final provider = consultationControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<ConsultationState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) return;
      // 首屏失败由错误状态承接；已有内容时（加载更多失败）只轻提示。
      if (next.items.isNotEmpty) {
        AppToast.showError(context, msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.mounted) controller.clearError();
        });
      }
    });

    final counts = <ConsultationCategory, int>{
      for (final category in ConsultationCategory.values)
        category: state.items.where(category.matches).length,
    };
    final tabs = ConsultationCategory.values
        .where((c) => c == ConsultationCategory.all || counts[c]! > 0)
        .toList(growable: false);
    final category = tabs.contains(_category)
        ? _category
        : ConsultationCategory.all;
    final visible = state.items
        .where(category.matches)
        .toList(growable: false);

    final Widget body;
    if (state.loading && state.items.isEmpty) {
      body = const _ConsultationSkeleton();
    } else if (state.items.isEmpty && state.errorMessage.isNotEmpty) {
      body = AppErrorState(
        title: '资讯加载失败',
        description: state.errorMessage,
        onRetry: controller.refresh,
      );
    } else if (state.items.isEmpty) {
      body = const AppEmptyState(
        icon: Icons.feed_outlined,
        title: '暂无资讯',
        description: '画室或平台发布资讯后会显示在这里',
      );
    } else if (visible.isEmpty) {
      body = AppEmptyState(
        icon: Icons.feed_outlined,
        title: '「${category.label}」暂无资讯',
        actionLabel: '查看全部',
        onAction: () => setState(() => _category = ConsultationCategory.all),
      );
    } else {
      body = _ConsultationGrid(
        items: visible,
        loadingMore: state.loadingMore,
        sourceName: args.sourceName,
        onLoadMore: controller.loadMore,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: args.schoolMode ? '校园资讯' : '资讯',
          subtitle: args.schoolMode
              ? '${args.sourceName ?? '画室'}发布的通知与动态'
              : '联考政策、院校校考与备考经验',
          onBack: _back,
          bottom: tabs.length > 2
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: AppTabs<ConsultationCategory>(
                    tabs: [
                      for (final tab in tabs)
                        AppTab(
                          value: tab,
                          label: tab.label,
                          count: counts[tab],
                        ),
                    ],
                    value: category,
                    onChanged: (value) => setState(() => _category = value),
                  ),
                )
              : null,
        ),
        Expanded(child: body),
      ],
    );
  }

  ConsultationPageArgs _parseArgs(dynamic raw) {
    if (raw is ConsultationPageArgs) {
      return raw;
    }
    if (raw is Map) {
      return ConsultationPageArgs(
        schoolMode: _isTruthy(raw['schoolMode']) || _isTruthy(raw['school']),
        sourceName:
            raw['sourceName']?.toString() ?? raw['schoolName']?.toString(),
      );
    }
    return const ConsultationPageArgs();
  }
}

/// 仿 JS `!!value` 语义：null/false/0/空串视为假，其他视为真。
bool _isTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower != 'false' && lower != '0';
  }
  return true;
}

int _columnsFor(double width) => width >= 840 ? 3 : (width >= 520 ? 2 : 1);

const _cardExtent = 104.0;

class _ConsultationGrid extends StatefulWidget {
  const _ConsultationGrid({
    required this.items,
    required this.loadingMore,
    required this.onLoadMore,
    this.sourceName,
  });

  final List<ConsultationItem> items;
  final bool loadingMore;
  final String? sourceName;
  final Future<void> Function() onLoadMore;

  @override
  State<_ConsultationGrid> createState() => _ConsultationGridState();
}

class _ConsultationGridState extends State<_ConsultationGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 320) {
      unawaited(widget.onLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth - AppSpace.page * 2);
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                AppSpace.s4,
                AppSpace.page,
                AppSpace.s24,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpace.s16,
                  mainAxisSpacing: AppSpace.s16,
                  mainAxisExtent: _cardExtent,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ConsultationCard(
                    item: widget.items[index],
                    latest: widget.items[index].isLatest(now),
                    sourceName: widget.sourceName,
                  ),
                  childCount: widget.items.length,
                ),
              ),
            ),
            if (widget.loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: AppSpace.s24),
                  child: Center(child: AppLoadingIndicator(size: 24)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({
    required this.item,
    required this.latest,
    this.sourceName,
  });

  final ConsultationItem item;
  final bool latest;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s12),
      onTap: () => Navigator.pushNamed(
        context,
        RoutePaths.consultationDetail,
        arguments: ConsultationDetailArgs(id: item.id, sourceName: sourceName),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            src: item.coverUrl,
            width: 80,
            height: 80,
            borderRadius: AppRadius.br8,
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
                const Spacer(),
                Row(
                  children: [
                    if (latest) ...[
                      const AppTag(label: '最新', tone: AppTone.brand),
                      const SizedBox(width: AppSpace.s8),
                    ],
                    Flexible(
                      child: Text(
                        formatRelativeTime(item.createTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s12),
                    ViewCountLabel(count: item.viewCount),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 浏览量：眼睛图标 + 数字，资讯、视频共用一种写法。
class ViewCountLabel extends StatelessWidget {
  const ViewCountLabel({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.visibility_outlined,
          size: 14,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: AppSpace.s4),
        Text(
          '$count',
          style: AppText.number(size: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _ConsultationSkeleton extends StatelessWidget {
  const _ConsultationSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth - AppSpace.page * 2);
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s4,
            AppSpace.page,
            AppSpace.s24,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpace.s16,
            mainAxisSpacing: AppSpace.s16,
            mainAxisExtent: _cardExtent,
          ),
          itemCount: columns * 3,
          itemBuilder: (_, _) => const AppCard(
            padding: EdgeInsets.all(AppSpace.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 80, height: 80, radius: AppRadius.control),
                SizedBox(width: AppSpace.s12),
                Expanded(child: AppSkeletonText(lines: 3)),
              ],
            ),
          ),
        );
      },
    );
  }
}
