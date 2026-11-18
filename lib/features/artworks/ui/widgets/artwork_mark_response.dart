import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/artwork_models.dart';

/// 学生对一处定点点评的两个回应：「改了」「没看懂」，再点一次取消。选中的垫浅灰
/// 胶囊、墨色粗体加对勾，不用品牌紫。点击区域高 44，看上去高 32。
class ArtworkMarkResponseButtons extends StatelessWidget {
  const ArtworkMarkResponseButtons({
    required this.number,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 第几处，读屏用。
  final int number;
  final ArtworkMarkResponseStatus? value;
  final ValueChanged<ArtworkMarkResponseStatus?> onChanged;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final status in ArtworkMarkResponseStatus.values) ...[
          if (status.index > 0) const SizedBox(width: AppSpace.s8),
          _ResponseToggle(
            key: ValueKey<String>('mark-respond-$number-${status.code}'),
            label: status.label,
            selected: value == status,
            semanticLabel: value == status
                ? '第 $number 处已标${status.label}，再点一次取消'
                : '第 $number 处标为${status.label}',
            onTap: () => onChanged(value == status ? null : status),
          ),
        ],
      ],
    );
  }
}

class _ResponseToggle extends StatelessWidget {
  const _ResponseToggle({
    required this.label,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: semanticLabel,
      child: SizedBox(
        height: ArtworkMarkResponseButtons.height,
        child: ExcludeSemantics(
          child: Center(
            child: Container(
              height: 32,
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              decoration: BoxDecoration(
                color: selected ? AppColors.canvas : null,
                borderRadius: AppRadius.brPill,
                border: Border.all(
                  color: selected ? AppColors.canvas : AppColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: AppSpace.s4),
                  ],
                  Text(
                    label,
                    style: selected
                        ? AppText.body13.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          )
                        : AppText.body13.copyWith(
                            color: AppColors.textSecondary,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 学生回应的状态：8 的圆点加 12 号文字，「改了」绿、「没看懂」琥珀，颜色只跟着文字出现。
class ArtworkMarkResponseLabel extends StatelessWidget {
  const ArtworkMarkResponseLabel({
    required this.status,
    this.prefix = '学生：',
    super.key,
  });

  final ArtworkMarkResponseStatus status;

  /// 写在状态前面，老师端是「学生：」，学生端不写。
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ArtworkMarkResponseStatus.fixed => AppColors.success,
      ArtworkMarkResponseStatus.unclear => AppColors.warning,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpace.s4),
        Text(
          '$prefix${status.label}',
          style: AppText.caption12.copyWith(
            color: status == ArtworkMarkResponseStatus.unclear
                ? AppColors.warning
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
