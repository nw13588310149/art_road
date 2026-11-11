import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/config/app_config_repository.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/network/chat_socket_service.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/auth/data/auth_repository.dart';
import 'package:the_road_of_art_flutter/features/auth/state/auth_state.dart';
import 'package:the_road_of_art_flutter/features/auth/ui/forget_password_page.dart';
import 'package:the_road_of_art_flutter/features/auth/ui/login_page.dart';
import 'package:the_road_of_art_flutter/features/auth/ui/register_page.dart';

class _FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;

  @override
  Future<ApiResponse> login({
    required String mobile,
    required String password,
  }) async {
    loginCalls++;
    return const ApiResponse(code: 1, msg: '账号或密码错误');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppConfigRepository implements AppConfigRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatSocketService implements ChatSocketService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeAuthRepository> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1180, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        appConfigRepositoryProvider.overrideWithValue(
          _FakeAppConfigRepository(),
        ),
        chatSocketServiceProvider.overrideWithValue(_FakeChatSocketService()),
      ],
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump();
  return repository;
}

bool _agreed(WidgetTester tester) =>
    tester.widget<AppCheckbox>(find.byType(AppCheckbox)).value;

/// 轻提示 2.2 秒后消失，跑完计时器再结束用例。
Future<void> _settleToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

void main() {
  group('LoginPage', () {
    testWidgets('consent starts unchecked and is asked for before login', (
      tester,
    ) async {
      final repository = await _pumpPage(tester, const LoginPage());
      expect(_agreed(tester), isFalse);
      expect(find.text('立即注册'), findsOneWidget);
      expect(find.textContaining('！'), findsNothing);

      await tester.enterText(find.byType(EditableText).at(0), '13809310001');
      await tester.enterText(find.byType(EditableText).at(1), '123456');
      await tester.tap(find.text('立即登录'));
      await tester.pumpAndSettle();
      expect(find.text('请先阅读并同意协议'), findsOneWidget);
      expect(repository.loginCalls, 0);

      await tester.tap(find.text('不同意'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(_agreed(tester), isFalse);
      expect(repository.loginCalls, 0);

      await tester.tap(find.text('立即登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同意并登录'));
      await tester.pump();
      await tester.pump();
      expect(repository.loginCalls, 1);
      expect(_agreed(tester), isTrue);
      expect(find.text('账号或密码错误'), findsOneWidget);
      await _settleToast(tester);
    });

    testWidgets('shows format errors under the field', (tester) async {
      await _pumpPage(tester, const LoginPage());
      await tester.enterText(find.byType(EditableText).at(0), '1380931');
      await tester.tap(find.text('立即登录'));
      await tester.pump();
      expect(find.text('手机号应为 11 位数字'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).at(0), '13809310001');
      await tester.pump();
      expect(find.text('手机号应为 11 位数字'), findsNothing);
    });

    testWidgets('password field toggles visibility', (tester) async {
      await _pumpPage(tester, const LoginPage());
      EditableText password() =>
          tester.widget<EditableText>(find.byType(EditableText).at(1));
      expect(password().obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(password().obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('demo identities do not tick the consent box', (tester) async {
      final repository = await _pumpPage(tester, const LoginPage());
      await tester.tap(find.text('学生 · 林小雨'));
      await tester.pump();
      await tester.pump();
      expect(repository.loginCalls, 1);
      expect(find.byType(AppDialog), findsNothing);
      expect(_agreed(tester), isFalse);
      await _settleToast(tester);
    });
  });

  testWidgets('RegisterPage has confirm password and no forgot link', (
    tester,
  ) async {
    await _pumpPage(tester, const RegisterPage());
    expect(find.text('忘记密码？'), findsNothing);
    expect(find.text('请再次输入密码'), findsOneWidget);
    expect(find.text('密码为 6–20 位，建议同时包含字母和数字'), findsOneWidget);
    expect(find.text('获取验证码'), findsOneWidget);
    expect(find.text('已有账号？'), findsOneWidget);
    expect(find.text('立即登录'), findsOneWidget);
    expect(_agreed(tester), isFalse);
  });

  testWidgets('registration keeps the SMS input and button on one centerline', (
    tester,
  ) async {
    await _pumpPage(tester, const RegisterPage());
    final field = find.byType(AppIconInputField).at(1);
    final text = find.text('获取验证码');
    final button = find.ancestor(of: text, matching: find.byType(AppPressable));
    expect(tester.getSize(button), const Size(117, 45));
    expect(tester.getSize(field).height, 45);
    expect(tester.getCenter(button).dy, closeTo(tester.getCenter(field).dy, 1));
    expect(tester.getCenter(button).dy, closeTo(tester.getCenter(text).dy, 1));
    expect(tester.widget<Text>(text).style?.fontSize, 14);
    expect(
      tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('ForgetPasswordPage shows steps and a way back', (tester) async {
    await _pumpPage(tester, const ForgetPasswordPage());
    expect(find.text('第 1 步（共 3 步）：验证手机号'), findsOneWidget);
    expect(find.text('返回登录'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '13809310001');
    await tester.tap(find.text('下一步'));
    await tester.pump();
    expect(find.text('第 2 步（共 3 步）：输入验证码'), findsOneWidget);
    expect(find.textContaining('138****0001'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);

    await tester.tap(find.text('上一步'));
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      '13809310001',
    );
  });

  test('AuthState defaults to not agreed and formats the countdown', () {
    const state = AuthState();
    expect(state.agreeTerms, isFalse);
    expect(state.smsButtonText, '获取验证码');
    expect(state.copyWith(smsCountDown: 60).smsButtonText, '60 秒后重发');
    final failed = state.copyWith(
      errorField: AuthField.mobile,
      errorMessage: '请输入手机号',
    );
    expect(failed.errorOf(AuthField.mobile), '请输入手机号');
    expect(failed.errorOf(AuthField.password), isNull);
    expect(failed.copyWith(clearError: true).errorOf(AuthField.mobile), isNull);
  });
}
