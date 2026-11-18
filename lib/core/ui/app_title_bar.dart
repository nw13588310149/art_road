import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 新页面的页头：页面名称看得见，位置和字号在所有新页面里相同。
///
/// 从左到右是返回（[onBack]，详情页才有）、名称、视图切换（[tabs]）、一行说明
/// （[caption]），操作（[actions]）靠右。高 44。名称和导航或入口上的叫法一致；
/// 详情页的名称是对象的名字，太长时省略成一行。
///
/// 和 `AppPageHeader` 的区别：那个只把标题交给读屏，不画出来，保留页面在用。
class AppTitleBar extends StatelessWidget {
  const AppTitleBar({
    required this.title,
    this.caption = '',
    this.tabs,
    this.actions = const <Widget>[],
    this.onBack,
    this.backLabel = '返回',
    super.key,
  });

  final String title;
  final String caption;

  /// 视图切换，通常是 `AppViewTabs`。
  final Widget? tabs;

  /// 靠右的操作：最多一个主按钮，其余用 `AppPlainButton`。
  final List<Widget> actions;

  /// 不为空时在名称左边放一个返回按钮（点击区域 44 见方）。
  final VoidCallback? onBack;

  /// 返回按钮的读屏名称和悬停提示。
  final String backLabel;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (back != null) ...[
            AppBackButton(onTap: back, semanticLabel: backLabel),
            const SizedBox(width: AppSpace.s4),
          ],
          // 名称、切换和说明占去操作以外的宽度；名称和说明都放不下时各让一半。
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title20,
                    ),
                  ),
                ),
                if (tabs != null) ...[
                  const SizedBox(width: AppSpace.s32),
                  tabs!,
                ],
                if (caption.isNotEmpty) ...[
                  const SizedBox(width: AppSpace.s12),
                  Flexible(
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// 新页面的返回按钮：只有一个墨色箭头，没有底色，点击区域 44 见方。
///
/// 箭头和左边缘对齐（点击区域向右延伸），所以放在页头最左边时，箭头和下面的
/// 内容在同一条对齐线上。
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    required this.onTap,
    this.semanticLabel = '返回',
    this.color = AppColors.ink,
    super.key,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final Color color;

  static const double extent = 44;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        child: SizedBox(
          width: extent,
          height: extent,
          child: Align(
            alignment: const Alignment(-0.9, 0),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// 只有图标的次要操作（收藏、全屏、更多）：没有底色，点击区域 44 见方。
///
/// [semanticLabel] 同时是读屏名称和悬停提示。[active] 为 true 时图标用
/// [activeColor]，默认品牌紫（例如详情页里已收藏），一屏里算一处品牌紫。列表里
/// 每行都可能处于已收藏时传 `activeColor: AppColors.ink`，靠实心图标表示状态。
class AppIconAction extends StatelessWidget {
  const AppIconAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.active = false,
    this.activeIcon,
    this.size = 20,
    this.color = AppColors.textSecondary,
    this.activeColor = AppColors.brand,
    super.key,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool active;
  final double size;
  final Color color;
  final Color activeColor;

  static const double extent = 44;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onTap,
        enabled: onTap != null,
        semanticLabel: semanticLabel,
        toggled: activeIcon == null ? null : active,
        child: SizedBox(
          width: extent,
          height: extent,
          child: Center(
            child: Icon(
              active ? (activeIcon ?? icon) : icon,
              size: size,
              color: active ? activeColor : color,
            ),
          ),
        ),
      ),
    );
  }
}
