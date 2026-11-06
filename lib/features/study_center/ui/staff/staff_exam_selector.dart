import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../widgets/study_common.dart';

/// 考试选择条（新 → 旧），阅卷中的考试不可选。
class StaffExamSelector extends StatelessWidget {
  const StaffExamSelector({
    required this.exams,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<TeacherExam> exams;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: exams.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final exam = exams[index];
          return _ExamChip(
            exam: exam,
            selected: exam.examId == selectedId,
            onTap: exam.isPublished ? () => onSelected(exam.examId) : null,
          );
        },
      ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final titleColor = selected
        ? Colors.white
        : (enabled ? ArtColors.ink : ArtColors.ink3);
    final detail = enabled
        ? '${studyDateText(exam.examTime)} · ${exam.participantCount} 人'
        : '${studyDateText(exam.examTime)} · 出分后可查看';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? ArtColors.brandGradient : null,
          color: selected ? null : ArtColors.subtle,
          borderRadius: BorderRadius.circular(12),
          border: selected ? null : Border.all(color: ArtColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exam.examName,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    color: titleColor,
                    fontFamily: 'PingFang SC',
                    fontWeight: selected ? AppFont.w600 : AppFont.w500,
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(width: 6),
                  const StudyChip(label: '阅卷中', color: ArtColors.warn),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: ArtText.caption(
                size: 11,
                color: selected ? Colors.white70 : ArtColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
