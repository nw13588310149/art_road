import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';

/// 尚未开放的功能页：页头 + 「暂未开放」空状态，保持路由畅通。
class _FeatureDefaultPage extends StatelessWidget {
  const _FeatureDefaultPage({required this.title, required this.icon});

  final String title;
  final IconData icon;

  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(title: title, onBack: () => _back(context)),
        Expanded(
          child: AppEmptyState(
            icon: icon,
            title: '「$title」暂未开放',
            description: '功能整理中，开放后会在首页通知',
          ),
        ),
      ],
    );
  }
}

class MockExamDefaultPage extends StatelessWidget {
  const MockExamDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '模拟考试',
    icon: Icons.assignment_outlined,
  );
}

class CampDefaultPage extends StatelessWidget {
  const CampDefaultPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _FeatureDefaultPage(title: '题库', icon: Icons.quiz_outlined);
}

class ConsultationDefaultPage extends StatelessWidget {
  const ConsultationDefaultPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _FeatureDefaultPage(title: '资讯', icon: Icons.article_outlined);
}
