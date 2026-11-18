import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../data/exam_critique_models.dart';
import '../../state/exam_critique_controller.dart';
import '../../state/study_detail_providers.dart';
import 'exam_critique_workspace.dart';

/// 班级学情选了科目后的一行「月考讲评」：状态（未开始 / 草稿 N 张 / 已发布 N 张）和
/// 打开讲评工作台的入口。能不能改由接口的 `access.canEdit` 决定。
class StaffCritiqueEntry extends ConsumerWidget {
  const StaffCritiqueEntry({
    required this.examId,
    required this.subjectId,
    super.key,
  });

  final String examId;
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = StudySubjectKey(examId: examId, subjectId: subjectId);
    final summary = ref.watch(staffCritiqueSummaryProvider(key));
    final board = summary.valueOrNull;
    Future<void> open() async {
      await openExamCritiqueWorkspace(
        context,
        examId: examId,
        subjectId: subjectId,
      );
      ref.invalidate(staffCritiqueSummaryProvider(key));
    }

    final Widget status;
    final String note;
    Widget? action;
    if (board == null) {
      status = summary.hasError
          ? const AppStatusTag(label: '加载失败')
          : const AppSkeleton(width: 64, height: 16);
      note = '';
      if (summary.hasError) {
        action = AppPlainButton(
          label: '重试',
          onTap: () => ref.invalidate(staffCritiqueSummaryProvider(key)),
        );
      }
    } else {
      final critique = board.critique;
      final started = critique.papers.isNotEmpty;
      status = AppStatusTag(
        label: critiqueStatusText(critique),
        tone: critique.published && started ? AppTone.success : AppTone.neutral,
      );
      note = started && critique.teacherName.isNotEmpty
          ? '${critique.teacherName}老师'
          : (board.canEdit ? '每一档挑一张代表卷，在卷面上标出要讲的地方' : '任课老师发布后学生在「学情」查看');
      if (board.canEdit || started) {
        action = AppButton(
          label: board.canEdit ? (started ? '继续讲评' : '开始讲评') : '查看讲评',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          onTap: open,
        );
      }
    }
    return Row(
      children: [
        const Icon(
          Icons.record_voice_over_outlined,
          size: 18,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpace.s8),
        Text('月考讲评', style: AppText.body14Strong),
        const SizedBox(width: AppSpace.s12),
        status,
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption12,
          ),
        ),
        ?action,
      ],
    );
  }
}
