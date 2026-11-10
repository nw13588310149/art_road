import 'package:flutter/material.dart';

import '../theme/app_font.dart';
import '../widgets/app_asset_graphic.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';

/// 按钮变体。
enum AppButtonVariant {
  /// 品牌紫渐变：每个区域只放一个主操作。
  primary,

  /// 白底描边：取消、返回等中性操作。
  secondary,

  /// 云盘、笔记等内容区右下角的浮动操作。
  floating,

  /// 浅紫底深紫字：工具条、卡片内的次要操作。
  quiet,

  /// 红色实底：删除、移除等不可撤销操作。
  danger,

  /// 无底品牌紫文字：行内链接式操作。
  text,
}

/// 统一按钮：md 45 高 16px，sm 34 高 14px，圆角 12。
///
/// [onTap] 为 null 或 [enabled] 为 false 时为禁用态；[loading] 时显示转圈并忽略点击。
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onTap,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.iconAsset,
    this.loading = false,
    this.enabled = true,
    this.expand = false,
    super.key,
  }) : assert(icon == null || iconAsset == null);

  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final String? iconAsset;
  final bool loading;
  final bool enabled;

  /// 撑满父级宽度。
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final md = size == AppButtonSize.md;
    final floating = variant == AppButtonVariant.floating;
    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.brand, AppColors.onBrand, null),
      AppButtonVariant.secondary || AppButtonVariant.floating => (
        AppColors.surface,
        AppColors.ink,
        AppColors.lineSoft,
      ),
      AppButtonVariant.quiet => (
        AppColors.brandWash,
        AppColors.brandDeep,
        null,
      ),
      AppButtonVariant.danger => (AppColors.danger, AppColors.onBrand, null),
      AppButtonVariant.text => (null, AppColors.brand, null),
    };
    final horizontal = switch (variant) {
      AppButtonVariant.text => AppSpace.s4,
      AppButtonVariant.floating => 13.0,
      _ => md ? AppSpace.s20 : 14.0,
    };
    final iconSize = floating ? 20.0 : (md ? 18.0 : 16.0);
    final asset = iconAsset;
    final Widget? leading = loading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : asset != null
        ? AppAssetGraphic(asset, width: iconSize, height: iconSize)
        : (icon == null ? null : Icon(icon, size: iconSize, color: foreground));

    final content = Container(
      height: floating ? 40 : (md ? AppSize.buttonMd : AppSize.buttonSm),
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      decoration: BoxDecoration(
        color: variant == AppButtonVariant.primary ? null : background,
        gradient: variant == AppButtonVariant.primary
            ? const LinearGradient(
                colors: [AppColors.brandDeep, AppColors.brand],
              )
            : null,
        borderRadius: floating ? AppRadius.br8 : AppRadius.br12,
        border: border == null ? null : Border.all(color: border),
        boxShadow: floating
            ? const [
                BoxShadow(
                  color: Color(0x59B5B5B5),
                  blurRadius: 20,
                  offset: Offset(0, 16),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading,
            SizedBox(width: floating ? AppSpace.s8 : 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: md || floating ? 16 : 14,
                height: 1.25,
                fontWeight: AppFont.w500,
                color: foreground,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
        ],
      ),
    );

    return AppPressable(
      onTap: loading ? null : onTap,
      enabled: enabled && onTap != null,
      child: content,
    );
  }
}
