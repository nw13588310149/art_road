import 'package:flutter/widgets.dart';

/// [AppCompareView] 的三种看法。
enum AppCompareMode {
  /// 两张图同样高度左右并排。
  sideBySide('并排'),

  /// 卷帘：两张图叠在同一个画框里，分隔条左边是第一张、右边是第二张。
  reveal('滑动'),

  /// 叠加：第二张半透明地盖在第一张上，滑条调上层的不透明度。
  overlay('叠加');

  const AppCompareMode(this.label);

  final String label;
}

/// 一侧画面的缩放：[scale] 是相对完整显示时的倍数（不小于 1），[center] 是画框
/// 正中对着的那一点，按画面宽高的比例记（0–1）。
///
/// 用比例而不是像素记，两张大小、比例不同的画才能对上：锁定时两侧放大同样的倍数，
/// 看的是各自画面上同一个位置。
@immutable
class AppCompareZoom {
  const AppCompareZoom({this.scale = 1, this.center = const Offset(0.5, 0.5)});

  static const identity = AppCompareZoom();

  final double scale;
  final Offset center;

  bool get isIdentity => (scale - 1).abs() < 0.001;

  /// 倍数限制在 1–[AppCompareController.maxScale]，并且画面始终铺满画框。
  AppCompareZoom clamped() {
    final s = scale.clamp(1.0, AppCompareController.maxScale).toDouble();
    final half = 0.5 / s;
    return AppCompareZoom(
      scale: s,
      center: Offset(
        center.dx.clamp(half, 1 - half).toDouble(),
        center.dy.clamp(half, 1 - half).toDouble(),
      ),
    );
  }

  /// 画框大小为 [viewport] 时的变换矩阵（`InteractiveViewer` 用的那种）。
  Matrix4 toMatrix(Size viewport) {
    final s = scale;
    return Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, viewport.width / 2 - s * center.dx * viewport.width)
      ..setEntry(1, 3, viewport.height / 2 - s * center.dy * viewport.height);
  }

  static AppCompareZoom fromMatrix(Matrix4 matrix, Size viewport) {
    final s = matrix.entry(0, 0);
    if (s <= 0 || viewport.isEmpty) {
      return identity;
    }
    return AppCompareZoom(
      scale: s,
      center: Offset(
        (viewport.width / 2 - matrix.entry(0, 3)) / (s * viewport.width),
        (viewport.height / 2 - matrix.entry(1, 3)) / (s * viewport.height),
      ),
    );
  }

  /// 画框里的一点（[viewport] 坐标）在画面上的比例位置。
  Offset fractionAt(Offset point, Size viewport) => Offset(
    center.dx + (point.dx - viewport.width / 2) / (scale * viewport.width),
    center.dy + (point.dy - viewport.height / 2) / (scale * viewport.height),
  );

  bool closeTo(AppCompareZoom other) =>
      (scale - other.scale).abs() < 1e-4 &&
      (center - other.center).distance < 1e-4;

  AppCompareZoom _map(Offset Function(Offset) f) =>
      AppCompareZoom(scale: scale, center: f(center));

  @override
  bool operator ==(Object other) =>
      other is AppCompareZoom &&
      other.scale == scale &&
      other.center == center;

  @override
  int get hashCode => Object.hash(scale, center);

  @override
  String toString() =>
      'AppCompareZoom(${scale.toStringAsFixed(2)}, '
      '${center.dx.toStringAsFixed(3)}, ${center.dy.toStringAsFixed(3)})';
}

/// 一侧画面的摆放：旋转、翻转和缩放。翻转按看到的画面算（左右翻转总是把眼前的
/// 画面左右对调），旋转总是顺时针。
@immutable
class AppCompareSide {
  const AppCompareSide({
    this.quarterTurns = 0,
    this.flipX = false,
    this.flipY = false,
    this.zoom = AppCompareZoom.identity,
  });

  static const initial = AppCompareSide();

  /// 顺时针转了几个 90°（0–3），在翻转之前生效。
  final int quarterTurns;
  final bool flipX;
  final bool flipY;
  final AppCompareZoom zoom;

  bool get isInitial =>
      quarterTurns == 0 && !flipX && !flipY && zoom.isIdentity;

  /// 显示出来的宽高比：转了 90° 或 270° 时宽高对调。
  double displayRatio(double ratio) => quarterTurns.isOdd ? 1 / ratio : ratio;

  AppCompareSide copyWith({AppCompareZoom? zoom}) => AppCompareSide(
    quarterTurns: quarterTurns,
    flipX: flipX,
    flipY: flipY,
    zoom: zoom ?? this.zoom,
  );

  /// 看到的画面顺时针转 90°，放大的那一处跟着转过去。
  ///
  /// 画面是「先旋转、再翻转」画出来的；只翻了一个方向时，翻转会把旋转的方向
  /// 倒过来，所以这时内层要逆时针转，看到的才是顺时针。
  AppCompareSide rotated() {
    final mirrored = flipX != flipY;
    return AppCompareSide(
      quarterTurns: (quarterTurns + (mirrored ? 3 : 1)) % 4,
      flipX: flipX,
      flipY: flipY,
      zoom: zoom._map((c) => Offset(1 - c.dy, c.dx)),
    );
  }

  AppCompareSide flippedX() => AppCompareSide(
    quarterTurns: quarterTurns,
    flipX: !flipX,
    flipY: flipY,
    zoom: zoom._map((c) => Offset(1 - c.dx, c.dy)),
  );

  AppCompareSide flippedY() => AppCompareSide(
    quarterTurns: quarterTurns,
    flipX: flipX,
    flipY: !flipY,
    zoom: zoom._map((c) => Offset(c.dx, 1 - c.dy)),
  );

  @override
  bool operator ==(Object other) =>
      other is AppCompareSide &&
      other.quarterTurns == quarterTurns &&
      other.flipX == flipX &&
      other.flipY == flipY &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(quarterTurns, flipX, flipY, zoom);
}

/// [AppCompareView] 的状态：看法、锁定、两侧的摆放、分隔条和上层不透明度。
///
/// 页面持有它，顶栏的切换（并排 / 滑动 / 叠加、彩色 / 灰度）和画布下面那一行的
/// 操作（[AppCompareActions]）都改它。两侧按 0（第一张）和 1（第二张）编号，交换
/// 左右只改摆放的位置，不改编号。
///
/// - **锁定**（默认）：缩放、拖动、双击放大一侧，另一侧放大同样的倍数、看同一个
///   位置；旋转和翻转两侧一起做。从不锁定改回锁定时，另一侧对齐到刚才操作的那一侧。
/// - **不锁定**：两侧各自缩放；旋转和翻转只作用于最后摸过的那一侧（[activeSide]）。
/// - 滑动和叠加时两张图在同一个画框里，缩放总是一起；锁定只管旋转和翻转。
class AppCompareController extends ChangeNotifier {
  AppCompareController({
    AppCompareMode mode = AppCompareMode.sideBySide,
    bool locked = true,
    bool grayscale = false,
    this.modes = AppCompareMode.values,
    this.canRotate = true,
    this.canFlip = true,
    this.canSwap = true,
  }) : _mode = mode,
       _locked = locked,
       _grayscale = grayscale;

  static const double maxScale = 6;

  /// 双击放大到的倍数。
  static const double doubleTapScale = 2.5;

  /// 分隔条的范围。
  static const double splitMin = 0.15;
  static const double splitMax = 0.85;

  /// 页面提供的看法；只有一种时不显示切换。
  final List<AppCompareMode> modes;
  final bool canRotate;
  final bool canFlip;
  final bool canSwap;

  AppCompareMode _mode;
  bool _locked;
  bool _grayscale;
  bool _swapped = false;
  int _activeSide = 0;
  List<AppCompareSide> _sides = const [
    AppCompareSide.initial,
    AppCompareSide.initial,
  ];
  AppCompareZoom _frameZoom = AppCompareZoom.identity;
  double? _split;
  double _revealSplit = 0.5;
  double _overlayOpacity = 0.5;

  AppCompareMode get mode => _mode;
  bool get locked => _locked;
  bool get grayscale => _grayscale;

  /// 第二张摆在左边。
  bool get swapped => _swapped;

  /// 最后摸过的一侧（0 或 1）。不锁定时旋转和翻转作用于它。
  int get activeSide => _activeSide;

  AppCompareSide side(int index) => _sides[index];

  /// 滑动和叠加时共用的缩放。
  AppCompareZoom get frameZoom => _frameZoom;

  /// 并排时分隔条的位置；为 null 时放在让两张图都尽量大的位置。
  double? get split => _split;
  double get revealSplit => _revealSplit;

  /// 叠加时上层（第二张）的不透明度。
  double get overlayOpacity => _overlayOpacity;

  bool get framed => _mode != AppCompareMode.sideBySide;

  /// 和刚打开时一样：没有缩放、旋转、翻转、交换，分隔条和不透明度在默认位置。
  bool get isPristine =>
      _sides.every((s) => s.isInitial) &&
      _frameZoom.isIdentity &&
      !_swapped &&
      _split == null &&
      _revealSplit == 0.5 &&
      _overlayOpacity == 0.5;

  /// 画布下面那一句提示，随看法和锁定变化。
  String get hint => switch (_mode) {
    AppCompareMode.sideBySide =>
      _locked
          ? '已锁定：缩放、拖动或旋转一侧，另一侧同样处理 · 双击画面放大'
          : '未锁定：两侧分别缩放，旋转和翻转只作用于名称加粗的一侧',
    AppCompareMode.reveal => '左右拖动分隔条对照同一处 · 两张图一起缩放，双击画面放大',
    AppCompareMode.overlay => '拖动滑条调上层的深浅，看两张图哪里对不上 · 双击画面放大',
  };

  List<int> get _targets => _locked ? const [0, 1] : [_activeSide];

  void setMode(AppCompareMode value) {
    if (value == _mode) {
      return;
    }
    final wasFramed = framed;
    _mode = value;
    if (!wasFramed && framed) {
      _frameZoom = _sides[_activeSide].zoom;
    } else if (wasFramed && !framed) {
      for (final index in _targets) {
        _sides = _with(index, _sides[index].copyWith(zoom: _frameZoom));
      }
    }
    notifyListeners();
  }

  /// 改回锁定时，另一侧对齐到最后操作的那一侧（旋转、翻转、缩放都对齐）。
  void setLocked(bool value) {
    if (value == _locked) {
      return;
    }
    _locked = value;
    if (value) {
      final source = _sides[_activeSide];
      _sides = [source, source];
    }
    notifyListeners();
  }

  void toggleLock() => setLocked(!_locked);

  void setGrayscale(bool value) {
    if (value == _grayscale) {
      return;
    }
    _grayscale = value;
    notifyListeners();
  }

  void setActiveSide(int index) {
    if (index == _activeSide) {
      return;
    }
    _activeSide = index;
    notifyListeners();
  }

  /// 并排时一侧的缩放变了；锁定时另一侧跟着变。
  void setSideZoom(int index, AppCompareZoom zoom) {
    final value = zoom.clamped();
    var changed = false;
    for (final target in _locked ? const [0, 1] : [index]) {
      if (!_sides[target].zoom.closeTo(value)) {
        _sides = _with(target, _sides[target].copyWith(zoom: value));
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void setFrameZoom(AppCompareZoom zoom) {
    final value = zoom.clamped();
    if (_frameZoom.closeTo(value)) {
      return;
    }
    _frameZoom = value;
    notifyListeners();
  }

  /// 双击：没放大时放大到 [doubleTapScale]，点的那一处移到正中；已放大时复原。
  static AppCompareZoom doubleTapped(
    AppCompareZoom zoom,
    Offset point,
    Size viewport,
  ) {
    if (!zoom.isIdentity) {
      return AppCompareZoom.identity;
    }
    return AppCompareZoom(
      scale: doubleTapScale,
      center: zoom.fractionAt(point, viewport),
    ).clamped();
  }

  void rotate() => _apply((s) => s.rotated());

  void flipHorizontal() => _apply((s) => s.flippedX());

  void flipVertical() => _apply((s) => s.flippedY());

  void _apply(AppCompareSide Function(AppCompareSide) change) {
    final targets = _targets;
    for (final index in targets) {
      _sides = _with(index, change(_sides[index]));
    }
    if (framed && targets.length == 2) {
      _frameZoom = change(AppCompareSide(zoom: _frameZoom)).zoom;
    }
    notifyListeners();
  }

  void swap() {
    _swapped = !_swapped;
    final split = _split;
    if (split != null) {
      _split = 1 - split;
    }
    notifyListeners();
  }

  void setSplit(double? value) {
    final next = value?.clamp(splitMin, splitMax).toDouble();
    if (next == _split) {
      return;
    }
    _split = next;
    notifyListeners();
  }

  void setRevealSplit(double value) {
    final next = value.clamp(splitMin, splitMax).toDouble();
    if (next == _revealSplit) {
      return;
    }
    _revealSplit = next;
    notifyListeners();
  }

  void setOverlayOpacity(double value) {
    final next = value.clamp(0.0, 1.0).toDouble();
    if (next == _overlayOpacity) {
      return;
    }
    _overlayOpacity = next;
    notifyListeners();
  }

  /// 只把缩放复原（换了一张图时用）。
  void resetZoom() {
    _sides = [for (final s in _sides) s.copyWith(zoom: AppCompareZoom.identity)];
    _frameZoom = AppCompareZoom.identity;
    notifyListeners();
  }

  /// 复位：回到刚打开时的摆放。看法、锁定和灰度是用户选的，保持不变。
  void reset() {
    _sides = const [AppCompareSide.initial, AppCompareSide.initial];
    _frameZoom = AppCompareZoom.identity;
    _swapped = false;
    _split = null;
    _revealSplit = 0.5;
    _overlayOpacity = 0.5;
    notifyListeners();
  }

  List<AppCompareSide> _with(int index, AppCompareSide value) => [
    for (var i = 0; i < _sides.length; i++) i == index ? value : _sides[i],
  ];
}
