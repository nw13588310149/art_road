import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// 静态进度条：没有入场动画。[striped] 时填充部分叠 45° 白色斜纹（与机构端首页一致）。
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    this.height = 8,
    this.color = AppColors.brand,
    this.trackColor = AppColors.line,
    this.striped = false,
    super.key,
  });

  /// 0–1，超出范围按边界处理，null 视为 0。
  final double? value;
  final double height;
  final Color color;
  final Color trackColor;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    final factor = (value ?? 0).clamp(0.0, 1.0);
    return Semantics(
      value: '${(factor * 100).round()}%',
      child: ClipRRect(
        borderRadius: AppRadius.brPill,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: trackColor),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: factor,
                child: ClipRRect(
                  borderRadius: AppRadius.brPill,
                  child: CustomPaint(
                    painter: _ProgressFillPainter(
                      color: color,
                      striped: striped,
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

class _ProgressFillPainter extends CustomPainter {
  const _ProgressFillPainter({required this.color, required this.striped});

  final Color color;
  final bool striped;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    if (!striped || size.isEmpty) {
      return;
    }
    // 斜纹宽 3px、周期 8px（沿 45° 法线方向），与机构端 repeating-linear-gradient 一致。
    final stripe = 3 * math.sqrt2;
    final period = 8 * math.sqrt2;
    final paint = Paint()..color = const Color(0x47FFFFFF);
    for (var x = -size.height; x < size.width; x += period) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripe, size.height)
        ..lineTo(x + stripe + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressFillPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.striped != striped;
}
