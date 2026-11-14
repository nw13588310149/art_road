import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_data.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_seed.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoStore.init();
    await DemoStore.reset();
    DemoArtworkStore.setNow(DateTime(2026, 11, 14, 16));
    registerDemoFixtures();
  });
  tearDown(() => DemoArtworkStore.setNow(null));
  Future<dynamic> call(
    String method,
    String path, {
    DemoAccount? account,
    Map<String, dynamic> body = const {},
    bool marking = false,
  }) async {
    final router = marking ? DemoBackend.marking : DemoBackend.platform;
    final endpoint = router.match(method, path);
    expect(
      endpoint,
      isNotNull,
      reason: '$method $path must have a demo fixture',
    );
    return endpoint!.handler(
      DemoRequest(
        method: method,
        path: path,
        query: {},
        body: body,
        headers: {'token': (account ?? DemoAccounts.student).token},
        pathParams: endpoint.params,
      ),
    );
  }

  Matcher rejected(int code) =>
      throwsA(isA<DemoApiException>().having((e) => e.code, 'code', code));

  test(
    'uploaded image book resumes by reader identity with valid page bounds',
    () async {
      await call('GET', '/app/micro-lessons/resources');
      DemoStore.list('creative:resources:v1', () => []).add({
        'id': 'reading-test',
        'title': '体积练习',
        'kind': 'images',
        'cover': 'asset:assets/demo/ebooks/eb-sketch-still-cover.jpg',
        'pages': ['page-1', 'page-2'],
        'ownerId': DemoAccounts.student.userId,
      });
      const path = '/app/creative/resources/reading-test/progress';
      await expectLater(
        call('GET', path, account: DemoAccounts.teacher),
        rejected(403),
      );
      await call(
        'POST',
        '/app/micro-lessons',
        body: {
          'title': '体积阅读练习',
          'intro': '读完这两页，观察体块与明暗之间的关系。',
          'subject': '素描',
          'minutes': 10,
          'resourceIds': ['reading-test'],
        },
      );
      await call('POST', path, body: {'page': 1});
      expect((await call('GET', path))['page'], 1);
      expect(
        (await call('GET', path, account: DemoAccounts.teacher))['page'],
        0,
      );
      await expectLater(call('POST', path, body: {'page': 2}), rejected(400));
      expect((await call('GET', path))['page'], 1);
    },
  );

  test(
    'leader waits for all assigned teachers and each teacher retains a pending task',
    () async {
      const id = 'co-review-pending';
      final work = <String, dynamic>{
        ...DemoArtworkStore.workById(DemoArtworkSeed.storyChainId)!,
        'id': id,
        'rootId': id,
        'teacherIds': ['t-1', 't-4', 't-5'],
        'review': null,
        'teacherReviews': <Map<String, dynamic>>[],
        'leadReview': null,
        'reviewHistory': <Map<String, dynamic>>[],
        'principalComments': <Map<String, dynamic>>[],
        'seedCoReviewsAt': {'t-5': '2026-11-14 16:01:00'},
      };
      DemoArtworkStore.saveWork(work);
      for (final account in [DemoAccounts.teacher, DemoAccounts.headTeacher]) {
        await call(
          'POST',
          '/school/teacher/artworks/review',
          marking: true,
          account: account,
          body: {
            'artworkId': id,
            'score': 86,
            'maxScore': 100,
            'content': '体积关系清楚，继续观察边缘线和空间之间的关系。',
          },
        );
        expect(DemoArtworkStore.workById(id)!['leadReview'], isNull);
      }
      await expectLater(
        call(
          'POST',
          '/school/leader/reviews/$id',
          marking: true,
          account: DemoAccounts.groupLeader,
          body: {
            'action': 'REVIEW',
            'score': 90,
            'qualityStars': 4,
            'content': '先完成所有任课老师的独立评价。',
          },
        ),
        rejected(400),
      );
      DemoArtworkStore.setNow(DateTime(2026, 11, 14, 16, 2));
      final completed = DemoArtworkStore.workById(id)!;
      expect(DemoArtworkData.reviewsOf(completed), hasLength(3));
      expect(DemoArtworkData.teacherStageComplete(completed), isTrue);
      expect(
        DemoArtworkData.leadStatusOf(completed),
        DemoArtworkData.leadInReview,
      );
    },
  );

  test(
    'topic publication keeps PDF and image book references and per-user favorites',
    () async {
      final topics = await call('GET', '/app/micro-lessons') as List;
      expect(topics, hasLength(8));
      expect(topics.every((t) => (t['resources'] as List).length >= 2), isTrue);
      final result = await call(
        'POST',
        '/app/micro-lessons',
        body: {
          'title': '明暗关系阅读练习',
          'intro': '通过图文对照观察明暗关系与形体转折。',
          'subject': '素描',
          'minutes': 12,
          'resourceIds': ['eb-sketch-still', 'eb-sketch-still-pdf'],
          'tags': ['明暗'],
        },
      );
      final id = result['id'];
      await call('POST', '/app/micro-lessons/$id/favorite');
      final mine = (await call('GET', '/app/micro-lessons') as List).first;
      expect(mine['mine'], isTrue);
      expect(mine['favorite'], isTrue);
      expect((mine['resources'] as List).map((r) => r['kind']), [
        'images',
        'pdf',
      ]);
      final other =
          (await call(
                    'GET',
                    '/app/micro-lessons',
                    account: DemoAccounts.teacher,
                  )
                  as List)
              .first;
      expect(other['favorite'], isFalse);
      expect(other['mine'], isFalse);
      await expectLater(
        call(
          'POST',
          '/app/micro-lessons/$id/remove',
          account: DemoAccounts.teacher,
        ),
        rejected(403),
      );
      await expectLater(
        call(
          'POST',
          '/app/micro-lessons',
          body: {
            'title': '空资料',
            'intro': '介绍足够完整但是没有选择阅读资料。',
            'subject': '素描',
            'minutes': 10,
            'resourceIds': [],
          },
        ),
        rejected(400),
      );
    },
  );

  test(
    'market creates one order per buyer and preserves its license snapshot after withdrawal',
    () async {
      final first = await call(
        'POST',
        '/app/market/orders',
        body: {
          'listingId': 'market-1',
          'idempotencyKey': 'legacy-flow',
          'expectedPriceCents': 1800,
          'expectedTotalCents': 1800,
          'termsAccepted': true,
        },
      );
      final again = await call(
        'POST',
        '/app/market/orders',
        body: {
          'listingId': 'market-1',
          'idempotencyKey': 'legacy-flow',
          'expectedPriceCents': 1800,
          'expectedTotalCents': 1800,
          'termsAccepted': true,
        },
      );
      expect(again['id'], first['id']);
      expect(first['status'], 'pending_payment');
      await call('POST', '/app/market/orders/${first['id']}/pay');
      expect(await call('GET', '/app/market/orders'), hasLength(1));
      expect(
        await call('GET', '/app/market/orders', account: DemoAccounts.teacher),
        hasLength(1),
      );
      await expectLater(
        call(
          'POST',
          '/app/market/orders',
          account: DemoAccounts.teacher,
          body: {
            'listingId': 'market-1',
            'idempotencyKey': 'legacy-flow',
            'expectedPriceCents': 1800,
            'expectedTotalCents': 1800,
            'termsAccepted': true,
          },
        ),
        rejected(400),
      );
      await expectLater(
        call(
          'POST',
          '/app/market/orders',
          body: {
            'listingId': 'market-3',
            'idempotencyKey': 'showcase',
            'expectedPriceCents': 0,
            'expectedTotalCents': 0,
            'termsAccepted': true,
          },
        ),
        rejected(409),
      );
      await call(
        'POST',
        '/app/market/listings/market-1/remove',
        account: DemoAccounts.teacher,
      );
      final orders = await call('GET', '/app/market/orders') as List;
      expect(orders.single['listing']['priceCents'], 1800);
      expect(orders.single['listing']['license'], 'study');
      expect(orders.single['listing']['cover'], isNotEmpty);
    },
  );

  test(
    'publishing requires rights, validates integer money and forbids selling another student work',
    () async {
      final body = <String, dynamic>{
        'title': '新的静物作品',
        'description': '记录静物创作中的明暗组织与空间关系。',
        'subject': '素描',
        'imageId': 'sample-1',
        'kind': 'digital',
        'submit': true,
        'deliveryIds': ['sample-1'],
        'priceCents': 1800,
        'license': 'study',
        'rightsConfirmed': true,
      };
      await expectLater(
        call(
          'POST',
          '/app/market/listings',
          body: {...body, 'rightsConfirmed': false},
        ),
        rejected(400),
      );
      await expectLater(
        call(
          'POST',
          '/app/market/listings',
          body: {...body, 'priceCents': 1800.5},
        ),
        rejected(400),
      );
      await expectLater(
        call(
          'POST',
          '/app/market/listings',
          account: DemoAccounts.teacher,
          body: {...body, 'artworkId': DemoArtworkSeed.storyChainId},
        ),
        rejected(403),
      );
      final saved = await call('POST', '/app/market/listings', body: body);
      final row = (await call('GET', '/app/market/listings') as List).first;
      expect(row['id'], saved['id']);
      expect(row['mine'], isTrue);
      expect(row['author'], DemoAccounts.student.name);
    },
  );

  test(
    'three teachers, leader and principal retain independent scores and edit history',
    () async {
      const id = DemoArtworkSeed.storyChainId;
      final original = DemoArtworkStore.workById(id)!;
      expect(DemoArtworkData.reviewsOf(original), hasLength(3));
      expect(DemoArtworkData.principalCommentsOf(original).single['score'], 93);
      await call(
        'POST',
        '/school/teacher/artworks/review',
        marking: true,
        account: DemoAccounts.headTeacher,
        body: {
          'artworkId': id,
          'score': 88,
          'maxScore': 100,
          'content': '动态线与转折表达准确，可以继续强化空间关系。',
        },
      );
      var work = DemoArtworkStore.workById(id)!;
      expect(DemoArtworkData.reviewsOf(work), hasLength(3));
      expect(DemoArtworkData.reviewOf(work)!['score'], 87);
      expect(DemoArtworkData.finalScoreOf(work), 91);
      await call(
        'POST',
        '/school/leader/reviews/$id',
        marking: true,
        account: DemoAccounts.groupLeader,
        body: {
          'action': 'REVIEW',
          'score': 92,
          'content': '整体关系明确，重点部位的虚实组织可以继续推敲。',
          'qualityStars': 4,
        },
      );
      await call(
        'POST',
        '/school/principal/artworks/$id/comment',
        marking: true,
        account: DemoAccounts.principal,
        body: {'score': 95, 'content': '保持整体观察，期待后续对空间关系的深入表现。'},
      );
      work = DemoArtworkStore.workById(id)!;
      expect(DemoArtworkData.finalScoreOf(work), 92);
      expect(DemoArtworkData.principalCommentsOf(work).single['score'], 95);
      expect(DemoArtworkData.reviewsOf(work), hasLength(3));
      expect(DemoArtworkData.mapsOf(work['reviewHistory']), hasLength(3));
      final detail = await call('GET', '/app/artworks/$id', marking: true);
      expect(detail['reviews'], hasLength(3));
      expect(detail['work']['reviewedCount'], 3);
      await expectLater(
        call(
          'POST',
          '/school/principal/artworks/$id/comment',
          marking: true,
          account: DemoAccounts.principal,
          body: {'score': 101, 'content': '这份评分超过了满分范围。'},
        ),
        rejected(400),
      );
    },
  );
}
