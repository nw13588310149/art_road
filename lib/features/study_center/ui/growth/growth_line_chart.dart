import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';

/// 成长曲线折线图：网格 + 坐标、渐变面积、数值标注、末点高亮；
/// 排名指标纵轴反向（越靠上名次越好）。
class GrowthLineChart extends StatelessWidget {
  const GrowthLineChart({
    required this.points,
    required this.metric,
    this.color = ArtColors.brand,
    super.key,
  });

  final List<GrowthPoint> points;
  final GrowthMetric metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final data = [
      for (final point in points)
        if (point.value != null) point,
    ];
    if (data.isEmpty) {
      return const ArtEmptyState(
        message: '暂无可展示的成绩',
        icon: Icons.show_chart_rounded,
      );
    }
    final signature =
        '${metric.name}|${data.map((p) => '${p.examId}:${p.value}').join(',')}';
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(signature),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => CustomPaint(
        size: Size.infinite,
        painter: _GrowthChartPainter(
          points: data,
          metric: metric,
          color: color,
          progress: progress,
        ),
      ),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  _GrowthChartPainter({
    required this.points,
    required this.metric,
    required this.color,
    required this.progress,
  });

  final List<GrowthPoint> points;
  final GrowthMetric metric;
  final Color color;
  final double progress;

  static const _padLeft = 46.0;
  static const _padRight = 24.0;
  static const _padTop = 40.0;
  static const _padBottom = 50.0;

  static const _axisStyle = TextStyle(
    fontSize: 11,
    height: 1.2,
    color: ArtColors.ink3,
    fontFamily: 'Manrope',
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const _dateStyle = TextStyle(
    fontSize: 10,
    height: 1.2,
    color: ArtColors.ink4,
    fontFamily: 'Manrope',
  );

  bool get _ranking => metric == GrowthMetric.ranking;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _padLeft,
      _padTop,
      size.width - _padRight,
      size.height - _padBottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final values = [for (final point in points) point.value!];
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    double? ceiling;
    if (!_ranking) {
      for (final point in points) {
        final full = point.maxScore;
        if (full != null && (ceiling == null || full > ceiling)) {
          ceiling = full;
        }
      }
    }
    final axis = niceAxis(
      low,
      high,
      integer: _ranking,
      floor: _ranking ? 1 : 0,
      ceiling: ceiling,
    );
    double yOf(double value) {
      final fraction = axis.fraction(value);
      return _ranking
          ? plot.top + fraction * plot.height
          : plot.bottom - fraction * plot.height;
    }

    final count = points.length;
    final inset = count == 1 ? 0.0 : math.min(32.0, plot.width / (count * 2));
    double xOf(int index) => count == 1
        ? plot.center.dx
        : plot.left + inset + index * (plot.width - inset * 2) / (count - 1);

    final grid = Paint()
      ..color = ArtColors.line
      ..strokeWidth = 1;
    for (final tick in axis.ticks) {
      final y = yOf(tick);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _paintText(
        canvas,
        TextSpan(text: formatScore(tick), style: _axisStyle),
        Offset(plot.left - 10, y),
        const Alignment(1, 0),
      );
    }

    for (var i = 0; i < count; i++) {
      final last = i == count - 1;
      final x = xOf(i);
      _paintText(
        canvas,
        TextSpan(
          text: shortExamName(points[i].examName),
          style: ArtText.caption(
            size: 11,
            color: last ? ArtColors.brandDeep : ArtColors.ink2,
          ),
        ),
        Offset(x, plot.bottom + 10),
        const Alignment(0, -1),
      );
      _paintText(
        canvas,
        TextSpan(text: studyShortDate(points[i].examTime), style: _dateStyle),
        Offset(x, plot.bottom + 28),
        const Alignment(0, -1),
      );
    }

    final offsets = [
      for (var i = 0; i < count; i++) Offset(xOf(i), yOf(values[i])),
    ];
    final revealX = count == 1
        ? size.width
        : offsets.first.dx + (offsets.last.dx - offsets.first.dx) * progress;

    if (count > 1) {
      final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (var i = 1; i < count; i++) {
        final from = offsets[i - 1];
        final to = offsets[i];
        final midX = (from.dx + to.dx) / 2;
        line.cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy);
      }
      final area = Path.from(line)
        ..lineTo(offsets.last.dx, plot.bottom)
        ..lineTo(offsets.first.dx, plot.bottom)
        ..close();
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(0, 0, revealX + 1, size.height))
        ..drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0),
              ],
            ).createShader(plot),
        )
        ..drawPath(
          line,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        )
        ..restore();
    }

    for (var i = 0; i < count; i++) {
      final point = offsets[i];
      if (count > 1 && point.dx > revealX + 0.5) continue;
      final last = i == count - 1;
      if (last) {
        canvas
          ..drawCircle(
            point,
            11,
            Paint()..color = color.withValues(alpha: 0.16),
          )
          ..drawCircle(point, 6, Paint()..color = color)
          ..drawCircle(point, 2.6, Paint()..color = Colors.white);
        _paintBubble(canvas, size, _valueSpan(values[i], Colors.white), point);
      } else {
        canvas
          ..drawCircle(point, 4.5, Paint()..color = Colors.white)
          ..drawCircle(
            point,
            4.5,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        _paintText(
          canvas,
          _valueSpan(values[i], ArtColors.ink2),
          Offset(point.dx, point.dy - 9),
          const Alignment(0, 1),
        );
      }
    }
  }

  InlineSpan _valueSpan(double value, Color textColor) {
    final number = TextStyle(
      fontSize: 12,
      height: 1.2,
      color: textColor,
      fontFamily: 'Manrope',
      fontWeight: FontWeight.w500,
    );
    if (!_ranking) return TextSpan(text: formatScore(value), style: number);
    final unit = ArtText.caption(size: 10, color: textColor);
    return TextSpan(
      children: [
        TextSpan(text: '第', style: unit),
        TextSpan(text: formatScore(value), style: number),
        TextSpan(text: '名', style: unit),
      ],
    );
  }

  /// 以 [alignment] 指定的文字锚点对齐到 [anchor]。
  void _paintText(
    Canvas canvas,
    InlineSpan span,
    Offset anchor,
    Alignment alignment,
  ) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        anchor.dx - painter.width * (alignment.x + 1) / 2,
        anchor.dy - painter.height * (alignment.y + 1) / 2,
      ),
    );
  }

  void _paintBubble(Canvas canvas, Size size, InlineSpan span, Offset point) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    const padH = 9.0;
    const padV = 4.0;
    const gap = 14.0;
    final width = painter.width + padH * 2;
    final height = painter.height + padV * 2;
    final maxLeft = math.max(2.0, size.width - width - 2);
    final left = math.min(maxLeft, math.max(2.0, point.dx - width / 2));
    final above = point.dy - gap - height >= 0;
    final top = above ? point.dy - gap - height : point.dy + gap;
    final fill = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, height),
        Radius.circular(height / 2),
      ),
      fill,
    );
    final tipY = above ? top + height : top;
    final pointer = Path()
      ..moveTo(point.dx - 4, tipY)
      ..lineTo(point.dx + 4, tipY)
      ..lineTo(point.dx, above ? tipY + 4 : tipY - 4)
      ..close();
    canvas.drawPath(pointer, fill);
    painter.paint(canvas, Offset(left + padH, top + padV));
  }

  @override
  bool shouldRepaint(_GrowthChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.metric != metric ||
      oldDelegate.color != color ||
      !identical(oldDelegate.points, points);
}
