import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/student_study_controller.dart';
import '../widgets/study_common.dart';
import '../widgets/study_hero_card.dart';

/// 考试记录：全部 / 已出分 / 阅卷中，已出分的考试可进入成绩报告。
class StudentExamListCard extends StatelessWidget {
  const StudentExamListCard({
    required this.state,
    required this.onFilterChanged,
    required this.onOpen,
    required this.onLoadMore,
    super.key,
  });

  final StudentStudyState state;
  final ValueChanged<StudyExamFilter> onFilterChanged;
  final ValueChanged<StudyExamRecord> onOpen;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final exams = state.exams;
    final Widget body;
    if (state.examsLoading && exams.isEmpty) {
      body = const _ExamListSkeleton();
    } else if (exams.isEmpty) {
      body = SizedBox(
        height: 180,
        child: AppEmptyState(
          icon: Icons.event_note_outlined,
          title: state.filter == StudyExamFilter.marking
              ? '没有阅卷中的考试'
              : '暂无考试记录',
          description: '画室组织的月考、阶段考出分后会出现在这里',
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = AppSpace.s12;
              final columns = constraints.maxWidth >= 760 ? 2 : 1;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final exam in exams)
                    SizedBox(
                      width: width,
                      child: _ExamTile(exam: exam, onTap: () => onOpen(exam)),
                    ),
                ],
              );
            },
          ),
          if (state.examsHasMore) ...[
            const SizedBox(height: AppSpace.s16),
            Center(
              child: AppButton(
                label: '加载更多',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                loading: state.examsLoadingMore,
                onTap: onLoadMore,
              ),
            ),
          ],
        ],
      );
    }
    return AppCard(
      title: '考试记录',
      subtitle: state.examsTotal > 0 ? '共 ${state.examsTotal} 场' : null,
      trailing: AppSegmented<StudyExamFilter>(
        size: AppControlSize.sm,
        segments: [
          for (final filter in StudyExamFilter.values)
            AppSegment(value: filter, label: filter.label),
        ],
        value: state.filter,
        onChanged: onFilterChanged,
      ),
      child: body,
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({required this.exam, required this.onTap});

  final StudyExamRecord exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scored = exam.isPublished && exam.hasScore;
    final String detail;
    if (scored) {
      final rank = exam.totalRanking;
      final total = exam.participantCount;
      detail = [
        studyDateText(exam.examTime),
        if (rank != null)
          total == null ? '第 $rank 名' : '第 $rank 名 / $total 人',
      ].join(' · ');
    } else {
      detail = exam.isPublished ? '本场考试暂无你的成绩' : '阅卷中，出分后会通知你';
    }
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      onTap: scored ? onTap : null,
      child: Row(
        children: [
          _DateBadge(time: exam.examTime, active: scored),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        exam.examName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body14Strong,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    StudyExamStatusTag(exam: exam),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          if (scored) ...[
            StudyNumberText(
              formatScore(exam.totalScore),
              unit: ' / ${formatScore(exam.maxScore)}',
              size: 20,
            ),
            const SizedBox(width: AppSpace.s4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textPlaceholder,
              size: 20,
            ),
          ] else
            const Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.textTertiary,
              size: 18,
            ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.time, required this.active});

  final String time;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final monthDay = studyMonthDay(time);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br8,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: monthDay == null
          ? const Icon(Icons.event_outlined, color: AppColors.textTertiary)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${monthDay.$1} 月', style: AppText.caption12),
                Text(
                  monthDay.$2.toString().padLeft(2, '0'),
                  style: AppText.number(
                    size: 20,
                    color: active ? AppColors.ink : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ExamListSkeleton extends StatelessWidget {
  const _ExamListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s12),
          const AppSkeleton(height: 76, radius: AppRadius.card),
        ],
      ],
    );
  }
}
