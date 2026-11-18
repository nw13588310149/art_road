import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/audio/recording/recording_playback.dart';
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
import 'package:the_road_of_art_flutter/features/artworks/state/artwork_voice_player.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/artwork_review_workspace.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/student_artwork_detail_view.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/widgets/artwork_annotation.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/widgets/artwork_mark_editor.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/widgets/artwork_mark_layer.dart';

const _voice = 'http://127.0.0.1/f/mark_voice.m4a';

Future<dynamic> _call(
  String method,
  String path,
  DemoAccount account, {
  Map<String, dynamic> body = const {},
  Map<String, dynamic> query = const {},
}) async {
  final router = DemoBackend.marking;
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

Future<dynamic> _saveReview(
  DemoAccount account,
  String artworkId, {
  Object? marks,
  String content = '',
  double? score,
}) => _call(
  'POST',
  '/school/teacher/artworks/review',
  account,
  query: {'next': 'false'},
  body: {
    'artworkId': artworkId,
    'score': score,
    'maxScore': 100,
    'content': content.isEmpty ? null : content,
    'tagIds': <String>[],
    'marks': ?marks,
  },
);

Future<List<ArtworkReview>> _reviewsAs(
  DemoAccount account,
  String artworkId,
) async {
  final path = account == DemoAccounts.student
      ? '/app/artworks/$artworkId'
      : '/school/teacher/artworks/$artworkId';
  return ArtworkDetail.fromJson(await _call('GET', path, account)).reviews;
}

Map<String, dynamic> _mark(
  String text, {
  double x = 0.5,
  double y = 0.5,
  int imageIndex = 0,
  String voice = '',
}) => {
  'id': 'mk-${text.hashCode}',
  'imageIndex': imageIndex,
  'x': x,
  'y': y,
  'text': text,
  if (voice.isNotEmpty) 'voiceUrl': voice,
  if (voice.isNotEmpty) 'voiceSeconds': 12,
};

Matcher _demoError(int code) =>
    throwsA(isA<DemoApiException>().having((e) => e.code, 'code', code));

/// 不出声的播放器：记下播了什么、有没有被停掉。
class _FakePlayback implements RecordingPlayback {
  _FakePlayback() {
    created.add(this);
  }

  static final created = <_FakePlayback>[];

  final _status = StreamController<RecordingPlaybackStatus>.broadcast();
  String? source;
  bool playing = false;
  bool disposed = false;

  @override
  Stream<int> get positionMs => const Stream<int>.empty();
  @override
  Stream<int> get durationMs => const Stream<int>.empty();
  @override
  Stream<RecordingPlaybackStatus> get status => _status.stream;
  @override
  bool get isPlaying => playing;
  @override
  bool get isCompleted => false;
  @override
  int? get currentDurationMs => 12000;

  @override
  Future<int?> setSource(String source, {required bool isUrl}) async {
    this.source = source;
    return 12000;
  }

  @override
  Future<int?> setSources(
    List<String> sources, {
    required bool isUrl,
    List<int>? segmentDurationsMs,
    int? totalDurationMs,
  }) async => null;

  void _emit(bool value) {
    playing = value;
    if (!_status.isClosed) {
      _status.add(RecordingPlaybackStatus(playing: value, completed: false));
    }
  }

  @override
  Future<void> play() async => _emit(true);
  @override
  Future<void> pause() async => _emit(false);
  @override
  Future<void> stop() async => _emit(false);
  @override
  Future<void> seek(int positionMs) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    playing = false;
    await _status.close();
  }
}

/// 1×1 的 PNG：测试环境加载不了网络图片，作品图都换成它。
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

Future<void> _pump(
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
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(prefs)),
        artworkPlaybackFactoryProvider.overrideWithValue(_FakePlayback.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          builder: (_) => Scaffold(backgroundColor: AppColors.page, body: page),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Finder _dot(int number, {required bool selected}) => find.byWidgetPredicate(
  (w) => w is ArtworkMarkDot && w.number == number && w.selected == selected,
);

void main() {
  setUpAll(registerDemoFixtures);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoStore.init();
    await DemoStore.reset();
    DemoArtworkStore.clearCache();
    _FakePlayback.created.clear();
    ArtworkAnnotatedImage.debugImageProvider = (_) => MemoryImage(_pixel);
  });
  tearDown(() => ArtworkAnnotatedImage.debugImageProvider = null);

  group('ArtworkMark 数据', () {
    test('JSON 往返、坐标夹在 0–1、兼容 voiceRef', () {
      const mark = ArtworkMark(
        id: 'mk-1',
        x: 0.25,
        y: 0.75,
        imageIndex: 1,
        text: '三大面区分不够',
        voiceUrl: 'f/a.m4a',
        voiceSeconds: 12,
      );
      expect(ArtworkMark.fromJson(mark.toJson()), mark);
      final clamped = ArtworkMark.fromJson({
        'id': 'mk-2',
        'x': 1.4,
        'y': -0.2,
        'text': '投影',
        'voiceRef': 'f/b.m4a',
      });
      expect(clamped.position, const Offset(1, 0));
      expect(clamped.voiceUrl, 'f/b.m4a');
      expect(const ArtworkMark(id: 'e', x: 0, y: 0, text: '  ').isEmpty, true);
    });

    test('点评带定点点评：丢弃空的一处，只有定点点评也算可见', () {
      final review = ArtworkReview.fromJson({
        'teacherId': 't-1',
        'reviewed': true,
        'marks': [
          {'id': 'a', 'x': 0.1, 'y': 0.1, 'text': '眼睛偏高'},
          {'id': 'b', 'x': 0.2, 'y': 0.2, 'text': ''},
        ],
      });
      expect(review.marks.map((m) => m.id), ['a']);
      expect(review.visible, true);
    });

    test('编号按老师先后、再按图片和添加先后连续', () {
      const first = ArtworkReview(
        teacherId: 't-1',
        teacherName: '李静',
        marks: [
          ArtworkMark(id: 'a', x: 0, y: 0, imageIndex: 1, text: '第二张'),
          ArtworkMark(id: 'b', x: 0, y: 0, text: '第一张'),
        ],
      );
      const second = ArtworkReview(
        teacherId: 't-4',
        teacherName: '赵雪',
        marks: [ArtworkMark(id: 'a', x: 0, y: 0, text: '另一位老师')],
      );
      final numbered = numberArtworkMarks([first, second]);
      expect(numbered.map((m) => '${m.number}:${m.key}'), [
        '1:t-1/b',
        '2:t-1/a',
        '3:t-4/a',
      ]);
    });
  });

  group('演示接口', () {
    test('只写定点点评也能保存，学生端读得到', () async {
      const id = DemoArtworkSeed.storyPendingId;
      await _saveReview(
        DemoAccounts.teacher,
        id,
        marks: [
          _mark('三大面区分不够，亮面和灰面要拉开', x: 1.3, y: 0.4),
          _mark('', voice: _voice),
        ],
      );
      final review = (await _reviewsAs(DemoAccounts.student, id)).single;
      expect(review.marks, hasLength(2));
      expect(review.marks.first.text, '三大面区分不够，亮面和灰面要拉开');
      expect(review.marks.first.x, 1.0);
      expect(review.marks.last.voiceUrl, _voice);
      expect(review.marks.last.voiceSeconds, 12);
    });

    test('校验：每张最多 20 处、每处最多 200 字、文字和语音至少一样、图片序号', () async {
      const id = DemoArtworkSeed.storyPendingId;
      final teacher = DemoAccounts.teacher;
      await expectLater(
        _saveReview(
          teacher,
          id,
          marks: [for (var i = 0; i < 21; i++) _mark('第 $i 处')],
        ),
        _demoError(400),
      );
      await expectLater(
        _saveReview(teacher, id, marks: [_mark('长' * 201)]),
        _demoError(400),
      );
      await expectLater(
        _saveReview(teacher, id, marks: [_mark('')]),
        _demoError(400),
      );
      await expectLater(
        _saveReview(teacher, id, marks: [_mark('序号', imageIndex: 9)]),
        _demoError(400),
      );
      await expectLater(_saveReview(teacher, id), _demoError(400));
    });

    test('不传 marks 沿用上次，传空列表清除', () async {
      const id = DemoArtworkSeed.storyInReviewId;
      final teacher = DemoAccounts.teacher;
      final before = (await _reviewsAs(teacher, id)).single.marks;
      expect(before, hasLength(3));
      await _saveReview(teacher, id, score: 88, content: '结构交代清楚，暗部再整体一些。');
      expect((await _reviewsAs(teacher, id)).single.marks, before);
      await _saveReview(teacher, id, score: 88, marks: <Object>[]);
      expect((await _reviewsAs(teacher, id)).single.marks, isEmpty);
    });

    test('几位任课老师的定点点评各自独立', () async {
      const id = DemoArtworkSeed.storyChainId;
      await _saveReview(
        DemoAccounts.headTeacher,
        id,
        score: 89,
        marks: [_mark('边线用长线概括', x: 0.4, y: 0.4)],
      );
      final reviews = await _reviewsAs(DemoAccounts.student, id);
      final byTeacher = {for (final r in reviews) r.teacherId: r.marks};
      expect(byTeacher['t-4']!.map((m) => m.text), ['边线用长线概括']);
      expect(byTeacher['t-1'], hasLength(2));
      expect(byTeacher['t-5'], isEmpty);
    });
  });

  group('界面', () {
    testWidgets('学生点图上的编号看到这一处的点评，列表行和编号互相选中', (tester) async {
      await _pump(
        tester,
        StudentArtworkDetailView(
          artworkId: DemoArtworkSeed.storyInReviewId,
          onBack: () {},
        ),
        account: DemoAccounts.student,
      );
      expect(find.text('定点点评'), findsOneWidget);
      expect(find.byType(ArtworkMarkLayer), findsOneWidget);
      expect(_dot(1, selected: false), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('mark-pin-t-1/mk-1')));
      await _settle(tester);
      expect(find.text('第 1 处'), findsOneWidget);
      expect(find.textContaining('两眼的位置偏高'), findsNWidgets(2));
      expect(_dot(1, selected: true), findsNWidgets(2));

      await tester.tap(find.textContaining('耳朵偏低').first);
      await _settle(tester);
      expect(find.text('第 2 处'), findsOneWidget);
      expect(find.text('第 1 处'), findsNothing);
      expect(_dot(2, selected: true), findsNWidgets(2));

      await tester.tap(find.byTooltip('关闭这一处点评'));
      await _settle(tester);
      expect(find.text('第 2 处'), findsNothing);
      await _unmount(tester);
    });

    testWidgets('有语音的一处：点编号就播放，换一处时停掉上一段', (tester) async {
      const id = DemoArtworkSeed.storyPendingId2;
      await _saveReview(
        DemoAccounts.teacher,
        id,
        score: 85,
        marks: [
          _mark('三大面区分不够', x: 0.3, y: 0.3, voice: _voice),
          _mark('投影再虚一些', x: 0.7, y: 0.7),
        ],
      );
      final saved = (await _reviewsAs(DemoAccounts.student, id)).single;
      await _pump(
        tester,
        StudentArtworkDetailView(artworkId: id, onBack: () {}),
        account: DemoAccounts.student,
      );
      final first = saved.marks.first.id;
      await tester.tap(find.byKey(ValueKey('mark-pin-t-1/$first')));
      await _settle(tester);
      expect(find.text('第 1 处'), findsOneWidget);
      expect(find.text('三大面区分不够'), findsNWidgets(2));
      expect(_FakePlayback.created, hasLength(1));
      expect(_FakePlayback.created.single.source, _voice);
      expect(_FakePlayback.created.single.playing, true);
      expect(find.bySemanticsLabel('暂停语音'), findsWidgets);

      await tester.tap(find.text('投影再虚一些'));
      await _settle(tester);
      expect(find.text('第 2 处'), findsOneWidget);
      expect(_FakePlayback.created.single.disposed, true);
      await _unmount(tester);
    });

    testWidgets('老师在画上加一处定点点评，写一句话后随点评保存', (tester) async {
      const id = DemoArtworkSeed.storyPendingId2;
      await _pump(
        tester,
        ArtworkReviewWorkspace(
          artworkId: id,
          onBack: () {},
          onOpenArtwork: (_) {},
        ),
        account: DemoAccounts.teacher,
      );
      await tester.tap(find.widgetWithText(AppButton, '定点点评'));
      await _settle(tester);
      expect(find.byType(ArtworkMarkEditorPanel), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.byType(ArtworkMarkLayer)));
      await _settle(tester);
      expect(find.text('第 1 处'), findsOneWidget);
      expect(_dot(1, selected: true), findsWidgets);
      await tester.enterText(
        find.descendant(
          of: find.byType(ArtworkMarkEditorPanel),
          matching: find.byType(EditableText),
        ),
        '投影的边缘太硬，近实远虚',
      );
      await _settle(tester);

      final layerWidth = tester.getSize(find.byType(ArtworkMarkLayer)).width;
      final pin = find.byWidgetPredicate(
        (w) =>
            w is Positioned &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('mark-pin-'),
      );
      expect(pin, findsOneWidget);
      await tester.drag(pin, const Offset(40, 0));
      await _settle(tester);

      await tester.tap(find.widgetWithText(AppButton, '完成'));
      await _settle(tester);
      expect(find.byType(ArtworkMarkEditorPanel), findsNothing);
      expect(find.text('投影的边缘太硬，近实远虚'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, '保存'));
      await _settle(tester);
      final mark = (await _reviewsAs(
        DemoAccounts.student,
        id,
      )).single.marks.single;
      expect(mark.text, '投影的边缘太硬，近实远虚');
      expect(mark.x, closeTo(0.5 + 40 / layerWidth, 0.02));
      expect(mark.y, closeTo(0.5, 0.02));
      await _unmount(tester);
    });
  });
}
