import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';

void main() {
  final today = DateTime.now();
  final now = DateTime(today.year, today.month, today.day, 21, 30);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoStore.init();
    await DemoStore.reset();
    DemoArtworkStore.setNow(now);
    registerDemoFixtures();
  });
  tearDown(() => DemoArtworkStore.setNow(null));

  Future<dynamic> call(
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

  test(
    'principal totals match campus-filtered attendance, queues and attention',
    () async {
      final router = DemoBackend.marking;
      for (final campus in ['', '501', '502', '503']) {
        final query = {'campusId': campus};
        final overview =
            await call(
                  router,
                  'GET',
                  '/school/principal/overview',
                  DemoAccounts.principal,
                  query: query,
                )
                as Map;
        final attendance =
            await call(
                  router,
                  'GET',
                  '/school/principal/attendance',
                  DemoAccounts.principal,
                  query: query,
                )
                as Map;
        final attention =
            await call(
                  router,
                  'GET',
                  '/school/principal/attention-students',
                  DemoAccounts.principal,
                  query: query,
                )
                as List;
        expect(overview['attentionCount'], attention.length);
        for (final key in [
          'studentPresent',
          'studentExpected',
          'teacherPresent',
          'teacherExpected',
        ]) {
          expect(overview['attendance'][key], attendance[key]);
        }
        expect(
          attendance['students'],
          hasLength(
            (attendance['studentExpected'] as int) -
                (attendance['studentPresent'] as int),
          ),
        );
        expect(
          attendance['teachers'],
          hasLength(
            (attendance['teacherExpected'] as int) -
                (attendance['teacherPresent'] as int),
          ),
        );
        for (final (filter, metric) in [
          ('overdue', 'overdueReviews'),
          ('leadOverdue', 'overdueLeadReviews'),
        ]) {
          final chain =
              await call(
                    router,
                    'GET',
                    '/school/principal/review-chain',
                    DemoAccounts.principal,
                    query: {...query, 'filter': filter},
                  )
                  as Map;
          expect(chain['total'], overview[metric], reason: '$campus $filter');
        }
        final chain =
            await call(
                  router,
                  'GET',
                  '/school/principal/review-chain',
                  DemoAccounts.principal,
                  query: {...query, 'date': overview['date']},
                )
                as Map;
        expect(chain['total'], overview['todaySubmissions']);
      }
    },
  );

  test(
    'only principal, the group leader and the teacher can see their permitted performance data',
    () async {
      final router = DemoBackend.marking;
      for (final account in [
        DemoAccounts.admin,
        DemoAccounts.teacher,
        DemoAccounts.student,
      ]) {
        await expectLater(
          call(router, 'GET', '/school/principal/teachers', account),
          throwsA(isA<DemoApiException>().having((e) => e.code, 'code', 403)),
        );
      }
      final group =
          await call(
                router,
                'GET',
                '/school/leader/teachers',
                DemoAccounts.groupLeader,
              )
              as List;
      expect(group.map((row) => row['subject']).toSet(), {'素描'});
      final own =
          await call(
                router,
                'GET',
                '/school/teacher/performance',
                DemoAccounts.teacher,
              )
              as Map;
      expect(own['id'], DemoAccounts.teacher.teacherId);
    },
  );

  test(
    'published assignment and all review actions share the same artwork',
    () async {
      final router = DemoBackend.marking;
      final platform = DemoBackend.platform;
      const teacher = DemoAccounts.teacher;
      const student = DemoAccounts.student;
      const leader = DemoAccounts.groupLeader;
      const principal = DemoAccounts.principal;
      final tomorrow = now
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      final published =
          await call(
                platform,
                'POST',
                '/app/school/v2/teacher/teacherHomeworkSave',
                teacher,
                body: {
                  'title': '接续素描练习',
                  'classIds': ['501'],
                  'subjectId': 38,
                  'endTime': '$tomorrow 21:30:00',
                  'description': '交一幅石膏素描',
                },
              )
              as Map;
      final taskId = (published['ids'] as List).single as String;
      Future<Map> task() async {
        final tasks = await call(router, 'GET', '/app/tasks', student) as List;
        return tasks.firstWhere((row) => row['id'] == taskId) as Map;
      }

      expect((await task())['status'], 'PENDING');
      Future<String> submit(String imageId, {String parentId = ''}) async {
        DemoArtworkStore.uploads()[imageId] = {
          'personIndex': student.personIndex,
          'ref': 'asset:assets/demo/art/sketch-bust-1.jpg',
        };
        final created = await call(
          router,
          'POST',
          '/app/artworks',
          student,
          body: {
            'title': '接续素描练习',
            'subject': '素描',
            'drawingDate': now.toIso8601String().substring(0, 10),
            if (parentId.isEmpty) 'taskId': taskId,
            if (parentId.isNotEmpty) 'parentId': parentId,
            'imageIds': [imageId],
          },
        );
        return created is Map
            ? created['artworkId'] as String
            : created as String;
      }

      final id = await submit('qa-art-1');
      expect((await task())['status'], 'SUBMITTED');
      await call(
        router,
        'POST',
        '/school/teacher/artworks/review',
        teacher,
        body: {
          'artworkId': id,
          'score': 83,
          'maxScore': 100,
          'content': '请留意暗部的层次和轮廓交接',
          'dimensions': {
            'composition': 4,
            'form': 4,
            'value': 3,
            'rendering': 3,
          },
          'requestLeadReview': true,
        },
      );
      final original =
          await call(router, 'GET', '/app/artworks/$id', student) as Map;
      expect(original['work']['finalScore'], 83);
      expect(original['leadReview'], isNot(contains('reasons')));
      await call(
        router,
        'POST',
        '/school/leader/reviews/$id',
        leader,
        body: {
          'action': 'ADJUST',
          'score': 86,
          'reason': '造型比例稳定，综合各项表现调整分数',
          'qualityStars': 4,
        },
      );
      await call(
        router,
        'POST',
        '/school/principal/artworks/$id/comment',
        principal,
        body: {'content': '构图完整，继续练习明暗交界'},
      );
      await call(
        router,
        'POST',
        '/school/principal/artworks/$id/feature',
        principal,
        body: {'featured': true},
      );
      expect((await task())['status'], 'REVIEWED');
      final detail =
          await call(router, 'GET', '/app/artworks/$id', student) as Map;
      expect(detail['work']['finalScore'], 86);
      expect(
        (detail['timeline'] as List).map((event) => event['type']),
        containsAll(['REVIEW', 'LEAD_ADJUST', 'PRINCIPAL_COMMENT', 'FEATURE']),
      );
      final campus =
          await call(
                platform,
                'POST',
                '/app/school/v2/student/studentHomeworkDetail',
                student,
                body: {'id': taskId},
              )
              as Map;
      expect(campus['homeworkStudent']['score'], 86);
      final revisionId = await submit('qa-art-2', parentId: id);
      final revision =
          await call(router, 'GET', '/app/artworks/$revisionId', student)
              as Map;
      expect(revision['work']['taskId'], taskId);
      expect(revision['work']['version'], 2);
      expect(revision['work']['teacherName'], teacher.name);
      expect((await task())['status'], 'SUBMITTED');
    },
  );
}
