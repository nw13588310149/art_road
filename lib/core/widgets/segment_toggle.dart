import 'package:flutter/material.dart';

import '../ui/app_segmented.dart';
import '../ui/app_spacing.dart';

/// 单个分段选项。
class SegmentToggleOption {
  const SegmentToggleOption({
    required this.label,
    this.badge,
    this.enabled = true,
  });

  final String label;

  /// 可选角标（如待审核数 `3` / `10+`）；为空不显示。
  final String? badge;

  /// 是否可点击（禁用时降低不透明度且不可选中）。
  final bool enabled;
}

/// 按下标选择的分段开关，外观与选中逻辑完全交给 [AppSegmented]：浅灰轨道 +
/// 实底选中块，选中立即切换。
///
/// [height] 不小于 32 时用 md，否则用 sm。[fontSize] 保留旧调用兼容。
class SegmentToggle extends StatelessWidget {
  const SegmentToggle({
    super.key,
    required this.selectedIndex,
    required this.options,
    required this.onChanged,
    this.height = 32,
    this.fontSize = 13,
    this.trackColor = const Color(0xFFEFEFEF),
    this.thumbColor = const Color(0xFF715EFE),
  });

  final int selectedIndex;
  final List<SegmentToggleOption> options;
  final ValueChanged<int> onChanged;
  final double height;
  final double fontSize;
  final Color trackColor;
  final Color thumbColor;

  @override
  Widget build(BuildContext context) {
    final count = options.length;
    final safeIndex = count == 0 ? 0 : selectedIndex.clamp(0, count - 1);
    return AppSegmented<int>(
      segments: [
        for (var i = 0; i < count; i++)
          AppSegment<int>(
            value: i,
            label: options[i].label,
            enabled: options[i].enabled,
            badge: options[i].badge,
          ),
      ],
      value: safeIndex,
      onChanged: onChanged,
      size: height >= 32 ? AppControlSize.md : AppControlSize.sm,
      trackColor: trackColor,
      selectedColor: thumbColor,
    );
  }
}
