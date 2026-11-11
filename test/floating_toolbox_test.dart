import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_dock_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/state/toolbox_dock_controller.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/floating_toolbox_host.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/toolbox_route_observer.dart';

const _handleKey = ValueKey('floating-toolbox-handle');

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final observer = ToolboxRouteObserver();
  addTearDown(observer.dispose);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        builder: (_, child) =>
            FloatingToolboxHost(observer: observer, child: child!),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              Scaffold(body: Center(child: Text('业务页面 ${settings.name}'))),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return navigator;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'snap uses nearest of all four safe edges and adapts to resized bounds',
    () {
      const bounds = Rect.fromLTRB(8, 8, 1112, 752);
      final cases = <Offset, ToolboxDockEdge>{
        const Offset(15, 320): ToolboxDockEdge.left,
        const Offset(1100, 320): ToolboxDockEdge.right,
        const Offset(500, 15): ToolboxDockEdge.top,
        const Offset(500, 740): ToolboxDockEdge.bottom,
      };
      for (final entry in cases.entries) {
        final dock = ToolboxDockGeometry.snap(entry.key, bounds);
        expect(dock.edge, entry.value);
        const resized = Rect.fromLTRB(32, 20, 700, 310);
        final position = ToolboxDockGeometry.resolve(dock, resized);
        expect(position.dx, inInclusiveRange(resized.left, resized.right));
        expect(position.dy, inInclusiveRange(resized.top, resized.bottom));
      }
      expect(
        ToolboxDockGeometry.snap(const Offset(-500, -500), Rect.zero).fraction,
        0,
      );
    },
  );

  test(
    'position survives a new controller and corrupt preferences fall back',
    () async {
      final repository = ToolboxDockPreferences();
      await repository.save(
        const ToolboxDockPosition(edge: ToolboxDockEdge.left, fraction: 0.3),
      );
      final controller = ToolboxDockController(repository);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.edge, ToolboxDockEdge.left);
      expect(controller.state.fraction, 0.3);
      controller.dispose();
      SharedPreferences.setMockInitialValues({
        ToolboxDockPreferences.edgeKey: 'invalid',
        ToolboxDockPreferences.fractionKey: double.nan,
      });
      final fallback = await repository.load();
      expect(fallback.edge, ToolboxDockEdge.right);
      expect(fallback.fraction, 0.64);
    },
  );

  for (final size in [
    const Size(1180, 820),
    const Size(1024, 768),
    const Size(720, 400),
  ]) {
    testWidgets(
      'expand, full screen, retain settings, resume and return at $size',
      (tester) async {
        final nav = await _pumpHost(tester, size);
        await tester.tap(find.byKey(_handleKey));
        await tester.pumpAndSettle();
        expect(find.text('随手用画具'), findsOneWidget);
        await tester.tap(find.text('速写计时练习'));
        await tester.pumpAndSettle();
        expect(find.text('收起工具'), findsOneWidget);
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('收起工具'), findsOneWidget);
        semantics.dispose();
        await tester.ensureVisible(find.text('30 秒'));
        await tester.tap(find.text('30 秒'));
        await tester.pump();
        await tester.tap(find.text('收起工具'));
        await tester.pumpAndSettle();
        expect(find.text('业务页面 /'), findsOneWidget);
        nav.currentState!.pushNamed<void>('/notes');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_handleKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('继续 · 速写计时练习'));
        await tester.pumpAndSettle();
        expect(find.textContaining('共 10 张 · 每张 30 秒'), findsOneWidget);
        await tester.tap(find.text('收起工具'));
        await tester.pumpAndSettle();
        expect(find.text('业务页面 /notes'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'drag does not open panel, snaps, then tap and system back dismiss',
    (tester) async {
      final nav = await _pumpHost(tester, const Size(1180, 820));
      final handle = find.byKey(_handleKey);
      await tester.drag(handle, const Offset(-700, -470));
      await tester.pumpAndSettle();
      expect(find.text('随手用画具'), findsNothing);
      expect(tester.getTopLeft(handle).dy, 8);
      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(find.text('随手用画具'), findsOneWidget);
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('随手用画具'), findsNothing);
      expect(find.text('业务页面 /'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login and modal dialogs yield the launcher; logout clears workspace',
    (tester) async {
      final nav = await _pumpHost(tester, const Size(1024, 768));
      showDialog<void>(
        context: nav.currentContext!,
        builder: (_) => const AlertDialog(title: Text('确认操作')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_handleKey), findsNothing);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_handleKey), findsOneWidget);
      nav.currentState!.pushNamedAndRemoveUntil('/login', (_) => false);
      await tester.pumpAndSettle();
      expect(find.byKey(_handleKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Escape dismisses panel without leaving source route', (
    tester,
  ) async {
    await _pumpHost(tester, const Size(1024, 768));
    await tester.tap(find.byKey(_handleKey));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('随手用画具'), findsNothing);
    expect(find.text('业务页面 /'), findsOneWidget);
  });

  testWidgets('minimizing pauses a running sketch and retains the exercise', (
    tester,
  ) async {
    await _pumpHost(tester, const Size(1024, 768));
    await tester.tap(find.byKey(_handleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('速写计时练习'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始练习'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('收起工具'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 65));
    await tester.tap(find.byKey(_handleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续 · 速写计时练习'));
    await tester.pumpAndSettle();
    expect(find.text('已暂停，点击继续'), findsOneWidget);
    expect(find.text('练习回顾'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
