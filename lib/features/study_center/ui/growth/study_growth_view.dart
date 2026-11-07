import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
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
    String labelOf(String subjectName) {
      for (final tab in tabs) {
        if (tab.subjectName == subjectName) {
          return tab.label;
        }
      }
      return subjectName.isEmpty ? '总分' : subjectName;
    }

    final header = AppPageHeader(
      title: title,
      subtitle: subtitle,
      onBack: onBack,
      bottom: Wrap(
        spacing: AppSpace.s12,
        runSpacing: AppSpace.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppSegmented<String>(
            segments: [
              for (final tab in tabs)
                AppSegment(value: tab.subjectName, label: tab.label),
            ],
            value: state.subjectName,
            onChanged: controller.selectSubject,
          ),
          AppSegmented<GrowthMetric>(
            segments: [
              for (final metric in GrowthMetric.values)
                AppSegment(value: metric, label: metric.label),
            ],
            value: state.metric,
            onChanged: controller.selectMetric,
          ),
        ],
      ),
    );

    final Widget body;
    if (result == null) {
      body = state.failed
          ? AppErrorState(
              title: '成长曲线加载失败',
              description: state.errorMessage.isEmpty
                  ? '请检查网络后重试'
                  : state.errorMessage,
              onRetry: controller.load,
            )
          : ListView(
              padding: studyBodyPadding,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                AppSkeleton(height: 360, radius: AppRadius.card),
                SizedBox(height: AppSpace.s16),
                StudyCardSkeleton(lines: 2),
              ],
            );
    } else {
      final metric = state.resultMetric;
      final subjectName = state.resultSubjectName;
      final accent = subjectName.isEmpty
          ? AppColors.brand
          : studySubjectColor(subjectName);
      body = ListView(
        padding: studyBodyPadding,
        children: [
          AppCard(
            title:
                '${labelOf(subjectName)} · ${metric == GrowthMetric.score ? '分数走势' : '排名走势'}',
            subtitle: '近 ${result.points.length} 次已出分测评',
            trailing: metric == GrowthMetric.ranking
                ? const AppTag(
                    label: '越靠上名次越靠前',
                    icon: Icons.info_outline_rounded,
                  )
                : null,
            child: SizedBox(
              height: 300,
              child: Opacity(
                opacity: state.loading ? AppOpacity.disabled : 1,
                child: GrowthLineChart(
                  points: result.points,
                  metric: metric,
                  color: accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          _GrowthStatsCard(statistics: result.statistics, metric: metric),
          const SizedBox(height: AppSpace.s16),
          _GrowthHistoryCard(
            points: result.points,
            metric: metric,
            accent: accent,
          ),
        ],
      );
    }

    return StudyPageFrame(header: header, body: body);
  }
}

class _GrowthStatsCard extends StatelessWidget {
  const _GrowthStatsCard({required this.statistics, required this.metric});

  final GrowthStatistics statistics;
  final GrowthMetric metric;

  @override
  Widget build(BuildContext context) {
    final score = metric == GrowthMetric.score;
    final unit = score ? '分' : '名';
    final change = statistics.recentChange;
    final tiles = [
      AppStatTile(
        label: score ? '最高分' : '最高名次',
        value: formatScore(statistics.bestValue),
        unit: unit,
        boxed: true,
      ),
      AppStatTile(
        label: score ? '平均分' : '平均名次',
        value: formatScore(statistics.averageValue),
        unit: unit,
        boxed: true,
      ),
      AppStatTile(
        label: score ? '最新成绩' : '最新名次',
        value: formatScore(statistics.latestValue),
        unit: unit,
        boxed: true,
      ),
      AppStatTile(
        label: '较上次',
        value: change == null
            ? '—'
            : (score ? formatScoreDelta(change) : '${change.abs().round()}'),
        unit: change == null ? '' : unit,
        valueColor: change == null || change == 0
            ? AppColors.textTertiary
            : (change > 0 ? AppColors.success : AppColors.danger),
        boxed: true,
      ),
    ];
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 600 ? 4 : 2;
          const gap = AppSpace.s12;
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
    return AppCard(
      title: '历次成绩',
      subtitle: '共 ${points.length} 次',
      child: newestFirst.isEmpty
          ? const SizedBox(
              height: 140,
              child: AppEmptyState(
                icon: Icons.show_chart_rounded,
                title: '暂无已出分的考试',
                description: '考试出分后会按时间记录在这里',
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < newestFirst.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.lineSoft,
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
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: latest ? accent : AppColors.line,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.examName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
                const SizedBox(height: 2),
                Text(studyDateText(point.examTime), style: AppText.caption12),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          if (metric == GrowthMetric.score)
            StudyNumberText(
              formatScore(point.score),
              unit: ' / ${formatScore(point.maxScore)}',
              size: 16,
            )
          else
            StudyRankText(
              rank: point.ranking,
              total: point.participantCount,
              size: 16,
            ),
          const SizedBox(width: AppSpace.s12),
          // 最小宽度对齐各行，变化量更长时标签按内容变宽，不被压缩。
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
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
