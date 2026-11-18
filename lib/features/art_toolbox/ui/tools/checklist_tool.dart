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
///
/// 主栏是分组的物品行（设计语言第六节：要本人打勾的用 22 的圆圈，整行可点），
/// 每组最后一行直接输入添加；侧栏是整体进度。
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

    Widget groupOf(ChecklistGroup group) => _GroupSection(
      group: group,
      checklist: checklist,
      onToggle: controller.toggle,
      onRemove: (item) async {
        await controller.remove(item.id);
        if (context.mounted) {
          AppToast.showSuccess(context, '已删除「${item.label}」');
        }
      },
      onAdd: (label) => controller.add(group, label),
    );

    final groups = LayoutBuilder(
      builder: (context, constraints) {
        if (state.loading) {
          return const AppSkeletonText(lines: 10, lineHeight: 20);
        }
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in ChecklistGroup.values) groupOf(group),
            ],
          );
        }
        // 两列：左边证件、素描、速写，右边色彩、其他，两列大致一样长。
        const left = [
          ChecklistGroup.documents,
          ChecklistGroup.sketch,
          ChecklistGroup.speed,
        ];
        const right = [ChecklistGroup.color, ChecklistGroup.other];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final group in left) groupOf(group)],
              ),
            ),
            const SizedBox(width: AppSpace.s32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final group in right) groupOf(group)],
              ),
            ),
          ],
        );
      },
    );

    return ToolPageScaffold(
      tool: ArtTool.checklist,
      onBack: onBack,
      caption: '勾选状态保存在本机',
      actions: [
        AppPlainButton(
          label: '清空勾选',
          onTap: state.loading || checklist.checkedCount == 0
              ? null
              : () => _clearTicks(context, ref),
        ),
        AppPlainButton(
          label: '恢复默认清单',
          onTap:
              state.loading ||
                  (checklist.checkedCount == 0 && checklist.custom.isEmpty)
              ? null
              : () => _restore(context, ref),
        ),
      ],
      body: Builder(
        builder: (context) {
          final wide = ToolFrame.of(context)?.wide ?? true;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.only(bottom: AppSpace.s24),
                  child: groups,
                ),
              ),
              SizedBox(width: AppPageBody.columnGap(wide)),
              SizedBox(
                width: AppPageBody.sideWidth(wide),
                child: state.loading
                    ? const AppSkeleton(height: 160)
                    : _Progress(checklist: checklist),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 侧栏的整体进度：一个进度环，下面一句还差几件，再下面是考点要求的提醒。
class _Progress extends StatelessWidget {
  const _Progress({required this.checklist});

  final ExamChecklist checklist;

  @override
  Widget build(BuildContext context) {
    final done = checklist.checkedCount;
    final total = checklist.total;
    final complete = total > 0 && done == total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionTitle(title: '已准备'),
        const SizedBox(height: AppSpace.s16),
        Row(
          children: [
            AppProgressRing(
              value: total == 0 ? 0 : done / total,
              size: 88,
              stroke: 7,
              color: complete ? AppColors.success : AppColors.brand,
              semanticLabel: '已准备 $done 件，共 $total 件',
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$done', style: AppText.displayNumber(size: 24)),
                    Text('/ $total 件', style: AppText.caption12),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s16),
            Expanded(
              child: complete
                  ? const ToolNotice('都准备好了', tone: AppTone.success)
                  : Text('还差 ${total - done} 件', style: AppText.title16),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s16),
        Text(
          complete ? '出门前再核对一遍准考证和身份证。' : '准备好一件就勾一件，出门前再核对一遍准考证和身份证。',
          style: AppText.body13,
        ),
        const SizedBox(height: AppSpace.s24),
        const AppRule(),
        const SizedBox(height: AppSpace.s16),
        const ToolNotice(kChecklistNotice),
      ],
    );
  }
}

/// 一组物品：分区标题写组名和已勾数量，下面是物品行，最后一行直接输入添加。
class _GroupSection extends StatefulWidget {
  const _GroupSection({
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
  State<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends State<_GroupSection> {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionTitle(
            title: widget.group.label,
            note: '$done / ${items.length}',
          ),
          const SizedBox(height: AppSpace.s4),
          for (final item in items)
            _ItemRow(
              item: item,
              checked: widget.checklist.isChecked(item.id),
              onToggle: () => widget.onToggle(item.id),
              onRemove: item.custom ? () => widget.onRemove(item) : null,
            ),
          _AddRow(
            controller: _input,
            hint: '添加${widget.group.label}物品',
            error: _error,
            onChanged: () {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmit: _add,
          ),
        ],
      ),
    );
  }
}

/// 一件物品：22 的打勾圆圈和名称，整行可点；自己添加的物品行尾可以删除。
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.checked,
    required this.onToggle,
    this.onRemove,
  });

  final ChecklistItem item;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final remove = onRemove;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppPressable(
              onTap: onToggle,
              checked: checked,
              semanticLabel: item.label,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Row(
                  children: [
                    _TickCircle(checked: checked),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          item.label,
                          style: checked
                              ? AppText.body14.copyWith(
                                  color: AppColors.textSecondary,
                                )
                              : AppText.body14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (remove != null)
            Transform.translate(
              offset: const Offset(AppSpace.s12, 0),
              child: AppIconAction(
                icon: Icons.close_rounded,
                semanticLabel: '删除「${item.label}」',
                onTap: remove,
              ),
            ),
        ],
      ),
    );
  }
}

/// 要本人打勾的圆圈：没勾是浅灰描边，勾上是绿色实心加白色对勾。
class _TickCircle extends StatelessWidget {
  const _TickCircle({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? AppColors.success : null,
        border: checked
            ? null
            : Border.all(color: AppColors.textPlaceholder, width: 1.5),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 14, color: AppColors.onBrand)
          : null,
    );
  }
}

/// 每组最后一行：加号、不带边框的输入，右边「添加」。
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.controller,
    required this.hint,
    required this.error,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final String? error;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final message = error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: message == null ? AppColors.lineSoft : AppColors.danger,
              ),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                child: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppText.body14,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(kChecklistLabelMaxLength),
                  ],
                  decoration: InputDecoration.collapsed(
                    hintText: hint,
                    hintStyle: AppText.body14.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              Transform.translate(
                offset: const Offset(AppSpace.s12, 0),
                child: AppPlainButton(label: '添加', onTap: onSubmit),
              ),
            ],
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpace.s4),
          Text(
            message,
            style: AppText.caption12.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}
