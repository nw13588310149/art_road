import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../widgets/app_asset_graphic.dart';
import '../widgets/app_text_field.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 搜索框：白底圆角 12，左侧放大镜，有内容时右侧出现清空按钮。
///
/// 聚焦时描边立即转为品牌紫，没有过渡动画。
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    this.controller,
    this.hint = '搜索',
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    this.size = AppControlSize.md,
    this.toolbar = false,
    this.autofocus = false,
    this.focusNode,
    this.enabled = true,
    super.key,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// 点击清空按钮后回调（[onChanged] 也会收到空字符串）。
  final VoidCallback? onCleared;
  final AppControlSize size;
  final bool toolbar;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_refresh);
      _controller.addListener(_refresh);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_refresh);
      _focusNode.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _focusNode.removeListener(_refresh);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final md = widget.size == AppControlSize.md;
    final showClear = widget.enabled && _controller.text.isNotEmpty;
    final textStyle = (md ? AppText.body14 : AppText.body13).copyWith(
      color: AppColors.ink,
    );
    final field = Container(
      height: widget.toolbar
          ? AppSize.iconButton
          : (md ? 36 : AppSize.controlSm),
      padding: EdgeInsets.only(left: md ? 14 : 10, right: showClear ? 2 : 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(
          color: _focusNode.hasFocus
              ? AppColors.brand
              : (widget.toolbar ? AppColors.surface : AppColors.lineSoft),
        ),
      ),
      child: Row(
        children: [
          const AppAssetGraphic(
            AppAssets.shellV2Search,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AppTextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              maxLines: 1,
              style: textStyle,
              cursorColor: AppColors.brand,
              cursorWidth: 1.5,
              cursorHeight: (textStyle.fontSize ?? 14) + 2,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: textStyle.copyWith(color: AppColors.textPlaceholder),
                hintFadeDuration: Duration.zero,
              ),
            ),
          ),
          if (showClear)
            AppPressable(
              onTap: _clear,
              semanticLabel: '清空',
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.cancel_rounded,
                  size: 16,
                  color: AppColors.textPlaceholder,
                ),
              ),
            ),
        ],
      ),
    );
    return widget.enabled
        ? field
        : Opacity(opacity: AppOpacity.disabled, child: field);
  }
}
