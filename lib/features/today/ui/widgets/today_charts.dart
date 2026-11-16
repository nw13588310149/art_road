import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/today_models.dart';
import '../today_style.dart';

/// 一张图表卡片：标题、图、一句结论和一个去处。
///
/// 柱状图和折线图可以切到数据表，数值不靠点按才能看到；每张图都有给读屏用的
/// 文字版。图表不做动画。
class TodayChartCard extends StatefulWidget {
  const TodayChartCard({required this.chart, required this.onOpen, super.key});

  final TodayChart chart;
  final ValueChanged<TodayAction> onOpen;

  @override
  State<TodayChartCard> createState() => _TodayChartCardState();
}

class _TodayChartCardState extends State<TodayChartCard> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final action = chart.action;
    final plotted = chart is TodayColumnsChart || chart is TodayLineChart;
    final Widget body;
    if (chart.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s20),
        child: Text(
          chart.empty.isEmpty ? '暂时没有数据' : chart.empty,
          textAlign: TextAlign.center,
          style: AppText.body13,
        ),
      );
    } else if (_table && plotted) {
      body = _DataTable(lines: chart.table);
    } else {
      body = switch (chart) {
        TodayMetersChart() => _Meters(chart: chart),
        TodayColumnsChart() => _described(chart, _Columns(chart: chart)),
        TodayLineChart() => _described(chart, _Line(chart: chart)),
        TodayPartsChart() => _described(chart, _Parts(chart: chart)),
        TodayRoomsChart() => _described(chart, _Rooms(chart: chart)),
        TodayCompareChart() => _described(chart, _Compare(chart: chart)),
      };
    }
    final badge = todayChartBadge(chart);
    final headline = chart.headline;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标 + 标题占满左侧，操作贴右；说明在标题下面，窄卡片里也不会被挤短。
          Row(
            children: [
              TodayIconChip(icon: badge.icon, tint: badge.tint, size: 32),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chart.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong,
                    ),
                    if (chart.subtitle.isNotEmpty)
                      Text(
                        chart.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                  ],
                ),
              ),
              if (plotted && !chart.isEmpty)
                AppIconButton(
                  icon: _table
                      ? Icons.bar_chart_rounded
                      : Icons.table_rows_outlined,
                  semanticLabel: _table
                      ? '${chart.title}：看图表'
                      : '${chart.title}：看数据表',
                  size: AppButtonSize.sm,
                  filled: false,
                  color: AppColors.textTertiary,
                  onTap: () => setState(() => _table = !_table),
                ),
              if (action != null && action.type != 'practiceLog')
                AppButton(
                  label: action.label,
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.sm,
                  onTap: () => widget.onOpen(action),
                ),
            ],
          ),
          if (headline != null && !chart.isEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            _Headline(headline: headline),
          ],
          const SizedBox(height: AppSpace.s12),
          body,
          if (chart.caption.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text(chart.caption, style: AppText.caption12),
          ],
          if (action != null && action.type == 'practiceLog') ...[
            const SizedBox(height: AppSpace.s12),
            AppButton(
              label: action.label,
              icon: Icons.add_rounded,
              variant: AppButtonVariant.quiet,
              size: AppButtonSize.sm,
              expand: true,
              onTap: () => widget.onOpen(action),
            ),
          ],
        ],
      ),
    );
  }

  /// 图形本身对读屏是一整块，读出每一项的文字版。
  Widget _described(TodayChart chart, Widget plot) => Semantics(
    container: true,
    label: '${chart.title}：${chart.table.join('；')}',
    child: ExcludeSemantics(child: plot),
  );
}

/// 图上方的大数字：一眼看到这张图的结论，再往下看走势。
class _Headline extends StatelessWidget {
  const _Headline({required this.headline});

  final TodayHeadline headline;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: headline.value,
                style: AppText.displayNumber(size: 32),
              ),
              if (headline.unit.isNotEmpty)
                TextSpan(
                  text: headline.unit == '%'
                      ? headline.unit
                      : ' ${headline.unit}',
                  style: AppText.body13,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                if (headline.label.isNotEmpty)
                  Flexible(
                    child: Text(
                      headline.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                  ),
                if (headline.delta.isNotEmpty) ...[
                  const SizedBox(width: AppSpace.s8),
                  AppTag(
                    label: headline.delta,
                    tone: headline.deltaGood ? AppTone.success : AppTone.danger,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 数据表：每行一条，和图上的数完全一样。
class _DataTable extends StatelessWidget {
  const _DataTable({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: i < lines.length - 1
                ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.lineSoft),
                    ),
                  )
                : null,
            child: Text(
              lines[i],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body13.copyWith(color: AppColors.ink),
            ),
          ),
      ],
    );
  }
}

String _trim(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

/// 取一个好读的刻度间隔：1、2、5 乘以 10 的幂。
double _niceStep(double raw) {
  if (raw <= 0) return 1;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final ratio = raw / magnitude;
  final nice = ratio <= 1 ? 1 : (ratio <= 2 ? 2 : (ratio <= 5 ? 5 : 10));
  return nice * magnitude;
}

const _gridLine = FlLine(color: AppColors.lineSoft, strokeWidth: 1);

const _noTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

// ───────────────────────── 进度条列表 ─────────────────────────

class _Meters extends StatelessWidget {
  const _Meters({required this.chart});

  final TodayMetersChart chart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chart.rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s12),
          _MeterRow(row: chart.rows[i]),
        ],
      ],
    );
  }
}

class _MeterRow extends StatelessWidget {
  const _MeterRow({required this.row});

  final TodayMeterRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body13.copyWith(color: AppColors.ink),
                    ),
                  ),
                  if (row.tag.isNotEmpty) ...[
                    const SizedBox(width: AppSpace.s8),
                    AppTag(
                      label: row.tag,
                      tone: AppTone.warning,
                      icon: Icons.priority_high_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Text(row.text, style: AppText.number(size: 13)),
          ],
        ),
        const SizedBox(height: 6),
        AppProgressBar(
          value: row.ratio,
          color: TodayPalette.tone(row.tone),
          trackColor: TodayPalette.trackOf(row.tone),
        ),
        if (row.caption.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s4),
          Text(
            row.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption12,
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── 柱状图 ─────────────────────────

class _Columns extends StatelessWidget {
  const _Columns({required this.chart});

  final TodayColumnsChart chart;

  @override
  Widget build(BuildContext context) {
    final items = chart.items;
    var high = 1.0;
    for (final item in items) {
      high = math.max(high, math.max(item.value ?? 0, item.total ?? 0));
    }
    var step = _niceStep(high / 2);
    var top = (high / step).ceil() * step;
    if (top > high * 1.4 && step >= 2) {
      step = step / 2;
      top = (high / step).ceil() * step;
    }
    return SizedBox(
      height: 124,
      child: BarChart(
        duration: Duration.zero,
        BarChartData(
          minY: 0,
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) => _gridLine,
          ),
          titlesData: FlTitlesData(
            topTitles: _noTitles,
            rightTitles: _noTitles,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: step,
                getTitlesWidget: (value, meta) =>
                    Text(_trim(value), style: AppText.caption12),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= items.length) {
                    return const SizedBox.shrink();
                  }
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      item.label,
                      style: item.emphasis
                          ? AppText.caption12Strong.copyWith(
                              color: AppColors.ink,
                            )
                          : AppText.caption12,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.ink,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = items[group.x];
                if (item.value == null) return null;
                return BarTooltipItem(
                  item.note.isNotEmpty
                      ? item.note
                      : '${item.label} ${_trim(item.value!)}${chart.unit}',
                  AppText.caption12Strong.copyWith(color: AppColors.onBrand),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < items.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: items[i].value ?? 0,
                    width: 16,
                    color: items[i].emphasis ? null : TodayPalette.brandMuted,
                    gradient: items[i].emphasis
                        ? TodayPalette.barGradient
                        : null,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: items[i].total != null,
                      toY: items[i].total ?? 0,
                      color: TodayPalette.track,
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

// ───────────────────────── 折线图 ─────────────────────────

class _Line extends StatelessWidget {
  const _Line({required this.chart});

  final TodayLineChart chart;

  @override
  Widget build(BuildContext context) {
    final points = chart.points;
    final values = [for (final p in points) ?p.value];
    final target = chart.target;
    final low = [...values, ?target].reduce(math.min);
    final high = [...values, ?target].reduce(math.max);
    final step = _niceStep(math.max(1, high - low) / 3);
    var bottom = (low / step).floor() * step;
    if (bottom > 0 && low - bottom < step * 0.25) bottom -= step;
    bottom = math.max(0, bottom);
    var top = (high / step).ceil() * step;
    if (top - high < step * 0.25) top += step;
    if (chart.unit == '%') top = math.min(100, top);
    if (top <= bottom) top = bottom + step;

    var last = -1;
    for (var i = 0; i < points.length; i++) {
      if (points[i].value != null) last = i;
    }
    final every = points.length > 7 ? 2 : 1;
    // 有的日子没有数时线会断开，孤立的点连不成线，所以每个点都画出来。
    final sparse = points.any((p) => p.value == null);
    final bar = LineChartBarData(
      spots: [
        for (var i = 0; i < points.length; i++)
          points[i].value == null
              ? FlSpot.nullSpot
              : FlSpot(i.toDouble(), points[i].value!),
      ],
      color: TodayPalette.brand,
      barWidth: 2,
      isCurved: true,
      curveSmoothness: 0.22,
      preventCurveOverShooting: true,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TodayPalette.brand.withValues(alpha: 0.18),
            TodayPalette.brand.withValues(alpha: 0),
          ],
        ),
      ),
      dotData: FlDotData(
        checkToShowDot: (spot, _) => sparse || spot.x == last,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: spot.x == last ? 4 : 3,
          color: TodayPalette.brand,
          strokeWidth: 2,
          strokeColor: AppColors.surface,
        ),
      ),
    );
    return SizedBox(
      height: 132,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.s8, right: AppSpace.s12),
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: 0,
            maxX: math.max(1, points.length - 1).toDouble(),
            minY: bottom,
            maxY: top,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) => _gridLine,
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (target != null)
                  HorizontalLine(
                    y: target,
                    color: AppColors.textTertiary,
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                    label: HorizontalLineLabel(
                      show: chart.targetLabel.isNotEmpty,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(bottom: 2),
                      style: AppText.caption12,
                      labelResolver: (_) => '目标 ${chart.targetLabel}',
                    ),
                  ),
              ],
            ),
            titlesData: FlTitlesData(
              topTitles: _noTitles,
              rightTitles: _noTitles,
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: step,
                  getTitlesWidget: (value, meta) =>
                      Text(_trim(value), style: AppText.caption12),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (value != index ||
                        index < 0 ||
                        index >= points.length ||
                        (points.length - 1 - index) % every != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        points[index].label,
                        style: AppText.caption12,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      points[spot.x.toInt()].note.isNotEmpty
                          ? points[spot.x.toInt()].note
                          : '${points[spot.x.toInt()].label} '
                                '${_trim(spot.y)}${chart.unit}',
                      AppText.caption12Strong.copyWith(
                        color: AppColors.onBrand,
                      ),
                    ),
                ],
              ),
            ),
            lineBarsData: [bar],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 分段条 ─────────────────────────

class _Parts extends StatelessWidget {
  const _Parts({required this.chart});

  final TodayPartsChart chart;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final part in chart.parts)
        if (part.value > 0) part,
    ];
    final total = chart.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            const gap = 2.0;
            final width = box.maxWidth - gap * (shown.length - 1);
            return Row(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  () {
                    final part = shown[i];
                    // 太窄的一段至少留 6 宽，看得见；数字只在放得下时写在里面。
                    final w = math.max(6.0, width * part.value / total);
                    return Flexible(
                      flex: (w * 100).round(),
                      child: Container(
                        height: 28,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: TodayPalette.tone(part.tone),
                          borderRadius: AppRadius.br4,
                        ),
                        child: w >= 36
                            ? Text(
                                _trim(part.value),
                                maxLines: 1,
                                style: AppText.number(
                                  size: 13,
                                  color: TodayPalette.onTone(part.tone),
                                ),
                              )
                            : null,
                      ),
                    );
                  }(),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpace.s12),
        Wrap(
          spacing: AppSpace.s16,
          runSpacing: AppSpace.s8,
          children: [
            for (final part in chart.parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: TodayPalette.tone(part.tone),
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(part.label, style: AppText.body13),
                  const SizedBox(width: 6),
                  Text(
                    '${_trim(part.value)} ${chart.unit}',
                    style: AppText.number(size: 13),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────── 宿舍状态格 ─────────────────────────

class _Rooms extends StatelessWidget {
  const _Rooms({required this.chart});

  final TodayRoomsChart chart;

  static const _states = [
    ('done', '已查完'),
    ('pending', '有人没打卡'),
    ('issue', '有晚归或缺勤'),
  ];

  static Color _fill(String state) => switch (state) {
    'issue' => AppColors.dangerSoft,
    'pending' => AppColors.warningSoft,
    _ => AppColors.successSoft,
  };

  static Color _dot(String state) => switch (state) {
    'issue' => TodayPalette.bad,
    'pending' => TodayPalette.caution,
    _ => TodayPalette.good,
  };

  @override
  Widget build(BuildContext context) {
    final buildings = <String, List<TodayRoom>>{};
    for (final room in chart.rooms) {
      (buildings[room.building] ??= <TodayRoom>[]).add(room);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in buildings.entries) ...[
          Text(entry.key, style: AppText.caption12Strong),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final room in entry.value)
                Container(
                  width: 52,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _fill(room.state),
                    borderRadius: AppRadius.br8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        room.name,
                        style: AppText.caption12Strong.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${room.checked}/${room.total}',
                        style: AppText.number(
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
        ],
        Wrap(
          spacing: AppSpace.s12,
          runSpacing: AppSpace.s4,
          children: [
            for (final state in _states)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _dot(state.$1),
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(state.$2, style: AppText.caption12),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────── 对比表 ─────────────────────────

class _Compare extends StatelessWidget {
  const _Compare({required this.chart});

  final TodayCompareChart chart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 64),
            for (final column in chart.columns)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpace.s8),
                  child: Text(
                    column,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ),
              ),
          ],
        ),
        for (final row in chart.rows) ...[
          const SizedBox(height: AppSpace.s12),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body13.copyWith(color: AppColors.ink),
                ),
              ),
              for (final cell in row.cells)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpace.s8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cell.text, style: AppText.number(size: 13)),
                        const SizedBox(height: 4),
                        AppProgressBar(
                          value: cell.ratio,
                          height: 4,
                          color: TodayPalette.brand,
                          trackColor: AppColors.brandTint,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── 人与事 ─────────────────────────

/// 需要跟进的人或事：点一行看详情，跟进后标记一下，下次一眼知道哪些还没管。
class TodayPeopleCard extends StatelessWidget {
  const TodayPeopleCard({
    required this.people,
    required this.busy,
    required this.onOpen,
    required this.onFollow,
    super.key,
  });

  final TodayPeople people;
  final Set<String> busy;
  final ValueChanged<TodayAction> onOpen;
  final ValueChanged<TodayPerson> onFollow;

  @override
  Widget build(BuildContext context) {
    final rows = people.rows;
    final followed = rows.where((row) => row.followed).length;
    return AppCard(
      title: people.title,
      subtitle: rows.isEmpty
          ? null
          : '${people.followLabel} $followed / ${rows.length}',
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Text(people.empty, style: AppText.body13),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < rows.length; i++)
                  _PersonRow(
                    person: rows[i],
                    followLabel: people.followLabel,
                    busy: busy.contains('person:${rows[i].id}'),
                    divider: i < rows.length - 1,
                    onOpen: onOpen,
                    onFollow: () => onFollow(rows[i]),
                  ),
              ],
            ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.followLabel,
    required this.busy,
    required this.divider,
    required this.onOpen,
    required this.onFollow,
  });

  final TodayPerson person;
  final String followLabel;
  final bool busy;
  final bool divider;
  final ValueChanged<TodayAction> onOpen;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final action = person.action;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: divider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
            )
          : null,
      child: Row(
        children: [
          ExcludeSemantics(
            child: _Avatar(name: person.name, muted: person.followed),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: AppPressable(
              onTap: action == null ? null : () => onOpen(action),
              semanticLabel:
                  '${person.name}，${person.value}，${person.detail}'
                  '${person.followed ? '，$followLabel' : ''}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: person.followed
                              ? AppText.body14.copyWith(
                                  color: AppColors.textSecondary,
                                )
                              : AppText.body14Strong,
                        ),
                      ),
                      if (person.value.isNotEmpty) ...[
                        const SizedBox(width: AppSpace.s8),
                        AppTag(label: person.value),
                      ],
                    ],
                  ),
                  if (person.detail.isNotEmpty)
                    Text(
                      person.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          AppButton(
            label: person.followed ? followLabel : '标记$followLabel',
            icon: person.followed ? Icons.check_rounded : null,
            size: AppButtonSize.sm,
            variant: person.followed
                ? AppButtonVariant.text
                : AppButtonVariant.secondary,
            enabled: !busy,
            onTap: onFollow,
          ),
        ],
      ),
    );
  }
}

/// 姓名首字的圆形头像，颜色按姓名固定。
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.muted = false});

  final String name;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    const tints = [
      TodayTint.purple,
      TodayTint.teal,
      TodayTint.pink,
      TodayTint.blue,
      TodayTint.amber,
    ];
    final tint = tints[name.isEmpty ? 0 : name.codeUnitAt(0) % tints.length];
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceSubtle : tint.soft,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? '' : name.substring(0, 1),
        style: AppText.body14Strong.copyWith(
          color: muted ? AppColors.textTertiary : tint.color,
        ),
      ),
    );
  }
}
