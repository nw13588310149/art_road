import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/widgets/art_widgets.dart';
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
      return Text(
        '暂未配置档位标准',
        style: ArtText.body(size: 13, color: ArtColors.ink3),
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
          if (i > 0) const SizedBox(height: 8),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted ? ArtColors.brandWash : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? ArtColors.brandLight : ArtColors.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArtGradeBadge(grade: band.grade, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StudyNumberText(
                      '${formatScore(band.min)}–${formatScore(band.max)}',
                      unit: ' 分',
                      size: 15,
                    ),
                    if (highlighted && mine != null)
                      StudyChip(
                        label: '本次 ${formatScore(mine)} 分',
                        color: Colors.white,
                        background: ArtColors.brand,
                      ),
                  ],
                ),
                if (band.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    band.description,
                    style: ArtText.body(size: 13, color: ArtColors.ink2),
                  ),
                ],
              ],
            ),
          ),
          if (preview != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: preview,
              child: Column(
                children: [
                  Stack(
                    children: [
                      ArtNetworkImage(
                        band.imageUrl,
                        width: 68,
                        height: 68,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0x73000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.zoom_in_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '样图',
                    style: ArtText.caption(size: 11, color: ArtColors.brand),
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
      spacing: 8,
      runSpacing: 8,
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
          ? ArtColors.brand.withValues(alpha: 0.32)
          : Colors.white.withValues(alpha: 0.06);
      border = highlighted ? ArtColors.brandSoft : Colors.transparent;
      text = highlighted ? Colors.white : Colors.white70;
    } else {
      background = highlighted ? ArtColors.brandWash : ArtColors.subtle;
      border = highlighted ? ArtColors.brandLight : Colors.transparent;
      text = highlighted ? ArtColors.brandDeep : ArtColors.ink2;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArtGradeBadge(grade: band.grade, size: 20),
          const SizedBox(width: 6),
          Text(
            '${formatScore(band.min)}–${formatScore(band.max)}',
            style: ArtText.number(size: 12, color: text),
          ),
        ],
      ),
    );
  }
}
