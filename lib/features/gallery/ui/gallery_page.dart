import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../shell/ui/shell_layout.dart';
import '../../smart_campus/navigation/group_chat_return.dart';
import '../data/gallery_models.dart';
import '../state/gallery_controller.dart';
import '../state/gallery_state.dart';
import 'gallery_detail_view.dart';
import 'widgets/gallery_widgets.dart';
import 'widgets/library_controls.dart';

/// 范画库：名师范画、联考高分卷、学生优秀作品。
///
/// 路由参数（均可选）：`{'subject': '素描'|'色彩'|'速写', 'keyword': String,
/// 'category': 分类 key 或名称, 'workId': String}`；带 `workId` 时直接打开详情，
/// 详情返回即关闭本页（回到收藏、群聊等来源页）。
/// 从侧栏进入（一级页）不显示返回；从其他页面带参数打开时才显示返回。
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  final ScrollController _scroll = ScrollController();
  GalleryQuery? _query;
  bool _openedFromPage = false;

  GalleryQuery get _currentQuery => _query ?? const GalleryQuery();

  GalleryController get _controller =>
      ref.read(galleryControllerProvider(_currentQuery).notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_query == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _openedFromPage = args is Map && args.isNotEmpty;
      _query = GalleryQuery.fromArgs(args);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_handleScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 480) {
      unawaited(_controller.loadMore());
    }
  }

  void _applyFilter(VoidCallback change) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    change();
  }

  Future<void> _toggleFavorite(GalleryWork work) async {
    final ok = await _controller.toggleFavorite(work);
    if (!mounted) {
      return;
    }
    if (!ok) {
      AppToast.showError(context, '收藏失败，请稍后重试');
      return;
    }
    AppToast.showSuccess(context, work.favorite ? '已取消收藏' : '已收藏到「我的收藏」');
  }

  /// 通过 `workId` 直达的详情返回时关闭整页，其余情况回到列表 / 上一幅作品。
  void _closeDetail(GalleryState state) {
    final entryId = _currentQuery.workId;
    final isEntryDetail =
        entryId.isNotEmpty &&
        state.detailStack.length == 1 &&
        state.detailStack.first == entryId;
    if (isEntryDetail) {
      if (GroupChatReturnNavigator.isActive(context)) {
        GroupChatReturnNavigator.pop(context, ref: ref);
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
    }
    _controller.closeDetail();
  }

  void _searchTag(String tag) {
    final controller = _controller..closeAllDetails();
    _applyFilter(() {
      controller.resetFilters();
      controller.setKeyword(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = galleryControllerProvider(_currentQuery);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<GalleryState>(provider, (previous, next) {
      if (!identical(previous?.works, next.works)) {
        // 首屏不足一屏时不会触发滚动，布局完成后再检查一次是否需要加载下一页。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleScroll();
          }
        });
      }
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage || next.works.isEmpty) {
        return;
      }
      // 没有旧数据时由页面错误状态说明，有旧数据时用轻提示，不替换内容。
      AppToast.showError(context, msg);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.clearError();
        }
      });
    });

    final openId = state.openWorkId;
    final canPop = _openedFromPage && Navigator.of(context).canPop();
    return ShellPageSurface(
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: openId != null,
            child: TickerMode(
              enabled: openId == null,
              child: _GalleryBrowser(
                state: state,
                scrollController: _scroll,
                onBack: canPop
                    ? () => GroupChatReturnNavigator.pop(context, ref: ref)
                    : null,
                onSubjectChanged: (s) =>
                    _applyFilter(() => controller.setSubject(s)),
                onCategoryChanged: (c) =>
                    _applyFilter(() => controller.setCategory(c)),
                onSortChanged: (s) => _applyFilter(() => controller.setSort(s)),
                onKeywordChanged: (k) =>
                    _applyFilter(() => controller.setKeyword(k)),
                onResetFilters: () => _applyFilter(controller.resetFilters),
                onRefresh: controller.refresh,
                onOpen: (work) => controller.openDetail(work.id),
                onToggleFavorite: _toggleFavorite,
              ),
            ),
          ),
          if (openId != null)
            GalleryDetailView(
              key: ValueKey(openId),
              detail: state.details[openId],
              loading: state.detailLoading.contains(openId),
              error: state.detailErrors[openId] ?? '',
              onBack: () => _closeDetail(state),
              onRetry: () => unawaited(controller.retryDetail()),
              onToggleFavorite: _toggleFavorite,
              onOpenWork: controller.openDetail,
              onTagSelected: _searchTag,
            ),
        ],
      ),
    );
  }
}

/// 列表：版式取自视频中心。白色内容板内，顶部一行放科目页签、排序和搜索
/// （四周 16、下 12），下面是分类筛选条和作品网格，一起滚动。
class _GalleryBrowser extends StatelessWidget {
  const _GalleryBrowser({
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

  static const _side = 16.0;

  @override
  Widget build(BuildContext context) {
    final subtitle = state.total > 0
        ? '名师范画 · 联考高分卷 · 学生优秀作品 · 共 ${state.total} 幅'
        : '名师范画 · 联考高分卷 · 学生优秀作品';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: '范画库',
          hint: subtitle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_side, 16, _side, 12),
            child: GalleryToolbar(
              state: state,
              onBack: onBack,
              onSubjectChanged: onSubjectChanged,
              onSortChanged: onSortChanged,
              onKeywordChanged: onKeywordChanged,
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _categoryBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_side, 0, _side, 16),
      child: GalleryCategoryBar(state: state, onChanged: onCategoryChanged),
    );
  }

  Widget _buildBody() {
    if (state.works.isEmpty) {
      // 列表为空时 controller 把失败原因留在 errorMessage 里。
      final failed = state.loadFailed || state.errorMessage.isNotEmpty;
      final Widget content;
      if (state.loading) {
        content = const Center(child: AppLoadingIndicator());
      } else if (failed) {
        content = AppErrorState(
          title: '范画加载失败',
          description: '请检查网络后重试',
          onRetry: () => unawaited(onRefresh()),
        );
      } else {
        content = LibraryEmptyState(
          message: state.keyword.isNotEmpty
              ? '没有找到与「${state.keyword}」相关的范画'
              : '这个分类下暂时还没有作品',
          description: state.hasFilters ? '换个科目或分类看看' : '老师上传范画后会出现在这里',
          actionLabel: state.hasFilters ? '清除筛选' : null,
          onAction: state.hasFilters ? onResetFilters : null,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _categoryBar(),
          Expanded(child: content),
        ],
      );
    }
    return Stack(
      children: [
        AppRefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _categoryBar()),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: _side),
                sliver: SliverToBoxAdapter(
                  child: GalleryMasonryGrid(
                    works: state.works,
                    onOpen: onOpen,
                    onToggleFavorite: onToggleFavorite,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _ListFooter(state: state)),
            ],
          ),
        ),
        // 切换筛选时保留旧作品，中间显示加载动画。
        if (state.loading) const Positioned.fill(child: AppLoadingOverlay()),
      ],
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
        padding: EdgeInsets.only(bottom: 16),
        child: Center(child: AppLoadingIndicator()),
      );
    }
    if (state.hasMore) {
      return const SizedBox(height: 24);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: Text(
          '已显示全部 ${state.works.length} 幅作品',
          style: libraryText(size: 12, color: AppColors.textPlaceholder),
        ),
      ),
    );
  }
}
