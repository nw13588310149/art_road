import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../../../shell/ui/shell_layout.dart';

/// 统计卡数值字族：`assets/fonts/Barlow-SemiBold.ttf`
const smartCampusStatValueFontFamily = 'Barlow SemiBold';

/// 统计卡数值样式：Barlow SemiBold 24 / w600。
TextStyle smartCampusStatValueTextStyle(
  double Function(double) ui, {
  Color color = const Color(0xFF0B081A),
}) {
  return TextStyle(
    fontSize: ui(24),
    color: color,
    fontFamily: smartCampusStatValueFontFamily,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );
}

final _smartCampusHomeStatChineseValuePattern = RegExp(r'[\u4e00-\u9fff]');
final _smartCampusHomeStatDaysValuePattern = RegExp(r'^(\d+)天$');

/// 首页中文数值字号：PingFang 同 pt 比 Barlow 数字显大，用 18 对齐数字 24 的视觉体量。
const smartCampusHomeStatChineseFontSize = 18.0;

/// 首页 6 格统计卡数值：纯数字 Barlow 24；中文（周几、今天、已过）PingFang 18。
TextStyle smartCampusHomeStatValueTextStyle(
  double Function(double) ui, {
  required String value,
  Color color = const Color(0xFF0B081A),
}) {
  if (_smartCampusHomeStatChineseValuePattern.hasMatch(value)) {
    return TextStyle(
      fontSize: ui(smartCampusHomeStatChineseFontSize),
      color: color,
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w600,
      height: 1.0,
    );
  }
  return smartCampusStatValueTextStyle(ui, color: color);
}

TextStyle _smartCampusHomeStatChineseSuffixTextStyle(
  double Function(double) ui, {
  Color color = const Color(0xFF0B081A),
  double? fontSize,
}) {
  return TextStyle(
    fontSize: ui(fontSize ?? smartCampusHomeStatChineseFontSize),
    color: color,
    fontFamily: 'PingFang SC',
    fontWeight: AppFont.w600,
    height: 1.0,
  );
}

/// 「180天」：数字 Barlow 24 + 「天」PingFang 18，避免整段中文样式偏大。
Widget smartCampusHomeStatValue({
  required String value,
  required double Function(double) ui,
  Color color = const Color(0xFF0B081A),
  Color? numberColor,
  double? suffixFontSize,
  TextAlign textAlign = TextAlign.center,
}) {
  final daysMatch = _smartCampusHomeStatDaysValuePattern.firstMatch(value);
  if (daysMatch != null) {
    const textHeightBehavior = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    );
    final numberStyle = smartCampusStatValueTextStyle(
      ui,
      color: numberColor ?? color,
    );
    final suffixStyle = _smartCampusHomeStatChineseSuffixTextStyle(
      ui,
      color: color,
      fontSize: suffixFontSize,
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          daysMatch.group(1)!,
          style: numberStyle,
          textHeightBehavior: textHeightBehavior,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Transform.translate(
          offset: Offset(0, -ui(2)),
          child: Text(
            '天',
            style: suffixStyle,
            textHeightBehavior: textHeightBehavior,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (textAlign == TextAlign.center) {
      return content;
    }
    return Align(
      alignment: textAlign == TextAlign.end
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: content,
    );
  }

  return Text(
    value,
    textAlign: textAlign,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: smartCampusHomeStatValueTextStyle(ui, value: value, color: color),
  );
}

/// 统计卡 1px 白边：Canvas 描边，绘制在背景与文字之上。
class _SmartCampusStatCardBorderPainter extends CustomPainter {
  const _SmartCampusStatCardBorderPainter({
    required this.borderRadius,
    required this.strokeWidth,
  });

  final BorderRadius borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final half = strokeWidth / 2;
    final rrect = borderRadius.toRRect(
      Rect.fromLTWH(
        half,
        half,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _SmartCampusStatCardBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 智慧校园二级页顶部统计卡（背景图 + 标题 + 数值）。
///
/// 背景图统一：高度撑满卡片，宽度按素材比例自适应，右上对齐；
/// 左侧留白由白底填充（素材左侧一般为白底，文字叠在上方）。
class SmartCampusStatCard extends StatelessWidget {
  const SmartCampusStatCard({
    super.key,
    required this.backgroundAsset,
    required this.label,
    this.value = 0,
    this.valueLabel,
    this.valueSuffix,
    this.valueIsText = false,
    this.valueColor = const Color(0xFF0B081A),
    this.rightPadding = 56,
    this.onTap,
  }) : child = null,
       contentPadding = null;

  /// 自定义内容区（提供时忽略 [label]/[value] 默认排版）。
  ///
  /// [contentPadding] 为 `EdgeInsets.zero` 时，子组件按卡片边缘绝对定位（如 Figma
  /// left/top 16/44）；默认保留统计卡通用内边距。
  const SmartCampusStatCard.custom({
    super.key,
    required this.backgroundAsset,
    required this.child,
    this.rightPadding = 56,
    this.contentPadding,
    this.onTap,
  }) : label = '',
       value = 0,
       valueLabel = null,
       valueSuffix = null,
       valueIsText = false,
       valueColor = const Color(0xFF0B081A);

  final String backgroundAsset;
  final String label;
  final int value;
  final String? valueLabel;
  final String? valueSuffix;
  final bool valueIsText;
  final Color valueColor;
  final double rightPadding;
  final EdgeInsets? contentPadding;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = ui(12);
    final strokeWidth = ui(1);
    final borderRadius = BorderRadius.circular(radius);
    // 背景图圆角略小于外框，避免右缘/右上角抗锯齿溢出盖白边。
    final contentRadius = BorderRadius.circular(
      (radius - strokeWidth).clamp(0.0, radius),
    );

    final card = SizedBox(
      height: ui(100),
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: borderRadius,
            ),
          ),
          ClipRRect(
            borderRadius: contentRadius,
            clipBehavior: Clip.hardEdge,
            child: Align(
              alignment: Alignment.topRight,
              child: Image.asset(
                backgroundAsset,
                height: double.infinity,
                fit: BoxFit.fitHeight,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
          Padding(
            padding:
                contentPadding ??
                EdgeInsets.fromLTRB(
                  ui(16),
                  ui(14),
                  ui(rightPadding),
                  ui(14),
                ),
            child: child ?? _DefaultStatContent(this, ui),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SmartCampusStatCardBorderPainter(
                  borderRadius: borderRadius,
                  strokeWidth: strokeWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: card,
      ),
    );
  }
}

class _DefaultStatContent extends StatelessWidget {
  const _DefaultStatContent(this.card, this.ui);

  final SmartCampusStatCard card;
  final double Function(double) ui;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFF0B081A),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.0,
          ),
        ),
        SizedBox(height: ui(8)),
        _buildValueRow(),
      ],
    );
  }

  Widget _buildValueRow() {
    final display = card.valueLabel ?? '${card.value}';
    final valueWidget = card.valueIsText
        ? Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(18),
              color: card.valueColor,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.0,
            ),
          )
        : Text(
            display,
            style: smartCampusStatValueTextStyle(ui, color: card.valueColor),
          );

    final suffix = card.valueSuffix;
    if (suffix == null || suffix.isEmpty) {
      return valueWidget;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: valueWidget),
        SizedBox(width: ui(8)),
        Padding(
          padding: EdgeInsets.only(bottom: ui(2)),
          child: Text(
            suffix,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: const Color(0xFFB6B5BB),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
