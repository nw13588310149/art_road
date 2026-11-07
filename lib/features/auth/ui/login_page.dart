import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/demo/demo_accounts.dart';
import '../../../core/demo/demo_config.dart';
import '../../../core/demo/demo_store.dart';
import '../../../core/ui/ui.dart';
import '../../../features/shell/state/school_binding_controller.dart';
import '../../../features/shell/state/shell_controller.dart';
import '../../ai_chat/state/ai_chat_controller.dart';
import '../state/auth_controller.dart';
import '../state/auth_state.dart';
import 'widgets/auth_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  AuthController get _controller =>
      ref.read(authControllerProvider(AuthScene.login).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider(AuthScene.login));
    final controller = _controller;

    return AuthPageFrame(
      card: AuthCard(
        title: '账号登录',
        subtitle: '使用手机号和密码登录美术之路',
        children: [
          AppIconInputField(
            icon: Icons.phone_iphone_rounded,
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
          const SizedBox(height: AppSpace.s12),
          AppIconInputField(
            icon: Icons.lock_outline_rounded,
            hint: '请输入密码',
            obscureText: true,
            textInputAction: TextInputAction.done,
            errorText: state.errorOf(AuthField.password),
            onChanged: controller.setPassword,
            onSubmitted: (_) => _onLogin(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: '忘记密码？',
              variant: AppButtonVariant.text,
              size: AppButtonSize.sm,
              onTap: () => Navigator.pushNamed(context, RoutePaths.forget),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton(
            label: '立即登录',
            expand: true,
            loading: state.isSubmitting,
            onTap: _onLogin,
          ),
          const SizedBox(height: AppSpace.s12),
          AuthAgreementRow(
            checked: state.agreeTerms,
            onChanged: controller.setAgreeTerms,
            onOpenTerms: _openTerms,
          ),
          const SizedBox(height: AppSpace.s12),
          AuthSwitchLine(
            prompt: '没有账号？',
            action: '立即注册',
            onTap: () => Navigator.pushNamed(context, RoutePaths.register),
          ),
        ],
      ),
      below: kDemoMode
          ? _DemoIdentityPanel(
              enabled: !state.isSubmitting,
              onPick: _onDemoLogin,
              onReset: _onDemoReset,
            )
          : null,
    );
  }

  Future<void> _openTerms(AuthTermsSection section) async {
    final agreed = await openAuthTerms(context, section);
    if (agreed && mounted) {
      _controller.setAgreeTerms(true);
    }
  }

  Future<void> _onLogin() async {
    final controller = _controller;
    var result = await controller.submitLogin();
    if (!mounted) {
      return;
    }
    if (result.field == AuthField.terms) {
      final agreed = await showAuthTermsDialog(context, confirmLabel: '同意并登录');
      if (!agreed || !mounted) {
        return;
      }
      controller.setAgreeTerms(true);
      result = await controller.submitLogin();
      if (!mounted) {
        return;
      }
    }
    if (result.field != null) {
      return;
    }
    AppToast.show(context, result.message);
    if (result.success) {
      _enterApp();
    }
  }

  Future<void> _onDemoLogin(DemoAccount account) async {
    final result = await _controller.submitDemoLogin(account.mobile);
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      result.success ? '已以「${account.role.label}」身份进入演示' : result.message,
    );
    if (result.success) {
      _enterApp();
    }
  }

  Future<void> _onDemoReset() async {
    final confirmed = await showAppConfirm(
      context: context,
      title: '重置演示数据',
      message: '将清除本机上传的作品、点评、笔记、收藏、请假等演示写入，恢复到初始演示数据。',
      confirmLabel: '重置',
      danger: true,
    );
    if (!confirmed) {
      return;
    }
    await DemoStore.reset();
    if (!mounted) {
      return;
    }
    AppToast.showSuccess(context, '演示数据已恢复初始状态');
  }

  void _enterApp() {
    ref.invalidate(aiChatControllerProvider);
    // 登录成功后立即预热 ShellController（触发 myInfo/mySchool 并行请求），
    // 使菜单和头像在导航动画期间就已在飞，进入主框架时第一时间呈现。
    final shell = ref.read(shellControllerProvider.notifier);
    unawaited(shell.refreshUserAndSchool());
    shell.resumePolling();
    // 同步触发「绑定学校」轮询：构造控制器即开始 5s 一次的 schoolList
    // 检查，未绑定时 ShellScaffold 进场即可弹出强制绑定遮罩。
    ref.read(schoolBindingControllerProvider.notifier).refresh();
    Navigator.pushReplacementNamed(context, RoutePaths.home);
  }
}

/// 演示版「体验身份」：一键以学生 / 老师 / 班主任 / 宿管 / 管理员身份进入。
///
/// 五个身份同一样式，不预设选中；演示身份只读写本机演示数据。
class _DemoIdentityPanel extends StatelessWidget {
  const _DemoIdentityPanel({
    required this.enabled,
    required this.onPick,
    required this.onReset,
  });

  final bool enabled;
  final ValueChanged<DemoAccount> onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.panel,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s12,
        AppSpace.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '演示版 · 选择体验身份（无需密码）',
                  style: AppText.caption12Strong,
                ),
              ),
              AppButton(
                label: '重置演示数据',
                variant: AppButtonVariant.text,
                size: AppButtonSize.sm,
                onTap: enabled ? onReset : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final account in DemoAccounts.all)
                AppButton(
                  label: '${account.role.label} · ${account.name}',
                  variant: AppButtonVariant.quiet,
                  size: AppButtonSize.sm,
                  onTap: enabled ? () => onPick(account) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
