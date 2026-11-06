import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../../features/shell/ui/shell_layout.dart';
import 'cloud_folder_more_menu_button.dart';

/// 文件夹卡片底图（yp8 有内容 / yp9 空）与右上角 ⋯ 热区比例定位。
///
/// 菜单位置按卡片尺寸百分比计算，避免网格列数变化（5 列 → 4 列）后
/// 固定像素定位导致 ⋯ 溢出文件夹区域。
class CloudFolderCardArtwork extends StatelessWidget {
  const CloudFolderCardArtwork({
    super.key,
    required this.hasContent,
    this.isCreateShortcut = false,
    this.menuTriggerKey,
    this.onMenuTap,
  });

  final bool hasContent;
  final bool isCreateShortcut;
  final GlobalKey? menuTriggerKey;
  final VoidCallback? onMenuTap;

  /// 文件夹底图设计宽高比（160 × 130）。
  static const double artworkAspectRatio = 162 / 132;

  /// 底图与标题之间的间距。
  static const double titleGap = 10;

  /// 标题单行区域高度（fontSize 13，line height 16/13，留足英文降部）。
  static const double titleAreaHeight = 18;

  /// 子像素取整余量，避免 Grid 单元高度与 Column 子项合计差 ~1px 溢出。
  static const double gridLayoutSlack = 1;

  /// 网格单元宽高比：底图 + 间距 + 标题 + 取整余量。
  static const double gridChildAspectRatio =
      160 / (130 + titleGap + titleAreaHeight + gridLayoutSlack);

  /// 左下角日期/大小相对底图左缘的内边距。
  static const double metaLeftInset = 20;

  /// 左下角第一行（日期），与左侧目录副标题「已存储 X 个」一致。
  static const Color metaDateColor = Color(0xFF7F7F7F);

  /// 左下角第二行（大小），应用主色。
  static const Color metaSizeColor = Color(0xFF8741FF);

  /// 左下角第二行（大小）距底图底缘的内边距（原 8，上移 4 → 12）。
  static const double metaSizeBottomInset = 12;

  /// ⋯ 相对文件夹底图的位置（对齐 yp8/yp9 上印刷的三点）。
  static const double menuTopFactor = 0.43;
  static const double menuRightFactor = 0.07;

  static String backgroundAsset({
    required bool hasContent,
    bool isCreateShortcut = false,
  }) {
    if (isCreateShortcut || !hasContent) {
      return AppAssets.cloudFolderEmptyBg;
    }
    return AppAssets.cloudFolderFilledBg;
  }

  /// ⋯ 在比例定位基础上的微调（逻辑像素，经 ui 缩放）。
  static const double menuTopOffset = -5;
  static const double menuRightOffset = -10;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final asset = backgroundAsset(
      hasContent: hasContent,
      isCreateShortcut: isCreateShortcut,
    );
    final showMenu =
        !isCreateShortcut && onMenuTap != null && menuTriggerKey != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            if (showMenu)
              Positioned(
                top: constraints.maxHeight * menuTopFactor + ui(menuTopOffset),
                right:
                    constraints.maxWidth * menuRightFactor + ui(menuRightOffset),
                child: CloudFolderMoreMenuButton(
                  key: menuTriggerKey,
                  onTap: onMenuTap!,
                  iconOpacity: 0,
                ),
              ),
          ],
        );
      },
    );
  }
}
