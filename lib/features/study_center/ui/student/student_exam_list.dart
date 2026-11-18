import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/student_study_controller.dart';

/// 考试记录（侧栏）：全部 / 已出分 / 阅卷中，已出分的一行点开是那场考试的成绩报告。
class StudentExamRecords extends StatelessWidget {
  const StudentExamRecords({
    required this.state,
    required this.onFilterChanged,
    required this.onOpen,
    required this.onLoadMore,
    required this.onRetry,
    super.key,
  });

  final StudentStudyState state;
  final ValueChanged<StudyExamFilter> onFilterChanged;
  final ValueChanged<StudyExamRecord> onOpen;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  int? _countOf(StudyExamFilter filter) {
    final statistics = state.overview?.statistics;
    if (statistics == null) return null;
    return switch (filter) {
      StudyExamFilter.all => statistics.total,
      StudyExamFilter.published => statistics.published,
      StudyExamFilter.marking => statistics.pending,
    };
  }

  @override
  Widget build(BuildContext context) {
    final exams = state.exams;
    final Widget body;
    if (state.examsLoading && exams.isEmpty) {
      body = const _RecordsSkeleton();
    } else if (state.examsFailed) {
      body = SizedBox(
        height: 220,
        child: AppErrorState(
          title: '考试记录加载失败',
          description: '请检查网络后重试',
          onRetry: onRetry,
        ),
      );
    } else if (exams.isEmpty) {
      body = SizedBox(
        height: 220,
        child: AppEmptyState(
          icon: Icons.event_note_outlined,
          title: state.filter == StudyExamFilter.marking
              ? '没有阅卷中的考试'
              : '暂无考试记录',
          description: switch (state.filter) {
            StudyExamFilter.all => '画室组织的月考、阶段考会出现在这里',
            StudyExamFilter.published => '阅卷完成并发布成绩后会出现在这里',
            StudyExamFilter.marking => '正在阅卷、尚未发布成绩的考试会出现在这里',
          },
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final exam in exams) ...[
            _RecordRow(exam: exam, onTap: () => onOpen(exam)),
            const AppRule(),
          ],
          if (state.examsHasMore)
            Center(
              child: state.examsLoadingMore
                  ? const SizedBox(
                      height: AppPlainButton.height,
                      child: Center(child: AppLoadingIndicator(size: 20)),
                    )
                  : AppPlainButton(label: '加载更多', onTap: onLoadMore),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionTitle(title: '考试记录'),
        AppViewTabs<StudyExamFilter>(
          dense: true,
          items: [
            for (final filter in StudyExamFilter.values)
              AppViewTab(
                value: filter,
                label: filter.label,
                count: _countOf(filter),
              ),
          ],
          value: state.filter,
          onChanged: onFilterChanged,
        ),
        const AppRule(),
        body,
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.exam, required this.onTap});

  final StudyExamRecord exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scored = exam.isPublished && exam.hasScore;
    final date = studyShortDate(exam.examTime);
    final String detail;
    if (scored) {
      final rank = exam.totalRanking;
      final total = exam.participantCount;
      detail = [
        date,
        if (rank != null) total == null ? '第 $rank 名' : '第 $rank 名 / $total 人',
      ].join(' · ');
    } else {
      detail = exam.isPublished ? '$date · 本场暂无你的成绩' : '$date · 出分后会通知你';
    }
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.examName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14Strong,
                  ),
                  Text(detail, style: AppText.caption12),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            if (scored) ...[
              Text(formatScore(exam.totalScore), style: AppText.number()),
              const SizedBox(width: AppSpace.s4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textPlaceholder,
              ),
            ] else
              AppStatusTag(
                label: exam.isPublished ? '无成绩' : '阅卷中',
                tone: exam.isPublished ? AppTone.neutral : AppTone.warning,
              ),
          ],
        ),
      ),
    );
    return scored
        ? AppPressable(
            onTap: onTap,
            semanticLabel: '${exam.examName}，${formatScore(exam.totalScore)} 分',
            child: row,
          )
        : row;
  }
}

class _RecordsSkeleton extends StatelessWidget {
  const _RecordsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.s12),
            child: AppSkeletonText(lines: 2),
          ),
      ],
    );
  }
}
