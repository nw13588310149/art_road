import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/artwork_models.dart';
import '../../data/artwork_rules.dart';

/// 点评状态：待点评（提醒色）/ 已点评（成功色），浅底深字。
class ArtworkStatusTag extends StatelessWidget {
  const ArtworkStatusTag({required this.done, super.key});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return AppTag(
      label: done ? '已点评' : '待点评',
      tone: done ? AppTone.success : AppTone.warning,
    );
  }
}

/// 组长复核状态：待复核（提醒色）/ 已复核（成功色）/ 已退回（危险色）/ 等老师点评。
/// 不需要复核的作品不显示。
class ArtworkLeadStatusTag extends StatelessWidget {
  const ArtworkLeadStatusTag({required this.status, super.key});

  /// `NONE / WAITING / PENDING / APPROVED / RETURNED`。
  final String status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'PENDING' => const AppTag(label: '待复核', tone: AppTone.warning),
      'APPROVED' => const AppTag(label: '已复核', tone: AppTone.success),
      'RETURNED' => const AppTag(label: '已退回', tone: AppTone.danger),
      'WAITING' => const AppTag(label: '等老师点评'),
      _ => const SizedBox.shrink(),
    };
  }
}

/// 组长复核卡片：通过时是组长点评（可带改定分数、范例标记），退回时是退回原因。
/// [showAttention] 只在教职端打开，学生端不显示「需关注」。
class ArtworkLeadReviewCard extends StatelessWidget {
  const ArtworkLeadReviewCard({
    required this.review,
    this.showAttention = false,
    this.maxScore = 100,
    super.key,
  });

  final ArtworkLeadReview review;
  final bool showAttention;
  final double maxScore;

  @override
  Widget build(BuildContext context) {
    final time = review.reviewedTime.isEmpty
        ? ''
        : ArtworkRules.shortTime(review.reviewedTime);
    final score = review.score;
    final name = review.leaderName.isEmpty ? '组长' : review.leaderName;
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: name, size: 32),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name老师 · 科目组长',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong,
                    ),
                    if (time.isNotEmpty)
                      Text(
                        '${review.approved ? '复核于' : '退回于'} $time',
                        style: AppText.caption12,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              if (review.approved && score != null)
                ArtworkScore(score: score, maxScore: maxScore)
              else
                AppTag(
                  label: review.approved ? '复核通过' : '退回重评',
                  tone: review.approved ? AppTone.success : AppTone.danger,
                ),
            ],
          ),
          if (review.exemplar ||
              (showAttention && review.attention) ||
              (review.approved && score != null)) ...[
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                if (review.approved && score != null)
                  const AppTag(label: '组长改定分数', tone: AppTone.brand),
                if (review.exemplar)
                  const AppTag(label: '范例', tone: AppTone.success),
                if (showAttention && review.attention)
                  const AppTag(label: '该生需关注', tone: AppTone.warning),
              ],
            ),
          ],
          if (review.content.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text(review.content, style: AppText.body14),
          ],
        ],
      ),
    );
  }
}

/// 科目标签：三科用科目色，自定义科目用品牌紫。
class ArtworkSubjectTag extends StatelessWidget {
  const ArtworkSubjectTag({required this.subject, super.key});

  final String subject;

  @override
  Widget build(BuildContext context) =>
      AppTag.subject(subject.isEmpty ? '作品' : subject);
}

/// 只读点评标签：问题用提醒色、亮点用成功色，可带次数与解释。
class ArtworkReviewTag extends StatelessWidget {
  const ArtworkReviewTag({
    required this.name,
    required this.color,
    this.positive = false,
    this.count,
    this.tooltip = '',
    super.key,
  });

  final String name;

  /// 标签的 `#HEX`，用于区分问题与亮点。
  final String color;
  final bool positive;
  final int? count;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final highlight = ArtworkRules.isHighlightTag(color, positive: positive);
    final times = count;
    final Widget tag = AppTag(
      label: times == null ? name : '$name $times 次',
      tone: highlight ? AppTone.success : AppTone.warning,
    );
    if (tooltip.isEmpty) {
      return tag;
    }
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      child: tag,
    );
  }
}

/// 分数「88 / 100」；未打分显示「未评分」。
class ArtworkScore extends StatelessWidget {
  const ArtworkScore({
    required this.score,
    required this.maxScore,
    this.size = 20,
    this.color = AppColors.ink,
    super.key,
  });

  final double? score;
  final double maxScore;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = score;
    if (value == null) {
      return Text('未评分', style: AppText.caption12);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: ArtworkRules.displayScore(value),
            style: AppText.number(size: size, color: color),
          ),
          TextSpan(
            text: ' / ${ArtworkRules.displayScore(maxScore)}',
            style: AppText.caption12,
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}

/// 封面上的张数角标。
class ArtworkImageCountTag extends StatelessWidget {
  const ArtworkImageCountTag({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) =>
      AppTag(label: '$count 张', icon: Icons.photo_library_outlined);
}

/// 作品缩略图条，选中项品牌紫描边，切换立即生效。
class ArtworkThumbnailStrip extends StatelessWidget {
  const ArtworkThumbnailStrip({
    required this.images,
    required this.selectedIndex,
    required this.onSelect,
    this.size = 56,
    super.key,
  });

  final List<ArtworkImage> images;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return AppPressable(
            onTap: () => onSelect(index),
            selected: selected,
            semanticLabel: '第 ${index + 1} 张',
            child: Container(
              width: size,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: AppRadius.br8,
                border: Border.all(
                  color: selected ? AppColors.brand : AppColors.lineSoft,
                  width: 2,
                ),
              ),
              child: AppImage(
                src: images[index].url,
                borderRadius: AppRadius.br4,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 一位老师的点评：头像、时间、分数、标签、评语。
class ArtworkReviewCard extends StatelessWidget {
  const ArtworkReviewCard({required this.review, super.key});

  final ArtworkReview review;

  @override
  Widget build(BuildContext context) {
    final time = review.reviewedTime.isEmpty
        ? ''
        : ArtworkRules.shortTime(review.reviewedTime);
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: review.teacherName, size: 32),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${review.teacherName}老师${review.mine ? '（我）' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong,
                    ),
                    if (time.isNotEmpty)
                      Text('点评于 $time', style: AppText.caption12),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              ArtworkScore(score: review.score, maxScore: review.maxScore),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final tag in review.tags)
                  ArtworkReviewTag(
                    name: tag.name,
                    color: tag.color,
                    tooltip: tag.explanation,
                  ),
              ],
            ),
          ],
          if (review.content.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text(review.content, style: AppText.body14),
          ],
          if (review.annotations.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Row(
              children: [
                const Icon(
                  Icons.gesture_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpace.s4),
                Text(
                  '在作品上留下了 ${review.annotations.length} 处批注',
                  style: AppText.caption12,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 点评按时间先后排列（没有时间的放在最后），读起来与点评顺序一致。
List<ArtworkReview> artworkReviewsByTime(Iterable<ArtworkReview> reviews) {
  final list = reviews.toList();
  list.sort((a, b) {
    if (a.reviewedTime.isEmpty != b.reviewedTime.isEmpty) {
      return a.reviewedTime.isEmpty ? 1 : -1;
    }
    return a.reviewedTime.compareTo(b.reviewedTime);
  });
  return list;
}
