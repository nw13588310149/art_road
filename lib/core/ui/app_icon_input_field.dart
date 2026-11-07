import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_text_field.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 带前置图标的单行输入框，45 高，与 [AppButtonSize.md] 按钮等高。
///
/// 用于登录、注册、找回密码这类输入框与主按钮上下排列的表单（艺考网机构端登录页
/// 同样是唯一放大输入框的地方）；普通表单仍用 34 高的 [AppInputField]。
/// 白底、1px 描边、圆角 12，聚焦立即转品牌紫，
/// 出错立即转红并在下方说明原因。[obscureText] 为 true 时右侧带「显示 / 隐藏密码」。
class AppIconInputField extends StatefulWidget {
  const AppIconInputField({
    required this.icon,
    this.controller,
    this.hint,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  final IconData icon;
  final TextEditingController? controller;
  final String? hint;

  /// 非空时描边转红并在下方显示。
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  /// 密码输入：默认隐藏内容，右侧可切换显示。
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<AppIconInputField> createState() => _AppIconInputFieldState();
}

class _AppIconInputFieldState extends State<AppIconInputField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  bool _revealed = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant AppIconInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_refresh);
      _focusNode.addListener(_refresh);
    }
  }

  @override
  void dispose() {
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
    final error = widget.errorText;
    final hasError = error != null && error.isNotEmpty;
    final textStyle = AppText.body14.copyWith(color: AppColors.ink);
    final borderColor = hasError
        ? AppColors.danger
        : (_focusNode.hasFocus ? AppColors.brand : AppColors.lineSoft);

    final box = Container(
      height: AppSize.buttonMd,
      padding: EdgeInsets.only(
        left: AppSpace.s12,
        right: widget.obscureText ? AppSpace.s4 : AppSpace.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: AppTextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              obscureText: widget.obscureText && !_revealed,
              autocorrect: false,
              enableSuggestions: !widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              inputFormatters: widget.inputFormatters,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              maxLines: 1,
              style: textStyle,
              cursorColor: AppColors.brand,
              cursorWidth: 1.5,
              cursorHeight: 16,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: textStyle.copyWith(color: AppColors.textPlaceholder),
                hintFadeDuration: Duration.zero,
              ),
            ),
          ),
          if (widget.obscureText)
            AppPressable(
              onTap: widget.enabled
                  ? () => setState(() => _revealed = !_revealed)
                  : null,
              semanticLabel: _revealed ? '隐藏密码' : '显示密码',
              toggled: _revealed,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  _revealed
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );

    final content = hasError
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              box,
              const SizedBox(height: AppSpace.s4),
              Text(
                error,
                style: AppText.caption12.copyWith(color: AppColors.danger),
              ),
            ],
          )
        : box;
    return widget.enabled
        ? content
        : Opacity(opacity: AppOpacity.disabled, child: content);
  }
}
