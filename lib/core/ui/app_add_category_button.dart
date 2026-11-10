import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../widgets/app_asset_graphic.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 云盘和笔记左栏底部的分类入口。
class AppAddCategoryButton extends StatelessWidget {
  const AppAddCategoryButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppAssetGraphic(AppAssets.addCategory, width: 18, height: 18),
            const SizedBox(height: AppSpace.s4),
            Text('新建分类', style: AppText.body13),
          ],
        ),
      ),
    );
  }
}
