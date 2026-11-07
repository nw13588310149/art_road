import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/image_gallery_viewer.dart';
import '../../data/study_models.dart';
import 'study_common.dart';

/// 档位标准表：分数区间、档位描述、样图（点击放大），高亮本次所在档位。
class GradeBandTable extends StatelessWidget {
  const GradeBandTable({
    required this.bands,
    this.highlightGrade = '',
    this.score,
    super.key,
  });

  final List<GradeBandInfo> bands;
  final String highlightGrade;
  final double? score;

  @override
  Widget build(BuildContext context) {
    if (bands.isEmpty) {
      return const AppEmptyState(
        icon: Icons.rule_rounded,
        title: '暂未配置档位标准',
        description: '阅卷系统配置打分规则后会显示在这里',
      );
    }
    final images = [
      for (final band in bands)
        if (band.imageUrl.isNotEmpty) MediaUrl.resolve(band.imageUrl),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < bands.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s8),
          _BandRow(
            band: bands[i],
            highlighted: bands[i].grade == highlightGrade,
            score: score,
            onPreview: bands[i].imageUrl.isEmpty
                ? null
                : () => showImageGallery(
                    context,
                    images: images,
                    initialIndex: math.max(
                      0,
                      images.indexOf(MediaUrl.resolve(bands[i].imageUrl)),
                    ),
                    heroTagPrefix: 'study_band',
                  ),
          ),
        ],
      ],
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({
    required this.band,
    required this.highlighted,
    required this.score,
    required this.onPreview,
  });

  final GradeBandInfo band;
  final bool highlighted;
  final double? score;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final mine = score;
    final preview = onPreview;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.brandWash : AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(
          color: highlighted ? AppColors.brand : AppColors.lineSoft,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StudyGradeTag(grade: band.grade),
                    StudyNumberText(
                      '${formatScore(band.min)}–${formatScore(band.max)}',
                      unit: ' 分',
                      size: 16,
                    ),
                    if (highlighted && mine != null)
                      AppTag(
                        label: '本次 ${formatScore(mine)} 分',
                        tone: AppTone.brand,
                      ),
                  ],
                ),
                if (band.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text(band.description, style: AppText.body13),
                ],
              ],
            ),
          ),
          if (preview != null) ...[
            const SizedBox(width: AppSpace.s12),
            AppPressable(
              onTap: preview,
              semanticLabel: '查看 ${band.grade} 档样图',
              child: Column(
                children: [
                  AppImage(
                    src: band.imageUrl,
                    width: 68,
                    height: 68,
                    borderRadius: AppRadius.br8,
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    '查看样图',
                    style: AppText.caption12.copyWith(color: AppColors.brand),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
