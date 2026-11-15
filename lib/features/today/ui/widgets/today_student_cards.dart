import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/today_practice.dart';
import '../../state/today_board.dart';

/// 学生的「今日练习」：按老师点评里的高频问题和弱项科目给 1–3 条建议，
/// 点开直达对应的工具或范画。
class TodayPracticeCard extends StatelessWidget {
  const TodayPracticeCard({
    required this.practices,
    required this.onOpen,
    super.key,
  });

  final List<TodayPractice> practices;
  final ValueChanged<TodayTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: '今日练习',
      subtitle: '按老师点评里的高频问题安排',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < practices.length; i++)
            _PracticeRow(
              item: practices[i],
              divider: i < practices.length - 1,
              onTap: () => onOpen(
                TodayRouteTarget(practices[i].route, practices[i].arguments),
              ),
            ),
        ],
      ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({
    required this.item,
    required this.divider,
    required this.onTap,
  });

  final TodayPractice item;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subject = ArtSubject.tryParse(item.subject);
    final tag = item.tag;
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        decoration: divider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
              )
            : null,
        child: Row(
          children: [
            AppIconTile(
              icon: item.icon,
              size: 40,
              color: subject?.accent ?? AppColors.brand,
              background: subject?.accentSoft ?? AppColors.brandWash,
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body14Strong,
                        ),
                      ),
                      if (tag.isNotEmpty) ...[
                        const SizedBox(width: AppSpace.s8),
                        switch (item.source) {
                          TodayPracticeSource.problem => AppTag(
                            label: tag,
                            tone: AppTone.warning,
                          ),
                          TodayPracticeSource.weakSubject => AppTag.subject(
                            tag,
                          ),
                          TodayPracticeSource.basics => AppTag(label: tag),
                        },
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Text('去练习', style: AppText.body13.copyWith(color: AppColors.brand)),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.brand,
            ),
          ],
        ),
      ),
    );
  }
}

/// 学生的「最近点评」：最近一份点评完成的作品，分数和老师的一句话；
/// 点评里指出了问题时可以直接改画重交。
class TodayLatestReviewCard extends StatelessWidget {
  const TodayLatestReviewCard({
    required this.review,
    required this.onOpen,
    super.key,
  });

  final TodayLatestReview? review;
  final ValueChanged<TodayTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    final data = review;
    return AppCard(
      title: '最近点评',
      trailing: AppButton(
        label: '作品档案',
        variant: AppButtonVariant.text,
        size: AppButtonSize.sm,
        onTap: () => onOpen(const TodayRouteTarget(RoutePaths.artworks)),
      ),
      child: data == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Text(
                '还没有点评完成的作品。上传日常作品，老师点评后会显示在这里。',
                style: AppText.body13,
              ),
            )
          : _ReviewBody(review: data, onOpen: onOpen),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.review, required this.onOpen});

  final TodayLatestReview review;
  final ValueChanged<TodayTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    final score = review.score;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPressable(
          onTap: () => onOpen(
            TodayRouteTarget(RoutePaths.artworks, <String, dynamic>{
              'artworkId': review.artworkId,
            }),
          ),
          semanticLabel: '查看作品 ${review.title}',
          child: Row(
            children: [
              AppImage(
                src: review.coverUrl,
                width: 56,
                height: 56,
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
                    Row(
                      children: [
                        if (review.subject.isNotEmpty) ...[
                          AppTag.subject(review.subject),
                          const SizedBox(width: AppSpace.s8),
                        ],
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: formatScore(score),
                                style: AppText.number(
                                  size: 16,
                                  color: score == null
                                      ? AppColors.textTertiary
                                      : AppColors.brand,
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
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          Container(
            padding: const EdgeInsets.all(AppSpace.s12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: AppRadius.br12,
            ),
            child: Text.rich(
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (review.canRevise) ...[
          const SizedBox(height: AppSpace.s12),
          AppButton(
            label: '按点评改画重交',
            variant: AppButtonVariant.quiet,
            size: AppButtonSize.sm,
            expand: true,
            onTap: () => onOpen(
              TodayUploadTarget(
                parentId: review.artworkId,
                title: review.title,
                subject: review.subject,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
