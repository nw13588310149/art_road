import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 新页面的次要操作：墨色文字，可以带一个图标，没有底色和描边。
///
/// 页头里的「添加安排」、主按钮旁边的「怎么做」、排序都用它。品牌紫留给一屏里
/// 唯一的主按钮（`AppButton`）。高 44。
class AppPlainButton extends StatelessWidget {
  const AppPlainButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.color = AppColors.ink,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;
  final Color color;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      enabled: enabled && onTap != null,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpace.s4),
            ],
            Text(label, style: AppText.body14Strong.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
