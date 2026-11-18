import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/ui/ui.dart';
import '../data/ebook_models.dart';
import '../state/ebook_reader_controller.dart';
import '../state/ebook_spread.dart';
import 'widgets/ebook_reader_bars.dart';
import 'widgets/ebook_reader_toc.dart';

/// 全屏阅读器：宽屏双页并排、窄屏单页；点左右半屏、两侧箭头、左右滑动或方向键翻页，
/// 翻页即时切换。底部缩略图与页码拖动条，支持跳页、目录、书签与放大查看，进度自动保存。
///
/// 沉浸页，不带外壳（`docs/新页面设计语言.md` 第九节）：白色顶栏和底栏，中间是
/// 中性灰的阅读区，书页衬在上面。
class EbookReaderPage extends ConsumerStatefulWidget {
  const EbookReaderPage({
    required this.bookId,
    this.initialPage = 0,
    super.key,
  });

  final String bookId;

  /// 打开时跳到的页码；0 表示从上次的进度继续。
  final int initialPage;

  static const routeName = '/ebooks/reader';
  static const previousKey = ValueKey<String>('ebook-reader-previous');
  static const nextKey = ValueKey<String>('ebook-reader-next');
  static const stageKey = ValueKey<String>('ebook-reader-stage');
  static const pageLabelKey = ValueKey<String>('ebook-reader-page-label');

  static const topBarHeight = EbookReaderTopBar.height;
  static const bottomBarHeight = EbookReaderBottomBar.height;

  /// 阅读区两侧留给翻页箭头的宽度（12 + 44 + 8）。
  static const sideGutter = 64.0;

  /// 阅读区上下的留白。
  static const stagePadding = 24.0;

  /// 阅读区的底色。
  static const stageColor = AppColors.canvas;

  /// 全屏阅读路由（不经过外壳、没有转场动画）；关闭时返回最新的阅读进度。
  static Route<EbookProgress> route({
    required String bookId,
    int initialPage = 0,
  }) {
    return PageRouteBuilder<EbookProgress>(
      settings: const RouteSettings(name: routeName),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          EbookReaderPage(bookId: bookId, initialPage: initialPage),
    );
  }

  @override
  ConsumerState<EbookReaderPage> createState() => _EbookReaderPageState();
}

class _EbookReaderPageState extends ConsumerState<EbookReaderPage> {
  late final EbookReaderArgs _args = EbookReaderArgs(
    bookId: widget.bookId,
    initialPage: widget.initialPage,
  );
  final ScrollController _thumbs = ScrollController();
  EbookSpread? _spread;
  bool _zoom = false;
  bool _closing = false;

  EbookReaderController get _controller =>
      ref.read(ebookReaderControllerProvider(_args).notifier);

  @override
  void dispose() {
    _thumbs.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    final progress = await _controller.flush();
    if (mounted) {
      Navigator.of(context).pop(progress);
    }
  }

  void _next() {
    final spread = _spread;
    if (spread != null) {
      _controller.next(spread);
    }
  }

  void _previous() {
    final spread = _spread;
    if (spread != null) {
      _controller.previous(spread);
    }
  }

  void _goTo(int page) {
    final spread = _spread;
    if (spread != null) {
      _controller.goTo(page, spread);
    }
  }

  void _syncThumbs(int page) {
    if (!_thumbs.hasClients) {
      return;
    }
    final position = _thumbs.position;
    const extent = EbookReaderBottomBar.thumbWidth;
    final target =
        ((page - 1) * extent - (position.viewportDimension - extent) / 2).clamp(
          0.0,
          position.maxScrollExtent,
        );
    if ((position.pixels - target).abs() > 1) {
      _thumbs.jumpTo(target);
    }
  }

  Future<void> _openToc(EbookReaderState state) async {
    final visible = _spread?.pagesAt(state.page) ?? <int>[state.page];
    final page = await showAppDrawer<int>(
      context: context,
      builder: (_) => EbookTocDrawer(state: state, visible: visible),
    );
    if (page != null && mounted) {
      _goTo(page);
    }
  }

  Future<void> _toggleBookmark(int page) async {
    final had = ref
        .read(ebookReaderControllerProvider(_args))
        .isBookmarked(page);
    final ok = await _controller.toggleBookmark(page);
    if (!mounted) {
      return;
    }
    if (ok) {
      AppToast.showSuccess(context, had ? '已删除第 $page 页的书签' : '已为第 $page 页加书签');
    } else {
      AppToast.showError(context, '书签保存失败，请稍后重试');
    }
  }

  Future<void> _jump(EbookReaderState state) async {
    final page = await showAppDialog<int>(
      context: context,
      builder: (_) =>
          EbookJumpDialog(pageCount: state.pageCount, current: state.page),
    );
    if (page != null && mounted) {
      _goTo(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ebookReaderControllerProvider(_args);
    final state = ref.watch(provider);
    ref.listen<int>(provider.select((s) => s.page), (previous, page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncThumbs(page);
        }
      });
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_close());
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
          const SingleActivator(LogicalKeyboardKey.pageDown): _next,
          const SingleActivator(LogicalKeyboardKey.pageUp): _previous,
        },
        child: Focus(
          autofocus: true,
          child: Material(
            color: AppColors.surface,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final area = Size(
                    constraints.maxWidth - EbookReaderPage.sideGutter * 2,
                    constraints.maxHeight -
                        EbookReaderPage.topBarHeight -
                        EbookReaderPage.bottomBarHeight -
                        EbookReaderPage.stagePadding * 2,
                  );
                  final spread = EbookSpread.fit(
                    pageCount: state.pageCount,
                    area: area,
                  );
                  _spread = spread;
                  final ready =
                      !state.loading &&
                      state.errorMessage.isEmpty &&
                      state.pageCount > 0;
                  final bookmarked = state.isBookmarked(
                    spread.startOf(state.page),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EbookReaderTopBar(
                        title: state.title,
                        ready: ready,
                        bookmarked: bookmarked,
                        zoom: _zoom,
                        compact: constraints.maxWidth < 640,
                        onBack: () => unawaited(_close()),
                        onToc: () => unawaited(_openToc(state)),
                        onBookmark: () => unawaited(
                          _toggleBookmark(spread.startOf(state.page)),
                        ),
                        onZoom: () => setState(() => _zoom = !_zoom),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: EbookReaderPage.stageColor,
                          child: _buildStage(state, spread),
                        ),
                      ),
                      if (ready)
                        EbookReaderBottomBar(
                          state: state,
                          spread: spread,
                          thumbs: _thumbs,
                          pageLabelKey: EbookReaderPage.pageLabelKey,
                          onGoTo: _goTo,
                          onJump: () => unawaited(_jump(state)),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(EbookReaderState state, EbookSpread spread) {
    if (state.loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (state.errorMessage.isNotEmpty || state.pageCount == 0) {
      return AppErrorState(
        title: '书刊加载失败',
        description: state.errorMessage,
        onRetry: () => unawaited(_controller.load()),
      );
    }
    final content = _Spread(
      pages: [
        for (final page in spread.pagesAt(state.page)) state.pageAt(page)!,
      ],
      twoPage: spread.twoPage,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_zoom) {
          return PhotoView.customChild(
            key: ValueKey<int>(spread.startOf(state.page)),
            childSize: constraints.biggest,
            backgroundDecoration: const BoxDecoration(
              color: EbookReaderPage.stageColor,
            ),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained * 4,
            child: Padding(
              padding: const EdgeInsets.all(EbookReaderPage.stagePadding),
              child: content,
            ),
          );
        }
        final width = constraints.maxWidth;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: EbookReaderPage.stageKey,
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => details.localPosition.dx < width / 2
                    ? _previous()
                    : _next(),
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -240) {
                    _next();
                  } else if (velocity > 240) {
                    _previous();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: EbookReaderPage.sideGutter,
                    vertical: EbookReaderPage.stagePadding,
                  ),
                  child: content,
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: AppIconAction(
                  key: EbookReaderPage.previousKey,
                  icon: Icons.chevron_left_rounded,
                  size: 28,
                  color: AppColors.ink,
                  semanticLabel: '上一页',
                  onTap: spread.previous(state.page) == null
                      ? null
                      : _previous,
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: AppIconAction(
                  key: EbookReaderPage.nextKey,
                  icon: Icons.chevron_right_rounded,
                  size: 28,
                  color: AppColors.ink,
                  semanticLabel: '下一页',
                  onTap: spread.next(state.page) == null ? null : _next,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 一屏：单页或双页并排，中缝一条细线。书页上不压书签和按钮。
class _Spread extends StatelessWidget {
  const _Spread({required this.pages, required this.twoPage});

  final List<EbookPage> pages;
  final bool twoPage;

  @override
  Widget build(BuildContext context) {
    final left = pages.first;
    final right = pages.length > 1 ? pages[1] : null;
    return Center(
      child: AspectRatio(
        aspectRatio: twoPage ? left.aspectRatio * 2 : left.aspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _PageImage(page: left)),
              if (twoPage) ...[
                const SizedBox(
                  width: 1,
                  child: ColoredBox(color: AppColors.lineSoft),
                ),
                Expanded(
                  child: right == null
                      ? const SizedBox.shrink()
                      : _PageImage(page: right),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PageImage extends StatelessWidget {
  const _PageImage({required this.page});

  final EbookPage page;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '第 ${page.page} 页',
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(src: page.imageUrl, fit: BoxFit.contain),
          IgnorePointer(
            child: Center(
              child: Transform.rotate(
                angle: -0.42,
                child: Text(
                  '示例书刊 · 仅供演示',
                  style: AppText.title20.copyWith(
                    color: AppColors.ink.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
