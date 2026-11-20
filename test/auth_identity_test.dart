import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/config/app_config_repository.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/network/chat_socket_service.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/features/auth/data/auth_repository.dart';
import 'package:the_road_of_art_flutter/features/auth/state/auth_controller.dart';
import 'package:the_road_of_art_flutter/features/auth/state/auth_state.dart';

class _Repository implements AuthRepository {
  ApiResponse response = const ApiResponse(code: 400, msg: '登录失败');
  int persisted = 0;
  int requests = 0;
  Completer<ApiResponse>? pending;
  @override
  String get pushId => '';
  @override
  Future<ApiResponse> login({
    required String mobile,
    required String password,
  }) async {
    requests++;
    return pending == null ? response : await pending!.future;
  }

  @override
  Future<ApiResponse> register({
    required String mobile,
    required String password,
    required String smsCode,
  }) async {
    requests++;
    return pending == null ? response : await pending!.future;
  }

  @override
  Future<ApiResponse> resetPassword({
    required String mobile,
    required String password,
    required String smsCode,
  }) async => response;
  @override
  Future<ApiResponse> sendSms({
    required String mobile,
    required int type,
  }) async {
    requests++;
    return pending == null
        ? const ApiResponse(code: 0, msg: 'ok')
        : await pending!.future;
  }

  @override
  Future<void> persistToken(String token) async {
    persisted++;
  }

  @override
  Future<void> persistMobile(String mobile, {String? expectedToken}) async {
    persisted++;
  }

  @override
  Future<ApiResponse> getCheck() async =>
      const ApiResponse(code: 0, msg: 'ok', data: false);
  @override
  Future<void> saveCheckStatus(dynamic value, {String? expectedToken}) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Config implements AppConfigRepository {
  @override
  Future<String> refreshFileBaseUrl() async => '';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Socket implements ChatSocketService {
  @override
  void reconnect() {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _Repository repo;
  late AuthController controller;
  setUp(() {
    repo = _Repository();
    controller = AuthController(
      repository: repo,
      appConfigRepository: _Config(),
      chatSocket: _Socket(),
      scene: AuthScene.login,
    );
    controller.setMobile('13912345678');
    controller.setPassword('test-password');
    controller.setAgreeTerms(true);
  });
  tearDown(() => controller.dispose());
  test('发送中切换手机号时，不会重复发送或展示上一身份的验证码', () async {
    repo.pending = Completer<ApiResponse>();
    final first = controller.sendSms();
    controller.setMobile(DemoAccounts.student.mobile);
    expect((await controller.sendSms()).success, isFalse);
    expect(repo.requests, 1);
    repo.pending!.complete(const ApiResponse(code: 0, msg: 'ok'));
    expect((await first).success, isFalse);
    expect(controller.state.isSendingSms, isFalse);
    expect(controller.state.smsCountDown, 0);
  });
  test('rejected or token-less success never persists credentials', () async {
    expect((await controller.submitLogin()).success, isFalse);
    repo.response = const ApiResponse(code: 0, msg: 'ok', data: {});
    expect((await controller.submitLogin()).success, isFalse);
    expect(repo.persisted, 0);
  });
  test('successful real login persists only after receiving token', () async {
    repo.response = const ApiResponse(
      code: 0,
      msg: 'ok',
      data: {'token': 'real-token'},
    );
    expect((await controller.submitLogin()).success, isTrue);
    expect(repo.persisted, 2);
  });
  test('only exact demo mobile exposes local SMS hint and shortcut', () async {
    expect((await controller.sendSms()).message, '验证码已发送');
    controller.dispose();
    controller = AuthController(
      repository: repo,
      appConfigRepository: _Config(),
      chatSocket: _Socket(),
      scene: AuthScene.login,
    );
    controller.setMobile(DemoAccounts.student.mobile);
    expect((await controller.sendSms()).message, contains('演示验证码'));
    expect((await controller.submitDemoLogin('13912345678')).success, isFalse);
    expect(repo.persisted, 0);
  });
  test('staff usernames and 64-character login names are accepted', () async {
    repo.response = const ApiResponse(
      code: 0,
      msg: 'ok',
      data: {'token': 'staff-token'},
    );
    controller.setMobile('teacher.school');
    expect((await controller.submitLogin()).success, isTrue);
    controller.setMobile('x' * 64);
    expect((await controller.submitLogin()).success, isTrue);
    controller.setMobile('x' * 65);
    expect((await controller.submitLogin()).success, isFalse);
  });
  test(
    'registration requires phone, six digits and 8–64 character password',
    () async {
      controller.dispose();
      controller = AuthController(
        repository: repo,
        appConfigRepository: _Config(),
        chatSocket: _Socket(),
        scene: AuthScene.register,
      );
      controller.setAgreeTerms(true);
      controller.setMobile('teacher.school');
      expect((await controller.submitRegister()).field, AuthField.mobile);
      controller.setMobile('13912345678');
      controller.setSmsCode('12345');
      expect((await controller.submitRegister()).field, AuthField.smsCode);
      controller.setSmsCode('123456');
      controller.setPassword('x' * 7);
      controller.setConfirmPassword('x' * 7);
      expect((await controller.submitRegister()).field, AuthField.password);
      repo.response = const ApiResponse(
        code: 0,
        msg: 'ok',
        data: {'token': 'new-token'},
      );
      for (final count in [8, 64]) {
        controller.setPassword('x' * count);
        controller.setConfirmPassword('x' * count);
        expect((await controller.submitRegister()).success, isTrue);
      }
      controller.setPassword('x' * 65);
      expect((await controller.submitRegister()).field, AuthField.password);
    },
  );
  test('password reset retains phone/six-digit and 8–64 boundaries', () async {
    controller.dispose();
    controller = AuthController(
      repository: repo,
      appConfigRepository: _Config(),
      chatSocket: _Socket(),
      scene: AuthScene.forgetPassword,
    );
    controller.setMobile('staff-name');
    expect((await controller.submitForgetPassword()).field, AuthField.mobile);
    controller.setMobile('13912345678');
    controller.setSmsCode('abcdef');
    expect((await controller.submitForgetPassword()).field, AuthField.smsCode);
    controller.setSmsCode('123456');
    repo.response = const ApiResponse(code: 0, msg: 'ok');
    for (final count in [8, 64]) {
      controller.setPassword('x' * count);
      controller.setConfirmPassword('x' * count);
      expect((await controller.submitForgetPassword()).success, isTrue);
    }
    for (final count in [7, 65]) {
      controller.setPassword('x' * count);
      expect(
        (await controller.submitForgetPassword()).field,
        AuthField.password,
      );
    }
    expect(repo.persisted, 0);
  });
  test(
    'pending login blocks button, keyboard and demo shortcut reentry',
    () async {
      repo.pending = Completer<ApiResponse>();
      final first = controller.submitLogin();
      expect((await controller.submitLogin()).success, isFalse);
      expect(
        (await controller.submitDemoLogin(DemoAccounts.teacher.mobile)).success,
        isFalse,
      );
      expect(repo.requests, 1);
      repo.pending!.complete(const ApiResponse(code: 400, msg: '拒绝'));
      await first;
      expect(repo.persisted, 0);
    },
  );
  test('malformed token is never persisted', () async {
    for (final token in [
      '   ',
      <String, String>{'nested': 'token'},
      123,
    ]) {
      repo.response = ApiResponse(code: 0, msg: 'ok', data: {'token': token});
      expect((await controller.submitLogin()).success, isFalse);
    }
    expect(repo.persisted, 0);
  });
  test('registration pending blocks duplicate requests', () async {
    controller.dispose();
    controller = AuthController(
      repository: repo,
      appConfigRepository: _Config(),
      chatSocket: _Socket(),
      scene: AuthScene.register,
    );
    controller.setMobile('13912345678');
    controller.setSmsCode('123456');
    controller.setPassword('abcdefgh');
    controller.setConfirmPassword('abcdefgh');
    controller.setAgreeTerms(true);
    repo.pending = Completer<ApiResponse>();
    final first = controller.submitRegister();
    expect((await controller.submitRegister()).success, isFalse);
    expect(repo.requests, 1);
    repo.pending!.complete(const ApiResponse(code: 400, msg: '拒绝'));
    await first;
    expect(repo.persisted, 0);
  });
}
