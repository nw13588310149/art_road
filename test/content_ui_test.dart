import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_text_field.dart';
import 'package:the_road_of_art_flutter/features/courseware/ui/courseware_page.dart';
import 'package:the_road_of_art_flutter/features/my_notes/ui/my_notes_page.dart';
import 'package:the_road_of_art_flutter/features/school/ui/school_courseware_page.dart';
import 'package:the_road_of_art_flutter/features/video_tutorial/ui/video_tutorial_page.dart';

class _ContentApi extends Fake implements ApiClient {
  bool unavailable = true;

  @override
  Future<ApiResponse> post(
    String path, {
    Object? data,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool lightweightJson = false,
  }) async {
    final isList =
        path.endsWith('/videoTutorialList') ||
        path.endsWith('/noteCategoryList') ||
        path.endsWith('/coursewareCategoryList');
    if (isList && unavailable) {
      return ApiResponse.failure('服务暂不可用');
    }
    if (path.endsWith('/videoTutorialDetail')) {
      return const ApiResponse(
        code: 0,
        msg: '',
        data: <String, dynamic>{'id': '1', 'name': '范画示范'},
      );
    }
    return const ApiResponse(code: 0, msg: '', data: <dynamic>[]);
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  required Size size,
  ApiClient? client,
  Object? arguments,
}) async {
  SharedPreferences.setMockInitialValues({'token': DemoAccounts.student.token});
  final preferences = await SharedPreferences.getInstance();
  await DemoStore.init();
  await DemoStore.reset();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(preferences)),
        if (client != null) apiClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(name: settings.name, arguments: arguments),
          builder: (_) => Scaffold(body: page),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUpAll(registerDemoFixtures);

  for (final width in [970.0, 814.0]) {
    testWidgets('video recommendation rail stays 255 by 280 at $width', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        const VideoTutorialV2Page(),
        size: Size(width, 732),
      );
      final rail = find.ancestor(
        of: find.text('最新视频'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is AppCard && widget.color == AppColors.surfaceSubtle,
        ),
      );
      expect(tester.getSize(rail), const Size(255, 280));
      expect(tester.widget<AppCard>(rail).color, AppColors.surfaceSubtle);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('cloud filters share a 40px toolbar at $width', (tester) async {
      await _pumpPage(tester, const MyCloudDrivePage(), size: Size(width, 732));
      final field = find.byType(AppTextField);
      expect(tester.getSize(field), const Size(324, 40));
      expect(
        tester.getCenter(field).dy,
        closeTo(tester.getCenter(find.text('排序')).dy, 1),
      );
      expect(
        tester.getCenter(field).dy,
        closeTo(tester.getCenter(find.text('刷新')).dy, 1),
      );
      await tester.tap(find.text('石膏几何体'));
      await _settle(tester);
      expect(find.byTooltip('返回文件夹列表'), findsOneWidget);
      expect(find.text('上传资料'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('school learning progress shows three figures at $width', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        const SchoolCoursewareV2Page(),
        size: Size(width, 732),
      );
      expect(find.text('学习进度'), findsOneWidget);
      expect(find.text('课程进度'), findsNWidgets(3));
      expect(find.text('总共'), findsNWidgets(3));
      expect(find.text('已上'), findsNWidgets(3));
      expect(find.text('剩余'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(1180, 820), const Size(1024, 768)]) {
    testWidgets('video detail keeps the legacy half-width at ${size.width}', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        const VideoTutorialV2Page(),
        size: size,
        client: _ContentApi()..unavailable = false,
        arguments: const {'openVideoId': '1'},
      );
      final detail = find
          .ancestor(
            of: find.byTooltip('关闭'),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Material &&
                  widget.type == MaterialType.transparency,
            ),
          )
          .first;
      expect(tester.getSize(detail).width, size.width / 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long preview titles leave both cloud actions visible', (
    tester,
  ) async {
    final title = List.filled(30, '石膏几何体比例资料').join();
    await _pumpPage(
      tester,
      const MyCloudDrivePage(),
      size: const Size(814, 680),
      arguments: {
        'previewItem': {'id': 123, 'typeValue': 3, 'title': title},
      },
    );
    expect(find.text(title), findsOneWidget);
    final share = tester.getRect(find.text('分享'));
    final delete = tester.getRect(find.text('删除'));
    expect(share.right, lessThan(delete.left));
    expect(delete.right, lessThan(814));
    expect(tester.takeException(), isNull);
  });

  for (final (page, error, empty) in const [
    (VideoTutorialV2Page(), '视频加载失败', '这个分类还没有视频'),
    (MyCloudDrivePage(), '云盘加载失败', '还没有资料分类'),
    (MyNotesPage(), '笔记加载失败', '这个分类还没有笔记'),
  ]) {
    testWidgets(
      '$error can be retried without treating an empty list as a failure',
      (tester) async {
        final client = _ContentApi();
        await _pumpPage(
          tester,
          page,
          size: const Size(814, 680),
          client: client,
        );
        expect(find.text(error), findsOneWidget);
        expect(find.text(empty), findsNothing);

        client.unavailable = false;
        await tester.tap(find.text('重试'));
        await _settle(tester);
        expect(find.text(error), findsNothing);
        expect(find.text(empty), findsOneWidget);
      },
    );
  }
}
