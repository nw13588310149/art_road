import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../data/study_models.dart';
import 'study_common.dart';

/// 表现解读：优势（绿）/ 待提升（琥珀）。
class StudyInterpretationsCard extends StatelessWidget {
  const StudyInterpretationsCard({
    required this.items,
    this.loading = false,
    super.key,
  });

  final List<StudyInterpretation> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (loading) {
      body = const StudyLoadingBlock(height: 96);
    } else if (items.isEmpty) {
      body = Text(
        '出分后会根据各科成绩生成解读',
        style: ArtText.body(size: 13, color: ArtColors.ink3),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: ArtColors.line),
              ),
            _InterpretationRow(item: items[i]),
          ],
        ],
      );
    }
    return StudyCard(title: '表现解读', subtitle: '根据本次成绩自动生成', child: body);
  }
}

class _InterpretationRow extends StatelessWidget {
  const _InterpretationRow({required this.item});

  final StudyInterpretation item;

  @override
  Widget build(BuildContext context) {
    final strength = item.isStrength;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Align(
            alignment: Alignment.topLeft,
            child: StudyChip(
              label: strength ? '优势' : '待提升',
              color: strength ? ArtColors.up : ArtColors.warn,
              icon: strength ? Icons.trending_up_rounded : Icons.flag_outlined,
            ),
          ),
        ),
        Expanded(
          child: Text(
            item.text,
            style: ArtText.body(size: 14, color: ArtColors.ink, height: 1.6),
          ),
        ),
      ],
    );
  }
}
