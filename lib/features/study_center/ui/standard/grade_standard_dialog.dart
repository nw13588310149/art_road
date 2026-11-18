import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/image_gallery_viewer.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/study_detail_providers.dart';

/// 学生端评分标准弹窗。传入 [subjects]（这场考试的各科）时，弹窗里可以切换科目。
Future<void> showStudyGradeStandard(
  BuildContext context, {
  required String examId,
  required StudySubjectRecord subject,
  List<StudySubjectRecord> subjects = const <StudySubjectRecord>[],
}) {
  return showAppDialog<void>(
    context: context,
    builder: (context) => StudyGradeStandardDialog(
      examId: examId,
      subject: subject,
      subjects: subjects,
    ),
  );
}

class StudyGradeStandardDialog extends ConsumerStatefulWidget {
  const StudyGradeStandardDialog({
    required this.examId,
    required this.subject,
    this.subjects = const <StudySubjectRecord>[],
    super.key,
  });

  final String examId;
  final StudySubjectRecord subject;
  final List<StudySubjectRecord> subjects;

  @override
  ConsumerState<StudyGradeStandardDialog> createState() =>
      _StudyGradeStandardDialogState();
}

class _StudyGradeStandardDialogState
    extends ConsumerState<StudyGradeStandardDialog> {
  late StudySubjectRecord _subject = widget.subject;

  @override
  Widget build(BuildContext context) {
    final subject = _subject;
    final key = StudySubjectKey(
      examId: widget.examId,
      subjectId: subject.subjectId,
    );
    final standard = ref.watch(studyGradeStandardProvider(key));
    final subjects = widget.subjects;
    final body = standard.when(
      loading: () => const SizedBox(
        height: 260,
        child: Center(child: AppLoadingIndicator(size: 36)),
      ),
      error: (error, _) => SizedBox(
        height: 260,
        child: AppErrorState(
          title: '评分标准加载失败',
          description: studyErrorText(error, '请检查网络后重试'),
          onRetry: () => ref.invalidate(studyGradeStandardProvider(key)),
        ),
      ),
      data: (value) => GradeStandardContent(
        standard: value,
        score: subject.score,
        grade: subject.grade,
      ),
    );
    return AppDialog(
      title: '${subject.subjectName} · 评分标准',
      message: '阅卷老师先判定档位，再在档位区间内给分',
      width: AppSize.dialogWide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subjects.length > 1) ...[
            AppViewTabs<String>(
              dense: true,
              items: [
                for (final item in subjects)
                  AppViewTab(value: item.subjectId, label: item.subjectName),
              ],
              value: subject.subjectId,
              onChanged: (id) => setState(
                () => _subject = subjects.firstWhere(
                  (item) => item.subjectId == id,
                  orElse: () => _subject,
                ),
              ),
            ),
            const AppRule(),
            const SizedBox(height: AppSpace.s16),
          ],
          body,
        ],
      ),
    );
  }
}

/// 计分方式说明 + 档位标准。
class GradeStandardContent extends StatelessWidget {
  const GradeStandardContent({
    required this.standard,
    this.score,
    this.grade = '',
    super.key,
  });

  final GradeStandard standard;
  final double? score;
  final String grade;

  static String algorithmText(GradeStandard standard) {
    final rule = standard.algorithm == ScoringAlgorithm.trimmed
        ? '截尾平均：去掉一个最高分和一个最低分，取其余老师分数的平均值，减少个别评分偏差的影响。'
        : '算术平均：每份试卷由多位阅卷老师独立评阅，最终得分取各位老师分数的平均值。';
    final threshold = standard.diffThreshold;
    if (threshold == null || threshold <= 0) {
      return rule;
    }
    return '$rule老师之间分差超过 ${formatScore(threshold)} 分（分差阈值）时，'
        '试卷会提交仲裁组复核。';
  }

  @override
  Widget build(BuildContext context) {
    final mine = score;
    final full = standard.fullScore;
    final threshold = standard.diffThreshold;
    final highlight = grade.isNotEmpty
        ? grade
        : bandForScore(standard.bands, mine)?.grade ?? '';
    final facts = [
      if (full != null) '满分 ${formatScore(full)} 分',
      standard.algorithm.label,
      if (threshold != null) '分差阈值 ${formatScore(threshold)} 分',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mine != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '本次 ', style: AppText.body14),
                TextSpan(text: formatScore(mine), style: AppText.number()),
                TextSpan(
                  text: highlight.isEmpty ? ' 分' : ' 分 · $highlight 档',
                  style: AppText.body14Strong,
                ),
              ],
            ),
          ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s4),
          Text(facts, style: AppText.body13),
        ],
        const SizedBox(height: AppSpace.s8),
        Text(algorithmText(standard), style: AppText.body13),
        const SizedBox(height: AppSpace.s24),
        const AppSectionTitle(title: '档位标准'),
        const SizedBox(height: AppSpace.s4),
        _BandList(bands: standard.bands, highlightGrade: highlight),
      ],
    );
  }
}

/// 档位一行一档：档位、分数区间、描述，右边是这一档的样图（点开放大）。
/// 本次所在的档位加粗，并写明「本次」。
class _BandList extends StatelessWidget {
  const _BandList({required this.bands, required this.highlightGrade});

  final List<GradeBandInfo> bands;
  final String highlightGrade;

  @override
  Widget build(BuildContext context) {
    if (bands.isEmpty) {
      return const SizedBox(
        height: 180,
        child: AppEmptyState(
          icon: Icons.rule_rounded,
          title: '暂未配置档位标准',
          description: '阅卷系统配置打分规则后会显示在这里',
        ),
      );
    }
    final images = [
      for (final band in bands)
        if (band.imageUrl.isNotEmpty) MediaUrl.resolve(band.imageUrl),
    ];
    final titles = [
      for (final band in bands)
        if (band.imageUrl.isNotEmpty) '${band.grade} 档样图',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppRule(),
        for (final band in bands) ...[
          _BandRow(
            band: band,
            mine: band.grade == highlightGrade,
            onPreview: band.imageUrl.isEmpty
                ? null
                : () => showImageGallery(
                    context,
                    images: images,
                    initialIndex: math.max(
                      0,
                      images.indexOf(MediaUrl.resolve(band.imageUrl)),
                    ),
                    heroTagPrefix: 'study_band',
                    titles: titles,
                  ),
          ),
          const AppRule(),
        ],
      ],
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({
    required this.band,
    required this.mine,
    required this.onPreview,
  });

  final GradeBandInfo band;
  final bool mine;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final preview = onPreview;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${band.grade} 档',
                  style: mine ? AppText.title16 : AppText.body14,
                ),
                if (mine)
                  Text(
                    '本次',
                    style: AppText.caption12.copyWith(
                      color: AppColors.brandDeep,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${formatScore(band.min)}–${formatScore(band.max)}',
                        style: AppText.number(size: 14),
                      ),
                      TextSpan(text: ' 分', style: AppText.caption12),
                    ],
                  ),
                ),
                if (band.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    band.description,
                    style: mine ? AppText.body14 : AppText.body13,
                  ),
                ],
              ],
            ),
          ),
          if (preview != null) ...[
            const SizedBox(width: AppSpace.s12),
            AppPressable(
              onTap: preview,
              semanticLabel: '查看 ${band.grade} 档样图',
              child: SizedBox.square(
                dimension: 64,
                child: AppImageTile.frame(
                  child: ColoredBox(
                    color: AppColors.canvas,
                    child: AppImage(
                      src: band.imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
