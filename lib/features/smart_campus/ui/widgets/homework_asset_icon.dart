import 'package:flutter/material.dart';

import '../../../../core/widgets/app_asset_graphic.dart';

/// 作业相关 PNG 图标带内边距，用 [BoxFit.cover] 铺满指定容器。
class HomeworkAssetIcon extends StatelessWidget {
  const HomeworkAssetIcon(
    this.asset, {
    required this.size,
    this.colorFilter,
    super.key,
  }) : expand = false;

  const HomeworkAssetIcon.expand(
    this.asset, {
    this.colorFilter,
    super.key,
  })  : size = null,
        expand = true;

  final String asset;
  final double? size;
  final ColorFilter? colorFilter;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    if (expand) {
      return SizedBox.expand(
        child: AppAssetGraphic(
          asset,
          fit: BoxFit.cover,
          colorFilter: colorFilter,
        ),
      );
    }
    final side = size!;
    return SizedBox(
      width: side,
      height: side,
      child: AppAssetGraphic(
        asset,
        width: side,
        height: side,
        fit: BoxFit.cover,
        colorFilter: colorFilter,
      ),
    );
  }
}
