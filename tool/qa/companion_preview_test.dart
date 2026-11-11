// 用实际 Flutter 角色绘制导出形象板：flutter test --no-pub tool/qa/companion_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_dock_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/widgets/art_companion_portrait.dart';

void main() {
  testWidgets('export Xiaomo character sheet from the shipped painter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 460);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final loader = FontLoader('PingFang SC')
      ..addFont(rootBundle.load('assets/fonts/ttf/PingFangSC-Regular.otf'));
    await loader.load();
    final boundaryKey = GlobalKey();
    Widget pose(
      String label, {
      bool happy = false,
      bool carried = false,
      double blink = 0,
    }) => Column(
      children: [
        ArtCompanionPortrait(
          size: 92,
          happy: happy,
          carried: carried,
          blink: blink,
        ),
        const SizedBox(height: 10),
        Text(label, style: AppText.body13),
      ],
    );
    Widget edgePose(String label, ToolboxDockEdge edge, double fraction) {
      final outward = switch (edge) {
        ToolboxDockEdge.left => const Offset(-1, 0),
        ToolboxDockEdge.right => const Offset(1, 0),
        ToolboxDockEdge.top => const Offset(0, -1),
        ToolboxDockEdge.bottom => const Offset(0, 1),
      };
      return Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border.all(color: AppColors.line),
              borderRadius: AppRadius.br12,
            ),
            clipBehavior: Clip.antiAlias,
            child: Transform.translate(
              offset: outward * (82 * fraction),
              child: ArtCompanionPortrait(
                size: 82,
                edge: edge,
                conceal: fraction,
              ),
            ),
          ),
          const SizedBox(height: 10),
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
              padding: const EdgeInsets.all(36),
              child: Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ArtCompanionPortrait(size: 208, happy: true),
                        const SizedBox(height: 20),
                        Text('小墨', style: AppText.display32),
                        const SizedBox(height: 8),
                        Text('美育集 · 画室小精灵', style: AppText.body14),
                        const SizedBox(height: 12),
                        Text('一团颜料，一撮笔锋。', style: AppText.body13),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('看形、看色，陪你练画', style: AppText.title20),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            pose('展开 · 微笑', happy: true),
                            pose('待机 · 眨眼', blink: 1),
                            pose('拖动 · 好奇', carried: true),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text('靠边休息，轻点就到', style: AppText.title16),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            edgePose('半露', ToolboxDockEdge.left, 0.5),
                            edgePose('少露', ToolboxDockEdge.right, 2 / 3),
                            edgePose('上沿', ToolboxDockEdge.top, 0.5),
                            edgePose('下沿', ToolboxDockEdge.bottom, 0.5),
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
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/xiaomo-character.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
