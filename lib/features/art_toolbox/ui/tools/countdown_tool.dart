import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_date_time_pickers.dart';
import '../../data/countdown_repository.dart';
import '../../data/toolbox_catalog.dart';
import '../../state/countdown_controller.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 考试倒计时：本地保存的考试日期卡片，可增删改。
class CountdownTool extends ConsumerWidget {
  const CountdownTool({required this.onBack, super.key});

  final VoidCallback onBack;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    ExamCountdown? item,
  ]) async {
    final draft = await showAppDrawer<_CountdownDraft>(
      context: context,
      builder: (_) => _CountdownEditor(initial: item),
    );
    if (draft == null) {
      return;
    }
    final controller = ref.read(countdownControllerProvider.notifier);
    if (item == null) {
      await controller.add(draft.name, draft.date);
    } else {
      await controller.update(item.id, draft.name, draft.date);
    }
    if (context.mounted) {
      AppToast.showSuccess(context, item == null ? '已添加倒计时' : '已保存修改');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ExamCountdown item,
  ) async {
    final confirmed = await showAppConfirm(
      context: context,
      title: '删除倒计时',
      message: '确定删除「${item.name}」吗？删除后不能恢复。',
      confirmLabel: '删除',
      danger: true,
    );
    if (!confirmed) {
      return;
    }
    await ref.read(countdownControllerProvider.notifier).remove(item.id);
    if (context.mounted) {
      AppToast.showSuccess(context, '已删除');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countdownControllerProvider);
    final now = DateTime.now();
    final items = state.sorted(now);
    Widget content;
    if (state.loading) {
      content = const _CountdownGrid.skeleton();
    } else if (items.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.only(top: AppSpace.s32),
        child: AppEmptyState(
          title: '还没有考试倒计时',
          description: '添加联考、校考的日期，随时查看还剩多少天',
          icon: Icons.event_available_rounded,
          actionLabel: '添加倒计时',
          onAction: () => _edit(context, ref),
        ),
      );
    } else {
      content = _CountdownGrid(
        items: items,
        now: now,
        onEdit: (item) => _edit(context, ref, item),
        onDelete: (item) => _delete(context, ref, item),
      );
    }
    return ToolPageScaffold(
      tool: ArtTool.countdown,
      onBack: onBack,
      actions: [
        AppButton(
          label: '添加倒计时',
          icon: Icons.add_rounded,
          size: AppButtonSize.sm,
          onTap: state.loading ? null : () => _edit(context, ref),
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
            const ToolNotice(
              '默认日期仅为示例，具体考试时间请以甘肃省教育考试院及各招生院校发布的官方公告为准，点击卡片可以修改。',
            ),
            const SizedBox(height: AppSpace.s16),
            content,
          ],
        ),
      ),
    );
  }
}

class _CountdownGrid extends StatelessWidget {
  const _CountdownGrid({
    required this.items,
    required this.now,
    required this.onEdit,
    required this.onDelete,
  }) : skeleton = false;

  const _CountdownGrid.skeleton()
    : items = const <ExamCountdown>[],
      now = null,
      onEdit = null,
      onDelete = null,
      skeleton = true;

  final List<ExamCountdown> items;
  final DateTime? now;
  final ValueChanged<ExamCountdown>? onEdit;
  final ValueChanged<ExamCountdown>? onDelete;
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpace.s16;
        final width = constraints.maxWidth;
        final columns = width >= 840 ? 3 : (width >= 500 ? 2 : 1);
        final itemWidth = (width - gap * (columns - 1)) / columns;
        if (skeleton) {
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < columns; i++)
                SizedBox(
                  width: itemWidth,
                  child: const AppSkeleton(
                    height: _CountdownCard.height,
                    radius: AppRadius.card,
                  ),
                ),
            ],
          );
        }
        final today = now!;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: itemWidth,
                child: _CountdownCard(
                  item: items[i],
                  daysLeft: items[i].daysLeftFrom(today),
                  highlight: i == 0 && items[i].daysLeftFrom(today) >= 0,
                  onEdit: () => onEdit?.call(items[i]),
                  onDelete: () => onDelete?.call(items[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.item,
    required this.daysLeft,
    required this.highlight,
    required this.onEdit,
    required this.onDelete,
  });

  static const double height = 168;

  final ExamCountdown item;
  final int daysLeft;

  /// 下一场未开始的考试，浅紫底突出。
  final bool highlight;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final past = daysLeft < 0;
    final status = switch (daysLeft) {
      0 => '就是今天，加油',
      > 0 => highlight ? '下一场考试 · 还有' : '距离考试还有',
      _ => '已结束',
    };
    final numberColor = past
        ? AppColors.textTertiary
        : (highlight ? AppColors.brand : AppColors.ink);
    return AppCard(
      onTap: onEdit,
      color: highlight ? AppColors.brandWash : AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s8,
        AppSpace.s16,
      ),
      child: SizedBox(
        height: height - AppSpace.s12 - AppSpace.s16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s4),
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title16,
                    ),
                  ),
                ),
                AppIconButton(
                  icon: Icons.edit_outlined,
                  semanticLabel: '编辑',
                  size: AppButtonSize.sm,
                  filled: false,
                  color: AppColors.textSecondary,
                  onTap: onEdit,
                ),
                AppIconButton(
                  icon: Icons.delete_outline_rounded,
                  semanticLabel: '删除',
                  size: AppButtonSize.sm,
                  filled: false,
                  color: AppColors.textSecondary,
                  onTap: onDelete,
                ),
              ],
            ),
            const Spacer(),
            Text(status, style: AppText.caption12),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  daysLeft == 0 ? '今天' : '${daysLeft.abs()}',
                  style: daysLeft == 0
                      ? AppText.title24.copyWith(color: numberColor)
                      : AppText.displayNumber(size: 32, color: numberColor),
                ),
                if (daysLeft != 0) ...[
                  const SizedBox(width: AppSpace.s4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      past ? '天前' : '天',
                      style: AppText.body14.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpace.s8,
                      bottom: 3,
                    ),
                    child: Text(
                      '${item.dateText} ${item.weekdayText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppText.number(
                        size: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownDraft {
  const _CountdownDraft(this.name, this.date);

  final String name;
  final DateTime date;
}

class _CountdownEditor extends StatefulWidget {
  const _CountdownEditor({this.initial});

  final ExamCountdown? initial;

  @override
  State<_CountdownEditor> createState() => _CountdownEditorState();
}

class _CountdownEditorState extends State<_CountdownEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late DateTime? _date = widget.initial?.date;
  String? _nameError;
  String? _dateError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 6, 12, 31),
      helpText: '选择考试日期',
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _dateError = null;
      });
    }
  }

  void _submit() {
    final name = _name.text.trim();
    final date = _date;
    setState(() {
      _nameError = name.isEmpty ? '请输入考试名称，如「2027 年美术联考」' : null;
      _dateError = date == null ? '请选择考试日期' : null;
    });
    if (name.isEmpty || date == null) {
      return;
    }
    Navigator.of(context).pop(_CountdownDraft(name, date));
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    final dateText = date == null
        ? '请选择日期'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}';
    return AppDrawer(
      title: widget.initial == null ? '添加倒计时' : '编辑倒计时',
      subtitle: '只保存在本机',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: '保存', onTap: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInputField(
            controller: _name,
            label: '考试名称',
            hint: '如：2027 年美术联考',
            required: true,
            maxLength: 30,
            errorText: _nameError,
            onChanged: (_) {
              if (_nameError != null) {
                setState(() => _nameError = null);
              }
            },
          ),
          const SizedBox(height: AppSpace.s16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '* ',
                  style: AppText.body14.copyWith(color: AppColors.danger),
                ),
                TextSpan(text: '考试日期', style: AppText.body14),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AppPressable(
            onTap: _pickDate,
            semanticLabel: '选择考试日期',
            child: Container(
              height: AppSize.control,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.br8,
                border: Border.all(
                  color: _dateError == null ? AppColors.line : AppColors.danger,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      dateText,
                      style: date == null
                          ? AppText.body14.copyWith(
                              color: AppColors.textPlaceholder,
                            )
                          : AppText.number(size: 14),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (_dateError != null) ...[
            const SizedBox(height: AppSpace.s4),
            Text(
              _dateError!,
              style: AppText.caption12.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
