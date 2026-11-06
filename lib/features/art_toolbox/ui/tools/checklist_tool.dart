import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../data/exam_checklist.dart';
import '../../data/toolbox_catalog.dart';
import '../../state/checklist_controller.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 考场物品清单：按证件、素描、色彩、速写、其他分组打勾，可添加自己的物品，勾选状态保存在本机。
class ChecklistTool extends ConsumerWidget {
  const ChecklistTool({required this.onBack, super.key});

  final VoidCallback onBack;

  Future<void> _clearTicks(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirm(
      context: context,
      title: '清空勾选',
      message: '所有物品会变回未准备，自己添加的物品会保留。',
      confirmLabel: '清空',
    );
    if (confirmed) {
      await ref
          .read(examChecklistControllerProvider.notifier)
          .reset(keepCustom: true);
      if (context.mounted) {
        AppToast.showSuccess(context, '已清空勾选');
      }
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirm(
      context: context,
      title: '恢复默认清单',
      message: '清空所有勾选，并删除自己添加的物品，删除后不能恢复。',
      confirmLabel: '恢复默认',
      danger: true,
    );
    if (confirmed) {
      await ref.read(examChecklistControllerProvider.notifier).reset();
      if (context.mounted) {
        AppToast.showSuccess(context, '已恢复默认清单');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examChecklistControllerProvider);
    final checklist = state.checklist;
    final controller = ref.read(examChecklistControllerProvider.notifier);
    return ToolPageScaffold(
      tool: ArtTool.checklist,
      onBack: onBack,
      actions: [
        AppButton(
          label: '清空勾选',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          onTap: state.loading || checklist.checkedCount == 0
              ? null
              : () => _clearTicks(context, ref),
        ),
        AppButton(
          label: '恢复默认清单',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          onTap: state.loading ||
                  (checklist.checkedCount == 0 && checklist.custom.isEmpty)
              ? null
              : () => _restore(context, ref),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          0,
          AppSpace.page,
          AppSpace.s24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.loading)
              const AppSkeleton(height: 88, radius: AppRadius.card)
            else
              _ProgressCard(checklist: checklist),
            const SizedBox(height: AppSpace.s12),
            const ToolNotice(kChecklistNotice),
            const SizedBox(height: AppSpace.s16),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = AppSpace.s16;
                final columns = constraints.maxWidth >= 760 ? 2 : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final group in ChecklistGroup.values)
                      SizedBox(
                        width: width,
                        child: state.loading
                            ? const AppSkeleton(
                                height: 200,
                                radius: AppRadius.card,
                              )
                            : _GroupCard(
                                group: group,
                                checklist: checklist,
                                onToggle: controller.toggle,
                                onRemove: (item) async {
                                  await controller.remove(item.id);
                                  if (context.mounted) {
                                    AppToast.showSuccess(
                                      context,
                                      '已删除「${item.label}」',
                                    );
                                  }
                                },
                                onAdd: (label) => controller.add(group, label),
                              ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.checklist});

  final ExamChecklist checklist;

  @override
  Widget build(BuildContext context) {
    final done = checklist.checkedCount;
    final total = checklist.total;
    final complete = total > 0 && done == total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('已准备', style: AppText.body14),
              const SizedBox(width: AppSpace.s8),
              Text(
                '$done',
                style: AppText.displayNumber(size: 24, color: AppColors.brand),
              ),
              Text(
                ' / $total 件',
                style: AppText.number(size: 14, color: AppColors.textSecondary),
              ),
              const Spacer(),
              if (complete)
                const AppStatusTag(label: '已完成', tone: AppTone.success)
              else
                AppStatusTag(
                  label: '还差 ${total - done} 件',
                  tone: AppTone.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          AppProgressBar(
            value: total == 0 ? 0 : done / total,
            color: complete ? AppColors.success : AppColors.brand,
          ),
          if (complete) ...[
            const SizedBox(height: AppSpace.s8),
            Text('都准备好了，出门前再核对一遍准考证和身份证', style: AppText.body13),
          ],
        ],
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  const _GroupCard({
    required this.group,
    required this.checklist,
    required this.onToggle,
    required this.onRemove,
    required this.onAdd,
  });

  final ChecklistGroup group;
  final ExamChecklist checklist;
  final ValueChanged<String> onToggle;
  final ValueChanged<ChecklistItem> onRemove;
  final Future<bool> Function(String label) onAdd;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  final TextEditingController _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final label = _input.text.trim();
    if (label.isEmpty) {
      setState(() => _error = '请输入物品名称');
      return;
    }
    final added = await widget.onAdd(label);
    if (!mounted) {
      return;
    }
    if (added) {
      _input.clear();
      setState(() => _error = null);
    } else {
      setState(() => _error = '「$label」已经在${widget.group.label}里了');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.checklist.itemsOf(widget.group);
    final done = items
        .where((item) => widget.checklist.isChecked(item.id))
        .length;
    return AppCard(
      title: widget.group.label,
      subtitle: '$done / ${items.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Row(
              children: [
                Expanded(
                  child: AppCheckbox(
                    value: widget.checklist.isChecked(item.id),
                    label: item.label,
                    onChanged: (_) => widget.onToggle(item.id),
                  ),
                ),
                if (item.custom)
                  AppIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: '删除「${item.label}」',
                    size: AppButtonSize.sm,
                    filled: false,
                    color: AppColors.textTertiary,
                    onTap: () => widget.onRemove(item),
                  ),
              ],
            ),
          const SizedBox(height: AppSpace.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppInputField(
                  controller: _input,
                  hint: '添加${widget.group.label}物品',
                  errorText: _error,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(kChecklistLabelMaxLength),
                  ],
                  onChanged: (_) {
                    if (_error != null) {
                      setState(() => _error = null);
                    }
                  },
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              AppButton(
                label: '添加',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.quiet,
                size: AppButtonSize.sm,
                onTap: _add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
