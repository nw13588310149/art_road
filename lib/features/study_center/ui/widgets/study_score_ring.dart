import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';

/// 总分环：品牌渐变弧表示得分率，中心显示分数与满分。
class StudyScoreRing extends StatelessWidget {
  const StudyScoreRing({
    required this.score,
    required this.maxScore,
    this.size = 140,
    super.key,
  });

  final double? score;
  final double? maxScore;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = score;
    final full = maxScore ?? 0;
    final progress = value == null || full <= 0
        ? 0.0
        : (value / full).clamp(0.0, 1.0);
    final stroke = size * 0.085;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animated, child) => CustomPaint(
          painter: _ScoreRingPainter(progress: animated, strokeWidth: stroke),
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatScore(value),
                style: ArtText.number(
                  size: size * 0.22,
                  color: value == null ? ArtColors.ink3 : ArtColors.brandDeep,
                ),
              ),
              SizedBox(height: size * 0.035),
              Text(
                full > 0 ? '满分 ${formatScore(full)}' : '总分',
                style: ArtText.caption(size: math.max(11.0, size * 0.08)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter({required this.progress, required this.strokeWidth});

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = ArtColors.brandTint,
    );
    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        endAngle: math.max(sweep, 0.001),
        colors: const [
          ArtColors.brandSoft,
          ArtColors.brand,
          ArtColors.brandDeep,
        ],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);

    final angle = -math.pi / 2 + sweep;
    final knob = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(knob, strokeWidth * 0.3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth;
}
