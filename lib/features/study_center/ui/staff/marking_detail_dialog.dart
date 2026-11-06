import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/art_widgets.dart';
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
  return showDialog<void>(
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
    return StudyDialogShell(
      title: '$who${subject.subjectName}阅卷明细',
      subtitle: '每位老师独立评阅 · 仅供机构内部查阅',
      icon: Icons.fact_check_outlined,
      accent: artSubjectColor(subject.subjectName),
      maxWidth: 720,
      child: review.when(
        loading: () => const StudyLoadingBlock(height: 280),
        error: (error, _) => StudyErrorView(
          message: studyErrorText(error, '阅卷明细加载失败'),
          onRetry: () => ref.invalidate(staffMarkingReviewProvider(key)),
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
    final accent = artSubjectColor(subjectName);
    final teachers = review.teachers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultHeader(review: review),
        const SizedBox(height: 16),
        _ProcessBox(review: review, explanation: explanation),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('老师评分', style: ArtText.title(size: 15)),
            const SizedBox(width: 8),
            Text('共 ${teachers.length} 位', style: ArtText.caption()),
          ],
        ),
        const SizedBox(height: 10),
        if (teachers.isEmpty)
          const StudyNotice(
            text: '该科成绩为手工录入，没有逐位老师的评阅记录。',
            color: ArtColors.ink2,
          )
        else
          for (var i = 0; i < teachers.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _JudgeCard(
              index: i,
              judge: teachers[i],
              mark: i < explanation.marks.length ? explanation.marks[i] : null,
              maxScore: review.maxScore,
              accent: accent,
            ),
          ],
        if (review.bands.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('档位标准', style: ArtText.title(size: 15)),
          const SizedBox(height: 10),
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
              Text('最终得分', style: ArtText.caption()),
              const SizedBox(height: 4),
              StudyNumberText(
                formatScore(review.finalScore),
                unit: full == null ? ' 分' : ' / ${formatScore(full)} 分',
                size: 34,
                color: ArtColors.brandDeep,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StudyChip(
                    label: review.algorithm.label,
                    icon: Icons.functions_rounded,
                    color: ArtColors.brandDeep,
                  ),
                  StudyChip(
                    label: '${review.teachers.length} 位老师',
                    icon: Icons.people_outline_rounded,
                  ),
                  if (review.arbitrationPending)
                    const StudyChip(
                      label: '仲裁中',
                      icon: Icons.gavel_rounded,
                      color: ArtColors.warn,
                    )
                  else if (review.arbitrated)
                    const StudyChip(
                      label: '经仲裁复核',
                      icon: Icons.gavel_rounded,
                      color: ArtColors.warn,
                    ),
                  if (review.finalScoreOverridden)
                    const StudyChip(label: '管理员已调整', color: ArtColors.danger),
                ],
              ),
            ],
          ),
        ),
        if (grade.isNotEmpty) ...[
          const SizedBox(width: 12),
          Column(
            children: [
              ArtGradeBadge(grade: grade, size: 46),
              const SizedBox(height: 4),
              Text('$grade 档', style: ArtText.caption()),
            ],
          ),
        ],
        if (paper.isNotEmpty) ...[
          const SizedBox(width: 16),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ArtColors.brandWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_outlined,
                size: 16,
                color: ArtColors.brandDeep,
              ),
              const SizedBox(width: 6),
              Text(
                '计分过程',
                style: ArtText.body(
                  size: 14,
                  color: ArtColors.brandDeep,
                  weight: AppFont.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _formula(),
          ..._diffLine(),
        ],
      ),
    );
  }

  Widget _formula() {
    final text = ArtText.body(size: 13, color: ArtColors.ink2, height: 1.6);
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
    final number = ArtText.number(size: 16, color: ArtColors.brandDeep);
    final struck = ArtText.number(size: 15, color: ArtColors.ink4).copyWith(
      decoration: TextDecoration.lineThrough,
      decorationColor: ArtColors.ink3,
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
          const SizedBox(height: 6),
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
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '最终得分 = ',
                style: text.copyWith(color: ArtColors.brandDeep),
              ),
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
      message = '老师间最大分差 ${formatScore(diff)} 分。';
      warn = false;
    } else if (explanation.exceedsThreshold) {
      message =
          '老师间最大分差 ${formatScore(diff)} 分，超过 ${formatScore(threshold)} 分的分差阈值'
          '${review.arbitrated ? '，已触发仲裁复核。' : '，请以最终复核结果为准。'}';
      warn = true;
    } else {
      message =
          '老师间最大分差 ${formatScore(diff)} 分，在 ${formatScore(threshold)} 分的分差阈值以内，评分一致。';
      warn = false;
    }
    final color = warn ? ArtColors.warn : ArtColors.success;
    return [
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              warn
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: ArtText.body(size: 13, color: color)),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ArtColors.subtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: ArtText.number(size: 13, color: accent),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  judge.teacherName.isEmpty
                      ? '评委 ${index + 1}'
                      : judge.teacherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArtText.body(
                    size: 14,
                    weight: AppFont.w500,
                    color: excluded ? ArtColors.ink3 : ArtColors.ink,
                  ),
                ),
              ),
              if (judge.grade.isNotEmpty) ...[
                const SizedBox(width: 8),
                ArtGradeBadge(grade: judge.grade, size: 20),
              ],
              if (excluded) ...[
                const SizedBox(width: 8),
                StudyChip(
                  label: mark == JudgeMark.highest ? '去掉最高分' : '去掉最低分',
                  color: ArtColors.ink3,
                ),
              ],
              const Spacer(),
              StudyNumberText(
                formatScore(score),
                unit: ' 分',
                size: 20,
                color: excluded ? ArtColors.ink4 : ArtColors.brandDeep,
                decoration: excluded ? TextDecoration.lineThrough : null,
              ),
            ],
          ),
          if (rate != null) ...[
            const SizedBox(height: 10),
            StudyProgressBar(
              value: rate,
              color: excluded ? ArtColors.ink4 : accent,
              height: 4,
            ),
          ],
          if (judge.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.format_quote_rounded,
                  size: 15,
                  color: ArtColors.ink4,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    judge.comment,
                    style: ArtText.body(size: 13, color: ArtColors.ink2),
                  ),
                ),
              ],
            ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showImageGallery(
        context,
        images: [MediaUrl.resolve(url)],
        heroTagPrefix: 'study_marking_paper',
      ),
      child: Column(
        children: [
          Stack(
            children: [
              ArtNetworkImage(
                url,
                width: 84,
                height: 108,
                borderRadius: BorderRadius.circular(10),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0x73000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '查看原卷',
            style: ArtText.caption(size: 11, color: ArtColors.brand),
          ),
        ],
      ),
    );
  }
}
