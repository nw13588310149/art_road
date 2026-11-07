import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../state/auth_controller.dart';
import '../state/auth_state.dart';
import 'widgets/auth_layout.dart';
import 'widgets/auth_sms_code_row.dart';

enum _ForgetStep {
  mobile('验证手机号'),
  sms('输入验证码'),
  password('设置新密码');

  const _ForgetStep(this.label);

  final String label;
}

class ForgetPasswordPage extends ConsumerStatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  ConsumerState<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends ConsumerState<ForgetPasswordPage> {
  _ForgetStep _step = _ForgetStep.mobile;

  // 三步分屏显示，输入框重建后仍保留已填内容（返回上一步时可见）。
  final _mobile = TextEditingController();
  final _smsCode = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  AuthController get _controller =>
      ref.read(authControllerProvider(AuthScene.forgetPassword).notifier);

  @override
  void dispose() {
    _mobile.dispose();
    _smsCode.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider(AuthScene.forgetPassword));
    final total = _ForgetStep.values.length;

    return AuthPageFrame(
      card: AuthCard(
        title: '找回密码',
        subtitle: '第 ${_step.index + 1} 步（共 $total 步）：${_step.label}',
        children: [
          ...switch (_step) {
            _ForgetStep.mobile => _mobileStep(state),
            _ForgetStep.sms => _smsStep(state),
            _ForgetStep.password => _passwordStep(state),
          },
          const SizedBox(height: AppSpace.s20),
          AppButton(
            label: _step == _ForgetStep.password ? '确认修改' : '下一步',
            expand: true,
            loading: state.isSubmitting,
            onTap: _onPrimaryTap,
          ),
          const SizedBox(height: AppSpace.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_step != _ForgetStep.mobile) ...[
                AppButton(
                  label: '上一步',
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.sm,
                  onTap: () => setState(
                    () => _step = _ForgetStep.values[_step.index - 1],
                  ),
                ),
                const SizedBox(width: AppSpace.s16),
              ],
              AppButton(
                label: '返回登录',
                variant: AppButtonVariant.text,
                size: AppButtonSize.sm,
                onTap: _backToLogin,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _mobileStep(AuthState state) {
    return [
      AppIconInputField(
        key: const ValueKey('mobile'),
        controller: _mobile,
        icon: Icons.phone_iphone_rounded,
        hint: '请输入注册时使用的手机号',
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ],
        errorText: state.errorOf(AuthField.mobile),
        onChanged: _controller.setMobile,
        onSubmitted: (_) => _onPrimaryTap(),
      ),
    ];
  }

  List<Widget> _smsStep(AuthState state) {
    return [
      Text(
        '点击「获取验证码」，验证码将以短信发送到 ${_maskMobile(state.mobile)}。',
        style: AppText.body13,
      ),
      const SizedBox(height: AppSpace.s12),
      AuthSmsCodeRow(
        key: const ValueKey('smsCode'),
        controller: _smsCode,
        state: state,
        onChanged: _controller.setSmsCode,
        onSend: _onSendSms,
      ),
    ];
  }

  List<Widget> _passwordStep(AuthState state) {
    final passwordError = state.errorOf(AuthField.password);
    return [
      AppIconInputField(
        key: const ValueKey('password'),
        controller: _password,
        icon: Icons.lock_outline_rounded,
        hint: '请输入新密码',
        obscureText: true,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          LengthLimitingTextInputFormatter(AuthController.passwordMaxLength),
        ],
        errorText: passwordError,
        onChanged: _controller.setPassword,
      ),
      if (passwordError == null) ...[
        const SizedBox(height: AppSpace.s4),
        Text('密码为 6–20 位，建议同时包含字母和数字', style: AppText.caption12),
      ],
      const SizedBox(height: AppSpace.s12),
      AppIconInputField(
        key: const ValueKey('confirmPassword'),
        controller: _confirmPassword,
        icon: Icons.lock_outline_rounded,
        hint: '请再次输入新密码',
        obscureText: true,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          LengthLimitingTextInputFormatter(AuthController.passwordMaxLength),
        ],
        errorText: state.errorOf(AuthField.confirmPassword),
        onChanged: _controller.setConfirmPassword,
        onSubmitted: (_) => _onPrimaryTap(),
      ),
    ];
  }

  Future<void> _onPrimaryTap() async {
    final controller = _controller;
    switch (_step) {
      case _ForgetStep.mobile:
        if (controller.validateMobileStep().success) {
          setState(() => _step = _ForgetStep.sms);
        }
        return;
      case _ForgetStep.sms:
        if (controller.validateSmsStep().success) {
          setState(() => _step = _ForgetStep.password);
        }
        return;
      case _ForgetStep.password:
        final result = await controller.submitForgetPassword();
        if (!mounted || result.field != null) {
          return;
        }
        AppToast.show(context, result.message);
        if (result.success) {
          _backToLogin();
        }
        return;
    }
  }

  Future<void> _onSendSms() async {
    final result = await _controller.sendSms();
    if (!mounted || result.field != null) {
      return;
    }
    AppToast.show(context, result.message);
  }

  void _backToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(RoutePaths.login);
    }
  }

  static String _maskMobile(String mobile) {
    if (mobile.length != 11) {
      return mobile;
    }
    return '${mobile.substring(0, 3)}****${mobile.substring(7)}';
  }
}
