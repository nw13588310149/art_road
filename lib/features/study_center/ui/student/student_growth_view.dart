import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/study_growth_controller.dart';
import 'student_line_chart.dart';
import 'student_study_parts.dart';

/// 学生本人的成长曲线：按科目筛选，分数和名次两种走势，下面是同一组数据的表格。
///
/// 从总览切过来时页头是「学情」加视图切换；从成绩报告点进来时（[onBack] 不为空）
/// 是带返回的「成长曲线」。
class StudentGrowthView extends ConsumerWidget {
  const StudentGrowthView({required this.onSelectTab, this.onBack, super.key});

  final ValueChanged<StudentStudyTab> onSelectTab;
  final VoidCallback? onBack;

  static const _defaultTabs = <GrowthTab>[
    GrowthTab(label: '总分'),
    GrowthTab(subjectName: '素描', label: '素描'),
    GrowthTab(subjectName: '色彩', label: '色彩'),
    GrowthTab(subjectName: '速写', label: '速写'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studyGrowthControllerProvider('');
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen<StudyGrowthState>(provider, (previous, next) {
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) {
        return;
      }
      AppToast.showError(context, message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.clearError();
        }
      });
    });

    final result = state.result;
    final tabs = result == null || result.tabs.isEmpty
        ? _defaultTabs
        : result.tabs;
    final back = onBack;
    return AppPageBody(
      builder: (context, wide) {
        final Widget body;
        if (result == null) {
          body = state.failed
              ? SizedBox(
                  height: 360,
                  child: AppErrorState(
                    title: '成长曲线加载失败',
                    description: state.errorMessage.isEmpty
                        ? '请检查网络后重试'
                        : state.errorMessage,
                    onRetry: controller.load,
                  ),
                )
              : const AppSkeleton(height: 360);
        } else {
          final subjectName = state.resultSubjectName;
          final label = tabs
              .firstWhere(
                (tab) => tab.subjectName == subjectName,
                orElse: () => GrowthTab(
                  subjectName: subjectName,
                  label: subjectName.isEmpty ? '总分' : subjectName,
                ),
              )
              .label;
          body = StudentColumns(
            wide: wide,
            main: _TrendSection(
              label: label,
              result: result,
              metric: state.resultMetric,
              selectedMetric: state.metric,
              loading: state.loading,
              onMetricChanged: controller.selectMetric,
            ),
            side: _GrowthSide(
              statistics: result.statistics,
              metric: state.resultMetric,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (back != null)
              AppTitleBar(title: '成长曲线', onBack: back)
            else
              StudentStudyTitleBar(
                selected: StudentStudyTab.growth,
                onSelect: onSelectTab,
              ),
            const SizedBox(height: AppSpace.s12),
            AppFilterBar<String>(
              items: [
                for (final tab in tabs)
                  AppFilterItem(value: tab.subjectName, label: tab.label),
              ],
              value: state.subjectName,
              onChanged: controller.selectSubject,
            ),
            const SizedBox(height: AppSpace.s24),
            body,
          ],
        );
      },
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.label,
    required this.result,
    required this.metric,
    required this.selectedMetric,
    required this.loading,
    required this.onMetricChanged,
  });

  final String label;
  final GrowthResult result;

  /// 图上数据的口径；切换后新数据回来之前仍按旧口径画。
  final GrowthMetric metric;
  final GrowthMetric selectedMetric;
  final bool loading;
  final ValueChanged<GrowthMetric> onMetricChanged;

  bool get _ranking => metric == GrowthMetric.ranking;

  static String _axisName(String name) =>
      name.replaceAll(RegExp(r'\s+'), '').replaceFirst(RegExp(r'^\d{4}年'), '');

  String _valueText(double value) =>
      _ranking ? '第 ${value.round()} 名' : formatScore(value);

  @override
  Widget build(BuildContext context) {
    final valued = [
      for (final point in result.points)
        if (point.value != null) point,
    ];
    final points = [
      for (final point in valued)
        StudyLinePoint(
          label: _axisName(point.examName),
          caption: studyShortDate(point.examTime),
          value: point.value!,
          valueText: _valueText(point.value!),
        ),
    ];
    final ChartAxis axis;
    List<double>? ticks;
    if (_ranking) {
      var bottom = 1;
      for (final point in valued) {
        bottom = math.max(
          bottom,
          point.participantCount ?? point.value!.round(),
        );
      }
      final nice = niceAxis(0, bottom.toDouble(), integer: true, floor: 0);
      axis = ChartAxis(min: 1, max: nice.max, step: nice.step);
      ticks = [for (final tick in nice.ticks) tick == 0 ? 1 : tick];
    } else {
      double? ceiling;
      for (final point in valued) {
        final full = point.maxScore;
        if (full != null && (ceiling == null || full > ceiling)) {
          ceiling = full;
        }
      }
      final high = valued.isEmpty
          ? 100.0
          : valued.map((p) => p.value!).reduce(math.max);
      axis = niceAxis(0, ceiling ?? high, floor: 0, ceiling: ceiling);
    }
    final unit = _ranking ? '名' : '分';
    final newestFirst = result.points.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: '$label · ${metric.label}走势',
          note: _ranking ? '越靠上名次越靠前' : '近 ${result.points.length} 次已出分考试',
          trailing: AppViewTabs<GrowthMetric>(
            dense: true,
            items: [
              for (final item in GrowthMetric.values)
                AppViewTab(value: item, label: item.label),
            ],
            value: selectedMetric,
            onChanged: onMetricChanged,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        SizedBox(
          height: 280,
          child: Opacity(
            opacity: loading ? AppOpacity.disabled : 1,
            child: StudyLineChart(
              points: points,
              axis: axis,
              ticks: ticks,
              reversed: _ranking,
              semanticLabel: [
                for (final point in points)
                  '${point.label} ${point.valueText}${_ranking ? '' : ' 分'}',
              ].join('；'),
            ),
          ),
        ),
        const StudentSectionGap(),
        AppSectionTitle(title: '历次成绩', note: '共 ${result.points.length} 次'),
        const SizedBox(height: AppSpace.s4),
        if (newestFirst.isEmpty)
          const SizedBox(
            height: 160,
            child: AppEmptyState(
              icon: Icons.show_chart_rounded,
              title: '暂无已出分的考试',
              description: '考试出分后会按时间记录在这里',
            ),
          )
        else
          AppDataTable(
            semanticLabel: '历次成绩',
            columns: [
              const AppTableColumn('考试', flex: 4),
              const AppTableColumn('日期', flex: 3),
              AppTableColumn(_ranking ? '名次' : '成绩', flex: 3, numeric: true),
              const AppTableColumn('较上次', flex: 3, numeric: true),
            ],
            rows: [
              for (final (index, point) in newestFirst.indexed)
                AppTableRow([
                  point.examName,
                  studyDateText(point.examTime),
                  _ranking
                      ? StudyRankCell(
                          rank: point.ranking,
                          total: point.participantCount,
                        )
                      : StudyScoreCell(
                          score: point.score,
                          maxScore: point.maxScore,
                        ),
                  point.change == null
                      ? Text('—', style: AppText.caption12)
                      : StudyDeltaText(point.change, unit: unit),
                ], emphasis: index == 0),
            ],
          ),
      ],
    );
  }
}

class _GrowthSide extends StatelessWidget {
  const _GrowthSide({required this.statistics, required this.metric});

  final GrowthStatistics statistics;
  final GrowthMetric metric;

  @override
  Widget build(BuildContext context) {
    final score = metric == GrowthMetric.score;
    final unit = score ? '分' : '名';
    final change = statistics.recentChange;
    final String changeText;
    if (change == null) {
      changeText = '—';
    } else if (change.abs() < 0.05) {
      changeText = '持平';
    } else {
      final amount = score
          ? formatScoreDelta(change)
          : change.abs().round().toString();
      changeText = '${change > 0 ? '+' : '−'}$amount';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionTitle(title: '概况'),
        const SizedBox(height: AppSpace.s4),
        const AppRule(),
        AppStatRow(
          label: score ? '最高分' : '最好名次',
          value: formatScore(statistics.bestValue),
          unit: unit,
        ),
        const AppRule(),
        AppStatRow(
          label: score ? '平均分' : '平均名次',
          value: formatScore(statistics.averageValue),
          unit: unit,
        ),
        const AppRule(),
        AppStatRow(
          label: '较上次',
          caption: score ? '最近一次和上一次相比' : '正数表示名次上升',
          value: changeText,
          unit: change == null || change.abs() < 0.05 ? '' : unit,
        ),
        const AppRule(),
        const SizedBox(height: AppSpace.s12),
        Text('仅统计已出分的考试，成绩来自艺考网阅卷系统', style: AppText.caption12),
      ],
    );
  }
}
