import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/ui/ui.dart';
import '../../state/today_board.dart';

/// 「待处理」：按轻重排好的事项，每行一个数字和一个直达的操作。
///
/// 最要紧的一行用主按钮，其余用次按钮；已完成的行排在后面，只留「查看」。
class TodayTaskCard extends StatelessWidget {
  const TodayTaskCard({required this.board, required this.onOpen, super.key});

  final TodayBoard board;
  final ValueChanged<TodayTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    final tasks = board.tasks;
    final pending = board.pendingCount;
    final primary = tasks.where((task) => task.pending).firstOrNull;
    final more = board.moreTasksTarget;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(
            title: '待处理',
            titleStyle: AppText.title16,
            subtitle: pending > 0 ? '$pending 项' : null,
          ),
          const SizedBox(height: AppSpace.s4),
          if (tasks.isEmpty)
            _AllClear(title: board.taskEmptyTitle, hint: board.taskEmptyHint)
          else
            for (var i = 0; i < tasks.length; i++)
              _TaskRow(
                task: tasks[i],
                primary: identical(tasks[i], primary),
                divider: i < tasks.length - 1 || board.moreTasks > 0,
                onTap: () => onOpen(tasks[i].target),
              ),
          if (board.moreTasks > 0 && more != null)
            AppPressable(
              onTap: () => onOpen(more),
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpace.s12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '还有 ${board.moreTasks} 项，查看全部',
                      style: AppText.body13.copyWith(color: AppColors.brand),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.brand,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.primary,
    required this.divider,
    required this.onTap,
  });

  final TodayTask task;
  final bool primary;
  final bool divider;
  final VoidCallback onTap;

  ({Color color, Color background}) get _tile {
    if (task.level == TodayLevel.done) {
      return (color: AppColors.success, background: AppColors.successSoft);
    }
    final subject = ArtSubject.tryParse(task.subject);
    if (subject != null) {
      return (color: subject.accent, background: subject.accentSoft);
    }
    return switch (task.level) {
      TodayLevel.urgent => (
        color: AppColors.danger,
        background: AppColors.dangerSoft,
      ),
      TodayLevel.attention => (
        color: AppColors.brand,
        background: AppColors.brandWash,
      ),
      _ => (color: AppColors.ink, background: AppColors.surfaceSubtle),
    };
  }

  @override
  Widget build(BuildContext context) {
    final done = task.level == TodayLevel.done;
    final tile = _tile;
    final count = task.count;
    return AppPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        decoration: divider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
              )
            : null,
        child: Row(
          children: [
            AppIconTile(
              icon: done ? Icons.check_rounded : task.icon,
              size: 40,
              color: tile.color,
              background: tile.background,
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: done
                              ? AppText.body14.copyWith(
                                  color: AppColors.textSecondary,
                                )
                              : AppText.body14Strong,
                        ),
                      ),
                      if (task.tag.isNotEmpty) ...[
                        const SizedBox(width: AppSpace.s8),
                        AppTag(
                          label: task.tag,
                          tone: task.level == TodayLevel.urgent
                              ? AppTone.danger
                              : AppTone.warning,
                        ),
                      ],
                    ],
                  ),
                  if (task.detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                  ],
                ],
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: AppSpace.s12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$count',
                      style: AppText.number(
                        size: 20,
                        color: task.level == TodayLevel.urgent
                            ? AppColors.danger
                            : AppColors.ink,
                      ),
                    ),
                    TextSpan(text: ' ${task.unit}', style: AppText.caption12),
                  ],
                ),
              ),
            ],
            const SizedBox(width: AppSpace.s12),
            AppButton(
              label: task.actionLabel,
              size: AppButtonSize.sm,
              variant: done
                  ? AppButtonVariant.text
                  : (primary
                        ? AppButtonVariant.primary
                        : AppButtonVariant.secondary),
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// 没有任何待办时的一块安静说明。
class _AllClear extends StatelessWidget {
  const _AllClear({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
      child: Row(
        children: [
          const AppIconTile(
            icon: Icons.check_rounded,
            size: 40,
            color: AppColors.success,
            background: AppColors.successSoft,
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.body14Strong),
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(hint, style: AppText.caption12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
