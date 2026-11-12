// 组长复核：复核范围、通过（组长点评、改定分数、范例、需关注）、退回重评后老师
// 重新点评，以及学生端能看到什么。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_data.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/marking_artwork_fixtures.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_models.dart';

/// 林小雨的《石膏头像结构练习》：李静与张明远都已点评，等素描组组长复核。
const _pendingWork = 'aw-1006';

/// 色彩作品，只指派给李静且未点评；色彩组组长没有体验账号。
const _colorWork = 'aw-1012';

void main() {
  late DemoRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DemoStore.init();
    await DemoStore.reset();
    router = DemoRouter('artwork-lead-review-test');
    registerMarkingArtworkFixtures(router);
  });

  Future<Object?> call(
    String method,
    String path,
    DemoAccount account, {
    Map<String, dynamic> query = const <String, dynamic>{},
    Map<String, dynamic>? body,
  }) async {
    final match = router.match(method, path);
    expect(match, isNotNull, reason: path);
    return await Future<Object?>.value(
      match!.handler(
        DemoRequest(
          method: method,
          path: path,
          query: query,
          body: body,
          headers: <String, dynamic>{'app-token': account.token},
          pathParams: match.params,
        ),
      ),
    );
  }

  Future<Map> leadStats([
    DemoAccount account = DemoAccounts.subjectLead,
  ]) async =>
      await call('GET', '/school/lead/artworks/statistics', account) as Map;

  Future<Map> teacherStats() async =>
      await call(
            'GET',
            '/school/teacher/artworks/statistics',
            DemoAccounts.teacher,
          )
          as Map;

  Future<List<ArtworkSummary>> leadList(String status) async {
    final page = ArtworkPage.fromJson(
      await call(
        'GET',
        '/school/lead/artworks',
        DemoAccounts.subjectLead,
        query: <String, dynamic>{'status': status, 'size': 50},
      ),
    );
    return page.records;
  }

  Future<ArtworkDetail> leadDetail(String id) async => ArtworkDetail.fromJson(
    await call('GET', '/school/lead/artworks/$id', DemoAccounts.subjectLead),
  );

  Future<ArtworkDetail> teacherDetail(String id) async =>
      ArtworkDetail.fromJson(
        await call('GET', '/school/teacher/artworks/$id', DemoAccounts.teacher),
      );

  Future<ArtworkDetail> studentDetail(String id) async =>
      ArtworkDetail.fromJson(
        await call('GET', '/app/artworks/$id', DemoAccounts.student),
      );

  Future<Object?> leadReview(
    String id, {
    required String action,
    String content = '',
    double? score,
    bool exemplar = false,
    bool attention = false,
    bool next = false,
  }) => call(
    'POST',
    '/school/lead/artworks/review',
    DemoAccounts.subjectLead,
    query: <String, dynamic>{'next': '$next'},
    body: <String, dynamic>{
      'artworkId': id,
      'action': action,
      'content': content,
      'score': score,
      'exemplar': exemplar,
      'attention': attention,
    },
  );

  Future<Object?> teacherReview(String id, {double score = 89}) => call(
    'POST',
    '/school/teacher/artworks/review',
    DemoAccounts.teacher,
    query: const <String, dynamic>{'next': 'false'},
    body: <String, dynamic>{
      'artworkId': id,
      'score': score,
      'maxScore': 100,
      'content': '按组长意见补充了比例问题的说明。',
      'tagIds': const <String>[],
    },
  );

  group('scope', () {
    test('only the group lead gets a review queue', () async {
      final lead = await leadStats();
      expect(lead['isLead'], isTrue);
      expect(lead['groupName'], '素描组');
      expect(lead['pending'], 2);
      expect(lead['reviewed'], greaterThan(0));

      final teacher = await leadStats(DemoAccounts.teacher);
      expect(teacher['isLead'], isFalse);
      expect(teacher['pending'], 0);

      expect(
        call('GET', '/school/lead/artworks', DemoAccounts.teacher),
        throwsA(isA<DemoApiException>()),
      );
    });

    test('queue holds the group subject, reviewed by other teachers', () async {
      final pending = await leadList('PENDING');
      expect(pending.map((w) => w.id).toSet(), {_pendingWork, 'aw-1015'});
      for (final work in await leadList('ALL')) {
        expect(work.subject, '素描', reason: work.title);
        expect(work.teacherNames, isNotEmpty, reason: work.title);
      }
      final done = await leadList('REVIEWED');
      expect(done, isNotEmpty);
      expect(done.every((w) => w.leadApproved), isTrue);
      expect(done.any((w) => w.exemplar), isTrue);
    });

    test('a work assigned only to the lead needs no review', () {
      final own = DemoArtworkData.seedWorks().firstWhere(
        (w) => DemoArtworkData.teacherIdsOf(w).join() == 't-2',
      );
      expect(DemoArtworkData.leadIdOf(own), isNull);
      expect(DemoArtworkData.leadStatusOf(own), DemoArtworkData.leadNone);
    });
  });

  group('approve', () {
    test('students already see teacher reviews before the lead acts', () async {
      final detail = await studentDetail(_pendingWork);
      expect(detail.work.reviewed, isTrue);
      expect(detail.work.finalScore, 87);
      expect(detail.leadReview, isNull);
    });

    test('lead comment, score override and exemplar reach the student', () async {
      final result = await leadReview(
        _pendingWork,
        action: 'APPROVE',
        content: '结构讲得清楚，暗部可以再整体。',
        score: 90,
        exemplar: true,
        attention: true,
        next: true,
      );
      expect((result as Map)['nextArtworkId'], 'aw-1015');
      expect((await leadStats())['pending'], 1);

      final student = await studentDetail(_pendingWork);
      expect(student.work.finalScore, 90);
      expect(student.work.exemplar, isTrue);
      expect(student.leadReview!.leaderName, '张明远');
      expect(student.leadReview!.content, contains('结构讲得清楚'));
      expect(student.leadReview!.score, 90);
      // 「需关注」只给教职工看。
      expect(student.leadReview!.attention, isFalse);

      final teacher = await teacherDetail(_pendingWork);
      expect(teacher.work.leadApproved, isTrue);
      expect(teacher.work.attention, isTrue);
      expect(teacher.leadReview!.attention, isTrue);
    });

    test('approving without a score keeps the teachers mean', () async {
      await leadReview(_pendingWork, action: 'APPROVE');
      final student = await studentDetail(_pendingWork);
      expect(student.work.finalScore, 87);
      expect(student.leadReview!.score, isNull);
    });

    test('score above the full mark is rejected', () {
      expect(
        leadReview(_pendingWork, action: 'APPROVE', score: 101),
        throwsA(isA<DemoApiException>()),
      );
    });

    test('works still waiting for teachers cannot be reviewed', () {
      expect(
        leadReview('aw-1001', action: 'APPROVE'),
        throwsA(isA<DemoApiException>()),
      );
    });
  });

  group('return', () {
    test('a reason is required', () {
      expect(
        leadReview(_pendingWork, action: 'RETURN'),
        throwsA(isA<DemoApiException>()),
      );
    });

    test('teacher re-reviews and the work comes back to the lead', () async {
      final before = await teacherStats();
      await leadReview(
        _pendingWork,
        action: 'RETURN',
        content: '比例问题没有点出来，请补充。',
      );

      // 老师端：回到待点评，带退回原因，原来的点评还在。
      final after = await teacherStats();
      expect(after['pending'], (before['pending'] as int) + 1);
      final returned = await teacherDetail(_pendingWork);
      expect(returned.work.myReviewed, isFalse);
      expect(returned.work.returnReason, contains('比例问题'));
      expect(returned.myReview!.returned, isTrue);
      expect(returned.myReview!.score, 88);

      // 组长端：不在待复核里，组长自己的点评保留。
      final lead = await leadDetail(_pendingWork);
      expect(lead.work.leadReturned, isTrue);
      expect(lead.leadReview!.approved, isFalse);
      expect(lead.reviews.where((r) => r.reviewed).map((r) => r.teacherName), [
        '张明远',
      ]);
      expect((await leadList('PENDING')).map((w) => w.id), ['aw-1015']);

      // 学生端：回到等待点评，看不到退回原因。
      final student = await studentDetail(_pendingWork);
      expect(student.work.reviewed, isFalse);
      expect(student.leadReview, isNull);

      await teacherReview(_pendingWork);
      final again = await leadDetail(_pendingWork);
      expect(again.work.leadPending, isTrue);
      expect(again.leadReview, isNull);
      expect(again.work.finalScore, 87.5);
      expect((await teacherDetail(_pendingWork)).work.returnReason, isEmpty);
    });
  });

  test('groups whose lead has no demo account pass automatically', () async {
    expect((await teacherDetail(_colorWork)).work.leadWaiting, isTrue);
    await teacherReview(_colorWork, score: 82);
    final detail = await teacherDetail(_colorWork);
    expect(detail.work.leadApproved, isTrue);
    expect(detail.leadReview!.leaderName, '王海波');
  });
}
