import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// 题库与练习回顾共用原版的数字在上、说明在下的统计排列。
class QuizStats extends StatelessWidget {
  const QuizStats({
    required this.notDone,
    required this.done,
    required this.wrong,
    required this.accuracyPercent,
    this.spacing = AppSpace.s16,
    super.key,
  });

  final int notDone;
  final int done;
  final int wrong;
  final int accuracyPercent;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('$notDone', '未做题', false),
      ('$done', '已做题', false),
      ('$wrong', '错题', false),
      (
        done > 0 ? '$accuracyPercent%' : '—',
        '正确率',
        done > 0 && accuracyPercent < 60,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) SizedBox(width: spacing),
          Expanded(
            child: _QuizStat(
              value: metrics[index].$1,
              label: metrics[index].$2,
              highlighted: metrics[index].$3,
            ),
          ),
        ],
      ],
    );
  }
}

class _QuizStat extends StatelessWidget {
  const _QuizStat({
    required this.value,
    required this.label,
    required this.highlighted,
  });

  final String value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(AppSpace.s8),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.displayNumber(
              size: 24,
              color: highlighted ? AppColors.danger : AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption12.copyWith(
              color: highlighted ? AppColors.danger : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
