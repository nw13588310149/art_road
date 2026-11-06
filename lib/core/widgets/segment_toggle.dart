import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';
import '../theme/app_font.dart';

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

  /// 是否可点击（禁用时文字置灰且不可选中）。
  final bool enabled;
}

/// 统一的「两段（或多段）开关」分段控件。
///
/// 视觉与动效统一参考 musicPlay「关闭 / 答案」切换：浅灰轨道 + 品牌紫滑块，
/// 选中态白字、未选中黑字；切换时仅滑块用 [AnimatedAlign] 平滑滑动（180ms /
/// easeOut）。文字颜色与字重随选中态即时切换，避免与滑块动画叠加产生闪烁。
class SegmentToggle extends StatelessWidget {
  const SegmentToggle({
    super.key,
    required this.selectedIndex,
    required this.options,
    required this.onChanged,
    this.height = 32,
    this.fontSize = 13,
    this.trackColor = const Color(0xFFEFEFEF),
    this.thumbColor = const Color(0xFF8741FF),
  });

  final int selectedIndex;
  final List<SegmentToggleOption> options;
  final ValueChanged<int> onChanged;
  final double height;
  final double fontSize;
  final Color trackColor;
  final Color thumbColor;

  static const Duration _duration = Duration(milliseconds: 180);
  static const Curve _curve = Curves.easeOut;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final count = options.length;
    final safeIndex = count == 0 ? 0 : selectedIndex.clamp(0, count - 1);
    // 选中段 → 水平对齐（-1 最左、1 最右），两段时即 -1 / 1。
    final thumbAlignX = count <= 1 ? 0.0 : (safeIndex / (count - 1)) * 2 - 1;

    return Container(
      height: ui(height),
      padding: EdgeInsets.all(ui(2)),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: ui(14)),
                  child: Opacity(
                    opacity: 0,
                    child: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: ui(fontSize),
                        fontFamily: 'PingFang SC',
                        height: 1,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: AnimatedAlign(
              duration: _duration,
              curve: _curve,
              alignment: Alignment(thumbAlignX, 0),
              child: FractionallySizedBox(
                widthFactor: count == 0 ? 1 : 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: thumbColor,
                    borderRadius: BorderRadius.circular(ui(6)),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                _SegmentToggleItem(
                  option: options[i],
                  selected: i == safeIndex,
                  fontSize: fontSize,
                  onTap: options[i].enabled ? () => onChanged(i) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentToggleItem extends StatelessWidget {
  const _SegmentToggleItem({
    required this.option,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });

  final SegmentToggleOption option;
  final bool selected;
  final double fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final Color textColor = selected
        ? Colors.white
        : (option.enabled ? const Color(0xFF000000) : const Color(0xFFC9C8CE));
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(14)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                option.label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: textColor,
                  fontSize: ui(fontSize),
                  fontFamily: 'PingFang SC',
                  fontWeight: selected ? AppFont.w500 : AppFont.w400,
                  height: 1,
                ),
              ),
              if (option.badge != null && option.badge!.isNotEmpty) ...[
                SizedBox(width: ui(6)),
                _SegmentBadge(text: option.badge!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentBadge extends StatelessWidget {
  const _SegmentBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      constraints: BoxConstraints(minWidth: ui(16)),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: ui(5), vertical: ui(1)),
      decoration: BoxDecoration(
        color: const Color(0xFFF04545),
        borderRadius: BorderRadius.circular(ui(20)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(10),
          color: Colors.white,
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}
