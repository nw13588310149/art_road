import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_font.dart';
import 'app_colors.dart';
import 'app_motion.dart';
import 'app_pressable.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// [AppSelect] 的单个选项。
class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
}

/// 下拉选择：34 高字段，点击后在字段下方（空间不够时在上方）弹出选项菜单。
///
/// 菜单淡入 180ms；选中项为品牌紫文字 + 对勾，不加底色。
class AppSelect<T> extends StatefulWidget {
  const AppSelect({
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint = '请选择',
    this.size = AppControlSize.md,
    this.enabled = true,
    this.menuMaxHeight = 280,
    super.key,
  });

  final List<AppSelectOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String hint;
  final AppControlSize size;
  final bool enabled;
  final double menuMaxHeight;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  bool _open = false;

  AppSelectOption<T>? get _selected {
    for (final option in widget.options) {
      if (option.value == widget.value) {
        return option;
      }
    }
    return null;
  }

  Future<void> _openMenu() async {
    final box = context.findRenderObject() as RenderBox?;
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlayBox =
        navigator.overlay?.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null || widget.options.isEmpty) {
      return;
    }
    final anchor =
        box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    setState(() => _open = true);
    final picked = await navigator.push<AppSelectOption<T>>(
      _SelectMenuRoute<T>(
        anchor: anchor,
        options: widget.options,
        value: widget.value,
        maxHeight: widget.menuMaxHeight,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _open = false);
    if (picked != null) {
      widget.onChanged(picked.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final md = widget.size == AppControlSize.md;
    final selected = _selected;
    final textStyle = md ? AppText.body14 : AppText.body13;
    return AppPressable(
      onTap: _openMenu,
      enabled: widget.enabled,
      child: Container(
        height: md ? AppSize.control : AppSize.controlSm,
        padding: const EdgeInsets.only(left: AppSpace.s12, right: AppSpace.s8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br8,
          border: Border.all(color: _open ? AppColors.brand : AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.label ?? widget.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle.copyWith(
                  color: selected == null
                      ? AppColors.textPlaceholder
                      : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s4),
            Icon(
              _open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectMenuRoute<T> extends PopupRoute<AppSelectOption<T>> {
  _SelectMenuRoute({
    required this.anchor,
    required this.options,
    required this.value,
    required this.maxHeight,
  });

  final Rect anchor;
  final List<AppSelectOption<T>> options;
  final T? value;
  final double maxHeight;

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
    final width = math.min(
      math.max(anchor.width, 120.0),
      screen.width - 2 * _edge,
    );
    final natural = options.length * _rowHeight + 2 * _panelPadding;
    final spaceBelow = screen.height - anchor.bottom - _gap - _edge;
    final spaceAbove = anchor.top - _gap - _edge;
    final below =
        spaceBelow >= math.min(natural, maxHeight) || spaceBelow >= spaceAbove;
    final limit = math.max(
      _rowHeight + 2 * _panelPadding,
      math.min(maxHeight, below ? spaceBelow : spaceAbove),
    );
    final left = anchor.left
        .clamp(_edge, math.max(_edge, screen.width - width - _edge))
        .toDouble();

    return Stack(
      children: [
        Positioned(
          left: left,
          width: width,
          top: below ? anchor.bottom + _gap : null,
          bottom: below ? null : screen.height - anchor.top + _gap,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: limit),
            child: Material(
              type: MaterialType.transparency,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.br12,
                  border: Border.all(color: AppColors.lineSoft),
                  boxShadow: AppShadow.popover,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(_panelPadding),
                  children: [
                    for (final option in options)
                      _SelectMenuRow(
                        label: option.label,
                        selected: option.value == value,
                        enabled: option.enabled,
                        onTap: () => Navigator.of(context).pop(option),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectMenuRow extends StatelessWidget {
  const _SelectMenuRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      enabled: enabled,
      selected: selected,
      child: Container(
        height: _SelectMenuRoute._rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body14.copyWith(
                  color: selected ? AppColors.brand : AppColors.ink,
                  fontWeight: selected ? AppFont.w500 : AppFont.w400,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 16, color: AppColors.brand),
          ],
        ),
      ),
    );
  }
}
