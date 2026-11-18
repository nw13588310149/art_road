import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';

/// 开关：md 42×26 / sm 34×20，开为品牌紫，圆钮位置立即切换，没有滑动动画。
///
/// 新页面里控件的选中态不用紫色，传 `activeColor: AppColors.ink`。
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.size = AppControlSize.md,
    this.semanticLabel,
    this.activeColor = AppColors.brand,
    super.key,
  });

  final bool value;

  /// 打开时的底色。
  final Color activeColor;

  /// null 为禁用。
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final AppControlSize size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final md = size == AppControlSize.md;
    final knob = md ? 22.0 : 16.0;
    final change = onChanged;
    return AppPressable(
      onTap: change == null ? null : () => change(!value),
      enabled: enabled && change != null,
      toggled: value,
      semanticLabel: semanticLabel,
      child: Container(
        width: md ? 42 : 34,
        height: md ? 26 : 20,
        padding: const EdgeInsets.all(2),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? activeColor : AppColors.line,
          borderRadius: AppRadius.brPill,
        ),
        child: Container(
          width: knob,
          height: knob,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: AppShadow.knob,
          ),
        ),
      ),
    );
  }
}
