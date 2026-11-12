import 'dart:typed_data';

import '../data/demo_artwork_data.dart';
import '../data/demo_marking_data.dart';
import '../demo_accounts.dart';
import '../demo_backend.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';

const _imageLimit = 9;
const _maxImageBytes = 20 * 1024 * 1024;
const _tagLimit = 50;
const _tagsPerReview = 8;
const _strokesPerImage = 200;
const _pointsPerStroke = 2000;
const _keptUploads = 60;

/// 作品档案（学生 `/app/artworks*`）与作品点评（教职 `/school/teacher/*`）演示接口。
void registerMarkingArtworkFixtures(DemoRouter marking) {
  // ── 学生：作品档案 ──────────────────────────────────────────────────
  marking.get('/app/artworks/statistics', (req) {
    final works = _worksOf(_studentIndex(req));
    final reviewed = works.where(_isReviewed).length;
    return <String, dynamic>{
      'total': works.length,
      'reviewed': reviewed,
      'pending': works.length - reviewed,
    };
  });

  marking.get('/app/artworks/insights', (req) {
    return DemoArtworkData.insightsOf(_worksOf(_studentIndex(req)));
  });

  marking.get('/app/artworks', (req) {
    final status = _statusFilter(req);
    final rows = _worksOf(_studentIndex(req))
        .where(
          (w) =>
              status == 'ALL' || DemoArtworkData.aggregate(w).status == status,
        )
        .map(_studentSummary)
        .toList();
    return demoPage(rows, req);
  });

  marking.get('/app/artworks/{id}', (req) {
    final id = req.param('id');
    final work = _worksOf(
      _studentIndex(req),
    ).where((w) => w['id'] == id).firstOrNull;
    if (work == null) {
      throw const DemoApiException('没有找到这份作品，请返回列表刷新', code: 404);
    }
    final visible = _isReviewed(work);
    return <String, dynamic>{
      'work': _studentSummary(work),
      'images': _imagesOf(work),
      'reviews': <Map<String, dynamic>>[
        for (final teacherId in DemoArtworkData.teacherIdsOf(work))
          _studentReview(work, teacherId, visible: visible),
      ],
    };
  });

  marking.post('/app/artworks/images/upload', (req) async {
    final person = _studentIndex(req);
    final file =
        req.files.where((f) => f.field == 'file').firstOrNull ??
        req.files.firstOrNull;
    if (file == null || file.bytes.isEmpty) {
      throw const DemoApiException('请选择要上传的作品照片', code: 400);
    }
    if (file.bytes.length > _maxImageBytes) {
      throw const DemoApiException('每张作品照片不能超过 20MB', code: 400);
    }
    if (!_isSupportedImage(file.bytes)) {
      throw const DemoApiException('图片格式不支持，请选择 JPG 或 PNG 照片', code: 400);
    }
    final ref = await DemoMedia.host(file.bytes, file.fileName);
    final id = DemoStore.nextId('img-');
    final uploads = _uploads();
    uploads[id] = <String, dynamic>{'ref': ref, 'personIndex': person};
    while (uploads.length > _keptUploads) {
      uploads.remove(uploads.keys.first);
    }
    DemoStore.save(DemoArtworkData.uploadsKey);
    return <String, dynamic>{'id': id, 'url': DemoMedia.url(ref)};
  });

  marking.post('/app/artworks', (req) {
    final person = _studentIndex(req);
    final body = req.bodyMap;
    final title = _text(body['title']);
    final subject = _text(body['subject']);
    final drawingDate = _text(body['drawingDate']);
    final description = _text(body['description']);
    final imageIds = req.listOf('imageIds').map((e) => e.toString()).toList();
    if (title.isEmpty || title.runes.length > 100) {
      throw const DemoApiException('请填写 1 至 100 个字的作品名称', code: 400);
    }
    if (subject.isEmpty || subject.runes.length > 50) {
      throw const DemoApiException('请填写 1 至 50 个字的作品科目', code: 400);
    }
    if (!_isPastOrToday(drawingDate)) {
      throw const DemoApiException('请选择有效的绘画日期，不能晚于今天', code: 400);
    }
    if (description.runes.length > 2000) {
      throw const DemoApiException('作品说明最多 2000 个字', code: 400);
    }
    if (imageIds.isEmpty || imageIds.length > _imageLimit) {
      throw const DemoApiException('每份作品请上传 1 至 9 张照片', code: 400);
    }
    if (imageIds.toSet().length != imageIds.length) {
      throw const DemoApiException('作品照片重复，请重新选择', code: 400);
    }
    final uploads = _uploads();
    final images = <Map<String, dynamic>>[];
    for (final imageId in imageIds) {
      final upload = uploads[imageId];
      if (upload is! Map || upload['personIndex'] != person) {
        throw const DemoApiException('部分照片已失效，请重新上传', code: 400);
      }
      images.add(<String, dynamic>{'id': imageId, 'ref': upload['ref']});
    }
    final id = DemoStore.nextId('aw-');
    _works().insert(0, <String, dynamic>{
      'id': id,
      'personIndex': person,
      'title': title,
      'subject': subject,
      'drawingDate': drawingDate,
      'createTime': _now(),
      'description': description,
      'images': images,
      'teacherIds': DemoArtworkData.teachersForNewWork(subject),
      'reviews': <Map<String, dynamic>>[],
    });
    imageIds.forEach(uploads.remove);
    DemoStore.save(DemoArtworkData.worksKey);
    DemoStore.save(DemoArtworkData.uploadsKey);
    return id;
  });

  // ── 教职：作品点评 ──────────────────────────────────────────────────
  marking.get('/school/teacher/artworks/statistics', (req) {
    final teacherId = _teacherId(req);
    final mine = _assigned(teacherId);
    final reviewed = mine
        .where((w) => DemoArtworkData.reviewOf(w, teacherId) != null)
        .length;
    return <String, dynamic>{
      'total': mine.length,
      'pending': mine.length - reviewed,
      'reviewed': reviewed,
    };
  });

  marking.get('/school/teacher/artworks', (req) {
    final teacherId = _teacherId(req);
    final status = _statusFilter(req);
    final archiveId = req.str('archiveId');
    final rows = _assigned(teacherId).where((w) {
      final mineReviewed = DemoArtworkData.reviewOf(w, teacherId) != null;
      final statusOk =
          status == 'ALL' || (status == 'REVIEWED') == mineReviewed;
      return statusOk &&
          (archiveId.isEmpty || _personOf(w)?.archiveId == archiveId);
    }).toList();
    final matched = demoSearch(rows, req.str('keyword'), (w) {
      final person = _personOf(w);
      return <String>[
        _text(w['title']),
        _text(w['subject']),
        person?.name ?? '',
        person?.organizationName ?? '',
      ];
    });
    return demoPage([
      for (final w in matched) _teacherSummary(w, teacherId),
    ], req);
  });

  marking.get('/school/teacher/artworks/{id}', (req) {
    final teacherId = _teacherId(req);
    final work = _assignedWork(teacherId, req.param('id'));
    return _teacherDetail(work, teacherId, req.account);
  });

  marking.post('/school/teacher/artworks/review', (req) {
    final teacherId = _teacherId(req);
    final body = req.bodyMap;
    final work = _assignedWork(teacherId, _text(body['artworkId']));
    final score = _optionalNumber(body['score'], '分数须为数字，最多两位小数');
    final maxScore = _optionalNumber(body['maxScore'], '满分须为大于 0 的数字') ?? 100;
    final content = _text(body['content']);
    final tagIds = req
        .listOf('tagIds')
        .map((e) => e.toString())
        .toSet()
        .toList();

    if (content.runes.length > 2000) {
      throw const DemoApiException('评语最多 2000 个字', code: 400);
    }
    if (tagIds.length > _tagsPerReview) {
      throw const DemoApiException('每份作品最多选择 8 个标签', code: 400);
    }
    if (score == null && content.isEmpty && tagIds.isEmpty) {
      throw const DemoApiException('请至少填写分数、选择标签或填写评语', code: 400);
    }
    if (maxScore <= 0 || !_twoDecimals(maxScore)) {
      throw const DemoApiException('满分须为大于 0 的数字，最多两位小数', code: 400);
    }
    if (score != null) {
      if (score < 0 || !_twoDecimals(score)) {
        throw const DemoApiException('分数须为不小于 0 的数字，最多两位小数', code: 400);
      }
      if (score > maxScore) {
        throw const DemoApiException('分数不能超过满分', code: 400);
      }
      final required = _requiredFullScore(work, teacherId);
      if (required != null && required != maxScore) {
        throw DemoApiException(
          '其他老师已按 ${_scoreText(required)} 分满分评分，满分须保持一致',
          code: 400,
        );
      }
    }

    final myTags = _tags(teacherId);
    final previous = DemoArtworkData.reviewOf(work, teacherId);
    final previousTags = previous == null
        ? const <Map<String, dynamic>>[]
        : DemoArtworkData.tagsOf(previous);
    final applied = <Map<String, dynamic>>[];
    for (final id in tagIds) {
      final tag =
          myTags.where((t) => t['id'] == id).firstOrNull ??
          previousTags.where((t) => t['id'] == id).firstOrNull;
      if (tag == null) {
        throw const DemoApiException('部分标签已被删除，请重新选择', code: 400);
      }
      applied.add(_tagSnapshot(tag));
    }
    final before = previousTags.map((t) => t['id']).toSet();
    for (final tag in myTags) {
      final count = (tag['usageCount'] as num?)?.toInt() ?? 0;
      if (tagIds.contains(tag['id']) && !before.contains(tag['id'])) {
        tag['usageCount'] = count + 1;
      } else if (before.contains(tag['id']) && !tagIds.contains(tag['id'])) {
        tag['usageCount'] = count > 0 ? count - 1 : 0;
      }
    }
    DemoStore.save(DemoArtworkData.tagsKey(teacherId));

    final review = <String, dynamic>{
      'teacherId': teacherId,
      'score': score,
      'maxScore': maxScore,
      'content': content,
      'reviewedTime': _now(),
      'tags': applied,
    };
    work['reviews'] = <Map<String, dynamic>>[
      ...DemoArtworkData.reviewsOf(
        work,
      ).where((r) => r['teacherId'] != teacherId),
      review,
    ];
    _simulatePeerReviews(work, review);
    DemoStore.save(DemoArtworkData.worksKey);

    final id = _text(work['id']);
    return <String, dynamic>{
      'artworkId': id,
      'nextArtworkId': req.boolOf('next') ? _nextPending(teacherId, id) : null,
    };
  });

  marking.get('/school/teacher/artworks/{id}/annotations', (req) {
    final teacherId = _teacherId(req);
    final work = _assignedWork(teacherId, req.param('id'));
    return <String, dynamic>{
      'strokes': _strokesOf(_text(work['id']), teacherId),
    };
  });

  marking.post('/school/teacher/artworks/{id}/annotations', (req) {
    final teacherId = _teacherId(req);
    final work = _assignedWork(teacherId, req.param('id'));
    final imageIndex = req.intOf('imageIndex', -1);
    if (imageIndex < 0 || imageIndex >= DemoArtworkData.imagesOf(work).length) {
      throw const DemoApiException('图片序号无效，请刷新后重试', code: 400);
    }
    final raw = req.listOf('strokes');
    if (raw.length > _strokesPerImage) {
      throw const DemoApiException('单张图片最多保存 200 笔批注', code: 400);
    }
    final strokes = _normalizeStrokes(raw, imageIndex);
    final workId = _text(work['id']);
    final all = _annotations();
    final byTeacher = all[workId] is Map
        ? (all[workId] as Map).map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    byTeacher[teacherId] = <Map<String, dynamic>>[
      ..._strokesOf(
        workId,
        teacherId,
      ).where((s) => s['imageIndex'] != imageIndex),
      ...strokes,
    ];
    all[workId] = byTeacher;
    DemoStore.save(DemoArtworkData.annotationsKey);
    return true;
  });

  // ── 教职：点评标签（老师私有） ──────────────────────────────────────
  marking.get('/school/teacher/tags', (req) {
    return <Map<String, dynamic>>[
      for (final tag in _tags(_teacherId(req))) <String, dynamic>{...tag},
    ];
  });

  marking.post('/school/teacher/tags', (req) {
    final teacherId = _teacherId(req);
    final tags = _tags(teacherId);
    final input = _tagInput(req, tags);
    if (tags.length >= _tagLimit) {
      throw const DemoApiException('最多可以创建 50 个标签', code: 400);
    }
    final id = DemoStore.nextId('tag-');
    tags.add(<String, dynamic>{'id': id, ...input, 'usageCount': 0});
    DemoStore.save(DemoArtworkData.tagsKey(teacherId));
    return id;
  });

  marking.post('/school/teacher/tags/update', (req) {
    final teacherId = _teacherId(req);
    final tags = _tags(teacherId);
    final id = req.str('id');
    final tag = tags.where((t) => t['id'] == id).firstOrNull;
    if (tag == null) {
      throw const DemoApiException('标签不存在，请刷新后重试', code: 404);
    }
    tag.addAll(_tagInput(req, tags, exceptId: id));
    DemoStore.save(DemoArtworkData.tagsKey(teacherId));
    return true;
  });

  marking.post('/school/teacher/tags/delete', (req) {
    final teacherId = _teacherId(req);
    final tags = _tags(teacherId);
    final id = req.str('id');
    final before = tags.length;
    tags.removeWhere((t) => t['id'] == id);
    if (tags.length == before) {
      throw const DemoApiException('标签不存在，请刷新后重试', code: 404);
    }
    DemoStore.save(DemoArtworkData.tagsKey(teacherId));
    return true;
  });
}

// ── 存储 ────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _works() =>
    DemoStore.list(DemoArtworkData.worksKey, DemoArtworkData.seedWorks);

List<Map<String, dynamic>> _tags(String teacherId) => DemoStore.list(
  DemoArtworkData.tagsKey(teacherId),
  () => DemoArtworkData.seedTags(teacherId),
);

Map<String, dynamic> _annotations() => DemoStore.map(
  DemoArtworkData.annotationsKey,
  DemoArtworkData.seedAnnotations,
);

Map<String, dynamic> _uploads() =>
    DemoStore.map(DemoArtworkData.uploadsKey, () => <String, dynamic>{});

// ── 身份 ────────────────────────────────────────────────────────────────

int _studentIndex(DemoRequest req) {
  final index = req.account.personIndex;
  if (index == null) {
    throw const DemoApiException('请使用学生账号查看作品档案', code: 403);
  }
  return index;
}

/// 没有阅卷老师身份的教职账号（如宿管）用账号 id 兜底：没有指派作品，标签单独保存。
String _teacherId(DemoRequest req) {
  final account = req.account;
  if (!account.role.isStaff) {
    throw const DemoApiException('仅教师账号可以点评作品', code: 403);
  }
  return account.teacherId ?? 'u-${account.userId}';
}

String _teacherNameOf(String teacherId, [DemoAccount? viewer]) {
  if (viewer != null &&
      viewer.teacherId == teacherId &&
      !DemoArtworkData.isReviewTeacher(teacherId)) {
    return viewer.name;
  }
  return DemoArtworkData.teacherName(teacherId);
}

// ── 查询 ────────────────────────────────────────────────────────────────

String _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text == 'null' ? '' : text;
}

bool _isReviewed(Map<String, dynamic> work) =>
    DemoArtworkData.aggregate(work).status == DemoArtworkData.statusReviewed;

String _statusFilter(DemoRequest req) {
  final status = req.str('status', 'ALL').toUpperCase();
  if (!const {'ALL', 'PENDING', 'REVIEWED'}.contains(status)) {
    throw const DemoApiException('作品状态无效', code: 400);
  }
  return status;
}

int _newestDrawn(Map<String, dynamic> a, Map<String, dynamic> b) {
  final byDate = _text(b['drawingDate']).compareTo(_text(a['drawingDate']));
  return byDate != 0 ? byDate : _newestSubmitted(a, b);
}

int _newestSubmitted(Map<String, dynamic> a, Map<String, dynamic> b) {
  final byTime = _text(b['createTime']).compareTo(_text(a['createTime']));
  return byTime != 0 ? byTime : _text(b['id']).compareTo(_text(a['id']));
}

List<Map<String, dynamic>> _worksOf(int personIndex) =>
    _works().where((w) => w['personIndex'] == personIndex).toList()
      ..sort(_newestDrawn);

List<Map<String, dynamic>> _assigned(String teacherId) =>
    _works()
        .where((w) => DemoArtworkData.teacherIdsOf(w).contains(teacherId))
        .toList()
      ..sort(_newestSubmitted);

Map<String, dynamic> _assignedWork(String teacherId, String id) {
  final work = _assigned(teacherId).where((w) => w['id'] == id).firstOrNull;
  if (work == null) {
    throw const DemoApiException('作品不存在或未分配给你，请返回列表刷新', code: 404);
  }
  return work;
}

DemoPerson? _personOf(Map<String, dynamic> work) {
  final index = (work['personIndex'] as num?)?.toInt();
  return DemoMarkingData.instance.persons
      .where((p) => p.index == index)
      .firstOrNull;
}

/// 已点评后保存会让当前作品离开队列，按列表顺序取它之后的下一份，没有再从头找。
String? _nextPending(String teacherId, String currentId) {
  final all = _assigned(teacherId);
  bool pending(Map<String, dynamic> w) =>
      w['id'] != currentId && DemoArtworkData.reviewOf(w, teacherId) == null;
  final position = all.indexWhere((w) => w['id'] == currentId);
  final ordered = [
    ...all.skip(position + 1),
    ...all.take(position < 0 ? 0 : position),
  ];
  return ordered.where(pending).map((w) => _text(w['id'])).firstOrNull;
}

double? _requiredFullScore(Map<String, dynamic> work, String teacherId) {
  final teacherIds = DemoArtworkData.teacherIdsOf(work);
  for (final review in DemoArtworkData.reviewsOf(work)) {
    final id = _text(review['teacherId']);
    if (id != teacherId && teacherIds.contains(id) && review['score'] is num) {
      return ((review['maxScore'] as num?) ?? 100).toDouble();
    }
  }
  return null;
}

// ── 视图 ────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _imagesOf(Map<String, dynamic> work) =>
    <Map<String, dynamic>>[
      for (final image in DemoArtworkData.imagesOf(work))
        <String, dynamic>{
          'id': _text(image['id']),
          'url': DemoMedia.url(_text(image['ref'])),
        },
    ];

Map<String, dynamic> _studentSummary(Map<String, dynamic> work) {
  final summary = DemoArtworkData.aggregate(work);
  final images = _imagesOf(work);
  return <String, dynamic>{
    'id': _text(work['id']),
    'title': _text(work['title']),
    'subject': _text(work['subject']),
    'drawingDate': _text(work['drawingDate']),
    'createTime': _text(work['createTime']),
    'description': _text(work['description']),
    'status': summary.status,
    'imageCount': images.length,
    'teacherCount': summary.teacherCount,
    'reviewedCount': summary.reviewedCount,
    'coverUrl': images.isEmpty ? '' : images.first['url'],
    'finalScore': summary.finalScore,
    'maxScore': summary.maxScore,
  };
}

/// 学生端：全部老师点评完成前只展示每位老师是否已点评，不透出分数与评语。
Map<String, dynamic> _studentReview(
  Map<String, dynamic> work,
  String teacherId, {
  required bool visible,
}) {
  final review = DemoArtworkData.reviewOf(work, teacherId);
  final shown = visible ? review : null;
  return <String, dynamic>{
    'teacherId': teacherId,
    'teacherName': _teacherNameOf(teacherId),
    'reviewed': review != null,
    'score': shown?['score'],
    'maxScore': review?['maxScore'] ?? 100,
    'content': shown == null ? '' : _text(shown['content']),
    'reviewedTime': shown?['reviewedTime'],
    'tags': <Map<String, dynamic>>[
      if (shown != null)
        for (final tag in DemoArtworkData.tagsOf(shown))
          <String, dynamic>{
            'name': tag['name'],
            'explanation': tag['explanation'] ?? '',
            'color': tag['color'],
          },
    ],
    'annotations': shown == null
        ? const <Map<String, dynamic>>[]
        : _strokesOf(_text(work['id']), teacherId),
  };
}

Map<String, dynamic> _teacherSummary(
  Map<String, dynamic> work,
  String teacherId,
) {
  final summary = DemoArtworkData.aggregate(work);
  final person = _personOf(work);
  final images = _imagesOf(work);
  return <String, dynamic>{
    'id': _text(work['id']),
    'archiveId': person?.archiveId ?? '',
    'studentNo': person?.studentNo ?? '',
    'studentName': person?.name ?? '学生',
    'organizationName': person?.organizationName ?? '',
    'avatarUrl': DemoMedia.url(person?.avatarRef ?? ''),
    'title': _text(work['title']),
    'subject': _text(work['subject']),
    'drawingDate': _text(work['drawingDate']),
    'createTime': _text(work['createTime']),
    'status': summary.status,
    'coverUrl': images.isEmpty ? '' : images.first['url'],
    'imageCount': images.length,
    'myReviewed': DemoArtworkData.reviewOf(work, teacherId) != null,
    'finalScore': summary.finalScore,
    'maxScore': summary.maxScore,
  };
}

/// 教师端：保存自己的点评前，其他老师的分数、评语与标签不可见（避免相互影响）。
Map<String, dynamic> _teacherDetail(
  Map<String, dynamic> work,
  String teacherId,
  DemoAccount viewer,
) {
  final teacherIds = DemoArtworkData.teacherIdsOf(work);
  final myReviewed = DemoArtworkData.reviewOf(work, teacherId) != null;
  return <String, dynamic>{
    'work': <String, dynamic>{
      ..._teacherSummary(work, teacherId),
      'description': _text(work['description']),
      'requiredFullScore': _requiredFullScore(work, teacherId),
      'teachers': <Map<String, dynamic>>[
        for (final id in teacherIds)
          <String, dynamic>{
            'teacherId': id,
            'teacherName': _teacherNameOf(id, viewer),
            'reviewed': DemoArtworkData.reviewOf(work, id) != null,
          },
      ],
    },
    'images': _imagesOf(work),
    'reviews': <Map<String, dynamic>>[
      for (final id in teacherIds)
        _teacherReview(
          work,
          id,
          viewer: viewer,
          mine: id == teacherId,
          revealed: id == teacherId || myReviewed,
        ),
    ],
  };
}

Map<String, dynamic> _teacherReview(
  Map<String, dynamic> work,
  String teacherId, {
  required DemoAccount viewer,
  required bool mine,
  required bool revealed,
}) {
  final review = DemoArtworkData.reviewOf(work, teacherId);
  final shown = revealed ? review : null;
  return <String, dynamic>{
    'teacherId': teacherId,
    'teacherName': _teacherNameOf(teacherId, viewer),
    'mine': mine,
    'reviewed': review != null,
    'score': shown?['score'],
    'maxScore': review?['maxScore'] ?? 100,
    'content': shown == null ? null : _text(shown['content']),
    'reviewedTime': shown?['reviewedTime'],
    'tags': shown == null
        ? const <Map<String, dynamic>>[]
        : DemoArtworkData.tagsOf(shown).map(_tagSnapshot).toList(),
  };
}

Map<String, dynamic> _tagSnapshot(Map<String, dynamic> tag) =>
    <String, dynamic>{
      'id': tag['id'],
      'name': tag['name'],
      'explanation': tag['explanation'] ?? '',
      'color': tag['color'],
    };

List<Map<String, dynamic>> _strokesOf(String workId, String teacherId) {
  final byTeacher = _annotations()[workId];
  if (byTeacher is! Map) {
    return const <Map<String, dynamic>>[];
  }
  return DemoArtworkData.mapsOf(byTeacher[teacherId]);
}

// ── 校验 ────────────────────────────────────────────────────────────────

final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

bool _twoDecimals(double value) =>
    ((value * 100) - (value * 100).roundToDouble()).abs() < 1e-6;

String _scoreText(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : DemoArtworkData.round2(value).toString();

double? _optionalNumber(Object? raw, String message) {
  if (raw == null || (raw is String && raw.trim().isEmpty)) {
    return null;
  }
  final value = raw is num
      ? raw.toDouble()
      : double.tryParse(raw.toString().trim());
  if (value == null || !value.isFinite) {
    throw DemoApiException(message, code: 400);
  }
  return value;
}

bool _isPastOrToday(String text) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) {
    return false;
  }
  final parts = [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  final date = DateTime(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    return false;
  }
  final now = DateTime.now();
  return !date.isAfter(DateTime(now.year, now.month, now.day));
}

bool _isSupportedImage(Uint8List b) {
  bool startsWith(List<int> sig, [int offset = 0]) {
    if (b.length < offset + sig.length) {
      return false;
    }
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) {
        return false;
      }
    }
    return true;
  }

  return startsWith(const [0xFF, 0xD8, 0xFF]) ||
      startsWith(const [0x89, 0x50, 0x4E, 0x47]) ||
      startsWith(const [0x47, 0x49, 0x46, 0x38]) ||
      (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
          startsWith(const [0x57, 0x45, 0x42, 0x50], 8));
}

Map<String, dynamic> _tagInput(
  DemoRequest req,
  List<Map<String, dynamic>> tags, {
  String? exceptId,
}) {
  final name = req.str('name');
  final explanation = _text(req.bodyMap['explanation']);
  final color = req.str('color').toUpperCase();
  if (name.isEmpty || name.runes.length > 50) {
    throw const DemoApiException('请填写 1 至 50 个字的标签名称', code: 400);
  }
  if (explanation.runes.length > 500) {
    throw const DemoApiException('标签解释最多 500 个字', code: 400);
  }
  if (!_hexColor.hasMatch(color)) {
    throw const DemoApiException('请选择标签颜色', code: 400);
  }
  final duplicated = tags.any(
    (t) =>
        t['id'] != exceptId &&
        _text(t['name']).toLowerCase() == name.toLowerCase(),
  );
  if (duplicated) {
    throw const DemoApiException('已有同名标签，请换一个名称', code: 409);
  }
  return <String, dynamic>{
    'name': name,
    'explanation': explanation,
    'color': color,
  };
}

List<Map<String, dynamic>> _normalizeStrokes(
  List<dynamic> raw,
  int imageIndex,
) {
  double unit(num v) => (v.toDouble().clamp(0.0, 1.0) * 10000).round() / 10000;
  final strokes = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final points = <List<double>>[];
    final rawPoints = item['points'];
    if (rawPoints is List) {
      for (final p in rawPoints.take(_pointsPerStroke)) {
        if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
          points.add(<double>[unit(p[0] as num), unit(p[1] as num)]);
        }
      }
    }
    if (points.isEmpty) {
      continue;
    }
    final color = _text(item['color']).toUpperCase();
    final width = item['width'] is num
        ? (item['width'] as num).toDouble()
        : 4.0;
    strokes.add(<String, dynamic>{
      'color': _hexColor.hasMatch(color) ? color : '#E5323B',
      'width': width.clamp(1.0, 24.0),
      'imageIndex': imageIndex,
      'points': points,
    });
  }
  return strokes;
}

String _now() {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)} '
      '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
}

// ── 演示：模拟其他老师 ──────────────────────────────────────────────────

const _peerTagPreference = <String, List<String>>{
  '素描': ['明暗层次弱', '暗部偏闷', '结构错误'],
  '色彩': ['环境色不足', '色调不统一'],
  '速写': ['线条生硬', '动态僵硬'],
};

/// 没有体验账号的指派老师（刘芳）在有老师保存点评后自动补上点评，
/// 让学生端能看到完整的多师点评；有体验账号的老师（李静、张明远、赵雪）需要登录点评。
void _simulatePeerReviews(
  Map<String, dynamic> work,
  Map<String, dynamic> trigger,
) {
  final loginTeachers = <String>{
    for (final account in DemoAccounts.all) ?account.teacherId,
  };
  final reviews = DemoArtworkData.reviewsOf(work);
  final subject = _text(work['subject']);
  final personIndex = (work['personIndex'] as num?)?.toInt() ?? 1;
  final added = <Map<String, dynamic>>[];
  for (final peerId in DemoArtworkData.teacherIdsOf(work)) {
    if (loginTeachers.contains(peerId) ||
        reviews.any((r) => r['teacherId'] == peerId)) {
      continue;
    }
    final maxScore = ((trigger['maxScore'] as num?) ?? 100).toDouble();
    final base = trigger['score'] is num
        ? (trigger['score'] as num).toDouble()
        : null;
    final offset = (_text(work['id']).hashCode + peerId.hashCode) % 5 - 2;
    final score = base == null
        ? null
        : DemoArtworkData.round2((base + offset).clamp(0, maxScore).toDouble());
    final peerTags = _tags(peerId);
    final preferred = _peerTagPreference[subject] ?? const <String>[];
    final tag = preferred
        .map((name) => peerTags.where((t) => t['name'] == name).firstOrNull)
        .nonNulls
        .firstOrNull;
    if (tag != null) {
      tag['usageCount'] = ((tag['usageCount'] as num?)?.toInt() ?? 0) + 1;
      DemoStore.save(DemoArtworkData.tagsKey(peerId));
    }
    added.add(<String, dynamic>{
      'teacherId': peerId,
      'score': score,
      'maxScore': maxScore,
      'content': DemoMarkingData.commentFor(
        subject,
        personIndex,
        added.length + 1,
      ),
      'reviewedTime': _now(),
      'tags': <Map<String, dynamic>>[if (tag != null) _tagSnapshot(tag)],
    });
  }
  if (added.isNotEmpty) {
    work['reviews'] = <Map<String, dynamic>>[...reviews, ...added];
  }
}
