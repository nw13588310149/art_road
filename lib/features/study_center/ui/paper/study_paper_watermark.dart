import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';

/// 原卷水印：斜向平铺的半透明文字，不拦截手势。
class StudyPaperWatermark extends StatelessWidget {
  const StudyPaperWatermark({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ClipRect(
        child: CustomPaint(
          size: Size.infinite,
          painter: _WatermarkPainter(text: text.trim()),
        ),
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter({required this.text});

  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    // 深色字 + 浅色描影，浅色画纸和深色背景上都能辨认。
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.body16.copyWith(
          fontWeight: AppFont.w500,
          color: AppColors.ink.withValues(alpha: 0.13),
          shadows: [
            Shadow(
              color: AppColors.onBrand.withValues(alpha: 0.14),
              offset: const Offset(0.8, 0.8),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final stepX = painter.width + 72;
    final stepY = painter.height + 64;
    final diagonal = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(-math.pi / 7);
    var row = 0;
    for (var y = -diagonal / 2; y < diagonal / 2; y += stepY) {
      final offset = row.isOdd ? stepX / 2 : 0.0;
      for (var x = -diagonal / 2 - offset; x < diagonal / 2; x += stepX) {
        painter.paint(canvas, Offset(x, y));
      }
      row++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) => oldDelegate.text != text;
}
