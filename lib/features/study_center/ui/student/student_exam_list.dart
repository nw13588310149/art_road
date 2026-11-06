import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/student_study_controller.dart';
import '../widgets/study_common.dart';

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
      body = const StudyLoadingBlock(height: 180);
    } else if (exams.isEmpty) {
      body = ArtEmptyState(
        message: state.filter == StudyExamFilter.marking
            ? '没有阅卷中的考试'
            : '暂无考试记录',
        icon: Icons.event_note_outlined,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
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
            const SizedBox(height: 14),
            Center(
              child: ArtButton(
                label: '加载更多',
                primary: false,
                height: 34,
                loading: state.examsLoadingMore,
                onTap: onLoadMore,
              ),
            ),
          ],
        ],
      );
    }
    return StudyCard(
      title: '考试记录',
      subtitle: state.examsTotal > 0 ? '共 ${state.examsTotal} 场' : null,
      trailing: ArtSegmentTabs<StudyExamFilter>(
        items: StudyExamFilter.values,
        value: state.filter,
        onChanged: onFilterChanged,
        labelOf: (filter) => filter.label,
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
    final status = scored
        ? const StudyChip(label: '已出分', color: ArtColors.success)
        : exam.isPublished
        ? const StudyChip(label: '无成绩', color: ArtColors.ink3)
        : const StudyChip(
            label: '阅卷中',
            color: ArtColors.warn,
            icon: Icons.hourglass_top_rounded,
          );
    final String detail;
    if (scored) {
      final rank = exam.totalRanking;
      final total = exam.participantCount;
      detail = [
        if (exam.admissionNo.isNotEmpty) '准考证号 ${exam.admissionNo}',
        if (rank != null) total == null ? '第 $rank 名' : '第 $rank / $total 名',
      ].join(' · ');
    } else {
      detail = exam.isPublished ? '本场考试暂无你的成绩' : '阅卷中，出分后提醒';
    }
    return Material(
      color: ArtColors.subtle,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: scored ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _DateBadge(time: exam.examTime, active: scored),
              const SizedBox(width: 14),
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
                            style: ArtText.body(size: 15, weight: AppFont.w500),
                          ),
                        ),
                        const SizedBox(width: 6),
                        status,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ArtText.caption(
                        color: scored ? ArtColors.ink3 : ArtColors.warn,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (scored) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StudyNumberText(
                      formatScore(exam.totalScore),
                      unit: ' 分',
                      size: 20,
                      color: ArtColors.brandDeep,
                    ),
                    Text(
                      '满分 ${formatScore(exam.maxScore)}',
                      style: ArtText.caption(size: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ArtColors.ink4,
                  size: 22,
                ),
              ] else
                const Icon(
                  Icons.notifications_active_outlined,
                  color: ArtColors.warn,
                  size: 20,
                ),
            ],
          ),
        ),
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
        color: active ? ArtColors.brandWash : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? ArtColors.brandTint : ArtColors.line,
        ),
      ),
      child: monthDay == null
          ? const Icon(Icons.event_outlined, color: ArtColors.ink3)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${monthDay.$1}月',
                  style: ArtText.caption(
                    size: 11,
                    color: active ? ArtColors.brand : ArtColors.ink3,
                  ),
                ),
                Text(
                  monthDay.$2.toString().padLeft(2, '0'),
                  style: ArtText.number(
                    size: 19,
                    color: active ? ArtColors.brandDeep : ArtColors.ink2,
                  ),
                ),
              ],
            ),
    );
  }
}
