import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 区块标题：标题 + 可选副标题 + 右侧「更多」或自定义操作。
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.subtitle,
    this.onMore,
    this.moreLabel = '更多',
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// 传入后右侧显示「更多 ›」。
  final VoidCallback? onMore;
  final String moreLabel;

  /// 自定义右侧内容，优先于「更多」。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    final Widget? action =
        trailing ??
        (onMore == null
            ? null
            : AppPressable(
                onTap: onMore,
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.br12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        moreLabel,
                        style: AppText.body14.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ));
    // 标题与副标题放进 Expanded 内的子 Row，右侧操作才能始终贴右。
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title20,
                ),
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(width: AppSpace.s8),
                Flexible(
                  child: Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: AppSpace.s12), action],
      ],
    );
  }
}
