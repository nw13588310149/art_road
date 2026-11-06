import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../data/schedule_color_palette.dart';

/// 课表颜色选择：16 色分两行展示（每行 8 个），与产品色板截图一致。
class ScheduleColorSwatchPicker extends StatelessWidget {
  const ScheduleColorSwatchPicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.colors = scheduleColorPalette,
    this.columnsPerRow = 8,
  });

  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelect;
  final int columnsPerRow;

  static const Color _borderColor = Color(0xFFF5F6FA);
  static const Color _selectionRing = Color(0xFF8741FF);

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final rows = _splitRows(colors, columnsPerRow);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) SizedBox(height: ui(14)),
            Row(
              children: [
                for (final color in rows[r])
                  Expanded(
                    child: Center(
                      child: _ScheduleColorSwatch(
                        color: color,
                        isSelected:
                            selected != null &&
                            scheduleColorsEqualRgb(selected!, color),
                        onTap: () => onSelect(color),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<List<Color>> _splitRows(List<Color> source, int columns) {
    if (columns <= 0 || source.isEmpty) return const [];
    final rows = <List<Color>>[];
    for (var i = 0; i < source.length; i += columns) {
      final end = (i + columns > source.length) ? source.length : i + columns;
      rows.add(source.sublist(i, end));
    }
    return rows;
  }
}

class _ScheduleColorSwatch extends StatelessWidget {
  const _ScheduleColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  List<BoxShadow> _glowShadows(double Function(num) scale) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.72),
        blurRadius: scale(10),
        spreadRadius: scale(1),
      ),
      BoxShadow(
        color: ScheduleColorSwatchPicker._selectionRing.withValues(alpha: 0.42),
        blurRadius: scale(16),
        spreadRadius: scale(2),
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.28),
        blurRadius: scale(22),
        spreadRadius: scale(4),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scaleUi = DashboardScaleScope.of(context).ui;
    const dotSize = 22.0;
    const haloPadding = 10.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: scaleUi(dotSize + haloPadding * 2),
        height: scaleUi(dotSize + haloPadding * 2),
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? 1.06 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: scaleUi(dotSize),
              height: scaleUi(dotSize),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.92)
                      : Colors.black.withValues(alpha: 0.08),
                  width: scaleUi(isSelected ? 1.5 : 1),
                ),
                boxShadow: isSelected ? _glowShadows(scaleUi) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
