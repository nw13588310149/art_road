import 'package:flutter/material.dart';

import '../widgets/app_asset_graphic.dart';
import 'app_badge.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';

/// 方形图标按钮：md 40（圆角 12）/ sm 34（圆角 8）。
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
    this.background = AppColors.surfaceSubtle,
    this.color = AppColors.ink,
    this.badgeCount = 0,
    this.enabled = true,
    this.showTooltip = true,
    super.key,
  }) : _asset = null,
       _isBack = false;

  const AppIconButton.asset({
    required String asset,
    required this.semanticLabel,
    required this.onTap,
    this.badgeCount = 0,
    super.key,
  }) : _asset = asset,
       icon = null,
       size = AppButtonSize.md,
       filled = true,
       background = AppColors.surface,
       color = AppColors.ink,
       enabled = true,
       showTooltip = true,
       _isBack = false;

  const AppIconButton.back({required this.onTap, super.key})
    : icon = Icons.chevron_left,
      _asset = null,
      semanticLabel = '返回',
      size = AppButtonSize.sm,
      filled = true,
      background = AppColors.surface,
      color = AppColors.ink,
      badgeCount = 0,
      enabled = true,
      showTooltip = true,
      _isBack = true;

  final IconData? icon;
  final String? _asset;
  final bool _isBack;
  final String semanticLabel;
  final VoidCallback? onTap;
  final AppButtonSize size;

  /// 浅灰底；false 时无底色，用于页头、弹窗右上角。
  final bool filled;
  final Color background;
  final Color color;
  final int badgeCount;
  final bool enabled;
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    final md = size == AppButtonSize.md;
    final extent = _isBack
        ? 32.0
        : (md ? AppSize.iconButton : AppSize.iconButtonSm);
    final image = _asset;
    Widget box = Container(
      width: extent,
      height: extent,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? background : null,
        borderRadius: md ? AppRadius.br12 : AppRadius.br8,
        border: _isBack ? Border.all(color: AppColors.lineSoft) : null,
      ),
      child: image == null
          ? Icon(icon, size: md || _isBack ? 20 : 18, color: color)
          : AppAssetGraphic(
              image,
              width: extent,
              height: extent,
              fit: BoxFit.contain,
            ),
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
