import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import 'study_common.dart';
import 'study_score_ring.dart';

/// 考试成绩主卡：总分环、排名、超过百分比、较上次变化，可附测评统计。
class StudyHeroCard extends StatelessWidget {
  const StudyHeroCard({
    required this.exam,
    this.studentLabel = '',
    this.studentName = '',
    this.scoreChange,
    this.rankingChange,
    this.surpassedPercent,
    this.statistics,
    this.onOpenReport,
    super.key,
  });

  final StudyExamRecord exam;
  final String studentLabel;
  final String studentName;
  final double? scoreChange;

  /// 正数表示名次上升。
  final int? rankingChange;

  /// 接口给出的超过百分比；有名次与参考人数时以二者计算的结果为准，保证能互相核对。
  final int? surpassedPercent;
  final StudyStatistics? statistics;
  final VoidCallback? onOpenReport;

  @override
  Widget build(BuildContext context) {
    final stats = statistics;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 640;
              return Row(
                children: [
                  StudyScoreRing(
                    score: exam.totalScore,
                    maxScore: exam.maxScore,
                    size: wide ? 148 : 120,
                  ),
                  SizedBox(width: wide ? AppSpace.s32 : AppSpace.s20),
                  Expanded(
                    child: _HeroInfo(
                      exam: exam,
                      studentName: studentName,
                      scoreChange: scoreChange,
                      rankingChange: rankingChange,
                      surpassedPercent:
                          surpassedPercentOf(
                            exam.totalRanking,
                            exam.participantCount,
                          ) ??
                          surpassedPercent,
                      onOpenReport: onOpenReport,
                    ),
                  ),
                ],
              );
            },
          ),
          if (studentLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            Text(studentLabel, style: AppText.caption12),
          ],
          if (stats != null) ...[
            const SizedBox(height: AppSpace.s20),
            _HeroStats(statistics: stats),
          ],
        ],
      ),
    );
  }
}

/// 考试状态标签：已出分 / 无成绩 / 阅卷中。
class StudyExamStatusTag extends StatelessWidget {
  const StudyExamStatusTag({required this.exam, super.key});

  final StudyExamRecord exam;

  @override
  Widget build(BuildContext context) {
    if (exam.isPublished && exam.hasScore) {
      return const AppTag(label: '已出分', tone: AppTone.success);
    }
    if (exam.isPublished) {
      return const AppTag(label: '无成绩');
    }
    return const AppTag(label: '阅卷中', tone: AppTone.warning);
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({
    required this.exam,
    required this.studentName,
    required this.scoreChange,
    required this.rankingChange,
    required this.surpassedPercent,
    required this.onOpenReport,
  });

  final StudyExamRecord exam;
  final String studentName;
  final double? scoreChange;
  final int? rankingChange;
  final int? surpassedPercent;
  final VoidCallback? onOpenReport;

  @override
  Widget build(BuildContext context) {
    final scored = exam.isPublished && exam.hasScore;
    final meta = [
      if (studentName.isNotEmpty) studentName,
      studyDateText(exam.examTime),
      if (exam.admissionNo.isNotEmpty) '准考证号 ${exam.admissionNo}',
      if (exam.organizationName.isNotEmpty) exam.organizationName,
    ].join(' · ');
    final percent = surpassedPercent;
    final openReport = onOpenReport;
    final organization = exam.organizationName.isEmpty
        ? '校区'
        : exam.organizationName;
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
                style: AppText.title20,
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            StudyExamStatusTag(exam: exam),
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          meta,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.body13,
        ),
        const SizedBox(height: AppSpace.s16),
        if (!scored)
          Text(
            exam.isPublished ? '本场考试暂无成绩（可能缺考或成绩未录入）' : '阅卷中，出分后会通知你',
            style: AppText.body14.copyWith(color: AppColors.textSecondary),
          )
        else
          Wrap(
            spacing: AppSpace.s32,
            runSpacing: AppSpace.s12,
            children: [
              _HeroMetric(
                label: '全画室排名',
                child: StudyRankText(
                  rank: exam.totalRanking,
                  total: exam.participantCount,
                  totalUnit: '人参考',
                  size: 20,
                  color: AppColors.brand,
                ),
              ),
              _HeroMetric(
                label: '$organization排名',
                child: StudyRankText(
                  rank: exam.organizationRanking,
                  total: exam.organizationParticipantCount,
                  totalUnit: '人参考',
                  size: 20,
                ),
              ),
              if (scoreChange != null || rankingChange != null)
                _HeroMetric(
                  label: '较上次',
                  child: Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s4,
                    children: [
                      StudyDeltaTag(value: scoreChange),
                      StudyDeltaTag(value: rankingChange, unit: '名'),
                    ],
                  ),
                ),
            ],
          ),
        if (scored && (percent != null || openReport != null)) ...[
          const SizedBox(height: AppSpace.s16),
          Wrap(
            spacing: AppSpace.s12,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (percent != null)
                AppTag(label: '超过全画室 $percent% 的考生', tone: AppTone.brand),
              if (openReport != null)
                AppButton(
                  label: '查看完整报告',
                  icon: Icons.article_outlined,
                  variant: AppButtonVariant.quiet,
                  size: AppButtonSize.sm,
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
        Text(label, style: AppText.caption12),
        const SizedBox(height: AppSpace.s4),
        SizedBox(
          height: 26,
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.statistics});

  final StudyStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('累计测评', statistics.total),
      ('已出分', statistics.published),
      ('待出成绩', statistics.pending),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.s12),
          Expanded(
            child: AppStatTile(
              label: items[i].$1,
              value: '${items[i].$2}',
              unit: '场',
              boxed: true,
            ),
          ),
        ],
      ],
    );
  }
}
