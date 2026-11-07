import 'package:flutter/material.dart';

import 'app_badge.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// 功能入口图标：浅色圆角方块 + 线性图标（扁平双色），可带红色计数角标。
///
/// 首页九宫格、智慧校园快捷入口这类「图标 + 名称」入口共用，保证各处图标同一风格；
/// 默认品牌浅底 + 品牌紫图标。点击由外层 [AppPressable] 负责，本身不响应点击。
class AppIconTile extends StatelessWidget {
  const AppIconTile({
    required this.icon,
    this.size = 44,
    this.color = AppColors.brand,
    this.background = AppColors.brandWash,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;

  /// 方块边长；图标为边长的一半。
  final double size;
  final Color color;
  final Color background;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: size >= 40 ? AppRadius.br12 : AppRadius.br8,
      ),
      child: Icon(icon, size: size / 2, color: color),
    );
    if (badgeCount <= 0) {
      return tile;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(top: -6, right: -6, child: AppBadge(count: badgeCount)),
      ],
    );
  }
}
