import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/help_guide/data/role_guide_store.dart';
import 'package:the_road_of_art_flutter/features/help_guide/data/role_guides.dart';
import 'package:the_road_of_art_flutter/features/help_guide/ui/help_guide_page.dart';
import 'package:the_road_of_art_flutter/features/help_guide/ui/role_guide_dialog.dart';
import 'package:the_road_of_art_flutter/features/shell/data/shell_repository.dart';
import 'package:the_road_of_art_flutter/features/shell/state/shell_controller.dart';
import 'package:the_road_of_art_flutter/features/shell/state/shell_state.dart';

/// 文案合规：与 yikao-marketing 违禁词表中会出现在界面文案里的规则一致。
final _banned = RegExp(
  r'最好|最佳|最优|最强|最大|最全|最快|唯一|首选|顶级|独家|保证|绝对|永久|万能|'
  r'保过|包过|必过|提分|涨分|上岸|逆袭|升学率|录取率|\bAI\b|人工智能|智能评分|自动评分|'
  r'第一(?!次|场|眼|步|张|位|天|个|批|份|轮|遍|笔|课|道|站|页|印象)|[!！]',
);

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required String role,
  required ValueSetter<bool> onShown,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AppButton(
              label: '进入首页',
              onTap: () async =>
                  onShown(await RoleGuideLauncher.maybeShow(context, role: role)),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RoleGuideLauncher.forgetSession();
  });

  group('seen flag', () {
    test('is stored per role and survives a new store instance', () async {
      const store = RoleGuideStore();
      expect(await store.hasSeen('student'), isFalse);
      await store.markSeen('student');
      expect(await store.hasSeen('student'), isTrue);
      expect(await store.hasSeen('teacher'), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(RoleGuideStore.keyOf('student')), isTrue);
      expect(await const RoleGuideStore().hasSeen('student'), isTrue);
      expect(await store.allSeen(), isFalse);
    });

    test('skip all and restore cover every role', () async {
      const store = RoleGuideStore();
      await store.markAllSeen();
      for (final role in roleGuideRoles) {
        expect(await store.hasSeen(role), isTrue, reason: role);
      }
      expect(await store.allSeen(), isTrue);
      await store.resetAll();
      for (final role in roleGuideRoles) {
        expect(await store.hasSeen(role), isFalse, reason: role);
      }
    });
  });

  group('content', () {
    test('every role has 3–4 steps pointing at its real entries', () {
      for (final role in roleGuideRoles) {
        final guide = roleGuideFor(role);
        expect(guide.role, role);
        expect(guide.steps.length, inInclusiveRange(3, 4), reason: role);
      }
      expect(roleGuideFor('student').steps.map((s) => s.title), [
        '我的学情',
        '作品档案',
        '画室工具箱',
        '美术书刊',
      ]);
      expect(roleGuideFor('teacher').steps.map((s) => s.title), [
        '作品点评',
        '班级学情',
        '智慧校园',
      ]);
      final dorm = roleGuideFor('dormManager').steps.map((s) => '${s.title}${s.body}');
      expect(dorm.join(), isNot(contains('学情')));
      expect(roleGuideFor('').role, 'student');
    });

    test('copy has no banned wording', () {
      for (final role in roleGuideRoles) {
        for (final step in roleGuideFor(role).steps) {
          final text = '${step.title}${step.body}${step.where}';
          expect(_banned.hasMatch(text), isFalse, reason: text);
        }
      }
    });
  });

  group('launcher', () {
    testWidgets('shows once per role with a visible 跳过 button', (
      tester,
    ) async {
      final shown = <bool>[];
      await _pumpLauncher(tester, role: 'student', onShown: shown.add);

      await tester.tap(find.text('进入首页'));
      await tester.pumpAndSettle();
      expect(shown, [true]);
      expect(find.byType(RoleGuideDialog), findsOneWidget);
      expect(find.text('我的学情'), findsOneWidget);
      expect(find.textContaining('学生新手引导'), findsOneWidget);
      expect(find.textContaining('1 / 4'), findsOneWidget);

      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('跳过'), findsOneWidget);
      semantics.dispose();
      expect(await const RoleGuideStore().hasSeen('student'), isTrue);

      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();
      expect(find.byType(RoleGuideDialog), findsNothing);

      // 同一身份再次进入首页（含刷新页面后的新会话）不再弹出。
      RoleGuideLauncher.forgetSession();
      await tester.tap(find.text('进入首页'));
      await tester.pumpAndSettle();
      expect(shown, [true, false]);
      expect(find.byType(RoleGuideDialog), findsNothing);
    });

    testWidgets('next steps through to 开始使用 without animations', (
      tester,
    ) async {
      await _pumpLauncher(tester, role: 'teacher', onShown: (_) {});
      await tester.tap(find.text('进入首页'));
      await tester.pumpAndSettle();
      expect(find.text('作品点评'), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('班级学情'), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pump();
      expect(find.text('智慧校园'), findsOneWidget);
      expect(find.text('跳过'), findsNothing);
      await tester.tap(find.text('开始使用'));
      await tester.pumpAndSettle();
      expect(find.byType(RoleGuideDialog), findsNothing);

      expect(await const RoleGuideStore().hasSeen('teacher'), isTrue);
      expect(await const RoleGuideStore().hasSeen('student'), isFalse);
    });

    testWidgets('a role skipped from the help page is not shown', (
      tester,
    ) async {
      await const RoleGuideStore().markAllSeen();
      final shown = <bool>[];
      await _pumpLauncher(tester, role: 'admin', onShown: shown.add);
      await tester.tap(find.text('进入首页'));
      await tester.pumpAndSettle();
      expect(shown, [false]);
      expect(find.byType(RoleGuideDialog), findsNothing);
    });
  });

  group('help page', () {
    Future<void> pumpHelp(WidgetTester tester) async {
      final storage = AppStorage(await SharedPreferences.getInstance());
      tester.view.physicalSize = const Size(950, 732);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(storage),
            shellControllerProvider.overrideWith(
              (ref) => _RoleShellController(ref, storage, 'headTeacher'),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: HelpGuidePage(demoMode: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('re-opens the guide of the current role', (tester) async {
      await pumpHelp(tester);
      await tester.tap(find.text('新手引导'));
      await tester.pumpAndSettle();
      expect(find.byType(RoleGuideDialog), findsOneWidget);
      expect(find.text('班级工作台'), findsOneWidget);
      expect(find.textContaining('班主任新手引导'), findsOneWidget);
    });

    testWidgets('demo build can skip and restore every guide', (tester) async {
      await pumpHelp(tester);
      expect(find.textContaining('第一次进入首页时会弹出新手引导'), findsOneWidget);
      await tester.tap(find.text('跳过新手引导'));
      await tester.pumpAndSettle();
      expect(await const RoleGuideStore().allSeen(), isTrue);
      expect(find.text('恢复新手引导'), findsOneWidget);

      await tester.tap(find.text('恢复新手引导'));
      await tester.pumpAndSettle();
      expect(await const RoleGuideStore().hasSeen('student'), isFalse);
      expect(find.text('跳过新手引导'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}

/// 未登录（不发请求、不开轮询）的外壳，只提供身份。
class _RoleShellController extends ShellController {
  _RoleShellController(Ref ref, AppStorage storage, String role)
    : super(
        repository: ref.read(shellRepositoryProvider),
        storage: storage,
        ref: ref,
      ) {
    state = state.copyWith(user: ShellUser(id: '1', role: role));
  }
}
