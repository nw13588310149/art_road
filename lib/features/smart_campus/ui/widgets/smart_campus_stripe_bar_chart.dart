import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../../../shell/ui/shell_layout.dart';

const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kGridLine = Color(0xFFE6E9F1);

/// 智慧校园通用柱形图数据项（班级工作台「七日查寝」、学生「均分柱形」等共用）。
class SmartCampusBarChartEntry {
  const SmartCampusBarChartEntry({
    required this.label,
    required this.value,
    this.labelIsHint = false,
  });

  final String label;
  final double value;

  /// X 轴标签是否以占位/空态样式展示。
  final bool labelIsHint;
}

/// 与班主任班级工作台「七日查寝」一致的紫斜纹柱形图。
class SmartCampusStripeBarChart extends StatelessWidget {
  const SmartCampusStripeBarChart({
    super.key,
    required this.entries,
    required this.ticks,
    this.yAxisUnit,
    this.maxValue,
    this.formatValueLabel,
    this.chartHeight,
    this.tickGap = 22,
    this.yAxisWidth = 28,
    this.yAxisToPlotGap = 8,
    this.barWidth = 28,
    this.columnGap = 28,
    this.bottomInset = 10,
    this.xAxisLabelGap = 0,
    this.showGridLines = true,
    this.valueLabelGap = 4,
    this.plotTopInset,
    this.xAxisLabelInset,
  });

  final List<SmartCampusBarChartEntry> entries;
  final List<int> ticks;

  /// Y 轴顶部单位，如「人」「分」；为 null 时不展示。
  final String? yAxisUnit;

  /// 柱高比例分母，默认取 [ticks] 首项。
  final double? maxValue;

  /// 柱顶数值文案；默认整数化展示。
  final String Function(double value)? formatValueLabel;

  /// 绘图区高度（设计稿 px）；默认 [designChartHeight]。
  final double? chartHeight;

  /// Y 轴刻度行间距（设计稿 px）。
  final double tickGap;

  /// Y 轴标签列宽（设计稿 px）。
  final double yAxisWidth;

  /// Y 轴与绘图区水平间距（设计稿 px）。
  final double yAxisToPlotGap;

  /// 单柱宽度（设计稿 px）。
  final double barWidth;

  /// 柱列间距（设计稿 px）。
  final double columnGap;

  /// 绘图区底部留白（设计稿 px）。
  final double bottomInset;

  /// X 轴标签与绘图区垂直间距（设计稿 px）。
  final double xAxisLabelGap;

  /// 是否绘制水平网格线。
  final bool showGridLines;

  /// 柱顶数值与柱顶间距（设计稿 px）。
  final double valueLabelGap;

  /// 绘图区顶部对齐留白；为 null 时无 Y 轴单位则 29，否则 0。
  final double? plotTopInset;

  /// X 轴标签左侧缩进；为 null 时取 [yAxisWidth] + [yAxisToPlotGap]。
  final double? xAxisLabelInset;

  static const double designChartHeight = 230;

  static String defaultValueLabel(double value) {
    if (value <= 0) return '';
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final labelForValue = formatValueLabel ?? defaultValueLabel;
    final resolvedChartHeight = chartHeight ?? designChartHeight;

    const tickRowHeight = 20.0;
    final tickCount = ticks.length;
    final tickRowH = ui(tickRowHeight);
    final tickGapPx = ui(tickGap);
    final nominalBaselineY = SmartCampusChartGridPainter.baselineY(
      tickRowHeight: tickRowH,
      tickGap: tickGapPx,
      tickCount: tickCount,
    );
    final nominalContentHeight = nominalBaselineY + ui(bottomInset);
    final chartHeightPx = ui(resolvedChartHeight);
    final topPadding = math.max(0.0, chartHeightPx - nominalContentHeight);
    final barBottomInset = ui(bottomInset);
    final scaleBarHeightPx = SmartCampusChartGridPainter.valueToBarHeight(
      value: ticks.first.toDouble(),
      ticks: ticks,
      tickRowHeight: tickRowH,
      tickGap: tickGapPx,
      tickCount: tickCount,
    );
    final resolvedPlotTopInset = ui(
      plotTopInset ?? (yAxisUnit == null ? 29.0 : 0.0),
    );
    final yAxisWidthPx = ui(yAxisWidth);
    final yAxisToPlotGapPx = ui(yAxisToPlotGap);
    final xLabelInsetPx = ui(xAxisLabelInset ?? (yAxisWidth + yAxisToPlotGap));
    final columnGapPx = ui(columnGap);
    final barWidthPx = ui(barWidth);
    final valueLabelGapPx = ui(valueLabelGap);
    final xAxisLabelGapPx = ui(xAxisLabelGap);

    Widget chartPlotArea({required Widget child}) {
      return SizedBox(
        height: chartHeightPx,
        child: Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: SizedBox(
            height: nominalContentHeight,
            child: child,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: yAxisWidthPx,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (yAxisUnit != null) ...[
                    SizedBox(
                      height: ui(21),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          yAxisUnit!,
                          style: SmartCampusChartYAxis.labelStyle(ui),
                        ),
                      ),
                    ),
                    SizedBox(height: ui(8)),
                  ] else if (resolvedPlotTopInset > 0)
                    SizedBox(height: resolvedPlotTopInset),
                  SizedBox(
                    height: chartHeightPx,
                    child: Padding(
                      padding: EdgeInsets.only(top: topPadding),
                      child: SizedBox(
                        height: nominalContentHeight,
                        child: SmartCampusChartYAxis(
                          ticks: ticks,
                          tickGap: tickGap,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: yAxisToPlotGapPx),
            Expanded(
              child: Column(
                children: [
                  if (resolvedPlotTopInset > 0)
                    SizedBox(height: resolvedPlotTopInset),
                  chartPlotArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (showGridLines)
                              CustomPaint(
                                size: Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                                painter: SmartCampusChartGridPainter(
                                  tickRowHeight: tickRowH,
                                  tickGap: tickGapPx,
                                  tickCount: tickCount,
                                ),
                              ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: barBottomInset,
                              height: scaleBarHeightPx,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (var i = 0; i < entries.length; i++) ...[
                                    if (i > 0) SizedBox(width: columnGapPx),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: SmartCampusStripeBarColumn(
                                          value: entries[i].value,
                                          valueLabel: labelForValue(
                                            entries[i].value,
                                          ),
                                          ticks: ticks,
                                          tickRowHeight: tickRowH,
                                          tickGap: tickGapPx,
                                          tickCount: tickCount,
                                          scaleBarHeight: scaleBarHeightPx,
                                          barWidth: barWidthPx,
                                          valueLabelGap: valueLabelGapPx,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (xAxisLabelGapPx > 0) SizedBox(height: xAxisLabelGapPx),
        Padding(
          padding: EdgeInsets.only(left: xLabelInsetPx),
          child: Row(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) SizedBox(width: columnGapPx),
                Expanded(
                  child: Text(
                    entries[i].label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: entries[i].labelIsHint
                          ? _kTextHint
                          : _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 20 / 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SmartCampusChartYAxis extends StatelessWidget {
  const SmartCampusChartYAxis({
    super.key,
    required this.ticks,
    this.tickGap = 22,
  });

  final List<int> ticks;
  final double tickGap;

  static TextStyle labelStyle(double Function(double) ui) {
    return TextStyle(
      fontSize: ui(12),
      color: _kTextHint,
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w400,
      height: 20 / 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final style = labelStyle(ui);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < ticks.length; i++) ...[
          SizedBox(
            height: ui(20),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                ticks[i].toString(),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.right,
                style: style,
              ),
            ),
          ),
          if (i < ticks.length - 1) SizedBox(height: ui(tickGap)),
        ],
      ],
    );
  }
}

class SmartCampusStripeBarColumn extends StatelessWidget {
  const SmartCampusStripeBarColumn({
    super.key,
    required this.value,
    required this.valueLabel,
    required this.ticks,
    required this.tickRowHeight,
    required this.tickGap,
    required this.tickCount,
    required this.scaleBarHeight,
    required this.barWidth,
    required this.valueLabelGap,
  });

  final double value;
  final String valueLabel;
  final List<int> ticks;
  final double tickRowHeight;
  final double tickGap;
  final int tickCount;
  final double scaleBarHeight;
  final double barWidth;
  final double valueLabelGap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final barH = SmartCampusChartGridPainter.valueToBarHeight(
      value: value,
      ticks: ticks,
      tickRowHeight: tickRowHeight,
      tickGap: tickGap,
      tickCount: tickCount,
    );

    return SizedBox(
      width: barWidth,
      height: scaleBarHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          if (barH > 0)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ui(8)),
                topRight: Radius.circular(ui(8)),
              ),
              child: SizedBox(
                width: barWidth,
                height: barH,
                child: const CustomPaint(
                  painter: SmartCampusStripeBarPainter(
                    colorA: Color(0xFFC29EFF),
                    colorB: Color(0xFFC9A6FF),
                  ),
                ),
              ),
            ),
          if (valueLabel.isNotEmpty)
            Positioned(
              bottom: barH + valueLabelGap,
              child: Text(
                valueLabel,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 20 / 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 双色斜纹柱体（-30°，带宽 10、间距 7），与班级工作台七日查寝一致。
class SmartCampusStripeBarPainter extends CustomPainter {
  const SmartCampusStripeBarPainter({
    required this.colorA,
    required this.colorB,
  });

  final Color colorA;
  final Color colorB;

  static const double _angleRad = -30 * math.pi / 180;
  static const double _stripeThickness = 10;
  static const double _stripeGap = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final period = _stripeThickness + _stripeGap;
    final extent = size.width + size.height + 200;

    canvas.drawRect(Offset.zero & size, Paint()..color = colorB);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width * 0.5, size.height);
    canvas.rotate(_angleRad);

    for (var offset = -extent, i = 0; offset < extent; offset += period, i++) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, offset),
          width: extent * 2,
          height: _stripeThickness,
        ),
        Paint()..color = i.isEven ? colorA : colorB,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, offset + _stripeThickness + _stripeGap / 2),
          width: extent * 2,
          height: _stripeGap,
        ),
        Paint()..color = i.isEven ? colorB : colorA,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SmartCampusStripeBarPainter oldDelegate) {
    return oldDelegate.colorA != colorA || oldDelegate.colorB != colorB;
  }
}

class SmartCampusChartGridPainter extends CustomPainter {
  const SmartCampusChartGridPainter({
    required this.tickRowHeight,
    required this.tickGap,
    required this.tickCount,
  });

  final double tickRowHeight;
  final double tickGap;
  final int tickCount;

  static double baselineY({
    required double tickRowHeight,
    required double tickGap,
    required int tickCount,
  }) {
    return tickRowHeight / 2 + (tickCount - 1) * (tickRowHeight + tickGap);
  }

  static double tickCenterY({
    required int index,
    required double tickRowHeight,
    required double tickGap,
  }) {
    return tickRowHeight / 2 + index * (tickRowHeight + tickGap);
  }

  /// 按 Y 轴刻度分段插值（各段视觉等距，段内线性），与网格线对齐。
  static double valueToY({
    required double value,
    required List<int> ticks,
    required double tickRowHeight,
    required double tickGap,
  }) {
    if (ticks.isEmpty) return 0;

    final top = ticks.first.toDouble();
    final bottom = ticks.last.toDouble();
    final v = value.clamp(bottom, top);

    if (v >= top) {
      return tickCenterY(
        index: 0,
        tickRowHeight: tickRowHeight,
        tickGap: tickGap,
      );
    }
    if (v <= bottom) {
      return tickCenterY(
        index: ticks.length - 1,
        tickRowHeight: tickRowHeight,
        tickGap: tickGap,
      );
    }

    for (var i = 0; i < ticks.length - 1; i++) {
      final upper = ticks[i].toDouble();
      final lower = ticks[i + 1].toDouble();
      if (v <= upper && v >= lower) {
        final yUpper = tickCenterY(
          index: i,
          tickRowHeight: tickRowHeight,
          tickGap: tickGap,
        );
        final yLower = tickCenterY(
          index: i + 1,
          tickRowHeight: tickRowHeight,
          tickGap: tickGap,
        );
        if (upper == lower) return yLower;
        final t = (upper - v) / (upper - lower);
        return yUpper + t * (yLower - yUpper);
      }
    }

    return tickCenterY(
      index: ticks.length - 1,
      tickRowHeight: tickRowHeight,
      tickGap: tickGap,
    );
  }

  /// 从 X 轴基线到 [value] 对应刻度位置的柱体高度。
  static double valueToBarHeight({
    required double value,
    required List<int> ticks,
    required double tickRowHeight,
    required double tickGap,
    required int tickCount,
  }) {
    final baseline = baselineY(
      tickRowHeight: tickRowHeight,
      tickGap: tickGap,
      tickCount: tickCount,
    );
    final y = valueToY(
      value: value,
      ticks: ticks,
      tickRowHeight: tickRowHeight,
      tickGap: tickGap,
    );
    return (baseline - y).clamp(0.0, double.infinity);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kGridLine
      ..strokeWidth = 1;

    var y = tickRowHeight / 2;
    for (var i = 0; i < tickCount - 1; i++) {
      _paintDashedLine(
        canvas,
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
      y += tickRowHeight + tickGap;
    }
    final baseline = baselineY(
      tickRowHeight: tickRowHeight,
      tickGap: tickGap,
      tickCount: tickCount,
    );
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      paint,
    );
  }

  static void _paintDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segEnd = math.min(drawn + dashWidth, total);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * segEnd,
        paint,
      );
      drawn += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant SmartCampusChartGridPainter oldDelegate) {
    return oldDelegate.tickRowHeight != tickRowHeight ||
        oldDelegate.tickGap != tickGap ||
        oldDelegate.tickCount != tickCount;
  }
}
