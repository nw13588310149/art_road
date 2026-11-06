import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/study_growth_controller.dart';
import '../widgets/study_common.dart';
import 'growth_line_chart.dart';

/// 成长曲线（学生本人）/ 成绩曲线（教职查看学生）。
class StudyGrowthView extends ConsumerWidget {
  const StudyGrowthView({
    required this.archiveId,
    required this.title,
    required this.onBack,
    this.subtitle,
    super.key,
  });

  /// 空串：学生本人；否则为教职查看的学生档案 id。
  final String archiveId;
  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  static const _defaultTabs = <GrowthTab>[
    GrowthTab(label: '总分'),
    GrowthTab(subjectName: '素描', label: '素描'),
    GrowthTab(subjectName: '色彩', label: '色彩'),
    GrowthTab(subjectName: '速写', label: '速写'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studyGrowthControllerProvider(archiveId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen<StudyGrowthState>(provider, (previous, next) {
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) return;
      AppToast.showError(context, message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) controller.clearError();
      });
    });

    final result = state.result;
    final tabs = result == null || result.tabs.isEmpty
        ? _defaultTabs
        : result.tabs;
    String labelOf(String subjectName) {
      for (final tab in tabs) {
        if (tab.subjectName == subjectName) return tab.label;
      }
      return subjectName.isEmpty ? '总分' : subjectName;
    }

    final header = ArtPageHeader(
      title: title,
      subtitle: subtitle,
      onBack: onBack,
      bottom: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ArtSegmentTabs<String>(
            items: [for (final tab in tabs) tab.subjectName],
            value: state.subjectName,
            onChanged: controller.selectSubject,
            labelOf: labelOf,
          ),
          ArtSegmentTabs<GrowthMetric>(
            items: GrowthMetric.values,
            value: state.metric,
            onChanged: controller.selectMetric,
            labelOf: (metric) => metric.label,
          ),
        ],
      ),
    );

    final Widget body;
    if (result == null) {
      body = state.failed
          ? StudyErrorView(
              message: state.errorMessage.isEmpty
                  ? '成长曲线加载失败'
                  : state.errorMessage,
              onRetry: controller.load,
            )
          : const SizedBox.shrink();
    } else {
      final metric = state.resultMetric;
      final subjectName = state.resultSubjectName;
      final accent = subjectName.isEmpty
          ? ArtColors.brand
          : artSubjectColor(subjectName);
      body = ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          StudyCard(
            title:
                '${labelOf(subjectName)} · ${metric == GrowthMetric.score ? '分数走势' : '排名走势'}',
            subtitle: '近 ${result.points.length} 次已出分测评',
            trailing: metric == GrowthMetric.ranking
                ? const StudyChip(
                    label: '名次越靠上越好',
                    icon: Icons.info_outline_rounded,
                    color: ArtColors.brandDeep,
                  )
                : null,
            child: SizedBox(
              height: 300,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GrowthLineChart(
                      points: result.points,
                      metric: metric,
                      color: accent,
                    ),
                  ),
                  if (state.loading)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x99FFFFFF),
                        child: Center(child: AppLoadingIndicator(size: 36)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _GrowthStatsCard(statistics: result.statistics, metric: metric),
          const SizedBox(height: 12),
          _GrowthHistoryCard(
            points: result.points,
            metric: metric,
            accent: accent,
          ),
        ],
      );
    }

    return PageInitLoadingShell(
      loading: state.loading && result == null,
      child: StudyPageFrame(header: header, body: body),
    );
  }
}

class _GrowthStatsCard extends StatelessWidget {
  const _GrowthStatsCard({required this.statistics, required this.metric});

  final GrowthStatistics statistics;
  final GrowthMetric metric;

  @override
  Widget build(BuildContext context) {
    final unit = metric == GrowthMetric.score ? '分' : '名';
    final change = statistics.recentChange;
    final tiles = [
      StudyStatTile(
        label: metric == GrowthMetric.score ? '最佳成绩' : '最佳名次',
        value: formatScore(statistics.bestValue),
        unit: unit,
        color: ArtColors.brandDeep,
      ),
      StudyStatTile(
        label: metric == GrowthMetric.score ? '平均分' : '平均名次',
        value: formatScore(statistics.averageValue),
        unit: unit,
      ),
      StudyStatTile(
        label: metric == GrowthMetric.score ? '最新成绩' : '最新名次',
        value: formatScore(statistics.latestValue),
        unit: unit,
      ),
      StudyStatTile(
        label: '较上次',
        value: change == null ? '—' : formatScore(change.abs()),
        unit: change == null ? '' : unit,
        color: change == null || change == 0
            ? ArtColors.ink3
            : (change > 0 ? ArtColors.up : ArtColors.down),
        icon: change == null || change == 0
            ? null
            : (change > 0
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded),
      ),
    ];
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 600 ? 4 : 2;
          const gap = 12.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final tile in tiles) SizedBox(width: width, child: tile),
            ],
          );
        },
      ),
    );
  }
}

class _GrowthHistoryCard extends StatelessWidget {
  const _GrowthHistoryCard({
    required this.points,
    required this.metric,
    required this.accent,
  });

  final List<GrowthPoint> points;
  final GrowthMetric metric;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final newestFirst = points.reversed.toList();
    return StudyCard(
      title: '历次成绩',
      subtitle: '共 ${points.length} 次',
      child: newestFirst.isEmpty
          ? Text(
              '暂无已出分的考试',
              style: ArtText.body(size: 13, color: ArtColors.ink3),
            )
          : Column(
              children: [
                for (var i = 0; i < newestFirst.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: ArtColors.line,
                    ),
                  _HistoryRow(
                    point: newestFirst[i],
                    metric: metric,
                    accent: accent,
                    latest: i == 0,
                  ),
                ],
              ],
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.point,
    required this.metric,
    required this.accent,
    required this.latest,
  });

  final GrowthPoint point;
  final GrowthMetric metric;
  final Color accent;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: latest ? accent : accent.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.examName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArtText.body(size: 14, weight: AppFont.w500),
                ),
                const SizedBox(height: 2),
                Text(studyDateText(point.examTime), style: ArtText.caption()),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (metric == GrowthMetric.score)
            StudyNumberText(
              formatScore(point.score),
              unit: ' / ${formatScore(point.maxScore)}',
              size: 17,
              color: latest ? accent : ArtColors.ink,
            )
          else
            StudyRankText(
              rank: point.ranking,
              total: point.participantCount,
              size: 17,
              color: latest ? accent : ArtColors.ink,
            ),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            child: Align(
              alignment: Alignment.centerRight,
              child: StudyDeltaTag(
                value: point.change,
                unit: metric == GrowthMetric.score ? '分' : '名',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
