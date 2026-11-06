import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_text_field.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 表单输入框：可选标题、占位、错误提示、字数计数，支持多行。
///
/// 单行 34 高（sm 30），白底 1px 描边，聚焦转品牌紫、出错转红色，均立即切换。
/// 只读为浅灰底。底层仍是 `core/widgets/app_text_field.dart` 的 [AppTextField]，
/// 需要完全自定义样式的输入（如聊天输入条）直接用它。
class AppInputField extends StatefulWidget {
  const AppInputField({
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.maxLength,
    this.multiline = false,
    this.minLines = 3,
    this.maxLines = 6,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.size = AppControlSize.md,
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;

  /// 非空时描边转红并在下方显示。
  final String? errorText;

  /// 设置后限制字数并在右下角显示「已输入 / 上限」。
  final int? maxLength;
  final bool multiline;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;

  /// 标题前加红色星号。
  final bool required;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;
  final AppControlSize size;

  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField> {
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
  void didUpdateWidget(covariant AppInputField oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final md = widget.size == AppControlSize.md;
    final error = widget.errorText;
    final hasError = error != null && error.isNotEmpty;
    final maxLength = widget.maxLength;
    final label = widget.label;
    final textStyle = (md ? AppText.body14 : AppText.body13).copyWith(
      color: AppColors.ink,
    );
    final borderColor = hasError
        ? AppColors.danger
        : (_focusNode.hasFocus && !widget.readOnly
              ? AppColors.brand
              : AppColors.line);

    final input = AppTextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      keyboardType:
          widget.keyboardType ??
          (widget.multiline ? TextInputType.multiline : TextInputType.text),
      textInputAction:
          widget.textInputAction ??
          (widget.multiline ? TextInputAction.newline : TextInputAction.done),
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      maxLength: maxLength,
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              null,
      minLines: widget.multiline ? widget.minLines : 1,
      maxLines: widget.multiline ? widget.maxLines : 1,
      style: textStyle,
      cursorColor: AppColors.brand,
      cursorWidth: 1.5,
      cursorHeight: (textStyle.fontSize ?? 14) + 2,
      textAlignVertical: widget.multiline
          ? TextAlignVertical.top
          : TextAlignVertical.center,
      decoration: InputDecoration.collapsed(
        hintText: widget.hint,
        hintStyle: textStyle.copyWith(color: AppColors.textPlaceholder),
        hintFadeDuration: Duration.zero,
      ),
    );

    final box = Container(
      constraints: BoxConstraints(
        minHeight: md ? AppSize.control : AppSize.controlSm,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: widget.multiline ? AppSpace.s8 : 0,
      ),
      alignment: widget.multiline ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: widget.readOnly ? AppColors.surfaceSubtle : AppColors.surface,
        borderRadius: AppRadius.br8,
        border: Border.all(color: borderColor),
      ),
      child: input,
    );

    final showFooter = hasError || maxLength != null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label.isNotEmpty) ...[
          Text.rich(
            TextSpan(
              children: [
                if (widget.required)
                  TextSpan(
                    text: '* ',
                    style: AppText.body14.copyWith(color: AppColors.danger),
                  ),
                TextSpan(text: label, style: AppText.body14),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        box,
        if (showFooter) ...[
          const SizedBox(height: AppSpace.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: hasError
                    ? Text(
                        error,
                        style: AppText.caption12.copyWith(
                          color: AppColors.danger,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (maxLength != null)
                Text(
                  '${_controller.text.characters.length}/$maxLength',
                  style: AppText.number(
                    size: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
    return widget.enabled
        ? content
        : Opacity(opacity: AppOpacity.disabled, child: content);
  }
}
