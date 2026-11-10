import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_assets.dart';
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
    final enabled = !state.isSendingSms;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppIconInputField(
            controller: controller,
            iconAsset: AppAssets.authSms,
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
        AppPressable(
          enabled: enabled,
          onTap: onSend,
          child: Container(
            width: 117,
            height: AppSize.buttonMd,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF0D1535),
              borderRadius: AppRadius.br12,
            ),
            child: Text(
              state.smsButtonText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body14.copyWith(color: AppColors.onBrand),
            ),
          ),
        ),
      ],
    );
  }
}
