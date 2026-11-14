import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/app_pressable.dart';
import '../../../../core/ui/app_segmented.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../shell/ui/shell_layout.dart';
import 'smart_campus_dark_tabs.dart';

/// 作品等页面独立的白色状态页签，选中项黑底白字。
///
/// 外观委托 [SmartCampusDarkTabs]（原版黑底页签，无描边版本）；保留旧签名，
/// 已有页面无需改动调用。
class SmartCampusStatusTabs<T> extends StatelessWidget {
  const SmartCampusStatusTabs({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SmartCampusDarkTabs<T>(
        segments: segments,
        value: value,
        onChanged: onChanged,
        bordered: false,
      ),
    );
  }
}

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

/// 原版二级页横幅：高 62、圆角 16、`xiaoquan/bg.png` 底图；左侧 32×32 白底
/// 返回，居中标题 16/600 + 12 号 `#B6B5BB` 副标题，右侧放 [actions]
/// （一般是 [SmartCampusBannerButton]，间距 8）。
///
/// 对应 R `features/smart_campus/ui/admin_teacher_management_view.dart`
/// 613–688（`_Banner`）；右侧按钮区对应 `admin_class_management_view.dart`
/// 1555–1574。各页原先各写一份，这里统一。
///
/// 放进 [SmartCampusSecondaryPageShell.header] 时壳层不再额外铺底图。
class SmartCampusPageBanner extends StatelessWidget {
  const SmartCampusPageBanner({
    required this.title,
    this.subtitle = '',
    this.onBack,
    this.actions = const [],
    this.titleHorizontalInset = 56,
    super.key,
  });

  final String title;

  /// 副标题；为空时只显示居中标题。
  final String subtitle;

  /// 为 null 时不显示返回按钮。
  final VoidCallback? onBack;

  /// 右侧操作，距右 12、距顶 14（按钮高 33 时垂直居中）。
  final List<Widget> actions;

  /// 居中标题区左右留白，右侧按钮较宽时调大，避免长副标题压到按钮下面。
  final double titleHorizontalInset;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
        width: double.infinity,
        height: ui(62),
        decoration: smartCampusPageBannerDecoration(ui),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(titleHorizontalInset),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(16),
                            height: 1.2,
                            fontWeight: AppFont.w600,
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: ui(4)),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            height: 1.2,
                            color: const Color(0xFFB6B5BB),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (onBack != null)
              Positioned(
                left: ui(12),
                top: ui(15),
                child: AppPressable(
                  onTap: onBack,
                  semanticLabel: '返回',
                  child: Container(
                    width: ui(32),
                    height: ui(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(8)),
                      border: Border.all(
                        color: const Color(0xFFF3F2F3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      size: ui(20),
                      color: const Color(0xFF0B081A),
                    ),
                  ),
                ),
              ),
            if (actions.isNotEmpty)
              Positioned(
                right: ui(12),
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) SizedBox(width: ui(8)),
                        actions[i],
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
  }
}

/// 横幅右侧按钮：高 33、白底 `#F3F2F3` 描边、圆角 8；16 图标 + 12/600 文字。
///
/// 对应 R `teacher_homework_review_view.dart` 1084–1134（`_BannerActionButton`）。
class SmartCampusBannerButton extends StatelessWidget {
  const SmartCampusBannerButton({
    required this.label,
    required this.onTap,
    this.iconAsset,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;

  /// 原版图标资源（优先于 [icon]）。
  final String? iconAsset;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final asset = iconAsset;
    final iconData = icon;
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: ui(33),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (asset != null)
              AppAssetGraphic(
                asset,
                width: ui(16),
                height: ui(16),
                fit: BoxFit.contain,
              )
            else if (iconData != null)
              Icon(iconData, size: ui(16), color: const Color(0xFF0B081A)),
            if (asset != null || iconData != null) SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      child: Center(child: child),
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
/// [header] 为 [SmartCampusPageBanner] 时原样放置（横幅自带底图）；其它
/// header（尚未还原的页面传入的工具栏）外面补一层同款底图，最小高 62。
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
    this.headerMinHeight = 62,
    this.headerGap = 16,
    this.bodyBorderRadius = 16,
    this.bodyTopClipRadius,
    this.bodyScrollable = true,
  });

  final Widget header;
  final Widget body;
  final Color backgroundColor;

  /// 非 [SmartCampusPageBanner] 的 header 外层底图的最小高度。
  final double headerMinHeight;

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
    final banner = header is SmartCampusPageBanner
        ? header
        : Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: ui(headerMinHeight)),
            alignment: Alignment.center,
            decoration: smartCampusPageBannerDecoration(ui),
            child: header,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        banner,
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
              child: bodyScrollable ? SingleChildScrollView(child: body) : body,
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
