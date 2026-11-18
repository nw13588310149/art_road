import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/ui/ui.dart';
import '../../../artworks/data/artwork_models.dart';

/// 作品成长的侧栏：练习概况和这一科各分项的等级。
class StudentArtworkGrowthSide extends StatelessWidget {
  const StudentArtworkGrowthSide({
    required this.insights,
    required this.levels,
    super.key,
  });

  final ArtworkInsights insights;
  final ArtworkDimensionLevels levels;

  String _day(String text) => text.length >= 10 ? text.substring(5, 10) : '—';

  String _change(String key, String name) {
    final valid = levels.history
        .map((h) => h.levels[key])
        .whereType<double>()
        .toList();
    if (valid.length < 2) return '再积累一份点评后可比较变化';
    final delta = valid.last - valid[valid.length - 2];
    final text = delta == 0
        ? '持平'
        : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} 级';
    return '$name较上份 $text · 仅比较相邻两份作品';
  }

  @override
  Widget build(BuildContext context) {
    final rate = insights.resolveRate;
    final scores = [...levels.items]
      ..sort((a, b) => (a.level ?? 5).compareTo(b.level ?? 5));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionTitle(title: '练习概况'),
        const SizedBox(height: AppSpace.s4),
        const AppRule(),
        AppStatRow(label: '连续练习', value: '${insights.streakDays}', unit: '天'),
        const AppRule(),
        AppStatRow(
          label: '近 7 天提交',
          value: '${insights.recentSubmitCount}',
          unit: '份',
        ),
        const AppRule(),
        AppStatRow(
          label: '问题解决率',
          caption: '标记过的问题里，最近一次已确认改善的比例',
          value: rate == null ? '—' : '${(rate * 100).round()}',
          unit: rate == null ? '' : '%',
        ),
        const AppRule(),
        const SizedBox(height: AppSpace.s32),
        AppSectionTitle(title: '分项观察', note: levels.subject),
        Text(
          '最近 ${levels.sampleCount} 份已点评作品 · ${levels.reviewCount} 条任课点评'
          ' · ${_day(levels.fromDate)}—${_day(levels.toDate)}',
          style: AppText.caption12,
        ),
        const SizedBox(height: AppSpace.s8),
        const AppRule(),
        for (final item in scores) ...[
          AppStatRow(
            label: item.name,
            value: item.level?.toStringAsFixed(1) ?? '—',
            unit: item.level == null ? '' : '/ 5',
          ),
          const AppRule(),
        ],
        const SizedBox(height: AppSpace.s12),
        Text(
          '5 级评价，同一作品多位老师取均值。'
          '${levels.history.length >= 2 && scores.isNotEmpty ? _change(scores.first.key, scores.first.name) : ''}',
          style: AppText.caption12,
        ),
      ],
    );
  }
}

/// 一个问题的点评依据：每条点评一行，可以打开原作品。
Future<void> showStudentArtworkEvidence(
  BuildContext context,
  ArtworkDimensionLevels levels,
  ArtworkInsightTag issue,
) async {
  final id = await showAppDrawer<String>(
    context: context,
    builder: (drawer) => AppDrawer(
      title: issue.name,
      subtitle: '${levels.subject} · ${issue.count} 份作品的点评依据',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('状态取自最新相关点评；历史改善记录不会覆盖之后再次出现的问题。', style: AppText.body13),
          const SizedBox(height: AppSpace.s16),
          const AppRule(),
          for (final e in issue.evidence) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(e.title, style: AppText.body14Strong),
                  Text('${e.teacher} · ${e.time}', style: AppText.caption12),
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    e.comment.isEmpty ? '老师标记了此问题，请结合原作品查看。' : e.comment,
                    style: AppText.body14,
                  ),
                  Row(
                    children: [
                      AppStatusTag(
                        label: e.resolved ? '本次确认改善' : '本次仍需关注',
                        tone: e.resolved ? AppTone.success : AppTone.warning,
                      ),
                      const Spacer(),
                      AppPlainButton(
                        label: '查看原作品',
                        onTap: () => Navigator.of(drawer).pop(e.artworkId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const AppRule(),
          ],
        ],
      ),
    ),
  );
  if (id != null && id.isNotEmpty && context.mounted) {
    Navigator.of(
      context,
    ).pushNamed(RoutePaths.artworks, arguments: {'artworkId': id});
  }
}
