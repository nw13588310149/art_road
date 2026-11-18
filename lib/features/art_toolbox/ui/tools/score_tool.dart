import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../data/score_form_repository.dart';
import '../../data/toolbox_catalog.dart';
import '../../logic/score_calculator.dart';
import '../../state/score_controller.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 综合分计算器：按省份预设公式估算艺术类综合分（排序成绩），展示计算过程与依据。
///
/// 左边是单列的表单，右边面板是结果：一个大数字、计算过程和依据。没有画，
/// 所以「画布」用白底，表单直接放在底板上。
class ScoreTool extends ConsumerStatefulWidget {
  const ScoreTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  ConsumerState<ScoreTool> createState() => _ScoreToolState();
}

String _provinceLabel(ScoreProvince province) => switch (province) {
  ScoreProvince.gansu => '甘肃 · 美术与设计类',
  ScoreProvince.beijing => '北京 · 本科',
  ScoreProvince.heilongjiang => '黑龙江 · 美术与设计类',
  _ => province.label,
};

final _scoreFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  LengthLimitingTextInputFormatter(7),
];

class _ScoreToolState extends ConsumerState<ScoreTool> {
  final _culture = TextEditingController();
  final _professional = TextEditingController();
  final _bonus = TextEditingController();
  final _full = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _culture.dispose();
    _professional.dispose();
    _bonus.dispose();
    _full.dispose();
    super.dispose();
  }

  void _seed(ScoreFormData data) {
    _seeded = true;
    _culture.text = data.culture;
    _professional.text = data.professional;
    _bonus.text = data.bonus;
    _full.text = '${data.custom.professionalFull}';
  }

  void _update(ScoreFormData Function(ScoreFormData data) change) =>
      ref.read(scoreFormControllerProvider.notifier).update(change);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scoreFormControllerProvider);
    if (!state.loading && !_seeded) {
      _seed(state.data);
    }
    return ToolPageScaffold(
      tool: ArtTool.score,
      onBack: widget.onBack,
      caption: '修改后自动保存在本机',
      body: ImageToolLayout(
        hint: '',
        canvasColor: AppColors.surface,
        stage: (_) => SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.only(bottom: AppSpace.s24),
          child: state.loading
              ? const AppSkeletonText(lines: 8, lineHeight: 20)
              : _buildForm(state.data),
        ),
        panel: (_) => state.loading
            ? const AppSkeletonText(lines: 6, lineHeight: 20)
            : _ScoreResult(data: state.data),
      ),
    );
  }

  Widget _buildForm(ScoreFormData data) {
    final rule = data.rule;
    final outcome = data.outcome;
    final error = outcome.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolField(
          label: '省份',
          child: AppSelect<ScoreProvince>(
            options: [
              for (final p in ScoreProvince.values)
                AppSelectOption(value: p, label: _provinceLabel(p)),
            ],
            value: data.province,
            onChanged: (p) => _update((d) => d.copyWith(province: p)),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        if (data.province == ScoreProvince.yunnan) ...[
          ToolField(
            label: '计算方式',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToolSegmented<YunnanMode>(
                  values: YunnanMode.values,
                  value: data.yunnanMode,
                  labelOf: (m) => m.label,
                  onChanged: (m) => _update((d) => d.copyWith(yunnanMode: m)),
                ),
                ToolNote(data.yunnanMode.description),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
        ],
        if (data.province == ScoreProvince.custom) ..._buildCustom(data),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInputField(
                controller: _culture,
                label: '文化课成绩',
                hint: '如 500',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: _scoreFormatters,
                errorText: error != null && error.startsWith('文化')
                    ? error
                    : null,
                onChanged: (v) => _update((d) => d.copyWith(culture: v)),
              ),
            ),
            const SizedBox(width: AppSpace.s16),
            Expanded(
              child: AppInputField(
                controller: _professional,
                label: '专业统考成绩',
                hint: rule.cultureOnly ? '只作合格判断' : '如 240',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: _scoreFormatters,
                errorText: error != null && error.startsWith('专业')
                    ? error
                    : null,
                onChanged: (v) => _update((d) => d.copyWith(professional: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          '文化课满分 750 · 专业统考满分 ${rule.professionalFull}',
          style: AppText.caption12,
        ),
        if (rule.withBonus) ...[
          const SizedBox(height: AppSpace.s16),
          AppInputField(
            controller: _bonus,
            label: '政策加分（没有可不填）',
            hint: '如 10',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _scoreFormatters,
            errorText: error != null && error.startsWith('政策') ? error : null,
            onChanged: (v) => _update((d) => d.copyWith(bonus: v)),
          ),
        ],
        const SizedBox(height: AppSpace.s24),
        ToolTipCard(title: '计算公式', text: rule.formula),
      ],
    );
  }

  List<Widget> _buildCustom(ScoreFormData data) {
    final custom = data.custom;
    final fullText = _full.text.trim();
    final full = int.tryParse(fullText);
    final fullError =
        fullText.isNotEmpty &&
            (full == null || full < 1 || full > kMaxProfessionalFull)
        ? '专业满分应为 1–$kMaxProfessionalFull 的整数'
        : null;
    return [
      ToolSliderRow(
        label: '文化成绩权重',
        hint: '专业成绩权重为 ${100 - custom.culturePercent}%',
        value: custom.culturePercent.toDouble(),
        min: 0,
        max: 100,
        divisions: 20,
        valueLabel: '${custom.culturePercent}%',
        onChanged: (v) => _update(
          (d) =>
              d.copyWith(custom: d.custom.copyWith(culturePercent: v.round())),
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppInputField(
              controller: _full,
              label: '专业满分',
              hint: '如 300',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              errorText: fullError,
              onChanged: (v) {
                final parsed = int.tryParse(v.trim());
                if (parsed != null &&
                    parsed >= 1 &&
                    parsed <= kMaxProfessionalFull) {
                  _update(
                    (d) => d.copyWith(
                      custom: d.custom.copyWith(professionalFull: parsed),
                    ),
                  );
                } else {
                  setState(() {});
                }
              },
            ),
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: ToolField(
              label: '保留小数',
              child: ToolSegmented<int>(
                values: const [0, 1, 2, 3],
                value: custom.decimals,
                labelOf: (n) => n == 0 ? '取整' : '$n 位',
                onChanged: (n) => _update(
                  (d) => d.copyWith(custom: d.custom.copyWith(decimals: n)),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.s16),
    ];
  }
}

/// 右侧面板：综合分（一屏唯一的大数字）、计算过程、依据和免责说明。
class _ScoreResult extends StatelessWidget {
  const _ScoreResult({required this.data});

  final ScoreFormData data;

  @override
  Widget build(BuildContext context) {
    final rule = data.rule;
    final outcome = data.outcome;
    final result = outcome.result;
    final error = outcome.error;
    final List<Widget> body;
    if (error != null) {
      body = [ToolNotice(error, tone: AppTone.danger)];
    } else if (result == null) {
      body = [Text('填好文化课和专业统考成绩后，这里显示综合分和计算过程。', style: AppText.body13)];
    } else {
      body = [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                result.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.displayNumber(size: 32, color: AppColors.brand),
              ),
            ),
            const SizedBox(width: AppSpace.s4),
            Text('分', style: AppText.body14),
          ],
        ),
        if (rule.note.isNotEmpty) Text(rule.note, style: AppText.caption12),
        const SizedBox(height: AppSpace.s24),
        const AppSectionTitle(title: '计算过程'),
        const SizedBox(height: AppSpace.s4),
        for (final (index, step) in result.steps.indexed) ...[
          if (index > 0) const AppRule(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.label, style: AppText.caption12),
                const SizedBox(height: 2),
                Text(step.expression, style: AppText.number(size: 14)),
              ],
            ),
          ),
        ],
      ];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: '综合分',
          note: '排序成绩 · ${_provinceLabel(data.province)}',
        ),
        const SizedBox(height: AppSpace.s12),
        ...body,
        const SizedBox(height: AppSpace.s24),
        const AppRule(),
        const SizedBox(height: AppSpace.s16),
        Text('依据：${rule.source}', style: AppText.caption12),
        const SizedBox(height: AppSpace.s12),
        const ToolNotice('$kScoreDisclaimer。计算结果仅供估算参考，录取以官方公布的成绩和招生章程为准。'),
      ],
    );
  }
}
