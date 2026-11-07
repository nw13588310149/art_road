import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_models.dart';
import 'study_common.dart';

/// 各科成绩卡（素描 / 色彩 / 速写）：宽屏三列等高，窄屏纵向排列。
class StudySubjectCards extends StatelessWidget {
  const StudySubjectCards({
    required this.subjects,
    required this.onOpenPaper,
    required this.onOpenStandard,
    this.participantCount,
    this.organizationParticipantCount,
    super.key,
  });

  final List<StudySubjectRecord> subjects;
  final ValueChanged<StudySubjectRecord> onOpenPaper;
  final ValueChanged<StudySubjectRecord> onOpenStandard;

  /// 名次分母：本场全画室 / 本校区参考人数。
  final int? participantCount;
  final int? organizationParticipantCount;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final cards = [
          for (final subject in subjects)
            _SubjectCard(
              subject: subject,
              stretch: wide,
              participantCount: participantCount,
              organizationParticipantCount: organizationParticipantCount,
              onOpenPaper: () => onOpenPaper(subject),
              onOpenStandard: () => onOpenStandard(subject),
            ),
        ];
        if (!wide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpace.s12),
                cards[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpace.s12),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.stretch,
    required this.participantCount,
    required this.organizationParticipantCount,
    required this.onOpenPaper,
    required this.onOpenStandard,
  });

  final StudySubjectRecord subject;

  /// 等高排列时按钮贴底。
  final bool stretch;
  final int? participantCount;
  final int? organizationParticipantCount;
  final VoidCallback onOpenPaper;
  final VoidCallback onOpenStandard;

  @override
  Widget build(BuildContext context) {
    final accent = studySubjectColor(subject.subjectName);
    final tagline = ArtSubject.tryParse(subject.subjectName)?.tagline ?? '';
    final rate = subject.rate;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StudySubjectIcon(subjectName: subject.subjectName),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.subjectName, style: AppText.title16),
                    if (tagline.isNotEmpty)
                      Text(
                        tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              if (subject.hasScore)
                StudyGradeTag(grade: subject.grade)
              else
                const AppTag(label: '待出分', tone: AppTone.warning),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: StudyNumberText(
                  formatScore(subject.score),
                  unit: ' / ${formatScore(subject.maxScore)} 分',
                  size: 32,
                  color: subject.hasScore ? accent : AppColors.textTertiary,
                ),
              ),
              StudyDeltaTag(value: subject.scoreChange),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Row(
            children: [
              Text('得分率', style: AppText.caption12),
              const Spacer(),
              Text(
                studyPercentText(rate),
                style: AppText.number(size: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          AppProgressBar(value: rate ?? 0, color: accent, height: 6),
          const SizedBox(height: AppSpace.s16),
          Row(
            children: [
              Expanded(
                child: _MiniRank(
                  label: '科目排名',
                  rank: subject.ranking,
                  total: participantCount,
                ),
              ),
              Expanded(
                child: _MiniRank(
                  label: '校区排名',
                  rank: subject.organizationRanking,
                  total: organizationParticipantCount,
                ),
              ),
            ],
          ),
          if (subject.gradeDescription.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            Text(
              '${subject.grade} 档：${subject.gradeDescription}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.body13,
            ),
          ],
          if (stretch)
            const Spacer()
          else
            const SizedBox(height: AppSpace.s4),
          const SizedBox(height: AppSpace.s16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '看原卷',
                  icon: Icons.image_outlined,
                  variant: AppButtonVariant.quiet,
                  size: AppButtonSize.sm,
                  expand: true,
                  onTap: subject.paperAvailable ? onOpenPaper : null,
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: AppButton(
                  label: '评分标准',
                  icon: Icons.rule_rounded,
                  variant: AppButtonVariant.quiet,
                  size: AppButtonSize.sm,
                  expand: true,
                  onTap: onOpenStandard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniRank extends StatelessWidget {
  const _MiniRank({required this.label, required this.rank, this.total});

  final String label;
  final int? rank;
  final int? total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption12),
        const SizedBox(height: 2),
        StudyRankText(rank: rank, total: total, size: 16),
      ],
    );
  }
}
