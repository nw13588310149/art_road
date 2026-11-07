import 'package:flutter/foundation.dart';

enum EbookSort {
  recommend('recommend', '推荐'),
  latest('latest', '最新'),
  popular('popular', '最热');

  const EbookSort(this.key, this.label);

  final String key;
  final String label;
}

@immutable
class EbookCategory {
  const EbookCategory({
    required this.key,
    required this.label,
    required this.count,
  });

  static const allKey = 'all';

  final String key;
  final String label;
  final int count;

  factory EbookCategory.fromJson(Map<dynamic, dynamic> json) {
    return EbookCategory(
      key: _str(json['key']),
      label: _str(json['label']),
      count: _toInt(json['count']),
    );
  }

  static List<EbookCategory> listFrom(Object? data) => [
    if (data is List)
      for (final item in data)
        if (item is Map) EbookCategory.fromJson(item),
  ];
}

/// 阅读进度：最近读到的页码（1 起）与更新时间。
@immutable
class EbookProgress {
  const EbookProgress({required this.page, required this.updatedAt});

  final int page;
  final String updatedAt;

  /// 没有记录或页码无效时返回 null。
  static EbookProgress? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final page = _toInt(json['page']);
    if (page < 1) {
      return null;
    }
    return EbookProgress(page: page, updatedAt: _str(json['updatedAt']));
  }

  @override
  bool operator ==(Object other) =>
      other is EbookProgress &&
      other.page == page &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(page, updatedAt);
}

@immutable
class EbookSummary {
  const EbookSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.editor,
    required this.publisher,
    required this.category,
    required this.categoryLabel,
    required this.subjects,
    required this.stage,
    required this.tags,
    required this.pageCount,
    required this.coverUrl,
    required this.intro,
    required this.featuredIntro,
    required this.publishDate,
    required this.readers,
    required this.favorite,
    required this.progress,
    this.lastActiveAt = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String editor;
  final String publisher;
  final String category;
  final String categoryLabel;

  /// 素描 / 色彩 / 速写 / 美术常识。
  final List<String> subjects;

  /// 适用阶段：基础 / 提高 / 冲刺。
  final String stage;
  final List<String> tags;
  final int pageCount;
  final String coverUrl;
  final String intro;

  /// 编辑推荐语，只有入选「编辑推荐」的书刊才有。
  final String featuredIntro;
  final String publishDate;
  final int readers;
  final bool favorite;
  final EbookProgress? progress;

  /// 书架接口返回：最近一次阅读或收藏的时间。
  final String lastActiveAt;

  bool get started => progress != null;

  bool get finished => progress != null && progress!.page >= pageCount;

  bool get reading => started && !finished;

  /// 0–1 的阅读进度。
  double get progressFraction {
    final page = progress?.page ?? 0;
    if (pageCount <= 0 || page <= 0) {
      return 0;
    }
    return (page / pageCount).clamp(0.0, 1.0);
  }

  EbookSummary copyWith({bool? favorite, EbookProgress? progress}) {
    return EbookSummary(
      id: id,
      title: title,
      subtitle: subtitle,
      editor: editor,
      publisher: publisher,
      category: category,
      categoryLabel: categoryLabel,
      subjects: subjects,
      stage: stage,
      tags: tags,
      pageCount: pageCount,
      coverUrl: coverUrl,
      intro: intro,
      featuredIntro: featuredIntro,
      publishDate: publishDate,
      readers: readers,
      favorite: favorite ?? this.favorite,
      progress: progress ?? this.progress,
      lastActiveAt: lastActiveAt,
    );
  }

  factory EbookSummary.fromJson(Map<dynamic, dynamic> json) {
    return EbookSummary(
      id: _str(json['id']),
      title: _str(json['title']),
      subtitle: _str(json['subtitle']),
      editor: _str(json['editor']),
      publisher: _str(json['publisher']),
      category: _str(json['category']),
      categoryLabel: _str(json['categoryLabel']),
      subjects: _strings(json['subjects']),
      stage: _str(json['stage']),
      tags: _strings(json['tags']),
      pageCount: _toInt(json['pageCount']),
      coverUrl: _str(json['coverUrl']),
      intro: _str(json['intro']),
      featuredIntro: _str(json['featuredIntro']),
      publishDate: _str(json['publishDate']),
      readers: _toInt(json['readers']),
      favorite: json['favorite'] == true,
      progress: EbookProgress.fromJson(json['progress']),
      lastActiveAt: _str(json['lastActiveAt']),
    );
  }

  static List<EbookSummary> listFrom(Object? raw) => [
    if (raw is List)
      for (final item in raw)
        if (item is Map) EbookSummary.fromJson(item),
  ];
}

@immutable
class EbookTocEntry {
  const EbookTocEntry({required this.title, required this.page});

  final String title;
  final int page;
}

@immutable
class EbookDetail {
  const EbookDetail({
    required this.book,
    required this.description,
    required this.toc,
    required this.related,
  });

  final EbookSummary book;
  final String description;
  final List<EbookTocEntry> toc;
  final List<EbookSummary> related;

  EbookDetail withFavorite(String id, bool favorite) {
    return EbookDetail(
      book: book.id == id ? book.copyWith(favorite: favorite) : book,
      description: description,
      toc: toc,
      related: [
        for (final item in related)
          item.id == id ? item.copyWith(favorite: favorite) : item,
      ],
    );
  }

  EbookDetail withProgress(String id, EbookProgress progress) {
    return EbookDetail(
      book: book.id == id ? book.copyWith(progress: progress) : book,
      description: description,
      toc: toc,
      related: [
        for (final item in related)
          item.id == id ? item.copyWith(progress: progress) : item,
      ],
    );
  }

  factory EbookDetail.fromJson(Map<dynamic, dynamic> json) {
    final toc = json['toc'];
    return EbookDetail(
      book: EbookSummary.fromJson(json),
      description: _str(json['description']),
      toc: [
        if (toc is List)
          for (final item in toc)
            if (item is Map && _toInt(item['page']) > 0)
              EbookTocEntry(
                title: _str(item['title']),
                page: _toInt(item['page']),
              ),
      ],
      related: EbookSummary.listFrom(json['related']),
    );
  }
}

@immutable
class EbookPage {
  const EbookPage({
    required this.page,
    required this.imageUrl,
    this.width = 720,
    this.height = 960,
  });

  final int page;
  final String imageUrl;
  final int width;
  final int height;

  double get aspectRatio => height <= 0 ? 0.75 : width / height;

  /// 兼容 `{pages: [...]}` 与直接返回列表两种形态，按页码排序。
  static List<EbookPage> listFrom(Object? data) {
    final raw = data is Map ? data['pages'] : data;
    final pages = <EbookPage>[
      if (raw is List)
        for (final item in raw)
          if (item is Map && _toInt(item['page']) > 0)
            EbookPage(
              page: _toInt(item['page']),
              imageUrl: _str(item['imageUrl']),
              width: _toInt(item['width']) > 0 ? _toInt(item['width']) : 720,
              height: _toInt(item['height']) > 0 ? _toInt(item['height']) : 960,
            ),
    ]..sort((a, b) => a.page.compareTo(b.page));
    return pages;
  }
}

/// 阅读器需要的个人状态：进度与书签。
@immutable
class EbookReading {
  const EbookReading({required this.progress, required this.bookmarks});

  final EbookProgress? progress;
  final List<int> bookmarks;

  factory EbookReading.fromJson(Object? data) {
    final map = data is Map ? data : const <String, dynamic>{};
    return EbookReading(
      progress: EbookProgress.fromJson(map),
      bookmarks: _ints(map['bookmarks']),
    );
  }
}

@immutable
class EbookListPage {
  const EbookListPage({required this.records, required this.total});

  final List<EbookSummary> records;
  final int total;

  /// 兼容标准分页结构 `{records, total}` 与直接返回列表两种形态。
  factory EbookListPage.fromJson(Object? data) {
    final records = EbookSummary.listFrom(
      data is Map ? data['records'] : data,
    );
    final total = data is Map ? _toInt(data['total']) : records.length;
    return EbookListPage(
      records: records,
      total: total < records.length ? records.length : total,
    );
  }
}

/// 我的书架：收藏与读过的书刊，按最近活动时间排列。
@immutable
class EbookShelf {
  const EbookShelf({required this.records});

  static const empty = EbookShelf(records: <EbookSummary>[]);

  final List<EbookSummary> records;

  /// 在读（未读完），最近读过的在前。
  List<EbookSummary> get reading {
    final list = records.where((b) => b.reading).toList()
      ..sort(
        (a, b) => b.progress!.updatedAt.compareTo(a.progress!.updatedAt),
      );
    return list;
  }

  List<EbookSummary> get favorites =>
      records.where((b) => b.favorite).toList();

  EbookShelf withFavorite(EbookSummary book, bool favorite) {
    final exists = records.any((b) => b.id == book.id);
    final updated = [
      if (!exists && favorite) book.copyWith(favorite: true),
      for (final b in records)
        if (b.id == book.id) b.copyWith(favorite: favorite) else b,
    ];
    return EbookShelf(
      records: [
        for (final b in updated)
          if (b.favorite || b.started) b,
      ],
    );
  }

  EbookShelf withProgress(String id, EbookProgress progress) {
    return EbookShelf(
      records: [
        for (final b in records)
          b.id == id ? b.copyWith(progress: progress) : b,
      ],
    );
  }

  factory EbookShelf.fromJson(Object? data) {
    return EbookShelf(
      records: EbookSummary.listFrom(data is Map ? data['records'] : data),
    );
  }
}

String _str(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text == 'null' ? '' : text;
}

List<String> _strings(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return [
    for (final item in value)
      if (_str(item).isNotEmpty) _str(item),
  ];
}

List<int> _ints(Object? value) {
  if (value is! List) {
    return const <int>[];
  }
  return [
    for (final item in value)
      if (_toInt(item) > 0) _toInt(item),
  ]..sort();
}

int _toInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
