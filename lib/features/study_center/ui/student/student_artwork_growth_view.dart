import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/ui/ui.dart';
import '../../../artworks/data/artwork_models.dart';
import '../../../artworks/state/student_artworks_controller.dart';
import '../../../artworks/ui/widgets/artwork_focus_panel.dart'
    show showArtworkPractice;
import '../../data/study_logic.dart';
import 'student_artwork_growth_parts.dart';
import 'student_line_chart.dart';
import 'student_study_parts.dart';

/// 作品成长：按科目看老师分项点评的统计。先给出下一次练习，再列反复出现的问题和
/// 分项趋势；侧栏是练习概况和各分项的等级。
///
/// 首页用的 `ArtworkFocusPanel` 是同一组数据的紧凑版本，这里按新页面的版式另排。
class StudentArtworkGrowthView extends ConsumerStatefulWidget {
  const StudentArtworkGrowthView({required this.onSelectTab, super.key});

  final ValueChanged<StudentStudyTab> onSelectTab;

  @override
  ConsumerState<StudentArtworkGrowthView> createState() =>
      _StudentArtworkGrowthViewState();
}

class _StudentArtworkGrowthViewState
    extends ConsumerState<StudentArtworkGrowthView> {
  String _subject = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentArtworksControllerProvider);
    final insights = state.insights;
    final dimensions = insights.dimensions;
    final current =
        dimensions.where((d) => d.subject == _subject).firstOrNull ??
        dimensions.firstOrNull;
    return AppPageBody(
      builder: (context, wide) {
        final Widget body;
        if (state.loading && !state.loaded) {
          body = const SizedBox(
            height: 360,
            child: Center(child: AppLoadingIndicator()),
          );
        } else if (state.insightsError.isNotEmpty) {
          body = SizedBox(
            height: 360,
            child: AppErrorState(
              title: '点评分析加载失败',
              description: state.insightsError,
              onRetry: ref
                  .read(studentArtworksControllerProvider.notifier)
                  .refresh,
            ),
          );
        } else if (current == null) {
          body = const SizedBox(
            height: 360,
            child: AppEmptyState(
              icon: Icons.brush_outlined,
              title: '暂无分项点评',
              description: '老师填写分项评价后会显示在这里',
            ),
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dimensions.length > 1) ...[
                AppFilterBar<String>(
                  items: [
                    for (final item in dimensions)
                      AppFilterItem(value: item.subject, label: item.subject),
                  ],
                  value: current.subject,
                  onChanged: (value) => setState(() => _subject = value),
                ),
                const SizedBox(height: AppSpace.s24),
              ],
              StudentColumns(
                wide: wide,
                main: _GrowthMain(levels: current),
                side: StudentArtworkGrowthSide(
                  insights: insights,
                  levels: current,
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudentStudyTitleBar(
              selected: StudentStudyTab.artwork,
              onSelect: widget.onSelectTab,
            ),
            const SizedBox(height: AppSpace.s12),
            body,
          ],
        );
      },
    );
  }
}

class _GrowthMain extends StatelessWidget {
  const _GrowthMain({required this.levels});

  final ArtworkDimensionLevels levels;

  @override
  Widget build(BuildContext context) {
    final issues = levels.issues.take(5).toList();
    final priority = levels.issues.where((i) => !i.latestResolved).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (priority != null) ...[
          _NextPractice(levels: levels, issue: priority),
          const StudentSectionGap(),
        ],
        const AppSectionTitle(title: '近期关注', note: '按反复出现的作品数排序 · 点开看老师的点评依据'),
        const SizedBox(height: AppSpace.s4),
        if (issues.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
            child: Text('暂未标记具体问题，可先查看老师的分项点评。', style: AppText.body13),
          )
        else ...[
          const AppRule(),
          for (final issue in issues) ...[
            _IssueRow(
              issue: issue,
              onTap: () => showStudentArtworkEvidence(context, levels, issue),
            ),
            const AppRule(),
          ],
        ],
        if (levels.history.isNotEmpty && levels.items.isNotEmpty) ...[
          const StudentSectionGap(),
          _DimensionTrend(levels: levels),
        ],
        if (levels.sourceWorks.isNotEmpty) ...[
          const StudentSectionGap(),
          AppSectionTitle(
            title: '本次统计的作品',
            note: '共 ${levels.sourceWorks.length} 份',
          ),
          const SizedBox(height: AppSpace.s4),
          const AppRule(),
          for (final work in levels.sourceWorks.reversed) ...[
            _WorkRow(
              title: work.title,
              onTap: work.id.isEmpty
                  ? null
                  : () => Navigator.of(context).pushNamed(
                      RoutePaths.artworks,
                      arguments: {'artworkId': work.id},
                    ),
            ),
            const AppRule(),
          ],
        ],
      ],
    );
  }
}

/// 这一科最该先练的一件事：唯一的主按钮在这里。
class _NextPractice extends StatelessWidget {
  const _NextPractice({required this.levels, required this.issue});

  final ArtworkDimensionLevels levels;
  final ArtworkInsightTag issue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('下一次练习 · ${levels.subject}', style: AppText.caption12),
        const SizedBox(height: AppSpace.s4),
        Text(issue.name, style: AppText.title24),
        const SizedBox(height: AppSpace.s8),
        Text(
          issue.advice.isEmpty ? issue.explanation : issue.advice,
          style: AppText.body14.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.s16),
        Row(
          children: [
            AppButton(
              label: '制定练习',
              onTap: () => showArtworkPractice(
                context,
                subject: levels.subject,
                title: issue.name,
                instruction: issue.advice,
                sourceLabel: '短板练习 · ${issue.name}',
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            AppPlainButton(
              label: '找学习资料',
              onTap: () => Navigator.of(context).pushNamed(
                RoutePaths.microLessons,
                arguments: {
                  'subject': levels.subject,
                  'keyword': issue.keyword,
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.onTap});

  final ArtworkInsightTag issue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final explanation = issue.explanation.isEmpty
        ? issue.advice
        : issue.explanation;
    return AppPressable(
      onTap: onTap,
      semanticLabel: '查看点评依据',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(issue.name, style: AppText.body14Strong),
                        ),
                        if (issue.latestResolved) ...[
                          const SizedBox(width: AppSpace.s12),
                          const AppStatusTag(
                            label: '最近已确认改善',
                            tone: AppTone.success,
                          ),
                        ],
                      ],
                    ),
                    if (explanation.isNotEmpty)
                      Text(
                        explanation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body13,
                      ),
                    Text(
                      '${issue.count} 份作品 · ${issue.evidence.length} 条点评',
                      style: AppText.caption12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textPlaceholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  const _WorkRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.body14)),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textPlaceholder,
            ),
        ],
      ),
    );
    final tap = onTap;
    return tap == null ? row : AppPressable(onTap: tap, child: row);
  }
}

/// 分项趋势：一次看一个分项，5 级评价，纵轴从 0 起。
class _DimensionTrend extends StatefulWidget {
  const _DimensionTrend({required this.levels});

  final ArtworkDimensionLevels levels;

  @override
  State<_DimensionTrend> createState() => _DimensionTrendState();
}

class _DimensionTrendState extends State<_DimensionTrend> {
  String _key = '';

  static String _level(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final items = widget.levels.items;
    final item = items.where((i) => i.key == _key).firstOrNull ?? items.first;
    final points = [
      for (final point in widget.levels.history)
        if (point.levels[item.key] != null)
          StudyLinePoint(
            label: point.date.length >= 10
                ? point.date.substring(5, 10)
                : point.date,
            value: point.levels[item.key]!,
            valueText: _level(point.levels[item.key]!),
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: '分项趋势',
          note: '每份作品一个点',
          trailing: AppViewTabs<String>(
            dense: true,
            items: [
              for (final entry in items)
                AppViewTab(value: entry.key, label: entry.name),
            ],
            value: item.key,
            onChanged: (value) => setState(() => _key = value),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        SizedBox(
          height: 240,
          child: StudyLineChart(
            points: points,
            axis: const ChartAxis(min: 0, max: 5, step: 1),
            semanticLabel: [
              '${item.name}，5 级评价',
              for (final point in points) '${point.label} ${point.valueText} 级',
            ].join('；'),
          ),
        ),
      ],
    );
  }
}
