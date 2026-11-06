import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/art_widgets.dart';
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

/// 「班级学情」：班级总览 / 学生成绩报告 / 学生成绩曲线三个页内视图。
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
      if (message.isEmpty || message == previous?.errorMessage) return;
      AppToast.showError(context, message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) controller.clearError();
      });
    });

    final student = state.student;
    final Widget child;
    if (state.section == StaffStudySection.report && student != null) {
      child = StudyReportView(
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
    } else if (state.section == StaffStudySection.trend && student != null) {
      child = StudyGrowthView(
        key: ValueKey<String>('staff-trend-${student.archiveId}'),
        archiveId: student.archiveId,
        title: '${student.studentName} · 成绩曲线',
        subtitle: [
          if (student.organizationName.isNotEmpty) student.organizationName,
          '仅统计已出分的考试',
        ].join(' · '),
        onBack: controller.back,
      );
    } else {
      child = _StaffOverview(
        key: const ValueKey<String>('staff-overview'),
        state: state,
        controller: controller,
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: child,
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
    final header = ArtPageHeader(
      title: '班级学情',
      subtitle: [
        if (schoolName.isNotEmpty) schoolName,
        if (state.exams.isNotEmpty) '共 ${state.exams.length} 场考试',
        '成绩来自艺考网阅卷系统',
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
        body = const SizedBox.shrink();
      } else if (state.loadFailed) {
        body = StudyErrorView(message: '考试列表加载失败', onRetry: controller.refresh);
      } else {
        body = const ArtEmptyState(
          message: '暂无考试记录',
          icon: Icons.event_busy_outlined,
        );
      }
    } else if (exam == null) {
      body = const ArtEmptyState(
        message: '考试均在阅卷中，出分后可查看班级学情',
        icon: Icons.hourglass_top_rounded,
      );
    } else {
      body = _StaffBody(state: state, controller: controller, exam: exam);
    }

    return PageInitLoadingShell(
      loading: state.loading && state.exams.isEmpty,
      child: StudyPageFrame(header: header, body: body),
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
        ? ArtColors.brand
        : artSubjectColor(subjectName);
    final subjectLabel = subject == null ? '总分' : subjectName;
    final groups = groupStats<ScoreQueryRow>(
      rows,
      (row) => row.organizationName,
      (row) => rowScore(row, subjectName),
    );

    final distribution = StudyCard(
      title: '分数段分布',
      subtitle: subject == null ? '按总分分段统计' : '按$subjectName档位统计',
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
    );

    return AppRefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        key: const PageStorageKey<String>('staff-study-overview'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: StudyCard(
              title: exam.examName,
              subtitle: '${studyDateText(exam.examTime)} · $subjectLabel',
              trailing: ArtSegmentTabs<String>(
                items: ['', for (final item in exam.subjects) item.subjectName],
                value: subjectName,
                onChanged: controller.selectSubject,
                labelOf: (name) => name.isEmpty ? '总分' : name,
              ),
              child: state.rowsLoading && rows.isEmpty
                  ? const StudyLoadingBlock(height: 96)
                  : StaffStatTiles(summary: summary, fullScore: fullScore),
            ),
          ),
          if (state.rowsFailed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: StudyCard(
                  child: StudyErrorView(
                    message: '成绩数据加载失败',
                    onRetry: controller.reloadRows,
                  ),
                ),
              ),
            )
          else if (!state.rowsLoading && rows.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: StudyCard(
                  child: ArtEmptyState(
                    message: '本场考试暂无成绩',
                    icon: Icons.inbox_outlined,
                  ),
                ),
              ),
            )
          else if (rows.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        distribution,
                        const SizedBox(height: 12),
                        campus,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: distribution),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: campus),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: StaffSubjectAverages(
                exam: exam,
                rows: rows,
                selectedSubject: subjectName,
                onSelect: controller.selectSubject,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
