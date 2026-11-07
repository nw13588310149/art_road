import 'package:flutter/material.dart';

import '../art/art_subject.dart';
import '../ui/app_colors.dart';
import '../ui/app_pressable.dart';
import '../ui/app_spacing.dart';
import '../ui/app_text.dart';

/// 首页科目入口：浅色底图、左上标题和右下范画缩略图。
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
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    AppColors.tint(subject.accent, 0.28),
                    subject.accentSoft,
                  ],
                ),
              ),
            ),
            Positioned(
              right: AppSpace.s12,
              bottom: AppSpace.s12,
              width: 64,
              height: 56,
              child: ClipRRect(
                borderRadius: AppRadius.br8,
                child: Image.asset(
                  subject.coverAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            Positioned(
              top: AppSpace.s12,
              left: AppSpace.s16,
              child: Text(subject.label, style: AppText.title16),
            ),
          ],
        ),
      ),
    );
  }
}
