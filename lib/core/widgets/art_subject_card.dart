import 'package:flutter/material.dart';

import '../art/art_subject.dart';
import '../theme/app_font.dart';

/// 三科入口卡：范画封面 + 科目色渐变 + 科目名称与要点。
class ArtSubjectCard extends StatelessWidget {
  const ArtSubjectCard({
    required this.subject,
    required this.onTap,
    this.borderRadius = 16,
    super.key,
  });

  final ArtSubject subject;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              subject.coverAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    subject.accent.withValues(alpha: 0.92),
                    subject.accent.withValues(alpha: 0.55),
                    subject.accent.withValues(alpha: 0.05),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.label,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.1,
                      color: Colors.white,
                      fontWeight: AppFont.w600,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subject.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: Color(0xE6FFFFFF),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
