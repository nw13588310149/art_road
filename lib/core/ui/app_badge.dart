import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 角标：红色计数气泡或红点。计数为 0 且没有 [label] 时不占位。
class AppBadge extends StatelessWidget {
  const AppBadge({this.count = 0, this.label, this.max = 99, super.key})
    : dot = false;

  /// 只显示一个 8px 红点（有新内容但不需要数字）。
  const AppBadge.dot({super.key})
    : count = 0,
      label = null,
      max = 99,
      dot = true;

  final int count;

  /// 自定义文字（如「新」），优先于 [count]。
  final String? label;

  /// 超过后显示为「99+」。
  final int max;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    if (dot) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 1),
        ),
      );
    }
    final text =
        label ?? (count <= 0 ? null : (count > max ? '$max+' : '$count'));
    if (text == null) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 18,
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: const BoxDecoration(
        color: AppColors.danger,
        borderRadius: AppRadius.brPill,
      ),
      // 只按文字取宽：Container.alignment 在父级给出有界宽度时会撑满。
      child: Align(
        widthFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: label == null
              ? AppText.number(
                  size: 12,
                  color: AppColors.onBrand,
                ).copyWith(height: 1)
              : AppText.caption12Strong.copyWith(
                  color: AppColors.onBrand,
                  height: 1,
                ),
        ),
      ),
    );
  }
}
