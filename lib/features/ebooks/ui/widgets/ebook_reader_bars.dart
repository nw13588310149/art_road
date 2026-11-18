import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/ebook_models.dart';
import '../../state/ebook_reader_controller.dart';
import '../../state/ebook_spread.dart';

/// 阅读器顶栏：白底、高 64、左右留 24，里面是带返回的页头，下面一条细线。
///
/// 右边是目录、书签、放大三个次要操作；阅读器没有主按钮，整屏不用品牌紫。
/// 窄屏只留图标（带读屏名称和悬停提示）。
class EbookReaderTopBar extends StatelessWidget {
  const EbookReaderTopBar({
    required this.title,
    required this.ready,
    required this.bookmarked,
    required this.zoom,
    required this.compact,
    required this.onBack,
    required this.onToc,
    required this.onBookmark,
    required this.onZoom,
    super.key,
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

  static const double barHeight = 64;

  /// 连同下面那条细线的高度。
  static const double height = barHeight + 1;

  @override
  Widget build(BuildContext context) {
    Widget action(
      String label,
      IconData icon,
      VoidCallback onTap, {
      String? spoken,
    }) => compact
        ? AppIconAction(
            icon: icon,
            semanticLabel: spoken ?? label,
            color: AppColors.ink,
            onTap: onTap,
          )
        : AppPlainButton(
            label: label,
            icon: icon,
            onTap: onTap,
            semanticLabel: spoken,
          );
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: barHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
              child: Center(
                child: AppTitleBar(
                  title: title.isEmpty ? '电子书刊' : title,
                  onBack: onBack,
                  actions: [
                    if (ready) ...[
                      action(
                        '目录',
                        Icons.format_list_bulleted_rounded,
                        onToc,
                        spoken: '目录与书签',
                      ),
                      action(
                        bookmarked ? '已加书签' : '加书签',
                        bookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        onBookmark,
                      ),
                      action(
                        zoom ? '退出放大' : '放大',
                        zoom ? Icons.zoom_out_rounded : Icons.zoom_in_rounded,
                        onZoom,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const AppRule(),
        ],
      ),
    );
  }
}

/// 阅读器底栏：一排缩略图（页码写在图下面），下面是页码拖动条、当前页码和「跳页」。
class EbookReaderBottomBar extends StatelessWidget {
  const EbookReaderBottomBar({
    required this.state,
    required this.spread,
    required this.thumbs,
    required this.onGoTo,
    required this.onJump,
    this.pageLabelKey,
    super.key,
  });

  final EbookReaderState state;
  final EbookSpread spread;
  final ScrollController thumbs;
  final ValueChanged<int> onGoTo;
  final VoidCallback onJump;
  final Key? pageLabelKey;

  /// 一张缩略图的点击区域宽度；看得见的页面宽 [_thumbImageWidth]，两边各留 4。
  static const double thumbWidth = 48;
  static const double _thumbImageWidth = 40;
  static const double _thumbInset = (thumbWidth - _thumbImageWidth) / 2;
  static const double _thumbHeight = 53;
  static const double _thumbExtent = _thumbHeight + 4 + 18;
  static const double _top = AppSpace.s12;
  static const double _bottom = AppSpace.s4;

  /// 细线、上下留白、缩略图一行和拖动条一行。
  static const double height = 1 + _top + _thumbExtent + 44 + _bottom;

  @override
  Widget build(BuildContext context) {
    final visible = spread.pagesAt(state.page);
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppRule(),
          // 缩略图的点击区域比图宽 8，左右少留 4，图和下面的拖动条对齐。
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s24 - _thumbInset,
              _top,
              AppSpace.s24 - _thumbInset,
              _bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _thumbExtent,
                  child: ListView.builder(
                    controller: thumbs,
                    scrollDirection: Axis.horizontal,
                    itemExtent: thumbWidth,
                    itemCount: state.pageCount,
                    itemBuilder: (context, index) {
                      final page = state.pages[index];
                      return _Thumb(
                        page: page,
                        active: visible.contains(page.page),
                        bookmarked: state.isBookmarked(page.page),
                        onTap: () => onGoTo(page.page),
                      );
                    },
                  ),
                ),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: _thumbInset),
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
                      const SizedBox(width: AppSpace.s16),
                      Text(
                        spread.label(state.page),
                        key: pageLabelKey,
                        style: AppText.number(size: 14),
                      ),
                      const SizedBox(width: AppSpace.s4),
                      Transform.translate(
                        offset: const Offset(AppSpace.s12, 0),
                        child: AppPlainButton(label: '跳页', onTap: onJump),
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
  }
}

/// 缩略图：细描边，当前页换成 2 像素的墨色描边；页码和书签写在图下面。
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.page,
    required this.active,
    required this.bookmarked,
    required this.onTap,
  });

  final EbookPage page;
  final bool active;
  final bool bookmarked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(3));
    return AppPressable(
      onTap: onTap,
      selected: active,
      semanticLabel: bookmarked
          ? '第 ${page.page} 页，有书签'
          : '第 ${page.page} 页',
      child: ExcludeSemantics(
        child: SizedBox(
          width: EbookReaderBottomBar.thumbWidth,
          child: Column(
            children: [
              Container(
                width: EbookReaderBottomBar._thumbImageWidth,
                height: EbookReaderBottomBar._thumbHeight,
                foregroundDecoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: active ? AppColors.ink : AppColors.lineSoft,
                    width: active ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: AppImage(src: page.imageUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (bookmarked) ...[
                    const Icon(
                      Icons.bookmark_rounded,
                      size: 12,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    '${page.page}',
                    style: AppText.number(
                      size: 12,
                      color: active ? AppColors.ink : AppColors.textTertiary,
                    ),
                  ),
                ],
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
              size: Size(width, 44),
              painter: _ScrubberPainter(fraction: fraction.clamp(0.0, 1.0)),
            ),
          ),
        );
      },
    );
  }
}

/// 中性色的进度条：浅灰轨道、二级文字色的已读部分、墨色圆钮带白描边。
class _ScrubberPainter extends CustomPainter {
  const _ScrubberPainter({required this.fraction});

  final double fraction;

  static const _knob = 14.0;
  static const _track = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < _knob) {
      return;
    }
    final y = size.height / 2;
    final x = _knob / 2 + (size.width - _knob) * fraction;
    const radius = Radius.circular(_track / 2);
    canvas
      ..drawRRect(
        RRect.fromLTRBR(0, y - _track / 2, size.width, y + _track / 2, radius),
        Paint()..color = AppColors.line,
      )
      ..drawRRect(
        RRect.fromLTRBR(0, y - _track / 2, x, y + _track / 2, radius),
        Paint()..color = AppColors.textSecondary,
      )
      ..drawCircle(Offset(x, y), _knob / 2, Paint()..color = AppColors.surface)
      ..drawCircle(Offset(x, y), _knob / 2 - 2, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
