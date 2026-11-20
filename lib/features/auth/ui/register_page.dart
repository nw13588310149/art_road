import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/ui/ui.dart';
import '../state/auth_controller.dart';
import '../state/auth_state.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_sms_code_row.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  AuthController get _controller =>
      ref.read(authControllerProvider(AuthScene.register).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider(AuthScene.register));
    final controller = _controller;
    final passwordError = state.errorOf(AuthField.password);

    return AuthPageFrame(
      card: AuthCard(
        title: '账号注册',
        bottomPadding: 45,
        children: [
          AppIconInputField(
            iconAsset: AppAssets.authPhone,
            hint: '请输入手机号',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            errorText: state.errorOf(AuthField.mobile),
            onChanged: controller.setMobile,
          ),
          const SizedBox(height: 21),
          AuthSmsCodeRow(
            state: state,
            onChanged: controller.setSmsCode,
            onSend: _onSendSms,
          ),
          const SizedBox(height: 21),
          AppIconInputField(
            iconAsset: AppAssets.authPassword,
            hint: '请设置密码',
            obscureText: true,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              LengthLimitingTextInputFormatter(
                AuthController.passwordMaxLength,
              ),
            ],
            errorText: passwordError,
            onChanged: controller.setPassword,
          ),
          const SizedBox(height: 21),
          AppIconInputField(
            iconAsset: AppAssets.authPassword,
            hint: '请再次输入密码',
            obscureText: true,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              LengthLimitingTextInputFormatter(
                AuthController.passwordMaxLength,
              ),
            ],
            errorText: state.errorOf(AuthField.confirmPassword),
            onChanged: controller.setConfirmPassword,
            onSubmitted: (_) => _onRegister(),
          ),
          if (passwordError == null) ...[
            const SizedBox(height: 11),
            Text(
              '密码为 8–64 位，建议同时包含字母和数字',
              style: AppText.caption12.copyWith(height: 1),
            ),
          ],
          const SizedBox(height: 23),
          AuthPrimaryButton(
            label: '立即注册',
            loading: state.isSubmitting,
            onTap: _onRegister,
          ),
          const SizedBox(height: 30),
          AuthAgreementRow(
            checked: state.agreeTerms,
            onChanged: controller.setAgreeTerms,
            onOpenTerms: _openTerms,
          ),
          const SizedBox(height: 37),
          AuthSwitchLine(
            prompt: '已有账号？',
            action: '立即登录',
            divided: false,
            onTap: _backToLogin,
          ),
        ],
      ),
    );
  }

  void _backToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(RoutePaths.login);
    }
  }

  Future<void> _openTerms(AuthTermsSection section) async {
    final agreed = await openAuthTerms(context, section);
    if (agreed && mounted) {
      _controller.setAgreeTerms(true);
    }
  }

  Future<void> _onSendSms() async {
    final result = await _controller.sendSms();
    if (!mounted || result.field != null) {
      return;
    }
    AppToast.show(context, result.message);
  }

  Future<void> _onRegister() async {
    final controller = _controller;
    var result = await controller.submitRegister();
    if (!mounted) {
      return;
    }
    if (result.field == AuthField.terms) {
      final agreed = await showAuthTermsDialog(context, confirmLabel: '同意并注册');
      if (!agreed || !mounted) {
        return;
      }
      controller.setAgreeTerms(true);
      result = await controller.submitRegister();
      if (!mounted) {
        return;
      }
    }
    if (result.field != null) {
      return;
    }
    AppToast.show(context, result.message);
    if (result.success) {
      Navigator.pushReplacementNamed(context, RoutePaths.login);
    }
  }
}
