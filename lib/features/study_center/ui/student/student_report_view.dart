import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/study_center_args.dart';
import '../../state/study_report_controller.dart';
import '../paper/study_paper_viewer_page.dart';
import '../standard/grade_standard_dialog.dart';
import '../widgets/study_common.dart';
import 'student_study_parts.dart';

/// 学生本人的单场成绩报告（详情页）：一行总分和名次，下面是完整的各科成绩表和
/// 表现解读。教职查看学生的报告仍用 `StudyReportView`。
class StudentReportView extends ConsumerStatefulWidget {
  const StudentReportView({
    required this.examId,
    required this.onBack,
    required this.onOpenTrend,
    this.initialAction,
    this.initialSubjectId = '',
    this.onInitialActionHandled,
    super.key,
  });

  final String examId;
  final VoidCallback onBack;
  final VoidCallback onOpenTrend;

  /// 报告加载后自动打开原卷或评分标准（来自路由参数）。
  final StudyCenterInitialView? initialAction;
  final String initialSubjectId;
  final VoidCallback? onInitialActionHandled;

  @override
  ConsumerState<StudentReportView> createState() => _StudentReportViewState();
}

class _StudentReportViewState extends ConsumerState<StudentReportView> {
  bool _initialActionScheduled = false;

  StudyReportKey get _key => StudyReportKey(examId: widget.examId);

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
        _openStandard(exam, requested ?? subjects.first);
      }
    });
  }

  void _openStandard(StudyExamRecord exam, StudySubjectRecord subject) {
    showStudyGradeStandard(
      context,
      examId: exam.examId,
      subject: subject,
      subjects: exam.subjects,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = studyReportControllerProvider(_key);
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
    final exam = report?.exam.withSubjects(report.subjects);
    if (exam != null) {
      _scheduleInitialAction(exam);
    }

    return AppPageBody(
      builder: (context, wide) {
        final titleBar = AppTitleBar(
          title: exam?.examName ?? '成绩报告',
          caption: exam == null
              ? ''
              : [
                  studyDateText(exam.examTime),
                  if (exam.admissionNo.isNotEmpty) '准考证号 ${exam.admissionNo}',
                  if (exam.organizationName.isNotEmpty) exam.organizationName,
                ].join(' · '),
          onBack: widget.onBack,
          actions: [
            AppPlainButton(
              label: '成长曲线',
              icon: Icons.show_chart_rounded,
              onTap: widget.onOpenTrend,
            ),
          ],
        );
        final Widget body;
        if (report == null || exam == null) {
          body = state.failed
              ? SizedBox(
                  height: 360,
                  child: AppErrorState(
                    title: '成绩报告加载失败',
                    description: state.errorMessage.isEmpty
                        ? '请检查网络后重试'
                        : state.errorMessage,
                    onRetry: controller.load,
                  ),
                )
              : const _ReportSkeleton();
        } else {
          body = _ReportBody(
            report: report,
            exam: exam,
            onOpenPaper: (subject) => openStudyPaperViewer(
              context,
              exam: exam,
              subjectId: subject.subjectId,
            ),
            onOpenStandard: () => _openStandard(exam, exam.subjects.first),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleBar,
            const SizedBox(height: AppSpace.s24),
            body,
          ],
        );
      },
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.report,
    required this.exam,
    required this.onOpenPaper,
    required this.onOpenStandard,
  });

  final StudyExamReport report;
  final StudyExamRecord exam;
  final ValueChanged<StudySubjectRecord> onOpenPaper;
  final VoidCallback onOpenStandard;

  @override
  Widget build(BuildContext context) {
    final scored = exam.isPublished && exam.hasScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scored)
          _ReportSummary(report: report, exam: exam)
        else
          Row(
            children: [
              AppStatusTag(
                label: exam.isPublished ? '无成绩' : '阅卷中',
                tone: exam.isPublished ? AppTone.neutral : AppTone.warning,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(
                  exam.isPublished
                      ? '这场考试暂无成绩，可能缺考或成绩未录入'
                      : '这场考试仍在阅卷中，出分后会通知你',
                  style: AppText.body14,
                ),
              ),
            ],
          ),
        const StudentSectionGap(),
        AppSectionTitle(
          title: '各科成绩',
          note: '共 ${exam.subjects.length} 科 · 点一科查看原卷',
          trailing: exam.subjects.isEmpty
              ? null
              : AppPlainButton(label: '评分标准', onTap: onOpenStandard),
        ),
        StudentSubjectTable(exam: exam, onOpenPaper: onOpenPaper, full: true),
        if (report.interpretations.isNotEmpty) ...[
          const StudentSectionGap(),
          const AppSectionTitle(title: '表现解读', note: '根据本次各科成绩整理'),
          const SizedBox(height: AppSpace.s4),
          StudentInterpretations(items: report.interpretations),
        ],
        const StudentFootnote('成绩以阅卷系统最终结果为准，仅供本人查阅'),
      ],
    );
  }
}

/// 报告的一行总览：总分、两种名次、较上次，并排，中间竖线隔开。
class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report, required this.exam});

  final StudyExamReport report;
  final StudyExamRecord exam;

  @override
  Widget build(BuildContext context) {
    final organization = exam.organizationName.isEmpty
        ? '校区'
        : exam.organizationName;
    final percent =
        surpassedPercentOf(exam.totalRanking, exam.participantCount) ??
        report.surpassedPercent;
    final scoreChange = report.scoreChange;
    final rankingChange = report.rankingChange;
    final blocks = <Widget>[
      _SummaryBlock(
        label: '总分',
        value: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatScore(exam.totalScore),
                style: AppText.displayNumber(),
              ),
              if (exam.maxScore != null)
                TextSpan(
                  text: ' / ${formatScore(exam.maxScore)} 分',
                  style: AppText.body13,
                ),
            ],
          ),
        ),
      ),
      _SummaryBlock(
        label: '全画室排名',
        value: StudyRankText(
          rank: exam.totalRanking,
          total: exam.participantCount,
          size: 20,
        ),
        note: percent == null ? '' : '超过全画室 $percent% 的考生',
      ),
      _SummaryBlock(
        label: '$organization排名',
        value: StudyRankText(
          rank: exam.organizationRanking,
          total: exam.organizationParticipantCount,
          size: 20,
        ),
      ),
      if (scoreChange != null || rankingChange != null)
        _SummaryBlock(
          label: '较上次',
          value: Wrap(
            spacing: AppSpace.s12,
            runSpacing: AppSpace.s4,
            children: [
              StudyDeltaText(scoreChange, size: 16),
              if (rankingChange != null)
                StudyDeltaText(rankingChange, unit: '名', size: 16),
            ],
          ),
        ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const AppRule.vertical(gap: AppSpace.s32 + 1),
            Expanded(flex: i == 0 ? 4 : 5, child: blocks[i]),
          ],
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.label,
    required this.value,
    this.note = '',
  });

  final String label;
  final Widget value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption12),
        const SizedBox(height: AppSpace.s4),
        SizedBox(
          height: 36,
          child: Align(alignment: Alignment.centerLeft, child: value),
        ),
        if (note.isNotEmpty) Text(note, style: AppText.caption12),
      ],
    );
  }
}

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSkeleton(height: 64),
        StudentSectionGap(),
        AppSkeletonText(lines: 4, lineHeight: 20),
      ],
    );
  }
}
