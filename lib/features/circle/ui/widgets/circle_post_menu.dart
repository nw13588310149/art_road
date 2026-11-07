import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';

enum _PostMenuAction { report, delete }

/// 动态的「···」更多操作：举报 / 删除动态。两个回调都为空时不显示。
///
/// [onDark] 用于大图模式：白色图标叠在半透明墨色底上，深浅画面都看得清。
class CirclePostMenuButton extends StatelessWidget {
  const CirclePostMenuButton({
    super.key,
    this.onDelete,
    this.onReport,
    this.onDark = false,
  });

  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (onDelete == null && onReport == null) return const SizedBox.shrink();
    final button = Builder(
      builder: (anchor) => AppIconButton(
        icon: Icons.more_horiz_rounded,
        semanticLabel: '更多操作',
        size: AppButtonSize.sm,
        filled: false,
        color: onDark ? AppColors.onBrand : AppColors.textTertiary,
        onTap: () => _open(anchor),
      ),
    );
    if (!onDark) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.4),
        borderRadius: AppRadius.br8,
      ),
      child: button,
    );
  }

  Future<void> _open(BuildContext anchor) async {
    final action = await showAppMenu<_PostMenuAction>(
      context: anchor,
      width: 132,
      items: [
        if (onReport != null)
          const AppMenuItem(
            value: _PostMenuAction.report,
            label: '举报',
            icon: Icons.flag_outlined,
          ),
        if (onDelete != null)
          const AppMenuItem(
            value: _PostMenuAction.delete,
            label: '删除动态',
            icon: Icons.delete_outline_rounded,
            danger: true,
          ),
      ],
    );
    switch (action) {
      case _PostMenuAction.report:
        onReport?.call();
      case _PostMenuAction.delete:
        onDelete?.call();
      case null:
        break;
    }
  }
}
