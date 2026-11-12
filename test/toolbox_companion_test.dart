import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/companion_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_dock_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/state/companion_controller.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/widgets/art_companion_portrait.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/widgets/toolbox_companion.dart';

Future<void> pumpCompanion(
  WidgetTester tester, {
  ToolboxDockEdge edge = ToolboxDockEdge.right,
  bool motion = true,
  bool reduced = false,
  bool ticker = true,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: ticker,
            child: Align(
              alignment: Alignment.centerRight,
              child: ToolboxCompanion(
                edge: edge,
                expanded: false,
                dragging: false,
                motionEnabled: motion,
                onTap: onTap ?? () {},
                onDragStart: (_) {},
                onDragUpdate: (_) {},
                onDragEnd: (_) {},
                onDragCancel: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ArtCompanionPortrait portrait(WidgetTester tester) =>
    tester.widget<ArtCompanionPortrait>(find.byType(ArtCompanionPortrait));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final edge in ToolboxDockEdge.values) {
    testWidgets(
      '$edge reveals half then one third and preserves a 44px target',
      (tester) async {
        var taps = 0;
        await pumpCompanion(tester, edge: edge, onTap: () => taps++);
        expect(portrait(tester).pose.conceal, 0);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(portrait(tester).pose.conceal, closeTo(0.5, 0.001));
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(portrait(tester).pose.conceal, closeTo(2 / 3, 0.001));
        final target = find.byKey(const ValueKey('floating-toolbox-handle'));
        final size = tester.getSize(target);
        expect(size.shortestSide, greaterThanOrEqualTo(44));
        await tester.tap(target);
        expect(taps, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'hover wakes the face and departure restores its edge resting state',
    (tester) async {
      await pumpCompanion(tester);
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('floating-toolbox-handle'))),
      );
      await tester.pumpAndSettle();
      expect(portrait(tester).pose.conceal, 0);
      expect(portrait(tester).pose.mood, CompanionMood.happy);
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(portrait(tester).pose.conceal, 0.5);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final distanceFromEdge in [12.0, 54.0]) {
    testWidgets(
      'a stationary mouse does not prevent resting: $distanceFromEdge',
      (tester) async {
        await pumpCompanion(tester);
        final target = find.byKey(const ValueKey('floating-toolbox-handle'));
        final bounds = tester.getRect(target);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          Offset(bounds.right - distanceFromEdge, bounds.center.dy),
        );
        await tester.pumpAndSettle();
        expect(portrait(tester).pose.mood, CompanionMood.happy);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(portrait(tester).pose.conceal, 0.5);
        expect(find.text('小画 · 轻点用画具，拖动可贴边'), findsNothing);
        // 收纳可能让鼠标自动离开命中区；离开也不能把角色重新弹出来。
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(portrait(tester).pose.conceal, closeTo(2 / 3, 0.001));
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('only keyboard focus keeps the companion fully revealed', (
    tester,
  ) async {
    final manager = FocusManager.instance;
    final previousStrategy = manager.highlightStrategy;
    addTearDown(() => manager.highlightStrategy = previousStrategy);
    manager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    await pumpCompanion(tester);
    final detector = tester.widget<FocusableActionDetector>(
      find.descendant(
        of: find.byType(ToolboxCompanion),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    detector.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    expect(portrait(tester).pose.conceal, 0);
    // 桌面鼠标也可能处于 traditional 模式；实际按下后应退出键盘聚焦。
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final point = tester.getCenter(
      find.byKey(const ValueKey('floating-toolbox-handle')),
    );
    await mouse.addPointer(location: point);
    await mouse.down(point);
    await mouse.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(detector.focusNode!.hasFocus, isFalse);
    expect(portrait(tester).pose.conceal, 0.5);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'quiet preference or system reduction disables idle gestures: $reduced',
      (tester) async {
        await pumpCompanion(tester, motion: reduced, reduced: reduced);
        await tester.pump(const Duration(seconds: 7));
        await tester.pump(const Duration(milliseconds: 300));
        expect(portrait(tester).pose.blink, 0);
        expect(portrait(tester).pose.peek, 0);
        expect(portrait(tester).pose.wave, 0);
        expect(portrait(tester).pose.dip, 0);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'idle gestures blink, briefly peek, then release their frame clock',
    (tester) async {
      await pumpCompanion(tester);
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 350));
      expect(portrait(tester).pose.blink, greaterThan(0.2));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      // 第三次短动作会探头，之后恢复少露状态。
      await tester.pump(const Duration(seconds: 14));
      await tester.pump(const Duration(milliseconds: 700));
      expect(portrait(tester).pose.peek, greaterThan(0.4));
      await tester.pumpAndSettle();
      expect(portrait(tester).pose.peek, 0);
      expect(portrait(tester).pose.conceal, closeTo(2 / 3, 0.001));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('hidden ticker and background application stop idle actions', (
    tester,
  ) async {
    await pumpCompanion(tester, ticker: false);
    await tester.pump(const Duration(seconds: 30));
    expect(portrait(tester).pose.conceal, 0);
    expect(portrait(tester).pose.look, Offset.zero);
    await pumpCompanion(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(portrait(tester).pose.look, Offset.zero);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });

  test('motion preference survives a fresh controller', () async {
    final preferences = CompanionPreferences();
    final first = CompanionMotionController(preferences);
    first.setMotion(false);
    await Future<void>.delayed(Duration.zero);
    expect(await preferences.loadMotion(), isFalse);
    first.dispose();
    final second = CompanionMotionController(preferences);
    await Future<void>.delayed(Duration.zero);
    expect(second.state, isFalse);
    second.dispose();
  });
}
