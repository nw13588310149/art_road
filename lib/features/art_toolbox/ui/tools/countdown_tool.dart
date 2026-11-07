import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_date_time_pickers.dart';
import '../../data/countdown_repository.dart';
import '../../data/toolbox_catalog.dart';
import '../../state/countdown_controller.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 考试倒计时：本地保存的考试日程，可增删改。
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
      content = const _CountdownList.skeleton();
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
      content = _CountdownList(
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
              '默认日期仅为示例，具体考试时间请以甘肃省教育考试院及各招生院校发布的官方公告为准，点击考试可修改日期。',
            ),
            const SizedBox(height: AppSpace.s16),
            content,
          ],
        ),
      ),
    );
  }
}

class _CountdownList extends StatelessWidget {
  const _CountdownList({
    required this.items,
    required this.now,
    required this.onEdit,
    required this.onDelete,
  }) : skeleton = false;

  const _CountdownList.skeleton()
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
    if (skeleton) {
      return const Column(
        children: [
          AppSkeleton(height: 72),
          SizedBox(height: AppSpace.s8),
          AppSkeleton(height: 72),
        ],
      );
    }
    final today = now!;
    return Column(
      children: [
        for (var index = 0; index < items.length; index++)
          _CountdownRow(
            item: items[index],
            daysLeft: items[index].daysLeftFrom(today),
            highlight: index == 0 && items[index].daysLeftFrom(today) >= 0,
            onEdit: () => onEdit?.call(items[index]),
            onDelete: () => onDelete?.call(items[index]),
          ),
      ],
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.item,
    required this.daysLeft,
    required this.highlight,
    required this.onEdit,
    required this.onDelete,
  });

  final ExamCountdown item;
  final int daysLeft;
  final bool highlight;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final past = daysLeft < 0;
    final color = past
        ? AppColors.textTertiary
        : (highlight ? AppColors.brand : AppColors.ink);
    final status = switch (daysLeft) {
      0 => '今天考试',
      > 0 when highlight => '下一场考试',
      > 0 => '未开始',
      _ => '已结束',
    };
    return AppPressable(
      onTap: onEdit,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s12,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14Strong,
                  ),
                  Text(
                    '${item.dateText} ${item.weekdayText} · $status',
                    style: AppText.body13,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Text.rich(
              TextSpan(
                style: AppText.body13.copyWith(color: color),
                children: [
                  if (daysLeft == 0)
                    const TextSpan(text: '今天')
                  else ...[
                    TextSpan(
                      text: '${daysLeft.abs()}',
                      style: AppText.displayNumber(size: 24, color: color),
                    ),
                    TextSpan(text: past ? ' 天前' : ' 天'),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            AppIconButton.asset(
              asset: AppAssets.homeRename,
              assetSize: 18,
              semanticLabel: '编辑',
              size: AppButtonSize.sm,
              filled: false,
              onTap: onEdit,
            ),
            AppIconButton.asset(
              asset: AppAssets.coursewareActionDelete,
              assetSize: 18,
              semanticLabel: '删除',
              size: AppButtonSize.sm,
              filled: false,
              onTap: onDelete,
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
