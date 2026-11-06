import 'package:flutter/material.dart';

import '../theme/app_font.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';

/// 可选筛选胶囊：未选白底灰描边，选中浅紫底 + 品牌紫字 + 品牌紫描边。
///
/// 用于可多选或可取消的筛选条件；互斥的视图切换用 [AppSegmented]。
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.enabled = true,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.brand : AppColors.ink;
    return AppPressable(
      onTap: onTap,
      enabled: enabled,
      selected: selected,
      child: Container(
        height: AppSize.controlSm,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandWash : AppColors.surface,
          borderRadius: AppRadius.brPill,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: AppSpace.s4),
            ],
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: selected ? AppFont.w500 : AppFont.w400,
                color: foreground,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
