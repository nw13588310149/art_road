import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/artwork_models.dart';
import '../../data/artwork_rules.dart';

/// 点评状态徽章：待点评琥珀色、已点评绿色。
class ArtworkStatusBadge extends StatelessWidget {
  const ArtworkStatusBadge({
    required this.done,
    this.label,
    this.solid = false,
    super.key,
  });

  final bool done;
  final String? label;

  /// 叠在封面图上时用实底，保证可读。
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final color = done ? ArtColors.success : ArtColors.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label ?? (done ? '已点评' : '待点评'),
        style: TextStyle(
          fontSize: 11,
          height: 1.3,
          color: solid ? Colors.white : color,
          fontWeight: AppFont.w500,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

/// 科目标签：三科用科目色，自定义科目用品牌紫。
class ArtworkSubjectChip extends StatelessWidget {
  const ArtworkSubjectChip({required this.subject, super.key});

  final String subject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: artSubjectSoftColor(subject),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        subject.isEmpty ? '作品' : subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          height: 1.4,
          color: artSubjectColor(subject),
          fontWeight: AppFont.w500,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

/// 点评标签 chip：颜色取自标签 `#HEX`；可选中、可带次数、可提示解释。
class ArtworkTagChip extends StatelessWidget {
  const ArtworkTagChip({
    required this.name,
    required this.color,
    this.count,
    this.selected = false,
    this.dense = false,
    this.tooltip = '',
    this.onTap,
    super.key,
  });

  final String name;
  final String color;
  final int? count;
  final bool selected;
  final bool dense;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = ArtColors.fromHex(color);
    final fg = selected ? Colors.white : tone;
    Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: selected ? tone : tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? tone : tone.withValues(alpha: 0.26),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 12 : 13,
                height: 1.25,
                color: fg,
                fontWeight: AppFont.w500,
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 4),
            Text(
              '×$count',
              style: TextStyle(
                fontSize: dense ? 11 : 12,
                height: 1.2,
                color: fg.withValues(alpha: 0.85),
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap != null) {
      chip = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: chip,
      );
    }
    if (tooltip.isNotEmpty) {
      chip = Tooltip(
        message: tooltip,
        triggerMode: onTap == null
            ? TooltipTriggerMode.tap
            : TooltipTriggerMode.longPress,
        preferBelow: false,
        child: chip,
      );
    }
    return chip;
  }
}

/// 分数：`88.5 /100`；未打分显示「未评分」。
class ArtworkScore extends StatelessWidget {
  const ArtworkScore({
    required this.score,
    required this.maxScore,
    this.size = 20,
    this.color = ArtColors.brandDeep,
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
      return Text('未评分', style: ArtText.caption(size: 12));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          ArtworkRules.formatScore(value),
          style: ArtText.number(size: size, color: color),
        ),
        const SizedBox(width: 2),
        Text(
          '/${ArtworkRules.formatScore(maxScore)}',
          style: ArtText.caption(size: math.max(11, size * 0.5)),
        ),
      ],
    );
  }
}

class ArtworkSectionTitle extends StatelessWidget {
  const ArtworkSectionTitle({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: ArtColors.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: ArtText.title(size: 15)),
          const SizedBox(width: 8),
          if (trailing != null)
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
        ],
      ),
    );
  }
}

/// 作品缩略图条。
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: size,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? ArtColors.brand : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ArtNetworkImage(
                images[index].url,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 一位老师的点评：头像、分数、标签、评语。
class ArtworkReviewCard extends StatelessWidget {
  const ArtworkReviewCard({required this.review, super.key});

  final ArtworkReview review;

  @override
  Widget build(BuildContext context) {
    final time = review.reviewedTime.isEmpty
        ? ''
        : ArtworkRules.shortTime(review.reviewedTime);
    return ArtCard(
      color: ArtColors.subtle,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ArtAvatar(name: review.teacherName, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${review.teacherName}老师${review.mine ? '（我）' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ArtText.body(weight: AppFont.w500),
                    ),
                    if (time.isNotEmpty)
                      Text('点评于 $time', style: ArtText.caption(size: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ArtworkScore(score: review.score, maxScore: review.maxScore),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in review.tags)
                  ArtworkTagChip(
                    name: tag.name,
                    color: tag.color,
                    dense: true,
                    tooltip: tag.explanation,
                  ),
              ],
            ),
          ],
          if (review.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.content,
              style: ArtText.body(size: 13, color: ArtColors.ink2, height: 1.6),
            ),
          ],
          if (review.annotations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.gesture_rounded,
                  size: 14,
                  color: ArtColors.brandSoft,
                ),
                const SizedBox(width: 4),
                Text(
                  '在作品上留下了 ${review.annotations.length} 处批注',
                  style: ArtText.caption(size: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 统计卡：标题 + 数值（件）+ 右侧图标。
class ArtworkStatCard extends StatelessWidget {
  const ArtworkStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = ArtColors.ink,
    this.onTap,
    super.key,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = color == ArtColors.ink ? ArtColors.brand : color;
    return ArtCard(
      color: ArtColors.subtle,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: ArtStatTile(
              label: label,
              value: '$value',
              unit: '件',
              color: color,
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
        ],
      ),
    );
  }
}

/// 弹窗标题栏：标题、说明与关闭按钮。
class ArtworkDialogHeader extends StatelessWidget {
  const ArtworkDialogHeader({
    required this.title,
    this.subtitle = '',
    this.onClose,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ArtText.title(size: 18)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: ArtText.caption()),
                ],
              ],
            ),
          ),
          ArtworkIconAction(
            icon: Icons.close_rounded,
            tooltip: '关闭',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

/// 小号方形图标按钮（工具栏）。
class ArtworkIconAction extends StatelessWidget {
  const ArtworkIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
    this.color = ArtColors.ink2,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? ArtColors.brandWash : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? ArtColors.brandLight : ArtColors.line,
            ),
          ),
          child: Icon(icon, size: 18, color: enabled ? color : ArtColors.ink4),
        ),
      ),
    );
  }
}

/// 表单输入框统一样式。
InputDecoration artworkInputDecoration({
  String hint = '',
  bool showCounter = false,
  Widget? prefixIcon,
  EdgeInsetsGeometry? contentPadding,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: ArtText.body(color: ArtColors.ink4),
    counterText: showCounter ? null : '',
    counterStyle: ArtText.caption(size: 11),
    isDense: true,
    filled: true,
    fillColor: ArtColors.subtle,
    prefixIcon: prefixIcon,
    prefixIconConstraints: prefixIcon == null
        ? null
        : const BoxConstraints(minWidth: 36, minHeight: 32),
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: border(ArtColors.line),
    enabledBorder: border(ArtColors.line),
    disabledBorder: border(Colors.transparent),
    focusedBorder: border(ArtColors.brandSoft, 1.2),
  );
}
