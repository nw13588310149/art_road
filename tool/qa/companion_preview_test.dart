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
  testWidgets('export Xiaohua character sheet from the shipped painter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final loader = FontLoader('PingFang SC')
      ..addFont(rootBundle.load('assets/fonts/ttf/PingFangSC-Regular.otf'));
    await loader.load();
    final boundaryKey = GlobalKey();
    Widget pose(String label, CompanionPose pose) => Column(
      children: [
        ArtCompanionPortrait(size: 104, pose: pose),
        const SizedBox(height: 8),
        Text(label, style: AppText.body13),
      ],
    );
    Widget edgePose(
      String label,
      ToolboxDockEdge edge,
      CompanionPose pose,
    ) {
      final alignment = switch (edge) {
        ToolboxDockEdge.left => Alignment.centerLeft,
        ToolboxDockEdge.right => Alignment.centerRight,
        ToolboxDockEdge.top => Alignment.topCenter,
        ToolboxDockEdge.bottom => Alignment.bottomCenter,
      };
      return Column(
        children: [
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
                        const ArtCompanionPortrait(
                          size: 240,
                          pose: CompanionPose(mood: CompanionMood.happy),
                        ),
                        const SizedBox(height: 16),
                        Text('小画', style: AppText.display32),
                        const SizedBox(height: 8),
                        Text('美育集 · 画室小画童', style: AppText.body14),
                        const SizedBox(height: 12),
                        Text('头顶调色盘，手握水粉笔。', style: AppText.body13),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final size in [64.0, 44.0, 32.0]) ...[
                              ArtCompanionPortrait(
                                size: size,
                                pose: const CompanionPose(
                                  mood: CompanionMood.happy,
                                ),
                              ),
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
                        Text('看形、看色，陪你练画', style: AppText.title20),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            pose('待机', const CompanionPose()),
                            pose(
                              '挥手问好',
                              const CompanionPose(
                                mood: CompanionMood.joy,
                                wave: 1,
                                swing: 0.8,
                              ),
                            ),
                            pose(
                              '蘸颜料',
                              const CompanionPose(
                                mood: CompanionMood.focus,
                                look: Offset(0.3, -1),
                                dip: 1,
                                dipPaint: 1,
                              ),
                            ),
                            pose(
                              '被拎起来',
                              const CompanionPose(
                                mood: CompanionMood.surprised,
                                cheer: 1,
                                tilt: 0.22,
                                squash: -0.12,
                                paint: 2,
                              ),
                            ),
                            pose(
                              '打开画具',
                              const CompanionPose(
                                mood: CompanionMood.happy,
                                cheer: 1,
                                look: Offset(-0.6, 0),
                                paint: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('靠边休息，扒着屏幕边偷看', style: AppText.title16),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            edgePose(
                              '右边 · 一半',
                              ToolboxDockEdge.right,
                              const CompanionPose(
                                conceal: 0.5,
                                look: Offset(-0.55, 0),
                              ),
                            ),
                            edgePose(
                              '右边 · 少露',
                              ToolboxDockEdge.right,
                              const CompanionPose(
                                conceal: 2 / 3,
                                look: Offset(-0.55, 0),
                              ),
                            ),
                            edgePose(
                              '左边 · 挥手',
                              ToolboxDockEdge.left,
                              const CompanionPose(
                                conceal: 2 / 3,
                                peek: 1,
                                wave: 1,
                                swing: 0.6,
                                mood: CompanionMood.joy,
                              ),
                            ),
                            edgePose(
                              '下沿',
                              ToolboxDockEdge.bottom,
                              const CompanionPose(
                                conceal: 2 / 3,
                                look: Offset(0, -0.55),
                              ),
                            ),
                            edgePose(
                              '上沿',
                              ToolboxDockEdge.top,
                              const CompanionPose(
                                conceal: 2 / 3,
                                look: Offset(0, 0.55),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            edgePose(
                              '右边 · 画爱心',
                              ToolboxDockEdge.right,
                              const CompanionPose(
                                conceal: 2 / 3,
                                peek: 0.8,
                                mood: CompanionMood.focus,
                                look: Offset(-0.9, 0),
                                brushOut: 1,
                                stroke: 0.7,
                              ),
                            ),
                            edgePose(
                              '左边 · 画星星',
                              ToolboxDockEdge.left,
                              const CompanionPose(
                                conceal: 0.5,
                                peek: 0.8,
                                mood: CompanionMood.joy,
                                doodle: CompanionDoodle.star,
                                stroke: 1,
                                markFade: 0.3,
                                paint: 1,
                              ),
                            ),
                            edgePose(
                              '下沿 · 画旋涡',
                              ToolboxDockEdge.bottom,
                              const CompanionPose(
                                conceal: 2 / 3,
                                peek: 0.8,
                                mood: CompanionMood.focus,
                                look: Offset(0, -0.9),
                                doodle: CompanionDoodle.swirl,
                                brushOut: 1,
                                stroke: 0.8,
                                paint: 2,
                              ),
                            ),
                            edgePose(
                              '右边 · 蘸色',
                              ToolboxDockEdge.right,
                              const CompanionPose(
                                conceal: 2 / 3,
                                peek: 0.7,
                                mood: CompanionMood.focus,
                                look: Offset(-0.2, -1),
                                dip: 1,
                                dipPaint: 2,
                              ),
                            ),
                            edgePose(
                              '落地 · 星光',
                              ToolboxDockEdge.right,
                              const CompanionPose(
                                mood: CompanionMood.joy,
                                squash: 0.2,
                                sparkle: 0.45,
                              ),
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
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/xiaohua-character.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
