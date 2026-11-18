import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';

/// 折线上的一个点：横轴写名称和日期，点上直接标数。
class StudyLinePoint {
  const StudyLinePoint({
    required this.label,
    required this.value,
    required this.valueText,
    this.caption = '',
  });

  final String label;
  final String caption;
  final double value;
  final String valueText;
}

/// 学生学情里的折线图：纵轴从 0（名次从第 1 名）起，一条中性灰的线，只有最新一点
/// 用品牌紫；每个点都标数，没有面积和动画。[reversed] 为 true 时越靠上越好（名次）。
///
/// 读屏读 [semanticLabel]，内容和图下的表格相同。
class StudyLineChart extends StatelessWidget {
  const StudyLineChart({
    required this.points,
    required this.axis,
    required this.semanticLabel,
    this.reversed = false,
    this.ticks,
    super.key,
  });

  final List<StudyLinePoint> points;
  final ChartAxis axis;
  final String semanticLabel;
  final bool reversed;

  /// 刻度；为空时取 [axis] 的刻度。
  final List<double>? ticks;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AppEmptyState(
        icon: Icons.show_chart_rounded,
        title: '暂无可展示的成绩',
        description: '考试出分后会在这里画出走势',
      );
    }
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: CustomPaint(
        size: Size.infinite,
        painter: _LinePainter(
          points: points,
          axis: axis,
          reversed: reversed,
          ticks: ticks ?? axis.ticks,
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.axis,
    required this.reversed,
    required this.ticks,
  });

  final List<StudyLinePoint> points;
  final ChartAxis axis;
  final bool reversed;
  final List<double> ticks;

  static const _padLeft = 40.0;
  static const _padRight = 8.0;
  static const _padTop = 28.0;
  static const _padBottom = 58.0;

  static const _line = AppColors.textPlaceholder;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _padLeft,
      _padTop,
      size.width - _padRight,
      size.height - _padBottom,
    );
    if (plot.width <= 0 || plot.height <= 0) {
      return;
    }
    double yOf(double value) {
      final fraction = axis.fraction(value);
      return reversed
          ? plot.top + fraction * plot.height
          : plot.bottom - fraction * plot.height;
    }

    final count = points.length;
    final slot = plot.width / count;
    double xOf(int index) => plot.left + slot * (index + 0.5);

    final grid = Paint()
      ..color = AppColors.lineSoft
      ..strokeWidth = 1;
    for (final tick in ticks) {
      final y = yOf(tick);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        TextSpan(
          text: formatAxis(tick),
          style: AppText.number(size: 12, color: AppColors.textTertiary),
        ),
        Offset(plot.left - 8, y),
        const Alignment(1, 0),
      );
    }

    for (var i = 0; i < count; i++) {
      final last = i == count - 1;
      final x = xOf(i);
      final name = _text(
        canvas,
        TextSpan(
          text: points[i].label,
          style: last
              ? AppText.caption12Strong.copyWith(color: AppColors.ink)
              : AppText.caption12.copyWith(color: AppColors.textSecondary),
        ),
        Offset(x, plot.bottom + 10),
        const Alignment(0, -1),
        maxWidth: math.max(24, slot - 8),
        maxLines: 2,
      );
      if (points[i].caption.isNotEmpty) {
        _text(
          canvas,
          TextSpan(
            text: points[i].caption,
            style: AppText.number(size: 12, color: AppColors.textTertiary),
          ),
          Offset(x, plot.bottom + 12 + name.height),
          const Alignment(0, -1),
        );
      }
    }

    final offsets = [
      for (var i = 0; i < count; i++) Offset(xOf(i), yOf(points[i].value)),
    ];
    if (count > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final point in offsets.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (var i = 0; i < count; i++) {
      final point = offsets[i];
      final last = i == count - 1;
      if (last) {
        canvas.drawCircle(point, 5, Paint()..color = AppColors.brand);
      } else {
        canvas
          ..drawCircle(point, 4, Paint()..color = AppColors.surface)
          ..drawCircle(
            point,
            4,
            Paint()
              ..color = _line
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      }
      _text(
        canvas,
        _valueSpan(
          points[i].valueText,
          size: last ? 14 : 12,
          color: last ? AppColors.brandDeep : AppColors.textSecondary,
        ),
        Offset(point.dx, point.dy - 10),
        const Alignment(0, 1),
      );
    }
  }

  /// 数字用数字字体，「第 7 名」里的汉字用正文字体（数字字体里没有汉字）。
  static InlineSpan _valueSpan(
    String text, {
    required double size,
    required Color color,
  }) {
    final number = AppText.number(size: size, color: color);
    final words = AppText.caption12.copyWith(color: color);
    return TextSpan(
      children: [
        for (final match in RegExp(r'[0-9.\-+]+|[^0-9.\-+]+').allMatches(text))
          TextSpan(
            text: match[0],
            style: RegExp(r'^[0-9.\-+]+$').hasMatch(match[0]!) ? number : words,
          ),
      ],
    );
  }

  static String formatAxis(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  /// 以 [alignment] 指定的文字锚点对齐到 [anchor]，返回排好的文字。
  TextPainter _text(
    Canvas canvas,
    InlineSpan span,
    Offset anchor,
    Alignment alignment, {
    double maxWidth = double.infinity,
    int maxLines = 1,
  }) {
    final painter = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(
        anchor.dx - painter.width * (alignment.x + 1) / 2,
        anchor.dy - painter.height * (alignment.y + 1) / 2,
      ),
    );
    return painter;
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.reversed != reversed ||
      oldDelegate.axis.min != axis.min ||
      oldDelegate.axis.max != axis.max ||
      !identical(oldDelegate.points, points);
}
