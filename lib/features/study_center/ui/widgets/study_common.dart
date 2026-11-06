import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/art_widgets.dart';

/// 学情中心页面骨架：白色页头卡片 + 下方内容区（页面底色由 Shell 提供）。
class StudyPageFrame extends StatelessWidget {
  const StudyPageFrame({required this.header, required this.body, super.key});

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: header,
        ),
        const SizedBox(height: 12),
        Expanded(child: body),
      ],
    );
  }
}

/// 白底圆角内容卡片，可带标题行。
class StudyCard extends StatelessWidget {
  const StudyCard({
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final heading = title;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (heading != null) ...[
            StudySectionHeader(
              title: heading,
              subtitle: subtitle,
              trailing: trailing,
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// 卡片标题行：窄屏下右侧操作区换到标题下方。
class StudySectionHeader extends StatelessWidget {
  const StudySectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ArtText.title(size: 16),
          ),
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ArtText.caption(),
            ),
          ),
        ],
      ],
    );
    final action = trailing;
    if (action == null) return heading;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 10), action],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 12),
            action,
          ],
        );
      },
    );
  }
}

/// 数字（Manrope）+ 单位（PingFang）组合文本。
class StudyNumberText extends StatelessWidget {
  const StudyNumberText(
    this.value, {
    this.unit = '',
    this.prefix = '',
    this.size = 16,
    this.color = ArtColors.ink,
    this.unitColor = ArtColors.ink3,
    this.decoration,
    super.key,
  });

  final String value;
  final String unit;
  final String prefix;
  final double size;
  final Color color;
  final Color unitColor;
  final TextDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final unitSize = math.max(11.0, size * 0.55);
    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: ArtText.caption(size: unitSize, color: unitColor),
            ),
          TextSpan(
            text: value,
            style: ArtText.number(
              size: size,
              color: color,
            ).copyWith(decoration: decoration, decorationColor: color),
          ),
          if (unit.isNotEmpty)
            TextSpan(
              text: unit,
              style: ArtText.caption(size: unitSize, color: unitColor),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 名次文本：「第 7 名」，可带「/ 38 人」。
class StudyRankText extends StatelessWidget {
  const StudyRankText({
    required this.rank,
    this.total,
    this.size = 15,
    this.color = ArtColors.ink,
    super.key,
  });

  final int? rank;
  final int? total;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = rank;
    if (value == null) {
      return Text(
        '—',
        style: ArtText.number(size: size, color: ArtColors.ink3),
      );
    }
    final count = total;
    final small = ArtText.caption(size: math.max(11.0, size * 0.75));
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '第 ', style: small),
          TextSpan(
            text: '$value',
            style: ArtText.number(size: size, color: color),
          ),
          TextSpan(text: ' 名', style: small),
          if (count != null && count > 0) ...[
            TextSpan(
              text: ' / $count',
              style: ArtText.number(size: size * 0.8, color: ArtColors.ink3),
            ),
            TextSpan(text: ' 人', style: small),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 升降标签：正数表示进步（绿色向上），负数退步（红色向下），0 为持平。
class StudyDeltaTag extends StatelessWidget {
  const StudyDeltaTag({required this.value, this.unit = '分', super.key});

  final num? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final delta = value;
    if (delta == null) return const SizedBox.shrink();
    final flat = delta.abs() < 0.05;
    final color = flat
        ? ArtColors.ink3
        : (delta > 0 ? ArtColors.up : ArtColors.down);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!flat)
            Icon(
              delta > 0
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 12,
              color: color,
            ),
          if (flat)
            Text('持平', style: ArtText.caption(size: 12, color: color))
          else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatScore(delta.abs()),
                    style: ArtText.number(size: 12, color: color),
                  ),
                  TextSpan(
                    text: unit,
                    style: ArtText.caption(size: 11, color: color),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 得分率进度条（带入场动画）。
class StudyProgressBar extends StatelessWidget {
  const StudyProgressBar({
    required this.value,
    this.color = ArtColors.brand,
    this.height = 6,
    super.key,
  });

  /// 0–1，null 视为 0。
  final double? value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = (value ?? 0).clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: ArtColors.line),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: target),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, factor, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: factor,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.65), color],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 小胶囊标签（状态、计分方式等）。
class StudyChip extends StatelessWidget {
  const StudyChip({
    required this.label,
    this.color = ArtColors.ink2,
    this.background,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: color,
              fontWeight: AppFont.w500,
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

/// 指标块：标签 + 数值 + 单位，可带图标强调升降。
class StudyStatTile extends StatelessWidget {
  const StudyStatTile({
    required this.label,
    required this.value,
    this.unit = '',
    this.color = ArtColors.ink,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: ArtColors.subtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ArtText.caption(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (glyph != null) ...[
                Icon(glyph, size: 16, color: color),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: StudyNumberText(
                  value,
                  unit: unit.isEmpty ? '' : ' $unit',
                  size: 22,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 提示条（阅卷中、无成绩等）。
class StudyNotice extends StatelessWidget {
  const StudyNotice({
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color = ArtColors.warn,
    super.key,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: ArtText.body(size: 13, color: color)),
          ),
        ],
      ),
    );
  }
}

class StudyLoadingBlock extends StatelessWidget {
  const StudyLoadingBlock({this.height = 160, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: AppLoadingIndicator(size: 36)),
    );
  }
}

/// 加载失败占位：说明 + 重新加载。
class StudyErrorView extends StatelessWidget {
  const StudyErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ArtEmptyState(
      message: message,
      icon: Icons.cloud_off_rounded,
      actionLabel: '重新加载',
      onAction: onRetry,
    );
  }
}

/// 科目图标块（科目色底 + 图标）。
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
    final accent = artSubjectColor(subjectName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: artSubjectSoftColor(subjectName),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(iconOf(subjectName), size: size * 0.52, color: accent),
    );
  }
}

/// 弹窗外壳：标题栏 + 可滚动内容。
class StudyDialogShell extends StatelessWidget {
  const StudyDialogShell({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon = Icons.rule_rounded,
    this.accent = ArtColors.brand,
    this.maxWidth = 680,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final note = subtitle;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 10, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 20, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ArtText.title(size: 17),
                        ),
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ArtText.caption(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: ArtColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: ArtColors.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String studyPercentText(double? rate) =>
    rate == null ? '—' : '${(rate * 100).round()}%';
