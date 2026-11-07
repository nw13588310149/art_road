import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../state/home_student_cards.dart';

/// 学生首页「最近点评」：最近一份点评完成的作品，分数与老师的一句评语，点开进入作品详情。
class HomeLatestReviewCard extends ConsumerWidget {
  const HomeLatestReviewCard({super.key});

  static const double _bodyHeight = 160;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref, [
    String artworkId = '',
  ]) async {
    await Navigator.of(context).pushNamed(
      RoutePaths.artworks,
      arguments: artworkId.isEmpty
          ? null
          : <String, dynamic>{'artworkId': artworkId},
    );
    if (context.mounted) {
      ref.invalidate(homeLatestReviewProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(homeLatestReviewProvider);
    return AppCard(
      title: '最近点评',
      trailing: AppButton(
        label: '作品档案',
        variant: AppButtonVariant.text,
        size: AppButtonSize.sm,
        onTap: () => _open(context, ref),
      ),
      child: review.when(
        loading: () => const _ReviewSkeleton(),
        error: (_, _) => SizedBox(
          height: _bodyHeight,
          child: AppErrorState(
            title: '最近点评加载失败',
            description: '请检查网络后重试',
            onRetry: () => ref.invalidate(homeLatestReviewProvider),
          ),
        ),
        data: (data) => data == null
            ? const SizedBox(
                height: _bodyHeight,
                child: AppEmptyState(
                  icon: Icons.rate_review_outlined,
                  title: '还没有点评完成的作品',
                  description: '上传日常作业，老师点评后会显示在这里',
                ),
              )
            : _ReviewBody(
                review: data,
                onTap: () => _open(context, ref, data.artworkId),
              ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.review, required this.onTap});

  final HomeLatestReview review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = review.score;
    final date = review.drawingDate.length >= 10
        ? review.drawingDate.substring(0, 10)
        : review.drawingDate;
    return AppPressable(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppImage(
                src: review.coverUrl,
                width: 64,
                height: 64,
                borderRadius: AppRadius.br8,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      review.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong,
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Wrap(
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (review.subject.isNotEmpty)
                          AppTag.subject(review.subject),
                        if (date.isNotEmpty)
                          Text(date, style: AppText.caption12),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '最终得分  ', style: AppText.caption12),
                TextSpan(
                  text: formatScore(score),
                  style: AppText.number(
                    size: 24,
                    color: score == null ? AppColors.textTertiary : AppColors.brand,
                  ),
                ),
                if (score != null)
                  TextSpan(
                    text: ' / ${formatScore(review.maxScore)} 分',
                    style: AppText.caption12,
                  ),
              ],
            ),
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text.rich(
              TextSpan(
                children: [
                  if (review.teacherName.isNotEmpty)
                    TextSpan(
                      text: '${review.teacherName}：',
                      style: AppText.body13.copyWith(color: AppColors.ink),
                    ),
                  TextSpan(text: review.comment, style: AppText.body13),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: HomeLatestReviewCard._bodyHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeleton(width: 64, height: 64, radius: AppRadius.control),
              SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 120, height: 16),
                    SizedBox(height: AppSpace.s8),
                    AppSkeleton(width: 80, height: 22, radius: AppRadius.pill),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpace.s16),
          AppSkeleton(width: 96, height: 24),
          SizedBox(height: AppSpace.s12),
          AppSkeleton(height: 14),
        ],
      ),
    );
  }
}
