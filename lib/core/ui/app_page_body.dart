import 'package:flutter/widgets.dart';

import 'app_spacing.dart';

/// 新页面的内容区：在外壳给的白色底板上留出统一的边距，内容上下滚动。
///
/// 内容区宽度不小于 [wideBreakpoint] 算宽屏（1180×820 下约 970），否则是窄屏
/// （1024×768 下约 814）。[builder] 拿到这个判断，用来决定列数和栏宽。
/// 规范见 `docs/新页面设计语言.md`。
class AppPageBody extends StatelessWidget {
  const AppPageBody({
    required this.builder,
    this.scrollable = true,
    this.controller,
    super.key,
  });

  final Widget Function(BuildContext context, bool wide) builder;

  /// 页面自己管理滚动（长列表、分页加载）时设为 false，这里只留边距。
  final bool scrollable;
  final ScrollController? controller;

  static const double wideBreakpoint = 900;

  /// 页头上方的留白。
  static const double top = AppSpace.s20;

  /// 左右边距：宽屏 32，窄屏 24。
  static double gutter(bool wide) => wide ? AppSpace.s32 : AppSpace.s24;

  /// 主栏和侧栏之间的距离：宽屏 48，窄屏 32。
  static double columnGap(bool wide) => wide ? 48 : AppSpace.s32;

  /// 侧栏宽度：宽屏 280，窄屏 232。
  static double sideWidth(bool wide) => wide ? 280 : 232;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= wideBreakpoint;
        final side = gutter(wide);
        final child = builder(context, wide);
        if (!scrollable) {
          return Padding(
            padding: EdgeInsets.fromLTRB(side, top, side, 0),
            child: child,
          );
        }
        return SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(side, top, side, AppSpace.s32),
          child: child,
        );
      },
    );
  }
}
