import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../state/today_board.dart';

/// 「值得关注」：最多三格，每格一个数字和一句依据，点开进入详情。这里不放图表。
class TodaySignalCard extends StatelessWidget {
  const TodaySignalCard({required this.board, required this.onOpen, super.key});

  final TodayBoard board;
  final ValueChanged<TodayTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    final signals = board.signals.take(3).toList();
    return AppCard(
      title: board.signalsTitle,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < signals.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.s12),
              Expanded(
                child: _SignalTile(
                  signal: signals[i],
                  onTap: () => onOpen(signals[i].target),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.signal, required this.onTap});

  final TodaySignal signal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (signal.level) {
      TodayLevel.urgent => AppColors.danger,
      TodayLevel.attention => AppColors.warning,
      _ => AppColors.ink,
    };
    // 数字用展示数字字体；「色彩」这类文字用标题字体。
    final numeric = RegExp(r'^[0-9./\s—+-]+$').hasMatch(signal.value);
    return AppPressable(
      onTap: onTap,
      semanticLabel:
          '${signal.label} ${signal.value}${signal.unit} ${signal.caption}',
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    signal.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12Strong,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: signal.value,
                    style: numeric
                        ? AppText.displayNumber(size: 24, color: color)
                        : AppText.title20.copyWith(color: color),
                  ),
                  if (signal.unit.isNotEmpty)
                    TextSpan(text: ' ${signal.unit}', style: AppText.caption12),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (signal.caption.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s4),
              Text(
                signal.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 需要跟进的人和事：每行一句话，点开进入对应的报表或档案。
class TodayNoteCard extends StatelessWidget {
  const TodayNoteCard({required this.board, required this.onOpen, super.key});

  final TodayBoard board;
  final ValueChanged<TodayTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    final notes = board.notes;
    return AppCard(
      title: board.notesTitle,
      child: notes.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Text(board.notesEmpty, style: AppText.body13),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < notes.length; i++)
                  AppListRow(
                    title: notes[i].title,
                    subtitle: notes[i].detail,
                    chevron: true,
                    divider: i < notes.length - 1,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                    minHeight: 44,
                    onTap: () => onOpen(notes[i].target),
                  ),
              ],
            ),
    );
  }
}

/// 「常用」：这个身份常去的几个地方，放在页面底部。
class TodayShortcutCard extends StatelessWidget {
  const TodayShortcutCard({
    required this.shortcuts,
    required this.onOpen,
    super.key,
  });

  final List<TodayShortcut> shortcuts;
  final ValueChanged<TodayTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s8),
            child: Text('常用', style: AppText.body14Strong),
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final shortcut in shortcuts)
                  AppPressable(
                    onTap: () => onOpen(shortcut.target),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: AppRadius.br12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(shortcut.icon, size: 18, color: AppColors.ink),
                          const SizedBox(width: AppSpace.s8),
                          Text(
                            shortcut.label,
                            style: AppText.body13.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
