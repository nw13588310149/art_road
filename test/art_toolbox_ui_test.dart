import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_catalog.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_image_source.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/image_ops.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/state/toolbox_image_controller.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/art_toolbox_page.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/widgets/image_tool_frame.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/widgets/tool_panel.dart';

class _PreloadedImageController extends ToolboxImageController {
  _PreloadedImageController(ToolboxImage image) : super(ToolboxImageLoader()) {
    state = ToolboxImageState(image: image);
  }
}

/// 80×60 的测试图：左暖右冷、上亮下暗。
ArtImageData _sampleData() {
  const w = 80;
  const h = 60;
  final rgba = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final light = 255 - y * 3;
      rgba[i] = x < w / 2 ? light : light ~/ 3;
      rgba[i + 1] = light ~/ 2;
      rgba[i + 2] = x < w / 2 ? light ~/ 4 : light;
      rgba[i + 3] = 255;
    }
  }
  return ArtImageData(width: w, height: h, rgba: rgba);
}

Future<ToolboxImage> _sampleImage(WidgetTester tester) async {
  final data = _sampleData();
  final image = await tester.runAsync(() => artImageToUiImage(data));
  return ToolboxImage(data: data, image: image!, label: '测试图', version: 1);
}

Future<void> _pumpToolbox(
  WidgetTester tester, {
  required Size size,
  String? tool,
  ToolboxImage? image,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (image != null)
          toolboxImageControllerProvider.overrideWith(
            (ref) => _PreloadedImageController(image),
          ),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(
            name: '/toolbox',
            arguments: tool == null ? null : <String, dynamic>{'tool': tool},
          ),
          builder: (_) => const Scaffold(
            backgroundColor: AppColors.page,
            body: ArtToolboxPage(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // 让后台处理（compute）跑完，再把结果渲染出来。
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final size in const [Size(950, 740), Size(720, 400)]) {
    testWidgets(
      'home switches groups and lists their tools at ${size.width.round()}',
      (tester) async {
        await _pumpToolbox(tester, size: size);
        for (final group in ArtToolGroup.values) {
          expect(find.text(group.label), findsOneWidget);
          await tester.tap(find.text(group.label));
          await tester.pump();
          for (final tool in ArtTool.values) {
            final item = find.text(tool.label);
            expect(item, tool.group == group ? findsOneWidget : findsNothing);
            if (tool.group == group) await tester.ensureVisible(item);
          }
        }
        await tester.tap(find.text(ArtTool.countdown.label));
        await tester.pump();
        await tester.tap(find.byTooltip('返回'));
        await tester.pump();
        expect(find.text(ArtTool.countdown.label), findsOneWidget);
        expect(find.text(ArtTool.value.label), findsNothing);
      },
    );

    for (final tool in ArtTool.values) {
      testWidgets('${tool.key} renders at ${size.width.round()}', (
        tester,
      ) async {
        final image = tool.usesImage ? await _sampleImage(tester) : null;
        await _pumpToolbox(tester, size: size, tool: tool.key, image: image);
        expect(find.byTooltip('返回'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ToolDetailHeader),
            matching: find.text(tool.label),
          ),
          findsOneWidget,
        );
        if (size.width == 720 &&
            const {
              ArtTool.value,
              ArtTool.blur,
              ArtTool.simplify,
              ArtTool.temperature,
              ArtTool.edges,
              ArtTool.mirror,
            }.contains(tool)) {
          final compare = find.text('与原图并排对比');
          final labels = find.byType(StageLabel);
          final initiallyComparing = labels.evaluate().length == 2;
          await tester.ensureVisible(compare);
          await tester.tap(compare);
          await tester.pump();
          if (initiallyComparing) {
            expect(labels, findsOneWidget);
            await tester.tap(compare);
            await tester.pump();
          }
          expect(labels, findsNWidgets(2));
          expect(
            tester.getTopLeft(labels.first).dx,
            lessThan(tester.getTopLeft(labels.last).dx),
          );
        }
        expect(find.text(tool.help), findsNothing);
        await tester.tap(find.byTooltip('工具用法'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text(tool.help), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('timed sketch controls fit a short landscape window', (
    tester,
  ) async {
    await _pumpToolbox(
      tester,
      size: const Size(800, 400),
      tool: ArtTool.quickSketch.key,
    );
    final start = find.text('开始练习');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getBottomRight(find.byType(Image).last).dy,
      lessThan(tester.getTopLeft(find.text('暂停')).dy),
    );
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('已暂停，点击继续'), findsOneWidget);
    await tester.tap(find.text('继续'));
    await tester.pump();
    await tester.tap(find.byTooltip('跳过'));
    await tester.pump();
    await tester.tap(find.byTooltip('结束'));
    await tester.pump();
    expect(find.text('练习回顾'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the grid slider supports single steps in either direction', (
    tester,
  ) async {
    final image = await _sampleImage(tester);
    await _pumpToolbox(
      tester,
      size: const Size(950, 740),
      tool: ArtTool.grid.key,
      image: image,
    );
    final decrease = find.byTooltip('减小不透明度');
    final increase = find.byTooltip('增大不透明度');
    await tester.ensureVisible(decrease);
    expect(find.text('85%'), findsOneWidget);
    await tester.tap(decrease);
    await tester.pump();
    expect(find.text('81%'), findsOneWidget);
    await tester.tap(increase);
    await tester.pump();
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('image tools show the upload prompt without an image', (
    tester,
  ) async {
    await _pumpToolbox(tester, size: const Size(950, 740), tool: '冷暖');
    expect(find.text('上传图片'), findsOneWidget);
    expect(find.text('选一张画作，开始使用「冷暖分布」'), findsOneWidget);
    expect(find.text('暖调静物'), findsOneWidget);
  });

  testWidgets('score calculator shows the Gansu worked example', (
    tester,
  ) async {
    await _pumpToolbox(tester, size: const Size(814, 680), tool: 'score');
    final fields = find.byType(EditableText);
    expect(
      tester.getTopLeft(fields.at(0)).dy,
      tester.getTopLeft(fields.at(1)).dy,
    );
    await tester.enterText(fields.at(0), '500');
    await tester.enterText(fields.at(1), '240');
    await tester.pump();
    expect(find.text('550.00'), findsOneWidget);
    expect(find.text('500 × 50% = 250.00'), findsOneWidget);
    expect(find.textContaining('各省以当年省教育考试院公布为准'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('art_toolbox_score_form_v1'),
      contains('"culture":"500"'),
    );
  });

  testWidgets('checklist ticks persist the progress', (tester) async {
    await _pumpToolbox(tester, size: const Size(950, 740), tool: 'checklist');
    expect(find.text('准考证'), findsOneWidget);
    await tester.tap(find.text('准考证'));
    await tester.pump();
    expect(find.text('1'), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('art_toolbox_exam_checklist_v1'),
      contains('doc-admission'),
    );
  });

  testWidgets('value order check marks misplaced swatches', (tester) async {
    await _pumpToolbox(tester, size: const Size(950, 740), tool: 'valueOrder');
    await tester.tap(find.text('检查顺序'));
    await tester.pump();
    expect(find.textContaining('位置不对'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
  });

  testWidgets('temperature analysis renders the computed shares', (
    tester,
  ) async {
    final image = await _sampleImage(tester);
    await _pumpToolbox(
      tester,
      size: const Size(950, 740),
      tool: 'temperature',
      image: image,
    );
    for (var i = 0; i < 20 && find.text('中性灰').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.text('暖色'), findsOneWidget);
    expect(find.text('冷色'), findsOneWidget);
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('measure tool compares two tapped segments', (tester) async {
    final image = await _sampleImage(tester);
    await _pumpToolbox(
      tester,
      size: const Size(950, 740),
      tool: 'measure',
      image: image,
    );
    final stage = tester.getRect(
      find.byWidgetPredicate(
        (widget) => widget is RawImage && identical(widget.image, image.image),
      ),
    );
    final fit = applyBoxFit(
      BoxFit.contain,
      Size(image.width.toDouble(), image.height.toDouble()),
      stage.size,
    );
    final rect = Alignment.center.inscribe(fit.destination, stage);
    Offset at(double x, double y) =>
        rect.topLeft + Offset(rect.width * x, rect.height * y);
    // 按实际 contain 结果取点，横向或纵向留白都不会影响测量比例。
    for (final point in [
      at(0.2, 0.5),
      at(0.4, 0.5),
      at(0.2, 0.3),
      at(0.6, 0.3),
    ]) {
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('A : B = '), findsNothing);
    expect(find.textContaining('B 段约为 A 段的'), findsOneWidget);
    expect(find.textContaining('1 : 2.00'), findsOneWidget);
  });

  testWidgets('figure tool switches pose notes', (tester) async {
    await _pumpToolbox(tester, size: const Size(950, 740), tool: '人体比例');
    expect(find.textContaining('臂三腿四'), findsOneWidget);
    await tester.tap(find.text('坐姿').first);
    await tester.pump();
    expect(find.textContaining('坐五：'), findsOneWidget);
    expect(find.text('常用参考比例，写生时以对象为准'), findsOneWidget);
  });
}
