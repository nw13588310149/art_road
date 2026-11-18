import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_models.dart';

/// 档位图例（紧凑）：A 90–100 · B 80–89.5 …，高亮当前档位。
class GradeBandLegend extends StatelessWidget {
  const GradeBandLegend({
    required this.bands,
    this.highlightGrade = '',
    this.dark = false,
    super.key,
  });

  final List<GradeBandInfo> bands;
  final String highlightGrade;

  /// 深色背景（原卷查看页）。
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s8,
      children: [
        for (final band in bands)
          _LegendChip(
            band: band,
            highlighted: band.grade == highlightGrade,
            dark: dark,
          ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.band,
    required this.highlighted,
    required this.dark,
  });

  final GradeBandInfo band;
  final bool highlighted;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color border;
    final Color text;
    if (dark) {
      background = highlighted
          ? AppColors.brand
          : AppColors.onBrand.withValues(alpha: 0.08);
      border = AppColors.onBrand.withValues(alpha: 0);
      text = AppColors.onBrand.withValues(alpha: highlighted ? 1 : 0.72);
    } else {
      background = highlighted ? AppColors.brandWash : AppColors.surfaceSubtle;
      border = highlighted ? AppColors.brand : AppColors.surfaceSubtle;
      text = highlighted ? AppColors.brandDeep : AppColors.textSecondary;
    }
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${band.grade} 档',
            style: AppText.caption12Strong.copyWith(color: text),
          ),
          const SizedBox(width: AppSpace.s4),
          Text(
            '${formatScore(band.min)}–${formatScore(band.max)}',
            style: AppText.number(size: 12, color: text),
          ),
        ],
      ),
    );
  }
}
