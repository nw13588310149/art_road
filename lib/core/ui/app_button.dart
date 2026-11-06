import 'package:flutter/material.dart';

import '../theme/app_font.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';

/// 按钮变体（与机构端 Button 同名同义）。
enum AppButtonVariant {
  /// 品牌紫实底：每个区域只放一个主操作。
  primary,

  /// 白底描边：取消、返回等中性操作。
  secondary,

  /// 浅紫底深紫字：工具条、卡片内的次要操作。
  quiet,

  /// 红色实底：删除、移除等不可撤销操作。
  danger,

  /// 无底品牌紫文字：行内链接式操作。
  text,
}

/// 统一按钮：md 44 高 16px，sm 34 高 14px，圆角 8。
///
/// [onTap] 为 null 或 [enabled] 为 false 时为禁用态；[loading] 时显示转圈并忽略点击。
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onTap,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.loading = false,
    this.enabled = true,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool enabled;

  /// 撑满父级宽度。
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final md = size == AppButtonSize.md;
    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (AppColors.brand, AppColors.onBrand, null),
      AppButtonVariant.secondary => (
        AppColors.surface,
        AppColors.ink,
        AppColors.line,
      ),
      AppButtonVariant.quiet => (
        AppColors.brandWash,
        AppColors.brandDeep,
        null,
      ),
      AppButtonVariant.danger => (AppColors.danger, AppColors.onBrand, null),
      AppButtonVariant.text => (null, AppColors.brand, null),
    };
    final horizontal = variant == AppButtonVariant.text
        ? AppSpace.s4
        : (md ? AppSpace.s20 : 14.0);
    final iconSize = md ? 18.0 : 16.0;
    final Widget? leading = loading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : (icon == null ? null : Icon(icon, size: iconSize, color: foreground));

    final content = Container(
      height: md ? AppSize.buttonMd : AppSize.buttonSm,
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.br8,
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: md ? 16 : 14,
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
