typedef CreativeJson = Map<String, dynamic>;

CreativeJson creativeMap(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : {};
List<CreativeJson> creativeRows(Object? raw) =>
    raw is List ? raw.map(creativeMap).toList() : [];
String creativeText(Object? raw) => raw?.toString() ?? '';

class ReadingResource {
  const ReadingResource({
    required this.id,
    required this.title,
    required this.kind,
    required this.cover,
    this.url = '',
    this.pages = const [],
    this.bookId = '',
  });
  factory ReadingResource.fromJson(CreativeJson json) => ReadingResource(
    id: creativeText(json['id']),
    title: creativeText(json['title']),
    kind: creativeText(json['kind']),
    cover: creativeText(json['cover']),
    url: creativeText(json['url']),
    bookId: creativeText(json['bookId']),
    pages: (json['pages'] as List? ?? []).map(creativeText).toList(),
  );
  final String id, title, kind, cover, url, bookId;
  final List<String> pages;
  bool get isPdf => kind == 'pdf';
  CreativeJson toJson() => {
    'id': id,
    'title': title,
    'kind': kind,
    'cover': cover,
    'url': url,
    'pages': pages,
    'bookId': bookId,
  };
}

class LearningTopic {
  LearningTopic.fromJson(CreativeJson json)
    : id = creativeText(json['id']),
      title = creativeText(json['title']),
      subject = creativeText(json['subject']),
      intro = creativeText(json['intro']),
      author = creativeText(json['author']),
      cover = creativeText(json['cover']),
      exercise = creativeText(json['exercise']),
      level = creativeText(json['level']),
      minutes = (json['minutes'] as num?)?.toInt() ?? 10,
      favorite = json['favorite'] == true,
      mine = json['mine'] == true,
      tags = (json['tags'] as List? ?? []).map(creativeText).toList(),
      resources = creativeRows(
        json['resources'],
      ).map(ReadingResource.fromJson).toList();
  final String id, title, subject, intro, author, cover, exercise, level;
  final int minutes;
  final bool favorite, mine;
  final List<String> tags;
  final List<ReadingResource> resources;
}

enum MarketLicense {
  study('study', '个人学习使用', '仅供购买者个人欣赏与学习参考，不包含商用、转售、再分发或著作权转让。'),
  teaching('teaching', '教学展示使用', '允许购买者在本人授课中展示并注明作者，不包含素材转售、批量分发或著作权转让。'),
  commercial(
    'commercial',
    '单项目商业使用',
    '允许购买者在一个商业项目中使用并注明作者，不得单独转售素材、再授权或用于商标注册；著作权仍归作者。',
  );

  const MarketLicense(this.key, this.label, this.description);
  final String key, label, description;
  static MarketLicense parse(String value) =>
      values.firstWhere((item) => item.key == value, orElse: () => study);
}

enum MarketKind {
  showcase('showcase', '仅展示'),
  digital('digital', '数字授权'),
  physical('physical', '实物作品');

  const MarketKind(this.key, this.label);
  final String key, label;
  static MarketKind parse(String value) =>
      values.firstWhere((e) => e.key == value, orElse: () => showcase);
}

enum MarketPublication {
  draft('draft', '草稿'),
  pending('pending', '审核中'),
  published('published', '已上架'),
  rejected('rejected', '需修改'),
  withdrawn('withdrawn', '已下架'),
  archived('archived', '已归档');

  const MarketPublication(this.key, this.label);
  final String key, label;
  static MarketPublication parse(String value) =>
      values.firstWhere((e) => e.key == value, orElse: () => draft);
}

enum MarketOrderStatus {
  pendingPayment('pending_payment', '待付款'),
  awaitingShipment('awaiting_shipment', '待发货'),
  shipped('shipped', '待收货'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消'),
  expired('expired', '已超时'),
  refundRequested('refund_requested', '售后处理中'),
  returnRequired('return_required', '待寄回'),
  returnShipped('return_shipped', '退货待签收'),
  refunded('refunded', '已退款'),
  unknown('unknown', '状态待更新');

  const MarketOrderStatus(this.key, this.label);
  final String key, label;
  static MarketOrderStatus parse(String value) => value == 'demo_completed'
      ? completed
      : values.firstWhere((e) => e.key == value, orElse: () => unknown);
  bool get afterSale =>
      [refundRequested, returnRequired, returnShipped].contains(this);
}

String marketMoney(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';
int marketInt(Object? value) => value is num ? value.toInt() : 0;

class MarketListing {
  MarketListing.fromJson(CreativeJson json)
    : id = creativeText(json['id']),
      title = creativeText(json['title']),
      subject = creativeText(json['subject']),
      description = creativeText(json['description']),
      author = creativeText(json['author']),
      ownerId = creativeText(json['ownerId']),
      cover = creativeText(json['cover']),
      priceCents = marketInt(json['priceCents']),
      kind = MarketKind.parse(
        creativeText(
          json['kind'] ?? (json['forSale'] == true ? 'digital' : 'showcase'),
        ),
      ),
      status = MarketPublication.parse(
        creativeText(json['status'] ?? 'published'),
      ),
      favorite = json['favorite'] == true,
      mine = json['mine'] == true,
      purchased = json['purchased'] == true,
      license = MarketLicense.parse(creativeText(json['license'])),
      licenseTerms = creativeText(json['licenseTerms']),
      stock = marketInt(json['stock']),
      shippingCents = marketInt(json['shippingCents']),
      dispatchDays = marketInt(json['dispatchDays']),
      specification = creativeText(json['specification']),
      reviewNote = creativeText(json['reviewNote']),
      rightsNote = creativeText(json['rightsNote']),
      imageId = creativeText(json['imageId']),
      artworkId = creativeText(json['artworkId']),
      deliveryIds = (json['deliveryIds'] as List? ?? [])
          .map(creativeText)
          .toList(),
      deliveryCount = marketInt(json['deliveryCount']),
      reviews = creativeRows(json['reviews']),
      createdAt = creativeText(json['createdAt']);
  final String id,
      title,
      subject,
      description,
      author,
      ownerId,
      cover,
      licenseTerms;
  final String specification,
      reviewNote,
      rightsNote,
      imageId,
      artworkId,
      createdAt;
  final int priceCents, shippingCents, stock, dispatchDays, deliveryCount;
  final MarketKind kind;
  final MarketPublication status;
  final bool favorite, mine, purchased;
  final MarketLicense license;
  final List<String> deliveryIds;
  final List<CreativeJson> reviews;
  bool get forSale => kind != MarketKind.showcase;
  bool get editable => [
    MarketPublication.draft,
    MarketPublication.rejected,
    MarketPublication.withdrawn,
  ].contains(status);
  bool get purchasable =>
      !mine &&
      forSale &&
      status == MarketPublication.published &&
      (kind != MarketKind.physical || stock > 0);
  String get priceLabel => forSale ? marketMoney(priceCents) : '仅展示';
  String get terms =>
      licenseTerms.isNotEmpty ? licenseTerms : license.description;
  int get totalCents =>
      priceCents + (kind == MarketKind.physical ? shippingCents : 0);
}

class MarketAddress {
  const MarketAddress({
    required this.id,
    required this.name,
    required this.phone,
    required this.detail,
    this.isDefault = false,
  });
  factory MarketAddress.fromJson(CreativeJson json) => MarketAddress(
    id: creativeText(json['id']),
    name: creativeText(json['name']),
    phone: creativeText(json['phone']),
    detail: creativeText(json['detail']),
    isDefault: json['default'] == true,
  );
  final String id, name, phone, detail;
  final bool isDefault;
}

class MarketOrder {
  MarketOrder.fromJson(CreativeJson json)
    : id = creativeText(json['id']),
      time = creativeText(json['time']),
      listing = MarketListing.fromJson(creativeMap(json['listing'])),
      status = MarketOrderStatus.parse(creativeText(json['status'])),
      buyer = json['buyer'] == true,
      seller = json['seller'] == true,
      buyerName = creativeText(json['buyerName']),
      totalCents = marketInt(
        json['totalCents'] ?? creativeMap(json['listing'])['priceCents'],
      ),
      shippingCents = marketInt(json['shippingCents']),
      expiresAt = creativeText(json['expiresAt']),
      paidAt = creativeText(json['paidAt']),
      updatedAt = creativeText(json['updatedAt']),
      address = json['address'] is Map
          ? MarketAddress.fromJson(creativeMap(json['address']))
          : null,
      shipment = creativeMap(json['shipment']),
      afterSale = creativeMap(json['afterSale']),
      dispute = creativeMap(json['dispute']),
      review = creativeMap(json['review']),
      events = creativeRows(json['events']);
  final String id, time, buyerName, expiresAt, paidAt, updatedAt;
  final MarketListing listing;
  final MarketOrderStatus status;
  final bool buyer, seller;
  final int totalCents, shippingCents;
  final MarketAddress? address;
  final CreativeJson shipment, afterSale, dispute, review;
  final List<CreativeJson> events;
  bool get canRefund =>
      buyer &&
      dispute['status'] != 'open' &&
      [
        MarketOrderStatus.completed,
        MarketOrderStatus.shipped,
        MarketOrderStatus.awaitingShipment,
      ].contains(status);
  bool get canReview =>
      buyer && status == MarketOrderStatus.completed && review.isEmpty;
  bool get canDispute =>
      buyer && afterSale['status'] == 'rejected' && dispute.isEmpty;
  bool get canDeliver =>
      buyer &&
      listing.kind == MarketKind.digital &&
      status == MarketOrderStatus.completed;
}

class MarketModeration {
  MarketModeration.fromJson(CreativeJson json)
    : listings = creativeRows(
        json['listings'],
      ).map(MarketListing.fromJson).toList(),
      cases = creativeRows(json['cases']);
  final List<MarketListing> listings;
  final List<CreativeJson> cases;
}

/// 金额输入按十进制字符串转分，避免浮点价格计算。
int? marketCents(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null || whole > 100000) return null;
  return whole * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
}
