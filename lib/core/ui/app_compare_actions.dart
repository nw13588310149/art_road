import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_compare_controller.dart';
import 'app_plain_button.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';
import 'app_title_bar.dart';
import 'app_view_tabs.dart';

/// 并排 / 滑动 / 叠加：放在页头的 `AppViewTabs`，只列 [AppCompareController.modes]。
class AppCompareModeTabs extends StatelessWidget {
  const AppCompareModeTabs({required this.controller, super.key});

  final AppCompareController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AppViewTabs<AppCompareMode>(
        items: [
          for (final mode in controller.modes)
            AppViewTab(value: mode, label: mode.label),
        ],
        value: controller.mode,
        onChanged: controller.setMode,
      ),
    );
  }
}

/// 对比画布下面那一行（设计语言第八、九节）：左边一句随看法和锁定变化的提示，
/// 右边是 [AppCompareActions]。高 44。
class AppCompareFooter extends StatelessWidget {
  const AppCompareFooter({required this.controller, super.key});

  final AppCompareController controller;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12,
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            AppCompareActions(controller: controller),
          ],
        ),
      ),
    );
  }
}

/// 对比画布自己的操作：叠加时的上层深浅、锁定、旋转、翻转、交换、复位。
///
/// 锁定是开关，开着时墨色实心锁，关着时二级色开锁，不用品牌紫。[compact] 时
/// 只放锁定和复位两个图标（工具箱的画布下面还有工具自己的提示）。
class AppCompareActions extends StatelessWidget {
  const AppCompareActions({
    required this.controller,
    this.compact = false,
    super.key,
  });

  final AppCompareController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final reset = c.isPristine ? null : c.reset;
        if (compact) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconAction(
                icon: Icons.lock_open_rounded,
                activeIcon: Icons.lock_rounded,
                active: c.locked,
                activeColor: AppColors.ink,
                semanticLabel: '锁定两侧',
                onTap: c.toggleLock,
              ),
              AppIconAction(
                icon: Icons.restart_alt_rounded,
                semanticLabel: '复位缩放',
                onTap: reset,
              ),
            ],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.mode == AppCompareMode.overlay) ...[
              AppCompareOpacitySlider(
                value: c.overlayOpacity,
                onChanged: c.setOverlayOpacity,
              ),
              const SizedBox(width: AppSpace.s12),
            ],
            _LockToggle(locked: c.locked, onTap: c.toggleLock),
            if (c.canRotate)
              AppIconAction(
                icon: Icons.rotate_90_degrees_cw_outlined,
                semanticLabel: '旋转 90°',
                onTap: c.rotate,
              ),
            if (c.canFlip) ...[
              AppIconAction(
                icon: Icons.flip_rounded,
                semanticLabel: '左右翻转',
                onTap: c.flipHorizontal,
              ),
              RotatedBox(
                quarterTurns: 1,
                child: AppIconAction(
                  icon: Icons.flip_rounded,
                  semanticLabel: '上下翻转',
                  onTap: c.flipVertical,
                ),
              ),
            ],
            if (c.canSwap)
              AppIconAction(
                icon: Icons.swap_horiz_rounded,
                semanticLabel: '交换左右',
                onTap: c.swap,
              ),
            AppPlainButton(
              label: '复位',
              icon: Icons.restart_alt_rounded,
              semanticLabel: '复位缩放和摆放',
              onTap: reset,
            ),
          ],
        );
      },
    );
  }
}

/// 锁定开关：一个锁和「锁定」两个字，点击区域 44 高。
class _LockToggle extends StatelessWidget {
  const _LockToggle({required this.locked, required this.onTap});

  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = locked ? AppColors.ink : AppColors.textSecondary;
    return Tooltip(
      message: locked ? '已锁定：两侧一起缩放和旋转' : '未锁定：两侧各自操作',
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onTap,
        toggled: locked,
        semanticLabel: '锁定两侧',
        child: Container(
          height: AppPlainButton.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: AppSpace.s4),
                Text('锁定', style: AppText.body14Strong.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 叠加时上层的不透明度：「上层」、一条 120 宽的滑条和百分比。已选段是墨色。
/// 拖动或点击设置，左右方向键每次 10%；读屏当作滑块「上层不透明度」。
class AppCompareOpacitySlider extends StatelessWidget {
  const AppCompareOpacitySlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;

  static const double trackWidth = 120;
  static const double _thumb = 16;

  @override
  Widget build(BuildContext context) {
    String percent(double v) => '${(v * 100).round()}%';
    final decreased = (value - 0.1).clamp(0.0, 1.0);
    final increased = (value + 0.1).clamp(0.0, 1.0);
    void decrease() => onChanged(decreased);
    void increase() => onChanged(increased);
    void setAt(double dx) =>
        onChanged(((dx - _thumb / 2) / (trackWidth - _thumb)).clamp(0.0, 1.0));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Text('上层', style: AppText.caption12)),
        const SizedBox(width: AppSpace.s8),
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): decrease,
            const SingleActivator(LogicalKeyboardKey.arrowRight): increase,
          },
          child: Focus(
            child: Semantics(
              slider: true,
              label: '上层不透明度',
              value: percent(value),
              decreasedValue: value > 0 ? percent(decreased) : null,
              increasedValue: value < 1 ? percent(increased) : null,
              onDecrease: value > 0 ? decrease : null,
              onIncrease: value < 1 ? increase : null,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => setAt(details.localPosition.dx),
                  onHorizontalDragUpdate: (details) =>
                      setAt(details.localPosition.dx),
                  child: SizedBox(
                    width: trackWidth,
                    height: 44,
                    child: Builder(
                      builder: (context) => CustomPaint(
                        painter: _OpacityTrackPainter(
                          value: value,
                          focused: Focus.of(context).hasFocus,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        SizedBox(
          width: 36,
          child: ExcludeSemantics(
            child: Text(
              percent(value),
              style: AppText.number(size: 13, color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpacityTrackPainter extends CustomPainter {
  const _OpacityTrackPainter({required this.value, required this.focused});

  final double value;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    const thumb = AppCompareOpacitySlider._thumb;
    final y = size.height / 2;
    final start = thumb / 2;
    final end = size.width - thumb / 2;
    final x = start + (end - start) * value;
    final track = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(start, y),
        Offset(end, y),
        track..color = AppColors.textPlaceholder,
      )
      ..drawLine(Offset(start, y), Offset(x, y), track..color = AppColors.ink)
      ..drawCircle(Offset(x, y), thumb / 2, Paint()..color = AppColors.surface)
      ..drawCircle(
        Offset(x, y),
        thumb / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = focused ? 2 : 1
          ..color = AppColors.ink,
      );
  }

  @override
  bool shouldRepaint(_OpacityTrackPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.focused != focused;
}
