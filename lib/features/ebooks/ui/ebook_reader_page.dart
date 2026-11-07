import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/ui/ui.dart';
import '../data/ebook_models.dart';
import '../state/ebook_reader_controller.dart';
import '../state/ebook_spread.dart';

/// 全屏阅读器：宽屏双页并排、窄屏单页；点左右半屏、两侧箭头、左右滑动或方向键翻页，
/// 翻页即时切换。底部缩略图与页码拖动条，支持跳页、目录、书签与放大查看，进度自动保存。
class EbookReaderPage extends ConsumerStatefulWidget {
  const EbookReaderPage({required this.bookId, this.initialPage = 0, super.key});

  final String bookId;

  /// 打开时跳到的页码；0 表示从上次的进度继续。
  final int initialPage;

  static const routeName = '/ebooks/reader';
  static const previousKey = ValueKey<String>('ebook-reader-previous');
  static const nextKey = ValueKey<String>('ebook-reader-next');
  static const stageKey = ValueKey<String>('ebook-reader-stage');
  static const pageLabelKey = ValueKey<String>('ebook-reader-page-label');

  static const topBarHeight = 56.0;
  static const bottomBarHeight = 146.0;
  static const sideGutter = 72.0;
  static const stagePadding = 16.0;

  /// 全屏阅读路由（不经过外壳、没有转场动画）；关闭时返回最新的阅读进度。
  static Route<EbookProgress> route({required String bookId, int initialPage = 0}) {
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
  static const _thumbGap = AppSpace.s8;

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
    final target = ((page - 1) * extent - (position.viewportDimension - extent) / 2)
        .clamp(0.0, position.maxScrollExtent);
    if ((position.pixels - target).abs() > 1) {
      _thumbs.jumpTo(target);
    }
  }

  Future<void> _openToc(EbookReaderState state) async {
    final visible = _spread?.pagesAt(state.page) ?? <int>[state.page];
    final page = await showAppDrawer<int>(
      context: context,
      builder: (_) => _TocDrawer(state: state, visible: visible),
    );
    if (page != null && mounted) {
      _goTo(page);
    }
  }

  Future<void> _toggleBookmark(int page) async {
    final had = ref.read(ebookReaderControllerProvider(_args)).isBookmarked(page);
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
      builder: (_) => _JumpDialog(pageCount: state.pageCount, current: state.page),
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
            color: AppColors.page,
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
                  final spread = EbookSpread.fit(pageCount: state.pageCount, area: area);
                  _spread = spread;
                  final ready =
                      !state.loading && state.errorMessage.isEmpty && state.pageCount > 0;
                  final bookmarked = state.isBookmarked(spread.startOf(state.page));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        title: state.title,
                        ready: ready,
                        bookmarked: bookmarked,
                        zoom: _zoom,
                        onBack: () => unawaited(_close()),
                        onToc: () => unawaited(_openToc(state)),
                        onBookmark: () =>
                            unawaited(_toggleBookmark(spread.startOf(state.page))),
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
      pages: [for (final page in spread.pagesAt(state.page)) state.pageAt(page)!],
      twoPage: spread.twoPage,
      bookmarks: state.bookmarks,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_zoom) {
          return PhotoView.customChild(
            key: ValueKey<int>(spread.startOf(state.page)),
            childSize: constraints.biggest,
            backgroundDecoration: const BoxDecoration(color: AppColors.page),
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
                onTapUp: (details) =>
                    details.localPosition.dx < width / 2 ? _previous() : _next(),
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
              left: AppSpace.s16,
              top: 0,
              bottom: 0,
              child: Center(
                child: AppIconButton(
                  key: EbookReaderPage.previousKey,
                  icon: Icons.chevron_left_rounded,
                  semanticLabel: '上一页',
                  onTap: spread.previous(state.page) == null ? null : _previous,
                ),
              ),
            ),
            Positioned(
              right: AppSpace.s16,
              top: 0,
              bottom: 0,
              child: Center(
                child: AppIconButton(
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
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.ready,
    required this.bookmarked,
    required this.zoom,
    required this.onBack,
    required this.onToc,
    required this.onBookmark,
    required this.onZoom,
  });

  final String title;
  final bool ready;
  final bool bookmarked;
  final bool zoom;
  final VoidCallback onBack;
  final VoidCallback onToc;
  final VoidCallback onBookmark;
  final VoidCallback onZoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: EbookReaderPage.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            semanticLabel: '返回',
            filled: false,
            onTap: onBack,
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? '美术书刊' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
                Text('示例书刊 · 仅供演示', maxLines: 1, style: AppText.caption12),
              ],
            ),
          ),
          if (ready) ...[
            AppIconButton(
              icon: Icons.format_list_bulleted_rounded,
              semanticLabel: '目录与书签',
              onTap: onToc,
            ),
            const SizedBox(width: AppSpace.s8),
            AppIconButton(
              icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: bookmarked ? AppColors.brand : AppColors.ink,
              semanticLabel: bookmarked ? '删除本页书签' : '为本页加书签',
              onTap: onBookmark,
            ),
            const SizedBox(width: AppSpace.s8),
            AppIconButton(
              icon: zoom ? Icons.zoom_out_rounded : Icons.zoom_in_rounded,
              color: zoom ? AppColors.brand : AppColors.ink,
              semanticLabel: zoom ? '退出放大' : '放大查看',
              onTap: onZoom,
            ),
          ],
        ],
      ),
    );
  }
}

/// 一屏：单页或双页并排，中缝一条细线。
class _Spread extends StatelessWidget {
  const _Spread({required this.pages, required this.twoPage, required this.bookmarks});

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
                child: _PageImage(page: left, bookmarked: bookmarks.contains(left.page)),
              ),
              if (twoPage) ...[
                const SizedBox(width: 1, child: ColoredBox(color: AppColors.lineSoft)),
                Expanded(
                  child: right == null
                      ? const SizedBox.shrink()
                      : _PageImage(page: right, bookmarked: bookmarks.contains(right.page)),
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
              right: AppSpace.s12,
              child: Icon(Icons.bookmark_rounded, size: 28, color: AppColors.brand),
            ),
        ],
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final visible = spread.pagesAt(state.page);
    return Container(
      height: EbookReaderPage.bottomBarHeight,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s16,
        AppSpace.s8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 86,
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
                  active: visible.contains(page.page),
                  bookmarked: state.isBookmarked(page.page),
                  onTap: () => onGoTo(page.page),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          SizedBox(
            height: AppSize.buttonSm,
            child: Row(
              children: [
                Expanded(
                  child: _PageScrubber(
                    pageCount: state.pageCount,
                    page: visible.last,
                    onChanged: onGoTo,
                  ),
                ),
                const SizedBox(width: AppSpace.s16),
                Text(
                  spread.label(state.page),
                  key: EbookReaderPage.pageLabelKey,
                  style: AppText.number(size: 14),
                ),
                const SizedBox(width: AppSpace.s8),
                AppButton(
                  label: '跳页',
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.sm,
                  onTap: onJump,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.page,
    required this.width,
    required this.active,
    required this.bookmarked,
    required this.onTap,
  });

  final EbookPage page;
  final double width;
  final bool active;
  final bool bookmarked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: active,
      semanticLabel: '第 ${page.page} 页',
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              height: width / page.aspectRatio,
              decoration: BoxDecoration(
                borderRadius: AppRadius.br4,
                border: Border.all(
                  color: active ? AppColors.brand : AppColors.lineSoft,
                  width: active ? 2 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                    child: AppImage(src: page.imageUrl),
                  ),
                  if (bookmarked)
                    const Positioned(
                      top: 0,
                      right: 2,
                      child: Icon(Icons.bookmark_rounded, size: 14, color: AppColors.brand),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              '${page.page}',
              style: AppText.number(
                size: 12,
                color: active ? AppColors.brand : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 页码拖动条：点按或拖动立即跳页，没有滑块动画。
class _PageScrubber extends StatelessWidget {
  const _PageScrubber({required this.pageCount, required this.page, required this.onChanged});

  final int pageCount;
  final int page;
  final ValueChanged<int> onChanged;

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
        return Semantics(
          slider: true,
          label: '页码',
          value: '第 $page 页，共 $pageCount 页',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => onChanged(pageAt(details.localPosition.dx)),
            onHorizontalDragUpdate: (details) => onChanged(pageAt(details.localPosition.dx)),
            child: CustomPaint(
              size: Size(width, AppSize.buttonSm),
              painter: _ScrubberPainter(fraction: fraction.clamp(0.0, 1.0)),
            ),
          ),
        );
      },
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  const _ScrubberPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const thumb = 8.0;
    final y = size.height / 2;
    final left = thumb;
    final right = size.width - thumb;
    final x = left + (right - left) * fraction;
    final track = RRect.fromLTRBR(left, y - 2, right, y + 2, const Radius.circular(2));
    canvas.drawRRect(track, Paint()..color = AppColors.line);
    canvas.drawRRect(
      RRect.fromLTRBR(left, y - 2, x, y + 2, const Radius.circular(2)),
      Paint()..color = AppColors.brand,
    );
    canvas.drawCircle(Offset(x, y), thumb, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      Offset(x, y),
      thumb - 1,
      Paint()
        ..color = AppColors.brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter oldDelegate) => oldDelegate.fraction != fraction;
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
    return AppDrawer(
      title: '目录',
      subtitle: state.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.toc.isEmpty) Text('这本书刊没有目录。', style: AppText.body13),
          for (final entry in state.toc)
            AppListRow(
              title: entry.title,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
              divider: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (identical(entry, current)) ...[
                    const AppStatusTag(label: '在读', tone: AppTone.brand),
                    const SizedBox(width: AppSpace.s8),
                  ],
                  Text('第 ${entry.page} 页', style: AppText.caption12),
                ],
              ),
              onTap: () => Navigator.of(context).pop(entry.page),
            ),
          const SizedBox(height: AppSpace.s24),
          Text('书签', style: AppText.title16),
          const SizedBox(height: AppSpace.s8),
          if (bookmarks.isEmpty)
            Text('还没有书签。阅读时点右上角的书签按钮，可以标记当前页。', style: AppText.body13),
          for (final page in bookmarks)
            AppListRow(
              title: '第 $page 页',
              subtitle: _chapterOf(page)?.title,
              leading: const Icon(Icons.bookmark_rounded, size: 18, color: AppColors.brand),
              chevron: true,
              divider: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
              onTap: () => Navigator.of(context).pop(page),
            ),
        ],
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
  late final TextEditingController _input = TextEditingController(text: '${widget.current}');
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
      child: AppInputField(
        controller: _input,
        hint: '输入 1–${widget.pageCount}',
        errorText: _error,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
