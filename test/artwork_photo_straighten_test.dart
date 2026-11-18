import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/art/photo_rectify.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_rules.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/artwork_upload_dialog.dart';

/// 相册替身：选中一张 400×300 的 JPG，浅灰桌面上一块橙色的画纸。
class _FakePicker extends FilePicker {
  _FakePicker(this.bytes);

  final Uint8List bytes;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: '桌面照片.png', size: bytes.length, bytes: bytes),
  ]);
}

Uint8List _photo() {
  final image = img.Image(width: 400, height: 300);
  img.fill(image, color: img.ColorRgb8(190, 190, 190));
  img.fillRect(
    image,
    x1: 60,
    y1: 40,
    x2: 340,
    y2: 260,
    color: img.ColorRgb8(230, 120, 30),
  );
  return img.encodePng(image);
}

/// 演示接口有模拟延迟，图片解码和后台拉正要真实时间。
Future<void> _wait(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Uint8List _thumbBytes(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(
      of: find.bySemanticsLabel('拉正裁边：第 1 张'),
      matching: find.byType(Image),
    ),
  );
  final provider = image.image;
  final memory = provider is ResizeImage
      ? provider.imageProvider as MemoryImage
      : provider as MemoryImage;
  return memory.bytes;
}

Offset _handle(WidgetTester tester, int i) =>
    tester.getCenter(find.byKey(ValueKey('straighten-handle-$i')));

void main() {
  setUpAll(registerDemoFixtures);

  testWidgets('上传时点照片打开拉正裁边，拖角、完成后替换这张照片', (tester) async {
    final original = _photo();
    FilePicker.platform = _FakePicker(original);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'token': DemoAccounts.student.token,
    });
    final prefs = await SharedPreferences.getInstance();
    await DemoStore.init();
    await DemoStore.reset();
    DemoArtworkStore.clearCache();
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showArtworkUploadDialog(context),
                  child: const Text('打开上传'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开上传'));
    await _wait(tester, () => find.text('添加照片').evaluate().isNotEmpty);
    expect(find.textContaining('点照片可以拉正'), findsNothing);

    await tester.tap(find.text('添加照片'));
    await _wait(
      tester,
      () => find.bySemanticsLabel('拉正裁边：第 1 张').evaluate().isNotEmpty,
    );
    expect(find.textContaining('点照片可以拉正'), findsOneWidget);
    expect(_thumbBytes(tester), same(original));

    await tester.tap(find.bySemanticsLabel('拉正裁边：第 1 张'));
    await _wait(
      tester,
      () => find.byKey(const ValueKey('straighten-handle-0')).evaluate().isNotEmpty,
    );
    expect(find.text('拉正裁边'), findsOneWidget);
    expect(find.text('旋转 90°'), findsOneWidget);
    expect(find.text('复位'), findsOneWidget);

    // 拖动左上角：把手跟着手指走。
    final before = _handle(tester, 0);
    await tester.drag(
      find.byKey(const ValueKey('straighten-handle-0')),
      const Offset(60, 40),
    );
    await tester.pump();
    final after = _handle(tester, 0);
    expect(after.dx - before.dx, closeTo(60, 1));
    expect(after.dy - before.dy, closeTo(40, 1));

    // 拖过右下角会让四边形翻过去：把手停在可用的位置，四边形仍是凸的。
    await tester.drag(
      find.byKey(const ValueKey('straighten-handle-0')),
      const Offset(900, 700),
    );
    await tester.pump();
    final quad = [
      for (var i = 0; i < 4; i++)
        (x: _handle(tester, i).dx, y: _handle(tester, i).dy),
    ];
    expect(isConvexQuad(quad), isTrue);

    await tester.tap(find.text('复位'));
    await tester.pump();
    expect(_handle(tester, 0), before);

    await tester.tap(find.text('完成'));
    await _wait(tester, () => find.text('拉正裁边').evaluate().isEmpty);
    expect(find.text('拉正裁边'), findsNothing);
    expect(find.text('提交作品'), findsOneWidget);

    final replaced = _thumbBytes(tester);
    expect(replaced, isNot(same(original)));
    expect(ArtworkRules.imageError(replaced), isNull);
    final decoded = img.decodeJpg(replaced)!;
    // 默认四个角各收 4%：400×300 的照片裁成约 368×276。
    expect(decoded.width, closeTo(368, 2));
    expect(decoded.height, closeTo(276, 2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });
}
