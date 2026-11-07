import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';
import 'app_colors.dart';
import 'app_icon_button.dart';
import 'app_motion.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 右侧抽屉：宽 420（[AppSize.drawer]）或 560（[AppSize.drawerWide]），
/// 标题栏 + 可滚动内容 + 可选底部按钮。
///
/// 用于原地办理（名单、选老师、筛选、详情）；会改变阶段或不可撤销的操作用确认弹窗。
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.width = AppSize.drawer,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.s24,
      AppSpace.s16,
      AppSpace.s24,
      AppSpace.s24,
    ),
    this.onClose,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// 底部按钮，靠右排列，主操作放最后。
  final List<Widget> actions;
  final double width;
  final EdgeInsetsGeometry padding;

  /// 默认关闭当前路由。
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(AppRadius.panel),
          ),
          boxShadow: AppShadow.overlay,
        ),
        child: SafeArea(
          left: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s24,
                  AppSpace.s16,
                  AppSpace.s16,
                  AppSpace.s16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title20,
                          ),
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body13,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    AppIconButton(
                      icon: Icons.close_rounded,
                      semanticLabel: '关闭',
                      filled: false,
                      color: AppColors.textSecondary,
                      onTap: onClose ?? () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
              Expanded(
                child: SingleChildScrollView(padding: padding, child: child),
              ),
              if (actions.isNotEmpty) ...[
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.lineSoft,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s24,
                    vertical: AppSpace.s16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpace.s12),
                        actions[i],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 从右侧滑入抽屉（180ms）。外壳内调用时会把 `DashboardScaleScope` 带进抽屉。
Future<T?> showAppDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final scale = DashboardScaleScope.maybeOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '关闭',
    barrierColor: AppColors.scrim,
    useRootNavigator: true,
    transitionDuration: AppMotion.overlay,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final child = Builder(builder: builder);
      return scale == null
          ? child
          : DashboardScaleScope(data: scale, child: child);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.overlayCurve,
                ),
              ),
          child: child,
        ),
      );
    },
  );
}
