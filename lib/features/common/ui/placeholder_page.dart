import 'package:flutter/material.dart';

/// 外壳之外的占位页：原版标题栏 + 居中说明，不向用户展示路由路径。
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('「$title」暂未开放', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text('该功能正在整理中，可以先返回继续使用其他功能'),
            ],
          ),
        ),
      ),
    );
  }
}
