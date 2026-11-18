import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 新页面的细线：1 像素、最浅的线色。分区之间、列表行之间、并排的两栏之间都用它，
/// 代替卡片的边框。
class AppRule extends StatelessWidget {
  /// 横线，不占额外高度。
  const AppRule({super.key}) : _vertical = false, gap = 1;

  /// 竖线，放在等高的 Row 里；[gap] 是它连同两侧留白一共占的宽度。
  const AppRule.vertical({this.gap = 49, super.key}) : _vertical = true;

  final bool _vertical;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return _vertical
        ? VerticalDivider(width: gap, thickness: 1, color: AppColors.lineSoft)
        : const Divider(height: 1, thickness: 1, color: AppColors.lineSoft);
  }
}
