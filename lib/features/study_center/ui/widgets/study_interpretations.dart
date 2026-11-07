import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/study_models.dart';

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
      body = const AppSkeletonText(lines: 3);
    } else if (items.isEmpty) {
      body = Text(
        '出分后会根据各科成绩整理优势与待提升的地方',
        style: AppText.body13.copyWith(color: AppColors.textTertiary),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpace.s12),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.lineSoft,
                ),
              ),
            _InterpretationRow(item: items[i]),
          ],
        ],
      );
    }
    return AppCard(title: '表现解读', subtitle: '根据本次各科成绩整理', child: body);
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
          width: 72,
          child: Align(
            alignment: Alignment.topLeft,
            child: AppTag(
              label: strength ? '优势' : '待提升',
              tone: strength ? AppTone.success : AppTone.warning,
              icon: strength ? Icons.trending_up_rounded : Icons.flag_outlined,
            ),
          ),
        ),
        Expanded(child: Text(item.text, style: AppText.body14)),
      ],
    );
  }
}
