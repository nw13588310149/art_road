import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/app_colors.dart';
import '../../../../core/ui/app_pressable.dart';
import '../../../shell/ui/shell_layout.dart';

/// 原版右侧抽屉宽度：表单 600、窄侧栏 344。
const double kSmartCampusDrawerWidthWide = 600;
const double kSmartCampusDrawerWidthNarrow = 344;

/// 打开原版右侧滑入抽屉：240ms、easeOutCubic、半透明遮罩。
///
/// 对应 R `teacher_homework_review_view.dart` 887–915（`_openHistoryDrawer`）。
/// [child] 通常是 [SmartCampusSideDrawerShell]。
Future<T?> showSmartCampusSideDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String barrierLabel = '关闭',
  Duration transitionDuration = const Duration(milliseconds: 240),
}) {
  final scale = DashboardScaleScope.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.20),
    transitionDuration: transitionDuration,
    pageBuilder: (ctx, anim, sec) {
      return Align(
        alignment: Alignment.centerRight,
        child: DashboardScaleScope(
          data: scale,
          child: builder(ctx),
        ),
      );
    },
    transitionBuilder: (ctx, anim, sec, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

/// 原版抽屉外壳：白底全高、内距 20；标题紫条；可选底部 48 高渐变主按钮。
///
/// 对应 R `teacher_homework_review_view.dart` 3253–3423（点评抽屉骨架）与
/// 4324–4356（`_DrawerTitleBar`）、4512–4558（`_PrimaryGradientButton`）。
class SmartCampusSideDrawerShell extends StatelessWidget {
  const SmartCampusSideDrawerShell({
    required this.title,
    required this.body,
    this.width = kSmartCampusDrawerWidthWide,
    this.footer,
    this.footerLabel,
    this.footerIcon = Icons.check_circle_outline_rounded,
    this.onFooterTap,
    super.key,
  });

  final String title;
  final Widget body;
  final double width;

  /// 自定义底部；若为空且 [footerLabel] 有值，则用渐变主按钮。
  final Widget? footer;
  final String? footerLabel;
  final IconData footerIcon;
  final VoidCallback? onFooterTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hasFooter = footer != null || (footerLabel != null && footerLabel!.isNotEmpty);
    final bottomPad = ui(20) + (hasFooter ? ui(48) + ui(12) : 0) + bottomInset;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: ui(width),
        height: double.infinity,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartCampusDrawerTitleBar(title: title),
                  SizedBox(height: ui(20)),
                  Container(height: 1, color: const Color(0xFFF3F2F3)),
                  SizedBox(height: ui(16)),
                  Expanded(child: body),
                ],
              ),
            ),
            if (hasFooter)
              Positioned(
                left: ui(20),
                right: ui(20),
                bottom: ui(20) + bottomInset,
                child: footer ??
                    SmartCampusDrawerGradientButton(
                      icon: footerIcon,
                      label: footerLabel!,
                      onTap: onFooterTap,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉标题：3.25×14.85 品牌紫竖条 + 16/600 标题。
///
/// 对应 R `teacher_homework_review_view.dart` 4324–4356。
class SmartCampusDrawerTitleBar extends StatelessWidget {
  const SmartCampusDrawerTitleBar({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(4)),
        Text(
          title,
          style: TextStyle(
            fontSize: ui(16),
            color: const Color(0xFF0B081A),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// 抽屉底部主按钮：高 48、圆角 12、品牌紫渐变。
///
/// 对应 R `teacher_homework_review_view.dart` 4512–4558；
/// 原版 `#B68EFF → #8640FF` 换成品牌紫系 `#9585FF → #715EFE`。
class SmartCampusDrawerGradientButton extends StatelessWidget {
  const SmartCampusDrawerGradientButton({
    required this.label,
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: ui(48),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFF9585FF), Color(0xFF715EFE)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: ui(16), color: Colors.white),
              SizedBox(width: ui(8)),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
