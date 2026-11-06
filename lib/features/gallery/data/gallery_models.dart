import 'package:flutter/foundation.dart';

/// 范画来源（后端以中文传递）。
abstract final class GallerySource {
  static const master = '名师范画';
  static const examTop = '联考高分卷';
  static const student = '学生优秀作品';
}

enum GallerySort {
  latest('latest', '最新'),
  score('score', '高分'),
  popular('popular', '最热');

  const GallerySort(this.key, this.label);

  final String key;
  final String label;
}

@immutable
class GalleryCategory {
  const GalleryCategory({
    required this.key,
    required this.label,
    required this.subject,
    required this.count,
  });

  static const allKey = 'all';

  final String key;
  final String label;

  /// 所属科目；「全部」「联考高分卷」等跨科分类为 null。
  final String? subject;
  final int count;

  factory GalleryCategory.fromJson(Map<dynamic, dynamic> json) {
    final subject = json['subject']?.toString().trim() ?? '';
    return GalleryCategory(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      subject: subject.isEmpty || subject == 'null' ? null : subject,
      count: _toInt(json['count']),
    );
  }
}

@immutable
class GalleryWork {
  const GalleryWork({
    required this.id,
    required this.title,
    required this.subject,
    required this.category,
    required this.categoryLabel,
    required this.source,
    required this.author,
    required this.authorTitle,
    required this.imageUrl,
    required this.aspectRatio,
    required this.score,
    required this.grade,
    required this.examName,
    required this.tags,
    required this.points,
    required this.favorite,
    required this.views,
    required this.createTime,
  });

  final String id;
  final String title;
  final String subject;
  final String category;
  final String categoryLabel;
  final String source;
  final String author;
  final String authorTitle;
  final String imageUrl;

  /// 宽 / 高，用于瀑布流占位，避免图片加载后跳动。
  final double aspectRatio;
  final double? score;
  final String grade;
  final String examName;
  final List<String> tags;
  final List<String> points;
  final bool favorite;
  final int views;
  final String createTime;

  bool get isExamPaper => source == GallerySource.examTop || score != null;

  /// 发布日期（yyyy-MM-dd）。
  String get publishDate =>
      createTime.length >= 10 ? createTime.substring(0, 10) : createTime;

  GalleryWork copyWith({bool? favorite, int? views}) {
    return GalleryWork(
      id: id,
      title: title,
      subject: subject,
      category: category,
      categoryLabel: categoryLabel,
      source: source,
      author: author,
      authorTitle: authorTitle,
      imageUrl: imageUrl,
      aspectRatio: aspectRatio,
      score: score,
      grade: grade,
      examName: examName,
      tags: tags,
      points: points,
      favorite: favorite ?? this.favorite,
      views: views ?? this.views,
      createTime: createTime,
    );
  }

  factory GalleryWork.fromJson(Map<dynamic, dynamic> json) {
    final aspect = _toDouble(json['aspectRatio']);
    return GalleryWork(
      id: json['id']?.toString() ?? '',
      title: _str(json['title']),
      subject: _str(json['subject']),
      category: _str(json['category']),
      categoryLabel: _str(json['categoryLabel']),
      source: _str(json['source']),
      author: _str(json['author']),
      authorTitle: _str(json['authorTitle']),
      imageUrl: _str(json['imageUrl']),
      aspectRatio: aspect == null || aspect <= 0 ? 0.75 : aspect,
      score: _toDouble(json['score']),
      grade: _str(json['grade']),
      examName: _str(json['examName']),
      tags: _strings(json['tags']),
      points: _strings(json['points']),
      favorite: json['favorite'] == true,
      views: _toInt(json['views']),
      createTime: _str(json['createTime']),
    );
  }
}

@immutable
class GalleryWorkDetail {
  const GalleryWorkDetail({
    required this.work,
    required this.description,
    required this.related,
  });

  final GalleryWork work;
  final String description;
  final List<GalleryWork> related;

  GalleryWorkDetail withFavorite(String id, bool favorite) {
    return GalleryWorkDetail(
      work: work.id == id ? work.copyWith(favorite: favorite) : work,
      description: description,
      related: [
        for (final item in related)
          item.id == id ? item.copyWith(favorite: favorite) : item,
      ],
    );
  }

  factory GalleryWorkDetail.fromJson(Map<dynamic, dynamic> json) {
    final related = json['related'];
    return GalleryWorkDetail(
      work: GalleryWork.fromJson(json),
      description: _str(json['description']),
      related: related is List
          ? [
              for (final item in related)
                if (item is Map) GalleryWork.fromJson(item),
            ]
          : const <GalleryWork>[],
    );
  }
}

@immutable
class GalleryWorksPage {
  const GalleryWorksPage({required this.records, required this.total});

  final List<GalleryWork> records;
  final int total;

  /// 兼容标准分页结构 `{records, total}` 与直接返回列表两种形态。
  factory GalleryWorksPage.fromJson(Object? data) {
    final raw = data is Map ? data['records'] : data;
    final records = raw is List
        ? [
            for (final item in raw)
              if (item is Map) GalleryWork.fromJson(item),
          ]
        : const <GalleryWork>[];
    final total = data is Map ? _toInt(data['total']) : records.length;
    return GalleryWorksPage(
      records: records,
      total: total < records.length ? records.length : total,
    );
  }
}

/// 「对比我的原卷」用到的本人原卷。
@immutable
class GalleryMyPaper {
  const GalleryMyPaper({required this.imageUrl, required this.examName});

  final String imageUrl;
  final String examName;
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

int _toInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _toDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}
