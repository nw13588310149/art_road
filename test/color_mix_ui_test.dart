import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_image_source.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/image_ops.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/state/toolbox_image_controller.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/art_toolbox_page.dart';

class _PreloadedImageController extends ToolboxImageController {
  _PreloadedImageController(ToolboxImage image) : super(ToolboxImageLoader()) {
    state = ToolboxImageState(image: image);
  }
}

/// 80×60 的纯中灰图：在哪里取色都是同一个灰。
ArtImageData _grey() {
  const w = 80, h = 60;
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < rgba.length; i += 4) {
    rgba[i] = 128;
    rgba[i + 1] = 128;
    rgba[i + 2] = 128;
    rgba[i + 3] = 255;
  }
  return ArtImageData(width: w, height: h, rgba: rgba);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  for (final size in const [Size(950, 740), Size(814, 680)]) {
    testWidgets('取色后显示调色参考（${size.width.round()} 宽）', (tester) async {
      final data = _grey();
      final ui = await tester.runAsync(() => artImageToUiImage(data));
      final image = ToolboxImage(data: data, image: ui!, label: '灰', version: 1);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            toolboxImageControllerProvider.overrideWith(
              (ref) => _PreloadedImageController(image),
            ),
          ],
          child: MaterialApp(
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: const RouteSettings(
                name: '/toolbox',
                arguments: <String, dynamic>{'tool': 'color'},
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
      expect(find.text('调色参考'), findsNothing);

      final stage = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is RawImage && identical(w.image, image.image),
        ),
      );
      await tester.tapAt(stage.center);
      await tester.pump();
      expect(find.text('调色参考'), findsOneWidget);

      final rows = find.bySemanticsLabel(RegExp(r'份，(接近|大致|偏差较大)$'));
      for (var i = 0; i < 40 && rows.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      // 中灰：第一个配方是白加黑，三行配方各带匹配程度。
      expect(rows, findsNWidgets(3));
      expect(find.bySemanticsLabel('白 3 份 + 黑 2 份，接近'), findsOneWidget);
      expect(
        tester.getTopLeft(find.bySemanticsLabel('白 3 份 + 黑 2 份，接近')).dy,
        lessThan(tester.getTopLeft(rows.at(1)).dy),
      );
      expect(find.textContaining('不同品牌有色差'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
