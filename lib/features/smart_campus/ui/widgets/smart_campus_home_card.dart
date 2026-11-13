import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';

/// 智慧校园各端首页统一白底圆角容器（16px + 抗锯齿裁剪）。
class SmartCampusHomeCard extends StatelessWidget {
  const SmartCampusHomeCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.color = Colors.white,
    this.radius = ShellLayoutSpec.panelRadius,
    this.boxShadow,
    this.clipContent = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color color;
  final double radius;
  final List<BoxShadow>? boxShadow;

  /// 为 `false` 时不裁剪子组件（快捷入口角标等需溢出绘制时使用）。
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final borderRadius = BorderRadius.circular(ui(radius));

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
        color: clipContent ? null : color,
      ),
      child: clipContent
          ? ClipRRect(
              borderRadius: borderRadius,
              child: ColoredBox(
                color: color,
                child: padding == null
                    ? child
                    : Padding(padding: padding!, child: child),
              ),
            )
          : Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
    );
  }
}
