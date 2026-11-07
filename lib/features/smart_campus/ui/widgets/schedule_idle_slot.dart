import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

import 'schedule_course_card.dart';

/// 空闲格沿用课程卡的边距和标准高度，叠课时仍贴在格子顶部。
class ScheduleIdleSlot extends StatelessWidget {
  const ScheduleIdleSlot({super.key});

  static const double designSlotHeight =
      kScheduleCourseCardHeight + 2 * kScheduleCourseCellInset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(kScheduleCourseCellInset),
        child: SizedBox(
          width: kScheduleCourseCardWidth,
          height: kScheduleCourseCardHeight,
          child: CustomPaint(
            painter: const _DashedRoundedRectPainter(),
            child: Center(
              child: Text(
                '空闲',
                style: AppText.body14.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 1 || size.height <= 1) return;
    final border = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      const Radius.circular(8),
    );
    final paint = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(border);
    for (final metric in path.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += 8) {
        final end = (start + 4).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedRectPainter oldDelegate) => false;
}
