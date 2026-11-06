import 'package:flutter/material.dart';

import 'app_badge.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';

/// 方形图标按钮：md 40 / sm 34，圆角 8。
///
/// [semanticLabel] 必填，同时作为读屏文字与悬停提示。[badgeCount] 大于 0 时
/// 右上角显示计数。
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.size = AppButtonSize.md,
    this.filled = true,
    this.color = AppColors.ink,
    this.badgeCount = 0,
    this.enabled = true,
    this.showTooltip = true,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final AppButtonSize size;

  /// 浅灰底；false 时无底色，用于页头、弹窗右上角。
  final bool filled;
  final Color color;
  final int badgeCount;
  final bool enabled;
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    final md = size == AppButtonSize.md;
    final extent = md ? AppSize.iconButton : AppSize.iconButtonSm;
    Widget box = Container(
      width: extent,
      height: extent,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.surfaceSubtle : null,
        borderRadius: AppRadius.br8,
      ),
      child: Icon(icon, size: md ? 20 : 18, color: color),
    );
    if (badgeCount > 0) {
      box = Stack(
        clipBehavior: Clip.none,
        children: [
          box,
          Positioned(top: -5, right: -5, child: AppBadge(count: badgeCount)),
        ],
      );
    }
    final button = AppPressable(
      onTap: onTap,
      enabled: enabled && onTap != null,
      semanticLabel: semanticLabel,
      child: box,
    );
    if (!showTooltip) {
      return button;
    }
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: button,
    );
  }
}
