import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_compare_controller.dart';
import 'app_compare_divider.dart';
import 'app_compare_zoom_box.dart';
import 'app_pressable.dart';
import 'app_text.dart';

/// [AppCompareView] 的一侧：名称和一张图。
class AppComparePane {
  /// 一张图。[child] 铺满按原比例算好的画框（用 `BoxFit.contain` 或 `fill` 画）。
  /// 比例用 [aspectRatio]（宽 / 高）；不知道时给 [image]，读出图片尺寸再排。
  /// [overlay] 盖在画框上、不随缩放移动（例如原卷水印），不拦截手势。
  const AppComparePane({
    required this.label,
    required this.child,
    this.aspectRatio,
    this.image,
    this.overlay,
  }) : placeholder = false;

  /// 还没有图（加载中、出错、没有原卷）：[child] 铺满这一侧，不能缩放。
  const AppComparePane.placeholder({required this.label, required this.child})
    : aspectRatio = null,
      image = null,
      overlay = null,
      placeholder = true;

  final String label;
  final Widget child;
  final double? aspectRatio;
  final ImageProvider? image;
  final Widget? overlay;
  final bool placeholder;
}

/// 两张画的对比画布（设计语言第九节）：并排、滑动（卷帘）、叠加三种看法，
/// 状态都在 [controller] 里。
///
/// - 并排时两张画按同样的高度显示，大小可比；分隔条拖动、双击复位到两张都最大
///   的位置。名称写在画的正上方一行，不压在画上。
/// - 锁定时缩放、拖动一侧，另一侧放大同样的倍数、看同一个位置（按画面的比例
///   对齐，两张图大小、比例不同也成立）；不锁定时各自缩放，名称加粗的一侧是旋转、
///   翻转的对象，点名称或摸一下画面切换。
/// - 滑动和叠加时两张画在同一个画框里一起缩放。
/// - 键盘：L 锁定、R 旋转、H 左右翻转、V 上下翻转、S 交换、0 复位。
///
/// 只负责画布本身。画布下面那一行（提示和操作）用 [AppCompareFooter]，模式切换
/// 放在页头。
class AppCompareView extends StatefulWidget {
  const AppCompareView({
    required this.controller,
    required this.first,
    required this.second,
    this.dark = false,
    this.autofocus = false,
    super.key,
  });

  final AppCompareController controller;

  /// 第一张（不交换时在左边；叠加时在下层）。
  final AppComparePane first;
  final AppComparePane second;

  /// 画布是深色（`AppColors.canvasDark`）：名称用浅色字。
  final bool dark;

  /// 打开时就接收键盘快捷键。沉浸的对比页用 true；画布旁边有输入控件时用 false。
  final bool autofocus;

  /// 名称那一行的高度：文字贴着画，上面留出点击区域。
  static const double labelHeight = 44;

  /// 比例未知时的占位比例。
  static const double fallbackRatio = 3 / 4;

  @override
  State<AppCompareView> createState() => _AppCompareViewState();
}

class _AppCompareViewState extends State<AppCompareView> {
  final Map<ImageProvider, double> _ratios = {};
  final Map<ImageProvider, (ImageStream, ImageStreamListener)> _pending = {};

  AppCompareController get _c => widget.controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveRatios();
  }

  @override
  void didUpdateWidget(AppCompareView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveRatios();
  }

  @override
  void dispose() {
    for (final (stream, listener) in _pending.values) {
      stream.removeListener(listener);
    }
    _pending.clear();
    super.dispose();
  }

  void _resolveRatios() {
    for (final pane in [widget.first, widget.second]) {
      final provider = pane.image;
      if (pane.aspectRatio != null ||
          provider == null ||
          _ratios.containsKey(provider) ||
          _pending.containsKey(provider)) {
        continue;
      }
      final stream = provider.resolve(createLocalImageConfiguration(context));
      late final ImageStreamListener listener;
      void done() {
        stream.removeListener(listener);
        _pending.remove(provider);
      }

      listener = ImageStreamListener(
        (info, _) {
          final ratio = info.image.width / info.image.height;
          info.dispose();
          done();
          if (mounted && ratio > 0) {
            setState(() => _ratios[provider] = ratio);
          }
        },
        onError: (_, _) => done(),
      );
      _pending[provider] = (stream, listener);
      stream.addListener(listener);
    }
  }

  AppComparePane _pane(int index) => index == 0 ? widget.first : widget.second;

  double? _knownRatio(AppComparePane pane) {
    if (pane.placeholder) {
      return null;
    }
    final ratio = pane.aspectRatio ?? _ratios[pane.image];
    return ratio != null && ratio > 0 ? ratio : null;
  }

  /// 显示出来的宽高比（算上旋转）；不知道时借另一张的比例。
  double _ratio(int index) {
    final base =
        _knownRatio(_pane(index)) ??
        _knownRatio(_pane(1 - index)) ??
        AppCompareView.fallbackRatio;
    return _c.side(index).displayRatio(base);
  }

  List<int> get _order => _c.swapped ? const [1, 0] : const [0, 1];

  Color get _background => widget.dark ? AppColors.canvasDark : AppColors.canvas;

  @override
  Widget build(BuildContext context) {
    final c = _c;
    void when(bool enabled, VoidCallback action) {
      if (enabled) {
        action();
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyL): c.toggleLock,
        const SingleActivator(LogicalKeyboardKey.keyR): () =>
            when(c.canRotate, c.rotate),
        const SingleActivator(LogicalKeyboardKey.keyH): () =>
            when(c.canFlip, c.flipHorizontal),
        const SingleActivator(LogicalKeyboardKey.keyV): () =>
            when(c.canFlip, c.flipVertical),
        const SingleActivator(LogicalKeyboardKey.keyS): () =>
            when(c.canSwap, c.swap),
        const SingleActivator(LogicalKeyboardKey.digit0): c.reset,
      },
      child: Focus(
        autofocus: widget.autofocus,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final area = constraints.biggest;
              return c.framed ? _framed(area) : _sideBySide(area);
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── 并排 ───────────────────────────

  /// 两张画按同一高度放下时左右宽度之比，就是让两张画都最大的分隔位置。
  double _balancedSplit(double width) {
    final order = _order;
    if (width <= 0 || _pane(0).placeholder || _pane(1).placeholder) {
      return 0.5;
    }
    const gap = AppCompareDivider.extent;
    final left = _ratio(order[0]);
    final right = _ratio(order[1]);
    final leftWidth = (width - gap) * left / (left + right);
    return ((leftWidth + gap / 2) / width)
        .clamp(AppCompareDivider.min, AppCompareDivider.max)
        .toDouble();
  }

  Widget _sideBySide(Size area) {
    const gap = AppCompareDivider.extent;
    final order = _order;
    final split = _c.split ?? _balancedSplit(area.width);
    final splitX = area.width * split;
    final widths = [
      math.max(0.0, splitX - gap / 2),
      math.max(0.0, area.width - splitX - gap / 2),
    ];
    // 两张画取同一个高度：都要完整放进各自那一侧。
    var height = area.height - AppCompareView.labelHeight;
    for (var slot = 0; slot < 2; slot++) {
      if (!_pane(order[slot]).placeholder) {
        height = math.min(height, widths[slot] / _ratio(order[slot]));
      }
    }
    height = math.max(0, height);
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widths[0],
          child: _slot(order[0], widths[0], height),
        ),
        Positioned(
          left: splitX + gap / 2,
          top: 0,
          bottom: 0,
          width: widths[1],
          child: _slot(order[1], widths[1], height),
        ),
        Positioned(
          left: splitX - gap / 2,
          top: 0,
          bottom: 0,
          width: gap,
          child: AppCompareDivider(
            value: split,
            onDrag: (dx) {
              if (area.width > 0) {
                _c.setSplit(split + dx / area.width);
              }
            },
            onChanged: _c.setSplit,
            onReset: () => _c.setSplit(null),
          ),
        ),
      ],
    );
  }

  Widget _slot(int index, double width, double height) {
    final pane = _pane(index);
    if (pane.placeholder) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(index),
          Expanded(child: pane.child),
        ],
      );
    }
    final size = Size(math.min(width, height * _ratio(index)), height);
    final inset = (width - size.width) / 2;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: inset),
            child: SizedBox(width: width - inset, child: _label(index)),
          ),
          Padding(
            padding: EdgeInsets.only(left: inset),
            child: SizedBox.fromSize(
              size: size,
              child: Stack(
                children: [
                  AppCompareZoomBox(
                    size: size,
                    zoom: _c.side(index).zoom,
                    onZoom: (zoom) => _c.setSideZoom(index, zoom),
                    onTouch: () => _c.setActiveSide(index),
                    child: _content(index),
                  ),
                  if (pane.overlay != null)
                    Positioned.fill(child: IgnorePointer(child: pane.overlay)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 滑动 / 叠加 ───────────────────────────

  Widget _framed(Size area) {
    final order = _order;
    final ratios = [
      for (final index in order)
        if (!_pane(index).placeholder) _ratio(index),
    ];
    final ratio = ratios.isEmpty ? AppCompareView.fallbackRatio : ratios.reduce(math.max);
    final maxHeight = math.max(0.0, area.height - AppCompareView.labelHeight);
    var frameWidth = area.width;
    var frameHeight = frameWidth / ratio;
    if (frameHeight > maxHeight) {
      frameHeight = maxHeight;
      frameWidth = frameHeight * ratio;
    }
    final frame = Size(frameWidth, frameHeight);
    final reveal = _c.mode == AppCompareMode.reveal;
    final x = frameWidth * _c.revealSplit;
    final zoom = _c.frameZoom;
    // 卷帘的分界在屏幕上不动；换算到缩放后的画面里去裁上层。
    final clipX = zoom.fractionAt(Offset(x, 0), frame).dx * frameWidth;

    final Widget layers;
    if (reveal) {
      layers = Stack(
        children: [
          Positioned.fill(child: _layer(order[1], frame)),
          Positioned.fill(
            child: ClipRect(
              clipper: _LeftClipper(clipX),
              child: ColoredBox(
                color: _background,
                child: _layer(order[0], frame),
              ),
            ),
          ),
        ],
      );
    } else {
      layers = Stack(
        children: [
          Positioned.fill(child: _layer(order[0], frame)),
          Positioned.fill(
            child: Opacity(
              opacity: _c.overlayOpacity,
              child: _layer(order[1], frame),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: frameWidth,
            height: AppCompareView.labelHeight,
            child: Row(
              children: [
                Expanded(child: _label(order[0])),
                const SizedBox(width: 16),
                Expanded(
                  child: _label(order[1], alignEnd: true, top: !reveal),
                ),
              ],
            ),
          ),
          SizedBox.fromSize(
            size: frame,
            child: Stack(
              children: [
                AppCompareZoomBox(
                  size: frame,
                  zoom: zoom,
                  onZoom: _c.setFrameZoom,
                  child: layers,
                ),
                for (final index in order)
                  if (_pane(index).overlay != null)
                    Positioned.fill(
                      child: IgnorePointer(child: _pane(index).overlay),
                    ),
                if (reveal)
                  Positioned(
                    left: x - AppCompareDivider.extent / 2,
                    top: 0,
                    bottom: 0,
                    width: AppCompareDivider.extent,
                    child: AppCompareDivider(
                      value: _c.revealSplit,
                      onDrag: (dx) {
                        if (frameWidth > 0) {
                          _c.setRevealSplit(_c.revealSplit + dx / frameWidth);
                        }
                      },
                      onChanged: _c.setRevealSplit,
                      onReset: () => _c.setRevealSplit(0.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 画框里的一层：按自己的比例完整放进画框，居中。
  Widget _layer(int index, Size frame) {
    final pane = _pane(index);
    if (pane.placeholder) {
      return pane.child;
    }
    final ratio = _ratio(index);
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(ratio, 1),
      frame,
    ).destination;
    return Center(
      child: SizedBox.fromSize(size: fitted, child: _content(index)),
    );
  }

  // ─────────────────────────── 共用 ───────────────────────────

  /// 一侧的画面：先旋转、再翻转，灰度时去色。
  Widget _content(int index) {
    final side = _c.side(index);
    Widget child = SizedBox.expand(child: _pane(index).child);
    if (side.quarterTurns != 0) {
      child = RotatedBox(quarterTurns: side.quarterTurns, child: child);
    }
    if (side.flipX || side.flipY) {
      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          side.flipX ? -1 : 1,
          side.flipY ? -1 : 1,
          1,
        ),
        child: child,
      );
    }
    if (_c.grayscale) {
      child = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayMatrix),
        child: child,
      );
    }
    return child;
  }

  Widget _label(int index, {bool alignEnd = false, bool top = false}) {
    final pane = _pane(index);
    final text = top ? '${pane.label} · 上层' : pane.label;
    final unlocked = !_c.locked;
    final active = _c.activeSide == index;
    final strong = widget.dark ? AppColors.onBrand : AppColors.ink;
    final muted = widget.dark
        ? AppColors.onBrand.withValues(alpha: 0.64)
        : AppColors.textSecondary;
    final style = unlocked
        ? (active
              ? AppText.body14Strong.copyWith(color: strong)
              : AppText.body14.copyWith(color: muted))
        : AppText.body14.copyWith(color: strong);
    final label = SizedBox(
      height: AppCompareView.labelHeight,
      child: Align(
        alignment: alignEnd ? Alignment.bottomRight : Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: style,
          ),
        ),
      ),
    );
    if (!unlocked) {
      return label;
    }
    return AppPressable(
      onTap: () => _c.setActiveSide(index),
      selected: active,
      semanticLabel: '选中$text',
      child: ExcludeSemantics(child: label),
    );
  }
}

const _grayMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
];

class _LeftClipper extends CustomClipper<Rect> {
  const _LeftClipper(this.width);

  final double width;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, width.clamp(0.0, size.width), size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) =>
      oldClipper.width != width;
}
