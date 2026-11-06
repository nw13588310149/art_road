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
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final size in const [Size(950, 740), Size(720, 700)]) {
    testWidgets('home lists every group and tool at ${size.width.round()}', (
      tester,
    ) async {
      await _pumpToolbox(tester, size: size);
      for (final group in ArtToolGroup.values) {
        expect(find.text(group.label), findsOneWidget);
      }
      for (final tool in ArtTool.values) {
        await tester.scrollUntilVisible(
          find.text(tool.label),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(tool.label), findsOneWidget);
      }
    });

    for (final tool in ArtTool.values) {
      testWidgets('${tool.key} renders at ${size.width.round()}', (
        tester,
      ) async {
        final image = tool.usesImage ? await _sampleImage(tester) : null;
        await _pumpToolbox(tester, size: size, tool: tool.key, image: image);
        expect(find.text(tool.label), findsWidgets);
        expect(find.text(tool.help), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('image tools show the upload prompt without an image', (
    tester,
  ) async {
    await _pumpToolbox(tester, size: const Size(950, 740), tool: '冷暖');
    expect(find.text('上传图片'), findsOneWidget);
    expect(find.text('使用示例画作'), findsOneWidget);
    expect(find.text('暖调静物'), findsOneWidget);
  });

  testWidgets('score calculator shows the Gansu worked example', (
    tester,
  ) async {
    await _pumpToolbox(tester, size: const Size(950, 740), tool: 'score');
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), '500');
    await tester.enterText(fields.at(1), '240');
    await tester.pump();
    expect(find.text('550.00'), findsOneWidget);
    expect(find.text('500 × 50% = 250.00'), findsOneWidget);
    expect(find.textContaining('各省以当年省教育考试院公布为准'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('art_toolbox_score_form_v1'), contains('"culture":"500"'));
  });

  testWidgets('checklist ticks persist the progress', (tester) async {
    await _pumpToolbox(tester, size: const Size(950, 740), tool: 'checklist');
    expect(find.text('准考证'), findsOneWidget);
    await tester.tap(find.text('准考证'));
    await tester.pump();
    expect(find.text('1'), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('art_toolbox_exam_checklist_v1'), contains('doc-admission'));
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
    final rect = tester.getRect(find.byType(RawImage).first);
    Offset at(double x, double y) =>
        rect.topLeft + Offset(rect.width * x, rect.height * y);
    // 图片按 contain 居中，80×60 的图在舞台里宽度撑满，取点都落在图内。
    for (final point in [at(0.2, 0.5), at(0.4, 0.5), at(0.2, 0.3), at(0.6, 0.3)]) {
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
