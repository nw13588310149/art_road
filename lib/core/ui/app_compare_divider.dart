import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_compare_controller.dart';

/// 对比的分隔条：44 宽的拖动区域，里面一条细线和一个白色把手。
/// 左右方向键微调，Home 或双击复位；读屏当作滑块「对比分隔线」。
class AppCompareDivider extends StatelessWidget {
  const AppCompareDivider({
    required this.value,
    required this.onDrag,
    required this.onChanged,
    required this.onReset,
    super.key,
  });

  /// 分隔条位置，[min]–[max]。
  final double value;

  /// 拖动的横向位移（逻辑像素）。
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  static const double min = AppCompareController.splitMin;
  static const double max = AppCompareController.splitMax;
  static const double extent = 44;

  @override
  Widget build(BuildContext context) {
    final decreased = (value - 0.05).clamp(min, max);
    final increased = (value + 0.05).clamp(min, max);
    String percent(double fraction) => '${(fraction * 100).round()}%';
    void decrease() => onChanged(decreased);
    void increase() => onChanged(increased);
    void reset() => onReset();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): decrease,
        const SingleActivator(LogicalKeyboardKey.arrowRight): increase,
        const SingleActivator(LogicalKeyboardKey.home): reset,
      },
      child: Focus(
        child: Semantics(
          slider: true,
          label: '对比分隔线',
          value: percent(value),
          decreasedValue: value > min ? percent(decreased) : null,
          increasedValue: value < max ? percent(increased) : null,
          onDecrease: value > min ? decrease : null,
          onIncrease: value < max ? increase : null,
          onTap: reset,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
              onDoubleTap: reset,
              child: Builder(
                builder: (context) {
                  final focused = Focus.of(context).hasFocus;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 1, color: AppColors.textTertiary),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: focused ? AppColors.ink : AppColors.line,
                          ),
                        ),
                        child: const Icon(
                          Icons.compare_arrows_rounded,
                          size: 18,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
