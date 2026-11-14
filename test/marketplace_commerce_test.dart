import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/marketplace_fixtures.dart';

void main() {
  late DemoRouter router;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoStore.init();
    await DemoStore.reset();
    router = DemoRouter('commerce-test');
    registerMarketplaceFixtures(
      router,
      seedListings: () => [
        for (final kind in ['digital', 'physical'])
          {
            'id': kind,
            'kind': kind,
            'title': '$kind 静物作品',
            'subject': '素描',
            'description': '这幅作品以明暗关系表现几何体的空间与体积。',
            'ownerId': DemoAccounts.teacher.userId,
            'author': DemoAccounts.teacher.name,
            'cover': 'asset:assets/demo/art/sketch-bust-1.jpg',
            'priceCents': 1800,
            'shippingCents': kind == 'physical' ? 1200 : 0,
            'stock': 1,
            'status': 'published',
            'forSale': true,
            'license': 'study',
          },
      ],
      resources: () => [
        {
          'id': 'owned-pdf',
          'kind': 'pdf',
          'ownerId': DemoAccounts.teacher.userId,
          'url': 'blob:uploaded-pdf-without-extension',
        },
        {
          'id': 'sample-image',
          'kind': 'images',
          'sample': true,
          'cover': 'asset:assets/demo/art/sketch-bust-1.jpg',
          'pages': ['asset:assets/demo/art/sketch-bust-1.jpg'],
        },
      ],
    );
  });
  Future<dynamic> call(
    String method,
    String path, {
    DemoAccount account = DemoAccounts.student,
    Map<String, dynamic> body = const {},
  }) async {
    final match = router.match(method, path);
    expect(match, isNotNull, reason: path);
    return match!.handler(
      DemoRequest(
        method: method,
        path: path,
        query: {},
        body: body,
        headers: {'token': account.token},
        pathParams: match.params,
      ),
    );
  }

  Matcher rejected(int code) =>
      throwsA(isA<DemoApiException>().having((e) => e.code, 'code', code));
  Future<dynamic> create(
    String kind,
    String key, {
    String address = '',
    DemoAccount account = DemoAccounts.student,
  }) => call(
    'POST',
    '/app/market/orders',
    account: account,
    body: {
      'listingId': kind,
      'idempotencyKey': key,
      'expectedPriceCents': 1800,
      'expectedTotalCents': kind == 'physical' ? 3000 : 1800,
      'termsAccepted': true,
      'addressId': address,
    },
  );
  Future<String> address() async =>
      (await call(
            'POST',
            '/app/market/addresses',
            body: {
              'name': '林小雨',
              'phone': '13809310001',
              'detail': '示范画室城东校区一号楼前台',
              'default': true,
            },
          ))['id']
          as String;

  test(
    'digital checkout gates delivery, is idempotent, and preserves terms and price',
    () async {
      final order = await create('digital', 'first');
      final id = order['id'];
      expect(order['status'], 'pending_payment');
      expect(order['totalCents'], 1800);
      expect(order['listing'].containsKey('deliveryRefs'), false);
      expect((await create('digital', 'first'))['id'], id);
      expect(DemoStore.list('creative:orders:v1', () => []).length, 1);
      await expectLater(
        call('GET', '/app/market/orders/$id/delivery'),
        rejected(403),
      );
      await expectLater(
        call(
          'POST',
          '/app/market/orders/$id/pay',
          account: DemoAccounts.headTeacher,
        ),
        rejected(403),
      );
      final listing = DemoStore.list('creative:listings:v1', () => []).first;
      listing['priceCents'] = 9999;
      listing['license'] = 'commercial';
      final paid = await call('POST', '/app/market/orders/$id/pay');
      expect(paid['totalCents'], 1800);
      expect(paid['listing']['license'], 'study');
      expect(paid['listing']['licenseTerms'], contains('个人'));
      expect(
        (await call('POST', '/app/market/orders/$id/pay'))['events'].length,
        paid['events'].length,
      );
      expect(
        (await call('GET', '/app/market/orders/$id/delivery'))['files'],
        isNotEmpty,
      );
      await expectLater(
        call(
          'GET',
          '/app/market/orders/$id/delivery',
          account: DemoAccounts.teacher,
        ),
        rejected(403),
      );
    },
  );

  test(
    'physical reservation prevents overselling, cancellation and expiry release once',
    () async {
      final aid = await address();
      final first = await create('physical', 'one', address: aid);
      final id = first['id'];
      await expectLater(
        create('physical', 'two', account: DemoAccounts.headTeacher),
        rejected(409),
      );
      await call('POST', '/app/market/orders/$id/cancel');
      await call('POST', '/app/market/orders/$id/cancel');
      expect(DemoStore.list('creative:listings:v1', () => []).last['stock'], 1);
      final second = await create('physical', 'three', address: aid);
      final raw = DemoStore.list('creative:orders:v1', () => []).last;
      raw['expiresAt'] = '2000-01-01 10:00:00';
      expect(
        (await call('GET', '/app/market/orders/${second['id']}'))['status'],
        'expired',
      );
      await expectLater(
        call('POST', '/app/market/orders/${second['id']}/pay'),
        rejected(409),
      );
      expect(DemoStore.list('creative:listings:v1', () => []).last['stock'], 1);
    },
  );

  test(
    'physical fulfillment keeps address snapshot and supports authorized return/refund',
    () async {
      final aid = await address();
      final created = await create('physical', 'ship', address: aid);
      final id = created['id'];
      await call(
        'POST',
        '/app/market/addresses',
        body: {
          'id': aid,
          'name': '林小雨',
          'phone': '13809310001',
          'detail': '示范画室城西校区二号楼前台',
        },
      );
      await call('POST', '/app/market/orders/$id/pay');
      await expectLater(
        call('POST', '/app/market/orders/$id/receive'),
        rejected(409),
      );
      final shipment = {'carrier': '演示快递', 'tracking': 'DEMO20261115001'};
      await expectLater(
        call('POST', '/app/market/orders/$id/ship', body: shipment),
        rejected(403),
      );
      final shipped = await call(
        'POST',
        '/app/market/orders/$id/ship',
        account: DemoAccounts.teacher,
        body: shipment,
      );
      expect(shipped['address']['detail'], contains('城东'));
      expect(shipped['status'], 'shipped');
      await call('POST', '/app/market/orders/$id/receive');
      await call(
        'POST',
        '/app/market/orders/$id/refund',
        body: {'reason': '收到作品后发现边角运输受损'},
      );
      await call(
        'POST',
        '/app/market/orders/$id/refund-decision',
        account: DemoAccounts.teacher,
        body: {
          'approve': true,
          'note': '同意退货，收到原作后处理退款',
          'returnAddress': '示范画室城东校区前台，李静，13809310002',
        },
      );
      await expectLater(
        call(
          'POST',
          '/app/market/orders/$id/return-received',
          account: DemoAccounts.teacher,
        ),
        rejected(409),
      );
      await call('POST', '/app/market/orders/$id/return', body: shipment);
      final refunded = await call(
        'POST',
        '/app/market/orders/$id/return-received',
        account: DemoAccounts.teacher,
      );
      expect(refunded['status'], 'refunded');
      await call(
        'POST',
        '/app/market/orders/$id/return-received',
        account: DemoAccounts.teacher,
      );
      final listing = DemoStore.list('creative:listings:v1', () => []).last;
      expect(listing['stock'], 1);
      expect(listing['status'], 'withdrawn');
    },
  );

  test(
    'draft, review, publication, withdrawal and reports enforce ownership',
    () async {
      final body = {
        'title': '几何体局部练习',
        'description': '通过明暗交界线和反光描绘几何体的形体转折。',
        'subject': '素描',
        'kind': 'digital',
        'license': 'teaching',
        'priceCents': 1800,
        'imageId': 'sample-image',
        'deliveryIds': ['sample-image'],
        'rightsConfirmed': true,
        'submit': false,
      };
      final draft = await call('POST', '/app/market/listings', body: body);
      final id = draft['id'];
      expect(draft['status'], 'draft');
      await expectLater(
        call('GET', '/app/market/listings/$id', account: DemoAccounts.teacher),
        rejected(404),
      );
      await call('POST', '/app/market/listings/$id/submit');
      await expectLater(
        call('POST', '/app/market/listings/$id/save', body: body),
        rejected(409),
      );
      await expectLater(
        call(
          'POST',
          '/app/market/listings/$id/moderate',
          body: {'approve': true, 'note': '已检查演示内容与发布资料'},
        ),
        rejected(403),
      );
      final published = await call(
        'POST',
        '/app/market/listings/$id/moderate',
        account: DemoAccounts.principal,
        body: {'approve': true, 'note': '已检查演示内容与发布资料'},
      );
      expect(published['status'], 'published');
      final report = await call(
        'POST',
        '/app/market/listings/$id/report',
        account: DemoAccounts.teacher,
        body: {'reason': '希望核实作品发布者的授权范围'},
      );
      await call(
        'POST',
        '/app/market/cases/${report['id']}/resolve',
        account: DemoAccounts.principal,
        body: {'uphold': true, 'note': '先下架作品，请作者补充权属材料'},
      );
      expect(
        (await call('GET', '/app/market/listings/$id'))['status'],
        'withdrawn',
      );
    },
  );

  test(
    'digital refund and dispute revoke delivery and cannot refund twice',
    () async {
      final id = (await create('digital', 'dispute'))['id'];
      await call('POST', '/app/market/orders/$id/pay');
      await call(
        'POST',
        '/app/market/orders/$id/refund',
        body: {'reason': '交付资料与作品说明不一致'},
      );
      await expectLater(
        call('GET', '/app/market/orders/$id/delivery'),
        rejected(403),
      );
      await call(
        'POST',
        '/app/market/orders/$id/refund-decision',
        account: DemoAccounts.teacher,
        body: {'approve': false, 'note': '请补充具体不一致的页面说明'},
      );
      await call(
        'POST',
        '/app/market/orders/$id/dispute',
        body: {'reason': '已说明缺少文件，请平台核实交付内容'},
      );
      final cases = DemoStore.list('market:cases:v1', () => []);
      final caseId = cases.single['id'];
      await call(
        'POST',
        '/app/market/cases/$caseId/resolve',
        account: DemoAccounts.principal,
        body: {'uphold': true, 'note': '核对交付记录后同意本次演示退款'},
      );
      expect(
        (await call('GET', '/app/market/orders/$id'))['status'],
        'refunded',
      );
      await expectLater(
        call('GET', '/app/market/orders/$id/delivery'),
        rejected(403),
      );
      await expectLater(
        call(
          'POST',
          '/app/market/cases/$caseId/resolve',
          account: DemoAccounts.principal,
          body: {'uphold': true, 'note': '再次请求同一笔退款'},
        ),
        rejected(409),
      );
    },
  );
  test(
    'uploaded PDF delivery keeps its type even when the URL has no extension',
    () async {
      final listing = await call(
        'POST',
        '/app/market/listings',
        account: DemoAccounts.teacher,
        body: {
          'title': '明暗结构学习资料',
          'subject': '素描',
          'description': '包含几何体与明暗交界线的练习说明和示例。',
          'kind': 'digital',
          'priceCents': 1800,
          'license': 'study',
          'imageId': 'sample-image',
          'deliveryIds': ['owned-pdf'],
          'rightsConfirmed': true,
          'submit': true,
        },
      );
      await call(
        'POST',
        '/app/market/listings/${listing['id']}/moderate',
        account: DemoAccounts.principal,
        body: {'approve': true, 'note': '资料与权属说明已核对'},
      );
      await expectLater(
        call(
          'POST',
          '/app/market/orders',
          body: {
            'listingId': listing['id'],
            'idempotencyKey': 'stale-quote',
            'expectedPriceCents': 1,
            'expectedTotalCents': 1,
            'termsAccepted': true,
          },
        ),
        rejected(409),
      );
      final order = await call(
        'POST',
        '/app/market/orders',
        body: {
          'listingId': listing['id'],
          'idempotencyKey': 'pdf-checkout',
          'expectedPriceCents': 1800,
          'expectedTotalCents': 1800,
          'termsAccepted': true,
        },
      );
      await call('POST', '/app/market/orders/${order['id']}/pay');
      final delivery = await call(
        'GET',
        '/app/market/orders/${order['id']}/delivery',
      );
      expect(delivery['files'].single['kind'], 'pdf');
      expect(delivery['terms'], contains('个人欣赏'));
      expect(order['listing'].containsKey('deliveryKinds'), false);
    },
  );
}
