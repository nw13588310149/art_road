import 'package:flutter/material.dart';

import 'app_button.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 空状态（紧凑）：图标 + 标题 + 可选说明 + 可选操作，在父级内居中。
///
/// 标题说清楚「这里会有什么」，说明告诉用户怎么让它出现，操作给出唯一的下一步。
/// 需要多个按钮时传 [action]，它优先于 [actionLabel]。父级过矮时内容可滚动，不会溢出。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.action,
    this.iconColor = AppColors.textTertiary,
    this.iconBackground = AppColors.surfaceSubtle,
    super.key,
  });

  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final note = description;
    final label = actionLabel;
    final Widget? resolvedAction =
        action ??
        (label != null && onAction != null
            ? AppButton(
                label: label,
                variant: AppButtonVariant.quiet,
                size: AppButtonSize.sm,
                onTap: onAction,
              )
            : null);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: AppSpace.s24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: AppRadius.br12,
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(height: AppSpace.s12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.body14Strong,
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s4),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  style: AppText.body13.copyWith(color: AppColors.textTertiary),
                ),
              ],
              if (resolvedAction != null) ...[
                const SizedBox(height: AppSpace.s16),
                resolvedAction,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
