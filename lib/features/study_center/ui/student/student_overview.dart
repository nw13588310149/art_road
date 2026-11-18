import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/student_study_controller.dart';
import '../../state/study_report_controller.dart';
import '../paper/study_paper_viewer_page.dart';
import '../standard/grade_standard_dialog.dart';
import '../widgets/study_common.dart';
import '../widgets/study_composite_estimate_card.dart';
import 'student_exam_list.dart';
import 'student_study_parts.dart';

/// 学生「学情」总览：最近一次考试的总分和各科，侧栏是考试记录。
class StudentOverview extends ConsumerWidget {
  const StudentOverview({
    required this.state,
    required this.controller,
    required this.onSelectTab,
    super.key,
  });

  final StudentStudyState state;
  final StudentStudyController controller;
  final ValueChanged<StudentStudyTab> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = state.overview;
    final recent = overview?.recentStage;
    final reportKey = recent == null
        ? null
        : StudyReportKey(examId: recent.exam.examId);
    final reportState = reportKey == null
        ? null
        : ref.watch(studyReportControllerProvider(reportKey));
    final report = reportState?.report;
    final exam = recent == null
        ? null
        : (report?.exam ?? recent.exam).withSubjects(
            report?.subjects ?? recent.exam.subjects,
          );

    return AppRefreshIndicator(
      onRefresh: () async {
        if (reportKey != null) {
          ref.invalidate(studyReportControllerProvider(reportKey));
        }
        await controller.refresh();
      },
      child: AppPageBody.slivers(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: (context, wide) {
          final Widget body;
          if (overview == null) {
            body = state.loadFailed
                ? SizedBox(
                    height: 360,
                    child: AppErrorState(
                      title: '学情数据加载失败',
                      description: '请检查网络后重试',
                      onRetry: controller.refresh,
                    ),
                  )
                : _OverviewSkeleton(wide: wide);
          } else {
            body = StudentColumns(
              wide: wide,
              main: _OverviewMain(
                overview: overview,
                exam: exam,
                recent: recent,
                report: report,
                reportLoading:
                    report == null && (reportState?.loading ?? false),
                wide: wide,
                onOpenReport: controller.openReport,
              ),
              side: StudentExamRecords(
                state: state,
                onFilterChanged: controller.setFilter,
                onOpen: (item) => controller.openReport(item.examId),
                onLoadMore: () => controller.loadExams(),
                onRetry: () => controller.loadExams(reset: true),
              ),
            );
          }
          return [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StudentStudyTitleBar(
                    selected: StudentStudyTab.overview,
                    onSelect: onSelectTab,
                  ),
                  const SizedBox(height: AppSpace.s24),
                  body,
                ],
              ),
            ),
          ];
        },
      ),
    );
  }
}

class _OverviewMain extends StatelessWidget {
  const _OverviewMain({
    required this.overview,
    required this.exam,
    required this.recent,
    required this.report,
    required this.reportLoading,
    required this.wide,
    required this.onOpenReport,
  });

  final StudyOverview overview;
  final StudyExamRecord? exam;
  final StudyRecentStage? recent;
  final StudyExamReport? report;
  final bool reportLoading;
  final bool wide;
  final ValueChanged<String> onOpenReport;

  @override
  Widget build(BuildContext context) {
    final profile = overview.profile;
    final studentLabel = [
      profile.schoolName,
      profile.organizationName,
      if (profile.studentNo.isNotEmpty) '学号 ${profile.studentNo}',
    ].where((part) => part.isNotEmpty).join(' · ');
    final current = exam;
    final stage = recent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current == null || stage == null)
          const SizedBox(
            height: 240,
            child: AppEmptyState(
              icon: Icons.insights_outlined,
              title: '还没有已出分的考试',
              description: '阅卷完成、成绩发布后，这里会展示总分、排名与各科表现',
            ),
          )
        else ...[
          _LatestExam(
            exam: current,
            wide: wide,
            scoreChange: report?.scoreChange ?? stage.scoreChange,
            rankingChange: report?.rankingChange ?? stage.rankingChange,
            surpassedPercent:
                surpassedPercentOf(
                  current.totalRanking,
                  current.participantCount,
                ) ??
                report?.surpassedPercent,
            onOpenReport: () => onOpenReport(current.examId),
          ),
          const StudentSectionGap(),
          AppSectionTitle(
            title: '各科成绩',
            note: '点一科查看原卷',
            trailing: current.subjects.isEmpty
                ? null
                : AppPlainButton(
                    label: '评分标准',
                    onTap: () => showStudyGradeStandard(
                      context,
                      examId: current.examId,
                      subject: current.subjects.first,
                      subjects: current.subjects,
                    ),
                  ),
          ),
          StudentSubjectTable(
            exam: current,
            onOpenPaper: (subject) => openStudyPaperViewer(
              context,
              exam: current,
              subjectId: subject.subjectId,
            ),
          ),
          const StudentSectionGap(),
          const AppSectionTitle(title: '表现解读', note: '根据本次各科成绩整理'),
          const SizedBox(height: AppSpace.s4),
          StudentInterpretations(
            items: report?.interpretations ?? const <StudyInterpretation>[],
            loading: reportLoading,
          ),
        ],
        const StudentSectionGap(),
        StudyCompositeEstimateCard(exam: current),
        StudentFootnote(
          [
            if (studentLabel.isNotEmpty) studentLabel,
            '成绩以阅卷系统最终结果为准，仅供本人查阅',
          ].join(' · '),
        ),
      ],
    );
  }
}

/// 最近一次考试：总分环是这一屏的重点，旁边是名次、变化和唯一的主按钮。
class _LatestExam extends StatelessWidget {
  const _LatestExam({
    required this.exam,
    required this.wide,
    required this.scoreChange,
    required this.rankingChange,
    required this.surpassedPercent,
    required this.onOpenReport,
  });

  final StudyExamRecord exam;
  final bool wide;
  final double? scoreChange;
  final int? rankingChange;
  final int? surpassedPercent;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final score = exam.totalScore;
    final full = exam.maxScore;
    final organization = exam.organizationName.isEmpty
        ? '校区'
        : exam.organizationName;
    final percent = surpassedPercent;
    final meta = [
      '最近一次考试',
      studyDateText(exam.examTime),
      if (exam.admissionNo.isNotEmpty) '准考证号 ${exam.admissionNo}',
    ].join(' · ');
    final ringSize = wide ? 136.0 : 120.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppProgressRing(
          value: score == null || full == null || full <= 0 ? 0 : score / full,
          size: ringSize,
          stroke: 8,
          semanticLabel: '总分',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatScore(score), style: AppText.displayNumber()),
              const SizedBox(height: 2),
              Text(
                full == null ? '总分' : '满分 ${formatScore(full)}',
                style: AppText.caption12,
              ),
            ],
          ),
        ),
        SizedBox(width: wide ? AppSpace.s32 : AppSpace.s24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meta, style: AppText.caption12),
              const SizedBox(height: AppSpace.s4),
              Text(
                exam.examName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.title24,
              ),
              const SizedBox(height: AppSpace.s16),
              Wrap(
                spacing: AppSpace.s32,
                runSpacing: AppSpace.s12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: _Metric(
                          label: '全画室排名',
                          child: StudyRankText(
                            rank: exam.totalRanking,
                            total: exam.participantCount,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s32),
                      Flexible(
                        child: _Metric(
                          label: '$organization排名',
                          child: StudyRankText(
                            rank: exam.organizationRanking,
                            total: exam.organizationParticipantCount,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (scoreChange != null || rankingChange != null)
                    _Metric(
                      label: '较上次',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StudyDeltaText(scoreChange, size: 16),
                          if (rankingChange != null) ...[
                            const SizedBox(width: AppSpace.s12),
                            StudyDeltaText(rankingChange, unit: '名', size: 16),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              if (percent != null) ...[
                const SizedBox(height: AppSpace.s12),
                Text('超过全画室 $percent% 的考生', style: AppText.body13),
              ],
              const SizedBox(height: AppSpace.s20),
              AppButton(label: '查看完整报告', onTap: onOpenReport),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.caption12),
        const SizedBox(height: AppSpace.s4),
        SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return StudentColumns(
      wide: wide,
      main: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppSkeleton.circle(size: wide ? 136 : 120),
              const SizedBox(width: AppSpace.s32),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 220, height: 24),
                    SizedBox(height: AppSpace.s16),
                    AppSkeletonText(lines: 2, lineHeight: 20),
                  ],
                ),
              ),
            ],
          ),
          const StudentSectionGap(),
          const AppSkeletonText(lines: 4, lineHeight: 20),
        ],
      ),
      side: const AppSkeletonText(lines: 6, lineHeight: 20),
    );
  }
}
