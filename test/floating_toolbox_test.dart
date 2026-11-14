import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_dock_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/state/toolbox_dock_controller.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/state/page_tools_controller.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_catalog.dart';
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
  expect(
    tester.getSize(find.byKey(const ValueKey('professional-tool-rail'))).height,
    52,
  );
  await tester.tap(find.byKey(_handleKey));
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
    testWidgets('single column tools and bounded options at $size', (
      tester,
    ) async {
      final nav = await _pumpHost(tester, size);
      final rail = find.byKey(const ValueKey('professional-tool-rail'));
      expect(tester.getSize(rail).width, 52);
      expect(tester.getRect(rail).bottom, lessThanOrEqualTo(size.height));
      await tester.tap(find.bySemanticsLabel('在当前页面使用构图网格'));
      await tester.pumpAndSettle();
      final options = tester.getRect(
        find.byKey(const ValueKey('page-tool-options')),
      );
      expect(options.width, 300);
      expect(options.bottom, lessThanOrEqualTo(size.height));
      expect(options.left, greaterThanOrEqualTo(0));
      expect(find.byKey(const ValueKey('page-tool-lines')), findsOneWidget);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(FloatingToolboxHost)),
      );
      await tester.tap(find.text('4 × 4'));
      await tester.pump();
      expect(c.read(pageToolsProvider).grid, 4);
      await tester.tap(find.bySemanticsLabel('撤销工具调整'));
      await tester.pump();
      expect(c.read(pageToolsProvider).grid, 3);
      await tester.tap(find.bySemanticsLabel('收起工具参数'));
      await tester.pumpAndSettle();
      expect(c.read(pageToolsProvider).tool, ArtTool.grid);
      await tester.tap(find.bySemanticsLabel('在当前页面使用明度检查'));
      await tester.pumpAndSettle();
      expect(c.read(pageToolsProvider).tool, ArtTool.value);
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-tool-options')), findsNothing);
      expect(find.text('业务页面 /'), findsOneWidget);
      nav.currentState!.pushNamed<void>('/notes');
      await tester.pumpAndSettle();
      expect(c.read(pageToolsProvider).tool, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('precision mode frees canvas, supports exit and restores rail', (
    tester,
  ) async {
    await _pumpHost(tester, const Size(1024, 768));
    await tester.tap(find.bySemanticsLabel('在当前页面使用取色与色卡'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-color-sampler')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('professional-tool-rail')))
          .height,
      52,
    );
    expect(find.byKey(const ValueKey('page-tool-options')), findsNothing);
    await tester.tap(find.text('调整'));
    await tester.pumpAndSettle();
    expect(find.text('复制色值'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-color-sampler')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('结束当前页面工具'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-color-sampler')), findsNothing);
    expect(find.bySemanticsLabel('恢复页面操作'), findsOneWidget);
  });

  testWidgets('drag handle moves rail without opening options, tap collapses', (
    tester,
  ) async {
    await _pumpHost(tester, const Size(1180, 820));
    await tester.drag(find.byKey(_handleKey), const Offset(-1000, -100));
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('professional-tool-rail')))
          .dx,
      8,
    );
    expect(find.byKey(const ValueKey('page-tool-options')), findsNothing);
    await tester.tap(find.byKey(_handleKey));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('恢复页面操作'), findsNothing);
    expect(find.byKey(_handleKey), findsOneWidget);
  });

  testWidgets('dialogs, direct toolbox and logout hide global rail', (
    tester,
  ) async {
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
    nav.currentState!.pushNamed<void>('/toolbox');
    await tester.pumpAndSettle();
    expect(find.byKey(_handleKey), findsNothing);
    nav.currentState!.pushNamedAndRemoveUntil('/login', (_) => false);
    await tester.pumpAndSettle();
    expect(find.byKey(_handleKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timer continues collapsed, pauses in full toolbox, restores source',
    (tester) async {
      await _pumpHost(tester, const Size(1024, 768));
      await tester.tap(find.bySemanticsLabel('在当前页面使用速写计时'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始计时'));
      await tester.tap(find.bySemanticsLabel('收起工具参数'));
      await tester.pump();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(FloatingToolboxHost)),
      );
      expect(c.read(pageToolsProvider).running, isTrue);
      await tester.tap(find.bySemanticsLabel('打开完整工具箱，17 个工具'));
      await tester.pumpAndSettle();
      expect(find.text('看画分析'), findsOneWidget);
      expect(find.byKey(_handleKey), findsNothing);
      expect(c.read(pageToolsProvider).running, isFalse);
      await tester.tap(find.text('收起工具'));
      await tester.pumpAndSettle();
      expect(find.text('业务页面 /'), findsOneWidget);
      expect(c.read(pageToolsProvider).tool, ArtTool.quickSketch);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
