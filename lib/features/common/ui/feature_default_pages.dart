import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// 尚未开放的功能页：居中图标、功能名和状态说明。
class _FeatureDefaultPage extends StatelessWidget {
  const _FeatureDefaultPage({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.brand),
          ),
          const SizedBox(height: AppSpace.s20),
          Text(title, style: AppText.title20),
          const SizedBox(height: AppSpace.s8),
          Text(
            '功能整理中，开放后会在首页通知',
            style: AppText.body14.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class MockExamDefaultPage extends StatelessWidget {
  const MockExamDefaultPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _FeatureDefaultPage(title: '模拟考试', icon: Icons.assignment_outlined);
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
