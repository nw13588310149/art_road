// 月考原卷讲评：演示接口（权限、上限、发布前后谁看得到、已读）、今日学习的「听讲评」，
// 以及老师录讲评、学生听讲评两条界面流程。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/audio/recording/recording_playback.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_exam_critique_store.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/today/today_fixtures.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/today/today_support.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/features/artworks/state/artwork_voice_player.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/widgets/artwork_annotation.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/widgets/artwork_mark_layer.dart';
import 'package:the_road_of_art_flutter/features/study_center/data/exam_critique_models.dart';
import 'package:the_road_of_art_flutter/features/study_center/data/study_models.dart';
import 'package:the_road_of_art_flutter/features/study_center/state/exam_critique_controller.dart';
import 'package:the_road_of_art_flutter/features/study_center/state/study_center_args.dart';
import 'package:the_road_of_art_flutter/features/study_center/ui/paper/study_paper_viewer_page.dart';
import 'package:the_road_of_art_flutter/features/study_center/ui/staff/exam_critique_workspace.dart';
import 'package:the_road_of_art_flutter/features/study_center/ui/student/student_report_view.dart';
import 'package:the_road_of_art_flutter/features/today/data/today_models.dart';

const _voice = 'http://127.0.0.1/f/critique_voice.m4a';
const _staffBase = '/school/teacher/exams/26/subjects';
const _studentBase = '/app/study/exams/26/subjects';

Future<dynamic> _call(
  String method,
  String path,
  DemoAccount account, {
  Map<String, dynamic> body = const {},
  DemoRouter? router,
}) async {
  final target = router ?? DemoBackend.marking;
  final endpoint = target.match(method, path)!;
  return await endpoint.handler(
    DemoRequest(
      method: method,
      path: path,
      query: const <String, dynamic>{},
      body: body,
      headers: {'token': account.token},
      pathParams: endpoint.params,
    ),
  );
}

Future<ExamCritiqueBoard> _staff(DemoAccount account, String subjectId) async =>
    ExamCritiqueBoard.fromJson(
      await _call('GET', '$_staffBase/$subjectId/critique', account),
    );

Future<StudentExamCritique> _student(String subjectId) async =>
    StudentExamCritique.fromJson(
      await _call(
        'GET',
        '$_studentBase/$subjectId/critique',
        DemoAccounts.student,
      ),
    );

Future<Map<String, dynamic>> _savePaper(
  DemoAccount account,
  String subjectId,
  Map<String, dynamic> body,
) async =>
    await _call(
          'POST',
          '$_staffBase/$subjectId/critique/papers',
          account,
          body: body,
        )
        as Map<String, dynamic>;

Future<dynamic> _publish(
  DemoAccount account,
  String subjectId, {
  bool published = true,
  bool showNames = false,
}) => _call(
  'POST',
  '$_staffBase/$subjectId/critique/publish',
  account,
  body: {'published': published, 'showNames': showNames},
);

Map<String, dynamic> _mark(String text, {double x = 0.5, double y = 0.5}) => {
  'id': 'mk-${text.hashCode}',
  'imageIndex': 0,
  'x': x,
  'y': y,
  'text': text,
};

Matcher _demoError(int code) =>
    throwsA(isA<DemoApiException>().having((e) => e.code, 'code', code));

Future<StudySubjectRecord> _reportSubject(String subjectId) async {
  final report = StudyExamReport.fromJson(
    await _call('GET', '/app/study/exams/26', DemoAccounts.student),
  );
  return report.subjects.firstWhere((s) => s.subjectId == subjectId);
}

Future<List<Map>> _notices() async =>
    (await _call(
              'POST',
              '/app/msg/list',
              DemoAccounts.student,
              router: DemoBackend.platform,
            )
            as List)
        .cast<Map>();

Future<TodayBoard> _todayBoard() async => TodayBoard.fromJson(
  await buildTodayBoard(
    TodayContext(
      DemoRequest(
        method: 'POST',
        path: '/app/today/board',
        query: const <String, dynamic>{},
        body: const <String, dynamic>{},
        headers: <String, dynamic>{'app-token': DemoAccounts.student.token},
      ),
    ),
  ),
);

/// 不出声的播放器：记下播了什么。
class _FakePlayback implements RecordingPlayback {
  _FakePlayback() {
    created.add(this);
  }

  static final created = <_FakePlayback>[];

  final _status = StreamController<RecordingPlaybackStatus>.broadcast();
  String? source;
  bool playing = false;

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
    playing = false;
    await _status.close();
  }
}

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
  tester.view.physicalSize = const Size(1180, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(prefs)),
        artworkPlaybackFactoryProvider.overrideWithValue(_FakePlayback.new),
      ],
      child: MaterialApp(theme: AppTheme.light, home: page),
    ),
  );
  await _settle(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

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

  group('演示数据', () {
    test('色彩已发布三张代表卷和林小雨的个人讲评，素描是李静的草稿', () async {
      final color = await _staff(DemoAccounts.teacher, '39');
      expect(color.critique.published, isTrue);
      expect(color.critique.teacherName, '王海波');
      expect(color.critique.showNames, isFalse);
      expect(
        color.critique.papers.where((p) => p.shared).map((p) => p.grade),
        ['A', 'B', 'C'],
      );
      final personal = color.critique.papers.singleWhere((p) => !p.shared);
      expect(personal.archiveId, '900001');
      expect((personal.grade, personal.score), ('B', 85.0));
      final images = color.critique.papers.map((p) => p.imageUrl).toSet();
      expect(images, hasLength(4), reason: '四张讲评卷各是一张不同的画');
      expect(
        color.critique.papers.where((p) => p.shared && p.archiveId == '900001'),
        isEmpty,
      );
      for (final paper in color.critique.papers) {
        expect(paper.marks.length, inInclusiveRange(2, 4));
        expect(paper.summary, isNotEmpty);
      }

      final sketch = await _staff(DemoAccounts.teacher, '38');
      expect(sketch.critique.published, isFalse);
      expect(sketch.critique.teacherName, '李静');
      expect(sketch.critique.papers, hasLength(2));
      expect(sketch.critique.papers.every((p) => p.shared), isTrue);
    });

    test('档位：九月月考没有 E 档，速写没有 D 档；每个有卷子的档位建议一张', () async {
      for (final subjectId in ['38', '39', '40']) {
        final board = await _staff(DemoAccounts.teacher, subjectId);
        expect(board.bands.map((b) => b.grade), ['A', 'B', 'C', 'D', 'E']);
        expect(board.bands.last.count, 0, reason: subjectId);
        for (final band in board.bands) {
          final suggested = board
              .candidatesIn(band.grade)
              .where((c) => c.suggested);
          expect(suggested.length, band.count == 0 ? 0 : 1);
        }
      }
      final speed = await _staff(DemoAccounts.teacher, '40');
      expect(speed.bands.firstWhere((b) => b.grade == 'D').count, 0);
    });
  });

  group('权限', () {
    test('任教这一科的老师和这一科的组长能改，其他教职只读', () async {
      Future<bool> canEdit(DemoAccount account, String subjectId) async =>
          (await _staff(account, subjectId)).canEdit;
      expect(await canEdit(DemoAccounts.teacher, '38'), isTrue);
      expect(await canEdit(DemoAccounts.teacher, '39'), isFalse);
      expect(await canEdit(DemoAccounts.groupLeader, '38'), isTrue);
      expect(await canEdit(DemoAccounts.groupLeader, '40'), isFalse);
      expect(await canEdit(DemoAccounts.headTeacher, '40'), isTrue);
      expect(await canEdit(DemoAccounts.headTeacher, '38'), isFalse);
      expect(await canEdit(DemoAccounts.admin, '38'), isFalse);
      expect(await canEdit(DemoAccounts.principal, '39'), isFalse);
    });

    test('学生调教职接口 403，教职调学生接口 403，只读的老师写入 403', () async {
      await expectLater(
        _call('GET', '$_staffBase/38/critique', DemoAccounts.student),
        _demoError(403),
      );
      await expectLater(
        _call('GET', '$_studentBase/39/critique', DemoAccounts.teacher),
        _demoError(403),
      );
      await expectLater(
        _call('POST', '$_studentBase/39/critique/read', DemoAccounts.principal),
        _demoError(403),
      );
      await expectLater(
        _savePaper(DemoAccounts.teacher, '39', {
          'archiveId': '900003',
          'shared': true,
        }),
        _demoError(403),
      );
      await expectLater(
        _publish(DemoAccounts.headTeacher, '38'),
        _demoError(403),
      );
    });

    test('阅卷中的考试不能讲评', () async {
      await expectLater(
        _call(
          'GET',
          '/school/teacher/exams/27/subjects/38/critique',
          DemoAccounts.teacher,
        ),
        _demoError(409),
      );
    });
  });

  group('校验', () {
    test('每张最多 20 处、每处 200 字、文字或语音至少一样、只有一张图、总结 500 字', () async {
      final teacher = DemoAccounts.teacher;
      Map<String, dynamic> body(List<Map<String, dynamic>> marks) => {
        'archiveId': '900005',
        'shared': true,
        'marks': marks,
      };
      await expectLater(
        _savePaper(teacher, '38', body([for (var i = 0; i < 21; i++) _mark('第 $i 处')])),
        _demoError(400),
      );
      await expectLater(
        _savePaper(teacher, '38', body([_mark('长' * 201)])),
        _demoError(400),
      );
      await expectLater(
        _savePaper(teacher, '38', body([_mark('')])),
        _demoError(400),
      );
      await expectLater(
        _savePaper(teacher, '38', body([
          {..._mark('第二张图'), 'imageIndex': 1},
        ])),
        _demoError(400),
      );
      await expectLater(
        _savePaper(teacher, '38', {
          'archiveId': '900005',
          'shared': true,
          'summary': '字' * 501,
        }),
        _demoError(400),
      );
      await expectLater(
        _savePaper(teacher, '38', {'archiveId': '999999', 'shared': true}),
        _demoError(400),
      );
      final ok = await _savePaper(teacher, '38', body([
        for (var i = 0; i < 20; i++) _mark('第 $i 处', x: 1.4, y: -0.2),
      ]));
      final saved = ExamCritiqueBoard.fromJson(ok).paper('shared:900005')!;
      expect(saved.marks, hasLength(20));
      expect(saved.marks.first.position, const Offset(1, 0));
    });

    test('每科最多 10 张代表卷，个人讲评不占名额', () async {
      final teacher = DemoAccounts.teacher;
      final board = await _staff(teacher, '38');
      final free = board.candidates
          .where((c) => board.paper('shared:${c.archiveId}') == null)
          .toList();
      for (final candidate in free.take(8)) {
        await _savePaper(teacher, '38', {
          'archiveId': candidate.archiveId,
          'shared': true,
        });
      }
      await expectLater(
        _savePaper(teacher, '38', {
          'archiveId': free[8].archiveId,
          'shared': true,
        }),
        _demoError(400),
      );
      final personal = ExamCritiqueBoard.fromJson(
        await _savePaper(teacher, '38', {
          'archiveId': free[8].archiveId,
          'shared': false,
          'marks': [_mark('个人讲评')],
        }),
      );
      expect(personal.critique.sharedCount, 10);
      expect(personal.critique.personalCount, 1);
    });

    test('没有讲评内容时不能发布', () async {
      final teacher = DemoAccounts.teacher;
      for (final paper in (await _staff(teacher, '38')).critique.papers) {
        await _call(
          'POST',
          '$_staffBase/38/critique/papers/delete',
          teacher,
          body: {'archiveId': paper.archiveId, 'shared': true},
        );
      }
      await _savePaper(teacher, '38', {'archiveId': '900005', 'shared': true});
      await expectLater(_publish(teacher, '38'), _demoError(400));
    });
  });

  group('发布与可见', () {
    test('草稿学生看不到；发布后看到代表卷，默认不显示姓名，并收到一条学情消息', () async {
      expect((await _student('38')).published, isFalse);
      expect((await _student('38')).papers, isEmpty);
      expect((await _reportSubject('38')).critiqueAvailable, isFalse);
      final before = (await _notices()).length;

      await _publish(DemoAccounts.teacher, '38');
      final critique = await _student('38');
      expect(critique.published, isTrue);
      expect(critique.papers, hasLength(2));
      expect(critique.papers.every((p) => p.studentName.isEmpty), isTrue);
      expect(critique.watermarkText, contains('林小雨'));
      expect(critique.myGrade, 'A');
      final subject = await _reportSubject('38');
      expect(subject.critiqueAvailable, isTrue);
      expect(subject.critiqueUnread, isTrue);

      final notices = await _notices();
      expect(notices.length, before + 1);
      expect(notices.first['content'], startsWith('【学情】9 月月考素描讲评已发布'));
      expect(notices.first['targetType'], 1);
      expect(notices.first['targetId'], '26');

      await _publish(DemoAccounts.teacher, '38', showNames: true);
      expect(
        (await _student('38')).papers.every((p) => p.studentName.isNotEmpty),
        isTrue,
      );
      expect((await _notices()).length, before + 1, reason: '已发布时改设置不再通知');

      await _publish(DemoAccounts.teacher, '38', published: false);
      expect((await _student('38')).papers, isEmpty);
      expect((await _reportSubject('38')).critiqueAvailable, isFalse);
    });

    test('个人讲评只给本人；已发布时新录的个人讲评只通知那一位', () async {
      final teacher = DemoAccounts.teacher;
      await _publish(teacher, '38');
      final before = (await _notices()).length;
      await _savePaper(teacher, '38', {
        'archiveId': '900002',
        'shared': false,
        'marks': [_mark('林小舟的个人讲评')],
      });
      expect(
        (await _student('38')).papers.any((p) => p.marks.any((m) => m.text == '林小舟的个人讲评')),
        isFalse,
      );
      expect((await _notices()).length, before);

      await _savePaper(teacher, '38', {
        'archiveId': '900001',
        'shared': false,
        'summary': '构图很完整，暗部再透气一些',
      });
      final critique = await _student('38');
      final mine = critique.papers.singleWhere((p) => p.mine);
      expect(mine.studentName, '林小雨');
      expect(critique.sections.first.label, '我的原卷');
      final notices = await _notices();
      expect(notices.length, before + 1);
      expect(notices.first['content'], contains('李静老师给你的9 月月考素描原卷录了讲评'));

      await _savePaper(teacher, '38', {
        'archiveId': '900001',
        'shared': false,
        'summary': '改一句',
      });
      expect((await _notices()).length, before + 1, reason: '同一张只通知一次');
    });

    test('已读：打开前是新的，读过后报告和总览里都不再是新的', () async {
      final critique = await _student('39');
      expect(critique.read, isFalse);
      expect((await _reportSubject('39')).critiqueUnread, isTrue);
      await _call('POST', '$_studentBase/39/critique/read', DemoAccounts.student);
      expect((await _student('39')).read, isTrue);
      expect((await _reportSubject('39')).critiqueUnread, isFalse);
      final overview = StudyOverview.fromJson(
        await _call('GET', '/app/study/overview', DemoAccounts.student),
      );
      final recent = overview.recentStage!.exam.subjectById('39')!;
      expect((recent.critiqueAvailable, recent.critiqueUnread), (true, false));
      await expectLater(
        _call('POST', '$_studentBase/38/critique/read', DemoAccounts.student),
        _demoError(404),
      );
    });

    test('重置演示数据后讲评回到初始状态', () async {
      await _publish(DemoAccounts.teacher, '38');
      await DemoStore.reset();
      expect((await _staff(DemoAccounts.teacher, '38')).critique.published, isFalse);
      expect(DemoExamCritiqueStore.critique('26', '39')?['readBy'], isEmpty);
    });
  });

  group('学生看讲评的先后', () {
    CritiquePaper paper(String id, String grade, {bool mine = false}) =>
        CritiquePaper(id: id, grade: grade, mine: mine, shared: !mine);
    const bands = [
      CritiqueBand(grade: 'A', min: 90),
      CritiqueBand(grade: 'B', min: 80),
      CritiqueBand(grade: 'C', min: 70),
      CritiqueBand(grade: 'D', min: 60),
    ];

    test('我的原卷、我这一档、上一档、其他档', () {
      final sections = orderCritiqueSections([
        paper('a', 'A'),
        paper('c', 'C'),
        paper('b', 'B'),
        paper('d', 'D'),
        paper('me', 'B', mine: true),
      ], myGrade: 'B', bands: bands);
      expect(sections.map((s) => '${s.label}:${s.paper.id}'), [
        '我的原卷:me',
        '我这一档:b',
        '上一档:a',
        '其他档:c',
        '其他档:d',
      ]);
    });

    test('最高一档没有上一档', () {
      final sections = orderCritiqueSections([
        paper('c', 'C'),
        paper('b', 'B'),
        paper('a', 'A'),
      ], myGrade: 'A', bands: bands);
      expect(sections.map((s) => s.label), ['我这一档', '其他档', '其他档']);
      expect(sections.map((s) => s.paper.id), ['a', 'b', 'c']);
    });

    test('路由 view=critique', () {
      final args = StudyCenterArgs.parse({
        'examId': '26',
        'view': 'critique',
        'subjectId': '39',
      });
      expect(args.view, StudyCenterInitialView.critique);
      expect(args.subjectId, '39');
    });
  });

  group('今日学习', () {
    test('发布了讲评、还没听：有一件「听讲评」，听过后显示已完成', () async {
      final board = await _todayBoard();
      final step = board.steps.singleWhere((s) => s.kind == 'critique');
      expect(step.title, '听讲评：9 月月考 色彩');
      expect(step.done, isFalse);
      expect(step.detail, contains('王海波老师'));
      expect(step.detail, contains('还看了你的原卷'));
      expect(step.action!.route, '/study');
      expect(step.action!.arguments, {
        'examId': '26',
        'view': 'critique',
        'subjectId': '39',
      });

      await _call('POST', '$_studentBase/39/critique/read', DemoAccounts.student);
      final after = await _todayBoard();
      final done = after.steps.singleWhere((s) => s.kind == 'critique');
      expect(done.done, isTrue);
    });

    test('今天第一次打开看板前就听过的不再出现', () async {
      await _call('POST', '$_studentBase/39/critique/read', DemoAccounts.student);
      final board = await _todayBoard();
      expect(board.steps.where((s) => s.kind == 'critique'), isEmpty);
    });
  });

  group('界面', () {
    testWidgets('老师：加一张代表卷，点卷面加一处，写一句话，保存，确认后发布', (tester) async {
      await _pump(
        tester,
        const ExamCritiqueWorkspace(
          args: CritiqueWorkspaceArgs(examId: '26', subjectId: '38'),
        ),
        account: DemoAccounts.teacher,
      );
      expect(find.text('9 月月考 · 素描 · 讲评'), findsOneWidget);
      expect(find.textContaining('草稿 · 代表卷 2 张'), findsOneWidget);

      final board = await _staff(DemoAccounts.teacher, '38');
      final candidate = board
          .candidatesIn('C')
          .firstWhere((c) => c.suggested);
      final row = find.text(
        '${candidate.studentName} · ${candidate.score!.toStringAsFixed(candidate.score! % 1 == 0 ? 0 : 1)} 分',
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await _settle(tester);
      expect(find.text('还没加进讲评'), findsOneWidget);
      await tester.tap(find.text('加为代表卷'));
      await _settle(tester);
      expect(find.text('代表卷'), findsWidgets);

      await tester.tap(find.byType(ArtworkMarkLayer));
      await _settle(tester);
      expect(find.text('第 1 处'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, '背景和桌面拉开冷暖');
      await _settle(tester);
      await tester.tap(find.text('保存草稿'));
      await _settle(tester);

      final saved = (await _staff(DemoAccounts.teacher, '38'))
          .paper('shared:${candidate.archiveId}')!;
      expect(saved.marks.single.text, '背景和桌面拉开冷暖');

      await tester.tap(find.text('发布讲评'));
      await _settle(tester);
      expect(find.text('代表卷显示学生姓名'), findsOneWidget);
      await tester.tap(find.text('发布'));
      await _settle(tester);
      expect(
        (await _staff(DemoAccounts.teacher, '38')).critique.published,
        isTrue,
      );
      expect(find.text('撤回发布'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('老师：有没保存的改动时离开要确认', (tester) async {
      await _pump(
        tester,
        const ExamCritiqueWorkspace(
          args: CritiqueWorkspaceArgs(examId: '26', subjectId: '38'),
        ),
        account: DemoAccounts.teacher,
      );
      await tester.tap(find.byType(ArtworkMarkLayer));
      await _settle(tester);
      await tester.enterText(find.byType(EditableText).first, '没保存的一处');
      await _settle(tester);
      await tester.tap(find.byTooltip('关闭讲评'));
      await _settle(tester);
      expect(find.text('有没保存的讲评'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await _settle(tester);
      expect(find.text('第 3 处'), findsNothing);
      expect(find.text('9 月月考 · 素描 · 讲评'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('学生：成绩表上标着「讲评 · 新」，从「听讲评」直接进讲评', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: StudentReportView(examId: '26', onBack: () {}, onOpenTrend: () {}),
        ),
        account: DemoAccounts.student,
      );
      expect(find.text('讲评 · 新'), findsOneWidget);
      await tester.tap(find.text('听讲评'));
      await _settle(tester);
      expect(find.text('我的原卷'), findsOneWidget);
      expect(find.text('上一档'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('学生：讲评按先后排开，点编号弹出这一处并播放语音，打开即已读', (tester) async {
      final personal = DemoExamCritiqueStore.papersOf(
        DemoExamCritiqueStore.critique('26', '39')!,
      ).singleWhere((p) => p['shared'] != true);
      final first = (personal['marks'] as List).first as Map<String, dynamic>;
      first
        ..['voiceRef'] = _voice
        ..['voiceSeconds'] = 12;
      final report = StudyExamReport.fromJson(
        await _call('GET', '/app/study/exams/26', DemoAccounts.student),
      );
      await _pump(
        tester,
        StudyPaperViewerPage(
          exam: report.exam.withSubjects(report.subjects),
          initialSubjectId: '39',
          initialMode: StudyPaperMode.critique,
        ),
        account: DemoAccounts.student,
      );
      expect(find.text('讲评'), findsOneWidget);
      final labels = ['我的原卷', '我这一档', '上一档', '其他档'];
      final tops = [
        for (final label in labels) tester.getTopLeft(find.text(label)).dy,
      ];
      expect(tops, [...tops]..sort());

      await tester.tap(find.byKey(const ValueKey('mark-pin-cp-26-39-p1/mk-1')));
      await _settle(tester);
      expect(find.text('第 1 处'), findsOneWidget);
      expect(_FakePlayback.created, hasLength(1));
      expect(_FakePlayback.created.single.source, _voice);
      expect(_FakePlayback.created.single.playing, isTrue);
      expect((await _student('39')).read, isTrue);

      await tester.tap(find.text('上一档'));
      await _settle(tester);
      expect(find.text('第 1 处'), findsNothing);
      expect(find.textContaining('冷暖对比清楚'), findsOneWidget);
      await _unmount(tester);
    });
  });
}
