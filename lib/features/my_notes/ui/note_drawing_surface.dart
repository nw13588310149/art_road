import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pencil_kit/pencil_kit.dart';

import '../state/my_notes_state.dart';
import 'note_canvas_zoom.dart';

/// iOS 使用系统 PencilKit；其它平台沿用 Flutter 自研笔迹。
bool get noteDrawingUsesPencilKit =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class NoteDrawingHistory {
  const NoteDrawingHistory({required this.canUndo, required this.canRedo});

  final bool canUndo;
  final bool canRedo;
}

/// 笔记编辑器画布：纸张背景 + 笔迹层。
///
/// - iOS：原生 PencilKit（隐藏系统工具栏，由外部工具栏驱动）
/// - Android 等：GestureDetector + [CustomPainter]
class NoteDrawingSurface extends StatefulWidget {
  const NoteDrawingSurface({
    super.key,
    required this.paperType,
    required this.backgroundImage,
    required this.strokeColor,
    required this.strokeWidth,
    required this.toolMode,
    required this.strokes,
    required this.activeStroke,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
    required this.onHistoryChanged,
    required this.onBackgroundZoomChanged,
    this.pendingPencilKitData,
    this.onPendingPencilKitConsumed,
    this.borderRadius = 18,
  });

  final NotePaperType paperType;
  final Widget backgroundImage;
  final Color strokeColor;
  final double strokeWidth;
  final NoteToolMode toolMode;
  final List<NoteStroke> strokes;
  final List<Offset> activeStroke;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onPanCancel;
  final ValueChanged<NoteDrawingHistory> onHistoryChanged;
  final ValueChanged<double> onBackgroundZoomChanged;
  final String? pendingPencilKitData;
  final VoidCallback? onPendingPencilKitConsumed;
  final double borderRadius;

  @override
  State<NoteDrawingSurface> createState() => NoteDrawingSurfaceState();
}

class NoteDrawingSurfaceState extends State<NoteDrawingSurface> {
  final GlobalKey _flutterBoundaryKey = GlobalKey();
  final GlobalKey _backgroundBoundaryKey = GlobalKey();

  PencilKitController? _pencilKit;
  bool _iosHasContent = false;
  bool _iosCanRedo = false;
  int _iosUndoDepth = 0;
  static const double _minBackgroundZoom = 0.75;
  static const double _maxBackgroundZoom = 2.5;
  static const double _backgroundZoomStep = 0.25;
  double _backgroundZoom = 1;

  bool get canUndo =>
      noteDrawingUsesPencilKit ? _iosHasContent : widget.strokes.isNotEmpty;

  bool get canRedo => noteDrawingUsesPencilKit ? _iosCanRedo : false;

  @override
  void didUpdateWidget(covariant NoteDrawingSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!noteDrawingUsesPencilKit) {
      return;
    }
    final toolChanged = oldWidget.toolMode != widget.toolMode;
    final colorChanged = oldWidget.strokeColor != widget.strokeColor;
    final widthChanged = oldWidget.strokeWidth != widget.strokeWidth;
    if (toolChanged || colorChanged || widthChanged) {
      unawaited(_applyIosTool());
    }
    final pending = widget.pendingPencilKitData;
    if (pending != null &&
        pending.isNotEmpty &&
        pending != oldWidget.pendingPencilKitData) {
      unawaited(_loadPendingPencilKit(pending));
    }
  }

  Future<void> undo() async {
    if (noteDrawingUsesPencilKit) {
      final controller = _pencilKit;
      if (controller == null) {
        return;
      }
      await controller.undo();
      if (_iosUndoDepth > 0) {
        _iosUndoDepth -= 1;
        _iosCanRedo = true;
      }
      await _refreshIosContentFlag();
      _emitHistory();
      return;
    }
  }

  Future<void> redo() async {
    if (noteDrawingUsesPencilKit) {
      final controller = _pencilKit;
      if (controller == null) {
        return;
      }
      await controller.redo();
      _iosUndoDepth += 1;
      _iosHasContent = true;
      // PencilKit 不暴露 redo 栈深度；连续 redo 直到用户点不动为止。
      _emitHistory();
      return;
    }
  }

  Future<void> clear() async {
    if (noteDrawingUsesPencilKit) {
      final controller = _pencilKit;
      if (controller == null) {
        return;
      }
      await controller.clear();
      _iosHasContent = false;
      _iosCanRedo = false;
      _iosUndoDepth = 0;
      _emitHistory();
      return;
    }
  }

  double get backgroundZoom => _backgroundZoom;

  void zoomBackgroundIn() =>
      _setBackgroundZoom(_backgroundZoom + _backgroundZoomStep);

  void zoomBackgroundOut() =>
      _setBackgroundZoom(_backgroundZoom - _backgroundZoomStep);

  void resetBackgroundZoom() => _setBackgroundZoom(1);

  void _setBackgroundZoom(double value) {
    final next = value.clamp(_minBackgroundZoom, _maxBackgroundZoom).toDouble();
    if (next == _backgroundZoom) {
      return;
    }
    setState(() => _backgroundZoom = next);
    unawaited(NoteCanvasZoom.setZoom(next));
    widget.onBackgroundZoomChanged(next);
  }

  /// 导出 PencilKit base64（无前缀）；非 iOS 返回 null。
  Future<String?> exportPencilKitData() async {
    if (!noteDrawingUsesPencilKit) {
      return null;
    }
    final controller = _pencilKit;
    if (controller == null) {
      return null;
    }
    try {
      final data = await controller.getBase64Data();
      final trimmed = data.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadPencilKitData(String base64Data) async {
    if (!noteDrawingUsesPencilKit) {
      return;
    }
    await _loadPendingPencilKit(base64Data);
  }

  /// 导出整页 PNG（纸张 + 底图 + 笔迹）。
  Future<Uint8List?> capturePng({double pixelRatio = 2.2}) async {
    if (noteDrawingUsesPencilKit) {
      return _captureIosCompositedPng(pixelRatio: pixelRatio);
    }
    return _captureFlutterBoundaryPng(pixelRatio: pixelRatio);
  }

  Future<Uint8List?> _captureFlutterBoundaryPng({
    required double pixelRatio,
  }) async {
    final boundary =
        _flutterBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }
    await WidgetsBinding.instance.endOfFrame;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<Uint8List?> _captureIosCompositedPng({
    required double pixelRatio,
  }) async {
    final backgroundBoundary =
        _backgroundBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    final pencil = _pencilKit;
    if (backgroundBoundary == null || pencil == null) {
      return null;
    }

    await WidgetsBinding.instance.endOfFrame;
    final bgImage = await backgroundBoundary.toImage(pixelRatio: pixelRatio);
    final bgBytes = await bgImage.toByteData(format: ui.ImageByteFormat.png);
    if (bgBytes == null) {
      return null;
    }

    String drawingBase64;
    try {
      drawingBase64 = await pencil.getBase64PngData(scale: pixelRatio);
    } on PlatformException {
      return bgBytes.buffer.asUint8List();
    }
    if (drawingBase64.isEmpty) {
      return bgBytes.buffer.asUint8List();
    }

    Uint8List drawingBytes;
    try {
      drawingBytes = base64Decode(drawingBase64);
    } on FormatException {
      return bgBytes.buffer.asUint8List();
    }

    return _compositePng(
      backgroundPng: bgBytes.buffer.asUint8List(),
      drawingPng: drawingBytes,
      drawingScale: _backgroundZoom,
    );
  }

  Future<Uint8List?> _compositePng({
    required Uint8List backgroundPng,
    required Uint8List drawingPng,
    required double drawingScale,
  }) async {
    final bgCodec = await ui.instantiateImageCodec(backgroundPng);
    final bgFrame = await bgCodec.getNextFrame();
    final drawCodec = await ui.instantiateImageCodec(drawingPng);
    final drawFrame = await drawCodec.getNextFrame();

    final width = bgFrame.image.width;
    final height = bgFrame.image.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(bgFrame.image, Offset.zero, Paint());
    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.scale(drawingScale);
    canvas.translate(-width / 2, -height / 2);
    canvas.drawImageRect(
      drawFrame.image,
      Rect.fromLTWH(
        0,
        0,
        drawFrame.image.width.toDouble(),
        drawFrame.image.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
    final picture = recorder.endRecording();
    final composed = await picture.toImage(width, height);
    final out = await composed.toByteData(format: ui.ImageByteFormat.png);
    bgFrame.image.dispose();
    drawFrame.image.dispose();
    composed.dispose();
    return out?.buffer.asUint8List();
  }

  Future<void> _onPencilKitCreated(PencilKitController controller) async {
    _pencilKit = controller;
    try {
      await controller.hide();
      await _applyIosTool();
      await NoteCanvasZoom.setZoom(_backgroundZoom);
      final pending = widget.pendingPencilKitData;
      if (pending != null && pending.isNotEmpty) {
        await _loadPendingPencilKit(pending);
      }
    } catch (_) {
      // 工具栏同步失败不阻断书写。
    }
  }

  Future<void> _loadPendingPencilKit(String base64Data) async {
    final controller = _pencilKit;
    if (controller == null) {
      return;
    }
    try {
      await controller.loadBase64Data(base64Data);
      _iosHasContent = true;
      _iosCanRedo = false;
      _iosUndoDepth = 1;
      _emitHistory();
      widget.onPendingPencilKitConsumed?.call();
    } catch (_) {
      // 加载失败时保留底图兼容路径由外层决定。
    }
  }

  Future<void> _applyIosTool() async {
    final controller = _pencilKit;
    if (controller == null) {
      return;
    }
    if (widget.toolMode == NoteToolMode.eraser) {
      await controller.setPKTool(
        toolType: ToolType.eraserVector,
        width: widget.strokeWidth.clamp(1, 40),
      );
      return;
    }
    await controller.setPKTool(
      toolType: ToolType.pen,
      width: widget.strokeWidth.clamp(1, 40),
      color: widget.strokeColor,
    );
  }

  Future<void> _refreshIosContentFlag() async {
    final controller = _pencilKit;
    if (controller == null) {
      return;
    }
    try {
      final data = await controller.getBase64Data();
      _iosHasContent = data.trim().isNotEmpty;
      if (!_iosHasContent) {
        _iosCanRedo = _iosUndoDepth > 0 || _iosCanRedo;
        _iosUndoDepth = 0;
      }
    } catch (_) {
      // 保持现状
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _emitHistory() {
    widget.onHistoryChanged(
      NoteDrawingHistory(canUndo: _iosHasContent, canRedo: _iosCanRedo),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _onIosDrawingChanged() {
    _iosHasContent = true;
    _iosCanRedo = false;
    _iosUndoDepth += 1;
    _emitHistory();
  }

  int _pointerCount = 0;
  late final TransformationController _viewerController =
      TransformationController();

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount += 1;
    if (_pointerCount >= 2) {
      widget.onPanCancel();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerCount > 0) {
      _pointerCount -= 1;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pointerCount > 0) {
      _pointerCount -= 1;
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (_pointerCount >= 2) {
      return;
    }
    widget.onPanStart(details);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_pointerCount >= 2) {
      return;
    }
    widget.onPanUpdate(details);
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_pointerCount >= 2) {
      return;
    }
    widget.onPanEnd(details);
  }

  @override
  void dispose() {
    _viewerController.dispose();
    _pencilKit = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: noteDrawingUsesPencilKit
            ? _buildIosCanvas()
            : _buildFlutterCanvas(),
      ),
    );
  }

  Widget _buildPaperStack({required GlobalKey? boundaryKey}) {
    final paper = Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: NotePaperPainter(type: widget.paperType)),
        widget.backgroundImage,
      ],
    );
    if (boundaryKey == null) {
      return paper;
    }
    return RepaintBoundary(
      key: boundaryKey,
      child: _buildScaledCanvas(child: paper),
    );
  }

  Widget _buildScaledCanvas({required Widget child}) {
    return ClipRect(
      child: Transform.scale(
        scale: _backgroundZoom,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _buildIosCanvas() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPaperStack(boundaryKey: _backgroundBoundaryKey),
        PencilKit(
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          alwaysBounceVertical: false,
          alwaysBounceHorizontal: false,
          isRulerActive: false,
          isOpaque: false,
          backgroundColor: Colors.transparent,
          // anyInput(1) == PKCanvasViewDrawingPolicy.anyInput：Apple Pencil 与
          // 手指都能书写（对齐系统备忘录默认行为）。若要「仅 Apple Pencil」，
          // 系统会在用户开启 设置 > Apple Pencil > 仅用 Apple Pencil 绘图 时
          // 通过 PKToolPicker 尊重该偏好；此处不隐藏手指输入以保证触摸兼容。
          drawingPolicy: PencilKitIos14DrawingPolicy.anyInput,
          unAvailableFallback: const ColoredBox(color: Colors.transparent),
          onPencilKitViewCreated: _onPencilKitCreated,
          canvasViewDrawingDidChange: _onIosDrawingChanged,
        ),
      ],
    );
  }

  Widget _buildFlutterCanvas() {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: InteractiveViewer(
        transformationController: _viewerController,
        panEnabled: false,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 4.0,
        child: RepaintBoundary(
          key: _flutterBoundaryKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildPaperStack(boundaryKey: null),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _handlePanStart,
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                child: CustomPaint(
                  painter: NoteStrokePainter(
                    strokes: widget.strokes,
                    activeStroke: widget.activeStroke,
                    activeColor: widget.strokeColor,
                    activeWidth: widget.strokeWidth,
                    isEraserPreview: widget.toolMode == NoteToolMode.eraser,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 笔记纸张背景（模板预览与编辑器共用）。
class NotePaperPainter extends CustomPainter {
  const NotePaperPainter({required this.type});

  final NotePaperType type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD6DCE9)
      ..strokeWidth = 1;

    switch (type) {
      case NotePaperType.blank:
        _drawDots(canvas, size);
        break;
      case NotePaperType.notebook:
        _drawNotebook(canvas, size, paint);
        break;
      case NotePaperType.staff:
        _drawStaff(canvas, size, paint);
        break;
    }
  }

  void _drawDots(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFFE9EDF7);
    for (double y = 26; y < size.height; y += 28) {
      for (double x = 20; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  void _drawNotebook(Canvas canvas, Size size, Paint paint) {
    for (double y = 42; y < size.height; y += 34) {
      canvas.drawLine(Offset(24, y), Offset(size.width - 24, y), paint);
    }
  }

  void _drawStaff(Canvas canvas, Size size, Paint paint) {
    double startY = 36;
    while (startY < size.height - 20) {
      for (var i = 0; i < 5; i++) {
        final y = startY + i * 9;
        canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
      }
      startY += 66;
    }
  }

  @override
  bool shouldRepaint(covariant NotePaperPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

class NoteStrokePainter extends CustomPainter {
  const NoteStrokePainter({
    required this.strokes,
    required this.activeStroke,
    required this.activeColor,
    required this.activeWidth,
    this.isEraserPreview = false,
  });

  final List<NoteStroke> strokes;
  final List<Offset> activeStroke;
  final Color activeColor;
  final double activeWidth;
  final bool isEraserPreview;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width);
    }
    if (activeStroke.length >= 2) {
      if (isEraserPreview) {
        _drawStroke(
          canvas,
          activeStroke,
          const Color(0x668B5CFF),
          activeWidth.clamp(8, 40),
        );
      } else {
        _drawStroke(canvas, activeStroke, activeColor, activeWidth);
      }
    }
  }

  void _drawStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midPoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midPoint.dx,
        midPoint.dy,
      );
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant NoteStrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.activeWidth != activeWidth ||
        oldDelegate.isEraserPreview != isEraserPreview;
  }
}
