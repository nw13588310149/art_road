import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/study_models.dart';
import 'study_common.dart';

/// 各科成绩卡（素描 / 色彩 / 速写）：宽屏三列等高，窄屏纵向排列。
class StudySubjectCards extends StatelessWidget {
  const StudySubjectCards({
    required this.subjects,
    required this.onOpenPaper,
    required this.onOpenStandard,
    super.key,
  });

  final List<StudySubjectRecord> subjects;
  final ValueChanged<StudySubjectRecord> onOpenPaper;
  final ValueChanged<StudySubjectRecord> onOpenStandard;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final cards = [
          for (final subject in subjects)
            _SubjectCard(
              subject: subject,
              stretch: wide,
              onOpenPaper: () => onOpenPaper(subject),
              onOpenStandard: () => onOpenStandard(subject),
            ),
        ];
        if (!wide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
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
                if (i > 0) const SizedBox(width: 12),
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
    required this.onOpenPaper,
    required this.onOpenStandard,
  });

  final StudySubjectRecord subject;

  /// 等高排列时按钮贴底。
  final bool stretch;
  final VoidCallback onOpenPaper;
  final VoidCallback onOpenStandard;

  @override
  Widget build(BuildContext context) {
    final accent = artSubjectColor(subject.subjectName);
    final tagline = ArtSubject.tryParse(subject.subjectName)?.tagline ?? '';
    final rate = subject.rate;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StudySubjectIcon(subjectName: subject.subjectName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.subjectName, style: ArtText.title(size: 16)),
                    if (tagline.isNotEmpty)
                      Text(tagline, style: ArtText.caption(size: 11)),
                  ],
                ),
              ),
              if (subject.hasScore)
                ArtGradeBadge(grade: subject.grade, size: 28)
              else
                const StudyChip(label: '待出分', color: ArtColors.warn),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: StudyNumberText(
                  formatScore(subject.score),
                  unit: ' / ${formatScore(subject.maxScore)}',
                  size: 30,
                  color: subject.hasScore ? accent : ArtColors.ink3,
                ),
              ),
              StudyDeltaTag(value: subject.scoreChange),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('得分率', style: ArtText.caption()),
              const Spacer(),
              Text(
                studyPercentText(rate),
                style: ArtText.number(size: 13, color: ArtColors.ink2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          StudyProgressBar(value: rate, color: accent),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(label: '科目排名', rank: subject.ranking),
              ),
              Expanded(
                child: _MiniStat(
                  label: '校区排名',
                  rank: subject.organizationRanking,
                ),
              ),
            ],
          ),
          if (subject.gradeDescription.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${subject.grade} 档：${subject.gradeDescription}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ArtText.caption(size: 12, color: ArtColors.ink2),
            ),
          ],
          if (stretch) const Spacer() else const SizedBox(height: 4),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ArtButton(
                  label: '看原卷',
                  icon: Icons.image_outlined,
                  primary: false,
                  height: 34,
                  onTap: subject.paperAvailable ? onOpenPaper : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ArtButton(
                  label: '评分标准',
                  icon: Icons.rule_rounded,
                  primary: false,
                  height: 34,
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.rank});

  final String label;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArtText.caption(size: 11)),
        const SizedBox(height: 3),
        StudyRankText(rank: rank, size: 16),
      ],
    );
  }
}
