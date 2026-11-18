import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/ui/ui.dart';
import '../../../art_toolbox/data/toolbox_catalog.dart';
import '../../../art_toolbox/logic/score_calculator.dart';
import '../../data/composite_estimate.dart';
import '../../data/study_models.dart';
import '../../state/composite_estimate_controller.dart';

/// 「学情」综合分预估：最近一次已出分考试的专业总分 + 学生填写的文化课预估分，
/// 按省份公式估算艺术类综合分；可填目标分看差距。结果仅供参考。
///
/// 是总览里的一个分区：分区标题、一行输入、一行结果，不包卡片。
class StudyCompositeEstimateCard extends ConsumerStatefulWidget {
  const StudyCompositeEstimateCard({required this.exam, super.key});

  /// 最近一次已出分的考试；为空时只给出说明与完整计算器入口。
  final StudyExamRecord? exam;

  static const disclaimer = '仅供参考，以当年省教育考试院公布为准';

  @override
  ConsumerState<StudyCompositeEstimateCard> createState() =>
      _StudyCompositeEstimateCardState();
}

class _StudyCompositeEstimateCardState
    extends ConsumerState<StudyCompositeEstimateCard> {
  final _culture = TextEditingController();
  final _target = TextEditingController();

  static final _scoreFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    LengthLimitingTextInputFormatter(7),
  ];

  @override
  void initState() {
    super.initState();
    final current = ref.read(compositeEstimateFormProvider);
    if (!current.loading) {
      _fill(current.form);
    }
  }

  @override
  void dispose() {
    _culture.dispose();
    _target.dispose();
    super.dispose();
  }

  void _fill(CompositeEstimateForm form) {
    _culture.text = form.culture;
    _target.text = form.target;
  }

  void _openCalculator() {
    Navigator.of(context).pushNamed(
      RoutePaths.artToolbox,
      arguments: <String, dynamic>{'tool': ArtTool.score.key},
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CompositeEstimateFormState>(compositeEstimateFormProvider, (
      previous,
      next,
    ) {
      if ((previous?.loading ?? true) && !next.loading) {
        _fill(next.form);
      }
    });
    final formState = ref.watch(compositeEstimateFormProvider);
    final exam = widget.exam;
    final total = exam?.totalScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: '综合分预估',
          note: total == null || exam == null ? '' : '专业成绩取 ${exam.examName}',
          trailing: AppPlainButton(
            label: '完整计算器',
            icon: Icons.calculate_outlined,
            onTap: _openCalculator,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        if (total == null || exam == null)
          Text('月考出分后，会用最近一次的专业总分估算综合分；也可以在完整计算器里手动输入。', style: AppText.body13)
        else
          _EstimateBody(
            loading: formState.loading,
            form: formState.form,
            exam: exam,
            culture: _culture,
            target: _target,
            formatters: _scoreFormatters,
            onChanged: ref.read(compositeEstimateFormProvider.notifier).update,
          ),
        const SizedBox(height: AppSpace.s8),
        Text(StudyCompositeEstimateCard.disclaimer, style: AppText.caption12),
      ],
    );
  }
}

class _EstimateBody extends StatelessWidget {
  const _EstimateBody({
    required this.loading,
    required this.form,
    required this.exam,
    required this.culture,
    required this.target,
    required this.formatters,
    required this.onChanged,
  });

  final bool loading;
  final CompositeEstimateForm form;
  final StudyExamRecord exam;
  final TextEditingController culture;
  final TextEditingController target;
  final List<TextInputFormatter> formatters;
  final void Function(CompositeEstimateForm Function(CompositeEstimateForm))
  onChanged;

  @override
  Widget build(BuildContext context) {
    final estimate = estimateComposite(
      province: form.province,
      professionalScore: exam.totalScore,
      professionalFull: exam.maxScore,
      culture: form.culture,
      target: form.target,
    );
    final converted =
        exam.maxScore != null && exam.maxScore != kDefaultProfessionalFull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpace.s16,
          runSpacing: AppSpace.s12,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(
              width: 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('省份', style: AppText.body14),
                  const SizedBox(height: 6),
                  AppSelect<ScoreProvince>(
                    options: [
                      for (final province in compositeEstimateProvinces)
                        AppSelectOption(value: province, label: province.label),
                    ],
                    value: form.province,
                    enabled: !loading,
                    onChanged: (value) =>
                        onChanged((f) => f.copyWith(province: value)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 148,
              child: AppInputField(
                controller: culture,
                label: '文化课预估分',
                hint: '0–750',
                enabled: !loading,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: formatters,
                errorText: estimate.cultureError == null
                    ? null
                    : '应为 0–750，最多两位小数',
                onChanged: (value) =>
                    onChanged((f) => f.copyWith(culture: value)),
              ),
            ),
            SizedBox(
              width: 148,
              child: AppInputField(
                controller: target,
                label: '目标综合分（选填）',
                hint: '如 560',
                enabled: !loading,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: formatters,
                errorText: estimate.targetError == null
                    ? null
                    : '应为 0–750，最多两位小数',
                onChanged: (value) =>
                    onChanged((f) => f.copyWith(target: value)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        const AppRule(),
        AppStatRow(
          label: '综合分预估',
          caption: _gapText(estimate),
          value: estimate.result?.text ?? '—',
          unit: estimate.result == null ? '' : '分',
        ),
        const AppRule(),
        const SizedBox(height: AppSpace.s12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '专业成绩 ', style: AppText.caption12),
              TextSpan(
                text: scoreInputText(exam.totalScore ?? 0),
                style: AppText.number(size: 12, color: AppColors.textSecondary),
              ),
              TextSpan(
                text:
                    ' / ${scoreInputText(exam.maxScore ?? 300)} 分'
                    '${converted ? '，已按 300 分折算为 ${scoreInputText(estimate.professional ?? 0)} 分' : ''}',
                style: AppText.caption12,
              ),
            ],
          ),
        ),
        Text(estimate.rule.formula, style: AppText.caption12),
        for (final step in estimate.result?.steps ?? const <ScoreStep>[])
          Text('${step.label}：${step.expression}', style: AppText.caption12),
      ],
    );
  }

  static String _gapText(CompositeEstimate estimate) {
    final gap = estimate.gap;
    if (estimate.result == null) return '填写文化课预估分后显示';
    if (gap == null) return '填写目标综合分，看看离目标还差多少';
    if (gap > 0) return '距目标还差 ${scoreInputText(gap)} 分';
    if (gap == 0) return '正好达到目标';
    return '已达到目标，高出 ${scoreInputText(-gap)} 分';
  }
}
