import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 横向步骤条：24px 序号圆 + 短标签，步骤之间用细线连接。
///
/// [current] 之前的步骤显示为已完成（对勾），[current] 为当前步骤（品牌色
/// 序号），之后的步骤为中性色。标签保持 2–6 个字的短语，例如「选择人员」。
class AppSteps extends StatelessWidget {
  const AppSteps({required this.labels, this.current = 0, super.key});

  final List<String> labels;

  /// 当前步骤下标（从 0 开始）；大于等于 `labels.length` 表示全部完成。
  final int current;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      if (i > 0) {
        children.add(
          Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
              color: i <= current ? AppColors.brand : AppColors.line,
            ),
          ),
        );
      }
      children.add(
        _AppStep(
          index: i,
          label: labels[i],
          done: i < current,
          active: i == current,
        ),
      );
    }
    return Row(children: children);
  }
}

class _AppStep extends StatelessWidget {
  const _AppStep({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final highlighted = done || active;
    return Semantics(
      label: '第 ${index + 1} 步 $label${done ? '，已完成' : ''}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlighted ? AppColors.brand : AppColors.surface,
              border: highlighted ? null : Border.all(color: AppColors.line),
            ),
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.surface,
                  )
                : Text(
                    '${index + 1}',
                    style: AppText.caption12Strong.copyWith(
                      color: highlighted
                          ? AppColors.surface
                          : AppColors.textTertiary,
                      height: 1,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpace.s8),
          Text(
            label,
            maxLines: 1,
            style: AppText.body13.copyWith(
              color: highlighted ? AppColors.ink : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
