import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../shell/ui/shell_layout.dart';

/// 列表卡片右上角的原版删除图标（白底描边方块）。
const _kDeleteOnCard = 'assets/images/circle/del1.png';

/// 沉浸模式右上角的原版删除图标（半透明深色方块）。
const _kDeleteOnImage = 'assets/images/home/del.png';

enum _PostMenuAction { report, delete }

/// 动态右上角的操作：只能删除时直接显示原版删除图标；能举报时显示同尺寸的
/// 「···」按钮，展开举报 / 删除动态。两个回调都为空时不显示。
///
/// [onDark] 用于沉浸模式：深色半透明底、白色图标。
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
    final ui = DashboardScaleScope.of(context).ui;
    final delete = onDelete;
    if (delete == null && onReport == null) return const SizedBox.shrink();
    if (onReport == null && delete != null) {
      return AppPressable(
        onTap: delete,
        semanticLabel: '删除动态',
        child: Image.asset(
          onDark ? _kDeleteOnImage : _kDeleteOnCard,
          width: ui(32),
          height: ui(32),
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      );
    }
    return Builder(
      builder: (anchor) => AppPressable(
        onTap: () => _open(anchor),
        semanticLabel: '更多操作',
        child: Container(
          width: ui(32),
          height: ui(32),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: onDark
                ? null
                : Border.all(color: const Color(0xFFF3F2F3), width: 1),
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            size: ui(20),
            color: onDark ? Colors.white : const Color(0xFF1C274C),
          ),
        ),
      ),
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
