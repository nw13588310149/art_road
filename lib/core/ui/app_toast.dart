import 'dart:async';

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_text.dart';

enum AppToastType { success, error, info }

/// 全局轻提示：顶部居中的白色浮条，图标区分成功 / 失败 / 信息，180ms 淡入下滑。
///
/// 同一时间只显示一条，新提示会替换旧提示。不依赖 `DashboardScaleScope`。
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// `type` 不传时根据 [message] 文本自动判定成功 / 失败：
  /// - 含「失败 / 错误 / 无效 / 失效 / 无法 / 不支持 / 尚未 / 不可用 / 重试」→ 失败
  /// - 含「成功 / 完成」或「已…」状态确认 → 成功
  /// - 其余（请…、暂无… 等）兜底为失败样式
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
    AppToastType? type,
  }) {
    final text = message.trim();
    if (text.isEmpty) {
      return;
    }
    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }
    final resolved = type ?? _autoDetectType(text);

    _timer?.cancel();
    _entry?.remove();
    final entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: 72,
        left: AppSpace.s24,
        right: AppSpace.s24,
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: AppMotion.overlay,
              curve: AppMotion.overlayCurve,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -8 * (1 - value)),
                  child: child,
                ),
              ),
              child: Center(
                child: _ToastBody(text: text, type: resolved),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () {
      if (_entry == entry) {
        entry.remove();
        _entry = null;
      }
    });
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    show(context, message, duration: duration, type: AppToastType.success);
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    show(context, message, duration: duration, type: AppToastType.error);
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    show(context, message, duration: duration, type: AppToastType.info);
  }

  static AppToastType _autoDetectType(String text) {
    const errorKeywords = <String>[
      '失败',
      '错误',
      '无效',
      '失效',
      '无法',
      '不支持',
      '尚未',
      '不可用',
      '重试',
      '再试',
    ];
    for (final keyword in errorKeywords) {
      if (text.contains(keyword)) return AppToastType.error;
    }
    if (text.contains('成功') || text.contains('完成')) {
      return AppToastType.success;
    }
    if (text.contains('已')) return AppToastType.success;
    return AppToastType.error;
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({required this.text, required this.type});

  final String text;
  final AppToastType type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      AppToastType.success => (Icons.check_circle_rounded, AppColors.success),
      AppToastType.error => (Icons.error_rounded, AppColors.danger),
      AppToastType.info => (Icons.info_rounded, AppColors.brand),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 420),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: AppShadow.overlay,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpace.s8),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body14,
            ),
          ),
        ],
      ),
    );
  }
}
