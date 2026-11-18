import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../student/student_study_parts.dart';
import '../widgets/study_common.dart';

/// 右侧面板：这一科的成绩和档位，下面是各档的分数区间。
class StudyPaperPanel extends StatelessWidget {
  const StudyPaperPanel({
    required this.exam,
    required this.subject,
    required this.standard,
    required this.onRetryStandard,
    super.key,
  });

  final StudyExamRecord exam;
  final StudySubjectRecord subject;
  final AsyncValue<GradeStandard> standard;
  final VoidCallback onRetryStandard;

  @override
  Widget build(BuildContext context) {
    final bands = standard.valueOrNull?.bands ?? const <GradeBandInfo>[];
    final grade = subject.grade.isNotEmpty
        ? subject.grade
        : bandForScore(bands, subject.score)?.grade ?? '';
    final Widget bandList;
    if (standard.isLoading && bands.isEmpty) {
      bandList = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: AppSkeletonText(lines: 5),
      );
    } else if (standard.hasError && bands.isEmpty) {
      bandList = Row(
        children: [
          Expanded(child: Text('档位标准加载失败', style: AppText.body13)),
          AppPlainButton(label: '重试', onTap: onRetryStandard),
        ],
      );
    } else {
      bandList = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppRule(),
          for (final band in bands) ...[
            _BandLine(band: band, mine: band.grade == grade),
            const AppRule(),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${subject.subjectName} · 我的成绩', style: AppText.caption12),
        const SizedBox(height: AppSpace.s4),
        if (subject.hasScore) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatScore(subject.score),
                  style: AppText.number(size: 24),
                ),
                TextSpan(
                  text: ' / ${formatScore(subject.maxScore)} 分',
                  style: AppText.body13,
                ),
                if (grade.isNotEmpty)
                  TextSpan(text: '   $grade 档', style: AppText.title16),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          Row(
            children: [
              Text('科目排名 ', style: AppText.caption12),
              Flexible(
                child: StudyRankText(
                  rank: subject.ranking,
                  total: exam.participantCount,
                  totalUnit: '人',
                  size: 14,
                ),
              ),
            ],
          ),
          if (subject.scoreChange != null) ...[
            const SizedBox(height: AppSpace.s4),
            Row(
              children: [
                Text('较上次 ', style: AppText.caption12),
                StudyDeltaText(subject.scoreChange),
              ],
            ),
          ],
        ] else
          Text('待出分', style: AppText.title16),
        if (subject.gradeDescription.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s16),
          Text(
            '$grade 档：${subject.gradeDescription}',
            style: AppText.body14.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const StudentSectionGap(),
        const AppSectionTitle(title: '档位标准'),
        const SizedBox(height: AppSpace.s4),
        bandList,
      ],
    );
  }
}

class _BandLine extends StatelessWidget {
  const _BandLine({required this.band, required this.mine});

  final GradeBandInfo band;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text(
            '${band.grade} 档',
            style: mine ? AppText.body14Strong : AppText.body14,
          ),
          if (mine) ...[
            const SizedBox(width: AppSpace.s8),
            Text(
              '本次',
              style: AppText.caption12.copyWith(color: AppColors.brandDeep),
            ),
          ],
          const Spacer(),
          Text(
            '${formatScore(band.min)}–${formatScore(band.max)}',
            style: AppText.number(
              size: 14,
              color: mine ? AppColors.ink : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
