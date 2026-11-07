import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';

/// 智慧校园二级页统一顶栏背景（与请假审批页 [AppAssets.xiaoquanHeaderBg] 一致）。
BoxDecoration smartCampusPageBannerDecoration(
  double Function(double) ui, {
  double borderRadius = 16,
}) {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(ui(borderRadius)),
    border: Border.all(color: AppColors.lineSoft),
  );
}

/// 课表页顶栏壳层：固定 [AppAssets.authBgTop] 背景图 + 仅顶部圆角裁剪。
class SmartCampusScheduleTopBar extends StatelessWidget {
  const SmartCampusScheduleTopBar({
    super.key,
    required this.child,
    this.height = 68,
    this.borderRadius = 16,
  });

  final Widget child;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(height),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(borderRadius)),
          topRight: Radius.circular(ui(borderRadius)),
        ),
        color: AppColors.surface,
      ),
      child: child,
    );
  }
}

/// 学生端二级页通用壳层：
///
/// 顶部 [header]（标题 + 返回栏）固定浮在灰底上，**不随内容滚动**；与下方
/// 主内容容器之间留 [headerGap] 间距（即「容器到顶部标题栏有间距」）。
/// 主内容容器填满剩余高度并以 16 圆角裁切滚动内容；容器内部 **不再叠加**
/// 任何底部 padding —— 滚动到底时由外层 dashboard 的 16px contentPadding
/// 提供唯一、稳定的底部留白，避免「容器外下边距」忽大忽小。
///
/// 与 [SmartCampusSchedulePageShell]（banner 与内容同处一张白卡、banner
/// 平贴顶部）的区别：本壳层让 banner 独立浮起、内容容器单独裁切，更贴合
/// 学生端 `xiaoquanHeaderBg` 浮起式 banner 的视觉。
class SmartCampusSecondaryPageShell extends StatelessWidget {
  const SmartCampusSecondaryPageShell({
    super.key,
    required this.header,
    required this.body,
    this.backgroundColor = AppColors.page,
    this.headerGap = 16,
    this.bodyBorderRadius = 16,
    this.bodyTopClipRadius,
    this.bodyScrollable = true,
  });

  final Widget header;
  final Widget body;
  final Color backgroundColor;

  /// banner 与主内容容器之间的固定间距。
  final double headerGap;

  /// 主内容滚动容器的四角圆角（设计稿默认 16；贴边子卡为 8 时可下调以避免裁切冲突）。
  final double bodyBorderRadius;

  /// Optional top clip radius for edge-to-edge children that own their corners.
  /// This changes only clipping and never inserts layout padding.
  final double? bodyTopClipRadius;

  /// 为 `true` 时 [body] 自动包进无底部 padding 的 [SingleChildScrollView]；
  /// 为 `false` 时由调用方自行提供滚动（如下拉刷新场景）。
  final bool bodyScrollable;

  /// 页头用 [AppPageHeader]（自带左右 20 版心与底部 12 留白），主体与页头左右对齐，
  /// 卡片直接落在页面底色上；[headerGap]、[bodyBorderRadius]、[bodyTopClipRadius]
  /// 为旧参数，保留以兼容调用方。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: AppSpace.s4),
        Expanded(
          child: ColoredBox(
            color: backgroundColor,
            child: bodyScrollable
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      0,
                      AppSpace.page,
                      AppSpace.page,
                    ),
                    child: body,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      0,
                      AppSpace.page,
                      AppSpace.page,
                    ),
                    child: body,
                  ),
          ),
        ),
      ],
    );
  }
}

/// 课表页外层白卡：圆角固定不随内容滚动，内部仅 [body] 区域滚动。
class SmartCampusSchedulePageShell extends StatelessWidget {
  const SmartCampusSchedulePageShell({
    super.key,
    required this.header,
    required this.body,
    this.backgroundColor = AppColors.surface,
    this.bodyScrollable = true,
  });

  final Widget header;
  final Widget body;
  final Color backgroundColor;

  /// 为 `false` 时 [body] 占满剩余高度，由内部（如课表网格）自行处理纵向滚动。
  final bool bodyScrollable;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (bodyScrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: ui(20)),
                child: body,
              ),
            )
          else
            Expanded(child: body),
        ],
      ),
    );
  }
}
