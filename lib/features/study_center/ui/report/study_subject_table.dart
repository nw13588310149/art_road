import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/art_widgets.dart';
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
    super.key,
  });

  final List<StudySubjectRecord> subjects;
  final List<StudySubjectAction> actions;

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      title: '各科成绩',
      subtitle: '共 ${subjects.length} 科',
      child: subjects.isEmpty
          ? Text(
              '阅卷完成后会显示各科成绩',
              style: ArtText.body(size: 13, color: ArtColors.ink3),
            )
          : LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 820
                  ? _TableLayout(subjects: subjects, actions: actions)
                  : _ListLayout(subjects: subjects, actions: actions),
            ),
    );
  }
}

const _flexName = 3;
const _flexScore = 3;
const _flexGrade = 2;
const _flexRate = 4;
const _flexRank = 2;
const _flexChange = 3;

class _TableLayout extends StatelessWidget {
  const _TableLayout({required this.subjects, required this.actions});

  final List<StudySubjectRecord> subjects;
  final List<StudySubjectAction> actions;

  @override
  Widget build(BuildContext context) {
    final actionFlex = actions.length >= 2 ? 5 : 3;
    Widget head(String text, int flex) => Expanded(
      flex: flex,
      child: Text(text, style: ArtText.caption(size: 12)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ArtColors.subtle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              head('科目', _flexName),
              head('成绩', _flexScore),
              head('档位', _flexGrade),
              head('得分率', _flexRate),
              const SizedBox(width: 16),
              head('科目排名', _flexRank),
              head('校区排名', _flexRank),
              head('较上次', _flexChange),
              head('操作', actionFlex),
            ],
          ),
        ),
        for (var i = 0; i < subjects.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: ArtColors.line),
          _TableRow(
            subject: subjects[i],
            actions: actions,
            actionFlex: actionFlex,
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
  });

  final StudySubjectRecord subject;
  final List<StudySubjectAction> actions;
  final int actionFlex;

  @override
  Widget build(BuildContext context) {
    final accent = artSubjectColor(subject.subjectName);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    subject.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ArtText.body(size: 14, weight: AppFont.w500),
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
              size: 17,
              color: subject.hasScore ? accent : ArtColors.ink3,
            ),
          ),
          Expanded(
            flex: _flexGrade,
            child: Align(
              alignment: Alignment.centerLeft,
              child: subject.grade.isEmpty
                  ? Text('—', style: ArtText.caption())
                  : ArtGradeBadge(grade: subject.grade, size: 24),
            ),
          ),
          Expanded(
            flex: _flexRate,
            child: Row(
              children: [
                Expanded(
                  child: StudyProgressBar(value: subject.rate, color: accent),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  child: Text(
                    studyPercentText(subject.rate),
                    style: ArtText.number(size: 12, color: ArtColors.ink2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: _flexRank,
            child: StudyRankText(rank: subject.ranking, size: 14),
          ),
          Expanded(
            flex: _flexRank,
            child: StudyRankText(rank: subject.organizationRanking, size: 14),
          ),
          Expanded(
            flex: _flexChange,
            child: Align(
              alignment: Alignment.centerLeft,
              child: subject.scoreChange == null
                  ? Text('—', style: ArtText.caption())
                  : StudyDeltaTag(value: subject.scoreChange),
            ),
          ),
          Expanded(
            flex: actionFlex,
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final action in actions)
                  _ActionLink(action: action, subject: subject),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListLayout extends StatelessWidget {
  const _ListLayout({required this.subjects, required this.actions});

  final List<StudySubjectRecord> subjects;
  final List<StudySubjectAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < subjects.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _ListItem(subject: subjects[i], actions: actions),
        ],
      ],
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({required this.subject, required this.actions});

  final StudySubjectRecord subject;
  final List<StudySubjectAction> actions;

  @override
  Widget build(BuildContext context) {
    final accent = artSubjectColor(subject.subjectName);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ArtColors.subtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StudySubjectIcon(subjectName: subject.subjectName, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subject.subjectName,
                  style: ArtText.body(size: 15, weight: AppFont.w500),
                ),
              ),
              if (subject.grade.isNotEmpty) ...[
                ArtGradeBadge(grade: subject.grade, size: 24),
                const SizedBox(width: 10),
              ],
              StudyNumberText(
                formatScore(subject.score),
                unit: ' / ${formatScore(subject.maxScore)}',
                size: 20,
                color: subject.hasScore ? accent : ArtColors.ink3,
              ),
            ],
          ),
          const SizedBox(height: 10),
          StudyProgressBar(value: subject.rate, color: accent),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LabeledValue(
                label: '得分率',
                child: Text(
                  studyPercentText(subject.rate),
                  style: ArtText.number(size: 14),
                ),
              ),
              _LabeledValue(
                label: '科目排名',
                child: StudyRankText(rank: subject.ranking, size: 14),
              ),
              _LabeledValue(
                label: '校区排名',
                child: StudyRankText(
                  rank: subject.organizationRanking,
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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 16,
                children: [
                  for (final action in actions)
                    _ActionLink(action: action, subject: subject),
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
        Text(label, style: ArtText.caption()),
        const SizedBox(width: 6),
        child,
      ],
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({required this.action, required this.subject});

  final StudySubjectAction action;
  final StudySubjectRecord subject;

  @override
  Widget build(BuildContext context) {
    final enabled = action.enabled(subject);
    final color = enabled ? ArtColors.brandDeep : ArtColors.ink4;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => action.onTap(subject) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 15, color: color),
            const SizedBox(width: 3),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                color: color,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
