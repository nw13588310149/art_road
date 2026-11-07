import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/study_detail_providers.dart';
import '../widgets/grade_band_table.dart';

/// 学生端评分标准弹窗。
Future<void> showStudyGradeStandard(
  BuildContext context, {
  required String examId,
  required StudySubjectRecord subject,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (context) =>
        StudyGradeStandardDialog(examId: examId, subject: subject),
  );
}

class StudyGradeStandardDialog extends ConsumerWidget {
  const StudyGradeStandardDialog({
    required this.examId,
    required this.subject,
    super.key,
  });

  final String examId;
  final StudySubjectRecord subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = StudySubjectKey(examId: examId, subjectId: subject.subjectId);
    final standard = ref.watch(studyGradeStandardProvider(key));
    return AppDialog(
      title: '${subject.subjectName} · 评分标准',
      message: '阅卷老师先判定档位，再在档位区间内给分',
      width: AppSize.dialogWide,
      child: standard.when(
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
      ),
    );
  }
}

/// 计分方式说明 + 档位标准表。
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            if (full != null)
              _InfoTile(label: '满分', value: '${formatScore(full)} 分'),
            _InfoTile(label: '计分方式', value: standard.algorithm.label),
            if (threshold != null)
              _InfoTile(label: '分差阈值', value: '${formatScore(threshold)} 分'),
            if (mine != null)
              _InfoTile(
                label: '本次得分',
                value: highlight.isEmpty
                    ? '${formatScore(mine)} 分'
                    : '${formatScore(mine)} 分 · $highlight 档',
                highlighted: true,
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        Container(
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: AppRadius.br8,
          ),
          child: Text(algorithmText(standard), style: AppText.body13),
        ),
        const SizedBox(height: AppSpace.s20),
        Text('档位标准', style: AppText.title16),
        const SizedBox(height: AppSpace.s12),
        GradeBandTable(
          bands: standard.bands,
          highlightGrade: highlight,
          score: mine,
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.brandWash : AppColors.surfaceSubtle,
        borderRadius: AppRadius.br8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.caption12),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppText.body14Strong.copyWith(
              color: highlighted ? AppColors.brandDeep : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
