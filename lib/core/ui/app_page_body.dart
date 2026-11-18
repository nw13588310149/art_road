import 'package:flutter/widgets.dart';

import 'app_spacing.dart';

/// 新页面的内容区：在外壳给的白色底板上留出统一的边距，内容上下滚动。
///
/// 内容区宽度不小于 [wideBreakpoint] 算宽屏（1180×820 下约 970），否则是窄屏
/// （1024×768 下约 814）。[builder] 拿到这个判断，用来决定列数和栏宽。
/// 规范见 `docs/新页面设计语言.md`。
///
/// 三种用法：
/// - 默认：整页一起滚动；
/// - `scrollable: false`：只留边距，页面自己管高度（画布加面板、固定页头的长列表）；
/// - [AppPageBody.slivers]：需要下拉刷新、分页加载时，给出一组 sliver，
///   这里按同样的边距排好。
class AppPageBody extends StatelessWidget {
  const AppPageBody({
    required Widget Function(BuildContext context, bool wide) this.builder,
    this.scrollable = true,
    this.controller,
    super.key,
  }) : sliverBuilder = null,
       physics = null;

  /// 用 sliver 搭的整页滚动。每个 sliver 都加上左右边距；第一个之前留 [top]。
  const AppPageBody.slivers({
    required List<Widget> Function(BuildContext context, bool wide) slivers,
    this.controller,
    this.physics,
    super.key,
  }) : builder = null,
       sliverBuilder = slivers,
       scrollable = true;

  final Widget Function(BuildContext context, bool wide)? builder;
  final List<Widget> Function(BuildContext context, bool wide)? sliverBuilder;

  /// 页面自己管理滚动（长列表、分页加载）时设为 false，这里只留边距。
  final bool scrollable;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  static const double wideBreakpoint = 900;

  /// 页头上方的留白。
  static const double top = AppSpace.s20;

  /// 页面底部的留白。
  static const double bottom = AppSpace.s32;

  /// 按内容区宽度判断宽窄。
  static bool isWide(double width) => width >= wideBreakpoint;

  /// 左右边距：宽屏 32，窄屏 24。
  static double gutter(bool wide) => wide ? AppSpace.s32 : AppSpace.s24;

  /// 主栏和侧栏之间的距离：宽屏 48，窄屏 32。
  static double columnGap(bool wide) => wide ? 48 : AppSpace.s32;

  /// 侧栏宽度：宽屏 280，窄屏 232。
  static double sideWidth(bool wide) => wide ? 280 : 232;

  /// 图片网格的间距：宽屏 28，窄屏 24。
  static double tileGap(bool wide) => wide ? 28 : AppSpace.s24;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = isWide(box.maxWidth);
        final side = gutter(wide);
        final slivers = sliverBuilder;
        if (slivers != null) {
          return CustomScrollView(
            controller: controller,
            physics: physics,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: top)),
              for (final sliver in slivers(context, wide))
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  sliver: sliver,
                ),
              const SliverToBoxAdapter(child: SizedBox(height: bottom)),
            ],
          );
        }
        final child = builder!(context, wide);
        if (!scrollable) {
          return Padding(
            padding: EdgeInsets.fromLTRB(side, top, side, 0),
            child: child,
          );
        }
        return SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(side, top, side, bottom),
          child: child,
        );
      },
    );
  }
}
