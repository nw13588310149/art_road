import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';

/// 智慧校园二级页统一顶栏背景（与请假审批页 [AppAssets.xiaoquanHeaderBg] 一致）。
BoxDecoration smartCampusPageBannerDecoration(
  double Function(double) ui, {
  double borderRadius = 16,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(ui(borderRadius)),
    // 底图右缘曾带 1px 深色竖线；先铺渐变再 cover，避免拉伸后右侧露线。
    gradient: const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, Color(0xFFF9EDFF)],
    ),
    image: const DecorationImage(
      image: AssetImage(AppAssets.xiaoquanHeaderBg),
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
    ),
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
        // 底图 [authBgTop] 顶部圆角带透明像素；先铺渐变再 cover，避免拉伸后右上角露白。
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Color(0xFFF9EDFF)],
        ),
        image: const DecorationImage(
          image: AssetImage(AppAssets.authBgTop),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
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
    this.backgroundColor = const Color(0xFFEFF3FC),
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

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final topClipRadius = ui(bodyTopClipRadius ?? bodyBorderRadius);
    final bottomClipRadius = ui(bodyBorderRadius);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(height: ui(headerGap)),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(ui(bodyBorderRadius)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(topClipRadius),
                topRight: Radius.circular(topClipRadius),
                bottomLeft: Radius.circular(bottomClipRadius),
                bottomRight: Radius.circular(bottomClipRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: bodyScrollable
                  ? SingleChildScrollView(child: body)
                  : body,
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
    this.backgroundColor = Colors.white,
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
