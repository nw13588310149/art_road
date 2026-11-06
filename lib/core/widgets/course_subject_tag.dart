import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';
import 'course_inline_tag_style.dart';

/// 课程科目标签 12px PingFang SC w400，按学科分类切换配色：
/// • 视唱/听音/乐理/钢琴等理论与基础类 → 紫（#EAE5FF / #8741FF）
/// • 笛/箫/笙/胡/筝/吉他等器乐类       → 绿（#DFFCF0 / #0CAC40）
///
/// 盒模型与 [CourseClassKindTag] 一致；在 [DashboardScaleScope] 下按 ui 缩放。
class CourseSubjectTag extends StatelessWidget {
  const CourseSubjectTag({super.key, required this.name, this.muted = false});

  final String name;
  final bool muted;

  /// 仅用于器乐类匹配的关键字（钢琴归默认紫色）。
  static const List<String> instrumentKeywords = <String>[
    '笛',
    '箫',
    '笙',
    '胡',
    '筝',
    '阮',
    '琵琶',
    '吉他',
    '提琴',
    '萨克斯',
    '单簧',
    '双簧',
    '长号',
    '小号',
    '圆号',
    '手风琴',
    '竖琴',
    '葫芦丝',
    '陶笛',
    '口琴',
    '鼓',
    '木琴',
  ];

  static bool isInstrumentSubject(String subjectName) =>
      instrumentKeywords.any((kw) => subjectName.contains(kw));

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.maybeOf(context);
    double ui(double value) => scale?.ui(value) ?? value;

    final isInstrument = isInstrumentSubject(name);
    final bg = muted
        ? const Color(0xFFE6E9F1)
        : (isInstrument ? const Color(0xFFDFFCF0) : const Color(0xFFEAE5FF));
    final fg = muted
        ? const Color(0xFFB6B5BB)
        : (isInstrument ? const Color(0xFF0CAC40) : const Color(0xFF8741FF));

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
