import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

const _a = Key('content-a');
const _b = Key('content-b');

/// 竖幅（3:4）和横幅（3:2）两张「画」，同样高度并排，下面是提示和操作。
Future<AppCompareController> _pump(
  WidgetTester tester, {
  AppCompareController? controller,
}) async {
  tester.view.physicalSize = const Size(1000, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = controller ?? AppCompareController();
  addTearDown(c.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: AppCompareView(
                controller: c,
                first: const AppComparePane(
                  label: '范画',
                  aspectRatio: 0.75,
                  child: ColoredBox(key: _a, color: Color(0xFF888888)),
                ),
                second: const AppComparePane(
                  label: '我的原卷',
                  aspectRatio: 1.5,
                  child: ColoredBox(key: _b, color: Color(0xFF444444)),
                ),
              ),
            ),
            AppCompareFooter(controller: c),
          ],
        ),
      ),
    ),
  );
  return c;
}

Rect _box(WidgetTester tester, int index) =>
    tester.getRect(find.byType(AppCompareZoomBox).at(index));

/// 画框正中对着的是画面上的哪一处（按画面宽高的比例）。
Offset _centerFraction(WidgetTester tester, Key content, int box) {
  final viewport = _box(tester, box);
  final drawn = tester.getRect(find.byKey(content));
  return Offset(
    (viewport.center.dx - drawn.left) / drawn.width,
    (viewport.center.dy - drawn.top) / drawn.height,
  );
}

double _drawnScale(WidgetTester tester, Key content, int box) =>
    tester.getRect(find.byKey(content)).width / _box(tester, box).width;

Future<void> _pinch(WidgetTester tester, Offset center, double factor) async {
  const start = 30.0;
  final a = await tester.startGesture(center - const Offset(start, 0));
  final b = await tester.startGesture(center + const Offset(start, 0));
  for (var i = 1; i <= 10; i++) {
    final d = start + start * (factor - 1) * i / 10;
    await a.moveTo(center - Offset(d, 0));
    await b.moveTo(center + Offset(d, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await a.up();
  await b.up();
  await tester.pumpAndSettle();
}

Future<void> _doubleTap(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('panes of different shapes share one height', (tester) async {
    await _pump(tester);
    final left = _box(tester, 0);
    final right = _box(tester, 1);
    expect(left.height, moreOrLessEquals(right.height));
    expect(left.width / left.height, moreOrLessEquals(0.75));
    expect(right.width / right.height, moreOrLessEquals(1.5));
    expect(find.text('范画'), findsOneWidget);
    expect(find.text('我的原卷'), findsOneWidget);
    // 名称在画的上方，不压在画上。
    expect(tester.getBottomLeft(find.text('范画')).dy, lessThan(left.top + 1));
  });

  testWidgets('locked: pinching one side zooms the other to the same spot', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(c.locked, isTrue);
    final left = _box(tester, 0);
    await _pinch(tester, left.center + Offset(-left.width / 5, 0), 3);
    expect(c.side(0).zoom.scale, greaterThan(1.5));
    expect(c.side(1).zoom, c.side(0).zoom);
    // 两侧大小不同，看到的仍是画面上同一个比例位置、同样的倍数。
    expect(
      _drawnScale(tester, _b, 1),
      moreOrLessEquals(_drawnScale(tester, _a, 0), epsilon: 0.01),
    );
    final fa = _centerFraction(tester, _a, 0);
    final fb = _centerFraction(tester, _b, 1);
    expect(fa.dx, lessThan(0.5));
    expect((fa - fb).distance, lessThan(0.01));

    // 拖动一侧，另一侧跟着移。
    await tester.dragFrom(left.center, const Offset(-60, -40));
    await tester.pumpAndSettle();
    final moved = _centerFraction(tester, _a, 0);
    expect((moved - fa).distance, greaterThan(0.02));
    expect((_centerFraction(tester, _b, 1) - moved).distance, lessThan(0.01));
  });

  testWidgets('unlocked sides zoom on their own; re-locking snaps', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('锁定两侧'));
    await tester.pump();
    expect(c.locked, isFalse);
    expect(find.textContaining('未锁定'), findsOneWidget);

    await _pinch(tester, _box(tester, 1).center, 3);
    expect(c.side(1).zoom.scale, greaterThan(1.4));
    expect(c.side(0).zoom.isIdentity, isTrue);
    expect(c.activeSide, 1);
    expect(_drawnScale(tester, _a, 0), moreOrLessEquals(1));
    // 不锁定时，最后摸过的一侧名称加粗。
    final active = tester.widget<Text>(find.text('我的原卷'));
    final other = tester.widget<Text>(find.text('范画'));
    expect(
      active.style!.fontWeight!.value,
      greaterThan(other.style!.fontWeight!.value),
    );

    await tester.tap(find.bySemanticsLabel('锁定两侧'));
    await tester.pump();
    expect(c.locked, isTrue);
    expect(c.side(0), c.side(1));
    expect(
      _drawnScale(tester, _a, 0),
      moreOrLessEquals(_drawnScale(tester, _b, 1), epsilon: 0.01),
    );
  });

  testWidgets('double tap zooms both sides when locked and resets', (
    tester,
  ) async {
    final c = await _pump(tester);
    await _doubleTap(tester, _box(tester, 1).center);
    expect(c.side(1).zoom.scale, AppCompareController.doubleTapScale);
    expect(c.side(0).zoom.scale, AppCompareController.doubleTapScale);
    await _doubleTap(tester, _box(tester, 1).center);
    expect(c.side(0).zoom.isIdentity, isTrue);
    expect(c.side(1).zoom.isIdentity, isTrue);
  });

  testWidgets('rotate and flip follow the lock', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('旋转 90°'));
    await tester.pump();
    expect(c.side(0).quarterTurns, 1);
    expect(c.side(1).quarterTurns, 1);
    // 转了 90° 以后竖幅变横幅，仍然同样高度。
    expect(
      _box(tester, 0).width / _box(tester, 0).height,
      moreOrLessEquals(1 / 0.75),
    );
    expect(_box(tester, 0).height, moreOrLessEquals(_box(tester, 1).height));

    c.setLocked(false);
    await tester.tapAt(_box(tester, 0).center);
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.activeSide, 0);
    await tester.tap(find.bySemanticsLabel('左右翻转'));
    await tester.pump();
    expect(c.side(0).flipX, isTrue);
    expect(c.side(1).flipX, isFalse);

    // 点名称也能换一侧。
    await tester.tap(find.bySemanticsLabel('选中我的原卷'));
    await tester.pump();
    expect(c.activeSide, 1);
    await tester.tap(find.bySemanticsLabel('上下翻转'));
    await tester.pump();
    expect(c.side(1).flipY, isTrue);
    expect(c.side(0).flipY, isFalse);
  });

  test('rotating a mirrored side still turns what you see clockwise', () {
    const side = AppCompareSide(flipX: true);
    final turned = side.rotated();
    expect(turned.quarterTurns, 3);
    expect(turned.flipX, isTrue);
    // 放大的那一处跟着顺时针转：左上角转到右上角。
    const zoomed = AppCompareSide(
      zoom: AppCompareZoom(scale: 4, center: Offset(0.2, 0.2)),
    );
    expect(zoomed.rotated().zoom.center, const Offset(0.8, 0.2));
    expect(zoomed.flippedX().zoom.center.dx, moreOrLessEquals(0.8));
  });

  testWidgets('swap and reset', (tester) async {
    final c = await _pump(tester);
    final before = tester.getTopLeft(find.text('范画')).dx;
    await tester.tap(find.bySemanticsLabel('交换左右'));
    await tester.pump();
    expect(c.swapped, isTrue);
    expect(
      tester.getTopLeft(find.text('范画')).dx,
      greaterThan(tester.getTopLeft(find.text('我的原卷')).dx),
    );
    // 交换后两张仍然同样高度。
    expect(_box(tester, 0).height, moreOrLessEquals(_box(tester, 1).height));

    await tester.tap(find.bySemanticsLabel('旋转 90°'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('复位缩放和摆放'));
    await tester.pump();
    expect(c.isPristine, isTrue);
    expect(c.locked, isTrue);
    expect(tester.getTopLeft(find.text('范画')).dx, moreOrLessEquals(before));
  });

  testWidgets('divider drags and double tap restores the balanced split', (
    tester,
  ) async {
    final c = await _pump(tester);
    final divider = find.bySemanticsLabel('对比分隔线');
    expect(divider, findsOneWidget);
    final balanced = tester.getSemantics(divider).getSemanticsData().value;
    await tester.drag(divider, const Offset(-120, 0));
    await tester.pump();
    expect(c.split, isNotNull);
    expect(
      tester.getSemantics(divider).getSemanticsData().value,
      isNot(balanced),
    );
    final center = tester.getCenter(divider);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(c.split, isNull);
    expect(tester.getSemantics(divider).getSemanticsData().value, balanced);
  });

  testWidgets('overlay shares one zoom and the opacity slider works', (
    tester,
  ) async {
    final c = await _pump(tester);
    c.setMode(AppCompareMode.overlay);
    await tester.pump();
    expect(find.byType(AppCompareZoomBox), findsOneWidget);
    final layer = find.descendant(
      of: find.byType(AppCompareView),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(layer).opacity, 0.5);
    expect(find.text('我的原卷 · 上层'), findsOneWidget);

    final slider = find.bySemanticsLabel('上层不透明度');
    expect(slider, findsOneWidget);
    final track = tester.getRect(slider);
    await tester.tapAt(Offset(track.right - 4, track.center.dy));
    await tester.pump();
    expect(c.overlayOpacity, greaterThan(0.9));
    expect(find.text('100%'), findsOneWidget);

    await _doubleTap(tester, _box(tester, 0).center);
    expect(c.frameZoom.scale, AppCompareController.doubleTapScale);
    // 两层在同一个画框里一起放大（两张都按画框的高度放下）。
    final frame = _box(tester, 0);
    expect(
      tester.getRect(find.byKey(_a)).height / frame.height,
      moreOrLessEquals(AppCompareController.doubleTapScale, epsilon: 0.01),
    );
    expect(
      tester.getRect(find.byKey(_b)).height / frame.height,
      moreOrLessEquals(AppCompareController.doubleTapScale, epsilon: 0.01),
    );

    // 回到并排时，缩放带回去（锁定时两侧都带上）。
    c.setMode(AppCompareMode.sideBySide);
    await tester.pump();
    expect(c.side(0).zoom.scale, AppCompareController.doubleTapScale);
    expect(c.side(1).zoom.scale, AppCompareController.doubleTapScale);
  });

  testWidgets('reveal keeps the divider fixed while the layers zoom', (
    tester,
  ) async {
    final c = await _pump(tester);
    c.setMode(AppCompareMode.reveal);
    await tester.pump();
    final divider = find.bySemanticsLabel('对比分隔线');
    expect(divider, findsOneWidget);
    final x = tester.getCenter(divider).dx;
    await _pinch(tester, _box(tester, 0).center, 3);
    expect(c.frameZoom.scale, greaterThan(1.4));
    expect(tester.getCenter(divider).dx, moreOrLessEquals(x));
    expect(find.textContaining('两张图一起缩放'), findsOneWidget);
  });

  testWidgets('placeholder pane fills its half without zoom', (tester) async {
    tester.view.physicalSize = const Size(1000, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = AppCompareController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCompareView(
            controller: c,
            first: const AppComparePane(
              label: '范画',
              aspectRatio: 0.75,
              child: ColoredBox(key: _a, color: Color(0xFF888888)),
            ),
            second: const AppComparePane.placeholder(
              label: '我的原卷',
              child: Center(child: Text('暂无可对比的素描原卷')),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AppCompareZoomBox), findsOneWidget);
    expect(find.text('暂无可对比的素描原卷'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('zoom maps to a matrix and back for any viewport', () {
    const zoom = AppCompareZoom(scale: 3, center: Offset(0.3, 0.6));
    for (final size in const [Size(300, 400), Size(900, 600)]) {
      final back = AppCompareZoom.fromMatrix(zoom.toMatrix(size), size);
      expect(back.closeTo(zoom), isTrue);
    }
    const outside = AppCompareZoom(scale: 2, center: Offset(0.05, 0.99));
    expect(outside.clamped().center, const Offset(0.25, 0.75));
  });
}
