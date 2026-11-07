import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 页内提示条：浅底深字，左侧图标 + 一段说明，右侧可放一个操作。
///
/// 用于持续存在的状态说明（「阅卷中，出分后可查看」「全部老师点评后可查看分数」）；
/// 一次性的操作结果用 [AppToast]，没有数据用 [AppEmptyState]。
class AppNotice extends StatelessWidget {
  const AppNotice({
    required this.message,
    this.tone = AppTone.info,
    this.icon,
    this.action,
    super.key,
  });

  final String message;
  final AppTone tone;

  /// 为空时按色调取默认图标。
  final IconData? icon;

  /// 右侧操作，通常是 `AppButton(variant: text, size: sm)`。
  final Widget? action;

  static IconData _defaultIcon(AppTone tone) => switch (tone) {
    AppTone.success => Icons.check_circle_outline_rounded,
    AppTone.warning => Icons.schedule_rounded,
    AppTone.danger => Icons.error_outline_rounded,
    _ => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final trailing = action;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: AppRadius.br8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon ?? _defaultIcon(tone),
              size: 16,
              color: tone.foreground,
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              message,
              style: AppText.body13.copyWith(color: tone.foreground),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.s12),
            trailing,
          ],
        ],
      ),
    );
  }
}
