import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_data.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/marking_artwork_fixtures.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/platform_core_fixtures.dart';

/// 作品库的读写入口：读缓存、只读快照、到点的代点评与代复核、消息追加。
void main() {
  // 周五晚上，当天的作品已经交完。
  final now = DateTime(2026, 11, 13, 21, 30);
  late DemoRouter platform;
  late DemoRouter marking;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DemoStore.init();
    await DemoStore.reset();
    DemoArtworkStore.setNow(now);
    platform = DemoRouter('artwork-store-test-platform');
    marking = DemoRouter('artwork-store-test-marking');
    registerPlatformCoreFixtures(platform);
    registerMarkingArtworkFixtures(marking);
  });

  tearDown(() => DemoArtworkStore.setNow(null));

  Future<Object?> call(
    DemoRouter router,
    String method,
    String path,
    DemoAccount account, {
    Object? body,
    Map<String, dynamic> query = const <String, dynamic>{},
  }) async {
    final match = router.match(method, path);
    expect(match, isNotNull, reason: path);
    return match!.handler(
      DemoRequest(
        method: method,
        path: path,
        query: query,
        body: body,
        headers: <String, dynamic>{'app-token': account.token},
        pathParams: match.params,
      ),
    );
  }

  Future<List<Map>> notices(DemoAccount account) async =>
      (await call(platform, 'POST', '/app/msg/list', account) as List)
          .cast<Map>();

  /// 一份刚交、还没点评的作品（不在种子里）。
  Map<String, dynamic> submitted(
    String id, {
    required String subject,
    required String teacherId,
    int person = 1,
    DateTime? autoReviewAt,
  }) {
    final sample = DemoArtworkStore.works().firstWhere(
      (w) => w['subject'] == subject,
    );
    return <String, dynamic>{
      'id': id,
      'rootId': id,
      'version': 1,
      'parentId': '',
      'personIndex': person,
      'title': '课后练习',
      'subject': subject,
      'drawingDate': DemoArtworkData.ymd(now),
      'createTime': DemoArtworkData.fmt(now),
      'description': '',
      'images': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '$id-1',
          'ref': ((sample['images'] as List).first as Map)['ref'],
        },
      ],
      'taskId': '',
      'teacherId': teacherId,
      'review': null,
      'supplements': <Map<String, dynamic>>[],
      'leadReview': null,
      'principalComments': <Map<String, dynamic>>[],
      'featured': false,
      'featuredTime': '',
      'featuredBy': '',
      'seedReviewAt': ?(autoReviewAt == null
          ? null
          : DemoArtworkData.fmt(autoReviewAt)),
    };
  }

  group('reads', () {
    test('a list request merges the store once and returns only its page', () async {
      DemoArtworkStore.works();
      final merges = DemoArtworkStore.debugMergeCount;
      final watch = Stopwatch()..start();

      final page =
          await call(
                marking,
                'GET',
                '/school/teacher/artworks',
                DemoAccounts.principal,
                query: <String, dynamic>{'status': 'ALL', 'size': 20},
              )
              as Map;
      expect(page['total'], greaterThan(900));
      expect(page['records'], hasLength(20));
      final first = (page['records'] as List).first as Map;
      expect(first['studentName'], isNotEmpty);
      expect(first['versionCount'], greaterThanOrEqualTo(1));

      final tasks =
          await call(marking, 'GET', '/app/tasks', DemoAccounts.student) as List;
      expect(tasks, isNotEmpty);
      expect(tasks.cast<Map>().every((t) => '${t['status']}'.isNotEmpty), isTrue);

      // 没有写入就不重新合并；逐条重新合并时，这两个请求要十几秒。
      expect(DemoArtworkStore.debugMergeCount, merges);
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('works() hands out read-only works; workById gives a writable copy', () {
      final first = DemoArtworkStore.works().first;
      final id = DemoArtworkData.text(first['id']);
      final title = first['title'];
      expect(() => first['title'] = '改名', throwsUnsupportedError);
      expect(() => (first['images'] as List).clear(), throwsUnsupportedError);

      final copy = DemoArtworkStore.workById(id)!;
      copy['title'] = '改名';
      expect(DemoArtworkStore.workById(id)!['title'], title);

      DemoArtworkStore.saveWork(copy);
      expect(DemoArtworkStore.workById(id)!['title'], '改名');
      expect(
        DemoArtworkStore.works().firstWhere((w) => w['id'] == id)['title'],
        '改名',
      );
      expect(
        DemoArtworkStore.versionsOf(copy).map((w) => w['title']),
        contains('改名'),
      );
    });

    test('「重置演示数据」 drops saved changes even without clearing the cache', () async {
      final id = DemoArtworkData.text(DemoArtworkStore.works().first['id']);
      final copy = DemoArtworkStore.workById(id)!;
      final title = copy['title'];
      copy['title'] = '改名';
      DemoArtworkStore.saveWork(copy);
      expect(DemoArtworkStore.workById(id)!['title'], '改名');

      await DemoStore.reset();
      expect(DemoArtworkStore.workById(id)!['title'], title);
    });
  });

  group('teachers and leaders without a demo account', () {
    bool waitingReview(Map<String, dynamic> w) =>
        !DemoArtworkData.isReviewed(w) && w['seedReviewAt'] != null;
    bool waitingLead(Map<String, dynamic> w) =>
        DemoArtworkData.leadStatusOf(w) == DemoArtworkData.leadInReview &&
        (w['leadReview'] as Map)['seedLeadAt'] != null;

    test('seed works are reviewed and lead-reviewed as time passes', () {
      final before = DemoArtworkStore.works();
      final reviewIds = <String>[
        for (final w in before)
          if (waitingReview(w)) DemoArtworkData.text(w['id']),
      ];
      final leadIds = <String>[
        for (final w in before)
          if (waitingLead(w)) DemoArtworkData.text(w['id']),
      ];
      expect(reviewIds, isNotEmpty);
      expect(leadIds, isNotEmpty);
      final pendingByDemoTeachers = before
          .where(
            (w) =>
                !DemoArtworkData.isReviewed(w) &&
                DemoArtworkData.hasDemoAccount(
                  DemoArtworkData.text(w['teacherId']),
                ),
          )
          .length;
      final scriptedOverdue = before
          .where(
            (w) =>
                !DemoArtworkData.isReviewed(w) &&
                w['teacherId'] == 't-5' &&
                w['seedReviewAt'] == null,
          )
          .length;
      expect(scriptedOverdue, inInclusiveRange(5, 8));

      // 演示开着没关，过了很久再看。
      DemoArtworkStore.advanceNow(now.add(const Duration(days: 30)));
      final after = DemoArtworkStore.works();
      expect(after.where(waitingReview), isEmpty);
      expect(after.where(waitingLead), isEmpty);
      for (final id in reviewIds) {
        final work = DemoArtworkStore.workById(id)!;
        expect(DemoArtworkData.isReviewed(work), isTrue, reason: id);
        expect(
          DemoArtworkData.leadStatusOf(work),
          isNot(DemoArtworkData.leadInReview),
          reason: id,
        );
      }
      for (final id in leadIds) {
        final lead = DemoArtworkStore.workById(id)!['leadReview'] as Map;
        expect(DemoArtworkData.actions, contains(lead['action']), reason: id);
        expect(lead['qualityStars'], inInclusiveRange(1, 5), reason: id);
        expect('${lead['time']}', isNotEmpty, reason: id);
      }

      // 有演示账号的老师名下的待办、王海波编排好的超时作品都原样留着。
      expect(
        after
            .where(
              (w) =>
                  !DemoArtworkData.isReviewed(w) &&
                  DemoArtworkData.hasDemoAccount(
                    DemoArtworkData.text(w['teacherId']),
                  ),
            )
            .length,
        pendingByDemoTeachers,
      );
      expect(
        after
            .where(
              (w) => !DemoArtworkData.isReviewed(w) && w['teacherId'] == 't-5',
            )
            .length,
        scriptedOverdue,
      );

      // 处理过一次就不再重复处理。
      final applied = DemoArtworkStore.debugAutoApplied;
      final merges = DemoArtworkStore.debugMergeCount;
      DemoArtworkStore.works();
      DemoArtworkStore.workById(leadIds.first);
      expect(DemoArtworkStore.debugAutoApplied, applied);
      expect(DemoArtworkStore.debugMergeCount, merges);
    });

    test(
      'a new 色彩 work is reviewed after the delay and the student is told once',
      () async {
        // 林小雨的色彩由刘芳负责，刘芳没有演示账号；她本人是组长，不进复核池。
        final due = now.add(DemoArtworkData.autoDelay);
        DemoArtworkStore.saveWork(
          submitted(
            'aw-new-color',
            subject: '色彩',
            teacherId: 't-3',
            autoReviewAt: due,
          ),
        );
        expect(
          DemoArtworkData.isReviewed(DemoArtworkStore.workById('aw-new-color')!),
          isFalse,
        );

        DemoArtworkStore.advanceNow(due);
        final work = DemoArtworkStore.workById('aw-new-color')!;
        expect(DemoArtworkData.isReviewed(work), isTrue);
        expect((work['review'] as Map)['teacherId'], 't-3');
        expect(work['seedReviewAt'], isNull);
        expect(DemoArtworkData.leadStatusOf(work), DemoArtworkData.leadNone);

        final list = await notices(DemoAccounts.student);
        final about = list.where((n) => n['targetId'] == 'aw-new-color');
        expect(about, hasLength(1));
        expect(about.single['content'], contains('刘芳老师点评了你的《课后练习》'));
        // 其余消息照常都在。
        expect(list.any((n) => '${n['content']}'.startsWith('【学情】')), isTrue);
        expect(list.any((n) => '${n['content']}'.startsWith('【校园】')), isTrue);
      },
    );

    test(
      'a 速写 work 赵雪 sends to 周强 is lead-reviewed after the delay',
      () async {
        // 赵雪有演示账号，速写组长周强没有：赵雪请复核后，由后端代周强复核。
        DemoArtworkStore.saveWork(
          submitted('aw-new-sketch', subject: '速写', teacherId: 't-4'),
        );
        await notices(DemoAccounts.headTeacher);
        await call(
          marking,
          'POST',
          '/school/teacher/artworks/review',
          DemoAccounts.headTeacher,
          body: <String, dynamic>{
            'artworkId': 'aw-new-sketch',
            'score': 82,
            'maxScore': 100,
            'content': '动态抓得准，线条再肯定一些，注意重心落在支撑脚上。',
            'requestLeadReview': true,
          },
        );
        final entered = DemoArtworkStore.workById('aw-new-sketch')!;
        expect(
          DemoArtworkData.leadStatusOf(entered),
          DemoArtworkData.leadInReview,
        );
        expect((entered['leadReview'] as Map)['leaderId'], 't-6');

        DemoArtworkStore.advanceNow(
          now.add(DemoArtworkData.autoDelay + const Duration(seconds: 1)),
        );
        final done = DemoArtworkStore.workById('aw-new-sketch')!;
        final lead = done['leadReview'] as Map;
        expect(DemoArtworkData.leadStatusOf(done), DemoArtworkData.leadDone);
        expect(DemoArtworkData.actions, contains(lead['action']));
        expect(lead['qualityStars'], inInclusiveRange(1, 5));
        expect(lead['seedLeadAt'], isNull);
        expect(
          DemoArtworkData.timelineOf(done).map((e) => e['role']),
          containsAll(<String>['STUDENT', 'TEACHER', 'LEADER']),
        );

        final told = (await notices(DemoAccounts.headTeacher)).where(
          (n) =>
              n['targetId'] == 'aw-new-sketch' &&
              '${n['content']}'.contains('组长'),
        );
        expect(told, hasLength(1));
        expect(told.single['content'], contains('周强组长'));
      },
    );
  });

  group('notices', () {
    test(
      'a notice appended before the receiver opens notices keeps the full seed',
      () async {
        DemoArtworkStore.appendNotice(
          userId: DemoAccounts.teacher.userId,
          content: '【作品】校长点评了《石膏头像练习》，请查看。',
          targetId: 'aw-some-work',
        );
        final list = await notices(DemoAccounts.teacher);
        expect(list.any((n) => n['targetId'] == 'aw-some-work'), isTrue);
        expect(list.any((n) => '${n['content']}'.startsWith('【学情】')), isTrue);
        expect(list.any((n) => '${n['content']}'.startsWith('【校园】')), isTrue);
        expect(list.any((n) => '${n['content']}'.startsWith('【书刊】')), isTrue);
        final ids = list.map((n) => n['id']).toList();
        expect(ids.toSet(), hasLength(ids.length));
      },
    );

    test('a submission is announced once, whether or not the teacher has opened notices', () async {
      // 李静还没打开过消息：种子里「最近一份待点评」说的就是这份新作品。
      final first = submitted('aw-new-a', subject: '素描', teacherId: 't-1');
      DemoArtworkStore.saveWork(first);
      DemoArtworkStore.notifyTeacherOfSubmit(first);
      var list = await notices(DemoAccounts.teacher);
      expect(list.where((n) => n['targetId'] == 'aw-new-a'), hasLength(1));

      // 打开过之后再来一份：追加一条。
      final second = submitted('aw-new-b', subject: '素描', teacherId: 't-1');
      DemoArtworkStore.saveWork(second);
      DemoArtworkStore.notifyTeacherOfSubmit(second);
      list = await notices(DemoAccounts.teacher);
      expect(list.where((n) => n['targetId'] == 'aw-new-a'), hasLength(1));
      expect(list.where((n) => n['targetId'] == 'aw-new-b'), hasLength(1));
    });
  });
}
