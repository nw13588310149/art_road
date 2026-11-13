import 'package:flutter/material.dart';

import '../../../core/theme/app_font.dart';
import '../../shell/ui/shell_layout.dart';

/// 正确率过低时统计卡片整列变红高亮使用的颜色。
const Color _kAccuracyLowColor = Color(0xFFFF8486);
const Color _kStatCardBg = Color(0xFFF5F6FA);
const Color _kStatTextDefault = Color(0xFF0B081A);
const Color _kStatLabelDefault = Color(0xFF8B8B97);

/// 题库与练习回顾共用原版的数字在上、说明在下的统计排列。
class QuizStats extends StatelessWidget {
  const QuizStats({
    required this.notDone,
    required this.done,
    required this.wrong,
    required this.accuracyPercent,
    this.spacing,
    super.key,
  });

  final int notDone;
  final int done;
  final int wrong;
  final int accuracyPercent;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final gap = spacing ?? ui(16);
    final accuracyLow = done > 0 && accuracyPercent < 60;
    return Row(
      children: [
        Expanded(child: _QuizStat(value: '$notDone', label: '未做题')),
        SizedBox(width: gap),
        Expanded(child: _QuizStat(value: '$done', label: '已做题')),
        SizedBox(width: gap),
        Expanded(child: _QuizStat(value: '$wrong', label: '错题')),
        SizedBox(width: gap),
        Expanded(
          child: _QuizStat(
            value: done > 0 ? '$accuracyPercent%' : '—',
            label: '正确率',
            highlight: accuracyLow,
          ),
        ),
      ],
    );
  }
}

class _QuizStat extends StatelessWidget {
  const _QuizStat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final highlightColor = _kAccuracyLowColor;
    return Container(
      height: ui(86),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kStatCardBg,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ? highlightColor : _kStatTextDefault,
              fontSize: ui(26),
              fontFamily: 'Barlow',
              fontWeight: AppFont.w600,
              height: 1.1,
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ? highlightColor : _kStatLabelDefault,
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
