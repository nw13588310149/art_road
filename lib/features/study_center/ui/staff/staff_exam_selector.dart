import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';

/// 考试选择：最近 3 场直接点选，其余收进「更多考试」下拉；阅卷中的考试不可选。
class StaffExamSelector extends StatelessWidget {
  const StaffExamSelector({
    required this.exams,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  /// 新 → 旧。
  final List<TeacherExam> exams;
  final String selectedId;
  final ValueChanged<String> onSelected;

  static const _inlineCount = 3;

  @override
  Widget build(BuildContext context) {
    final inline = exams.take(_inlineCount).toList();
    final rest = exams.skip(_inlineCount).toList();
    final restSelected = rest.any((exam) => exam.examId == selectedId);
    return Wrap(
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final exam in inline)
          _ExamChip(
            exam: exam,
            selected: exam.examId == selectedId,
            onTap: exam.isPublished
                ? () => onSelected(exam.examId)
                : () => AppToast.showInfo(
                    context,
                    '${exam.examName}阅卷中，出分后可查看班级学情',
                  ),
          ),
        if (rest.isNotEmpty)
          SizedBox(
            width: 184,
            child: AppSelect<String>(
              options: [
                for (final exam in rest)
                  AppSelectOption<String>(
                    value: exam.examId,
                    label: exam.isPublished
                        ? exam.examName
                        : '${exam.examName}（阅卷中）',
                    enabled: exam.isPublished,
                  ),
              ],
              value: restSelected ? selectedId : null,
              hint: '更多考试（${rest.length} 场）',
              onChanged: onSelected,
            ),
          ),
      ],
    );
  }
}

class _ExamChip extends StatelessWidget {
  const _ExamChip({
    required this.exam,
    required this.selected,
    required this.onTap,
  });

  final TeacherExam exam;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final published = exam.isPublished;
    return AppPressable(
      onTap: onTap,
      selected: selected,
      child: Container(
        constraints: const BoxConstraints(minWidth: 132),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandWash : AppColors.surface,
          borderRadius: AppRadius.br8,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              exam.examName,
              maxLines: 1,
              style: AppText.body14Strong.copyWith(
                color: selected
                    ? AppColors.brandDeep
                    : (published ? AppColors.ink : AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 2),
            if (published)
              Text(
                '${studyDateText(exam.examTime)} · ${exam.participantCount} 人参考',
                maxLines: 1,
                style: AppText.caption12,
              )
            else
              const AppStatusTag(label: '阅卷中', tone: AppTone.warning),
          ],
        ),
      ),
    );
  }
}
