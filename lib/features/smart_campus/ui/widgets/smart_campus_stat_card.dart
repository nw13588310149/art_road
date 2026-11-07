import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

import '../../../shell/ui/shell_layout.dart';

/// 统计卡数值字族：`assets/fonts/Barlow-SemiBold.ttf`
const smartCampusStatValueFontFamily = 'Barlow SemiBold';

/// 统计卡数值样式：Barlow SemiBold 24 / w600。
TextStyle smartCampusStatValueTextStyle(
  double Function(double) ui, {
  Color color = AppColors.ink,
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
  Color color = AppColors.ink,
}) {
  if (_smartCampusHomeStatChineseValuePattern.hasMatch(value)) {
    return TextStyle(
      fontSize: ui(smartCampusHomeStatChineseFontSize),
      color: color,
      fontWeight: AppFont.w600,
      height: 1.0,
    );
  }
  return smartCampusStatValueTextStyle(ui, color: color);
}

TextStyle _smartCampusHomeStatChineseSuffixTextStyle(
  double Function(double) ui, {
  Color color = AppColors.ink,
  double? fontSize,
}) {
  return TextStyle(
    fontSize: ui(fontSize ?? smartCampusHomeStatChineseFontSize),
    color: color,
    fontWeight: AppFont.w600,
    height: 1.0,
  );
}

/// 「180天」：数字 Barlow 24 + 「天」PingFang 18，避免整段中文样式偏大。
Widget smartCampusHomeStatValue({
  required String value,
  required double Function(double) ui,
  Color color = AppColors.ink,
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

/// 智慧校园二级页指标卡。背景插图在右侧，标题与数值在左侧。
class SmartCampusStatCard extends StatelessWidget {
  const SmartCampusStatCard({
    super.key,
    required this.backgroundAsset,
    required this.label,
    this.value = 0,
    this.valueLabel,
    this.valueSuffix,
    this.valueIsText = false,
    this.valueColor = AppColors.ink,
    this.rightPadding = 56,
    this.onTap,
  }) : child = null,
       contentPadding = null;

  /// 自定义内容区（提供时忽略 [label]/[value] 默认排版），卡片保持 100 高。
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
       valueColor = AppColors.ink;

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
    final display = valueLabel ?? '$value';
    final suffix = valueSuffix;
    final valueText = Text(
      display,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: valueIsText
          ? smartCampusHomeStatValueTextStyle(
              ui,
              value: display,
              color: valueColor,
            )
          : smartCampusStatValueTextStyle(ui, color: valueColor),
    );
    final content =
        child ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body14Strong.copyWith(height: 1),
            ),
            const SizedBox(height: AppSpace.s8),
            if (suffix == null || suffix.isEmpty)
              valueText
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(child: valueText),
                  const SizedBox(width: AppSpace.s4),
                  Text(suffix, style: AppText.caption12),
                ],
              ),
          ],
        );
    final card = Container(
      height: 100,
      width: double.infinity,
      padding:
          contentPadding ??
          EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s12,
            rightPadding,
            AppSpace.s12,
          ),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(color: AppColors.surface),
        image: DecorationImage(
          image: AssetImage(backgroundAsset),
          fit: BoxFit.fitHeight,
          alignment: Alignment.centerRight,
        ),
      ),
      child: content,
    );
    return onTap == null ? card : AppPressable(onTap: onTap, child: card);
  }
}
