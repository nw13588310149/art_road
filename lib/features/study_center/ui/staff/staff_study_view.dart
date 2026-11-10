import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../shell/state/shell_controller.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/staff_study_controller.dart';
import '../../state/study_center_args.dart';
import '../../state/study_report_controller.dart';
import '../growth/study_growth_view.dart';
import '../report/study_report_view.dart';
import '../widgets/study_common.dart';
import 'staff_exam_selector.dart';
import 'staff_score_charts.dart';
import 'staff_student_list.dart';

/// 「班级学情」：班级总览 / 学生成绩报告 / 学生成绩曲线三个页内视图，切换立即生效。
class StaffStudyView extends ConsumerWidget {
  const StaffStudyView({required this.args, super.key});

  final StudyCenterArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = staffStudyControllerProvider(args.examId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen<StaffStudyState>(provider, (previous, next) {
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

    final student = state.student;
    if (state.section == StaffStudySection.report && student != null) {
      return StudyReportView(
        key: ValueKey<String>(
          'staff-report-${student.archiveId}-${state.examId}',
        ),
        reportKey: StudyReportKey(
          examId: state.examId,
          archiveId: student.archiveId,
        ),
        studentName: student.studentName,
        onBack: controller.back,
        onOpenTrend: controller.openTrend,
      );
    }
    if (state.section == StaffStudySection.trend && student != null) {
      return StudyGrowthView(
        key: ValueKey<String>('staff-trend-${student.archiveId}'),
        archiveId: student.archiveId,
        studentName: student.studentName,
        title: '${student.studentName} · 成绩曲线',
        subtitle: [
          if (student.organizationName.isNotEmpty) student.organizationName,
          '仅统计已出分的考试',
        ].join(' · '),
        onBack: controller.back,
      );
    }
    return _StaffOverview(
      key: const ValueKey<String>('staff-overview'),
      state: state,
      controller: controller,
    );
  }
}

class _StaffOverview extends ConsumerWidget {
  const _StaffOverview({
    required this.state,
    required this.controller,
    super.key,
  });

  final StaffStudyState state;
  final StaffStudyController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolName = ref.watch(
      shellControllerProvider.select((s) => s.schoolName),
    );
    final exam = state.exam;
    final header = AppPageHeader(
      title: '班级学情',
      subtitle: [
        if (schoolName.isNotEmpty) schoolName,
        if (state.exams.isNotEmpty) '共 ${state.exams.length} 场考试',
        '成绩经艺考网阅卷系统复核后发布',
      ].join(' · '),
      bottom: state.exams.isEmpty
          ? null
          : StaffExamSelector(
              exams: state.exams,
              selectedId: state.examId,
              onSelected: controller.selectExam,
            ),
    );

    final Widget body;
    if (state.exams.isEmpty) {
      if (state.loading) {
        body = const _StaffSkeleton();
      } else if (state.loadFailed) {
        body = AppErrorState(
          title: '考试列表加载失败',
          description: '请检查网络后重试',
          onRetry: controller.refresh,
        );
      } else {
        body = const AppEmptyState(
          icon: Icons.event_busy_outlined,
          title: '暂无考试记录',
          description: '阅卷系统发布考试成绩后，会在这里汇总班级学情',
        );
      }
    } else if (exam == null) {
      body = const AppEmptyState(
        icon: Icons.hourglass_top_rounded,
        title: '考试均在阅卷中',
        description: '出分后可查看分数段分布、校区对比与成绩排名',
      );
    } else {
      body = _StaffBody(state: state, controller: controller, exam: exam);
    }

    return StudyPageFrame(header: header, body: body);
  }
}

class _StaffSkeleton extends StatelessWidget {
  const _StaffSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: studyBodyPadding,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        StudyCardSkeleton(lines: 2),
        SizedBox(height: AppSpace.s16),
        StudyCardSkeleton(lines: 6),
      ],
    );
  }
}

class _StaffBody extends StatelessWidget {
  const _StaffBody({
    required this.state,
    required this.controller,
    required this.exam,
  });

  final StaffStudyState state;
  final StaffStudyController controller;
  final TeacherExam exam;

  static const _chartHeight = 236.0;

  @override
  Widget build(BuildContext context) {
    final subjectName = state.subjectName;
    final subject = state.subject;
    final rows = state.rows;
    final values = [for (final row in rows) ?rowScore(row, subjectName)];
    final summary = summarizeScores(values);
    final fullScore = subject == null ? exam.fullScore : subject.fullScore;
    final rule = state.gradeRule;
    final List<ScoreBucket> buckets;
    if (subject == null) {
      buckets = bucketsByStep(values);
    } else if (rule != null && rule.bands.isNotEmpty) {
      buckets = bucketsByBands(values, rule.bands);
    } else {
      buckets = bucketsByGrades([
        for (final row in rows) ?row.subjectNamed(subjectName)?.grade,
      ]);
    }
    final accent = subject == null
        ? AppColors.brand
        : studySubjectColor(subjectName);
    final subjectLabel = subject == null ? '总分' : subjectName;
    final groups = groupStats<ScoreQueryRow>(
      rows,
      (row) => row.organizationName,
      (row) => rowScore(row, subjectName),
    );

    final distribution = AppCard(
      title: '分数段分布',
      subtitle: subject == null ? '按总分分段统计人数' : '按$subjectName档位统计人数',
      child: SizedBox(
        height: _chartHeight,
        child: ScoreDistributionChart(buckets: buckets, color: accent),
      ),
    );
    final campus = StaffCampusCard(
      groups: groups,
      overallAverage: summary.average,
      fullScore: fullScore,
      subjectLabel: subjectLabel,
      color: accent,
    );

    return AppRefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        key: const PageStorageKey<String>('staff-study-overview'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s4,
              AppSpace.page,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: AppCard(
                title: exam.examName,
                subtitle: '${studyDateText(exam.examTime)} · $subjectLabel',
                trailing: AppSegmented<String>(
                  size: AppControlSize.sm,
                  segments: [
                    const AppSegment(value: '', label: '总分'),
                    for (final item in exam.subjects)
                      AppSegment(
                        value: item.subjectName,
                        label: item.subjectName,
                      ),
                  ],
                  value: subjectName,
                  onChanged: controller.selectSubject,
                ),
                child: state.rowsLoading && rows.isEmpty
                    ? const AppSkeleton(height: 72, radius: AppRadius.card)
                    : StaffStatTiles(summary: summary, fullScore: fullScore),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s16,
              AppSpace.page,
              0,
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                if (state.rowsFailed)
                  SliverToBoxAdapter(
                    child: AppCard(
                      child: SizedBox(
                        height: 200,
                        child: AppErrorState(
                          title: '成绩数据加载失败',
                          description: '请检查网络后重试',
                          onRetry: controller.reloadRows,
                        ),
                      ),
                    ),
                  )
                else if (!state.rowsLoading && rows.isEmpty)
                  const SliverToBoxAdapter(
                    child: AppCard(
                      child: SizedBox(
                        height: 200,
                        child: AppEmptyState(
                          icon: Icons.inbox_outlined,
                          title: '本场考试暂无成绩',
                          description: '阅卷完成并发布成绩后会显示在这里',
                        ),
                      ),
                    ),
                  )
                else if (rows.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 760) {
                          return Column(
                            children: [
                              distribution,
                              const SizedBox(height: AppSpace.s16),
                              campus,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 3, child: distribution),
                              const SizedBox(width: AppSpace.s16),
                              Expanded(flex: 2, child: campus),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpace.s16),
                  ),
                  SliverToBoxAdapter(
                    child: StaffSubjectAverages(
                      exam: exam,
                      rows: rows,
                      selectedSubject: subjectName,
                      onSelect: controller.selectSubject,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpace.s16),
                  ),
                  StaffStudentListSliver(
                    rows: rankedScoreRows(
                      rows,
                      subjectName: subjectName,
                      keyword: state.keyword,
                    ),
                    subjectName: subjectName,
                    totalCount: rows.length,
                    overflowCount: state.rowsTotal - rows.length,
                    keyword: state.keyword,
                    onKeywordChanged: controller.setKeyword,
                    onOpen: controller.openStudent,
                  ),
                ],
              ],
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s24)),
        ],
      ),
    );
  }
}
