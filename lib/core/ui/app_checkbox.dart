import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 复选框：16×16 圆角 4，选中品牌紫实底 + 白色对勾，立即切换。
///
/// 传 [label] 时文字也可点击，整行至少 32 高。
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  });

  final bool value;

  /// null 为禁用。
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool enabled;

  /// 没有 [label] 时供读屏使用。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    final box = Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: value ? AppColors.brand : AppColors.surface,
        borderRadius: AppRadius.br4,
        border: Border.all(
          color: value ? AppColors.brand : AppColors.textPlaceholder,
          width: 1.5,
        ),
      ),
      child: value
          ? const Icon(Icons.check_rounded, size: 12, color: AppColors.onBrand)
          : null,
    );
    final text = label;
    final content = text == null
        ? SizedBox(width: 24, height: 24, child: Center(child: box))
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                box,
                const SizedBox(width: AppSpace.s8),
                Flexible(child: Text(text, style: AppText.body14)),
              ],
            ),
          );
    return AppPressable(
      onTap: change == null ? null : () => change(!value),
      enabled: enabled && change != null,
      checked: value,
      semanticLabel: text == null ? semanticLabel : null,
      child: content,
    );
  }
}
