import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 列表行：左侧图标 / 头像 + 标题 + 副标题 + 右侧内容 + 可选箭头。
///
/// 行与行之间的分隔由列表决定（`divider: true` 时画在底部，左侧与文字对齐）。
class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.enabled = true,
    this.divider = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpace.s16,
      vertical: AppSpace.s12,
    ),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// 右侧箭头，表示点击进入下一级。
  final bool chevron;
  final VoidCallback? onTap;
  final bool enabled;
  final bool divider;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    Widget row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpace.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.s12),
            trailing!,
          ],
          if (chevron) ...[
            const SizedBox(width: AppSpace.s4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textPlaceholder,
            ),
          ],
        ],
      ),
    );
    if (divider) {
      row = DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
        ),
        child: row,
      );
    }
    if (onTap == null && enabled) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: row,
      );
    }
    return AppPressable(
      onTap: onTap,
      enabled: enabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: row,
      ),
    );
  }
}
