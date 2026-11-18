import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../smart_campus/navigation/group_chat_return.dart';
import '../data/gallery_models.dart';
import '../state/gallery_controller.dart';
import '../state/gallery_state.dart';
import 'gallery_detail_view.dart';
import 'widgets/gallery_browser.dart';

/// 素材中心：名师范画、联考高分卷、学生优秀作品。
///
/// 路由参数（均可选）：`{'subject': '素描'|'色彩'|'速写', 'keyword': String,
/// 'category': 分类 key 或名称, 'workId': String}`；带 `workId` 时直接打开详情，
/// 详情返回即关闭本页（回到收藏、群聊等来源页）。
/// 从侧栏进入（一级页）不显示返回；从其他页面带参数打开时才显示返回。
/// 页面放在外壳给的白色底板上。
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: openId != null,
          child: TickerMode(
            enabled: openId == null,
            child: GalleryBrowser(
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
    );
  }
}
