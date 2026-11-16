// 用实际 Flutter 组件导出小画的形象板：
// flutter test --no-pub tool/qa/companion_preview_test.dart
// 产物在 build/qa/xiaohua-character.png。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_dock_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/floating_toolbox_host.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/toolbox_route_observer.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/widgets/art_companion_portrait.dart';

Future<void> _loadFonts() async {
  final text = FontLoader('PingFang SC')
    ..addFont(rootBundle.load('assets/fonts/ttf/PingFangSC-Regular.otf'));
  await text.load();
  // 图标字体在 Flutter SDK 里；找不到时图标显示为方块，不影响导出。
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!icons.existsSync()) return;
  final bytes = icons.readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _export(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/qa/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('export Xiaohua character sheet from the shipped portrait', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _loadFonts();
    final boundaryKey = GlobalKey();
    Widget pose(String label, CompanionPose pose) => Column(
      children: [
        ArtCompanionPortrait(size: 104, pose: pose),
        const SizedBox(height: 8),
        Text(label, style: AppText.body13),
      ],
    );
    Widget edgePose(String label, ToolboxDockEdge edge, CompanionPose pose) {
      final alignment = switch (edge) {
        ToolboxDockEdge.left => Alignment.centerLeft,
        ToolboxDockEdge.right => Alignment.centerRight,
        ToolboxDockEdge.top => Alignment.topCenter,
        ToolboxDockEdge.bottom => Alignment.bottomCenter,
      };
      return Column(
        children: [
          // 方框的边就是屏幕的边：框外的部分在实际页面上看不到。
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: AppColors.page,
              border: Border.all(color: AppColors.line),
              borderRadius: AppRadius.br12,
            ),
            clipBehavior: Clip.antiAlias,
            child: Align(
              alignment: alignment,
              child: ArtCompanionPortrait(size: 96, edge: edge, pose: pose),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppText.body13),
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: Material(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ArtCompanionPortrait(size: 240),
                        const SizedBox(height: 16),
                        Text('小画', style: AppText.display32),
                        const SizedBox(height: 8),
                        Text('美育集 · 画具入口', style: AppText.body14),
                        const SizedBox(height: 12),
                        Text('戴圆眼镜、抱着笔记本的猫头鹰。', style: AppText.body13),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final size in [64.0, 44.0, 32.0]) ...[
                              ArtCompanionPortrait(size: size),
                              const SizedBox(width: 16),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('站在页面上', style: AppText.title20),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            pose('待机', const CompanionPose()),
                            pose('晃着打招呼', const CompanionPose(sway: 1)),
                            pose('点头', const CompanionPose(nod: 1)),
                            pose(
                              '被拎起来',
                              const CompanionPose(tilt: 0.22, squash: -0.12),
                            ),
                            pose(
                              '落地 · 星光',
                              const CompanionPose(squash: 0.2, sparkle: 0.45),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('靠边休息，从屏幕边上探头', style: AppText.title16),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            edgePose(
                              '右边 · 一半',
                              ToolboxDockEdge.right,
                              const CompanionPose(conceal: 0.5),
                            ),
                            edgePose(
                              '右边 · 少露',
                              ToolboxDockEdge.right,
                              const CompanionPose(conceal: 2 / 3),
                            ),
                            edgePose(
                              '右边 · 探身',
                              ToolboxDockEdge.right,
                              const CompanionPose(
                                conceal: 2 / 3,
                                peek: 1,
                                sway: 0.6,
                              ),
                            ),
                            edgePose(
                              '左边 · 一半',
                              ToolboxDockEdge.left,
                              const CompanionPose(conceal: 0.5),
                            ),
                            edgePose(
                              '左边 · 少露',
                              ToolboxDockEdge.left,
                              const CompanionPose(conceal: 2 / 3),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            edgePose(
                              '下沿 · 一半',
                              ToolboxDockEdge.bottom,
                              const CompanionPose(conceal: 0.5),
                            ),
                            edgePose(
                              '下沿 · 少露',
                              ToolboxDockEdge.bottom,
                              const CompanionPose(conceal: 2 / 3),
                            ),
                            edgePose(
                              '上沿 · 一半',
                              ToolboxDockEdge.top,
                              const CompanionPose(conceal: 0.5),
                            ),
                            edgePose(
                              '上沿 · 少露',
                              ToolboxDockEdge.top,
                              const CompanionPose(conceal: 2 / 3),
                            ),
                            edgePose(
                              '上沿 · 站立',
                              ToolboxDockEdge.top,
                              const CompanionPose(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // 图片解码是真实异步，要在 runAsync 里等它完成。
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(companionAsset),
        tester.element(find.byType(ArtCompanionPortrait).first),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _export(tester, boundaryKey, 'xiaohua-character.png');
  });

  testWidgets('export Xiaohua and the tool rail on a page', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
    final observer = ToolboxRouteObserver();
    addTearDown(observer.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ProviderScope(
          child: MaterialApp(
            navigatorObservers: [observer],
            builder: (_, child) =>
                FloatingToolboxHost(observer: observer, child: child!),
            home: Scaffold(
              backgroundColor: AppColors.page,
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('业务页面', style: AppText.title20),
                    const SizedBox(height: 16),
                    for (var i = 0; i < 4; i++) ...[
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.br12,
                            border: Border.all(color: AppColors.line),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(companionAsset),
        tester.element(find.byType(ArtCompanionPortrait)),
      ),
    );
    await tester.pumpAndSettle();
    await _export(tester, boundaryKey, 'xiaohua-page-1-standing.png');
    // 3 秒露出一半，12 秒后只留眼睛。
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await _export(tester, boundaryKey, 'xiaohua-page-2-half.png');
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await _export(tester, boundaryKey, 'xiaohua-page-3-least.png');
    await tester.tap(find.byKey(const ValueKey('floating-toolbox-handle')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await _export(tester, boundaryKey, 'xiaohua-page-4-rail.png');
    expect(tester.takeException(), isNull);
  });
}
