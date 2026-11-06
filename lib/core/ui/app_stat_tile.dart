import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 指标：标签 + 大号数字 + 单位 + 可选变化量。
///
/// [delta] 为正表示上升；[invertDelta] 用于名次等「越小越好」的指标。变好为绿色，
/// 变差为红色，0 不显示。[boxed] 时带浅灰底，适合横排多个指标。
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.deltaSuffix = '',
    this.invertDelta = false,
    this.valueColor = AppColors.ink,
    this.boxed = false,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;
  final num? delta;
  final String deltaSuffix;
  final bool invertDelta;
  final Color valueColor;
  final bool boxed;

  static String _formatDelta(num value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final change = delta;
    final unitText = unit;
    final better = change == null
        ? null
        : (invertDelta ? change < 0 : change > 0);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption12,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.number(size: 24, color: valueColor),
              ),
            ),
            if (unitText != null && unitText.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(unitText, style: AppText.caption12),
            ],
            if (change != null && change != 0) ...[
              const SizedBox(width: 6),
              Text(
                '${better! ? '↑' : '↓'}${_formatDelta(change.abs())}$deltaSuffix',
                style: AppText.number(
                  size: 12,
                  color: better ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ],
    );
    if (!boxed) {
      return content;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s16,
        AppSpace.s12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br12,
      ),
      child: content,
    );
  }
}
