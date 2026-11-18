import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// 进度环：一圈浅色的底加一段品牌色的弧，中间可以放数字。静态，没有入场动画。
///
/// 一屏最多一个，用在「做到第几个、一共几个」这种整体进度上。弧从正上方开始，
/// 顺时针走；[value] 为 0 时只有底。
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    required this.value,
    this.size = 56,
    this.stroke = 6,
    this.color = AppColors.brand,
    this.trackColor = AppColors.line,
    this.child,
    this.semanticLabel,
    super.key,
  });

  /// 0–1。
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color trackColor;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      value: '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: value.clamp(0.0, 1.0),
            stroke: stroke,
            color: color,
            trackColor: trackColor,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final arc = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = trackColor);
    if (value > 0) {
      canvas.drawArc(
        arc,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.stroke != stroke ||
      old.color != color ||
      old.trackColor != trackColor;
}
