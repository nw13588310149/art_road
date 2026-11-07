import 'package:flutter/material.dart';

import '../art/art_subject.dart';
import '../ui/app_colors.dart';
import '../ui/app_pressable.dart';
import '../ui/app_spacing.dart';
import '../ui/app_text.dart';

/// 三科入口卡：范画封面 + 科目色遮罩 + 科目名称与要点。
///
/// 文字所在的左侧 70% 用接近实色的科目色铺底，要点小字不再压在图像细节上；
/// 右侧逐渐露出范画。
class ArtSubjectCard extends StatelessWidget {
  const ArtSubjectCard({
    required this.subject,
    required this.onTap,
    this.borderRadius = AppRadius.panel,
    super.key,
  });

  final ArtSubject subject;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
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
                    subject.accent.withValues(alpha: 0.96),
                    subject.accent.withValues(alpha: 0.9),
                    subject.accent.withValues(alpha: 0.3),
                  ],
                  stops: const [0, 0.7, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s8,
                AppSpace.s12,
                AppSpace.s8,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.label,
                    style: AppText.title20.copyWith(color: AppColors.onBrand),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subject.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12.copyWith(color: AppColors.onBrand),
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
