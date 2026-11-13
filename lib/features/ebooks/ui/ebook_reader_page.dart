import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../gallery/ui/widgets/library_controls.dart';
import '../data/ebook_models.dart';
import '../state/ebook_reader_controller.dart';
import '../state/ebook_spread.dart';

/// 全屏阅读器：宽屏双页并排、窄屏单页；点左右半屏、两侧箭头、左右滑动或方向键翻页，
/// 翻页即时切换。底部缩略图与页码拖动条，支持跳页、目录、书签与放大查看，进度自动保存。
///
/// 外框取自原版的资料预览：56 高的工具栏、四周留 16 的浅色画布、图标按钮、
/// 缩略图的描边与当前页徽标、进度条和页码徽标。
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

  static const topBarHeight = LibraryPreviewHeader.height;

  /// 底栏：上下 10 + 缩略图 66 + 间距 10 + 拖动条一行 32，另加 1px 分隔线。
  static const bottomBarHeight = 129.0;

  /// 画布四周的留白。
  static const stageInset = 16.0;

  /// 画布内两侧留给翻页按钮的宽度（12 + 32 + 12）。
  static const sideGutter = 56.0;

  /// 画布内上下的留白。
  static const stagePadding = 16.0;

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
  static const _thumbWidth = 50.0;
  static const _thumbGap = 8.0;

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
    const extent = _thumbWidth + _thumbGap;
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
    final page = await showLibraryDrawer<int>(
      context: context,
      builder: (_) => _TocDrawer(state: state, visible: visible),
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
          _JumpDialog(pageCount: state.pageCount, current: state.page),
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
                    constraints.maxWidth -
                        (EbookReaderPage.stageInset +
                                EbookReaderPage.sideGutter) *
                            2,
                    constraints.maxHeight -
                        EbookReaderPage.topBarHeight -
                        EbookReaderPage.bottomBarHeight -
                        (EbookReaderPage.stageInset +
                                EbookReaderPage.stagePadding) *
                            2,
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
                      _TopBar(
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
                      Expanded(child: _buildStage(state, spread)),
                      if (ready)
                        _BottomBar(
                          state: state,
                          spread: spread,
                          thumbs: _thumbs,
                          thumbWidth: _thumbWidth,
                          thumbGap: _thumbGap,
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
      bookmarks: state.bookmarks,
    );
    return LibraryCanvas(
      padding: const EdgeInsets.all(EbookReaderPage.stageInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_zoom) {
            return PhotoView.customChild(
              key: ValueKey<int>(spread.startOf(state.page)),
              childSize: constraints.biggest,
              backgroundDecoration: const BoxDecoration(
                color: LibraryPalette.canvas,
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
                  child: LibraryIconButton(
                    key: EbookReaderPage.previousKey,
                    icon: Icons.chevron_left_rounded,
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
                  child: LibraryIconButton(
                    key: EbookReaderPage.nextKey,
                    icon: Icons.chevron_right_rounded,
                    semanticLabel: '下一页',
                    onTap: spread.next(state.page) == null ? null : _next,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 顶部工具栏：返回、居中的书名、目录 / 书签 / 放大三个操作胶囊。
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.ready,
    required this.bookmarked,
    required this.zoom,
    required this.compact,
    required this.onBack,
    required this.onToc,
    required this.onBookmark,
    required this.onZoom,
  });

  final String title;
  final bool ready;
  final bool bookmarked;
  final bool zoom;
  final bool compact;
  final VoidCallback onBack;
  final VoidCallback onToc;
  final VoidCallback onBookmark;
  final VoidCallback onZoom;

  @override
  Widget build(BuildContext context) {
    return LibraryPreviewHeader(
      title: title.isEmpty ? '美术书刊' : title,
      onBack: onBack,
      actions: [
        if (ready) ...[
          LibraryActionPill(
            label: '目录',
            semanticLabel: '目录与书签',
            icon: Icons.format_list_bulleted_rounded,
            iconSize: 18,
            compact: compact,
            onTap: onToc,
          ),
          LibraryActionPill(
            label: bookmarked ? '已加书签' : '加书签',
            semanticLabel: bookmarked ? '删除本页书签' : '为本页加书签',
            icon: bookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            iconSize: 18,
            active: bookmarked,
            compact: compact,
            onTap: onBookmark,
          ),
          LibraryActionPill(
            label: zoom ? '退出放大' : '放大',
            semanticLabel: zoom ? '退出放大' : '放大查看',
            icon: zoom ? Icons.zoom_out_rounded : Icons.zoom_in_rounded,
            iconSize: 18,
            active: zoom,
            compact: compact,
            onTap: onZoom,
          ),
        ],
      ],
    );
  }
}

/// 一屏：单页或双页并排，中缝一条细线。
class _Spread extends StatelessWidget {
  const _Spread({
    required this.pages,
    required this.twoPage,
    required this.bookmarks,
  });

  final List<EbookPage> pages;
  final bool twoPage;
  final Set<int> bookmarks;

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
              Expanded(
                child: _PageImage(
                  page: left,
                  bookmarked: bookmarks.contains(left.page),
                ),
              ),
              if (twoPage) ...[
                const SizedBox(
                  width: 1,
                  child: ColoredBox(color: AppColors.lineSoft),
                ),
                Expanded(
                  child: right == null
                      ? const SizedBox.shrink()
                      : _PageImage(
                          page: right,
                          bookmarked: bookmarks.contains(right.page),
                        ),
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
  const _PageImage({required this.page, required this.bookmarked});

  final EbookPage page;
  final bool bookmarked;

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
          if (bookmarked)
            const Positioned(
              top: 0,
              right: 12,
              child: Icon(
                Icons.bookmark_rounded,
                size: 28,
                color: AppColors.brand,
              ),
            ),
        ],
      ),
    );
  }
}

/// 底栏：一排缩略图，下面是页码拖动条、页码徽标和「跳页」。
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.spread,
    required this.thumbs,
    required this.thumbWidth,
    required this.thumbGap,
    required this.onGoTo,
    required this.onJump,
  });

  final EbookReaderState state;
  final EbookSpread spread;
  final ScrollController thumbs;
  final double thumbWidth;
  final double thumbGap;
  final ValueChanged<int> onGoTo;
  final VoidCallback onJump;

  static const _thumbHeight = 66.0;

  @override
  Widget build(BuildContext context) {
    final visible = spread.pagesAt(state.page);
    return Container(
      height: EbookReaderPage.bottomBarHeight,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _thumbHeight,
            child: ListView.separated(
              controller: thumbs,
              scrollDirection: Axis.horizontal,
              itemCount: state.pageCount,
              separatorBuilder: (_, _) => SizedBox(width: thumbGap),
              itemBuilder: (context, index) {
                final page = state.pages[index];
                return _Thumb(
                  page: page,
                  width: thumbWidth,
                  height: _thumbHeight,
                  active: visible.contains(page.page),
                  bookmarked: state.isBookmarked(page.page),
                  onTap: () => onGoTo(page.page),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: LibraryActionPill.height,
            child: Row(
              children: [
                Expanded(
                  child: _PageScrubber(
                    pageCount: state.pageCount,
                    page: visible.last,
                    onChanged: onGoTo,
                    previous: spread.previous(state.page),
                    next: spread.next(state.page),
                  ),
                ),
                const SizedBox(width: 16),
                LibraryCounter(
                  spread.label(state.page),
                  textKey: EbookReaderPage.pageLabelKey,
                ),
                const SizedBox(width: 8),
                LibraryActionPill(label: '跳页', onTap: onJump),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 缩略图：1px 浅描边，右下角页码徽标；当前页盖一层浅色蒙版，徽标转为
/// 浅紫底品牌紫字（原版预览缩略图的当前页样式）。
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.page,
    required this.width,
    required this.height,
    required this.active,
    required this.bookmarked,
    required this.onTap,
  });

  final EbookPage page;
  final double width;
  final double height;
  final bool active;
  final bool bookmarked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(4));
    return AppPressable(
      onTap: onTap,
      selected: active,
      semanticLabel: '第 ${page.page} 页',
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: LibraryPalette.canvas,
                  borderRadius: radius,
                  border: Border.all(
                    color: active ? AppColors.brand : AppColors.lineSoft,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: AppImage(src: page.imageUrl, fit: BoxFit.cover),
                ),
              ),
              if (active) const ColoredBox(color: LibraryPalette.activeScrim),
              if (bookmarked)
                const Positioned(
                  top: 0,
                  left: 2,
                  child: Icon(
                    Icons.bookmark_rounded,
                    size: 14,
                    color: AppColors.brand,
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? LibraryPalette.activeBadge
                        : AppColors.surfaceSubtle,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    '${page.page}',
                    style: libraryText(
                      size: 12,
                      color: active ? AppColors.brand : AppColors.ink,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 页码拖动条：点按或拖动立即跳页，没有滑块动画。
class _PageScrubber extends StatelessWidget {
  const _PageScrubber({
    required this.pageCount,
    required this.page,
    required this.onChanged,
    required this.previous,
    required this.next,
  });

  final int pageCount;
  final int page;
  final ValueChanged<int> onChanged;
  final int? previous;
  final int? next;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int pageAt(double dx) {
          if (pageCount <= 1 || width <= 0) {
            return 1;
          }
          return 1 + ((dx / width).clamp(0.0, 1.0) * (pageCount - 1)).round();
        }

        final fraction = pageCount <= 1 ? 0.0 : (page - 1) / (pageCount - 1);
        final previous = this.previous;
        final next = this.next;
        String pageLabel(int page) => '第 $page 页，共 $pageCount 页';
        return Semantics(
          slider: true,
          label: '页码',
          value: pageLabel(page),
          decreasedValue: previous == null ? null : pageLabel(previous),
          increasedValue: next == null ? null : pageLabel(next),
          onDecrease: previous == null ? null : () => onChanged(previous),
          onIncrease: next == null ? null : () => onChanged(next),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => onChanged(pageAt(details.localPosition.dx)),
            onHorizontalDragUpdate: (details) =>
                onChanged(pageAt(details.localPosition.dx)),
            child: CustomPaint(
              size: Size(width, LibraryActionPill.height),
              painter: _ScrubberPainter(fraction: fraction.clamp(0.0, 1.0)),
            ),
          ),
        );
      },
    );
  }
}

/// 进度条的画法取自原版预览的进度条：4 高圆头轨道、浅紫到品牌紫的渐变、
/// 12 的品牌紫圆钮带 1px 白描边和轻投影。
class _ScrubberPainter extends CustomPainter {
  const _ScrubberPainter({required this.fraction});

  final double fraction;

  static const _thumb = 12.0;
  static const _track = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < _thumb) {
      return;
    }
    final y = size.height / 2;
    final x = _thumb / 2 + (size.width - _thumb) * fraction;
    const radius = Radius.circular(23);
    final track = RRect.fromLTRBR(
      0,
      y - _track / 2,
      size.width,
      y + _track / 2,
      radius,
    );
    canvas.drawRRect(track, Paint()..color = LibraryPalette.track);
    if (x > 0) {
      final fill = Rect.fromLTRB(0, y - _track / 2, x, y + _track / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill, radius),
        Paint()
          ..shader = const LinearGradient(
            colors: [LibraryPalette.trackStart, AppColors.brand],
          ).createShader(fill),
      );
    }
    final center = Offset(x, y);
    canvas
      ..drawCircle(
        center + const Offset(0, 4),
        _thumb / 2,
        Paint()
          ..color = const Color(0x1F000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawCircle(center, _thumb / 2, Paint()..color = AppColors.surface)
      ..drawCircle(center, _thumb / 2 - 1, Paint()..color = AppColors.brand);
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

/// 目录与书签抽屉；点条目返回要跳转的页码。
class _TocDrawer extends StatelessWidget {
  const _TocDrawer({required this.state, required this.visible});

  final EbookReaderState state;
  final List<int> visible;

  EbookTocEntry? _chapterOf(int page) {
    EbookTocEntry? match;
    for (final entry in state.toc) {
      if (entry.page <= page) {
        match = entry;
      }
    }
    return match;
  }

  @override
  Widget build(BuildContext context) {
    final current = _chapterOf(visible.last);
    final bookmarks = state.bookmarks.toList()..sort();
    final note = libraryText(
      size: 12,
      color: AppColors.textPlaceholder,
      height: 1.5,
    );
    return LibraryDrawer(
      title: '目录与书签',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LibrarySectionTitle('目录'),
          const SizedBox(height: 12),
          if (state.toc.isEmpty) Text('这本书刊没有目录。', style: note),
          for (final entry in state.toc)
            _DrawerRow(
              title: entry.title,
              trailing: '第 ${entry.page} 页',
              current: identical(entry, current),
              onTap: () => Navigator.of(context).pop(entry.page),
            ),
          const SizedBox(height: 12),
          const LibrarySectionTitle('书签'),
          const SizedBox(height: 12),
          if (bookmarks.isEmpty)
            Text('还没有书签。阅读时点右上角的「加书签」，可以标记当前页。', style: note),
          for (final page in bookmarks)
            _DrawerRow(
              title: '第 $page 页',
              subtitle: _chapterOf(page)?.title,
              bookmark: true,
              onTap: () => Navigator.of(context).pop(page),
            ),
        ],
      ),
    );
  }
}

/// 抽屉里的一行：浅灰底圆角 12，在读的章节换成浅紫底并带「在读」标签。
class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.current = false,
    this.bookmark = false,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final bool current;
  final bool bookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    final tail = trailing;
    final muted = libraryText(size: 12, color: AppColors.textPlaceholder);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppPressable(
        onTap: onTap,
        selected: current,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: current ? LibraryPalette.lilac : AppColors.surfaceSubtle,
            borderRadius: AppRadius.br12,
          ),
          child: Row(
            children: [
              if (bookmark) ...[
                const Icon(
                  Icons.bookmark_rounded,
                  size: 18,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: libraryText(
                        size: 14,
                        weight: AppFont.w500,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ],
                  ],
                ),
              ),
              if (current) ...[
                const SizedBox(width: 8),
                LibraryTag.brand('在读'),
              ],
              if (tail != null) ...[
                const SizedBox(width: 8),
                Text(tail, style: muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JumpDialog extends StatefulWidget {
  const _JumpDialog({required this.pageCount, required this.current});

  final int pageCount;
  final int current;

  @override
  State<_JumpDialog> createState() => _JumpDialogState();
}

class _JumpDialogState extends State<_JumpDialog> {
  late final TextEditingController _input = TextEditingController(
    text: '${widget.current}',
  );
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final page = int.tryParse(_input.text.trim());
    if (page == null || page < 1 || page > widget.pageCount) {
      setState(() => _error = '请输入 1–${widget.pageCount} 之间的页码');
      return;
    }
    Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final textStyle = libraryText(
      size: 14,
      color: AppColors.ink,
      height: 20 / 14,
    );
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: AppRadius.br8,
      borderSide: BorderSide(color: color),
    );
    return AppDialog(
      title: '跳到指定页',
      message: '共 ${widget.pageCount} 页',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: '跳转', onTap: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 输入框沿用原版输入弹窗：48 高、圆角 8、1px 浅描边。
          SizedBox(
            height: 48,
            child: AppTextField(
              controller: _input,
              autofocus: true,
              maxLines: 1,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _submit(),
              textAlignVertical: TextAlignVertical.center,
              cursorColor: AppColors.brand,
              cursorWidth: 1.5,
              cursorHeight: 16,
              style: textStyle,
              decoration: InputDecoration(
                hintText: '输入 1–${widget.pageCount}',
                hintStyle: textStyle.copyWith(color: AppColors.textPlaceholder),
                hintFadeDuration: Duration.zero,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                filled: true,
                fillColor: AppColors.surface,
                enabledBorder: border(
                  error == null ? AppColors.surfaceSubtle : AppColors.danger,
                ),
                focusedBorder: border(
                  error == null ? AppColors.brandTint : AppColors.danger,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: libraryText(size: 12, color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}
