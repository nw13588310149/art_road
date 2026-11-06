import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

String _str(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text == 'null' ? '' : text;
}

double? _num(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(_str(value));
}

int _int(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_str(value)) ?? 0;
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = _str(value).toLowerCase();
  return text == 'true' || text == '1';
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, v) => MapEntry(key.toString(), v))
    : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? <Map<String, dynamic>>[
        for (final item in value)
          if (item is Map) _map(item),
      ]
    : const <Map<String, dynamic>>[];

/// 作品状态筛选；后端以 `ALL / PENDING / REVIEWED` 传递。
enum ArtworkStatusFilter {
  all('ALL', '全部'),
  pending('PENDING', '待点评'),
  reviewed('REVIEWED', '已点评');

  const ArtworkStatusFilter(this.code, this.label);

  final String code;
  final String label;
}

@immutable
class ArtworkStats {
  const ArtworkStats({this.total = 0, this.reviewed = 0, this.pending = 0});

  factory ArtworkStats.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkStats(
      total: _int(json['total']),
      reviewed: _int(json['reviewed']),
      pending: _int(json['pending']),
    );
  }

  final int total;
  final int reviewed;
  final int pending;
}

/// 作品列表项；教师端额外带学生信息与「我是否已点评」。
@immutable
class ArtworkSummary {
  const ArtworkSummary({
    required this.id,
    required this.title,
    this.subject = '',
    this.drawingDate = '',
    this.createTime = '',
    this.description = '',
    this.reviewed = false,
    this.imageCount = 0,
    this.teacherCount = 0,
    this.reviewedCount = 0,
    this.coverUrl = '',
    this.finalScore,
    this.maxScore = 100,
    this.archiveId = '',
    this.studentName = '',
    this.organizationName = '',
    this.avatarUrl = '',
    this.myReviewed = false,
  });

  factory ArtworkSummary.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkSummary(
      id: _str(json['id']),
      title: _str(json['title']),
      subject: _str(json['subject']),
      drawingDate: _str(json['drawingDate']),
      createTime: _str(json['createTime']),
      description: _str(json['description']),
      reviewed: _str(json['status']).toUpperCase() == 'REVIEWED',
      imageCount: _int(json['imageCount']),
      teacherCount: _int(json['teacherCount']),
      reviewedCount: _int(json['reviewedCount']),
      coverUrl: _str(json['coverUrl']),
      finalScore: _num(json['finalScore']),
      maxScore: _num(json['maxScore']) ?? 100,
      archiveId: _str(json['archiveId']),
      studentName: _str(json['studentName']),
      organizationName: _str(json['organizationName']),
      avatarUrl: _str(json['avatarUrl']),
      myReviewed: _bool(json['myReviewed']),
    );
  }

  final String id;
  final String title;
  final String subject;

  /// 绘画日期 `yyyy-MM-dd`。
  final String drawingDate;

  /// 提交时间 `yyyy-MM-dd HH:mm:ss`。
  final String createTime;
  final String description;

  /// 全部指派老师已点评（`status == REVIEWED`）。
  final bool reviewed;
  final int imageCount;
  final int teacherCount;
  final int reviewedCount;
  final String coverUrl;
  final double? finalScore;
  final double maxScore;
  final String archiveId;
  final String studentName;
  final String organizationName;
  final String avatarUrl;
  final bool myReviewed;
}

@immutable
class ArtworkImage {
  const ArtworkImage({required this.id, required this.url});

  factory ArtworkImage.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkImage(id: _str(json['id']), url: _str(json['url']));
  }

  final String id;
  final String url;
}

@immutable
class ArtworkTag {
  const ArtworkTag({
    required this.id,
    required this.name,
    this.explanation = '',
    this.color = '#715EFE',
    this.usageCount = 0,
  });

  factory ArtworkTag.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkTag(
      id: _str(json['id']),
      name: _str(json['name']),
      explanation: _str(json['explanation']),
      color: _str(json['color']),
      usageCount: _int(json['usageCount']),
    );
  }

  final String id;
  final String name;
  final String explanation;

  /// `#RRGGBB`。
  final String color;
  final int usageCount;
}

/// 一笔批注：[points] 按图片宽高归一化到 0–1，[width] 以 600 宽的图片为基准。
@immutable
class AnnotationStroke {
  const AnnotationStroke({
    required this.color,
    required this.width,
    required this.points,
    this.imageIndex = 0,
  });

  factory AnnotationStroke.fromJson(Object? raw) {
    final json = _map(raw);
    final points = <Offset>[];
    final rawPoints = json['points'];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        if (p is List && p.length >= 2) {
          final x = _num(p[0]);
          final y = _num(p[1]);
          if (x != null && y != null) {
            points.add(Offset(x, y));
          }
        }
      }
    }
    return AnnotationStroke(
      color: _str(json['color']),
      width: _num(json['width']) ?? 4,
      points: points,
      imageIndex: _int(json['imageIndex']),
    );
  }

  final String color;
  final double width;
  final List<Offset> points;
  final int imageIndex;

  Map<String, dynamic> toJson() {
    double r4(double v) => (v * 10000).round() / 10000;
    return <String, dynamic>{
      'color': color,
      'width': width,
      'imageIndex': imageIndex,
      'points': <List<double>>[
        for (final p in points) <double>[r4(p.dx), r4(p.dy)],
      ],
    };
  }
}

@immutable
class ArtworkTeacher {
  const ArtworkTeacher({
    required this.teacherId,
    required this.teacherName,
    required this.reviewed,
  });

  factory ArtworkTeacher.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkTeacher(
      teacherId: _str(json['teacherId']),
      teacherName: _str(json['teacherName']),
      reviewed: _bool(json['reviewed']),
    );
  }

  final String teacherId;
  final String teacherName;
  final bool reviewed;
}

/// 单个老师的点评。未公开（学生端未全部点评 / 教师端自己未点评）时
/// [score]、[content]、[tags] 为空，仅 [reviewed] 表示该老师是否已点评。
@immutable
class ArtworkReview {
  const ArtworkReview({
    required this.teacherId,
    required this.teacherName,
    this.mine = false,
    this.reviewed = false,
    this.score,
    this.maxScore = 100,
    this.content = '',
    this.reviewedTime = '',
    this.tags = const <ArtworkTag>[],
    this.annotations = const <AnnotationStroke>[],
  });

  factory ArtworkReview.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkReview(
      teacherId: _str(json['teacherId']),
      teacherName: _str(json['teacherName']),
      mine: _bool(json['mine']),
      reviewed: _bool(json['reviewed']),
      score: _num(json['score']),
      maxScore: _num(json['maxScore']) ?? 100,
      content: _str(json['content']),
      reviewedTime: _str(json['reviewedTime']),
      tags: _maps(json['tags']).map(ArtworkTag.fromJson).toList(),
      annotations: _maps(
        json['annotations'],
      ).map(AnnotationStroke.fromJson).toList(),
    );
  }

  final String teacherId;
  final String teacherName;
  final bool mine;
  final bool reviewed;
  final double? score;
  final double maxScore;
  final String content;
  final String reviewedTime;
  final List<ArtworkTag> tags;
  final List<AnnotationStroke> annotations;

  /// 点评内容对当前查看者可见。
  bool get visible =>
      reviewed && (score != null || content.isNotEmpty || tags.isNotEmpty);
}

@immutable
class ArtworkDetail {
  const ArtworkDetail({
    required this.work,
    this.requiredFullScore,
    this.teachers = const <ArtworkTeacher>[],
    this.images = const <ArtworkImage>[],
    this.reviews = const <ArtworkReview>[],
  });

  factory ArtworkDetail.fromJson(Object? raw) {
    final json = _map(raw);
    final work = _map(json['work']);
    final reviews = _maps(json['reviews']).map(ArtworkReview.fromJson).toList();
    final teachers = work['teachers'] is List
        ? _maps(work['teachers']).map(ArtworkTeacher.fromJson).toList()
        : <ArtworkTeacher>[
            for (final r in reviews)
              ArtworkTeacher(
                teacherId: r.teacherId,
                teacherName: r.teacherName,
                reviewed: r.reviewed,
              ),
          ];
    return ArtworkDetail(
      work: ArtworkSummary.fromJson(work),
      requiredFullScore: _num(work['requiredFullScore']),
      teachers: teachers,
      images: _maps(json['images']).map(ArtworkImage.fromJson).toList(),
      reviews: reviews,
    );
  }

  final ArtworkSummary work;

  /// 其他老师已打分时必须沿用的满分；为空表示可自定满分。
  final double? requiredFullScore;
  final List<ArtworkTeacher> teachers;
  final List<ArtworkImage> images;
  final List<ArtworkReview> reviews;

  ArtworkReview? get myReview {
    for (final review in reviews) {
      if (review.mine) {
        return review;
      }
    }
    return null;
  }

  List<ArtworkReview> get otherReviews =>
      reviews.where((review) => !review.mine).toList();
}

@immutable
class ArtworkInsightTag {
  const ArtworkInsightTag({
    required this.name,
    required this.color,
    required this.count,
    this.explanation = '',
    this.positive = false,
  });

  factory ArtworkInsightTag.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkInsightTag(
      name: _str(json['name']),
      color: _str(json['color']),
      count: _int(json['count']),
      explanation: _str(json['explanation']),
      positive: _bool(json['positive']),
    );
  }

  final String name;
  final String color;
  final int count;
  final String explanation;

  /// 表扬类标签（如「细节出彩」），不计入问题建议。
  final bool positive;
}

@immutable
class ArtworkSuggestion {
  const ArtworkSuggestion({
    required this.tag,
    required this.text,
    this.color = '',
    this.count = 0,
    this.gallerySubject = '',
    this.galleryKeyword = '',
    this.tool = '',
  });

  factory ArtworkSuggestion.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkSuggestion(
      tag: _str(json['tag']),
      text: _str(json['text']),
      color: _str(json['color']),
      count: _int(json['count']),
      gallerySubject: _str(json['gallerySubject']),
      galleryKeyword: _str(json['galleryKeyword']),
      tool: _str(json['tool']),
    );
  }

  final String tag;
  final String text;
  final String color;
  final int count;
  final String gallerySubject;
  final String galleryKeyword;

  /// 画室工具箱里对应的工具名（如「镜像」「明度检查」）；为空表示不推荐工具。
  final String tool;
}

@immutable
class ArtworkInsights {
  const ArtworkInsights({
    this.topTags = const <ArtworkInsightTag>[],
    this.reviewedCount = 0,
    this.averageScore,
    this.bestSubject = '',
    this.weakestSubject = '',
    this.suggestions = const <ArtworkSuggestion>[],
  });

  factory ArtworkInsights.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkInsights(
      topTags: _maps(json['topTags']).map(ArtworkInsightTag.fromJson).toList(),
      reviewedCount: _int(json['reviewedCount']),
      averageScore: _num(json['averageScore']),
      bestSubject: _str(json['bestSubject']),
      weakestSubject: _str(json['weakestSubject']),
      suggestions: _maps(
        json['suggestions'],
      ).map(ArtworkSuggestion.fromJson).toList(),
    );
  }

  final List<ArtworkInsightTag> topTags;
  final int reviewedCount;
  final double? averageScore;
  final String bestSubject;
  final String weakestSubject;
  final List<ArtworkSuggestion> suggestions;
}

/// 分页结构 `{records, total, size, current, pages}`。
@immutable
class ArtworkPage {
  const ArtworkPage({
    this.records = const <ArtworkSummary>[],
    this.total = 0,
    this.current = 1,
    this.pages = 0,
  });

  factory ArtworkPage.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkPage(
      records: _maps(json['records']).map(ArtworkSummary.fromJson).toList(),
      total: _int(json['total']),
      current: _int(json['current']) < 1 ? 1 : _int(json['current']),
      pages: _int(json['pages']),
    );
  }

  final List<ArtworkSummary> records;
  final int total;
  final int current;
  final int pages;

  bool get hasMore => current < pages;
}

@immutable
class ReviewSaveResult {
  const ReviewSaveResult({required this.artworkId, this.nextArtworkId});

  factory ReviewSaveResult.fromJson(Object? raw, String fallbackId) {
    final json = _map(raw);
    final id = _str(json['artworkId']);
    final next = _str(json['nextArtworkId']);
    return ReviewSaveResult(
      artworkId: id.isEmpty ? fallbackId : id,
      nextArtworkId: next.isEmpty ? null : next,
    );
  }

  final String artworkId;
  final String? nextArtworkId;
}

/// 上传弹窗里选中的一张作品照片（字节，Web 与 iPad 通用）。
class ArtworkDraftImage {
  ArtworkDraftImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

@immutable
class ArtworkDraft {
  const ArtworkDraft({
    required this.title,
    required this.subject,
    required this.drawingDate,
    required this.description,
    required this.images,
  });

  final String title;
  final String subject;

  /// `yyyy-MM-dd`。
  final String drawingDate;
  final String description;
  final List<ArtworkDraftImage> images;
}

/// 解析接口返回的 id（字符串或数字）。
String artworkIdOf(Object? raw) {
  if (raw is Map) {
    return _str(raw['id']);
  }
  return _str(raw);
}
