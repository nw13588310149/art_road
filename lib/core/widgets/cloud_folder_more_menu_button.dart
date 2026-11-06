import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../../features/shell/ui/shell_layout.dart';

/// 云盘 / 录音等「文件夹卡片」右上角的 ⋯ 菜单按钮。
///
/// 使用 [AppAssets.cloudActionMore]（yp2.png）并按 [BoxFit.contain] 绘制，
/// 避免把图标塞进非等比例容器里被拉伸变形。
class CloudFolderMoreMenuButton extends StatelessWidget {
  const CloudFolderMoreMenuButton({
    super.key,
    required this.onTap,
    this.iconLogicalSize = 20,
    this.hitLogicalExtent = 34,
    this.iconOpacity = 1,
  });

  final VoidCallback onTap;

  /// 图标显示尺寸（逻辑像素，经 [DashboardScaleScope.ui] 缩放）。
  final double iconLogicalSize;

  /// 点击热区边长（逻辑像素）。
  final double hitLogicalExtent;

  /// 图标透明度；文件夹卡片可设为 0，仅保留底图上的 ⋯ 与点击热区。
  final double iconOpacity;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final icon = ui(iconLogicalSize);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: ui(hitLogicalExtent),
        height: ui(hitLogicalExtent),
        child: Center(
          child: Opacity(
            opacity: iconOpacity.clamp(0, 1),
            child: Image.asset(
              AppAssets.cloudActionMore,
              width: icon,
              height: icon,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
