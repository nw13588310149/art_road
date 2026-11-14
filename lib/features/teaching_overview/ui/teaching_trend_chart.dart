import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/teaching_overview_repository.dart';

/// 同一口径的校区均分横向比较，柱形从零起算，数值不由视觉面积推算。
class TeachingComparisonChart extends StatelessWidget {
  const TeachingComparisonChart({required this.rows, super.key});
  final List<TeachingRow> rows;

  @override
  Widget build(BuildContext context) {
    final values = rows.map((r) => (r['value'] as num?)?.toDouble()).toList();
    if (values.whereType<double>().isEmpty) {
      return Center(child: Text('暂无可比较的成绩', style: AppText.body13));
    }
    final high = values.whereType<double>().reduce(math.max);
    final step = math.max(10.0, (high / 40).ceilToDouble() * 10);
    return Semantics(
      label: [
        for (var i = 0; i < rows.length; i++)
          '${rows[i]['label']} ${values[i]?.toStringAsFixed(1) ?? '暂无成绩'} 分',
      ].join('，'),
      child: BarChart(
        duration: Duration.zero,
        BarChartData(
          minY: 0,
          maxY: step * 4,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.line,
              strokeWidth: 1,
              dashArray: [3, 5],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: step,
                reservedSize: 38,
                getTitlesWidget: (value, meta) =>
                    Text(value.toInt().toString(), style: AppText.caption12),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    teachingText(rows[value.toInt()]['label']),
                    style: AppText.body13,
                  ),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${rows[group.x]['label']}\n${values[group.x]?.toStringAsFixed(1) ?? '—'} 分',
                AppText.body13.copyWith(color: AppColors.onBrand),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < rows.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i] ?? 0,
                    width: 42,
                    color: AppColors.brand,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: step * 4,
                      color: AppColors.surfaceSubtle,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 同一份数据生成图形、触摸提示和读屏摘要；缺失值保留断点。
class TeachingTrendChart extends StatelessWidget {
  const TeachingTrendChart({
    required this.rows,
    this.percent = false,
    this.unit = '份',
    super.key,
  });

  final List<TeachingRow> rows;
  final bool percent;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final values = rows
        .map((row) => (row['value'] as num?)?.toDouble())
        .toList();
    if (values.whereType<double>().isEmpty) {
      return Center(child: Text('暂无趋势数据', style: AppText.body13));
    }
    final high = values.whereType<double>().fold(1.0, math.max);
    final step = percent ? 25.0 : math.max(1.0, (high / 4).ceilToDouble());
    final maximum = percent ? 100.0 : step * 4;
    String label(int i) {
      final date = teachingText(rows[i]['date']);
      return date.length >= 10 ? date.substring(5, 10) : date;
    }

    String number(double n) =>
        '${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}${percent ? '%' : ' $unit'}';
    return Semantics(
      label: rows
          .asMap()
          .entries
          .map(
            (e) =>
                '${label(e.key)} ${values[e.key] == null ? '暂无数据' : number(values[e.key]!)}',
          )
          .join('，'),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, right: 14),
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: 0,
            maxX: math.max(1, rows.length - 1).toDouble(),
            minY: 0,
            maxY: maximum,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.line,
                strokeWidth: 1,
                dashArray: [3, 5],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  interval: step,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}${percent ? '%' : ''}',
                    style: AppText.caption12,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) => value.toInt() < rows.length
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            label(value.toInt()),
                            style: AppText.caption12,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                getTooltipItems: (spots) => spots
                    .map(
                      (spot) => LineTooltipItem(
                        '${label(spot.x.toInt())}\n${number(spot.y)}',
                        AppText.caption12Strong.copyWith(
                          color: AppColors.onBrand,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < values.length; i++)
                    values[i] == null
                        ? FlSpot.nullSpot
                        : FlSpot(i.toDouble(), values[i]!),
                ],
                color: AppColors.brand,
                barWidth: 2.5,
                isCurved: false,
                isStrokeCapRound: true,
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.brandWash,
                ),
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.surface,
                        strokeWidth: 2,
                        strokeColor: AppColors.brand,
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
