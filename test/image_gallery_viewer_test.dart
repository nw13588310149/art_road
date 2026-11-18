import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:the_road_of_art_flutter/app/router/route_paths.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/core/widgets/image_gallery_viewer.dart';
import 'package:the_road_of_art_flutter/core/widgets/image_viewer_page.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/viewer/art_viewer_toolkit.dart';

/// 纯色 PNG 的 data 地址，看图页按普通图片地址加载。
String _png(int width, int height, {int r = 200, int g = 120, int b = 60}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return 'data:image/png;base64,${base64Encode(img.encodePng(image))}';
}

class _Pushes extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
}

Future<void> _settle(WidgetTester tester, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<_Pushes> _open(
  WidgetTester tester,
  List<String> images, {
  List<String> titles = const <String>[],
  bool tools = true,
  bool injectTools = true,
  int initialIndex = 0,
}) async {
  tester.view.physicalSize = const Size(1180, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final pushes = _Pushes();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (injectTools)
          imageViewerToolkitProvider.overrideWithValue(
            const ArtImageViewerToolkit(),
          ),
      ],
      child: MaterialApp(
        navigatorObservers: [pushes],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text('工具箱 ${settings.arguments}'),
        ),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showImageGallery(
                context,
                images: images,
                titles: titles,
                tools: tools,
                initialIndex: initialIndex,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await _settle(tester);
  return pushes;
}

bool _selected(WidgetTester tester, String label) =>
    tester
        .getSemantics(find.bySemanticsLabel(label))
        .flagsCollection
        .isSelected ==
    ui.Tristate.isTrue;

void main() {
  testWidgets('opens on an opaque dark page with a title and counter', (
    tester,
  ) async {
    final pushes = await _open(
      tester,
      [_png(60, 80), _png(80, 60, r: 40, g: 40, b: 40)],
      titles: ['大卫石膏像', '静物'],
    );
    expect(pushes.routes.last.settings.name, imageViewerRouteName);
    expect((pushes.routes.last as ModalRoute<dynamic>).opaque, isTrue);
    expect(find.text('大卫石膏像'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    final material = tester.widget<Material>(
      find
          .ancestor(of: find.byType(PageView), matching: find.byType(Material))
          .first,
    );
    expect(material.color, AppColors.canvasDark);
    expect(find.bySemanticsLabel('关闭'), findsOneWidget);
    expect(find.bySemanticsLabel('向左旋转'), findsOneWidget);
    expect(find.bySemanticsLabel('向右旋转'), findsOneWidget);
  });

  testWidgets('shows the whole picture: a portrait image is contained', (
    tester,
  ) async {
    await _open(tester, [_png(600, 800)]);
    final rect = tester.getRect(find.byType(RawImage).first);
    final viewport = tester.getRect(find.byType(PageView));
    // 上下各留 16。
    final height = viewport.height - 32;
    expect(rect.height, moreOrLessEquals(height, epsilon: 1));
    expect(rect.width, moreOrLessEquals(height * 0.75, epsilon: 1));
    expect(rect.center.dx, moreOrLessEquals(viewport.center.dx, epsilon: 1));
    expect(rect.center.dy, moreOrLessEquals(viewport.center.dy, epsilon: 1));
  });

  testWidgets('swipe, arrow keys and the next button change the image', (
    tester,
  ) async {
    await _open(
      tester,
      [_png(60, 80), _png(80, 60), _png(70, 70)],
      titles: ['第一张', '第二张', '第三张'],
    );
    expect(find.text('第一张'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1500);
    await _settle(tester);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('第二张'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester, 2);
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('上一张'));
    await _settle(tester, 2);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('close and Escape both leave the viewer', (tester) async {
    await _open(tester, [_png(60, 80)], titles: ['范画']);
    await tester.tap(find.bySemanticsLabel('关闭'));
    await _settle(tester, 4);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ImageGalleryViewer), findsNothing, reason: '关闭');

    await tester.tap(find.text('打开'));
    await _settle(tester);
    expect(find.byType(ImageGalleryViewer), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester, 4);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ImageGalleryViewer), findsNothing, reason: 'Esc');
  });

  testWidgets('tools toggle, stay exclusive and reset with 原图', (tester) async {
    await _open(tester, [_png(60, 80)]);
    expect(_selected(tester, '原图'), isTrue);

    await tester.tap(find.bySemanticsLabel('灰度'));
    await tester.pump();
    expect(_selected(tester, '灰度'), isTrue);
    expect(_selected(tester, '原图'), isFalse);
    expect(find.byType(ColorFiltered), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('构图网格'));
    await tester.pump();
    expect(_selected(tester, '构图网格'), isTrue);
    expect(_selected(tester, '灰度'), isTrue, reason: '网格可以和灰度叠加');
    expect(find.bySemanticsLabel('九宫格'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('明度色阶'));
    await tester.pump();
    expect(_selected(tester, '明度色阶'), isTrue);
    expect(_selected(tester, '灰度'), isFalse, reason: '画面处理只能选一种');
    expect(find.bySemanticsLabel('3 档'), findsOneWidget);
    await _settle(tester, 10);

    await tester.tap(find.bySemanticsLabel('原图'));
    await tester.pump();
    for (final label in ['明度色阶', '构图网格', '灰度']) {
      expect(_selected(tester, label), isFalse, reason: label);
    }
    expect(_selected(tester, '原图'), isTrue);
  });

  testWidgets('picking a color shows HEX and value', (tester) async {
    await _open(tester, [_png(60, 80, r: 200, g: 120, b: 60)]);
    await tester.tap(find.bySemanticsLabel('取色'));
    await tester.pump();
    expect(find.text('点画面任意一处取色'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await _settle(tester, 10);
    expect(find.text('#C8783C'), findsOneWidget);
    expect(find.textContaining('明度 '), findsOneWidget);
  });

  testWidgets('measuring two segments shows their ratio', (tester) async {
    await _open(tester, [_png(600, 800)]);
    await tester.tap(find.bySemanticsLabel('比例测量'));
    await tester.pump();
    expect(find.text('依次点两个点量出 A 段，再点两个点量出 B 段'), findsOneWidget);

    final rect = tester.getRect(find.byType(RawImage).first);
    Future<void> tapImage(double x, double y) async {
      await tester.tapAt(
        Offset(rect.left + rect.width * x, rect.top + rect.height * y),
      );
      // 单击要等过了双击的判定时间才算数。
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      await tester.pump();
    }

    // 画面上方的点（缩放前在视口之外）也要能点到。
    await tapImage(0.1, 0.1);
    await tapImage(0.1, 0.3);
    await tapImage(0.5, 0.1);
    await tapImage(0.5, 0.5);
    expect(find.text('1 : 2.00'), findsOneWidget);
    expect(find.textContaining('接近 1 : 2'), findsOneWidget);

    // 第五个点重新开始量 A 段。
    await tapImage(0.2, 0.2);
    expect(find.text('再点一个点完成 A 段'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('清除测量线'));
    await tester.pump();
    expect(find.text('依次点两个点量出 A 段，再点两个点量出 B 段'), findsOneWidget);
  });

  testWidgets('mirroring flips the picture but not the tool bar', (
    tester,
  ) async {
    await _open(tester, [_png(60, 80)]);
    await tester.tap(find.bySemanticsLabel('镜像'));
    await tester.pump();
    expect(_selected(tester, '左右'), isTrue);
    final flipped = tester.widget<Transform>(
      find
          .ancestor(of: find.byType(RawImage), matching: find.byType(Transform))
          .first,
    );
    expect(flipped.transform.storage[0], -1);

    await tester.tap(find.bySemanticsLabel('上下'));
    await tester.pump();
    expect(_selected(tester, '上下'), isTrue);
    expect(_selected(tester, '镜像'), isTrue);
  });

  testWidgets('switching images keeps the tools and clears the marks', (
    tester,
  ) async {
    await _open(tester, [_png(60, 80), _png(80, 60)]);
    await tester.tap(find.bySemanticsLabel('灰度'));
    await tester.tap(find.bySemanticsLabel('取色'));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await _settle(tester, 10);
    expect(find.text('#C8783C'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('下一张'));
    await _settle(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(_selected(tester, '灰度'), isTrue);
    expect(_selected(tester, '取色'), isTrue);
    expect(find.text('#C8783C'), findsNothing);
    expect(find.text('点画面任意一处取色'), findsOneWidget);
  });

  testWidgets('更多工具 opens the toolbox with the tool, image and title', (
    tester,
  ) async {
    final src = _png(60, 80);
    final pushes = await _open(tester, [src], titles: ['大卫石膏像']);
    await tester.tap(find.bySemanticsLabel('镜像'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('更多工具，在画室工具箱里打开这张图'));
    await _settle(tester, 2);
    final route = pushes.routes.last;
    expect(route.settings.name, RoutePaths.artToolbox);
    expect(route.settings.arguments, <String, dynamic>{
      'tool': 'mirror',
      'imageUrl': src,
      'title': '大卫石膏像',
    });
  });

  testWidgets('without tools there is no tool bar', (tester) async {
    await _open(tester, [_png(60, 80)], tools: false);
    expect(find.bySemanticsLabel('灰度'), findsNothing);
    expect(find.bySemanticsLabel('关闭'), findsOneWidget);
  });

  testWidgets('without an injected toolkit there is no tool bar', (
    tester,
  ) async {
    await _open(tester, [_png(60, 80)], injectTools: false);
    expect(find.bySemanticsLabel('灰度'), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
  });

  test('image addresses: assets, network with headers, size limit', () {
    final asset = imageViewerProvider(
      'asset:assets/demo/art/sketch-bust-1.jpg',
      maxExtent: 2048,
    );
    expect(asset, isA<ResizeImage>());
    final assetBase = (asset as ResizeImage).imageProvider;
    expect(assetBase, isA<AssetImage>());
    expect(
      (assetBase as AssetImage).assetName,
      'assets/demo/art/sketch-bust-1.jpg',
    );
    expect(asset.width, 2048);
    expect(asset.policy, ResizeImagePolicy.fit);

    final plain = imageViewerProvider('assets/demo/art/sketch-bust-1.jpg');
    expect(plain, isA<AssetImage>());

    final network = imageViewerProvider(
      'https://example.com/a.png',
      headers: {'school-token': 't'},
    );
    expect(network, isA<CachedNetworkImageProvider>());
    expect((network as CachedNetworkImageProvider).headers, {
      'school-token': 't',
    });
    expect(network.url, 'https://example.com/a.png');
  });
}
