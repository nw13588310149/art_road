import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_models.dart';
import '../widgets/study_common.dart';

/// 单科操作（看原卷 / 评分标准 / 阅卷明细）。
class StudySubjectAction {
  const StudySubjectAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = _always,
  });

  final String label;
  final IconData icon;
  final ValueChanged<StudySubjectRecord> onTap;
  final bool Function(StudySubjectRecord subject) enabled;

  static bool _always(StudySubjectRecord subject) => true;
}

/// 各科成绩表：宽屏表格，窄屏卡片列表。
class StudySubjectTable extends StatelessWidget {
  const StudySubjectTable({
    required this.subjects,
    required this.actions,
    this.participantCount,
    this.organizationParticipantCount,
    super.key,
  });

  final List<StudySubjectRecord> subjects;
  final List<StudySubjectAction> actions;
  final int? participantCount;
  final int? organizationParticipantCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: '各科成绩',
      subtitle: '共 ${subjects.length} 科',
      child: subjects.isEmpty
          ? const SizedBox(
              height: 140,
              child: AppEmptyState(
                icon: Icons.assignment_outlined,
                title: '暂无各科成绩',
                description: '阅卷完成后会显示各科分数与档位',
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 820
                  ? _TableLayout(
                      subjects: subjects,
                      actions: actions,
                      participantCount: participantCount,
                      organizationParticipantCount:
                          organizationParticipantCount,
                    )
                  : _ListLayout(
                      subjects: subjects,
                      actions: actions,
                      participantCount: participantCount,
                      organizationParticipantCount:
                          organizationParticipantCount,
                    ),
            ),
    );
  }
}

const _flexName = 3;
const _flexScore = 3;
const _flexGrade = 2;
const _flexRate = 4;
const _flexRank = 3;
const _flexChange = 3;

class _TableLayout extends StatelessWidget {
  const _TableLayout({
    required this.subjects,
    required this.actions,
    required this.participantCount,
    required this.organizationParticipantCount,
  });

  final List<StudySubjectRecord> subjects;
  final List<StudySubjectAction> actions;
  final int? participantCount;
  final int? organizationParticipantCount;

  @override
  Widget build(BuildContext context) {
    final actionFlex = actions.length >= 2 ? 5 : 3;
    Widget head(String text, int flex) => Expanded(
      flex: flex,
      child: Text(text, style: AppText.caption12),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12,
            vertical: AppSpace.s8,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: AppRadius.br8,
          ),
          child: Row(
            children: [
              head('科目', _flexName),
              head('成绩', _flexScore),
              head('档位', _flexGrade),
              head('得分率', _flexRate),
              const SizedBox(width: AppSpace.s16),
              head('科目排名', _flexRank),
              head('校区排名', _flexRank),
              head('较上次', _flexChange),
              head('操作', actionFlex),
            ],
          ),
        ),
        for (var i = 0; i < subjects.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          _TableRow(
            subject: subjects[i],
            actions: actions,
            actionFlex: actionFlex,
            participantCount: participantCount,
            organizationParticipantCount: organizationParticipantCount,
          ),
        ],
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.subject,
    required this.actions,
    required this.actionFlex,
    required this.participantCount,
    required this.organizationParticipantCount,
  });

  final StudySubjectRecord subject;
  final List<StudySubjectAction> actions;
  final int actionFlex;
  final int? participantCount;
  final int? organizationParticipantCount;

  @override
  Widget build(BuildContext context) {
    final accent = studySubjectColor(subject.subjectName);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s12,
      ),
      child: Row(
        children: [
          Expanded(
            flex: _flexName,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Flexible(
                  child: Text(
                    subject.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14Strong,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: _flexScore,
            child: StudyNumberText(
              formatScore(subject.score),
              unit: ' / ${formatScore(subject.maxScore)}',
              size: 16,
              color: subject.hasScore ? AppColors.ink : AppColors.textTertiary,
            ),
          ),
          Expanded(
            flex: _flexGrade,
            child: Align(
              alignment: Alignment.centerLeft,
              child: subject.grade.isEmpty
                  ? Text('—', style: AppText.caption12)
                  : StudyGradeTag(grade: subject.grade),
            ),
          ),
          Expanded(
            flex: _flexRate,
            child: Row(
              children: [
                Expanded(
                  child: AppProgressBar(
                    value: subject.rate ?? 0,
                    color: accent,
                    height: 6,
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                SizedBox(
                  width: 40,
                  child: Text(
                    studyPercentText(subject.rate),
                    style: AppText.number(
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            flex: _flexRank,
            child: StudyRankText(
              rank: subject.ranking,
              total: participantCount,
              totalUnit: '人',
              size: 14,
            ),
          ),
          Expanded(
            flex: _flexRank,
            child: StudyRankText(
              rank: subject.organizationRanking,
              total: organizationParticipantCount,
              totalUnit: '人',
              size: 14,
            ),
          ),
          Expanded(
            flex: _flexChange,
            child: Align(
              alignment: Alignment.centerLeft,
              child: subject.scoreChange == null
                  ? Text('—', style: AppText.caption12)
                  : StudyDeltaTag(value: subject.scoreChange),
            ),
          ),
          Expanded(
            flex: actionFlex,
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s4,
              children: [
                for (final action in actions)
                  _ActionButton(action: action, subject: subject),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListLayout extends StatelessWidget {
  const _ListLayout({
    required this.subjects,
    required this.actions,
    required this.participantCount,
    required this.organizationParticipantCount,
  });

  final List<StudySubjectRecord> subjects;
  final List<StudySubjectAction> actions;
  final int? participantCount;
  final int? organizationParticipantCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < subjects.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s12),
          _ListItem(
            subject: subjects[i],
            actions: actions,
            participantCount: participantCount,
            organizationParticipantCount: organizationParticipantCount,
          ),
        ],
      ],
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.subject,
    required this.actions,
    required this.participantCount,
    required this.organizationParticipantCount,
  });

  final StudySubjectRecord subject;
  final List<StudySubjectAction> actions;
  final int? participantCount;
  final int? organizationParticipantCount;

  @override
  Widget build(BuildContext context) {
    final accent = studySubjectColor(subject.subjectName);
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StudySubjectIcon(subjectName: subject.subjectName, size: 30),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(subject.subjectName, style: AppText.body14Strong),
              ),
              if (subject.grade.isNotEmpty) ...[
                StudyGradeTag(grade: subject.grade),
                const SizedBox(width: AppSpace.s8),
              ],
              StudyNumberText(
                formatScore(subject.score),
                unit: ' / ${formatScore(subject.maxScore)}',
                size: 20,
                color: subject.hasScore
                    ? AppColors.ink
                    : AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          AppProgressBar(value: subject.rate ?? 0, color: accent, height: 6),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s16,
            runSpacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LabeledValue(
                label: '得分率',
                child: Text(
                  studyPercentText(subject.rate),
                  style: AppText.number(size: 14),
                ),
              ),
              _LabeledValue(
                label: '科目排名',
                child: StudyRankText(
                  rank: subject.ranking,
                  total: participantCount,
                  size: 14,
                ),
              ),
              _LabeledValue(
                label: '校区排名',
                child: StudyRankText(
                  rank: subject.organizationRanking,
                  total: organizationParticipantCount,
                  size: 14,
                ),
              ),
              if (subject.scoreChange != null)
                _LabeledValue(
                  label: '较上次',
                  child: StudyDeltaTag(value: subject.scoreChange),
                ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: AppSpace.s8,
                children: [
                  for (final action in actions)
                    _ActionButton(action: action, subject: subject),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.caption12),
        const SizedBox(width: AppSpace.s8),
        child,
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.subject});

  final StudySubjectAction action;
  final StudySubjectRecord subject;

  @override
  Widget build(BuildContext context) {
    final enabled = action.enabled(subject);
    return AppButton(
      label: action.label,
      icon: action.icon,
      variant: AppButtonVariant.text,
      size: AppButtonSize.sm,
      onTap: enabled ? () => action.onTap(subject) : null,
    );
  }
}
