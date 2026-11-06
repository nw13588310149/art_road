import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';
import '../art/art_subject.dart';
import 'course_inline_tag_style.dart';

/// 课程科目标签 12px PingFang SC w400，按科目切换配色：
/// 素描 / 色彩 / 速写 使用科目色，美术常识、文化课等其他课程使用品牌紫。
///
/// 盒模型与 [CourseClassKindTag] 一致；在 [DashboardScaleScope] 下按 ui 缩放。
class CourseSubjectTag extends StatelessWidget {
  const CourseSubjectTag({super.key, required this.name, this.muted = false});

  final String name;
  final bool muted;

  static ArtSubject? _subjectOf(String subjectName) {
    for (final subject in ArtSubject.values) {
      if (subjectName.contains(subject.label)) {
        return subject;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.maybeOf(context);
    double ui(double value) => scale?.ui(value) ?? value;

    final subject = _subjectOf(name);
    final bg = muted
        ? const Color(0xFFE6E9F1)
        : (subject?.accentSoft ?? const Color(0xFFE3DFFF));
    final fg = muted
        ? const Color(0xFFB6B5BB)
        : (subject?.accent ?? const Color(0xFF715EFE));

    return CourseInlineTagStyle.build(
      ui: ui,
      backgroundColor: bg,
      // 与后方大课/小课标签使用完全相同的 1px 描边盒模型，避免实色背景
      // 在视觉上比带描边标签上下各多出 1px。
      outlined: true,
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: CourseInlineTagStyle.textStyle(ui: ui, color: fg),
      ),
    );
  }
}
