import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/art/photo_rectify.dart';
import '../../../../core/ui/ui.dart';

/// 拉正裁边的画布：照片完整显示（contain），上面是画纸四边形的轮廓、四边形
/// 以外压暗，四个角各有一个可拖动的把手；拖动时左上（或右上）角出现放大镜。
///
/// [corners] 是相对于转过 [quarterTurns] 之后的照片的归一化坐标，顺序是左上、
/// 右上、右下、左下。拖到会让四边形凹进去或交叉的位置时，把手停在最后一个
/// 可用的位置。
class PhotoStraightenCanvas extends StatefulWidget {
  const PhotoStraightenCanvas({
    required this.image,
    required this.quarterTurns,
    required this.corners,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final ui.Image image;
  final int quarterTurns;
  final List<PhotoPoint> corners;
  final ValueChanged<List<PhotoPoint>> onChanged;
  final bool enabled;

  /// 把手看得见的直径和点击区域。
  static const double handleSize = 20;
  static const double hitSize = 44;

  /// 照片四周留出的空白，角上的把手不会被画布边缘切掉。
  static const double inset = hitSize / 2 + AppSpace.s4;

  /// 四边形的面积下限（占照片的比例）。
  static const double minArea = 0.01;

  static const cornerNames = ['左上角', '右上角', '右下角', '左下角'];

  @override
  State<PhotoStraightenCanvas> createState() => _PhotoStraightenCanvasState();
}

class _PhotoStraightenCanvasState extends State<PhotoStraightenCanvas> {
  int? _dragging;
  PhotoPoint? _dragStart;
  Offset _dragTotal = Offset.zero;

  Size get _photoSize {
    final w = widget.image.width.toDouble();
    final h = widget.image.height.toDouble();
    return widget.quarterTurns.isOdd ? Size(h, w) : Size(w, h);
  }

  Rect _photoRect(Size box) {
    final area = Rect.fromLTWH(0, 0, box.width, box.height).deflate(
      PhotoStraightenCanvas.inset,
    );
    final fitted = applyBoxFit(BoxFit.contain, _photoSize, area.size);
    return Alignment.center.inscribe(fitted.destination, area);
  }

  void _start(int index) {
    setState(() {
      _dragging = index;
      _dragStart = widget.corners[index];
      _dragTotal = Offset.zero;
    });
  }

  void _update(int index, Offset delta, Rect rect) {
    final start = _dragStart;
    if (start == null) return;
    _dragTotal += delta;
    double clamp(double v) => v.clamp(0.0, 1.0);
    final x = clamp(start.x + _dragTotal.dx / rect.width);
    final y = clamp(start.y + _dragTotal.dy / rect.height);
    final current = widget.corners[index];
    // 整步不行时只挪一个方向，贴着边界还能滑动。
    for (final candidate in <PhotoPoint>[
      (x: x, y: y),
      (x: x, y: current.y),
      (x: current.x, y: y),
    ]) {
      final next = List<PhotoPoint>.of(widget.corners)..[index] = candidate;
      if (isConvexQuad(next, minArea: PhotoStraightenCanvas.minArea)) {
        if (candidate != current) widget.onChanged(next);
        return;
      }
    }
  }

  void _end() => setState(() {
    _dragging = null;
    _dragStart = null;
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        final rect = _photoRect(box);
        final points = [
          for (final p in widget.corners)
            Offset(rect.left + p.x * rect.width, rect.top + p.y * rect.height),
        ];
        final dragging = _dragging;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _StraightenPainter(
                  image: widget.image,
                  quarterTurns: widget.quarterTurns,
                  photoRect: rect,
                  points: points,
                  focus: dragging == null ? null : points[dragging],
                ),
              ),
            ),
            for (var i = 0; i < 4; i++)
              Positioned(
                left: points[i].dx - PhotoStraightenCanvas.hitSize / 2,
                top: points[i].dy - PhotoStraightenCanvas.hitSize / 2,
                width: PhotoStraightenCanvas.hitSize,
                height: PhotoStraightenCanvas.hitSize,
                child: _Handle(
                  key: ValueKey('straighten-handle-$i'),
                  label: '拖动${PhotoStraightenCanvas.cornerNames[i]}',
                  active: dragging == i,
                  onStart: widget.enabled ? () => _start(i) : null,
                  onUpdate: (delta) => _update(i, delta, rect),
                  onEnd: _end,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.label,
    required this.active,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback? onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final start = onStart;
    return Semantics(
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 从按下的位置算起，把手跟着手指走，不丢掉起步的那一小段。
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: start == null ? null : (_) => start(),
        onPanUpdate: start == null ? null : (d) => onUpdate(d.delta),
        onPanEnd: start == null ? null : (_) => onEnd(),
        onPanCancel: start == null ? null : onEnd,
        child: Center(
          child: Container(
            width: PhotoStraightenCanvas.handleSize,
            height: PhotoStraightenCanvas.handleSize,
            decoration: BoxDecoration(
              color: active ? AppColors.surface : AppColors.ink,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? AppColors.ink : AppColors.surface,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.3),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StraightenPainter extends CustomPainter {
  const _StraightenPainter({
    required this.image,
    required this.quarterTurns,
    required this.photoRect,
    required this.points,
    required this.focus,
  });

  final ui.Image image;
  final int quarterTurns;
  final Rect photoRect;
  final List<Offset> points;

  /// 正在拖动的角；不为空时画放大镜。
  final Offset? focus;

  static const double _loupeRadius = 56;
  static const double _loupeZoom = 2.5;

  /// 把转过的照片画进 [photoRect]。
  void _paintPhoto(Canvas canvas) {
    final turns = quarterTurns % 4;
    canvas.save();
    canvas.translate(photoRect.center.dx, photoRect.center.dy);
    canvas.rotate(turns * math.pi / 2);
    final w = turns.isOdd ? photoRect.height : photoRect.width;
    final h = turns.isOdd ? photoRect.width : photoRect.height;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  Path get _quad => Path()..addPolygon(points, true);

  void _paintOutline(Canvas canvas, double scale) {
    canvas
      ..drawPath(
        _quad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 / scale
          ..color = AppColors.ink.withValues(alpha: 0.35),
      )
      ..drawPath(
        _quad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale
          ..color = AppColors.surface,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintPhoto(canvas);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(photoRect)
      ..addPolygon(points, true);
    canvas.drawPath(
      outside,
      Paint()..color = AppColors.ink.withValues(alpha: 0.5),
    );
    _paintOutline(canvas, 1);
    final at = focus;
    if (at != null) _paintLoupe(canvas, size, at);
  }

  /// 放大镜放在离手指远的上角，中心是被拖动的角。
  void _paintLoupe(Canvas canvas, Size size, Offset at) {
    const r = _loupeRadius;
    final center = at.dx < size.width / 2
        ? Offset(size.width - r - AppSpace.s12, r + AppSpace.s12)
        : const Offset(r + AppSpace.s12, r + AppSpace.s12);
    final circle = Rect.fromCircle(center: center, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawRect(circle, Paint()..color = AppColors.canvas);
    canvas.translate(center.dx, center.dy);
    canvas.scale(_loupeZoom);
    canvas.translate(-at.dx, -at.dy);
    _paintPhoto(canvas);
    _paintOutline(canvas, _loupeZoom);
    canvas.restore();
    final cross = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1;
    canvas
      ..drawLine(center.translate(-8, 0), center.translate(8, 0), cross)
      ..drawLine(center.translate(0, -8), center.translate(0, 8), cross)
      ..drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.surface,
      );
  }

  @override
  bool shouldRepaint(covariant _StraightenPainter old) =>
      old.image != image ||
      old.quarterTurns != quarterTurns ||
      old.photoRect != photoRect ||
      old.focus != focus ||
      !_samePoints(old.points, points);

  static bool _samePoints(List<Offset> a, List<Offset> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return a.length == b.length;
  }
}
