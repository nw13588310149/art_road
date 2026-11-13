import 'package:flutter/material.dart';

import '../../../core/theme/app_font.dart';

/// 尚未开放的功能页：80 圆形色块图标、22 号功能名和「功能开发中」说明。
class _FeatureDefaultPage extends StatelessWidget {
  const _FeatureDefaultPage({
    required this.title,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: accentColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: AppFont.w600,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'PingFang SC',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '功能开发中，敬请期待',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class MockExamDefaultPage extends StatelessWidget {
  const MockExamDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '模拟考试',
    icon: Icons.assignment_outlined,
    accentColor: Color(0xFFFF7043),
  );
}

class CampDefaultPage extends StatelessWidget {
  const CampDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '题库',
    icon: Icons.quiz_outlined,
    accentColor: Color(0xFF1976D2),
  );
}

class ConsultationDefaultPage extends StatelessWidget {
  const ConsultationDefaultPage({super.key});

  @override
  Widget build(BuildContext context) => const _FeatureDefaultPage(
    title: '资讯',
    icon: Icons.article_outlined,
    accentColor: Color(0xFF039BE5),
  );
}
