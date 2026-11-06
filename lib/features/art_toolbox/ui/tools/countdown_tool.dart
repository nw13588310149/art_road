import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_date_time_pickers.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../data/countdown_repository.dart';
import '../../data/toolbox_catalog.dart';
import '../../state/countdown_controller.dart';

/// 考试倒计时：本地保存的考试日期卡片，可增删改。
class CountdownTool extends ConsumerWidget {
  const CountdownTool({required this.onBack, super.key});

  final VoidCallback onBack;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    ExamCountdown? item,
  ]) async {
    final draft = await showScaledDialog<_CountdownDraft>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => _CountdownEditorDialog(initial: item),
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
      AppToast.show(context, item == null ? '已添加倒计时' : '已保存修改');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ExamCountdown item,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: '删除倒计时',
      content: '确定删除「${item.name}」吗？',
      confirmLabel: '删除',
    );
    if (!confirmed) {
      return;
    }
    await ref.read(countdownControllerProvider.notifier).remove(item.id);
    if (context.mounted) {
      AppToast.show(context, '已删除');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countdownControllerProvider);
    final now = DateTime.now();
    final items = state.sorted(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArtPageHeader(
          title: ArtTool.countdown.label,
          subtitle: ArtTool.countdown.description,
          onBack: onBack,
          actions: [
            ArtButton(
              label: '添加',
              icon: Icons.add_rounded,
              height: 34,
              onTap: () => _edit(context, ref),
            ),
          ],
        ),
        Expanded(
          child: state.loading
              ? const Center(child: AppLoadingIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ExampleNotice(),
                      const SizedBox(height: 16),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: ArtEmptyState(
                            icon: Icons.event_available_rounded,
                            message: '还没有倒计时，添加一个考试日期吧',
                            actionLabel: '添加倒计时',
                            onAction: () => _edit(context, ref),
                          ),
                        )
                      else
                        _CountdownGrid(
                          items: items,
                          now: now,
                          onEdit: (item) => _edit(context, ref, item),
                          onDelete: (item) => _delete(context, ref, item),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ExampleNotice extends StatelessWidget {
  const _ExampleNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF6DDB0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: ArtColors.warn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '默认日期仅为示例，具体考试时间请以甘肃省教育考试院及各招生院校发布的官方公告为准，可点击卡片修改。',
              style: ArtText.caption(size: 12, color: const Color(0xFF8A6420)),
            ),
          ),
        ],
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
  });

  final List<ExamCountdown> items;
  final DateTime now;
  final ValueChanged<ExamCountdown> onEdit;
  final ValueChanged<ExamCountdown> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final width = constraints.maxWidth;
        final columns = width >= 840 ? 3 : (width >= 500 ? 2 : 1);
        final itemWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: itemWidth,
                child: _CountdownCard(
                  item: items[i],
                  daysLeft: items[i].daysLeftFrom(now),
                  highlight: i == 0 && items[i].daysLeftFrom(now) >= 0,
                  onEdit: () => onEdit(items[i]),
                  onDelete: () => onDelete(items[i]),
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

  final ExamCountdown item;
  final int daysLeft;

  /// 最近一场未开始的考试，用渐变卡片突出。
  final bool highlight;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = ArtTool.countdown.accent;
    final past = daysLeft < 0;
    final primaryText = highlight ? Colors.white : ArtColors.ink;
    final secondaryText = highlight
        ? Colors.white.withValues(alpha: 0.8)
        : ArtColors.ink3;
    final numberColor = highlight
        ? Colors.white
        : (past ? ArtColors.ink4 : accent);
    final status = switch (daysLeft) {
      0 => '就是今天，加油！',
      > 0 => '距离考试还有',
      _ => '已结束',
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: Container(
        height: 172,
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 16),
        decoration: BoxDecoration(
          gradient: highlight
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, const Color(0xFFF08A6E)],
                )
              : null,
          color: highlight ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: highlight ? null : Border.all(color: ArtColors.line),
          boxShadow: highlight
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: primaryText,
                        fontWeight: AppFont.w600,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                ),
                _CardIconButton(
                  icon: Icons.edit_outlined,
                  color: secondaryText,
                  onTap: onEdit,
                ),
                _CardIconButton(
                  icon: Icons.delete_outline_rounded,
                  color: secondaryText,
                  onTap: onDelete,
                ),
              ],
            ),
            const Spacer(),
            Text(status, style: ArtText.caption(color: secondaryText)),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  daysLeft == 0 ? '今天' : '${daysLeft.abs()}',
                  style: daysLeft == 0
                      ? ArtText.title(size: 34, color: numberColor)
                      : ArtText.number(size: 44, color: numberColor),
                ),
                if (daysLeft != 0) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      past ? '天前' : '天',
                      style: ArtText.body(color: secondaryText),
                    ),
                  ),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 5),
                  child: Text(
                    '${item.dateText} ${item.weekdayText}',
                    style: ArtText.caption(color: secondaryText),
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

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _CountdownDraft {
  const _CountdownDraft(this.name, this.date);

  final String name;
  final DateTime date;
}

class _CountdownEditorDialog extends StatefulWidget {
  const _CountdownEditorDialog({this.initial});

  final ExamCountdown? initial;

  @override
  State<_CountdownEditorDialog> createState() => _CountdownEditorDialogState();
}

class _CountdownEditorDialogState extends State<_CountdownEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late DateTime? _date = widget.initial?.date;

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
      setState(() => _date = picked);
    }
  }

  void _submit() {
    final name = _name.text.trim();
    final date = _date;
    if (name.isEmpty) {
      AppToast.show(context, '请输入考试名称');
      return;
    }
    if (date == null) {
      AppToast.show(context, '请选择考试日期');
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
    final fieldDecoration = BoxDecoration(
      color: ArtColors.subtle,
      borderRadius: BorderRadius.circular(12),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null ? '添加倒计时' : '编辑倒计时',
                style: ArtText.title(size: 17),
              ),
              const SizedBox(height: 18),
              Text('考试名称', style: ArtText.caption(color: ArtColors.ink2)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: fieldDecoration,
                child: AppTextField(
                  controller: _name,
                  maxLength: 30,
                  style: ArtText.body(),
                  cursorColor: ArtColors.brand,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: '如：2027 年美术联考',
                    hintStyle: ArtText.body(color: ArtColors.ink4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('考试日期', style: ArtText.caption(color: ArtColors.ink2)),
              const SizedBox(height: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickDate,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: fieldDecoration,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: ArtColors.ink3,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dateText,
                          style: ArtText.body(
                            color: date == null
                                ? ArtColors.ink4
                                : ArtColors.ink,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: ArtColors.ink4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ArtButton(
                      label: '取消',
                      primary: false,
                      height: 42,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ArtButton(label: '保存', height: 42, onTap: _submit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
