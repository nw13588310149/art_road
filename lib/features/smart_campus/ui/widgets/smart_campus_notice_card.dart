import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';

/// 班级通知预览。学生可打开正文，班主任可在同一版式上撤回通知。
class SmartCampusNoticeCard extends StatelessWidget {
  const SmartCampusNoticeCard({
    required this.title,
    required this.content,
    required this.date,
    this.onTap,
    this.action,
    super.key,
  });

  final String title;
  final String content;
  final String date;
  final VoidCallback? onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(AppSpace.s8),
      decoration: const BoxDecoration(
        color: AppColors.brandWash,
        borderRadius: AppRadius.br8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 12,
                height: 20,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: AppSpace.s8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.isNotEmpty ? title : content,
                  style: AppText.body13.copyWith(
                    color: AppColors.ink,
                    fontWeight: AppFont.w500,
                  ),
                ),
              ),
              if (action case final control?) ...[
                const SizedBox(width: AppSpace.s4),
                control,
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty && content.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12.copyWith(
                      color: AppColors.textSecondary,
                      height: 16 / 12,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.s4),
                Text(
                  date,
                  style: AppText.caption12.copyWith(
                    color: AppColors.textSecondary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return onTap == null ? card : AppPressable(onTap: onTap, child: card);
  }
}
