import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/ui/ui.dart';
import '../../state/home_staff_cards.dart';

/// 任课老师首页「作品点评」：待点评件数（`GET /school/teacher/artworks/statistics`），
/// 点开进入作品点评（默认显示待我点评）。
class HomeReviewQueueCard extends ConsumerWidget {
  const HomeReviewQueueCard({super.key});

  static const double _bodyHeight = 124;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).pushNamed(RoutePaths.artworks);
    if (context.mounted) {
      ref.invalidate(homeReviewStatsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeReviewStatsProvider);
    return AppCard(
      title: '作品点评',
      child: stats.when(
        loading: () => const SizedBox(
          height: _bodyHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 48, height: 14),
              SizedBox(height: AppSpace.s8),
              AppSkeleton(width: 96, height: 32),
              SizedBox(height: AppSpace.s8),
              AppSkeleton(width: 140, height: 14),
              Spacer(),
              AppSkeleton(height: AppSize.buttonSm, radius: AppRadius.control),
            ],
          ),
        ),
        error: (_, _) => SizedBox(
          height: _bodyHeight,
          child: AppErrorState(
            title: '点评统计加载失败',
            onRetry: () => ref.invalidate(homeReviewStatsProvider),
          ),
        ),
        data: (data) {
          final pending = data.pending;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('待点评', style: AppText.caption12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$pending',
                      style: AppText.displayNumber(
                        size: 32,
                        color: pending > 0 ? AppColors.brand : AppColors.ink,
                      ),
                    ),
                    TextSpan(text: ' 件', style: AppText.body13),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                '已点评 ${data.reviewed} 件 · 共 ${data.total} 件',
                style: AppText.caption12,
              ),
              const SizedBox(height: AppSpace.s16),
              AppButton(
                label: pending > 0 ? '开始点评' : '查看已点评',
                variant: pending > 0
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                expand: true,
                onTap: () => _open(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}
