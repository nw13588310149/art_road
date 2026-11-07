import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/study_center_args.dart';
import '../../state/study_report_controller.dart';
import '../paper/study_paper_viewer_page.dart';
import '../staff/marking_detail_dialog.dart';
import '../standard/grade_standard_dialog.dart';
import '../widgets/study_common.dart';
import '../widgets/study_hero_card.dart';
import '../widgets/study_interpretations.dart';
import 'study_subject_table.dart';

/// 单场考试成绩报告（页内视图）：学生本人查看，或教职查看某位学生。
class StudyReportView extends ConsumerStatefulWidget {
  const StudyReportView({
    required this.reportKey,
    required this.onBack,
    this.onOpenTrend,
    this.studentName = '',
    this.initialAction,
    this.initialSubjectId = '',
    this.onInitialActionHandled,
    super.key,
  });

  final StudyReportKey reportKey;
  final VoidCallback onBack;
  final VoidCallback? onOpenTrend;

  /// 教职视角下显示的学生姓名。
  final String studentName;

  /// 报告加载后自动打开原卷或评分标准（来自路由参数）。
  final StudyCenterInitialView? initialAction;
  final String initialSubjectId;
  final VoidCallback? onInitialActionHandled;

  @override
  ConsumerState<StudyReportView> createState() => _StudyReportViewState();
}

class _StudyReportViewState extends ConsumerState<StudyReportView> {
  bool _initialActionScheduled = false;

  void _scheduleInitialAction(StudyExamRecord exam) {
    final action = widget.initialAction;
    if (_initialActionScheduled ||
        (action != StudyCenterInitialView.paper &&
            action != StudyCenterInitialView.standard)) {
      return;
    }
    _initialActionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onInitialActionHandled?.call();
      final subjects = exam.subjects;
      if (subjects.isEmpty) {
        return;
      }
      final requested = exam.subjectById(widget.initialSubjectId);
      if (action == StudyCenterInitialView.paper) {
        final target =
            requested ??
            subjects.where((s) => s.paperAvailable).firstOrNull ??
            subjects.first;
        openStudyPaperViewer(context, exam: exam, subjectId: target.subjectId);
      } else {
        showStudyGradeStandard(
          context,
          examId: exam.examId,
          subject: requested ?? subjects.first,
        );
      }
    });
  }

  List<StudySubjectAction> _actions(StudyExamRecord exam) {
    final key = widget.reportKey;
    if (key.isStaff) {
      return [
        StudySubjectAction(
          label: '阅卷明细',
          icon: Icons.fact_check_outlined,
          enabled: (subject) => subject.hasScore,
          onTap: (subject) => showMarkingDetailDialog(
            context,
            archiveId: key.archiveId,
            examId: exam.examId,
            subject: subject,
            studentName: widget.studentName,
          ),
        ),
      ];
    }
    return [
      StudySubjectAction(
        label: '看原卷',
        icon: Icons.image_outlined,
        enabled: (subject) => subject.paperAvailable,
        onTap: (subject) => openStudyPaperViewer(
          context,
          exam: exam,
          subjectId: subject.subjectId,
        ),
      ),
      StudySubjectAction(
        label: '评分标准',
        icon: Icons.rule_rounded,
        onTap: (subject) => showStudyGradeStandard(
          context,
          examId: exam.examId,
          subject: subject,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = studyReportControllerProvider(widget.reportKey);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen<StudyReportState>(provider, (previous, next) {
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) {
        return;
      }
      AppToast.showError(context, message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.clearError();
        }
      });
    });

    final report = state.report;
    StudyExamRecord? exam;
    if (report != null) {
      exam = report.exam.withSubjects(report.subjects);
      _scheduleInitialAction(exam);
    }

    final staff = widget.reportKey.isStaff;
    final openTrend = widget.onOpenTrend;
    final header = AppPageHeader(
      title: exam == null
          ? '成绩报告'
          : (staff && widget.studentName.isNotEmpty
                ? '${widget.studentName} · ${exam.examName}'
                : exam.examName),
      subtitle: exam == null
          ? null
          : [
              studyDateText(exam.examTime),
              if (exam.admissionNo.isNotEmpty) '准考证号 ${exam.admissionNo}',
              if (exam.organizationName.isNotEmpty) exam.organizationName,
            ].join(' · '),
      onBack: widget.onBack,
      actions: [
        if (openTrend != null)
          AppButton(
            label: staff ? '成绩曲线' : '成长曲线',
            icon: Icons.show_chart_rounded,
            variant: AppButtonVariant.quiet,
            size: AppButtonSize.sm,
            onTap: openTrend,
          ),
      ],
    );

    final Widget body;
    if (report == null || exam == null) {
      body = state.failed
          ? AppErrorState(
              title: '成绩报告加载失败',
              description: state.errorMessage.isEmpty
                  ? '请检查网络后重试'
                  : state.errorMessage,
              onRetry: controller.load,
            )
          : ListView(
              padding: studyBodyPadding,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                StudyCardSkeleton(lines: 4),
                SizedBox(height: AppSpace.s16),
                StudyCardSkeleton(lines: 3),
              ],
            );
    } else {
      final scored = exam.isPublished && exam.hasScore;
      body = ListView(
        padding: studyBodyPadding,
        children: [
          if (!scored) ...[
            AppNotice(
              tone: AppTone.warning,
              message: exam.isPublished
                  ? '这场考试暂无成绩，可能缺考或成绩未录入'
                  : '这场考试仍在阅卷中，出分后会通知你',
            ),
            const SizedBox(height: AppSpace.s16),
          ],
          StudyHeroCard(
            exam: exam,
            scoreChange: report.scoreChange,
            rankingChange: report.rankingChange,
            surpassedPercent: report.surpassedPercent,
          ),
          const SizedBox(height: AppSpace.s16),
          StudySubjectTable(
            subjects: exam.subjects,
            actions: _actions(exam),
            participantCount: exam.participantCount,
            organizationParticipantCount: exam.organizationParticipantCount,
          ),
          if (report.interpretations.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s16),
            StudyInterpretationsCard(items: report.interpretations),
          ],
          StudyFootnote(
            staff ? '成绩以阅卷系统最终结果为准，仅供机构内部查阅' : '成绩以阅卷系统最终结果为准，仅供本人查阅',
          ),
        ],
      );
    }

    return StudyPageFrame(header: header, body: body);
  }
}
