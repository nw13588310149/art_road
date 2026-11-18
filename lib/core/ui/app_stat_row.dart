import 'package:flutter/widgets.dart';

import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 新页面里的一个数：左边是名称和一句说明，右边是数字和单位。
///
/// 几个数上下排开，中间用 `AppRule` 隔开，代替一排带图标的数字卡。
/// 数字不带颜色；需要点进去看明细时传 [onTap]，整行可点。
class AppStatRow extends StatelessWidget {
  const AppStatRow({
    required this.label,
    required this.value,
    this.unit = '',
    this.caption = '',
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String unit;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppText.body14),
                  if (caption.isNotEmpty)
                    Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (unit.isNotEmpty)
                    TextSpan(text: ' $unit', style: AppText.caption12),
                ],
              ),
              style: AppText.number(size: 20),
            ),
          ],
        ),
      ),
    );
    return onTap == null ? row : AppPressable(onTap: onTap, child: row);
  }
}
