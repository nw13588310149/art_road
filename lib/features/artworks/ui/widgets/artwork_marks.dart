import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';
import '../../../gallery/ui/widgets/library_controls.dart';
import '../../data/artwork_models.dart';
import '../../data/artwork_rules.dart';

/// 作品卡片与详情上的状态小标。
///
/// 形状与配色取自参照工程（80e9dd3c）：方角标签和绿 / 橙两组状态色来自作品卡
/// （`student_my_homework_view.dart` 85–90、1848–1897），右上角标来自人员卡
/// （`admin_student_management_view.dart` 1286–1310）。原版的紫色换成品牌紫。
abstract final class ArtworkMarkPalette {
  /// 待点评、复核中。
  static const orange = Color(0xFFFF6A00);
  static const orangeBg = Color(0xFFFFEDD3);

  /// 已点评。
  static const green = LibraryPalette.badgeGreen;
  static const greenBg = LibraryPalette.badgeGreenBg;

  /// 校长点评。
  static const blue = LibraryPalette.badgeBlue;
  static const blueBg = LibraryPalette.badgeBlueBg;
}

/// 点评状态（待点评 / 已点评）的文字与配色。
({String label, Color foreground, Color background}) artworkStatusStyle(
  bool reviewed,
) => reviewed
    ? (
        label: '已点评',
        foreground: ArtworkMarkPalette.green,
        background: ArtworkMarkPalette.greenBg,
      )
    : (
        label: '待点评',
        foreground: ArtworkMarkPalette.orange,
        background: ArtworkMarkPalette.orangeBg,
      );

/// 贴在封面右上角的点评状态角标：高 22、左右 8、右上与左下圆角 12、12 号字。
///
/// 放进 [Stack]，自带定位；卡片要按圆角 12 裁剪。
class ArtworkStatusCornerBadge extends StatelessWidget {
  const ArtworkStatusCornerBadge({required this.reviewed, super.key});

  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    final style = artworkStatusStyle(reviewed);
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
        child: Text(
          style.label,
          maxLines: 1,
          softWrap: false,
          style: libraryText(size: 12, color: style.foreground, height: 1),
        ),
      ),
    );
  }
}

/// 点评状态的方角标签（详情页用）。
class ArtworkStatusMark extends StatelessWidget {
  const ArtworkStatusMark({required this.reviewed, super.key});

  final bool reviewed;

  @override
  Widget build(BuildContext context) {
    final style = artworkStatusStyle(reviewed);
    return LibraryTag(
      style.label,
      foreground: style.foreground,
      background: style.background,
    );
  }
}

/// 作品的附加小标，按「复核中、校长点评、优秀作品」的顺序；没有时为空。
///
/// 学生只知道作品在复核中，不显示进入复核的原因。
List<Widget> artworkMarkTags(ArtworkSummary work) => <Widget>[
  if (work.reviewed && work.leadStatus == ArtworkLeadStatus.inReview)
    const LibraryTag(
      '复核中',
      foreground: ArtworkMarkPalette.orange,
      background: ArtworkMarkPalette.orangeBg,
    ),
  if (work.hasPrincipalComment)
    const LibraryTag(
      '校长点评',
      foreground: ArtworkMarkPalette.blue,
      background: ArtworkMarkPalette.blueBg,
    ),
  if (work.featured) LibraryTag.brand('优秀作品'),
];

/// 封面右下角的深色小胶囊（共 N 版、N 张）：高 18、左右 8、12 号白字。
///
/// 原版视频卡的时长胶囊是半透明白底，压在浅色的素描上看不清，这里改成半透明墨色底。
class ArtworkCoverPill extends StatelessWidget {
  const ArtworkCoverPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.56),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: libraryText(size: 12, color: AppColors.onBrand, height: 1),
      ),
    );
  }
}

/// 科目方角标签：三科用科目色，其他科目用品牌紫。
class ArtworkSubjectMark extends StatelessWidget {
  const ArtworkSubjectMark({required this.subject, super.key});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final label = subject.isEmpty ? '作品' : subject;
    for (final item in ArtSubject.values) {
      if (label.contains(item.label)) {
        return LibraryTag(
          label,
          foreground: item.accent,
          background: item.accentSoft,
        );
      }
    }
    return LibraryTag.brand(label);
  }
}

/// 点评标签的方角标签：问题橙色、亮点绿色；可带次数，点一下看标签解释。
class ArtworkReviewMark extends StatelessWidget {
  const ArtworkReviewMark({
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
    final Widget tag = LibraryTag(
      times == null ? name : '$name $times 次',
      foreground: highlight
          ? ArtworkMarkPalette.green
          : ArtworkMarkPalette.orange,
      background: highlight
          ? ArtworkMarkPalette.greenBg
          : ArtworkMarkPalette.orangeBg,
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

/// 分数：数字 + 「分」。[emphasis] 时用品牌紫的大号数字（详情页的最终得分）。
class ArtworkScoreText extends StatelessWidget {
  const ArtworkScoreText({
    required this.score,
    this.size = 16,
    this.emphasis = false,
    super.key,
  });

  final String score;
  final double size;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: score,
            style: emphasis
                ? AppText.displayNumber(size: size, color: AppColors.brand)
                : AppText.number(size: size),
          ),
          TextSpan(
            text: ' 分',
            style: libraryText(
              size: 12,
              weight: AppFont.w400,
              color: AppColors.textPlaceholder,
            ),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
}
