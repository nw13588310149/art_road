// 今日页（今日学习 / 今日工作）：各身份在两种横屏尺寸下的版式，以及打勾、
// 看详情、添加安排、筛选、记录练习这些交互。数据走演示后端。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/today/data/today_models.dart';
import 'package:the_road_of_art_flutter/features/today/data/today_repository.dart';
import 'package:the_road_of_art_flutter/features/today/state/today_controller.dart';
import 'package:the_road_of_art_flutter/features/today/ui/today_page.dart';
import 'package:the_road_of_art_flutter/features/today/ui/widgets/today_charts.dart';
import 'package:the_road_of_art_flutter/features/today/ui/widgets/today_checklist.dart';
import 'package:the_road_of_art_flutter/features/today/ui/widgets/today_hero.dart';

/// 直接调演示后端的路由，按指定账号取数（不经过登录态）。
class _DemoTodayRepository implements TodayRepository {
  _DemoTodayRepository(this.account);

  final DemoAccount account;
  final calls = <String>[];

  Future<ApiResponse> _post(String path, [Map<String, dynamic> body = const {}]) async {
    calls.add(path);
    final match = DemoBackend.platform.match('POST', path)!;
    try {
      final data = await match.handler(
        DemoRequest(
          method: 'POST',
          path: path,
          query: const <String, dynamic>{},
          body: body,
          headers: <String, dynamic>{'app-token': account.token},
        ),
      );
      return ApiResponse(code: 0, msg: 'ok', data: data);
    } on DemoApiException catch (e) {
      return ApiResponse(code: e.code, msg: e.message, data: null);
    }
  }

  @override
  Future<ApiResponse> board() => _post('/app/today/board');

  @override
  Future<ApiResponse> complete(String id) =>
      _post('/app/today/step/complete', {'id': id});

  @override
  Future<ApiResponse> reopen(String id) =>
      _post('/app/today/step/reopen', {'id': id});

  @override
  Future<ApiResponse> skip(String id) => _post('/app/today/step/skip', {'id': id});

  @override
  Future<ApiResponse> restore(String id) =>
      _post('/app/today/step/restore', {'id': id});

  @override
  Future<ApiResponse> snooze(String id, {required bool on}) =>
      _post('/app/today/step/snooze', {'id': id, 'on': on});

  @override
  Future<ApiResponse> saveStep({
    required String title,
    required String slot,
    String detail = '',
  }) => _post('/app/today/step/save', {
    'title': title,
    'slot': slot,
    'detail': detail,
  });

  @override
  Future<ApiResponse> deleteStep(String id) =>
      _post('/app/today/step/delete', {'id': id});

  @override
  Future<ApiResponse> logPractice(int minutes) =>
      _post('/app/today/practice/log', {'minutes': minutes});

  @override
  Future<ApiResponse> follow(String id, {required bool followed}) =>
      _post('/app/today/people/follow', {'id': id, 'followed': followed});

  @override
  Future<ApiResponse> dismissTip() => _post('/app/today/tip/dismiss');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late ProviderContainer _container;

Future<_DemoTodayRepository> _pump(
  WidgetTester tester,
  DemoAccount account, {
  Size content = const Size(950, 732),
}) async {
  tester.view.physicalSize = const Size(1180, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final storage = AppStorage(await SharedPreferences.getInstance());
  await DemoStore.init();
  await DemoStore.reset();
  registerDemoFixtures();
  final repository = _DemoTodayRepository(account);
  _container = ProviderContainer(
    overrides: [
      appStorageProvider.overrideWithValue(storage),
      todayRepositoryProvider.overrideWithValue(repository),
      todayRoleProvider.overrideWith((ref) => account.roleKey),
      todayControllerProvider.overrideWith(
        (ref) => TodayController(repository, enabled: true),
      ),
    ],
  );
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.page,
          body: Center(
            child: SizedBox(
              width: content.width,
              height: content.height,
              child: const TodayPage(),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return repository;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

TodayBoard get _board => _container.read(todayControllerProvider).board!;

void main() {
  setUpAll(() async {
    for (final font in {
      'Barlow': 'assets/fonts/Barlow-SemiBold.ttf',
      'Manrope': 'assets/fonts/Manrope Medium.ttf',
      'PingFang SC': 'assets/fonts/ttf/PingFangSC-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  test('role falls back to the demo token before /myInfo returns', () {
    expect(resolveTodayRole('teacher', token: ''), 'teacher');
    expect(
      resolveTodayRole('', token: 'demo.dormManager.13809310004', demoMode: true),
      'dormManager',
    );
    // 教学组长的后端身份仍是任课老师。
    expect(
      resolveTodayRole('', token: 'demo.groupLeader.13809310012', demoMode: true),
      'teacher',
    );
    expect(resolveTodayRole('', token: '', demoMode: true), '');
    expect(resolveTodayRole('', token: 'real-token', demoMode: false), '');
  });

  // 1180 × 820 与 1024 × 768 两种横屏下的内容区。
  for (final content in [const Size(950, 732), const Size(794, 680)]) {
    for (final account in [
      DemoAccounts.student,
      DemoAccounts.teacher,
      DemoAccounts.groupLeader,
      DemoAccounts.headTeacher,
      DemoAccounts.admin,
      DemoAccounts.principal,
      DemoAccounts.dormManager,
    ]) {
      testWidgets('${account.role.name} page lays out at $content', (
        tester,
      ) async {
        await _pump(tester, account, content: content);
        expect(tester.takeException(), isNull);
        expect(find.byType(TodayHero), findsOneWidget);
        expect(find.byType(TodayChecklist), findsOneWidget);
        expect(find.text('今日进度'), findsOneWidget);
        expect(find.text('今日清单'), findsOneWidget);
        final board = _board;
        expect(
          find.byType(TodayChartCard),
          findsNWidgets(board.charts.length),
        );
        expect(find.text('近 7 天完成'), findsOneWidget);
        // 每件事都在清单里。
        for (final step in board.steps) {
          expect(find.text(step.title), findsWidgets, reason: step.title);
        }
        // 往下滚到底，整页没有溢出。
        await tester.scrollUntilVisible(
          find.text('快捷入口'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(
          find.byType(TodayPeopleCard),
          board.people == null ? findsNothing : findsOneWidget,
        );
      });
    }
  }

  testWidgets('the hero names the next step and opens it', (tester) async {
    await _pump(tester, DemoAccounts.teacher);
    final board = _board;
    final focus = board.focus!;
    final hero = find.byType(TodayHero);
    expect(
      find.descendant(of: hero, matching: find.text(focus.title)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: hero,
        matching: find.text(
          focus.status == TodayStepStatus.overdue ? '先做这件' : '下一步',
        ),
      ),
      findsOneWidget,
    );
    // 只有下一步用主按钮：头图一个，清单里对应的那一行一个。
    final primary = tester
        .widgetList<AppButton>(find.byType(AppButton))
        .where((b) => b.variant == AppButtonVariant.primary);
    expect(primary.map((b) => b.label).toSet(), {focus.action!.label});
    expect(primary, hasLength(2));
  });

  testWidgets('ticking a practice updates progress and the practice chart', (
    tester,
  ) async {
    final repository = await _pump(tester, DemoAccounts.student);
    final before = _board;
    final practice = before.steps.firstWhere((s) => s.kind == 'practice');
    final mark = find.bySemanticsLabel('打勾：${practice.title}');
    await tester.ensureVisible(mark);
    await tester.tap(mark);
    await _settle(tester);

    expect(repository.calls, contains('/app/today/step/complete'));
    final after = _board;
    expect(after.summary.done, before.summary.done + 1);
    expect(
      find.text('已打勾，今天完成 ${after.summary.done} / ${after.summary.total} 件'),
      findsOneWidget,
    );
    expect(
      find.textContaining('今天已练 ${practice.minutes} 分钟'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('取消打勾：${practice.title}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a step that completes by itself cannot be ticked by hand', (
    tester,
  ) async {
    final repository = await _pump(tester, DemoAccounts.student);
    final lesson = _board.steps.firstWhere((s) => s.kind == 'lesson');
    // 课程行没有打勾的入口。
    expect(find.bySemanticsLabel('打勾：${lesson.title}'), findsNothing);
    expect(repository.calls, isNot(contains('/app/today/step/complete')));
  });

  testWidgets('a row opens the how-to sheet with its options', (tester) async {
    final repository = await _pump(tester, DemoAccounts.student);
    final practice = _board.steps.firstWhere((s) => s.kind == 'practice');
    await tester.ensureVisible(find.text(practice.title));
    await tester.tap(find.text(practice.title));
    await _settle(tester);

    final sheet = find.byType(AppDrawer);
    expect(
      find.descendant(of: sheet, matching: find.text('怎么做')),
      findsOneWidget,
    );
    expect(find.text(practice.guide.first), findsOneWidget);
    expect(find.text(practice.source), findsOneWidget);
    expect(find.text('推迟到晚上再做'), findsOneWidget);
    expect(find.text('今天不做'), findsOneWidget);

    await tester.tap(find.text('今天不做'));
    await _settle(tester);
    expect(repository.calls, contains('/app/today/step/skip'));
    expect(
      _board.steps.firstWhere((s) => s.id == practice.id).status,
      TodayStepStatus.skipped,
    );
    expect(find.text('今天不做这件事'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('adding a personal step puts it in the chosen part of the day', (
    tester,
  ) async {
    await _pump(tester, DemoAccounts.teacher);
    final before = _board.summary.total;
    await tester.tap(find.text('添加安排'));
    await _settle(tester);
    expect(find.text('什么时候做'), findsOneWidget);

    // 没填内容不能添加。
    await tester.tap(find.text('添加'));
    await _settle(tester);
    expect(find.text('请填写要做的事'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '整理素描范画');
    final dialog = find.byType(AppDialog);
    await tester.tap(find.descendant(of: dialog, matching: find.text('下午')));
    await tester.tap(find.text('添加'));
    await _settle(tester);

    final custom = _board.steps.firstWhere((s) => s.custom);
    expect(custom.title, '整理素描范画');
    expect(_board.summary.total, before + 1);
    expect(
      _board.groups.firstWhere((g) => g.id == 'afternoon').steps,
      contains(custom),
    );
    expect(find.text('整理素描范画'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the filter narrows the list to what is left', (tester) async {
    await _pump(tester, DemoAccounts.dormManager);
    final board = _board;
    final open = board.steps.where((s) => s.status.open).toList();
    final closed = board.steps.where((s) => !s.status.open).toList();
    expect(find.text('全部 ${board.steps.length}'), findsOneWidget);
    expect(find.text('未完成 ${open.length}'), findsOneWidget);

    await tester.tap(find.text('未完成 ${open.length}'));
    await _settle(tester);
    for (final step in closed) {
      expect(
        find.descendant(
          of: find.byType(TodayChecklist),
          matching: find.text(step.title),
        ),
        findsNothing,
        reason: step.title,
      );
    }
    expect(
      find.descendant(
        of: find.byType(TodayChecklist),
        matching: find.text(open.first.title),
      ),
      findsOneWidget,
    );
  });

  testWidgets('charts switch to a data table with the same numbers', (
    tester,
  ) async {
    await _pump(tester, DemoAccounts.student);
    final week = _board.charts.first as TodayColumnsChart;
    await tester.tap(find.byTooltip('近 7 天完成：看数据表'));
    await _settle(tester);
    for (final line in week.table) {
      expect(find.text(line), findsOneWidget, reason: line);
    }
    expect(find.byTooltip('近 7 天完成：看图表'), findsOneWidget);
  });

  testWidgets('logging practice from the chart adds to today', (tester) async {
    final repository = await _pump(tester, DemoAccounts.student);
    await tester.ensureVisible(find.text('记录练习'));
    await tester.tap(find.text('记录练习'));
    await _settle(tester);
    await tester.tap(find.text('30 分钟'));
    await tester.pump();
    await tester.tap(find.text('记录 30 分钟'));
    await _settle(tester);
    expect(repository.calls, contains('/app/today/practice/log'));
    expect(find.textContaining('今天已练 30 分钟'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('marking a student as followed up is remembered', (tester) async {
    final repository = await _pump(tester, DemoAccounts.teacher);
    final person = _board.people!.rows.first;
    final button = find.text('标记已跟进').first;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await _settle(tester);
    expect(repository.calls, contains('/app/today/people/follow'));
    expect(
      _board.people!.rows.firstWhere((r) => r.id == person.id).followed,
      isTrue,
    );
    expect(find.textContaining('已跟进 1 /'), findsOneWidget);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = AppStorage(await SharedPreferences.getInstance());
    final repository = _FailingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStorageProvider.overrideWithValue(storage),
          todayRoleProvider.overrideWith((ref) => 'teacher'),
          todayControllerProvider.overrideWith(
            (ref) => TodayController(repository, enabled: true),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 950, height: 732, child: TodayPage())),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('今日内容加载失败'), findsOneWidget);
    expect(find.text('今日清单'), findsNothing);
    expect(repository.loads, 1);
    await tester.tap(find.text('重试'));
    await _settle(tester);
    expect(repository.loads, 2);
  });
}

class _FailingRepository implements TodayRepository {
  int loads = 0;

  @override
  Future<ApiResponse> board() async {
    loads++;
    return const ApiResponse(code: 500, msg: '服务暂时不可用', data: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
