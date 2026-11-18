import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';

/// 色块 + HEX + 补充说明 + 百分比的一行，点击复制 HEX。
class SwatchRow extends StatelessWidget {
  const SwatchRow({
    required this.color,
    required this.hex,
    required this.onCopy,
    this.caption,
    this.trailing,
    super.key,
  });

  final Color color;
  final String hex;
  final String? caption;
  final String? trailing;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: () => onCopy(hex),
      semanticLabel: '复制 $hex',
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadius.br4,
                border: Border.all(color: AppColors.line),
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Text(hex, style: AppText.number(size: 14)),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text(
                caption ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12,
              ),
            ),
            if (trailing != null)
              Text(trailing!, style: AppText.number(size: 14)),
          ],
        ),
      ),
    );
  }
}

/// 面积比例条：按比例横向排列的色块。
class RatioBar extends StatelessWidget {
  const RatioBar({
    required this.colors,
    required this.ratios,
    this.height = 20,
    super.key,
  });

  final List<Color> colors;
  final List<double> ratios;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.br4,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: AppRadius.br4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < colors.length; i++)
              if (ratios[i] > 0)
                Expanded(
                  flex: (ratios[i] * 1000).round().clamp(1, 1000),
                  child: ColoredBox(color: colors[i]),
                ),
          ],
        ),
      ),
    );
  }
}

/// 复制 HEX 并提示。
Future<void> copyHex(BuildContext context, String hex) async {
  await Clipboard.setData(ClipboardData(text: hex));
  if (context.mounted) {
    AppToast.showSuccess(context, '已复制 $hex');
  }
}
