import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 课程卡时间行内联标签（[CourseSubjectTag] / [CourseClassKindTag]）共用盒模型。
abstract final class CourseInlineTagStyle {
  CourseInlineTagStyle._();

  static const double height = 19;
  static const double borderRadius = 4;
  static const double horizontalPadding = 4;
  static const double fontSize = 12;
  static const double textLineHeight = 15.24 / 12;
  static const Color borderColor = Color(0xFFF3F2F3);

  static TextStyle textStyle({
    required double Function(double) ui,
    required Color color,
  }) {
    return TextStyle(
      fontSize: ui(fontSize),
      color: color,
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w400,
      height: textLineHeight,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// 与 [CourseClassKindTag] 默认 `outlined: true` 时完全一致的标签外壳。
  static Widget build({
    required double Function(double) ui,
    required Color backgroundColor,
    required Widget child,
    bool outlined = true,
  }) {
    return Container(
      height: ui(height),
      padding: EdgeInsets.symmetric(horizontal: ui(horizontalPadding)),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(ui(borderRadius)),
        border: outlined ? Border.all(color: borderColor) : null,
      ),
      // `Container.alignment` 在父级给出有限最大宽度时会主动撑满，导致短科目
      // 也占据整段剩余空间。用带 widthFactor 的 Align 只按文字内容取宽，
      // 同时仍允许外层在极窄布局下给出 maxWidth 并触发文字省略。
      child: Align(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
