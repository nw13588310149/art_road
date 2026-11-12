import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 拖动小画时身后留下的一笔颜料：笔头跟着小画，笔尾在半秒内收细消失。
/// 只有存在笔迹时才计帧，最后一点消失后立即释放。
class CompanionPaintTrail extends StatefulWidget {
  const CompanionPaintTrail({super.key});

  @override
  State<CompanionPaintTrail> createState() => CompanionPaintTrailState();
}

class CompanionPaintTrailState extends State<CompanionPaintTrail>
    with SingleTickerProviderStateMixin {
  static const _life = Duration(milliseconds: 520);

  Ticker? _ticker;
  final _frame = ValueNotifier<int>(0);
  final _points = <_TrailPoint>[];
  Duration _now = Duration.zero;
  Color _color = const Color(0xFFFF6B5E);

  void add(Offset point, Color color) {
    final ticker = _ticker ??= createTicker(_tick);
    if (!ticker.isActive) {
      _now = Duration.zero;
      _points.clear();
    }
    if (_points.isNotEmpty && (_points.last.position - point).distance < 1.5) {
      return;
    }
    _color = color;
    _points.add(_TrailPoint(point, _now));
    if (!ticker.isActive) ticker.start();
    _frame.value++;
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    _points.removeWhere((point) => elapsed - point.time >= _life);
    if (_points.isEmpty) _ticker?.stop();
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: _TrailPainter(this)),
      ),
    ),
  );
}

class _TrailPoint {
  const _TrailPoint(this.position, this.time);

  final Offset position;
  final Duration time;
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.state) : super(repaint: state._frame);

  final CompanionPaintTrailState state;

  @override
  void paint(Canvas canvas, Size size) {
    final points = state._points;
    if (points.length < 2) return;
    final life = CompanionPaintTrailState._life.inMicroseconds;
    final widths = [
      for (final point in points)
        2 +
            13 *
                math.pow(
                  (1 - (state._now - point.time).inMicroseconds / life).clamp(
                    0.0,
                    1.0,
                  ),
                  0.8,
                ),
    ];
    final left = <Offset>[];
    final right = <Offset>[];
    final normals = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final before = points[math.max(0, i - 1)].position;
      final after = points[math.min(points.length - 1, i + 1)].position;
      final direction = after - before;
      final length = direction.distance;
      final normal = length < 0.01
          ? const Offset(0, 1)
          : Offset(-direction.dy / length, direction.dx / length);
      normals.add(normal);
      left.add(points[i].position + normal * (widths[i] / 2));
      right.add(points[i].position - normal * (widths[i] / 2));
    }
    // 不透明的水粉一笔：沿路径收细的带状填充，笔头补一个圆角。
    final ribbon = Path()..moveTo(left.first.dx, left.first.dy);
    for (final point in left.skip(1)) {
      ribbon.lineTo(point.dx, point.dy);
    }
    for (final point in right.reversed) {
      ribbon.lineTo(point.dx, point.dy);
    }
    ribbon.close();
    final color = state._color;
    canvas.drawPath(ribbon, Paint()..color = color);
    canvas.drawCircle(
      points.last.position,
      widths.last / 2,
      Paint()..color = color,
    );
    // 湿颜料的高光和笔毛留下的深色丝痕。
    final shine = Path();
    final streak = Path();
    var started = false;
    for (var i = 0; i < points.length; i++) {
      if (widths[i] < 6) {
        started = false;
        continue;
      }
      final shinePoint = points[i].position + normals[i] * (widths[i] * 0.24);
      final streakPoint = points[i].position - normals[i] * (widths[i] * 0.22);
      if (!started) {
        shine.moveTo(shinePoint.dx, shinePoint.dy);
        streak.moveTo(streakPoint.dx, streakPoint.dy);
        started = true;
      } else {
        shine.lineTo(shinePoint.dx, shinePoint.dy);
        streak.lineTo(streakPoint.dx, streakPoint.dy);
      }
    }
    canvas.drawPath(
      shine,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      streak,
      Paint()
        ..color = Color.lerp(color, const Color(0xFF221651), 0.3)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) => oldDelegate.state != state;
}
