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

/// 复核状态：`NONE` / `IN_REVIEW`（复核中）/ `DONE`（已复核）。
enum ArtworkLeadStatus {
  none('NONE', ''),
  inReview('IN_REVIEW', '复核中'),
  done('DONE', '已复核');

  const ArtworkLeadStatus(this.code, this.label);

  final String code;
  final String label;

  static ArtworkLeadStatus parse(Object? raw) {
    switch (_str(raw).toUpperCase()) {
      case 'IN_REVIEW':
        return ArtworkLeadStatus.inReview;
      case 'DONE':
        return ArtworkLeadStatus.done;
      default:
        return ArtworkLeadStatus.none;
    }
  }
}

@immutable
class ArtworkStats {
  const ArtworkStats({
    this.total = 0,
    this.reviewed = 0,
    this.pending = 0,
    this.overdue = 0,
  });

  factory ArtworkStats.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkStats(
      total: _int(json['total']),
      reviewed: _int(json['reviewed']),
      pending: _int(json['pending']),
      overdue: _int(json['overdue']),
    );
  }

  final int total;
  final int reviewed;
  final int pending;
  final int overdue;
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
    this.practiceSource = const {},
    this.reviewed = false,
    this.leadStatus = ArtworkLeadStatus.none,
    this.version = 1,
    this.versionCount = 1,
    this.rootId = '',
    this.taskId = '',
    this.taskTitle = '',
    this.teacherId = '',
    this.teacherName = '',
    this.hasPrincipalComment = false,
    this.featured = false,
    this.overdue = false,
    this.leadOverdue = false,
    this.leadReasons = const <String>[],
    this.leadEnteredTime = '',
    this.imageCount = 0,
    this.teacherCount = 0,
    this.reviewedCount = 0,
    this.coverUrl = '',
    this.finalScore,
    this.maxScore = 100,
    this.archiveId = '',
    this.studentNo = '',
    this.studentName = '',
    this.organizationName = '',
    this.className = '',
    this.avatarUrl = '',
    this.myReviewed = false,
  });

  factory ArtworkSummary.fromJson(Object? raw) {
    final json = _map(raw);
    final root = _str(json['rootId']);
    final id = _str(json['id']);
    final reasons = json['leadReasons'];
    return ArtworkSummary(
      id: id,
      title: _str(json['title']),
      subject: _str(json['subject']),
      drawingDate: _str(json['drawingDate']),
      createTime: _str(json['createTime']),
      description: _str(json['description']),
      practiceSource: _map(
        json['practiceSource'],
      ).map((k, v) => MapEntry(k, _str(v))),
      reviewed: _str(json['status']).toUpperCase() == 'REVIEWED',
      leadStatus: ArtworkLeadStatus.parse(json['leadStatus']),
      version: _int(json['version']) < 1 ? 1 : _int(json['version']),
      versionCount: _int(json['versionCount']) < 1
          ? 1
          : _int(json['versionCount']),
      rootId: root.isEmpty ? id : root,
      taskId: _str(json['taskId']),
      taskTitle: _str(json['taskTitle']),
      teacherId: _str(json['teacherId']),
      teacherName: _str(json['teacherName']),
      hasPrincipalComment: _bool(json['hasPrincipalComment']),
      featured: _bool(json['featured']),
      overdue: _bool(json['overdue']),
      leadOverdue: _bool(json['leadOverdue']),
      leadReasons: reasons is List
          ? <String>[
              for (final item in reasons)
                if (_str(item).isNotEmpty) _str(item).toUpperCase(),
            ]
          : const <String>[],
      leadEnteredTime: _str(json['enteredTime']),
      imageCount: _int(json['imageCount']),
      teacherCount: _int(json['teacherCount']),
      reviewedCount: _int(json['reviewedCount']),
      coverUrl: _str(json['coverUrl']),
      finalScore: _num(json['finalScore']),
      maxScore: _num(json['maxScore']) ?? 100,
      archiveId: _str(json['archiveId']),
      studentNo: _str(json['studentNo']),
      studentName: _str(json['studentName']),
      organizationName: _str(json['organizationName']),
      className: _str(json['className']),
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
  final Map<String, String> practiceSource;

  /// 责任老师已点评（`status == REVIEWED`）。
  final bool reviewed;
  final ArtworkLeadStatus leadStatus;
  final int version;
  final int versionCount;
  final String rootId;
  final String taskId;
  final String taskTitle;
  final String teacherId;
  final String teacherName;
  final bool hasPrincipalComment;
  final bool featured;
  final bool overdue;
  final bool leadOverdue;

  /// 进入复核池的原因（`REQUESTED / SCORE_ANOMALY / BRIEF / SPOT_CHECK`），
  /// 只有复核池列表返回。
  final List<String> leadReasons;

  /// 进入复核池的时间 `yyyy-MM-dd HH:mm:ss`，只有复核池列表返回。
  final String leadEnteredTime;
  final int imageCount;
  final int teacherCount;
  final int reviewedCount;
  final String coverUrl;
  final double? finalScore;
  final double maxScore;

  /// 学生档案 id：只用于接口查询，界面上对老师显示 [studentNo]。
  final String archiveId;

  /// 画室学号（与学生名册一致）。
  final String studentNo;
  final String studentName;
  final String organizationName;
  final String className;
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
    this.dimension = '',
    this.usageCount = 0,
  });

  factory ArtworkTag.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkTag(
      id: _str(json['id']),
      name: _str(json['name']),
      explanation: _str(json['explanation']),
      color: _str(json['color']),
      dimension: _str(json['dimension']),
      usageCount: _int(json['usageCount']),
    );
  }

  final String id;
  final String name;
  final String explanation;

  /// `#RRGGBB`。
  final String color;

  /// 所属分项 key，可空。
  final String dimension;
  final int usageCount;
}

@immutable
class ArtworkDimensionDef {
  const ArtworkDimensionDef({required this.key, required this.name});

  factory ArtworkDimensionDef.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkDimensionDef(
      key: _str(json['key']),
      name: _str(json['name']),
    );
  }

  final String key;
  final String name;
}

@immutable
class ArtworkTimelineEvent {
  const ArtworkTimelineEvent({
    required this.role,
    required this.type,
    required this.name,
    this.time = '',
    this.content = '',
    this.score,
    this.fromScore,
    this.toScore,
  });

  factory ArtworkTimelineEvent.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkTimelineEvent(
      role: _str(json['role']),
      type: _str(json['type']),
      name: _str(json['name']),
      time: _str(json['time']),
      content: _str(json['content']),
      score: _num(json['score']),
      fromScore: _num(json['fromScore']),
      toScore: _num(json['toScore']),
    );
  }

  final String role;
  final String type;
  final String name;
  final String time;
  final String content;
  final double? score;
  final double? fromScore;
  final double? toScore;
}

@immutable
class ArtworkLeadReview {
  const ArtworkLeadReview({
    this.reasons = const <String>[],
    this.enteredTime = '',
    this.leaderId = '',
    this.leaderName = '',
    this.action = '',
    this.score,
    this.reason = '',
    this.content = '',
    this.qualityStars = 0,
    this.qualityNote = '',
    this.time = '',
  });

  factory ArtworkLeadReview.fromJson(Object? raw) {
    final json = _map(raw);
    final reasons = json['reasons'];
    return ArtworkLeadReview(
      reasons: reasons is List
          ? <String>[for (final item in reasons) _str(item)]
          : const <String>[],
      enteredTime: _str(json['enteredTime']),
      leaderId: _str(json['leaderId']),
      leaderName: _str(json['leaderName']),
      action: _str(json['action']).toUpperCase(),
      score: _num(json['score']),
      reason: _str(json['reason']),
      content: _str(json['content']),
      qualityStars: _int(json['qualityStars']),
      qualityNote: _str(json['qualityNote']),
      time: _str(json['time']),
    );
  }

  final List<String> reasons;
  final String enteredTime;
  final String leaderId;
  final String leaderName;
  final String action;
  final double? score;
  final String reason;
  final String content;
  final int qualityStars;
  final String qualityNote;
  final String time;
}

@immutable
class ArtworkPrincipalComment {
  const ArtworkPrincipalComment({
    required this.id,
    required this.name,
    required this.content,
    this.time = '',
    this.score,
  });

  factory ArtworkPrincipalComment.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkPrincipalComment(
      id: _str(json['id']),
      name: _str(json['name']),
      content: _str(json['content']),
      time: _str(json['time']),
      score: _num(json['score']),
    );
  }

  final String id;
  final String name;
  final String content;
  final String time;
  final double? score;
}

@immutable
class ArtworkTask {
  const ArtworkTask({
    required this.id,
    required this.title,
    this.subject = '',
    this.requirement = '',
    this.dueTime = '',
    this.createTime = '',
    this.teacherId = '',
    this.teacherName = '',
    this.status = '',
    this.classIds = const <String>[],
    this.referenceWorkId = '',
  });

  factory ArtworkTask.fromJson(Object? raw) {
    final json = _map(raw);
    final classes = json['classIds'];
    return ArtworkTask(
      id: _str(json['id']),
      title: _str(json['title']),
      subject: _str(json['subject']),
      requirement: _str(json['requirement']),
      dueTime: _str(json['dueTime']),
      createTime: _str(json['createTime']),
      teacherId: _str(json['teacherId']),
      teacherName: _str(json['teacherName']),
      status: _str(json['status']).toUpperCase(),
      referenceWorkId: _str(json['referenceWorkId']),
      classIds: classes is List
          ? <String>[for (final item in classes) _str(item)]
          : const <String>[],
    );
  }

  final String id;
  final String title;
  final String subject;
  final String requirement;
  final String dueTime;
  final String createTime;
  final String teacherId;
  final String teacherName;
  final String status;
  final List<String> classIds;
  final String referenceWorkId;
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
    this.dimensions = const <String, int>{},
    this.requestLeadReview = false,
    this.tags = const <ArtworkTag>[],
    this.tagResolutions = const <({String tag, bool resolved})>[],
    this.annotations = const <AnnotationStroke>[],
    this.voiceUrl = '',
    this.voiceSeconds = 0,
  });

  factory ArtworkReview.fromJson(Object? raw) {
    final json = _map(raw);
    final dims = <String, int>{};
    final rawDims = json['dimensions'];
    if (rawDims is Map) {
      rawDims.forEach((key, value) {
        final level = _int(value);
        if (level >= 1 && level <= 5) {
          dims[key.toString()] = level;
        }
      });
    }
    final resolutions = <({String tag, bool resolved})>[];
    for (final item in _maps(json['tagResolutions'])) {
      final tag = _str(item['tag']);
      if (tag.isEmpty) {
        continue;
      }
      resolutions.add((tag: tag, resolved: _bool(item['resolved'])));
    }
    final voice = _str(json['voiceUrl']);
    return ArtworkReview(
      teacherId: _str(json['teacherId']),
      teacherName: _str(json['teacherName']),
      mine: _bool(json['mine']),
      reviewed: _bool(json['reviewed']),
      score: _num(json['score']),
      maxScore: _num(json['maxScore']) ?? 100,
      content: _str(json['content']),
      reviewedTime: _str(json['reviewedTime']),
      dimensions: dims,
      requestLeadReview: _bool(json['requestLeadReview']),
      tags: _maps(json['tags']).map(ArtworkTag.fromJson).toList(),
      tagResolutions: resolutions,
      annotations: _maps(
        json['annotations'],
      ).map(AnnotationStroke.fromJson).toList(),
      voiceUrl: voice.isEmpty ? _str(json['voiceRef']) : voice,
      voiceSeconds: _int(json['voiceSeconds']),
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
  final Map<String, int> dimensions;
  final bool requestLeadReview;
  final List<ArtworkTag> tags;
  final List<({String tag, bool resolved})> tagResolutions;
  final List<AnnotationStroke> annotations;

  /// 语音评语：上传接口返回的相对路径或完整地址（接口字段 `voiceUrl` / `voiceRef`），
  /// 没有时为空。
  final String voiceUrl;

  /// 语音评语时长（秒）。
  final int voiceSeconds;

  /// 点评内容对当前查看者可见。
  bool get visible =>
      reviewed &&
      (score != null ||
          content.isNotEmpty ||
          tags.isNotEmpty ||
          voiceUrl.isNotEmpty);
}

@immutable
class ArtworkDetail {
  const ArtworkDetail({
    required this.work,
    this.requiredFullScore,
    this.teachers = const <ArtworkTeacher>[],
    this.images = const <ArtworkImage>[],
    this.reviews = const <ArtworkReview>[],
    this.review,
    this.leadReview,
    this.principalComments = const <ArtworkPrincipalComment>[],
    this.timeline = const <ArtworkTimelineEvent>[],
    this.versions = const <ArtworkSummary>[],
    this.dimensions = const <ArtworkDimensionDef>[],
    this.canReview = false,
    this.canSupplement = false,
    this.canComment = false,
    this.canFeature = false,
    this.seesLeadReasons = false,
    this.seesQuality = false,
    this.isOwner = false,
    this.canLeadReview = false,
  });

  factory ArtworkDetail.fromJson(Object? raw) {
    final json = _map(raw);
    final work = _map(json['work']);
    var reviews = _maps(json['reviews']).map(ArtworkReview.fromJson).toList();
    final single = json['review'] == null
        ? null
        : ArtworkReview.fromJson(json['review']);
    if (reviews.isEmpty && single != null) {
      reviews = <ArtworkReview>[single];
    }
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
    final access = _map(json['access']);
    return ArtworkDetail(
      work: ArtworkSummary.fromJson(work),
      requiredFullScore: _num(work['requiredFullScore']),
      teachers: teachers,
      images: _maps(json['images']).map(ArtworkImage.fromJson).toList(),
      reviews: reviews,
      review: single ?? (reviews.isEmpty ? null : reviews.first),
      leadReview: json['leadReview'] == null
          ? null
          : ArtworkLeadReview.fromJson(json['leadReview']),
      principalComments: _maps(
        json['principalComments'],
      ).map(ArtworkPrincipalComment.fromJson).toList(),
      timeline: _maps(
        json['timeline'],
      ).map(ArtworkTimelineEvent.fromJson).toList(),
      versions: _maps(json['versions']).map(ArtworkSummary.fromJson).toList(),
      dimensions: _maps(
        json['dimensions'],
      ).map(ArtworkDimensionDef.fromJson).toList(),
      canReview: _bool(access['canReview']),
      canSupplement: _bool(access['canSupplement']),
      canComment: _bool(access['canComment']),
      canFeature: _bool(access['canFeature']),
      seesLeadReasons: _bool(access['seesLeadReasons']),
      seesQuality: _bool(access['seesQuality']),
      isOwner: _bool(access['owner']),
      canLeadReview: _bool(access['canLeadReview']),
    );
  }

  final ArtworkSummary work;

  /// 其他老师已打分时必须沿用的满分；为空表示可自定满分。
  final double? requiredFullScore;
  final List<ArtworkTeacher> teachers;
  final List<ArtworkImage> images;
  final List<ArtworkReview> reviews;

  /// 责任老师点评（点评链新字段）；旧界面可继续用 [reviews]。
  final ArtworkReview? review;
  final ArtworkLeadReview? leadReview;
  final List<ArtworkPrincipalComment> principalComments;
  final List<ArtworkTimelineEvent> timeline;
  final List<ArtworkSummary> versions;
  final List<ArtworkDimensionDef> dimensions;

  /// 以下几项来自接口的 `access`：当前查看者能做什么、能看到什么。
  ///
  /// 责任老师可以点评。
  final bool canReview;

  /// 非责任的美术老师可以补充点评（不计分）。
  final bool canSupplement;

  /// 校长可以点评、推优。
  final bool canComment;
  final bool canFeature;

  /// 能看到进入复核的原因、点评质量星级与意见。
  final bool seesLeadReasons;
  final bool seesQuality;
  final bool isOwner;
  final bool canLeadReview;

  ArtworkReview? get myReview {
    for (final item in reviews) {
      if (item.mine) {
        return item;
      }
    }
    return null;
  }

  List<ArtworkReview> get otherReviews =>
      reviews.where((item) => !item.mine).toList();
}

@immutable
class ArtworkInsightTag {
  const ArtworkInsightTag({
    required this.name,
    required this.color,
    required this.count,
    this.explanation = '',
    this.positive = false,
    this.resolvedCount = 0,
    this.latestResolved = false,
    this.advice = '',
    this.keyword = '',
    this.evidence = const [],
  });

  factory ArtworkInsightTag.fromJson(Object? raw) {
    final json = _map(raw);
    return ArtworkInsightTag(
      name: _str(json['name']),
      color: _str(json['color']),
      count: _int(json['count']),
      explanation: _str(json['explanation']),
      positive: _bool(json['positive']),
      resolvedCount: _int(json['resolvedCount']),
      latestResolved: _bool(json['latestResolved']),
      advice: _str(json['advice']),
      keyword: _str(json['keyword']),
      evidence: _maps(
        json['evidence'],
      ).map(ArtworkReviewEvidence.fromJson).toList(),
    );
  }

  final String name;
  final String color;
  final int count;
  final String explanation;

  /// 表扬类标签（如「细节出彩」），不计入问题建议。
  final bool positive;
  final int resolvedCount;
  final bool latestResolved;
  final String advice, keyword;
  final List<ArtworkReviewEvidence> evidence;
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
    this.streakDays = 0,
    this.recentSubmitCount = 0,
    this.resolveRate,
    this.dimensions = const <ArtworkDimensionLevels>[],
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
      streakDays: _int(json['streakDays']),
      recentSubmitCount: _int(json['recentSubmitCount']),
      resolveRate: _num(json['resolveRate']),
      dimensions: _maps(
        json['dimensionLevels'],
      ).map(ArtworkDimensionLevels.fromJson).toList(),
    );
  }

  final List<ArtworkInsightTag> topTags;
  final int reviewedCount;
  final double? averageScore;
  final String bestSubject;
  final String weakestSubject;
  final List<ArtworkSuggestion> suggestions;
  final int streakDays;
  final int recentSubmitCount;
  final double? resolveRate;
  final List<ArtworkDimensionLevels> dimensions;
}

class ArtworkDimensionLevels {
  const ArtworkDimensionLevels({
    required this.subject,
    required this.sampleCount,
    required this.items,
    this.history = const [],
    this.reviewCount = 0,
    this.fromDate = '',
    this.toDate = '',
    this.issues = const [],
    this.sourceWorks = const [],
  });

  factory ArtworkDimensionLevels.fromJson(Map<String, dynamic> json) {
    return ArtworkDimensionLevels(
      subject: _str(json['subject']),
      reviewCount: _int(json['reviewCount']),
      fromDate: _str(json['fromDate']),
      toDate: _str(json['toDate']),
      issues: _maps(json['issues']).map(ArtworkInsightTag.fromJson).toList(),
      sourceWorks: _maps(json['history'])
          .map((h) => (id: _str(h['artworkId']), title: _str(h['title'])))
          .toList(),
      sampleCount: _int(json['sampleCount']),
      items: [
        for (final row in _maps(json['items']))
          (
            key: _str(row['key']),
            name: _str(row['name']),
            level: _num(row['level']),
          ),
      ],
      history: [
        for (final row in _maps(json['history']))
          (
            date: _str(row['date']),
            levels: {
              for (final entry in _map(row['levels']).entries)
                entry.key: ?_num(entry.value),
            },
          ),
      ],
    );
  }

  final String subject;
  final int sampleCount;
  final int reviewCount;
  final String fromDate, toDate;
  final List<ArtworkInsightTag> issues;
  final List<({String id, String title})> sourceWorks;
  final List<({String key, String name, double? level})> items;
  final List<({String date, Map<String, double> levels})> history;
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
    this.taskId = '',
    this.practiceSource = const {},
    this.parentId = '',
    this.teacherIds = const [],
  });

  final String title;
  final String subject;

  /// `yyyy-MM-dd`。
  final String drawingDate;
  final String description;
  final List<ArtworkDraftImage> images;
  final String taskId;
  final Map<String, String> practiceSource;
  final String parentId;
  final List<String> teacherIds;
}

/// 解析接口返回的 id（字符串或数字）。
String artworkIdOf(Object? raw) {
  if (raw is Map) {
    return _str(raw['id']);
  }
  return _str(raw);
}

class ArtworkReviewEvidence {
  const ArtworkReviewEvidence({
    required this.artworkId,
    required this.title,
    required this.teacher,
    required this.time,
    required this.comment,
    required this.resolved,
  });
  factory ArtworkReviewEvidence.fromJson(Map<String, dynamic> json) =>
      ArtworkReviewEvidence(
        artworkId: _str(json['artworkId']),
        title: _str(json['title']),
        teacher: _str(json['teacher']),
        time: _str(json['time']),
        comment: _str(json['comment']),
        resolved: _bool(json['resolved']),
      );
  final String artworkId, title, teacher, time, comment;
  final bool resolved;
}
