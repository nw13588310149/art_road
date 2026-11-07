import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// 外壳之外的占位页：页头 + 「暂未开放」空状态，不向用户展示路由路径。
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.routeName,
    required this.title,
    super.key,
  });

  final String routeName;
  final String title;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: title,
              onBack: navigator.canPop() ? navigator.pop : null,
            ),
            Expanded(
              child: AppEmptyState(
                icon: Icons.construction_outlined,
                title: '「$title」暂未开放',
                description: '该功能正在整理中，可以先返回继续使用其他功能',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
