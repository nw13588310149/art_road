import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

/// 智慧校园原版空状态。优先用该页面的插图，紧凑列表沿用小尺寸。
class SmartCampusEmptyState extends StatelessWidget {
  const SmartCampusEmptyState({
    super.key,
    required this.title,
    this.subtitle = '',
    this.illustration,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.padding,
  });

  final String title;
  final String subtitle;
  final String? illustration;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final asset = illustration;
    final hasIllustration = asset != null && asset.isNotEmpty;
    final visualSize = compact ? 56.0 : (hasIllustration ? 160.0 : 72.0);
    final action = onAction;
    final label = actionLabel;
    return Center(
      child: SingleChildScrollView(
        padding: padding ?? EdgeInsets.symmetric(vertical: compact ? 24 : 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasIllustration)
              Image.asset(asset, width: visualSize, height: visualSize)
            else
              Container(
                width: visualSize,
                height: visualSize,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.brandTint, AppColors.brandWash],
                  ),
                ),
                child: Icon(
                  icon,
                  size: compact ? 26 : 34,
                  color: AppColors.brand,
                ),
              ),
            SizedBox(height: compact ? 10 : 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: compact ? AppText.body13 : AppText.body14Strong,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppText.caption12,
                ),
              ),
            ],
            if (label != null && action != null) ...[
              const SizedBox(height: 16),
              AppPressable(
                onTap: action,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: AppText.body13.copyWith(color: AppColors.brand),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
