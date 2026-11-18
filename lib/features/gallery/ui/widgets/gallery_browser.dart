import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../data/gallery_models.dart';
import '../../state/gallery_state.dart';
import 'gallery_widgets.dart';

/// 素材中心的列表：页头（名称、搜索、排序）、科目筛选、带题材切换的分区标题，
/// 下面是按原比例排开的范画，整页一起滚动，到底自动加载下一页。
class GalleryBrowser extends StatelessWidget {
  const GalleryBrowser({
    required this.state,
    required this.scrollController,
    required this.onBack,
    required this.onSubjectChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onKeywordChanged,
    required this.onResetFilters,
    required this.onRefresh,
    required this.onOpen,
    required this.onToggleFavorite,
    super.key,
  });

  final GalleryState state;
  final ScrollController scrollController;
  final VoidCallback? onBack;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<GallerySort> onSortChanged;
  final ValueChanged<String> onKeywordChanged;
  final VoidCallback onResetFilters;
  final Future<void> Function() onRefresh;
  final ValueChanged<GalleryWork> onOpen;
  final ValueChanged<GalleryWork> onToggleFavorite;

  static const subjects = <String>['', '素描', '色彩', '速写'];

  /// 第二级（题材）：未选科目时只列跨科分类，选了科目再列该科目的分类。
  static List<GalleryCategory> categoriesOf(GalleryState state) => [
    for (final category in state.visibleCategories)
      if (category.key != GalleryCategory.allKey &&
          (state.subject.isNotEmpty || category.subject == null))
        category,
  ];

  /// 去掉分类名里重复的科目前缀：「素描 · 石膏」→「石膏」。
  static String shortLabel(GalleryCategory category) {
    final subject = category.subject;
    if (subject == null) {
      return category.label;
    }
    final label = category.label.replaceFirst(RegExp('^$subject\\s*·\\s*'), '');
    return label.isEmpty ? category.label : label;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppRefreshIndicator(
          onRefresh: onRefresh,
          child: AppPageBody.slivers(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: (context, wide) => [
              SliverToBoxAdapter(child: _header(wide)),
              ..._content(wide),
            ],
          ),
        ),
        // 切换筛选时保留旧作品，中间显示加载动画。
        if (state.loading && state.works.isNotEmpty)
          const Positioned.fill(child: AppLoadingOverlay()),
      ],
    );
  }

  Widget _header(bool wide) {
    final categories = categoriesOf(state);
    final showCount = state.works.isNotEmpty && state.total > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTitleBar(
          title: '素材中心',
          onBack: onBack,
          actions: [
            SizedBox(
              width: wide ? 260 : 220,
              child: GallerySearchBox(
                keyword: state.keyword,
                onChanged: onKeywordChanged,
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            GallerySortButton(value: state.sort, onChanged: onSortChanged),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        AppFilterBar<String>(
          items: [
            for (final subject in subjects)
              AppFilterItem(
                value: subject,
                label: subject.isEmpty ? '全部' : subject,
              ),
          ],
          value: state.subject,
          onChanged: onSubjectChanged,
        ),
        const SizedBox(height: AppSpace.s24),
        const AppRule(),
        const SizedBox(height: AppSpace.s24),
        AppSectionTitle(
          title: '范画',
          note: showCount ? '共 ${state.total} 幅' : '',
          trailing: categories.isEmpty
              ? null
              : AppViewTabs<String>(
                  dense: true,
                  items: [
                    const AppViewTab(
                      value: GalleryCategory.allKey,
                      label: '全部题材',
                    ),
                    for (final category in categories)
                      AppViewTab(
                        value: category.key,
                        label: shortLabel(category),
                      ),
                  ],
                  value: state.category,
                  onChanged: onCategoryChanged,
                ),
        ),
        const SizedBox(height: AppSpace.s16),
      ],
    );
  }

  List<Widget> _content(bool wide) {
    if (state.works.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: _emptyBody()),
        ),
      ];
    }
    final works = state.works;
    return [
      SliverToBoxAdapter(
        child: AppMasonryGrid(
          columns: wide ? 4 : 3,
          gap: AppPageBody.tileGap(wide),
          itemCount: works.length,
          aspectRatioOf: (index) => GalleryWorkTile.aspectOf(works[index]),
          itemBuilder: (context, index) {
            final work = works[index];
            return GalleryWorkTile(
              work: work,
              onOpen: () => onOpen(work),
              onToggleFavorite: () => onToggleFavorite(work),
            );
          },
        ),
      ),
      SliverToBoxAdapter(child: _ListFooter(state: state)),
    ];
  }

  Widget _emptyBody() {
    // 列表为空时 controller 把失败原因留在 errorMessage 里。
    final failed = state.loadFailed || state.errorMessage.isNotEmpty;
    if (state.loading) {
      return const AppLoadingIndicator();
    }
    if (failed) {
      return AppErrorState(
        title: '范画加载失败',
        description: '请检查网络后重试',
        onRetry: () => unawaited(onRefresh()),
      );
    }
    if (state.keyword.isNotEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: '没有找到与「${state.keyword}」相关的范画',
        description: '换个关键词试试，比如作者、题材或点评要点里的词',
        actionLabel: '清除搜索',
        onAction: () => onKeywordChanged(''),
      );
    }
    if (state.hasFilters) {
      return AppEmptyState(
        icon: Icons.image_outlined,
        title: '这个分类下暂时还没有范画',
        description: '换个科目或分类看看',
        actionLabel: '清除筛选',
        onAction: onResetFilters,
      );
    }
    return const AppEmptyState(
      icon: Icons.image_outlined,
      title: '还没有范画',
      description: '老师上传范画后会出现在这里',
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state});

  final GalleryState state;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpace.s24),
        child: Center(child: AppLoadingIndicator()),
      );
    }
    if (state.hasMore) {
      return const SizedBox(height: AppSpace.s24);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s32),
      child: Center(
        child: Text('已显示全部 ${state.works.length} 幅', style: AppText.caption12),
      ),
    );
  }
}
