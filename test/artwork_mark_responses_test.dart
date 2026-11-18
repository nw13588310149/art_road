import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_seed.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_models.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_rules.dart';
import 'package:the_road_of_art_flutter/features/artworks/state/student_artworks_controller.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/artwork_review_workspace.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/student_artwork_detail_view.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/student_artworks_view.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/widgets/artwork_annotation.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/widgets/artwork_mark_list.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/widgets/artwork_mark_response.dart';

const _inReview = DemoArtworkSeed.storyInReviewId;
const _v1 = DemoArtworkSeed.storyRevisionV1Id;
const _v2 = DemoArtworkSeed.storyRevisionV2Id;

Future<dynamic> _call(
  DemoRouter router,
  String method,
  String path,
  DemoAccount account, {
  Map<String, dynamic> body = const {},
  Map<String, dynamic> query = const {},
}) async {
  final endpoint = router.match(method, path)!;
  return await endpoint.handler(
    DemoRequest(
      method: method,
      path: path,
      query: query,
      body: body,
      headers: {'token': account.token},
      pathParams: endpoint.params,
    ),
  );
}

Future<dynamic> _respond(
  String artworkId,
  String markId,
  String status, {
  DemoAccount? account,
  String teacherId = 't-1',
}) => _call(
  DemoBackend.marking,
  'POST',
  '/app/artworks/$artworkId/marks/respond',
  account ?? DemoAccounts.student,
  body: {'teacherId': teacherId, 'markId': markId, 'status': status},
);

Future<ArtworkDetail> _detail(String id, DemoAccount account) async {
  final path = account == DemoAccounts.student
      ? '/app/artworks/$id'
      : '/school/teacher/artworks/$id';
  return ArtworkDetail.fromJson(
    await _call(DemoBackend.marking, 'GET', path, account),
  );
}

Future<ArtworkMark> _markOf(
  String id,
  String markId, {
  DemoAccount? account,
  String teacherId = 't-1',
}) async {
  final review = (await _detail(
    id,
    account ?? DemoAccounts.student,
  )).reviews.firstWhere((r) => r.teacherId == teacherId);
  return review.marks.firstWhere((m) => m.id == markId);
}

Future<List<String>> _unclearNotices(DemoAccount account) async {
  final list = await _call(
    DemoBackend.platform,
    'POST',
    '/app/msg/list',
    account,
  );
  return <String>[
    for (final item in (list as List).cast<Map>())
      if ('${item['content']}'.contains('没看懂')) '${item['content']}',
  ];
}

Matcher _demoError(int code) =>
    throwsA(isA<DemoApiException>().having((e) => e.code, 'code', code));

final _pixel = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget page, {
  required DemoAccount account,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'token': account.token,
  });
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1000, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
      child: MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (_) => Scaffold(backgroundColor: AppColors.page, body: page),
        ),
      ),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byWidget(page)));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Finder _inPopover(Finder finder) =>
    find.descendant(of: find.byType(ArtworkMarkPopover), matching: finder);

void main() {
  setUpAll(registerDemoFixtures);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoStore.init();
    await DemoStore.reset();
    DemoArtworkStore.clearCache();
    ArtworkAnnotatedImage.debugImageProvider = (_) => MemoryImage(_pixel);
  });
  tearDown(() => ArtworkAnnotatedImage.debugImageProvider = null);

  group('数据', () {
    test('回应按状态宽松解析，认不出的当作没有回应', () {
      final mark = ArtworkMark.fromJson({
        'id': 'mk-1',
        'x': 0.5,
        'y': 0.5,
        'text': '耳朵偏低',
        'response': {'status': 'unclear', 'time': '2026-11-17 20:50:00'},
      });
      expect(mark.response?.status, ArtworkMarkResponseStatus.unclear);
      expect(mark.response?.time, '2026-11-17 20:50:00');
      for (final raw in <Object?>[
        null,
        'FIXED',
        {'status': 'NONE'},
        {'status': 'LATER'},
        {'time': 'x'},
      ]) {
        expect(
          ArtworkMark.fromJson({
            'id': 'a',
            'x': 0,
            'y': 0,
            'text': 't',
            'response': raw,
          }).response,
          isNull,
          reason: '$raw',
        );
      }
    });

    test('保存点评时不回传回应，移动、改字都保留回应', () {
      const response = ArtworkMarkResponse(
        status: ArtworkMarkResponseStatus.fixed,
        time: '2026-11-17 12:00:00',
      );
      const mark = ArtworkMark(
        id: 'mk-1',
        x: 0.3,
        y: 0.4,
        text: '背景压灰',
        response: response,
      );
      expect(mark.toJson().containsKey('response'), false);
      expect(mark.copyWith(text: '背景再压灰').response, response);
      expect(
        mark.copyWith(position: const Offset(0.5, 0.5)).response,
        response,
      );
      expect(mark.withResponse(null).response, isNull);
      expect(mark.withResponse(null), isNot(mark));
    });

    test('数量文字带上没看懂的处数', () {
      const unclear = ArtworkMarkResponse(
        status: ArtworkMarkResponseStatus.unclear,
      );
      const marks = [
        ArtworkMark(id: 'a', x: 0, y: 0, text: '1', response: unclear),
        ArtworkMark(id: 'b', x: 0, y: 0, text: '2'),
        ArtworkMark(id: 'c', x: 0, y: 0, text: '3'),
      ];
      expect(ArtworkRules.markCount(marks), '3 处 · 1 处没看懂');
      expect(ArtworkRules.markCount(marks.skip(1), unit: '处定点点评'), '2 处定点点评');
      expect(
        ArtworkRules.markSemantics(
          2,
          '耳朵偏低',
          response: ArtworkMarkResponseStatus.unclear,
        ),
        '第 2 处点评：耳朵偏低，学生标了没看懂',
      );
    });

    test('改了一处的回应，只换那一位老师的那一处', () {
      final detail = ArtworkDetail.fromJson({
        'work': {'id': 'w'},
        'reviews': [
          {
            'teacherId': 't-1',
            'reviewed': true,
            'marks': [
              {'id': 'a', 'x': 0, 'y': 0, 'text': '1'},
            ],
          },
          {
            'teacherId': 't-4',
            'reviewed': true,
            'marks': [
              {'id': 'a', 'x': 0, 'y': 0, 'text': '2'},
            ],
          },
        ],
      });
      final next = detail.withMarkResponse(
        teacherId: 't-4',
        markId: 'a',
        response: const ArtworkMarkResponse(
          status: ArtworkMarkResponseStatus.fixed,
        ),
      );
      expect(next.reviews.first.marks.single.response, isNull);
      expect(
        next.reviews.last.marks.single.response?.status,
        ArtworkMarkResponseStatus.fixed,
      );
    });
  });

  group('演示接口', () {
    test('种子：第 1 版三处带回应，《石膏头像结构练习》第 2 处没看懂', () async {
      final previous = await _detail(_v1, DemoAccounts.student);
      final review = previous.reviews.single;
      expect(review.marks, hasLength(3));
      expect(review.marks.map((m) => m.response?.status), [
        ArtworkMarkResponseStatus.fixed,
        ArtworkMarkResponseStatus.unclear,
        null,
      ]);
      final teacherView = await _markOf(
        _inReview,
        'mk-2',
        account: DemoAccounts.teacher,
      );
      expect(teacherView.response?.status, ArtworkMarkResponseStatus.unclear);
      expect(teacherView.response?.time, isNotEmpty);
    });

    test('只有作品主人能回应；格式不对 400，找不到那一处 404', () async {
      await expectLater(
        _respond(_inReview, 'mk-1', 'FIXED', account: DemoAccounts.teacher),
        _demoError(403),
      );
      await expectLater(_respond(_inReview, 'mk-1', 'LATER'), _demoError(400));
      await expectLater(_respond(_inReview, '', 'FIXED'), _demoError(400));
      await expectLater(_respond(_inReview, 'mk-9', 'FIXED'), _demoError(404));
      await expectLater(
        _respond(_inReview, 'mk-1', 'FIXED', teacherId: 't-4'),
        _demoError(404),
      );
      await expectLater(
        _respond('aw-missing', 'mk-1', 'FIXED'),
        _demoError(404),
      );
      // 还没点评的作品没有可回应的定点点评。
      await expectLater(
        _respond(DemoArtworkSeed.storyPendingId, 'mk-1', 'FIXED'),
        _demoError(404),
      );
    });

    test('标改了、老师端看得到，NONE 清除', () async {
      final saved = await _respond(_inReview, 'mk-1', 'FIXED') as Map;
      expect((saved['response'] as Map)['status'], 'FIXED');
      expect(
        (await _markOf(_inReview, 'mk-1')).response?.status,
        ArtworkMarkResponseStatus.fixed,
      );
      expect(
        (await _markOf(
          _inReview,
          'mk-1',
          account: DemoAccounts.groupLeader,
        )).response?.status,
        ArtworkMarkResponseStatus.fixed,
      );
      final cleared = await _respond(_inReview, 'mk-1', 'NONE') as Map;
      expect(cleared['response'], isNull);
      expect((await _markOf(_inReview, 'mk-1')).response, isNull);
    });

    test('只在标成没看懂的那一下告诉老师，重复标不再发', () async {
      final before = (await _unclearNotices(DemoAccounts.teacher)).length;
      await _respond(_inReview, 'mk-1', 'UNCLEAR');
      var notices = await _unclearNotices(DemoAccounts.teacher);
      expect(notices, hasLength(before + 1));
      expect(notices.first, '【作品】林小雨对《石膏头像结构练习》第 1 处点评标了没看懂：两眼的位置偏高。');
      await _respond(_inReview, 'mk-1', 'UNCLEAR');
      await _respond(_inReview, 'mk-1', 'FIXED');
      expect(
        await _unclearNotices(DemoAccounts.teacher),
        hasLength(before + 1),
      );
      await _respond(_inReview, 'mk-1', 'UNCLEAR');
      expect(
        await _unclearNotices(DemoAccounts.teacher),
        hasLength(before + 2),
      );
      // 种子里已经是没看懂的一处，再标一次不算新的。
      await _respond(_inReview, 'mk-2', 'UNCLEAR');
      expect(
        await _unclearNotices(DemoAccounts.teacher),
        hasLength(before + 2),
      );
    });

    test('老师删掉的一处回应跟着去掉，没动的保留', () async {
      await _respond(_inReview, 'mk-1', 'FIXED');
      final marks = (await _detail(
        _inReview,
        DemoAccounts.teacher,
      )).reviews.single.marks;
      Map<String, dynamic> keep(String id) =>
          marks.firstWhere((m) => m.id == id).toJson();
      Future<void> save(List<Map<String, dynamic>> list) => _call(
        DemoBackend.marking,
        'POST',
        '/school/teacher/artworks/review',
        DemoAccounts.teacher,
        query: {'next': 'false'},
        body: {
          'artworkId': _inReview,
          'score': 88,
          'maxScore': 100,
          'tagIds': <String>[],
          'marks': list,
        },
      );

      await save([keep('mk-1'), keep('mk-3')]);
      final after = (await _detail(
        _inReview,
        DemoAccounts.student,
      )).reviews.single.marks;
      expect(after.map((m) => m.id), ['mk-1', 'mk-3']);
      expect(after.first.response?.status, ArtworkMarkResponseStatus.fixed);

      // 同一个 id 重新加回来，是新的一处，原来的没看懂不再跟着它。
      await save([keep('mk-1'), keep('mk-2'), keep('mk-3')]);
      expect((await _markOf(_inReview, 'mk-2')).response, isNull);
      expect(
        (await _markOf(_inReview, 'mk-1')).response?.status,
        ArtworkMarkResponseStatus.fixed,
      );
    });
  });

  group('界面', () {
    // 对比页和作品列表用网络图片缓存，测试里给它一个临时目录（图片读不到，显示裂图）。
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessenger messenger() =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(() {
      final temp = Directory.systemTemp.createTempSync('mark-responses');
      messenger().setMockMethodCallHandler(
        pathProvider,
        (_) async => temp.path,
      );
    });
    tearDown(() => messenger().setMockMethodCallHandler(pathProvider, null));

    testWidgets('学生点编号标没看懂，再点一次取消', (tester) async {
      await _pump(
        tester,
        StudentArtworkDetailView(artworkId: _inReview, onBack: () {}),
        account: DemoAccounts.student,
      );
      await tester.tap(find.byKey(const ValueKey('mark-pin-t-1/mk-1')));
      await _settle(tester);
      expect(find.byType(ArtworkMarkPopover), findsOneWidget);
      final unclear = _inPopover(
        find.byKey(const ValueKey('mark-respond-1-UNCLEAR')),
      );
      expect(unclear, findsOneWidget);
      expect(find.bySemanticsLabel('第 1 处标为没看懂'), findsNWidgets(2));

      await tester.tap(unclear);
      await _settle(tester);
      expect(
        (await _markOf(_inReview, 'mk-1')).response?.status,
        ArtworkMarkResponseStatus.unclear,
      );
      // 浮层和列表里的同一处一起变成选中。
      expect(find.bySemanticsLabel('第 1 处已标没看懂，再点一次取消'), findsNWidgets(2));
      expect(find.byType(ArtworkMarkPopover), findsOneWidget);

      await tester.tap(unclear);
      await _settle(tester);
      expect((await _markOf(_inReview, 'mk-1')).response, isNull);
      expect(find.bySemanticsLabel('第 1 处标为没看懂'), findsNWidgets(2));
      await _unmount(tester);
    });

    testWidgets('只读打开（推优作品墙）不显示回应按钮', (tester) async {
      await _pump(
        tester,
        StudentArtworkDetailView(
          artworkId: _inReview,
          readOnly: true,
          onBack: () {},
        ),
        account: DemoAccounts.student,
      );
      expect(find.byType(ArtworkMarkResponseButtons), findsNothing);
      await _unmount(tester);
    });

    testWidgets('老师在点评工作台看到学生的回应', (tester) async {
      await _pump(
        tester,
        ArtworkReviewWorkspace(
          artworkId: _inReview,
          onBack: () {},
          onOpenArtwork: (_) {},
        ),
        account: DemoAccounts.teacher,
      );
      await tester.tap(find.widgetWithText(AppButton, '定点点评'));
      await _settle(tester);
      expect(find.text('3 处 · 1 处没看懂'), findsOneWidget);
      expect(find.text('学生：没看懂'), findsOneWidget);
      expect(find.byType(ArtworkMarkResponseButtons), findsNothing);
      await _unmount(tester);
    });

    testWidgets('第 2 版列出上一版的三处，点一处打开对比并放大到那里', (tester) async {
      await _pump(
        tester,
        StudentArtworkDetailView(artworkId: _v2, onBack: () {}),
        account: DemoAccounts.student,
      );
      expect(find.text('上一版的定点点评'), findsOneWidget);
      expect(find.text('3 处 · 1 处没看懂'), findsOneWidget);
      final previous = await _detail(_v1, DemoAccounts.student);
      final teacherId = previous.reviews.single.teacherId;
      final row = find.byKey(ValueKey('previous-mark-$teacherId/mk-2'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('没看懂')),
        findsOneWidget,
      );

      await tester.ensureVisible(row);
      await tester.tap(row);
      await _settle(tester);
      final view = tester.widget<AppCompareView>(find.byType(AppCompareView));
      final expected = const AppCompareZoom(
        scale: 2.5,
        center: Offset(0.2, 0.42),
      ).clamped();
      expect(view.controller.locked, true);
      expect(view.controller.side(0).zoom.closeTo(expected), true);
      expect(view.controller.side(1).zoom.closeTo(expected), true);
      expect(find.text('当前版本'), findsOneWidget);
      expect(find.text('上一版本'), findsOneWidget);
      expect(find.textContaining('第 2 处 · 陶罐暗部'), findsOneWidget);
      await _unmount(tester);
      // 图片缓存 10 秒后的清理。
      await tester.pump(const Duration(seconds: 11));
    });

    Future<void> resubmit(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      DemoArtworkStore.uploads()['qa-revise'] = <String, dynamic>{
        'ref': 'asset:assets/demo/art/color-still-3.jpg',
        'personIndex': 1,
      };
      final image = ArtworkDraftImage(bytes: _pixel, name: 'v3.png');
      final error = await tester.runAsync(
        () => container
            .read(studentArtworksControllerProvider.notifier)
            .submit(
              ArtworkDraft(
                title: '秋日静物色彩写生',
                subject: '色彩',
                drawingDate: ArtworkRules.ymd(DateTime.now()),
                description: '衬布的环境色画得更大胆了。',
                images: [image],
                parentId: _v2,
              ),
              uploaded: {image: 'qa-revise'},
            ),
      );
      expect(error, isNull);
      await _settle(tester);
    }

    testWidgets('改画重交成功后切到新的一版，旧版的「改画重交」不再留着', (tester) async {
      final container = await _pump(
        tester,
        const StudentArtworksView(initialArtworkId: _v2),
        account: DemoAccounts.student,
      );
      expect(find.widgetWithText(AppButton, '改画重交'), findsOneWidget);
      expect(find.text('第 3 版'), findsNothing);

      await resubmit(tester, container);

      final submitted = container.read(studentArtworkSubmittedProvider);
      expect(submitted?.parentId, _v2);
      final view = tester.widget<StudentArtworkDetailView>(
        find.byType(StudentArtworkDetailView),
      );
      expect(view.artworkId, submitted?.id);
      expect(find.text('第 3 版'), findsOneWidget);
      expect(find.widgetWithText(AppButton, '改画重交'), findsNothing);
      await _unmount(tester);
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('不能切换版本时，改画重交成功后原地刷新', (tester) async {
      final page = StudentArtworkDetailView(artworkId: _v2, onBack: () {});
      final container = await _pump(
        tester,
        page,
        account: DemoAccounts.student,
      );
      expect(find.widgetWithText(AppButton, '改画重交'), findsOneWidget);

      await resubmit(tester, container);
      expect(find.widgetWithText(AppButton, '改画重交'), findsNothing);
      await _unmount(tester);
    });
  });
}
