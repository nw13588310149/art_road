import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/app_asset_graphic.dart';
import 'app_colors.dart';
import 'app_motion.dart';
import 'app_pressable.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// [showAppMenu] 的单个操作项；[danger] 用于删除等不可撤销操作（红字）。
class AppMenuItem<T> {
  const AppMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.iconAsset,
    this.danger = false,
    this.enabled = true,
  }) : assert(icon == null || iconAsset == null);

  final T value;
  final String label;
  final IconData? icon;
  final String? iconAsset;
  final bool danger;
  final bool enabled;
}

/// 操作菜单（「···」更多操作）：在 [context] 对应组件的下方弹出，空间不够时在上方；
/// 超出右边界时与组件右边对齐。白底圆角 12、行高 36、popover 阴影，淡入 180ms。
///
/// [context] 传触发按钮自身的 context（可用 `Builder` 包一层取得）。点遮罩关闭返回 null。
Future<T?> showAppMenu<T>({
  required BuildContext context,
  required List<AppMenuItem<T>> items,
  double width = 160,
}) {
  final box = context.findRenderObject() as RenderBox?;
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlayBox =
      navigator.overlay?.context.findRenderObject() as RenderBox?;
  if (box == null || overlayBox == null || items.isEmpty) {
    return Future<T?>.value();
  }
  final anchor =
      box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
  return navigator.push<T>(
    _AppMenuRoute<T>(anchor: anchor, items: items, width: width),
  );
}

class _AppMenuRoute<T> extends PopupRoute<T> {
  _AppMenuRoute({
    required this.anchor,
    required this.items,
    required this.width,
  });

  final Rect anchor;
  final List<AppMenuItem<T>> items;
  final double width;

  static const double _rowHeight = 36;
  static const double _panelPadding = 6;
  static const double _gap = 4;
  static const double _edge = 8;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '关闭';

  @override
  Duration get transitionDuration => AppMotion.overlay;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: AppMotion.overlayCurve,
      ),
      child: child,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final screen = MediaQuery.sizeOf(context);
    final panelWidth = math.min(width, screen.width - 2 * _edge);
    final natural = items.length * _rowHeight + 2 * _panelPadding;
    final spaceBelow = screen.height - anchor.bottom - _gap - _edge;
    final below = spaceBelow >= natural || spaceBelow >= anchor.top;
    final preferLeft = anchor.left + panelWidth <= screen.width - _edge;
    final left = (preferLeft ? anchor.left : anchor.right - panelWidth)
        .clamp(_edge, math.max(_edge, screen.width - panelWidth - _edge))
        .toDouble();

    return Stack(
      children: [
        Positioned(
          left: left,
          width: panelWidth,
          top: below ? anchor.bottom + _gap : null,
          bottom: below ? null : screen.height - anchor.top + _gap,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(_panelPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.br12,
                border: Border.all(color: AppColors.lineSoft),
                boxShadow: AppShadow.popover,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    _AppMenuRow(
                      item: item,
                      onTap: () => Navigator.of(context).pop(item.value),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppMenuRow extends StatelessWidget {
  const _AppMenuRow({required this.item, required this.onTap});

  final AppMenuItem<Object?> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? AppColors.danger : AppColors.ink;
    final icon = item.icon;
    final iconAsset = item.iconAsset;
    return AppPressable(
      onTap: onTap,
      enabled: item.enabled,
      child: Container(
        height: _AppMenuRoute._rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (iconAsset != null || icon != null) ...[
              if (iconAsset != null)
                AppAssetGraphic(iconAsset, width: 18, height: 18)
              else
                Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpace.s8),
            ],
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body14.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
