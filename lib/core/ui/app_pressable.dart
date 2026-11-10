import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// 所有可点击元素的底座：不透明命中区域 + Web 指针光标 + 按钮语义，没有任何
/// 按压反馈（无水波纹、无高亮、无缩放）。
///
/// - [enabled] 为 false 时整块降到 40% 不透明度且不响应点击；
/// - [onTap] 与 [onLongPress] 都为 null 时只是不响应，外观不变；
/// - [selected] / [checked] / [toggled] 只影响无障碍语义。
class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.semanticLabel,
    this.selected,
    this.checked,
    this.toggled,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final String? semanticLabel;
  final bool? selected;
  final bool? checked;
  final bool? toggled;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _showFocus = false;

  Object? _activate(Intent intent) {
    widget.onTap?.call();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final interactive =
        widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    final keyboardAction = widget.enabled && widget.onTap != null;
    Widget result = widget.child;
    if (interactive) {
      result = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: result,
        ),
      );
    }
    if (!widget.enabled) {
      result = Opacity(opacity: AppOpacity.disabled, child: result);
    }
    return Semantics(
      container: true,
      button: widget.checked == null && widget.toggled == null,
      enabled: interactive,
      selected: widget.selected,
      checked: widget.checked,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: keyboardAction,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: _activate,
          ),
        },
        onShowFocusHighlight: (show) => setState(() => _showFocus = show),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: AppRadius.br8,
            border: keyboardAction && _showFocus
                ? Border.all(color: AppColors.brand, width: 2)
                : null,
          ),
          child: result,
        ),
      ),
    );
  }
}
