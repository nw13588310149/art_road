import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../data/study_models.dart';
import '../../state/student_study_controller.dart';
import '../../state/study_center_args.dart';
import '../../state/study_report_controller.dart';
import '../growth/study_growth_view.dart';
import '../paper/study_paper_viewer_page.dart';
import '../report/study_report_view.dart';
import '../standard/grade_standard_dialog.dart';
import '../widgets/study_common.dart';
import '../widgets/study_composite_estimate_card.dart';
import '../widgets/study_hero_card.dart';
import '../widgets/study_interpretations.dart';
import '../widgets/study_subject_cards.dart';
import 'student_exam_list.dart';

/// 「我的学情」：总览 / 成绩报告 / 成长曲线三个页内视图，切换立即生效。
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

    return switch (state.section) {
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
        subtitle: '仅统计已出分的考试 · 成绩来自艺考网阅卷系统',
        onBack: controller.back,
      ),
    };
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
    return [
      profile.schoolName,
      profile.organizationName,
      if (profile.studentNo.isNotEmpty) '学号 ${profile.studentNo}',
    ].where((part) => part.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final overview = state.overview;
    final header = AppPageHeader(
      title: '我的学情',
      subtitle: overview == null ? '成绩来自艺考网阅卷系统' : _subtitle(overview),
      actions: [
        AppButton(
          label: '成长曲线',
          icon: Icons.show_chart_rounded,
          size: AppButtonSize.sm,
          onTap: controller.openGrowth,
        ),
      ],
    );
    final Widget body;
    if (overview == null) {
      body = state.loadFailed
          ? AppErrorState(
              title: '学情数据加载失败',
              description: '请检查网络后重试',
              onRetry: controller.refresh,
            )
          : const _OverviewSkeleton();
    } else {
      body = _OverviewBody(
        overview: overview,
        state: state,
        controller: controller,
      );
    }
    return StudyPageFrame(header: header, body: body);
  }
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: studyBodyPadding,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpace.s20),
          child: Row(
            children: [
              const AppSkeleton.circle(size: 148),
              const SizedBox(width: AppSpace.s32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppSkeleton(width: 220, height: 24),
                    SizedBox(height: AppSpace.s12),
                    AppSkeleton(width: 300),
                    SizedBox(height: AppSpace.s24),
                    AppSkeletonText(lines: 2, lineHeight: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        const StudyCardSkeleton(lines: 5),
      ],
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
        padding: studyBodyPadding,
        children: [
          if (recent == null || exam == null)
            AppCard(
              child: SizedBox(
                height: 200,
                child: AppEmptyState(
                  icon: Icons.insights_outlined,
                  title: '还没有已出分的考试',
                  description: '阅卷完成、成绩发布后，这里会展示总分、排名与各科表现',
                ),
              ),
            )
          else ...[
            StudyHeroCard(
              exam: exam,
              scoreChange: report?.scoreChange ?? recent.scoreChange,
              rankingChange: report?.rankingChange ?? recent.rankingChange,
              surpassedPercent: report?.surpassedPercent,
              statistics: overview.statistics,
              onOpenReport: () => controller.openReport(exam.examId),
            ),
            const SizedBox(height: AppSpace.s24),
            AppSectionHeader(title: '各科表现', subtitle: exam.examName),
            const SizedBox(height: AppSpace.s12),
            StudySubjectCards(
              subjects: exam.subjects,
              participantCount: exam.participantCount,
              organizationParticipantCount: exam.organizationParticipantCount,
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
            const SizedBox(height: AppSpace.s16),
            StudyInterpretationsCard(
              items: report?.interpretations ?? const <StudyInterpretation>[],
              loading: report == null && (reportState?.loading ?? false),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          StudyCompositeEstimateCard(exam: exam),
          const SizedBox(height: AppSpace.s16),
          StudentExamListCard(
            state: state,
            onFilterChanged: controller.setFilter,
            onOpen: (item) => controller.openReport(item.examId),
            onLoadMore: () => controller.loadExams(),
          ),
          const StudyFootnote('成绩以阅卷系统最终结果为准，仅供本人查阅'),
        ],
      ),
    );
  }
}
