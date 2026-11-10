import 'package:flutter/material.dart';

import 'app_card.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// 云盘与笔记共用的双栏版式。分类栏与主内容位于同一白色面板内。
class AppSplitPanel extends StatelessWidget {
  const AppSplitPanel({required this.sidebar, required this.child, super.key});

  final Widget sidebar;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    bordered: false,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 180, child: sidebar),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: AppColors.lineSoft,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: child,
          ),
        ),
      ],
    ),
  );
}
