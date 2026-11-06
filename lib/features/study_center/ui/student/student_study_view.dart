import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/student_study_controller.dart';
import '../../state/study_center_args.dart';
import '../../state/study_report_controller.dart';
import '../growth/study_growth_view.dart';
import '../paper/study_paper_viewer_page.dart';
import '../report/study_report_view.dart';
import '../standard/grade_standard_dialog.dart';
import '../widgets/study_common.dart';
import '../widgets/study_hero_card.dart';
import '../widgets/study_interpretations.dart';
import '../widgets/study_subject_cards.dart';
import 'student_exam_list.dart';

/// 「我的学情」：总览 / 成绩报告 / 成长曲线三个页内视图。
class StudentStudyView extends ConsumerWidget {
  const StudentStudyView({required this.args, super.key});

  final StudyCenterArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studentStudyControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen<StudentStudyState>(provider, (previous, next) {
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) return;
      AppToast.showError(context, message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) controller.clearError();
      });
    });

    final Widget child = switch (state.section) {
      StudentStudySection.overview => _StudentOverview(
        key: const ValueKey<String>('study-overview'),
        state: state,
        controller: controller,
      ),
      StudentStudySection.report => StudyReportView(
        key: ValueKey<String>('study-report-${state.reportExamId}'),
        reportKey: StudyReportKey(examId: state.reportExamId),
        onBack: controller.back,
        onOpenTrend: controller.openGrowth,
        initialAction: state.pendingAction,
        initialSubjectId: state.pendingSubjectId,
        onInitialActionHandled: controller.consumePendingAction,
      ),
      StudentStudySection.growth => StudyGrowthView(
        key: const ValueKey<String>('study-growth'),
        archiveId: '',
        title: '成长曲线',
        subtitle: '仅统计已出分的考试 · 数据来自艺考网阅卷系统',
        onBack: controller.back,
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: child,
    );
  }
}

class _StudentOverview extends StatelessWidget {
  const _StudentOverview({
    required this.state,
    required this.controller,
    super.key,
  });

  final StudentStudyState state;
  final StudentStudyController controller;

  String _subtitle(StudyOverview overview) {
    final profile = overview.profile;
    final admission = overview.latestAdmissionNo;
    return [
      profile.schoolName,
      profile.organizationName,
      profile.name,
      if (admission.isNotEmpty) '准考证号 $admission',
    ].where((part) => part.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final overview = state.overview;
    final header = ArtPageHeader(
      title: '我的学情',
      subtitle: overview == null ? null : _subtitle(overview),
      actions: [
        ArtButton(
          label: '成长曲线',
          icon: Icons.show_chart_rounded,
          height: 36,
          onTap: controller.openGrowth,
        ),
      ],
    );
    final Widget body;
    if (overview == null) {
      body = state.loadFailed
          ? StudyErrorView(message: '学情数据加载失败', onRetry: controller.refresh)
          : const SizedBox.shrink();
    } else {
      body = _OverviewBody(
        overview: overview,
        state: state,
        controller: controller,
      );
    }
    return PageInitLoadingShell(
      loading: state.loading && overview == null,
      child: StudyPageFrame(header: header, body: body),
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({
    required this.overview,
    required this.state,
    required this.controller,
  });

  final StudyOverview overview;
  final StudentStudyState state;
  final StudentStudyController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = overview.recentStage;
    final reportState = recent == null
        ? null
        : ref.watch(
            studyReportControllerProvider(
              StudyReportKey(examId: recent.exam.examId),
            ),
          );
    final report = reportState?.report;
    final exam = recent == null
        ? null
        : (report?.exam ?? recent.exam).withSubjects(
            report?.subjects ?? recent.exam.subjects,
          );

    return AppRefreshIndicator(
      onRefresh: () async {
        if (recent != null) {
          ref.invalidate(
            studyReportControllerProvider(
              StudyReportKey(examId: recent.exam.examId),
            ),
          );
        }
        await controller.refresh();
      },
      child: ListView(
        key: const PageStorageKey<String>('study-overview-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (recent == null || exam == null)
            const StudyCard(
              child: ArtEmptyState(
                message: '还没有已出分的考试，出分后会在这里展示成绩与解读',
                icon: Icons.insights_outlined,
              ),
            )
          else ...[
            StudyHeroCard(
              exam: exam,
              scoreChange: report?.scoreChange ?? recent.scoreChange,
              rankingChange: report?.rankingChange ?? recent.rankingChange,
              surpassedPercent:
                  report?.surpassedPercent ??
                  surpassedPercentOf(exam.totalRanking, exam.participantCount),
              statistics: overview.statistics,
              onOpenReport: () => controller.openReport(exam.examId),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: StudySectionHeader(title: '各科表现', subtitle: exam.examName),
            ),
            StudySubjectCards(
              subjects: exam.subjects,
              onOpenPaper: (subject) => openStudyPaperViewer(
                context,
                exam: exam,
                subjectId: subject.subjectId,
              ),
              onOpenStandard: (subject) => showStudyGradeStandard(
                context,
                examId: exam.examId,
                subject: subject,
              ),
            ),
            const SizedBox(height: 12),
            StudyInterpretationsCard(
              items: report?.interpretations ?? const <StudyInterpretation>[],
              loading: report == null && (reportState?.loading ?? false),
            ),
          ],
          const SizedBox(height: 12),
          StudentExamListCard(
            state: state,
            onFilterChanged: controller.setFilter,
            onOpen: (item) => controller.openReport(item.examId),
            onLoadMore: () => controller.loadExams(),
          ),
          const SizedBox(height: 16),
          Text(
            '成绩以阅卷系统最终结果为准，仅供本人查阅',
            textAlign: TextAlign.center,
            style: ArtText.caption(),
          ),
        ],
      ),
    );
  }
}
