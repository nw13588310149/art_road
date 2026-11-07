import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../state/auth_state.dart';

/// 短信验证码输入 + 「获取验证码」次按钮；倒计时期间按钮禁用并显示「60 秒后重发」。
class AuthSmsCodeRow extends StatelessWidget {
  const AuthSmsCodeRow({
    required this.state,
    required this.onChanged,
    required this.onSend,
    this.controller,
    super.key,
  });

  final AuthState state;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppIconInputField(
            controller: controller,
            icon: Icons.sms_outlined,
            hint: '请输入短信验证码',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            errorText: state.errorOf(AuthField.smsCode),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        SizedBox(
          width: 120,
          child: AppButton(
            label: state.smsButtonText,
            variant: AppButtonVariant.secondary,
            expand: true,
            onTap: state.isSendingSms ? null : onSend,
          ),
        ),
      ],
    );
  }
}
