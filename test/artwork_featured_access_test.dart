import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_data.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_seed.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/marking_artwork_fixtures.dart';

/// 优秀作品对全校公开：被推优的作品任何身份都能读详情，不是本人、也没有教职权限的
/// 读者按「学生」一列的可见范围看，不能做任何操作；撤销推优后恢复原来的权限。
void main() {
  final now = DateTime(2026, 11, 13, 21, 30);
  late DemoRouter marking;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DemoStore.init();
    await DemoStore.reset();
    DemoArtworkStore.setNow(now);
    marking = DemoRouter('artwork-featured-access-test');
    registerMarkingArtworkFixtures(marking);
  });

  tearDown(() => DemoArtworkStore.setNow(null));

  Future<Object?> call(
    String method,
    String path,
    DemoAccount account, {
    Object? body,
    Map<String, dynamic> query = const <String, dynamic>{},
  }) async {
    final match = marking.match(method, path);
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

  Future<Map<String, dynamic>> detail(String id, DemoAccount account) async =>
      (await call('GET', '/app/artworks/$id', account) as Map)
          .cast<String, dynamic>();

  Matcher apiError(int code) =>
      throwsA(isA<DemoApiException>().having((e) => e.code, 'code', code));

  Future<void> feature(String id, {required bool featured}) => call(
    'POST',
    '/school/principal/artworks/$id/feature',
    DemoAccounts.principal,
    body: <String, dynamic>{'featured': featured},
  );

  /// 一份别的学生的、组长已复核过的色彩作品，还没被推优。联考冲刺2班的色彩由
  /// 王海波负责、刘芳复核，两人都没有演示账号：演示账号里只有校长和管理员对它有
  /// 教职权限。
  String otherStudentWork() {
    final work = DemoArtworkStore.works().firstWhere(
      (w) =>
          DemoArtworkData.personOf(w) != DemoAccounts.student.personIndex &&
          w['featured'] != true &&
          w['subject'] == '色彩' &&
          DemoArtworkData.classOf(DemoArtworkData.personOf(w)).id == '502' &&
          DemoArtworkData.leadStatusOf(w) == DemoArtworkData.leadDone &&
          DemoArtworkData.versionOf(w) == 1 &&
          DemoArtworkStore.versionsOf(w).length == 1,
    );
    final lead = DemoArtworkData.leadOf(work)!;
    expect(lead['reasons'], isNotEmpty);
    expect(lead['qualityStars'], inInclusiveRange(1, 5));
    return DemoArtworkData.text(work['id']);
  }

  const classmate = DemoAccount(
    role: DemoRole.student,
    mobile: '13900000002',
    name: '林小舟',
    userId: '1880000000000000102',
    gender: '男',
    personIndex: 2,
  );

  group('accessOf', () {
    test('a featured work is readable by everyone, with the student view', () {
      final chain = DemoArtworkStore.workById(DemoArtworkSeed.storyChainId)!;
      expect(chain['featured'], isTrue);

      for (final viewer in <DemoAccount>[classmate, DemoAccounts.dormManager]) {
        final access = DemoArtworkData.accessOf(viewer, chain);
        expect(access.owner, isFalse, reason: viewer.name);
        expect(access.staff, isFalse, reason: viewer.name);
        expect(access.publicReader, isTrue, reason: viewer.name);
        expect(access.canRead, isTrue, reason: viewer.name);
        // 「学生」一列：点评、复核结果、校长点评与优秀标记可见。
        expect(access.seesReview, isTrue, reason: viewer.name);
        expect(access.seesLeadResult, isTrue, reason: viewer.name);
        expect(access.seesPrincipal, isTrue, reason: viewer.name);
        // 进入复核的原因、点评质量星级不可见。
        expect(access.seesLeadReasons, isFalse, reason: viewer.name);
        expect(access.seesQuality, isFalse, reason: viewer.name);
        // 不能做任何操作。
        expect(access.canReview, isFalse, reason: viewer.name);
        expect(access.canSupplement, isFalse, reason: viewer.name);
        expect(access.canComment, isFalse, reason: viewer.name);
        expect(access.canFeature, isFalse, reason: viewer.name);
      }
    });

    test('featuring adds read access only and never changes other rights', () {
      final id = otherStudentWork();
      final before = DemoArtworkStore.workById(id)!;
      final after = DemoArtworkStore.workById(id)!..['featured'] = true;

      for (final viewer in DemoAccounts.all) {
        final a = DemoArtworkData.accessOf(viewer, before);
        final b = DemoArtworkData.accessOf(viewer, after);
        expect(b.canRead, isTrue, reason: viewer.name);
        expect(b.publicReader, !a.canRead, reason: viewer.name);
        expect(b.staff, a.staff, reason: viewer.name);
        expect(b.owner, a.owner, reason: viewer.name);
        expect(b.seesLeadReasons, a.seesLeadReasons, reason: viewer.name);
        expect(b.seesQuality, a.seesQuality, reason: viewer.name);
        expect(b.canReview, a.canReview, reason: viewer.name);
        expect(b.canSupplement, a.canSupplement, reason: viewer.name);
        expect(b.canComment, a.canComment, reason: viewer.name);
        expect(b.canFeature, a.canFeature, reason: viewer.name);
      }
      // 没被推优时，别的学生和宿管读不到。
      expect(DemoArtworkData.accessOf(classmate, before).canRead, isFalse);
      expect(
        DemoArtworkData.accessOf(DemoAccounts.dormManager, before).canRead,
        isFalse,
      );
    });

    test('the owner and the staff keep their own view of a featured work', () {
      final chain = DemoArtworkStore.workById(DemoArtworkSeed.storyChainId)!;
      final owner = DemoArtworkData.accessOf(DemoAccounts.student, chain);
      expect(owner.owner, isTrue);
      expect(owner.publicReader, isFalse);
      expect(owner.seesLeadReasons, isFalse);

      final teacher = DemoArtworkData.accessOf(DemoAccounts.teacher, chain);
      expect(teacher.responsible, isTrue);
      expect(teacher.publicReader, isFalse);
      expect(teacher.seesLeadReasons, isTrue);
      expect(teacher.seesQuality, isTrue);
      expect(teacher.canReview, isTrue);

      final principal = DemoArtworkData.accessOf(DemoAccounts.principal, chain);
      expect(principal.publicReader, isFalse);
      expect(principal.canFeature, isTrue);
    });
  });

  group('GET /app/artworks/{id}', () {
    test('another student reads a featured work without reasons or stars', () async {
      final id = otherStudentWork();
      await expectLater(detail(id, DemoAccounts.student), apiError(404));

      await feature(id, featured: true);
      final json = await detail(id, DemoAccounts.student);
      final work = json['work'] as Map;
      expect(work['id'], id);
      expect(work['featured'], isTrue);
      expect(work['studentName'], isNotEmpty);
      expect(work['className'], '联考冲刺2班');

      final review = json['review'] as Map;
      expect(review['content'], isNotEmpty);
      expect(review['dimensions'], isNotEmpty);

      final lead = json['leadReview'] as Map;
      expect(DemoArtworkData.actions, contains(lead['action']));
      expect(lead.containsKey('reasons'), isFalse);
      expect(lead.containsKey('qualityStars'), isFalse);
      expect(lead.containsKey('qualityNote'), isFalse);

      final timeline = (json['timeline'] as List).cast<Map>();
      expect(
        timeline.map((e) => e['type']),
        containsAllInOrder(<String>['SUBMIT', 'REVIEW', 'FEATURE']),
      );
      expect(timeline.any((e) => e['role'] == 'LEADER'), isTrue);

      final access = json['access'] as Map;
      expect(access['owner'], isFalse);
      for (final key in <String>[
        'canReview',
        'canSupplement',
        'canComment',
        'canFeature',
        'seesLeadReasons',
        'seesQuality',
      ]) {
        expect(access[key], isFalse, reason: key);
      }
    });

    test('every identity reads a featured work, each with its own view', () async {
      final id = otherStudentWork();
      await feature(id, featured: true);

      for (final account in DemoAccounts.all) {
        final json = await detail(id, account);
        final lead = json['leadReview'] as Map;
        final access = json['access'] as Map;
        expect(json['review'], isNotNull, reason: account.name);
        expect(access['owner'], isFalse, reason: account.name);
        // 只有校长和管理员对它有教职权限，看得到进入复核的原因与星级。
        final manages = account.role.managesSchool;
        expect(lead.containsKey('reasons'), manages, reason: account.name);
        expect(lead.containsKey('qualityStars'), manages, reason: account.name);
        expect(access['canReview'], isFalse, reason: account.name);
        expect(
          access['canFeature'],
          account.role == DemoRole.principal,
          reason: account.name,
        );
      }
    });

    test('readers of a featured work cannot act on it', () async {
      final id = otherStudentWork();
      await feature(id, featured: true);

      // 学生不能拿别人的作品改画重交。
      await expectLater(
        call(
          'POST',
          '/app/artworks',
          DemoAccounts.student,
          body: <String, dynamic>{
            'title': '改画',
            'subject': '色彩',
            'drawingDate': DemoArtworkData.ymd(now),
            'imageIds': <String>['img-none'],
            'parentId': id,
          },
        ),
        apiError(404),
      );
      // 不是责任老师不能点评，不是本组组长不能复核，宿管不能补充点评。
      await expectLater(
        call(
          'POST',
          '/school/teacher/artworks/review',
          DemoAccounts.teacher,
          body: <String, dynamic>{
            'artworkId': id,
            'score': 90,
            'maxScore': 100,
            'content': '色调统一，冷暖关系明确，暗部可以再透气一些。',
          },
        ),
        apiError(403),
      );
      await expectLater(
        call(
          'POST',
          '/school/leader/reviews/$id',
          DemoAccounts.groupLeader,
          body: <String, dynamic>{'action': 'KEEP', 'qualityStars': 4},
        ),
        apiError(403),
      );
      await expectLater(
        call(
          'POST',
          '/school/teacher/artworks/$id/supplement',
          DemoAccounts.dormManager,
          body: <String, dynamic>{'content': '画得很认真，继续加油。'},
        ),
        apiError(403),
      );
      await expectLater(
        call(
          'GET',
          '/school/teacher/artworks/$id/annotations',
          DemoAccounts.dormManager,
        ),
        apiError(403),
      );

      final work = DemoArtworkStore.workById(id)!;
      expect(DemoArtworkData.supplementsOf(work), isEmpty);
      expect(DemoArtworkStore.versionsOf(work), hasLength(1));
    });

    test('taking a work off the wall restores the previous access', () async {
      final id = otherStudentWork();
      await feature(id, featured: true);
      await detail(id, DemoAccounts.student);
      await detail(id, DemoAccounts.dormManager);

      await feature(id, featured: false);
      await expectLater(detail(id, DemoAccounts.student), apiError(404));
      await expectLater(detail(id, DemoAccounts.dormManager), apiError(403));
      await expectLater(detail(id, DemoAccounts.principal), apiError(403));
      // 教职详情接口照旧：校长能读，宿管不能。
      expect(
        await call(
          'GET',
          '/school/teacher/artworks/$id',
          DemoAccounts.principal,
        ),
        isA<Map>(),
      );
      await expectLater(
        call('GET', '/school/teacher/artworks/$id', DemoAccounts.dormManager),
        apiError(403),
      );
    });

    test('the owner is told so, featured or not', () async {
      final featured = await detail(
        DemoArtworkSeed.storyChainId,
        DemoAccounts.student,
      );
      expect((featured['access'] as Map)['owner'], isTrue);
      expect((featured['work'] as Map)['className'], '联考冲刺1班');
      expect((featured['leadReview'] as Map).containsKey('reasons'), isFalse);

      final plain = await detail(
        DemoArtworkSeed.storyInReviewId,
        DemoAccounts.student,
      );
      expect((plain['access'] as Map)['owner'], isTrue);
      expect((plain['work'] as Map)['featured'], isFalse);

      // 教职身份读没被推优的作品，仍然走教职详情接口。
      await expectLater(
        detail(DemoArtworkSeed.storyInReviewId, DemoAccounts.teacher),
        apiError(403),
      );
      await expectLater(detail('aw-missing', DemoAccounts.student), apiError(404));
    });

    test('a public reader only sees the featured versions of a chain', () async {
      // 别的学生的一条改画链：把第 2 版推优。
      final v2 = DemoArtworkStore.works().firstWhere((w) {
        if (DemoArtworkData.personOf(w) == DemoAccounts.student.personIndex ||
            DemoArtworkData.versionOf(w) != 2 ||
            !DemoArtworkData.isReviewed(w)) {
          return false;
        }
        final chain = DemoArtworkStore.versionsOf(w);
        return chain.length == 2 && chain.every((v) => v['featured'] != true);
      });
      final id = DemoArtworkData.text(v2['id']);
      final parentId = DemoArtworkData.text(v2['parentId']);
      expect(parentId, isNotEmpty);
      await feature(id, featured: true);

      final reader = await detail(id, DemoAccounts.student);
      expect(
        (reader['versions'] as List).map((v) => (v as Map)['id']),
        <String>[id],
      );
      expect((reader['work'] as Map)['versionCount'], 2);
      await expectLater(detail(parentId, DemoAccounts.student), apiError(404));

      // 校长对这份作品有教职权限，两版都在。
      final principal = await detail(id, DemoAccounts.principal);
      expect(principal['versions'], hasLength(2));
    });
  });

  test('the wall lists featured works with student name and class', () async {
    final page =
        await call(
              'GET',
              '/app/artworks/excellent',
              DemoAccounts.dormManager,
              query: <String, dynamic>{'size': 50},
            )
            as Map;
    final records = (page['records'] as List).cast<Map>();
    expect(records, hasLength(12));
    const classes = <String>{'联考冲刺1班', '联考冲刺2班', '校考提高班'};
    for (final record in records) {
      expect(record['featured'], isTrue);
      expect(record['studentName'], isNotEmpty);
      expect(classes, contains(record['className']));
    }
    // 林小雨读得到墙上每一份作品的详情。
    for (final record in records) {
      final json = await detail('${record['id']}', DemoAccounts.student);
      expect((json['work'] as Map)['id'], record['id']);
    }
  });
}
