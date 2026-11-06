import 'package:flutter/material.dart';

import '../art/art_subject.dart';
import '../theme/app_font.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// 只读小胶囊：22 高、12px 字、浅底深字，按内容取宽，从不截断文字。
///
/// 颜色优先级：[color] / [background] > [tone]。只给 [color] 时浅底按 12% 自动生成。
/// 放在可能变窄的位置时用 `Wrap` 排列，不要放进会压缩它的 `Row`。
class AppTag extends StatelessWidget {
  const AppTag({
    required this.label,
    this.tone = AppTone.neutral,
    this.color,
    this.background,
    this.dotColor,
    this.icon,
    super.key,
  });

  /// 科目标签：素描 / 色彩 / 速写用科目色，其他课程用品牌紫；[muted] 时转灰。
  factory AppTag.subject(String subject, {bool muted = false, Key? key}) {
    if (muted) {
      return AppTag(label: subject, key: key);
    }
    final matched = _subjectOf(subject);
    return AppTag(
      label: subject,
      color: matched?.accent ?? AppColors.brandDeep,
      background: matched?.accentSoft ?? AppColors.brandTint,
      key: key,
    );
  }

  final String label;
  final AppTone tone;
  final Color? color;
  final Color? background;

  /// 文字前的 6px 圆点（如大课 / 小课的课程色）。
  final Color? dotColor;
  final IconData? icon;

  static ArtSubject? _subjectOf(String name) {
    for (final subject in ArtSubject.values) {
      if (name.contains(subject.label)) {
        return subject;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? tone.foreground;
    final fill =
        background ??
        (color == null ? tone.background : AppColors.tint(color!));
    final dot = dotColor;
    return Container(
      height: AppSize.tag,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      decoration: BoxDecoration(color: fill, borderRadius: AppRadius.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpace.s4),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpace.s4),
          ],
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: AppFont.w400,
              color: foreground,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ],
      ),
    );
  }
}
