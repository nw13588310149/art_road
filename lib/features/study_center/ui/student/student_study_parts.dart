import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';

/// 学生「学情」的三个视图，在页头名称右边切换。
enum StudentStudyTab {
  overview('总览'),
  growth('成长曲线'),
  artwork('作品成长');

  const StudentStudyTab(this.label);

  final String label;
}

/// 学生「学情」的页头：名称加三个视图的切换。
class StudentStudyTitleBar extends StatelessWidget {
  const StudentStudyTitleBar({
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final StudentStudyTab selected;
  final ValueChanged<StudentStudyTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppTitleBar(
      title: '学情',
      tabs: AppViewTabs<StudentStudyTab>(
        items: [
          for (final tab in StudentStudyTab.values)
            AppViewTab(value: tab, label: tab.label),
        ],
        value: selected,
        onChanged: onSelect,
      ),
    );
  }
}

/// 主栏加侧栏。内容区放不下两栏时（主栏不足 [minMain]）改成上下排。
class StudentColumns extends StatelessWidget {
  const StudentColumns({
    required this.wide,
    required this.main,
    required this.side,
    this.minMain = 480,
    super.key,
  });

  final bool wide;
  final Widget main;
  final Widget side;
  final double minMain;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final gap = AppPageBody.columnGap(wide);
        final sideWidth = AppPageBody.sideWidth(wide);
        if (box.maxWidth - gap - sideWidth < minMain) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [main, const StudentSectionGap(), side],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: main),
            SizedBox(width: gap),
            SizedBox(width: sideWidth, child: side),
          ],
        );
      },
    );
  }
}

/// 分区之间：留 24，画一条细线，再留 24。
class StudentSectionGap extends StatelessWidget {
  const StudentSectionGap({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpace.s24),
      child: AppRule(),
    );
  }
}

/// 较上次的变化：上升绿色、下降红色，箭头和文字一起表达方向；持平是灰字。
class StudyDeltaText extends StatelessWidget {
  const StudyDeltaText(
    this.value, {
    this.unit = '分',
    this.size = 14,
    super.key,
  });

  final num? value;
  final String unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final delta = value;
    final unitStyle = (size >= 16 ? AppText.body13 : AppText.caption12);
    if (delta == null) {
      return Text(
        '—',
        style: AppText.number(size: size, color: AppColors.textTertiary),
      );
    }
    if (delta.abs() < 0.05) {
      return Text('持平', style: unitStyle);
    }
    final up = delta > 0;
    final color = up ? AppColors.success : AppColors.danger;
    final amount = unit == '名'
        ? delta.abs().round().toString()
        : formatScoreDelta(delta);
    return Semantics(
      label: '${up ? '上升' : '下降'} $amount $unit',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: size,
            color: color,
          ),
          const SizedBox(width: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: amount,
                  style: AppText.number(size: size, color: color),
                ),
                TextSpan(
                  text: ' $unit',
                  style: unitStyle.copyWith(color: color),
                ),
              ],
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// 表格里的名次：「第 11 名 / 38」。
class StudyRankCell extends StatelessWidget {
  const StudyRankCell({required this.rank, this.total, super.key});

  final int? rank;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final value = rank;
    if (value == null) {
      return Text(
        '—',
        style: AppText.number(size: 14, color: AppColors.textTertiary),
      );
    }
    final count = total;
    final small = AppText.caption12.copyWith(color: AppColors.textSecondary);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '第 ', style: small),
          TextSpan(text: '$value', style: AppText.number(size: 14)),
          TextSpan(text: ' 名', style: small),
          if (count != null && count > 0)
            TextSpan(text: ' / $count', style: AppText.caption12),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 分数加满分：「92.5 / 100」。
class StudyScoreCell extends StatelessWidget {
  const StudyScoreCell({
    required this.score,
    this.maxScore,
    this.size = 14,
    this.unit = '',
    super.key,
  });

  final double? score;
  final double? maxScore;
  final double size;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final value = score;
    final full = maxScore;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatScore(value),
            style: AppText.number(
              size: size,
              color: value == null ? AppColors.textTertiary : AppColors.ink,
            ),
          ),
          if (full != null)
            TextSpan(
              text: ' / ${formatScore(full)}$unit',
              style: size >= 20 ? AppText.body13 : AppText.caption12,
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 各科成绩：整行可点，打开这一科的原卷。
///
/// 总览用五列（科目、档位、成绩、科目排名、较上次）；完整报告 [full] 再加上得分率和
/// 校区排名。
class StudentSubjectTable extends StatelessWidget {
  const StudentSubjectTable({
    required this.exam,
    required this.onOpenPaper,
    this.full = false,
    super.key,
  });

  final StudyExamRecord exam;
  final ValueChanged<StudySubjectRecord> onOpenPaper;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final subjects = exam.subjects;
    if (subjects.isEmpty) {
      return const SizedBox(
        height: 160,
        child: AppEmptyState(
          icon: Icons.assignment_outlined,
          title: '暂无各科成绩',
          description: '阅卷完成后会显示各科分数与档位',
        ),
      );
    }
    final organization = exam.organizationName.isEmpty
        ? '校区'
        : exam.organizationName;
    return AppDataTable(
      semanticLabel: '各科成绩',
      columns: [
        const AppTableColumn('科目', flex: 3),
        const AppTableColumn('档位', flex: 2),
        const AppTableColumn('成绩', flex: 3, numeric: true),
        if (full) const AppTableColumn('得分率', flex: 2, numeric: true),
        const AppTableColumn('科目排名', flex: 3, numeric: true),
        if (full) AppTableColumn('$organization排名', flex: 3, numeric: true),
        const AppTableColumn('较上次', flex: 3, numeric: true),
      ],
      rows: [
        for (final subject in subjects)
          AppTableRow([
            subject.subjectName,
            subject.hasScore
                ? (subject.grade.isEmpty ? '—' : '${subject.grade} 档')
                : '待出分',
            StudyScoreCell(score: subject.score, maxScore: subject.maxScore),
            if (full) _rateText(subject.rate),
            StudyRankCell(rank: subject.ranking, total: exam.participantCount),
            if (full)
              StudyRankCell(
                rank: subject.organizationRanking,
                total: exam.organizationParticipantCount,
              ),
            StudyDeltaText(subject.scoreChange),
          ], onTap: subject.paperAvailable ? () => onOpenPaper(subject) : null),
      ],
    );
  }

  static String _rateText(double? rate) =>
      rate == null ? '—' : '${(rate * 100).round()}%';
}

/// 表现解读：每条前面一个「优势 / 待提升」的状态标记。
class StudentInterpretations extends StatelessWidget {
  const StudentInterpretations({
    required this.items,
    this.loading = false,
    super.key,
  });

  final List<StudyInterpretation> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: AppSkeletonText(lines: 3),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: Text('出分后会根据各科成绩整理优势与待提升的地方', style: AppText.body13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const AppRule(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  height: 22,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppStatusTag(
                      label: items[i].isStrength ? '优势' : '待提升',
                      tone: items[i].isStrength
                          ? AppTone.success
                          : AppTone.warning,
                    ),
                  ),
                ),
                Expanded(child: Text(items[i].text, style: AppText.body14)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 页尾的一行口径说明。
class StudentFootnote extends StatelessWidget {
  const StudentFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s32),
      child: Text(text, style: AppText.caption12),
    );
  }
}
