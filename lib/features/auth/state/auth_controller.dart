import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config_repository.dart';
import '../../../core/network/chat_socket_service.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider = StateNotifierProvider.autoDispose
    .family<AuthController, AuthState, AuthScene>((ref, scene) {
      final repository = ref.watch(authRepositoryProvider);
      final appConfigRepository = ref.watch(appConfigRepositoryProvider);
      final chatSocket = ref.read(chatSocketServiceProvider);
      return AuthController(
        repository: repository,
        appConfigRepository: appConfigRepository,
        chatSocket: chatSocket,
        scene: scene,
      );
    });

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository repository,
    required AppConfigRepository appConfigRepository,
    required ChatSocketService chatSocket,
    required this.scene,
  }) : _repository = repository,
       _appConfigRepository = appConfigRepository,
       _chatSocket = chatSocket,
       super(const AuthState());

  final AuthRepository _repository;
  final AppConfigRepository _appConfigRepository;
  final ChatSocketService _chatSocket;
  final AuthScene scene;

  Timer? _timer;

  static final _mobileReg = RegExp(r'^\d{11}$');
  static const passwordMinLength = 6;
  static const passwordMaxLength = 20;
  static const _ok = AuthActionResult(success: true, message: '');

  void setMobile(String value) {
    state = state.copyWith(
      mobile: value.trim(),
      clearError: state.errorField == AuthField.mobile,
    );
  }

  void setPassword(String value) {
    state = state.copyWith(
      password: value,
      clearError:
          state.errorField == AuthField.password ||
          state.errorField == AuthField.confirmPassword,
    );
  }

  void setConfirmPassword(String value) {
    state = state.copyWith(
      confirmPassword: value,
      clearError: state.errorField == AuthField.confirmPassword,
    );
  }

  void setSmsCode(String value) {
    state = state.copyWith(
      smsCode: value.trim(),
      clearError: state.errorField == AuthField.smsCode,
    );
  }

  void setAgreeTerms(bool value) {
    state = state.copyWith(
      agreeTerms: value,
      clearError: state.errorField == AuthField.terms,
    );
  }

  AuthActionResult _fail(AuthField field, String message) {
    state = state.copyWith(errorField: field, errorMessage: message);
    return AuthActionResult(success: false, message: message, field: field);
  }

  AuthActionResult? _checkMobile() {
    if (state.mobile.isEmpty) {
      return _fail(AuthField.mobile, '请输入手机号');
    }
    if (!_mobileReg.hasMatch(state.mobile)) {
      return _fail(AuthField.mobile, '手机号应为 11 位数字');
    }
    return null;
  }

  AuthActionResult? _checkSmsCode() {
    if (state.smsCode.isEmpty) {
      return _fail(AuthField.smsCode, '请输入短信验证码');
    }
    return null;
  }

  /// 注册与重设密码：6–20 位，并与确认密码一致。
  AuthActionResult? _checkNewPassword() {
    final length = state.password.length;
    if (length == 0) {
      return _fail(AuthField.password, '请输入密码');
    }
    if (length < passwordMinLength || length > passwordMaxLength) {
      return _fail(AuthField.password, '密码应为 6–20 位');
    }
    if (state.confirmPassword.isEmpty) {
      return _fail(AuthField.confirmPassword, '请再次输入密码');
    }
    if (state.confirmPassword != state.password) {
      return _fail(AuthField.confirmPassword, '两次输入的密码不一致');
    }
    return null;
  }

  AuthActionResult? _checkTerms() {
    if (!state.agreeTerms) {
      return _fail(AuthField.terms, '请先阅读并同意用户服务协议和隐私政策');
    }
    return null;
  }

  /// 找回密码第 1 步：校验手机号。
  AuthActionResult validateMobileStep() => _checkMobile() ?? _ok;

  /// 找回密码第 2 步：校验验证码已填写。
  AuthActionResult validateSmsStep() => _checkSmsCode() ?? _ok;

  Future<AuthActionResult> sendSms() async {
    final invalid = _checkMobile();
    if (invalid != null) {
      return invalid;
    }
    if (state.isSendingSms) {
      return const AuthActionResult(success: false, message: '验证码已发送，请稍后再试');
    }

    final smsType = scene == AuthScene.forgetPassword ? 1 : 0;
    final response = await _repository.sendSms(
      mobile: state.mobile,
      type: smsType,
    );

    final success = _isSendSmsSuccess(response.code);
    if (!success) {
      return AuthActionResult(
        success: false,
        message: response.displayMsg,
      );
    }

    _startCountdown();
    return const AuthActionResult(success: true, message: '验证码已发送');
  }

  /// 手机号 + 密码登录；未勾选协议时返回 [AuthField.terms]，由页面弹窗征得同意。
  Future<AuthActionResult> submitLogin() async {
    final invalid =
        _checkMobile() ??
        (state.password.isEmpty
            ? _fail(AuthField.password, '请输入密码')
            : null) ??
        _checkTerms();
    if (invalid != null) {
      return invalid;
    }
    return _login();
  }

  Future<AuthActionResult> _login() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await _repository.login(
        mobile: state.mobile,
        password: state.password,
      );
      if (response.code != 0) {
        return AuthActionResult(
          success: false,
          message: response.displayMsg,
        );
      }

      final token = _extractToken(response.data);
      if (token.isNotEmpty) {
        await _repository.persistToken(token);
      }
      await _repository.persistMobile(state.mobile);

      // 登录成功后再拉一次字典/审核开关，结果写入本地供各业务页读取。
      await _syncCheckStatus().catchError((_) {});
      unawaited(_reportCidIfNeeded());
      unawaited(_appConfigRepository.refreshFileBaseUrl());
      // 登录成功后用新 token 重新建立 WS 长连接，承担 AI / 系统 / 群聊消息推送。
      _chatSocket.reconnect();

      return const AuthActionResult(success: true, message: '登录成功');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  /// 演示版「体验身份」：以预置演示账号走与正式登录相同的接口流程。
  ///
  /// 演示身份只读写本机演示数据，不替用户勾选协议，也不改变勾选状态。
  Future<AuthActionResult> submitDemoLogin(String mobile) {
    state = state.copyWith(mobile: mobile, password: '123456');
    return _login();
  }

  Future<AuthActionResult> submitGuestLogin() async {
    await _repository.persistToken('youke');
    unawaited(_appConfigRepository.refreshFileBaseUrl());
    // 游客 token 也尝试连一次 WS，至少能收到系统级被踢 / 升级提示等下行事件。
    _chatSocket.reconnect();
    return const AuthActionResult(success: true, message: '已进入游客模式');
  }

  Future<AuthActionResult> submitRegister() async {
    final invalid =
        _checkMobile() ?? _checkSmsCode() ?? _checkNewPassword() ?? _checkTerms();
    if (invalid != null) {
      return invalid;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await _repository.register(
        mobile: state.mobile,
        password: state.password,
        smsCode: state.smsCode,
      );

      if (response.code != 0) {
        return AuthActionResult(
          success: false,
          message: response.displayMsg,
        );
      }

      final token = _extractToken(response.data);
      if (token.isNotEmpty) {
        await _repository.persistToken(token);
      }
      await _repository.persistMobile(state.mobile);

      await _syncCheckStatus().catchError((_) {});
      unawaited(_appConfigRepository.refreshFileBaseUrl());
      unawaited(_reportCidIfNeeded());
      _chatSocket.reconnect();

      return const AuthActionResult(success: true, message: '注册成功');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<AuthActionResult> submitForgetPassword() async {
    final invalid = _checkMobile() ?? _checkSmsCode() ?? _checkNewPassword();
    if (invalid != null) {
      return invalid;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await _repository.resetPassword(
        mobile: state.mobile,
        password: state.password,
        smsCode: state.smsCode,
      );

      if (response.code != 0) {
        return AuthActionResult(
          success: false,
          message: response.displayMsg,
        );
      }

      return const AuthActionResult(success: true, message: '密码已重置，请用新密码登录');
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    state = state.copyWith(isSendingSms: true, smsCountDown: 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.smsCountDown - 1;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(smsCountDown: 0, isSendingSms: false);
        return;
      }
      state = state.copyWith(smsCountDown: next);
    });
  }

  String _extractToken(dynamic data) {
    if (data is Map<String, dynamic>) {
      final token = data['token'];
      if (token != null) {
        return token.toString();
      }
    }
    return '';
  }

  bool _isSendSmsSuccess(int code) {
    if (scene == AuthScene.register) {
      return code == 200 || code == 0;
    }
    return code == 0 || code == 200;
  }

  Future<void> _syncCheckStatus() async {
    final checkResponse = await _repository.getCheck();
    if (checkResponse.code == 0) {
      // data: true → 审核中，隐藏会员入口；data: false → 正常展示。
      await _repository.saveCheckStatus(checkResponse.data);
    }
  }

  Future<void> _reportCidIfNeeded() async {
    final pushId = _repository.pushId;
    if (pushId.isEmpty) {
      return;
    }
    await _repository.reportCid(pushId);
  }
}
