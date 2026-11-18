import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../artworks/data/artwork_models.dart';
import '../../../artworks/data/artwork_rules.dart';
import '../../../artworks/ui/widgets/artwork_annotation.dart';
import '../../../artworks/ui/widgets/artwork_mark_layer.dart';
import '../../data/exam_critique_models.dart';
import '../paper/study_paper_watermark.dart';

/// 一张讲评卷的出处：「B 档 · 85 分」，允许时带上姓名。
String critiquePaperLabel(CritiquePaper paper, {bool withName = true}) {
  final parts = <String>[
    if (paper.grade.isNotEmpty) '${paper.grade} 档',
    if (paper.score != null) '${formatScore(paper.score)} 分',
    if (withName && paper.studentName.isNotEmpty) paper.studentName,
  ];
  return parts.isEmpty ? '讲评卷' : parts.join(' · ');
}

/// 讲评卷的画面：卷子完整显示，上面是编号点（和卷子一起定位），学生端再铺一层
/// 本人的水印。老师可以点空白处加一处、按住编号拖动。
class CritiqueCanvas extends StatelessWidget {
  const CritiqueCanvas({
    required this.imageUrl,
    required this.marks,
    this.selectedKey,
    this.selectedLink,
    this.tapGroup,
    this.watermarkText = '',
    this.onTapPin,
    this.onMovePin,
    this.onTapBlank,
    super.key,
  });

  final String imageUrl;
  final List<NumberedArtworkMark> marks;
  final String? selectedKey;
  final LayerLink? selectedLink;
  final Object? tapGroup;
  final String watermarkText;
  final ValueChanged<String>? onTapPin;
  final void Function(String key, Offset position)? onMovePin;
  final ValueChanged<Offset>? onTapBlank;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 编号点在卷子边上时露出一半，留出位置画全。
      padding: const EdgeInsets.all(ArtworkMarkLayer.hitExtent / 2),
      child: ArtworkAnnotatedImage(
        url: imageUrl,
        overlay: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (watermarkText.isNotEmpty)
              StudyPaperWatermark(text: watermarkText),
            ArtworkMarkLayer(
              pins: [
                for (final item in marks)
                  ArtworkMarkPin(
                    key: item.key,
                    position: item.mark.position,
                    number: item.number,
                    semanticLabel: ArtworkRules.markSemantics(
                      item.number,
                      item.mark.text,
                      hasVoice: item.mark.hasVoice,
                      voiceSeconds: item.mark.voiceSeconds,
                    ),
                  ),
              ],
              selectedKey: selectedKey,
              selectedLink: selectedLink,
              tapGroup: tapGroup,
              onTapPin: onTapPin,
              onMovePin: onMovePin,
              onTapBlank: onTapBlank,
            ),
          ],
        ),
      ),
    );
  }
}
