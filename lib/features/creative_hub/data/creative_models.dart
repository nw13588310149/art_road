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
  study('study', '个人学习使用', '可用于个人欣赏与学习参考，不包含商用、转售或再次分发权限。'),
  teaching('teaching', '教学展示使用', '可在本人授课中展示并注明作者，不包含素材转售、批量分发或著作权转让。');

  const MarketLicense(this.key, this.label, this.description);
  final String key, label, description;
  static MarketLicense parse(String value) =>
      values.firstWhere((item) => item.key == value, orElse: () => study);
}

class MarketListing {
  MarketListing.fromJson(CreativeJson json)
    : id = creativeText(json['id']),
      title = creativeText(json['title']),
      subject = creativeText(json['subject']),
      description = creativeText(json['description']),
      author = creativeText(json['author']),
      cover = creativeText(json['cover']),
      priceCents = (json['priceCents'] as num?)?.toInt() ?? 0,
      forSale = json['forSale'] == true,
      favorite = json['favorite'] == true,
      mine = json['mine'] == true,
      purchased = json['purchased'] == true,
      license = MarketLicense.parse(creativeText(json['license']));
  final String id, title, subject, description, author, cover;
  final int priceCents;
  final bool forSale, favorite, mine, purchased;
  final MarketLicense license;
  String get priceLabel =>
      forSale ? '¥${(priceCents / 100).toStringAsFixed(2)}' : '仅展示';
}

class MarketOrder {
  MarketOrder.fromJson(CreativeJson json)
    : id = creativeText(json['id']),
      time = creativeText(json['time']),
      listing = MarketListing.fromJson(creativeMap(json['listing']));
  final String id, time;
  final MarketListing listing;
}
