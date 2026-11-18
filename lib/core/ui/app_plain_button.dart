import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 新页面的次要操作：墨色文字，可以带一个图标，没有底色和描边。
///
/// 页头里的「添加安排」、主按钮旁边的「怎么做」、排序都用它。品牌紫留给一屏里
/// 唯一的主按钮（`AppButton`）。高 44，宽度按内容取，不会撑满父级。
///
/// 左右各有 12 的内距（点击区域）。要让文字和上下的正文或右边缘对齐，在外面用
/// `Transform.translate` 抵消 12。
class AppPlainButton extends StatelessWidget {
  const AppPlainButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.color = AppColors.ink,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;
  final Color color;

  /// 读屏名称，要包含可见文字（例如按钮写「目录」，读作「目录与书签」）。
  /// 不传时读 [label]。
  final String? semanticLabel;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      enabled: enabled && onTap != null,
      semanticLabel: semanticLabel,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
        // 宽松约束下按内容取宽；被拉满时内容居中。
        child: Align(
          widthFactor: 1,
          // 给了读屏名称时不再把可见文字合并进去，避免读两遍。
          child: ExcludeSemantics(
            excluding: semanticLabel != null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: AppSpace.s4),
                ],
                Text(
                  label,
                  style: AppText.body14Strong.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
