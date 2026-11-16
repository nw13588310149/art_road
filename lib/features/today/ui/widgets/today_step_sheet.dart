import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/today_models.dart';
import '../today_style.dart';

/// 在详情里选了什么操作。
enum TodayStepChoice { act, toggle, snooze, skip, delete }

/// 一件事的详情：是什么、哪来的、怎么做，以及可以对它做的操作。
///
/// 返回用户选的操作，由页面去执行；直接关掉返回 null。
Future<TodayStepChoice?> showTodayStepSheet(
  BuildContext context,
  TodayStep step,
) {
  return showAppDrawer<TodayStepChoice>(
    context: context,
    builder: (sheetContext) => _StepSheet(step: step),
  );
}

class _StepSheet extends StatelessWidget {
  const _StepSheet({required this.step});

  final TodayStep step;

  @override
  Widget build(BuildContext context) {
    void choose(TodayStepChoice choice) => Navigator.of(context).pop(choice);
    final open = step.status.open;
    final skipped = step.status == TodayStepStatus.skipped;
    final action = step.action;
    final progress = step.progress;
    // 课程和查寝按固定时间进行，不能推迟。
    final canSnooze =
        open && step.kind != 'lesson' && step.kind != 'dorm' && !step.required;
    final facts = <(String, String)>[
      ('状态', step.status.label),
      if (step.timeRange.isNotEmpty) ('时间', step.timeRange),
      (
        '类型',
        '${todayStepKindLabel(step.kind)} · ${step.required ? '必做' : '建议'}',
      ),
      if (step.source.isNotEmpty) ('来源', step.source),
      if (step.minutes > 0) ('建议用时', '约 ${step.minutes} 分钟'),
    ];
    return AppDrawer(
      title: step.title,
      subtitle: step.manual ? '做完后自己打勾' : '完成对应的操作后自动打勾',
      actions: [
        if (open && action != null)
          AppButton(
            label: action.label,
            onTap: () => choose(TodayStepChoice.act),
          )
        else if (open && step.manual)
          AppButton(
            label: '打勾，标记完成',
            onTap: () => choose(TodayStepChoice.toggle),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (step.detail.isNotEmpty) ...[
            Text(step.detail, style: AppText.body14),
            const SizedBox(height: AppSpace.s16),
          ],
          if (step.tag.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: AppTag(
                label: step.tag,
                tone: TodayPalette.tagTone(step.tagTone),
              ),
            ),
            const SizedBox(height: AppSpace.s16),
          ],
          Container(
            padding: const EdgeInsets.all(AppSpace.s12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: AppRadius.br12,
            ),
            child: Column(
              children: [
                for (final fact in facts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(fact.$1, style: AppText.body13),
                        ),
                        Expanded(
                          child: Text(
                            fact.$2,
                            style: AppText.body13.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpace.s16),
            Row(
              children: [
                Expanded(child: Text('进度', style: AppText.body14Strong)),
                Text(
                  '${progress.done} / ${progress.total} ${progress.unit}',
                  style: AppText.body13,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            AppProgressBar(
              value: progress.ratio,
              color: step.status == TodayStepStatus.overdue
                  ? TodayPalette.bad
                  : TodayPalette.brand,
              trackColor: step.status == TodayStepStatus.overdue
                  ? AppColors.dangerSoft
                  : AppColors.brandTint,
            ),
          ],
          if (step.guide.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s20),
            Text('怎么做', style: AppText.title16),
            const SizedBox(height: AppSpace.s8),
            for (var i = 0; i < step.guide.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.brandWash,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: AppText.number(
                          size: 12,
                          color: AppColors.brandDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(child: Text(step.guide[i], style: AppText.body14)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpace.s12),
          if (step.manual && !skipped && action != null)
            _Option(
              icon: step.done
                  ? Icons.undo_rounded
                  : Icons.check_circle_outline_rounded,
              label: step.done ? '取消打勾' : '已经做完，打勾',
              onTap: () => choose(TodayStepChoice.toggle),
            ),
          if (step.manual && step.done && action == null)
            _Option(
              icon: Icons.undo_rounded,
              label: '取消打勾',
              onTap: () => choose(TodayStepChoice.toggle),
            ),
          if (canSnooze)
            _Option(
              icon: Icons.nightlight_outlined,
              label: step.snoozed ? '取消推迟' : '推迟到晚上再做',
              onTap: () => choose(TodayStepChoice.snooze),
            ),
          if (!step.required && !step.done)
            _Option(
              icon: skipped ? Icons.replay_rounded : Icons.do_not_disturb_alt,
              label: skipped ? '恢复到清单' : '今天不做',
              onTap: () => choose(TodayStepChoice.skip),
            ),
          if (step.custom)
            _Option(
              icon: Icons.delete_outline_rounded,
              label: '删除这件安排',
              danger: true,
              onTap: () => choose(TodayStepChoice.delete),
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.lineSoft)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(label, style: AppText.body14.copyWith(color: color)),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 添加一件自己的安排。返回 `(标题, 时段, 备注)`；取消返回 null。
Future<({String title, String slot, String detail})?> showTodayAddStepDialog(
  BuildContext context,
) {
  return showAppDialog<({String title, String slot, String detail})>(
    context: context,
    builder: (_) => const _AddStepDialog(),
  );
}

class _AddStepDialog extends StatefulWidget {
  const _AddStepDialog();

  @override
  State<_AddStepDialog> createState() => _AddStepDialogState();
}

class _AddStepDialogState extends State<_AddStepDialog> {
  final _title = TextEditingController();
  final _detail = TextEditingController();
  String _slot = 'anytime';
  String _error = '';

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请填写要做的事');
      return;
    }
    Navigator.of(
      context,
    ).pop((title: title, slot: _slot, detail: _detail.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '添加安排',
      message: '给今天加一件自己要做的事，做完后打勾。',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: '添加', onTap: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInputField(
            controller: _title,
            label: '要做的事',
            hint: '例如：临摹一张速写',
            maxLength: 30,
            required: true,
            autofocus: true,
            errorText: _error.isEmpty ? null : _error,
            onChanged: (_) {
              if (_error.isNotEmpty) setState(() => _error = '');
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpace.s16),
          Text('什么时候做', style: AppText.body13),
          const SizedBox(height: AppSpace.s8),
          AppSegmented<String>(
            expand: true,
            value: _slot,
            onChanged: (value) => setState(() => _slot = value),
            segments: const [
              AppSegment(value: 'morning', label: '上午'),
              AppSegment(value: 'afternoon', label: '下午'),
              AppSegment(value: 'evening', label: '晚上'),
              AppSegment(value: 'anytime', label: '随时'),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          AppInputField(
            controller: _detail,
            label: '备注',
            hint: '可以不填',
            maxLength: 40,
          ),
        ],
      ),
    );
  }
}

/// 记录练习时长。返回分钟数；取消返回 null。
Future<int?> showTodayPracticeDialog(BuildContext context) {
  return showAppDialog<int>(
    context: context,
    builder: (_) => const _PracticeDialog(),
  );
}

class _PracticeDialog extends StatefulWidget {
  const _PracticeDialog();

  @override
  State<_PracticeDialog> createState() => _PracticeDialogState();
}

class _PracticeDialogState extends State<_PracticeDialog> {
  static const _choices = [10, 20, 30, 45, 60];
  int _minutes = 20;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '记录练习',
      message: '刚才练了多久？记下来后会计入今天的练习时长。',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: '记录 $_minutes 分钟',
          onTap: () => Navigator.of(context).pop(_minutes),
        ),
      ],
      child: Wrap(
        spacing: AppSpace.s8,
        runSpacing: AppSpace.s8,
        children: [
          for (final minutes in _choices)
            AppChip(
              label: '$minutes 分钟',
              selected: minutes == _minutes,
              onTap: () => setState(() => _minutes = minutes),
            ),
        ],
      ),
    );
  }
}
