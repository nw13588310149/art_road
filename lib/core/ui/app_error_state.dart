import 'package:flutter/material.dart';

import 'app_button.dart';
import 'app_colors.dart';
import 'app_empty_state.dart';
import 'app_spacing.dart';

/// 错误状态：说明出了什么问题 + 「重试」，在父级内居中。
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    this.title = '加载失败',
    this.description,
    this.onRetry,
    this.retryLabel = '重试',
    this.icon = Icons.cloud_off_rounded,
    super.key,
  });

  final String title;

  /// 具体原因或接下来能做什么（如「请检查网络后重试」）。
  final String? description;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      description: description,
      icon: icon,
      iconColor: AppColors.danger,
      iconBackground: AppColors.dangerSoft,
      action: onRetry == null
          ? null
          : AppButton(
              label: retryLabel,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.sm,
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
    );
  }
}
