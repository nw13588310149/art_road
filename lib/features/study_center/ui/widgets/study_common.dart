import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';

/// 学情中心页面骨架：页头直接放在页面底色上，下方为内容区。
class StudyPageFrame extends StatelessWidget {
  const StudyPageFrame({required this.header, required this.body, super.key});

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }
}

/// 内容区左右版心与底部留白。
const studyBodyPadding = EdgeInsets.fromLTRB(
  AppSpace.page,
  AppSpace.s4,
  AppSpace.page,
  AppSpace.s24,
);

/// 数字（Manrope）+ 单位（中文字体）。
class StudyNumberText extends StatelessWidget {
  const StudyNumberText(
    this.value, {
    this.unit = '',
    this.size = 16,
    this.color = AppColors.ink,
    this.unitColor = AppColors.textTertiary,
    this.decoration,
    super.key,
  });

  final String value;
  final String unit;
  final double size;
  final Color color;
  final Color unitColor;
  final TextDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final unitStyle = (size >= 20 ? AppText.body13 : AppText.caption12)
        .copyWith(color: unitColor);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: AppText.number(
              size: size,
              color: color,
            ).copyWith(decoration: decoration, decorationColor: color),
          ),
          if (unit.isNotEmpty) TextSpan(text: unit, style: unitStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 名次：「第 7 名 / 38 人」；[totalUnit] 可改为「人参考」等说明分母口径。
class StudyRankText extends StatelessWidget {
  const StudyRankText({
    required this.rank,
    this.total,
    this.totalUnit = '人',
    this.size = 16,
    this.color = AppColors.ink,
    super.key,
  });

  final int? rank;
  final int? total;
  final String totalUnit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = rank;
    if (value == null) {
      return Text(
        '—',
        style: AppText.number(size: size, color: AppColors.textTertiary),
      );
    }
    final count = total;
    final small = (size >= 20 ? AppText.body13 : AppText.caption12).copyWith(
      color: AppColors.textSecondary,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '第 ', style: small),
          TextSpan(
            text: '$value',
            style: AppText.number(size: size, color: color),
          ),
          TextSpan(text: ' 名', style: small),
          if (count != null && count > 0) ...[
            TextSpan(
              text: ' / $count',
              style: AppText.number(
                size: size >= 20 ? 16 : 13,
                color: AppColors.textTertiary,
              ),
            ),
            TextSpan(text: ' $totalUnit', style: small),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 升降标签：上升绿色、下降红色、持平灰色；分数固定一位小数，名次为整数。
class StudyDeltaTag extends StatelessWidget {
  const StudyDeltaTag({required this.value, this.unit = '分', super.key});

  final num? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final delta = value;
    if (delta == null) {
      return const SizedBox.shrink();
    }
    if (delta.abs() < 0.05) {
      return const AppTag(label: '持平');
    }
    final up = delta > 0;
    final amount = unit == '名'
        ? delta.abs().round().toString()
        : formatScoreDelta(delta);
    return AppTag(
      label: '$amount $unit',
      tone: up ? AppTone.success : AppTone.danger,
      icon: up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
    );
  }
}

/// 档位标签：A 档用品牌色，D 档及以下用提醒色，其余中性。
class StudyGradeTag extends StatelessWidget {
  const StudyGradeTag({required this.grade, super.key});

  final String grade;

  static AppTone toneOf(String grade) => switch (grade.trim().toUpperCase()) {
    'A' => AppTone.brand,
    'B' || 'C' => AppTone.neutral,
    '' => AppTone.neutral,
    _ => AppTone.warning,
  };

  @override
  Widget build(BuildContext context) {
    final value = grade.trim();
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppTag(label: '$value 档', tone: toneOf(value));
  }
}

/// 科目色：三科取 [ArtSubject]，其他课程用品牌紫。
Color studySubjectColor(String subjectName) =>
    ArtSubject.tryParse(subjectName)?.accent ?? AppColors.brand;

Color studySubjectSoftColor(String subjectName) =>
    ArtSubject.tryParse(subjectName)?.accentSoft ?? AppColors.brandWash;

/// 科目图标块（科目浅底 + 科目色图标）。
class StudySubjectIcon extends StatelessWidget {
  const StudySubjectIcon({
    required this.subjectName,
    this.size = 36,
    super.key,
  });

  final String subjectName;
  final double size;

  static IconData iconOf(String subjectName) =>
      switch (ArtSubject.tryParse(subjectName)) {
        ArtSubject.sketch => Icons.draw_outlined,
        ArtSubject.color => Icons.palette_outlined,
        ArtSubject.speed => Icons.gesture_rounded,
        null => Icons.brush_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: studySubjectSoftColor(subjectName),
        borderRadius: AppRadius.br8,
      ),
      child: Icon(
        iconOf(subjectName),
        size: size * 0.52,
        color: studySubjectColor(subjectName),
      ),
    );
  }
}

/// 卡片内容加载占位：与成绩卡大致同高的静态骨架。
class StudyCardSkeleton extends StatelessWidget {
  const StudyCardSkeleton({this.lines = 3, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(width: 160, height: 18),
          const SizedBox(height: AppSpace.s16),
          AppSkeletonText(lines: lines),
        ],
      ),
    );
  }
}

/// 页尾说明（成绩口径）。
class StudyFootnote extends StatelessWidget {
  const StudyFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s16),
      child: Text(text, textAlign: TextAlign.center, style: AppText.caption12),
    );
  }
}

String studyPercentText(double? rate) =>
    rate == null ? '—' : '${(rate * 100).round()}%';
