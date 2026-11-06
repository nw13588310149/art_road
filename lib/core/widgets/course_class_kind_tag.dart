import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';
import 'course_inline_tag_style.dart';

/// 大课 / 小课标签：白底 + 圆点 + 文案，与智慧校园首页右侧课表一致。
///
/// 在 [DashboardScaleScope] 下按 ui 缩放；无 scope 时使用设计稿固定尺寸。
class CourseClassKindTag extends StatelessWidget {
  const CourseClassKindTag({
    super.key,
    required this.isSmall,
    this.muted = false,
    this.outlined = true,
    this.dotColor,
  });

  final bool isSmall;
  final bool muted;

  /// 是否描边（智慧校园首页课表为 true）。
  final bool outlined;

  /// 圆点色；为空时小课绿 / 大课紫，[muted] 时为灰。
  final Color? dotColor;

  static const Color _kTextDark = Color(0xFF0B081A);
  static const Color _kMuted = Color(0xFFB6B5BB);
  static const Color _kSmallDot = Color(0xFF0CAC40);
  static const Color _kBigDot = Color(0xFFA773FF);

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.maybeOf(context);
    double ui(double value) => scale?.ui(value) ?? value;

    final resolvedDot = dotColor ??
        (muted ? _kMuted : (isSmall ? _kSmallDot : _kBigDot));
    final textColor = muted ? _kMuted : _kTextDark;
    final label = isSmall ? '小课' : '大课';

    return CourseInlineTagStyle.build(
      ui: ui,
      backgroundColor: Colors.white,
      outlined: outlined,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: BoxDecoration(
              color: resolvedDot,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: CourseInlineTagStyle.textStyle(ui: ui, color: textColor),
          ),
        ],
      ),
    );
  }
}
