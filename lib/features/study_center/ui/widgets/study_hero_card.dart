import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import 'study_common.dart';
import 'study_score_ring.dart';

/// 考试成绩主卡：总分环、排名、超过百分比、较上次变化，可附测评统计。
class StudyHeroCard extends StatelessWidget {
  const StudyHeroCard({
    required this.exam,
    this.scoreChange,
    this.rankingChange,
    this.surpassedPercent,
    this.statistics,
    this.onOpenReport,
    super.key,
  });

  final StudyExamRecord exam;
  final double? scoreChange;

  /// 正数表示名次上升。
  final int? rankingChange;
  final int? surpassedPercent;
  final StudyStatistics? statistics;
  final VoidCallback? onOpenReport;

  @override
  Widget build(BuildContext context) {
    final stats = statistics;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1EEFF), Colors.white],
          stops: [0, 0.6],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ArtColors.brand.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final ring = StudyScoreRing(
                  score: exam.totalScore,
                  maxScore: exam.maxScore,
                  size: wide ? 148 : 118,
                );
                final info = _HeroInfo(
                  exam: exam,
                  scoreChange: scoreChange,
                  rankingChange: rankingChange,
                  surpassedPercent: surpassedPercent,
                  onOpenReport: onOpenReport,
                );
                if (wide) {
                  return Row(
                    children: [
                      ring,
                      const SizedBox(width: 28),
                      Expanded(child: info),
                      if (stats != null) ...[
                        const SizedBox(width: 20),
                        Container(width: 1, height: 132, color: ArtColors.line),
                        const SizedBox(width: 20),
                        _HeroStats(statistics: stats, vertical: true),
                      ],
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ring,
                        const SizedBox(width: 20),
                        Expanded(child: info),
                      ],
                    ),
                    if (stats != null) ...[
                      const SizedBox(height: 18),
                      _HeroStats(statistics: stats, vertical: false),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({
    required this.exam,
    required this.scoreChange,
    required this.rankingChange,
    required this.surpassedPercent,
    required this.onOpenReport,
  });

  final StudyExamRecord exam;
  final double? scoreChange;
  final int? rankingChange;
  final int? surpassedPercent;
  final VoidCallback? onOpenReport;

  @override
  Widget build(BuildContext context) {
    final scored = exam.isPublished && exam.hasScore;
    final meta = [
      studyDateText(exam.examTime),
      if (exam.admissionNo.isNotEmpty) '准考证号 ${exam.admissionNo}',
      if (exam.organizationName.isNotEmpty) exam.organizationName,
    ].join(' · ');
    final percent = surpassedPercent;
    final openReport = onOpenReport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                exam.examName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ArtText.title(size: 19),
              ),
            ),
            const SizedBox(width: 8),
            scored
                ? const StudyChip(label: '已出分', color: ArtColors.success)
                : StudyChip(
                    label: exam.isPublished ? '无成绩' : '阅卷中',
                    color: ArtColors.warn,
                  ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          meta,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ArtText.caption(size: 13),
        ),
        const SizedBox(height: 16),
        if (!scored)
          Text(
            exam.isPublished ? '本场考试暂无成绩（可能缺考或成绩未录入）' : '阅卷中，出分后提醒',
            style: ArtText.body(size: 14, color: ArtColors.ink2),
          )
        else
          Wrap(
            spacing: 28,
            runSpacing: 14,
            children: [
              _HeroMetric(
                label: '总排名',
                child: StudyRankText(
                  rank: exam.totalRanking,
                  total: exam.participantCount,
                  size: 22,
                  color: ArtColors.brandDeep,
                ),
              ),
              _HeroMetric(
                label: exam.organizationName.isEmpty
                    ? '校区排名'
                    : '${exam.organizationName}排名',
                child: StudyRankText(
                  rank: exam.organizationRanking,
                  total: exam.organizationParticipantCount,
                  size: 22,
                ),
              ),
              if (scoreChange != null || rankingChange != null)
                _HeroMetric(
                  label: '较上次',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StudyDeltaTag(value: scoreChange),
                        StudyDeltaTag(value: rankingChange, unit: '名'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (scored && (percent != null || openReport != null)) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (percent != null) _SurpassPill(percent: percent),
              if (openReport != null)
                ArtButton(
                  label: '查看完整报告',
                  icon: Icons.article_outlined,
                  primary: false,
                  height: 32,
                  onTap: openReport,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: ArtText.caption()),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _SurpassPill extends StatelessWidget {
  const _SurpassPill({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: ArtColors.brandGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '超过 ',
                  style: ArtText.body(size: 13, color: Colors.white),
                ),
                TextSpan(
                  text: '$percent%',
                  style: ArtText.number(size: 15, color: Colors.white),
                ),
                TextSpan(
                  text: ' 的考生',
                  style: ArtText.body(size: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.statistics, required this.vertical});

  final StudyStatistics statistics;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('累计测评', statistics.total),
      ('已发布', statistics.published),
      ('待更新', statistics.pending),
    ];
    if (vertical) {
      return SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _HeroStatItem(label: items[i].$1, value: items[i].$2),
            ],
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ArtColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Container(width: 1, height: 32, color: ArtColors.line),
            Expanded(
              child: Center(
                child: _HeroStatItem(label: items[i].$1, value: items[i].$2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStatItem extends StatelessWidget {
  const _HeroStatItem({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: ArtText.caption()),
        const SizedBox(height: 2),
        StudyNumberText('$value', unit: ' 场', size: 20),
      ],
    );
  }
}
