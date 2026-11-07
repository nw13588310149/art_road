import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/image_gallery_viewer.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/study_detail_providers.dart';
import '../widgets/grade_band_table.dart';
import '../widgets/study_common.dart';

/// 教职端单科阅卷明细：各位老师的分数 / 档位 / 评语与计分过程。
Future<void> showMarkingDetailDialog(
  BuildContext context, {
  required String archiveId,
  required String examId,
  required StudySubjectRecord subject,
  String studentName = '',
}) {
  return showAppDialog<void>(
    context: context,
    builder: (context) => MarkingDetailDialog(
      archiveId: archiveId,
      examId: examId,
      subject: subject,
      studentName: studentName,
    ),
  );
}

class MarkingDetailDialog extends ConsumerWidget {
  const MarkingDetailDialog({
    required this.archiveId,
    required this.examId,
    required this.subject,
    this.studentName = '',
    super.key,
  });

  final String archiveId;
  final String examId;
  final StudySubjectRecord subject;
  final String studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = StudyMarkingKey(
      archiveId: archiveId,
      examId: examId,
      subjectId: subject.subjectId,
    );
    final review = ref.watch(staffMarkingReviewProvider(key));
    final who = studentName.isEmpty ? '' : '$studentName · ';
    return AppDialog(
      title: '$who${subject.subjectName}阅卷明细',
      message: '每位老师独立评阅 · 仅供机构内部查阅',
      width: 720,
      child: review.when(
        loading: () => const SizedBox(
          height: 280,
          child: Center(child: AppLoadingIndicator(size: 36)),
        ),
        error: (error, _) => SizedBox(
          height: 280,
          child: AppErrorState(
            title: '阅卷明细加载失败',
            description: studyErrorText(error, '请检查网络后重试'),
            onRetry: () => ref.invalidate(staffMarkingReviewProvider(key)),
          ),
        ),
        data: (value) => _MarkingDetailContent(
          review: value,
          subjectName: subject.subjectName,
        ),
      ),
    );
  }
}

class _MarkingDetailContent extends StatelessWidget {
  const _MarkingDetailContent({
    required this.review,
    required this.subjectName,
  });

  final MarkingReview review;
  final String subjectName;

  @override
  Widget build(BuildContext context) {
    final explanation = explainScore(
      algorithm: review.algorithm,
      judges: [for (final teacher in review.teachers) teacher.score],
      finalScore: review.finalScore,
      diffThreshold: review.diffThreshold,
      arbitrated: review.arbitrated,
      overridden: review.finalScoreOverridden,
    );
    final accent = studySubjectColor(subjectName);
    final teachers = review.teachers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultHeader(review: review),
        const SizedBox(height: AppSpace.s16),
        _ProcessBox(review: review, explanation: explanation),
        const SizedBox(height: AppSpace.s20),
        AppSectionHeader(
          title: '老师评分',
          subtitle: '共 ${teachers.length} 位',
        ),
        const SizedBox(height: AppSpace.s12),
        if (teachers.isEmpty)
          const AppNotice(
            tone: AppTone.neutral,
            message: '该科成绩为手工录入，没有逐位老师的评阅记录',
          )
        else
          for (var i = 0; i < teachers.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.s8),
            _JudgeCard(
              index: i,
              judge: teachers[i],
              mark: i < explanation.marks.length ? explanation.marks[i] : null,
              maxScore: review.maxScore,
              accent: accent,
            ),
          ],
        if (review.bands.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s20),
          const AppSectionHeader(title: '档位标准'),
          const SizedBox(height: AppSpace.s12),
          GradeBandLegend(
            bands: review.bands,
            highlightGrade: review.finalGrade,
          ),
        ],
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.review});

  final MarkingReview review;

  @override
  Widget build(BuildContext context) {
    final full = review.maxScore;
    final grade = review.finalGrade;
    final paper = review.paperUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('最终得分', style: AppText.caption12),
              const SizedBox(height: AppSpace.s4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: StudyNumberText(
                      formatScore(review.finalScore),
                      unit: full == null ? ' 分' : ' / ${formatScore(full)} 分',
                      size: 32,
                      color: AppColors.brand,
                    ),
                  ),
                  if (grade.isNotEmpty) ...[
                    const SizedBox(width: AppSpace.s8),
                    StudyGradeTag(grade: grade),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  AppTag(
                    label: review.algorithm.label,
                    icon: Icons.functions_rounded,
                  ),
                  AppTag(
                    label: '${review.teachers.length} 位老师',
                    icon: Icons.people_outline_rounded,
                  ),
                  if (review.arbitrationPending)
                    const AppTag(
                      label: '仲裁中',
                      icon: Icons.gavel_rounded,
                      tone: AppTone.warning,
                    )
                  else if (review.arbitrated)
                    const AppTag(
                      label: '经仲裁复核',
                      icon: Icons.gavel_rounded,
                      tone: AppTone.warning,
                    ),
                  if (review.finalScoreOverridden)
                    const AppTag(label: '管理员已调整', tone: AppTone.danger),
                ],
              ),
            ],
          ),
        ),
        if (paper.isNotEmpty) ...[
          const SizedBox(width: AppSpace.s16),
          _PaperThumb(url: paper),
        ],
      ],
    );
  }
}

class _ProcessBox extends StatelessWidget {
  const _ProcessBox({required this.review, required this.explanation});

  final MarkingReview review;
  final ScoreExplanation explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpace.s4),
              Text('计分过程', style: AppText.body14Strong),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          _formula(),
          ..._diffLine(),
        ],
      ),
    );
  }

  Widget _formula() {
    final text = AppText.body13;
    final finalScore = formatScore(review.finalScore);
    if (review.teachers.isEmpty) {
      return Text('成绩为手工录入，最终得分以录入结果为准。', style: text);
    }
    if (review.finalScoreOverridden) {
      return Text('最终得分已由管理员调整为 $finalScore 分。', style: text);
    }
    if (review.arbitrated) {
      final diff = explanation.maxDiff;
      final threshold = review.diffThreshold;
      final reason =
          diff != null && threshold != null && explanation.exceedsThreshold
          ? '老师间分差 ${formatScore(diff)} 分，超过 ${formatScore(threshold)} 分的分差阈值，'
          : '';
      final grade = review.finalGrade.isEmpty ? '' : '${review.finalGrade} 档 ';
      return Text(
        review.arbitrationPending
            ? '$reason已提交仲裁，等待仲裁组复核，最终得分待定。'
            : '$reason已提交仲裁，由仲裁组复核定为 $grade$finalScore 分。',
        style: text,
      );
    }
    if (explanation.formula.isEmpty) {
      return Text('最终得分以阅卷系统复核结果为准。', style: text);
    }
    final trimmed = explanation.algorithm == ScoringAlgorithm.trimmed;
    final number = AppText.number(size: 16, color: AppColors.ink);
    final struck = AppText.number(size: 14, color: AppColors.textPlaceholder)
        .copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: AppColors.textTertiary,
        );
    final dropped = explanation.dropped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trimmed
              ? '截尾平均：去掉一个最高分和一个最低分，取其余 ${explanation.used.length} 位老师分数的平均值。'
              : explanation.used.length > 1
              ? '算术平均：取 ${explanation.used.length} 位老师分数的平均值。'
              : '以老师给出的分数为准。',
          style: text,
        ),
        if (trimmed && dropped.length == 2) ...[
          const SizedBox(height: AppSpace.s4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '去掉最高分 ', style: text),
                TextSpan(text: formatScore(dropped[0]), style: struck),
                TextSpan(text: '，最低分 ', style: text),
                TextSpan(text: formatScore(dropped[1]), style: struck),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '最终得分 = ', style: text),
              TextSpan(text: explanation.formula, style: number),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _diffLine() {
    final diff = explanation.maxDiff;
    final threshold = review.diffThreshold;
    final String message;
    final bool warn;
    if (review.teachers.length == 1) {
      message = '仅一位老师评分，无需比较分差。';
      warn = false;
    } else if (diff == null) {
      return const <Widget>[];
    } else if (threshold == null) {
      message = '老师评分的最高分与最低分相差 ${formatScore(diff)} 分。';
      warn = false;
    } else if (explanation.exceedsThreshold) {
      message =
          '老师评分的最高分与最低分相差 ${formatScore(diff)} 分，超过 ${formatScore(threshold)} 分的分差阈值'
          '${review.arbitrated ? '，已触发仲裁复核。' : '，请以最终复核结果为准。'}';
      warn = true;
    } else {
      message =
          '老师评分的最高分与最低分相差 ${formatScore(diff)} 分，在 ${formatScore(threshold)} 分的分差阈值以内，评分一致。';
      warn = false;
    }
    return [
      const SizedBox(height: AppSpace.s8),
      AppNotice(
        tone: warn ? AppTone.warning : AppTone.success,
        message: message,
      ),
    ];
  }
}

class _JudgeCard extends StatelessWidget {
  const _JudgeCard({
    required this.index,
    required this.judge,
    required this.mark,
    required this.maxScore,
    required this.accent,
  });

  final int index;
  final MarkingJudge judge;
  final JudgeMark? mark;
  final double? maxScore;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final excluded = mark != null;
    final score = judge.score;
    final full = maxScore;
    final rate = score == null || full == null || full <= 0
        ? null
        : score / full;
    final name = judge.teacherName.isEmpty
        ? '评委 ${index + 1}'
        : judge.teacherName;
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(name: name, size: 28),
              const SizedBox(width: AppSpace.s8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong.copyWith(
                    color: excluded ? AppColors.textTertiary : AppColors.ink,
                  ),
                ),
              ),
              if (judge.grade.isNotEmpty) ...[
                const SizedBox(width: AppSpace.s8),
                StudyGradeTag(grade: judge.grade),
              ],
              if (excluded) ...[
                const SizedBox(width: AppSpace.s8),
                AppTag(
                  label: mark == JudgeMark.highest ? '去掉最高分' : '去掉最低分',
                ),
              ],
              const Spacer(),
              StudyNumberText(
                formatScore(score),
                unit: ' 分',
                size: 20,
                color: excluded ? AppColors.textPlaceholder : AppColors.ink,
                decoration: excluded ? TextDecoration.lineThrough : null,
              ),
            ],
          ),
          if (rate != null) ...[
            const SizedBox(height: AppSpace.s8),
            AppProgressBar(
              value: rate,
              color: excluded ? AppColors.textPlaceholder : accent,
              height: 4,
            ),
          ],
          if (judge.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text('评语：${judge.comment}', style: AppText.body13),
          ],
        ],
      ),
    );
  }
}

class _PaperThumb extends StatelessWidget {
  const _PaperThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: () => showImageGallery(
        context,
        images: [MediaUrl.resolve(url)],
        heroTagPrefix: 'study_marking_paper',
      ),
      semanticLabel: '查看原卷大图',
      child: Column(
        children: [
          AppImage(
            src: url,
            width: 84,
            height: 108,
            borderRadius: AppRadius.br8,
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            '查看原卷',
            style: AppText.caption12.copyWith(color: AppColors.brand),
          ),
        ],
      ),
    );
  }
}
