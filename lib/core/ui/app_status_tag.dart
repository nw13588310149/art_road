import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 状态：圆点 + 文字，无底色。状态必须同时有文字，不能只靠颜色。
///
/// 约定：进行中 brand，已完成 success，需处理 / 待开始 warning，失败 / 缺勤
/// danger，未开始 / 已结束 neutral。
class AppStatusTag extends StatelessWidget {
  const AppStatusTag({
    required this.label,
    this.tone = AppTone.neutral,
    this.color,
    super.key,
  });

  final String label;
  final AppTone tone;

  /// 自定义颜色，优先于 [tone]。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? tone.foreground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: tone == AppTone.neutral && color == null
                ? AppColors.textPlaceholder
                : foreground,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpace.s4),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: AppText.caption12.copyWith(color: foreground),
        ),
      ],
    );
  }
}
