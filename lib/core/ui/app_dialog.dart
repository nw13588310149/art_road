import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';
import 'app_button.dart';
import 'app_colors.dart';
import 'app_icon_button.dart';
import 'app_motion.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 居中弹窗：白底圆角 12，标题 20 + 说明 14 + 内容 + 底部按钮。
///
/// 用 [showAppDialog] 打开。不依赖 `DashboardScaleScope`，登录页等外壳之外的页面也能用。
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    this.message,
    this.child,
    this.actions = const <Widget>[],
    this.fillActions = true,
    this.width = AppSize.dialog,
    this.showClose,
    super.key,
  });

  final String title;
  final String? message;

  /// 说明下方的自定义内容（表单、列表），超高时滚动。
  final Widget? child;

  /// 底部按钮，通常是 [AppButton]，主操作放最后。
  final List<Widget> actions;

  /// true 时按钮平分宽度；false 时靠右排列。
  final bool fillActions;
  final double width;

  /// 右上角关闭按钮；默认没有底部按钮时才显示。
  final bool? showClose;

  @override
  Widget build(BuildContext context) {
    final note = message;
    final content = child;
    final closable = showClose ?? actions.isEmpty;
    final hasNote = note != null && note.isNotEmpty;
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s24,
        AppSpace.s24,
        AppSpace.s24,
        AppSpace.s24 + insets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.br12,
                boxShadow: AppShadow.overlay,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpace.s24,
                      closable ? AppSpace.s20 : AppSpace.s24,
                      closable ? AppSpace.s16 : AppSpace.s24,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(title, style: AppText.title20)),
                        if (closable) ...[
                          const SizedBox(width: AppSpace.s8),
                          AppIconButton(
                            icon: Icons.close_rounded,
                            semanticLabel: '关闭',
                            size: AppButtonSize.sm,
                            filled: false,
                            color: AppColors.textSecondary,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasNote || content != null)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.s24,
                          AppSpace.s12,
                          AppSpace.s24,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (note != null && note.isNotEmpty)
                              Text(
                                note,
                                style: AppText.body14.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (hasNote && content != null)
                              const SizedBox(height: AppSpace.s16),
                            ?content,
                          ],
                        ),
                      ),
                    ),
                  if (actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpace.s12),
                            if (fillActions)
                              Expanded(child: actions[i])
                            else
                              actions[i],
                          ],
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: AppSpace.s24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 打开弹窗：遮罩 + 180ms 淡入。外壳内调用时会把 `DashboardScaleScope` 带进弹窗，
/// 方便内容里暂未迁移的旧组件继续工作。
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  final scale = DashboardScaleScope.maybeOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '关闭',
    barrierColor: AppColors.scrim,
    useRootNavigator: useRootNavigator,
    transitionDuration: AppMotion.overlay,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final child = SafeArea(child: Builder(builder: builder));
      return scale == null
          ? child
          : DashboardScaleScope(data: scale, child: child);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppMotion.overlayCurve,
        ),
        child: child,
      );
    },
  );
}

/// 二次确认：返回 true 表示点了确认；点遮罩或取消返回 false。
///
/// [danger] 为 true 时确认按钮为红色（删除、移除等不可撤销操作）。
Future<bool> showAppConfirm({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool danger = false,
  bool barrierDismissible = true,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AppDialog(
      title: title,
      message: message,
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(dialogContext).pop(false),
        ),
        AppButton(
          label: confirmLabel,
          variant: danger ? AppButtonVariant.danger : AppButtonVariant.primary,
          onTap: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
