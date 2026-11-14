import 'dart:convert';
import '../data/demo_artwork_data.dart';
import '../data/demo_artwork_store.dart';
import '../demo_backend.dart';
import '../demo_clock.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';

typedef MarketRow = Map<String, dynamic>;

/// 演示商业接口：每次变更检查身份和状态，订单保存交易时快照。
/// 真实支付、文件鉴权和物流需要服务端实现同等契约。
void registerMarketplaceFixtures(
  DemoRouter router, {
  required List<MarketRow> Function() seedListings,
  required List<MarketRow> Function() resources,
}) => _MarketplaceFixture(router, seedListings, resources).register();

class _MarketplaceFixture {
  _MarketplaceFixture(this.router, this.seedListings, this.resources);
  final DemoRouter router;
  final List<MarketRow> Function() seedListings, resources;
  static const listingsKey = 'creative:listings:v1';
  static const ordersKey = 'creative:orders:v1';
  static const casesKey = 'market:cases:v1';
  static const reviewsKey = 'market:reviews:v1';
  static const licenseTerms = {
    'study': '仅供购买者个人欣赏与学习参考，不包含商用、转售、再分发或著作权转让。',
    'teaching': '允许购买者在本人授课中展示并注明作者，不包含素材转售、批量分发或著作权转让。',
    'commercial': '允许购买者在一个商业项目中使用并注明作者，不得单独转售素材、再授权或用于商标注册；著作权仍归作者。',
  };

  String text(Object? v) => v?.toString().trim() ?? '';
  int number(Object? v) => v is num ? v.toInt() : 0;
  String now() => DemoArtworkData.fmt(DemoClock.now());
  MarketRow copy(MarketRow row) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(row)) as Map);
  List<MarketRow> rows(Object? v) => v is List
      ? v.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
      : [];
  Never fail(String message, [int code = 400]) =>
      throw DemoApiException(message, code: code);
  MarketRow find(List<MarketRow> values, String id) =>
      values.where((r) => r['id'] == id).firstOrNull ??
      fail('内容不存在或已移除，请刷新后重试', 404);
  void owner(DemoRequest req, MarketRow row) {
    if (row['ownerId'] != req.account.userId) fail('只有发布者可以操作这份作品', 403);
  }

  void admin(DemoRequest req) {
    if (!req.account.role.managesSchool) fail('需要平台管理权限', 403);
  }

  void field(MarketRow body, String key, String label, int min, int max) {
    final count = text(body[key]).runes.length;
    if (count < min || count > max) fail('$label须为 $min 至 $max 个字');
  }

  List<MarketRow> listings() {
    final list = DemoStore.list(listingsKey, seedListings);
    for (var i = 0; i < list.length; i++) {
      final row = list[i];
      row.putIfAbsent(
        'kind',
        () => row['forSale'] != true
            ? 'showcase'
            : i.isOdd
            ? 'physical'
            : 'digital',
      );
      row.putIfAbsent('status', () => 'published');
      row.putIfAbsent('stock', () => row['kind'] == 'physical' ? 1 : 9999);
      row.putIfAbsent(
        'shippingCents',
        () => row['kind'] == 'physical' ? 1200 : 0,
      );
      row.putIfAbsent('specification', () => '纸本原作 · 38 × 53 cm · 未装裱');
      row.putIfAbsent('dispatchDays', () => 3);
      row.putIfAbsent('deliveryRefs', () => [row['cover']]);
      row.putIfAbsent('license', () => 'study');
      row.putIfAbsent('rightsConfirmed', () => true);
      row.putIfAbsent(
        'licenseTerms',
        () => licenseTerms[text(row['license'])] ?? '',
      );
      row.putIfAbsent('rightsNote', () => '演示作品，由发布者确认具有发布和相应授权权限。');
      row.putIfAbsent('reviewNote', () => '');
      row.putIfAbsent('revision', () => 1);
    }
    return list;
  }

  List<MarketRow> orders() {
    final list = DemoStore.list(ordersKey, () => []);
    for (final order in list) {
      if (order['status'] == 'demo_completed') {
        final snapshot = Map<String, dynamic>.from(order['listing'] as Map);
        snapshot['kind'] = 'digital';
        snapshot['deliveryRefs'] = [snapshot['cover']];
        order.addAll({
          'status': 'completed',
          'listing': snapshot,
          'sellerId': snapshot['ownerId'],
          'totalCents': snapshot['priceCents'],
          'shippingCents': 0,
          'paidAt': order['time'],
          'events': [],
          'afterSale': null,
        });
      }
    }
    return list;
  }

  void event(MarketRow order, String label, String actor, {String note = ''}) {
    final history = rows(order['events']);
    history.add({'time': now(), 'label': label, 'actor': actor, 'note': note});
    order['events'] = history;
    order['updatedAt'] = now();
  }

  void release(MarketRow order) {
    final snapshot = order['listing'] as Map;
    if (snapshot['kind'] != 'physical' || order['stockReleased'] == true) {
      return;
    }
    final listing = listings()
        .where((r) => r['id'] == order['listingId'])
        .firstOrNull;
    if (listing != null) listing['stock'] = number(listing['stock']) + 1;
    order['stockReleased'] = true;
    DemoStore.save(listingsKey);
  }

  void expire() {
    var changed = false;
    for (final order in orders()) {
      if (order['status'] != 'pending_payment') continue;
      final deadline = DateTime.tryParse(text(order['expiresAt']));
      if (deadline != null && !DemoClock.now().isBefore(deadline)) {
        order['status'] = 'expired';
        release(order);
        event(order, '超时关闭，库存已释放', '系统');
        changed = true;
      }
    }
    if (changed) DemoStore.save(ordersKey);
  }

  MarketRow orderFor(DemoRequest req, {String? side}) {
    expire();
    final row = find(orders(), req.param('id'));
    final uid = req.account.userId;
    if (side == 'buyer' && row['buyerId'] != uid) fail('只能操作自己的购买订单', 403);
    if (side == 'seller' && row['sellerId'] != uid) fail('只能处理自己售出的订单', 403);
    if (side == null &&
        row['buyerId'] != uid &&
        row['sellerId'] != uid &&
        !req.account.role.managesSchool) {
      fail('没有权限查看此订单', 403);
    }
    return row;
  }

  MarketRow projectListing(MarketRow row, DemoRequest req) {
    final result = copy(row)
      ..remove('deliveryRefs')
      ..remove('deliveryKinds');
    final reviews = DemoStore.list(
      reviewsKey,
      () => [],
    ).where((r) => r['listingId'] == row['id']).toList();
    return {
      ...result,
      'cover': DemoMedia.url(text(row['cover'])),
      'mine': row['ownerId'] == req.account.userId,
      'favorite':
          DemoStore.map(
            'creative:favorites:${req.account.userId}',
            () => {},
          )['market/listings:${row['id']}'] ==
          true,
      'purchased': orders().any(
        (o) =>
            o['buyerId'] == req.account.userId &&
            o['listingId'] == row['id'] &&
            ['completed', 'awaiting_shipment', 'shipped'].contains(o['status']),
      ),
      'reviews': reviews,
      'reviewCount': reviews.length,
      'rating': reviews.isEmpty
          ? null
          : reviews.fold<int>(0, (n, r) => n + number(r['rating'])) /
                reviews.length,
      'deliveryCount': (row['deliveryRefs'] as List? ?? []).length,
    };
  }

  MarketRow projectOrder(MarketRow row, DemoRequest req) {
    final result = copy(row);
    final listing = Map<String, dynamic>.from(result['listing'] as Map)
      ..remove('deliveryRefs')
      ..remove('deliveryKinds');
    listing['cover'] = DemoMedia.url(text(listing['cover']));
    result['listing'] = listing;
    result['buyer'] = row['buyerId'] == req.account.userId;
    result['seller'] = row['sellerId'] == req.account.userId;
    return result;
  }

  MarketRow saveOrder(MarketRow row, DemoRequest req) {
    DemoStore.save(ordersKey);
    return projectOrder(row, req);
  }

  void register() {
    router.get('/app/market/listings', (req) {
      expire();
      return [
        for (final row in listings())
          if (row['status'] == 'published' ||
              row['ownerId'] == req.account.userId)
            projectListing(row, req),
      ];
    });
    router.get('/app/market/listings/{id}', (req) {
      final row = find(listings(), req.param('id'));
      if (row['status'] != 'published' &&
          row['ownerId'] != req.account.userId &&
          !req.account.role.managesSchool) {
        fail('作品已下架或尚未公开', 404);
      }
      return projectListing(row, req);
    });
    router.post('/app/market/listings', (req) => saveListing(req));
    router.post(
      '/app/market/listings/{id}/save',
      (req) => saveListing(req, existing: find(listings(), req.param('id'))),
    );
    for (final action in ['submit', 'withdraw', 'remove']) {
      router.post('/app/market/listings/{id}/$action', (req) {
        final row = find(listings(), req.param('id'));
        owner(req, row);
        if (action == 'submit') {
          if (row['status'] == 'published' || row['status'] == 'pending') {
            fail('作品已提交，请勿重复操作', 409);
          }
          validateListing(row);
          row['status'] = 'pending';
          row['reviewNote'] = '';
          row['submittedAt'] = now();
        } else {
          row['status'] = action == 'remove' ? 'archived' : 'withdrawn';
        }
        DemoStore.save(listingsKey);
        return projectListing(row, req);
      });
    }
    router.post('/app/market/listings/{id}/favorite', (req) {
      final row = find(listings(), req.param('id'));
      if (row['status'] != 'published') fail('作品当前不可收藏', 409);
      final key = 'creative:favorites:${req.account.userId}';
      final saved = DemoStore.map(key, () => {});
      final id = 'market/listings:${row['id']}';
      saved[id] = saved[id] != true;
      DemoStore.save(key);
      return saved[id];
    });
    registerAddresses();
    registerOrders();
    registerAfterSales();
    registerModeration();
  }

  void validateListing(MarketRow row) {
    field(row, 'title', '作品名称', 2, 40);
    field(row, 'description', '创作说明', 10, 1000);
    if (!['素描', '色彩', '速写', '美术常识'].contains(row['subject'])) fail('请选择科目');
    if (!['showcase', 'digital', 'physical'].contains(row['kind'])) {
      fail('请选择交易类型');
    }
    if (text(row['cover']).isEmpty) fail('请先选择作品图片');
    if (row['rightsConfirmed'] != true) fail('请确认拥有作品发布和相应授权权限');
    field(row, 'rightsNote', '权属说明', 0, 500);
    if (row['kind'] == 'showcase') return;
    if (row['priceCents'] is! int ||
        number(row['priceCents']) < 100 ||
        number(row['priceCents']) > 10000000) {
      fail('售价须在 1 至 100000 元之间');
    }
    if (row['kind'] == 'digital') {
      if (!['study', 'teaching', 'commercial'].contains(row['license'])) {
        fail('请选择数字使用许可');
      }
      if ((row['deliveryRefs'] as List? ?? []).isEmpty) fail('请添加数字交付文件');
    } else {
      field(row, 'specification', '实物规格', 4, 200);
      if (row['stock'] is! int ||
          number(row['stock']) < 1 ||
          number(row['stock']) > 999) {
        fail('库存须为 1 至 999 件');
      }
      if (row['shippingCents'] is! int ||
          number(row['shippingCents']) < 0 ||
          number(row['shippingCents']) > 100000) {
        fail('请填写有效运费');
      }
      if (row['dispatchDays'] is! int ||
          number(row['dispatchDays']) < 1 ||
          number(row['dispatchDays']) > 30) {
        fail('发货时限须为 1 至 30 天');
      }
    }
  }

  MarketRow saveListing(DemoRequest req, {MarketRow? existing}) {
    if (existing != null) {
      owner(req, existing);
      if (['pending', 'published'].contains(existing['status'])) {
        fail('请先撤回审核或下架后再编辑', 409);
      }
    }
    final b = req.bodyMap;
    final row = existing == null
        ? <String, dynamic>{
            'id': DemoStore.nextId('market-'),
            'ownerId': req.account.userId,
            'author': req.account.name,
            'createdAt': now(),
            'revision': 0,
            'deliveryRefs': <String>[],
            'deliveryIds': <String>[],
          }
        : copy(existing);
    for (final key in [
      'title',
      'subject',
      'description',
      'kind',
      'license',
      'specification',
      'rightsNote',
    ]) {
      row[key] = text(b[key]);
    }
    row.addAll({
      'priceCents': b['priceCents'] ?? 0,
      'shippingCents': b['shippingCents'] ?? 0,
      'stock': b['stock'] ?? 1,
      'dispatchDays': b['dispatchDays'] ?? 3,
      'rightsConfirmed': b['rightsConfirmed'] == true,
    });
    final artworkId = req.str('artworkId');
    final imageId = req.str('imageId');
    if (artworkId.isNotEmpty) {
      final work = DemoArtworkStore.workById(artworkId);
      if (work == null || !DemoArtworkData.accessOf(req.account, work).owner) {
        fail('请选择本人的作品', 403);
      }
      row['cover'] = DemoArtworkData.imagesOf(work).firstOrNull?['ref'];
      row['artworkId'] = artworkId;
      row['imageId'] = '';
      if (req.boolOf('deliverArtwork')) {
        row['deliveryRefs'] = DemoArtworkData.imagesOf(
          work,
        ).map((i) => text(i['ref'])).toList();
        row['deliveryIds'] = <String>[];
        row['deliveryKinds'] = <String, String>{};
      }
    } else if (imageId.isNotEmpty) {
      final resource = find(resources(), imageId);
      if (resource['kind'] != 'images' ||
          (resource['ownerId'] != req.account.userId &&
              resource['sample'] != true)) {
        fail('请选择自己的图片或演示素材', 403);
      }
      row['cover'] = resource['cover'];
      row['imageId'] = imageId;
      row['artworkId'] = '';
    }
    final deliveryIds = req.listOf('deliveryIds').map(text).toSet().toList();
    if (deliveryIds.length > 12) fail('最多选择 12 份交付资料');
    if (deliveryIds.isNotEmpty) {
      final refs = <String>[];
      final kinds = <String, String>{};
      for (final id in deliveryIds) {
        final resource = find(resources(), id);
        if (resource['ownerId'] != req.account.userId &&
            resource['sample'] != true) {
          fail('交付文件必须属于本人', 403);
        }
        if (resource['kind'] == 'pdf') {
          refs.add(text(resource['url']));
          kinds[text(resource['url'])] = 'pdf';
        } else {
          refs.addAll(
            (resource['pages'] as List? ?? [resource['cover']]).map(text),
          );
        }
      }
      row['deliveryRefs'] = refs;
      row['deliveryKinds'] = kinds;
      row['deliveryIds'] = deliveryIds;
    }
    row['forSale'] = row['kind'] != 'showcase';
    row['licenseTerms'] = licenseTerms[text(row['license'])] ?? '';
    row['status'] = req.boolOf('submit') ? 'pending' : 'draft';
    row['revision'] = number(row['revision']) + 1;
    row['reviewNote'] = '';
    row['updatedAt'] = now();
    field(row, 'title', '作品名称', 2, 40);
    if (req.boolOf('submit')) validateListing(row);
    if (existing == null) {
      listings().insert(0, row);
    } else {
      existing
        ..clear()
        ..addAll(row);
    }
    DemoStore.save(listingsKey);
    return projectListing(row, req);
  }

  void registerAddresses() {
    String key(DemoRequest req) => 'market:addresses:${req.account.userId}';
    List<MarketRow> addresses(DemoRequest req) =>
        DemoStore.list(key(req), () => []);
    router.get('/app/market/addresses', (req) => addresses(req));
    router.post('/app/market/addresses', (req) {
      field(req.bodyMap, 'name', '收件人', 2, 30);
      field(req.bodyMap, 'detail', '详细地址', 8, 200);
      if (!RegExp(r'^1\d{10}$').hasMatch(req.str('phone'))) {
        fail('请填写 11 位手机号码');
      }
      final list = addresses(req);
      final old = req.str('id').isEmpty ? null : find(list, req.str('id'));
      if (old == null && list.length >= 10) fail('最多保存 10 个地址，请先整理已有地址');
      final row = {
        'id': old?['id'] ?? DemoStore.nextId('address-'),
        'name': req.str('name'),
        'phone': req.str('phone'),
        'detail': req.str('detail'),
        'default': req.boolOf('default') || list.isEmpty,
      };
      if (row['default'] == true) {
        for (final item in list) {
          item['default'] = false;
        }
      }
      if (old == null) {
        list.add(row);
      } else {
        old
          ..clear()
          ..addAll(row);
      }
      DemoStore.save(key(req));
      return row;
    });
    router.post('/app/market/addresses/{id}/remove', (req) {
      final list = addresses(req);
      list.remove(find(list, req.param('id')));
      if (list.isNotEmpty && !list.any((a) => a['default'] == true)) {
        list.first['default'] = true;
      }
      DemoStore.save(key(req));
      return true;
    });
  }

  void registerOrders() {
    router.get('/app/market/orders', (req) {
      expire();
      return [
        for (final row in orders().reversed)
          if (row['buyerId'] == req.account.userId ||
              row['sellerId'] == req.account.userId)
            projectOrder(row, req),
      ];
    });
    router.get(
      '/app/market/orders/{id}',
      (req) => projectOrder(orderFor(req), req),
    );
    router.post('/app/market/orders', (req) {
      expire();
      final key = req.str('idempotencyKey');
      if (key.isEmpty || key.length > 120) fail('请重新核对订单后提交');
      final existing = orders()
          .where(
            (o) =>
                o['buyerId'] == req.account.userId &&
                o['idempotencyKey'] == key,
          )
          .firstOrNull;
      if (existing != null) {
        if (existing['listingId'] != req.str('listingId')) {
          fail('订单提交标识已被使用', 409);
        }
        return projectOrder(existing, req);
      }
      final listing = find(listings(), req.str('listingId'));
      if (listing['ownerId'] == req.account.userId) fail('不能购买自己发布的作品');
      if (listing['status'] != 'published' || listing['kind'] == 'showcase') {
        fail('作品当前不可购买，请刷新页面', 409);
      }
      if (req.bodyMap['expectedPriceCents'] != listing['priceCents']) {
        fail('作品价格已更新，请重新核对', 409);
      }
      final expectedTotal =
          number(listing['priceCents']) +
          (listing['kind'] == 'physical'
              ? number(listing['shippingCents'])
              : 0);
      if (req.bodyMap['expectedTotalCents'] != expectedTotal) {
        fail('订单金额或运费已更新，请重新核对', 409);
      }
      if (!req.boolOf('termsAccepted')) fail('请阅读并确认交易说明与许可范围');
      final physical = listing['kind'] == 'physical';
      MarketRow? address;
      if (physical) {
        if (number(listing['stock']) < 1) fail('这件作品已售罄', 409);
        address = copy(
          find(
            DemoStore.list('market:addresses:${req.account.userId}', () => []),
            req.str('addressId'),
          ),
        );
      } else {
        final prior = orders()
            .where(
              (o) =>
                  o['buyerId'] == req.account.userId &&
                  o['listingId'] == listing['id'] &&
                  [
                    'pending_payment',
                    'completed',
                    'refund_requested',
                    'return_required',
                    'return_shipped',
                  ].contains(o['status']),
            )
            .firstOrNull;
        if (prior != null) return projectOrder(prior, req);
      }
      final snapshot = copy(listing);
      final order = <String, dynamic>{
        'id': DemoStore.nextId('MYJ-'),
        'idempotencyKey': key,
        'buyerId': req.account.userId,
        'buyerName': req.account.name,
        'sellerId': listing['ownerId'],
        'listingId': listing['id'],
        'listing': snapshot,
        'time': now(),
        'status': 'pending_payment',
        'expiresAt': DemoArtworkData.fmt(
          DemoClock.now().add(const Duration(minutes: 30)),
        ),
        'shippingCents': physical ? number(listing['shippingCents']) : 0,
        'totalCents':
            number(listing['priceCents']) +
            (physical ? number(listing['shippingCents']) : 0),
        'address': address,
        'events': [],
        'afterSale': null,
        'review': null,
      };
      if (physical) listing['stock'] = number(listing['stock']) - 1;
      event(order, '订单已创建', req.account.name);
      orders().add(order);
      DemoStore.save(listingsKey);
      return saveOrder(order, req);
    });
    router.post('/app/market/orders/{id}/pay', (req) {
      final row = orderFor(req, side: 'buyer');
      if (row['paidAt'] != null) return projectOrder(row, req);
      if (row['status'] != 'pending_payment') fail('此订单已关闭，无法付款', 409);
      row['paidAt'] = now();
      row['status'] = (row['listing'] as Map)['kind'] == 'digital'
          ? 'completed'
          : 'awaiting_shipment';
      event(row, '模拟支付完成，未实际扣款', req.account.name);
      if (row['status'] == 'completed') event(row, '数字文件与许可凭证已交付', '系统');
      return saveOrder(row, req);
    });
    router.post('/app/market/orders/{id}/cancel', (req) {
      final row = orderFor(req, side: 'buyer');
      if (row['status'] == 'cancelled' || row['status'] == 'expired') {
        return projectOrder(row, req);
      }
      if (row['status'] != 'pending_payment') fail('已付款订单请通过售后申请处理', 409);
      row['status'] = 'cancelled';
      release(row);
      event(row, '买家取消订单', req.account.name);
      return saveOrder(row, req);
    });
    router.post('/app/market/orders/{id}/ship', (req) {
      final row = orderFor(req, side: 'seller');
      if (row['status'] != 'awaiting_shipment') fail('订单当前不能发货', 409);
      field(req.bodyMap, 'carrier', '承运方', 2, 30);
      field(req.bodyMap, 'tracking', '物流单号', 6, 40);
      row['shipment'] = {
        'carrier': req.str('carrier'),
        'tracking': req.str('tracking'),
        'shippedAt': now(),
      };
      row['status'] = 'shipped';
      event(
        row,
        '卖家已发货',
        req.account.name,
        note: '${req.str('carrier')} ${req.str('tracking')}',
      );
      return saveOrder(row, req);
    });
    router.post('/app/market/orders/{id}/receive', (req) {
      final row = orderFor(req, side: 'buyer');
      if (row['status'] == 'completed') return projectOrder(row, req);
      if (row['status'] != 'shipped') fail('请在卖家发货并收到作品后确认', 409);
      row['status'] = 'completed';
      event(row, '买家确认收货', req.account.name);
      return saveOrder(row, req);
    });
    router.get('/app/market/orders/{id}/delivery', (req) {
      final row = orderFor(req, side: 'buyer');
      final snapshot = row['listing'] as Map;
      if (snapshot['kind'] != 'digital' || row['status'] != 'completed') {
        fail('完成付款且无进行中售后时可查看数字交付', 403);
      }
      return {
        'orderId': row['id'],
        'license': snapshot['license'],
        'terms': snapshot['licenseTerms'],
        'title': snapshot['title'],
        'licenseNumber': 'MYJ-LICENSE-${row['id']}',
        'buyer': row['buyerName'],
        'author': snapshot['author'],
        'issuedAt': row['paidAt'],
        'files': [
          for (final ref in snapshot['deliveryRefs'] as List? ?? [])
            {
              'url': DemoMedia.url(text(ref)),
              'kind':
                  (snapshot['deliveryKinds'] as Map?)?[text(ref)] ??
                  (text(ref).toLowerCase().endsWith('.pdf') ? 'pdf' : 'image'),
            },
        ],
      };
    });
    router.post('/app/market/orders/{id}/review', (req) {
      final row = orderFor(req, side: 'buyer');
      if (row['status'] != 'completed') fail('订单完成后可以评价', 409);
      if (row['review'] != null) fail('这份订单已经评价过了', 409);
      if (req.bodyMap['rating'] is! int ||
          req.intOf('rating') < 1 ||
          req.intOf('rating') > 5) {
        fail('请选择 1 至 5 星');
      }
      field(req.bodyMap, 'content', '评价内容', 5, 500);
      final review = {
        'id': DemoStore.nextId('review-'),
        'listingId': row['listingId'],
        'orderId': row['id'],
        'name': req.account.name,
        'rating': req.intOf('rating'),
        'content': req.str('content'),
        'time': now(),
      };
      row['review'] = review;
      DemoStore.list(reviewsKey, () => []).add(review);
      DemoStore.save(reviewsKey);
      event(row, '买家已评价', req.account.name);
      return saveOrder(row, req);
    });
  }

  void registerAfterSales() {
    router.post('/app/market/orders/{id}/refund', (req) {
      final row = orderFor(req, side: 'buyer');
      if (![
        'completed',
        'awaiting_shipment',
        'shipped',
      ].contains(row['status'])) {
        fail('订单当前不能申请售后', 409);
      }
      if ((row['dispute'] as Map?)?['status'] == 'open') {
        fail('平台正在处理本次售后，请等待处理结果', 409);
      }
      field(req.bodyMap, 'reason', '售后原因', 5, 500);
      row.remove('dispute');
      row['afterSale'] = {
        'reason': req.str('reason'),
        'previousStatus': row['status'],
        'status': 'requested',
        'requestedAt': now(),
      };
      row['status'] = 'refund_requested';
      event(row, '买家申请售后', req.account.name, note: req.str('reason'));
      return saveOrder(row, req);
    });
    router.post('/app/market/orders/{id}/refund-decision', (req) {
      final row = orderFor(req, side: 'seller');
      if (row['status'] != 'refund_requested') fail('此售后已处理，请刷新', 409);
      final sale = Map<String, dynamic>.from(row['afterSale'] as Map);
      field(req.bodyMap, 'note', '处理说明', 5, 500);
      sale['decisionNote'] = req.str('note');
      if (!req.boolOf('approve')) {
        row['status'] = sale['previousStatus'];
        sale['status'] = 'rejected';
        event(row, '卖家拒绝售后申请', req.account.name, note: req.str('note'));
      } else if ((row['listing'] as Map)['kind'] == 'physical' &&
          sale['previousStatus'] != 'awaiting_shipment') {
        field(req.bodyMap, 'returnAddress', '退货地址与联系方式', 10, 300);
        row['status'] = 'return_required';
        sale['status'] = 'return_required';
        sale['returnAddress'] = req.str('returnAddress');
        event(row, '卖家同意退货，等待买家寄回', req.account.name);
      } else {
        row['afterSale'] = sale;
        refund(row, req.account.name, req.str('note'));
        return saveOrder(row, req);
      }
      row['afterSale'] = sale;
      return saveOrder(row, req);
    });
    router.post('/app/market/orders/{id}/return', (req) {
      final row = orderFor(req, side: 'buyer');
      if (row['status'] != 'return_required') fail('请等待卖家同意退货后再填写物流', 409);
      field(req.bodyMap, 'carrier', '退货承运方', 2, 30);
      field(req.bodyMap, 'tracking', '退货单号', 6, 40);
      final sale = Map<String, dynamic>.from(row['afterSale'] as Map);
      sale['carrier'] = req.str('carrier');
      sale['tracking'] = req.str('tracking');
      sale['status'] = 'return_shipped';
      row['afterSale'] = sale;
      row['status'] = 'return_shipped';
      event(row, '买家已寄回作品', req.account.name);
      return saveOrder(row, req);
    });
    router.post('/app/market/orders/{id}/return-received', (req) {
      final row = orderFor(req, side: 'seller');
      if (row['status'] == 'refunded') return projectOrder(row, req);
      if (row['status'] != 'return_shipped') fail('请在买家寄回并收到作品后确认', 409);
      refund(row, req.account.name, '卖家确认收到退货');
      return saveOrder(row, req);
    });
    router.post('/app/market/orders/{id}/dispute', (req) {
      final row = orderFor(req, side: 'buyer');
      if ((row['afterSale'] as Map?)?['status'] != 'rejected') {
        fail('卖家拒绝售后后可申请平台介入', 409);
      }
      if (row['dispute'] != null) fail('本次售后已有平台处理记录，请查看处理结果', 409);
      field(req.bodyMap, 'reason', '申请说明', 5, 500);
      final cases = DemoStore.list(casesKey, () => []);
      if (cases.any(
        (c) => c['orderId'] == row['id'] && c['status'] == 'open',
      )) {
        fail('平台正在处理中，请勿重复提交', 409);
      }
      cases.add({
        'id': DemoStore.nextId('case-'),
        'kind': 'dispute',
        'orderId': row['id'],
        'listingId': row['listingId'],
        'title': (row['listing'] as Map)['title'],
        'reporterId': req.account.userId,
        'reporter': req.account.name,
        'reason': req.str('reason'),
        'status': 'open',
        'time': now(),
      });
      row['dispute'] = {
        'status': 'open',
        'reason': req.str('reason'),
        'time': now(),
      };
      event(row, '已申请平台介入', req.account.name);
      DemoStore.save(casesKey);
      return saveOrder(row, req);
    });
  }

  void refund(MarketRow row, String actor, String note) {
    final previous = (row['afterSale'] as Map?)?['previousStatus'];
    row['status'] = 'refunded';
    row['refundedAt'] = now();
    final sale = Map<String, dynamic>.from(row['afterSale'] as Map? ?? {});
    sale['status'] = 'refunded';
    sale['decisionNote'] = note;
    row['afterSale'] = sale;
    release(row);
    if ((row['listing'] as Map)['kind'] == 'physical' &&
        previous != 'awaiting_shipment') {
      final listing = listings()
          .where((l) => l['id'] == row['listingId'])
          .firstOrNull;
      if (listing != null) listing['status'] = 'withdrawn';
      DemoStore.save(listingsKey);
    }
    event(row, '模拟退款完成，未发生资金转移', actor, note: note);
  }

  void registerModeration() {
    router.get('/app/market/moderation', (req) {
      admin(req);
      return {
        'listings': [
          for (final l in listings())
            if (l['status'] == 'pending') projectListing(l, req),
        ],
        'cases': [
          for (final c in DemoStore.list(casesKey, () => []).reversed)
            {
              ...copy(c),
              'listing': projectListing(
                find(listings(), text(c['listingId'])),
                req,
              ),
              if (c['orderId'] != null)
                'order': projectOrder(find(orders(), text(c['orderId'])), req),
            },
        ],
      };
    });
    router.post('/app/market/listings/{id}/moderate', (req) {
      admin(req);
      final row = find(listings(), req.param('id'));
      if (row['status'] != 'pending') fail('审核状态已更新，请刷新', 409);
      field(req.bodyMap, 'note', '审核说明', 5, 500);
      if (req.boolOf('approve')) validateListing(row);
      row['status'] = req.boolOf('approve') ? 'published' : 'rejected';
      row['reviewNote'] = req.str('note');
      row['reviewer'] = req.account.name;
      row['reviewedAt'] = now();
      DemoStore.save(listingsKey);
      return projectListing(row, req);
    });
    router.post('/app/market/listings/{id}/report', (req) {
      final listing = find(listings(), req.param('id'));
      if (listing['status'] != 'published') fail('只能举报公开作品', 409);
      field(req.bodyMap, 'reason', '举报说明', 5, 500);
      final cases = DemoStore.list(casesKey, () => []);
      if (cases.any(
        (c) =>
            c['listingId'] == listing['id'] &&
            c['reporterId'] == req.account.userId &&
            c['status'] == 'open',
      )) {
        fail('已收到举报，请等待处理', 409);
      }
      final row = {
        'id': DemoStore.nextId('case-'),
        'kind': 'report',
        'listingId': listing['id'],
        'title': listing['title'],
        'reporterId': req.account.userId,
        'reporter': req.account.name,
        'reason': req.str('reason'),
        'status': 'open',
        'time': now(),
      };
      cases.add(row);
      DemoStore.save(casesKey);
      return row;
    });
    router.post('/app/market/cases/{id}/resolve', (req) {
      admin(req);
      final row = find(DemoStore.list(casesKey, () => []), req.param('id'));
      if (row['status'] != 'open') fail('此事项已处理', 409);
      field(req.bodyMap, 'note', '处理说明', 5, 500);
      if (req.boolOf('uphold')) {
        if (row['kind'] == 'dispute') {
          final order = find(orders(), text(row['orderId']));
          if (order['status'] == 'refunded') fail('订单已经退款，请刷新', 409);
          refund(order, req.account.name, req.str('note'));
          DemoStore.save(ordersKey);
        } else {
          final listing = find(listings(), text(row['listingId']));
          listing['status'] = 'withdrawn';
          listing['reviewNote'] = '平台处理举报：${req.str('note')}';
          DemoStore.save(listingsKey);
        }
      }
      if (row['kind'] == 'dispute') {
        final order = find(orders(), text(row['orderId']));
        order['dispute'] = {
          'status': 'resolved',
          'note': req.str('note'),
          'upheld': req.boolOf('uphold'),
          'operator': req.account.name,
          'time': now(),
        };
        event(
          order,
          req.boolOf('uphold') ? '平台支持售后申请' : '平台未支持售后申请',
          req.account.name,
          note: req.str('note'),
        );
        DemoStore.save(ordersKey);
      }
      row.addAll({
        'status': 'resolved',
        'upheld': req.boolOf('uphold'),
        'note': req.str('note'),
        'operator': req.account.name,
        'resolvedAt': now(),
      });
      DemoStore.save(casesKey);
      return row;
    });
  }
}
