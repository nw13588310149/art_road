import 'dart:typed_data';

import '../data/demo_artwork_data.dart';
import '../data/demo_artwork_seed.dart';
import '../data/demo_artwork_store.dart';
import '../data/demo_campus_data.dart';
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

/// 作品点评链演示接口（阅卷一侧，口径见实施规格 2.6）。
void registerMarkingArtworkFixtures(DemoRouter marking) {
  marking.get(
    '/app/artworks/review-teachers',
    (req) => [
      for (final teacher in DemoMarkingData.reviewTeachers)
        if (!teacher.leader)
          {
            'teacherId': teacher.id,
            'teacherName': teacher.name,
            'subject': teacher.subject,
          },
    ],
  );
  // ── 学生：作品档案 ──────────────────────────────────────────────────
  marking.get('/app/artworks/statistics', (req) {
    final works = _studentLatest(_studentIndex(req));
    final reviewed = works.where((w) => DemoArtworkData.isReviewed(w)).length;
    return <String, dynamic>{
      'total': works.length,
      'reviewed': reviewed,
      'pending': works.length - reviewed,
    };
  });

  marking.get('/app/artworks/insights', (req) {
    final person = _studentIndex(req);
    return DemoArtworkData.insightsOf(
      DemoArtworkStore.works()
          .where((w) => DemoArtworkData.personOf(w) == person)
          .toList(),
      DemoArtworkStore.now(),
    );
  });

  marking.get('/app/artworks/excellent', (req) {
    final subject = req.str('subject');
    final campusId = req.str('campusId');
    final rows =
        DemoArtworkStore.works().where((w) {
          if (w['featured'] != true) {
            return false;
          }
          final person = _personOf(w);
          if (campusId.isNotEmpty &&
              (person == null ||
                  DemoArtworkData.classOf(person.index).id != campusId)) {
            return false;
          }
          return subject.isEmpty ||
              DemoArtworkData.text(w['subject']) == subject;
        }).toList()..sort(
          (a, b) => DemoArtworkData.text(
            b['featuredTime'],
          ).compareTo(DemoArtworkData.text(a['featuredTime'])),
        );
    // 优秀作品墙全校可见，带学生姓名和班级（规格 2.6）。
    return _projectPage(
      rows,
      req,
      (w) => <String, dynamic>{
        ...DemoArtworkStore.projectSummary(w, req.account),
        'className': _classNameOf(w),
      },
    );
  });

  marking.get('/app/artworks', (req) {
    final status = _statusFilter(req);
    final revised = req.str('revised').toLowerCase();
    var rows = _studentLatest(_studentIndex(req));
    if (status != 'ALL') {
      rows = rows
          .where(
            (w) =>
                (_reviewedFor(w, req.account)
                    ? DemoArtworkData.statusReviewed
                    : DemoArtworkData.statusPending) ==
                status,
          )
          .toList();
    }
    if (revised == '1' || revised == 'true') {
      rows = rows
          .where((w) => ((w['versionCount'] as num?)?.toInt() ?? 1) > 1)
          .toList();
    }
    return _projectPage(
      rows,
      req,
      (w) => DemoArtworkStore.projectSummary(
        w,
        req.account,
        versionCount: (w['versionCount'] as num?)?.toInt(),
      ),
    );
  });

  // 学生本人的作品；被推优的作品挂在优秀作品墙上，任何身份都能从这里读详情。
  marking.get('/app/artworks/{id}', (req) {
    final work = DemoArtworkStore.workById(req.param('id'));
    final access = work == null
        ? const DemoArtworkAccess()
        : DemoArtworkData.accessOf(req.account, work);
    if (work == null || !(access.owner || access.featured)) {
      // 没被推优的作品只有学生本人能从这里读，教职身份走教职详情接口。
      _studentIndex(req);
      throw const DemoApiException('没有找到这份作品，请返回列表刷新', code: 404);
    }
    final detail = DemoArtworkStore.projectDetail(work, req.account);
    // 只有本人能改画重交；其余读者只读。
    (detail['access'] as Map<String, dynamic>)['owner'] = access.owner;
    (detail['work'] as Map<String, dynamic>)['className'] = _classNameOf(work);
    if (access.publicReader) {
      // 只因推优读到这份作品的人，同一条改画链上没被推优的版本不给看。
      final id = _text(work['id']);
      detail['versions'] = <Object?>[
        for (final version in detail['versions'] as List)
          if (version is Map &&
              (_text(version['id']) == id || version['featured'] == true))
            version,
      ];
    }
    return detail;
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
    final uploads = DemoArtworkStore.uploads();
    uploads[id] = <String, dynamic>{'ref': ref, 'personIndex': person};
    while (uploads.length > _keptUploads) {
      uploads.remove(uploads.keys.first);
    }
    DemoArtworkStore.saveUploads();
    return <String, dynamic>{'id': id, 'url': DemoMedia.url(ref)};
  });

  marking.post('/app/artworks', (req) {
    final person = _studentIndex(req);
    final body = req.bodyMap;
    final title = _text(body['title']);
    final subject = _text(body['subject']);
    final drawingDate = _text(body['drawingDate']);
    final description = _text(body['description']);
    var taskId = _text(body['taskId']);
    final parentId = _text(body['parentId']);
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

    Map<String, dynamic>? parent;
    if (parentId.isNotEmpty) {
      parent = DemoArtworkStore.workById(parentId);
      if (parent == null || DemoArtworkData.personOf(parent) != person) {
        throw const DemoApiException('没有找到要改画的原作品', code: 404);
      }
      final version = DemoArtworkData.versionOf(parent);
      if (!DemoArtworkData.isReviewed(parent) ||
          DemoArtworkStore.versionsOf(
            parent,
          ).any((work) => DemoArtworkData.versionOf(work) > version)) {
        throw const DemoApiException('请从已点评的当前版本改画', code: 400);
      }
      taskId = _text(parent['taskId']);
    }

    String teacherId;
    if (parent != null) {
      teacherId = _text(parent['teacherId']);
    } else if (taskId.isNotEmpty) {
      final task = DemoArtworkStore.taskById(taskId);
      if (task == null) {
        throw const DemoApiException('没有找到对应的作品', code: 404);
      }
      final classId = DemoArtworkData.classOf(person).id;
      if (!(task['classIds'] as List).contains(classId) ||
          task['subject'] != subject) {
        throw const DemoApiException('请选择本班同科目的作品', code: 400);
      }
      if (DemoArtworkStore.works().any(
        (work) =>
            work['taskId'] == taskId &&
            DemoArtworkData.personOf(work) == person,
      )) {
        throw const DemoApiException('这份作品已提交，可在作品档案查看', code: 400);
      }
      teacherId = _text(task['teacherId']);
    } else {
      teacherId = DemoArtworkData.responsibleTeacherId(
        DemoArtworkData.classOf(person).id,
        subject,
      );
    }

    final teacherIds = {teacherId, ...req.listOf('teacherIds').map(_text)};
    if (parent != null) {
      teacherIds.addAll((parent['teacherIds'] as List? ?? []).map(_text));
    }
    if (teacherIds.any((id) => !DemoArtworkData.isReviewTeacher(id))) {
      throw const DemoApiException('请选择有效的任课老师', code: 400);
    }
    final uploads = DemoArtworkStore.uploads();
    final images = <Map<String, dynamic>>[];
    for (final imageId in imageIds) {
      final upload = uploads[imageId];
      if (upload is! Map || upload['personIndex'] != person) {
        throw const DemoApiException('部分照片已失效，请重新上传', code: 400);
      }
      images.add(<String, dynamic>{'id': imageId, 'ref': upload['ref']});
    }

    final id = DemoStore.nextId('aw-');
    final version = parent == null ? 1 : DemoArtworkData.versionOf(parent) + 1;
    final rootId = parent == null ? id : DemoArtworkData.rootOf(parent);
    final createTime = DemoArtworkData.fmt(DemoArtworkStore.now());
    final work = <String, dynamic>{
      'id': id,
      'rootId': rootId,
      'version': version,
      'parentId': parentId,
      'personIndex': person,
      'title': title,
      'subject': parent == null ? subject : _text(parent['subject']),
      'drawingDate': drawingDate,
      'createTime': createTime,
      'description': description,
      'images': images,
      'taskId': taskId,
      'teacherId': teacherId,
      'teacherIds': teacherIds.toList(),
      'seedCoReviewsAt': {
        for (final id in teacherIds)
          if (id != teacherId && !DemoArtworkData.hasDemoAccount(id))
            id: DemoArtworkData.fmt(
              DemoArtworkStore.now().add(DemoArtworkData.autoDelay),
            ),
      },
      'review': null,
      'supplements': <Map<String, dynamic>>[],
      'leadReview': null,
      'principalComments': <Map<String, dynamic>>[],
      'featured': false,
      'featuredTime': '',
      'featuredBy': '',
      if (!DemoArtworkData.hasDemoAccount(teacherId))
        'seedReviewAt': DemoArtworkData.fmt(
          DemoArtworkStore.now().add(DemoArtworkData.autoDelay),
        ),
    };
    DemoArtworkStore.saveWork(work);
    imageIds.forEach(uploads.remove);
    DemoArtworkStore.saveUploads();
    DemoArtworkStore.notifyTeacherOfSubmit(work);
    return id;
  });

  marking.get('/app/tasks', (req) {
    final person = _studentIndex(req);
    final classId = DemoArtworkData.classOf(person).id;
    final status = req.str('status').toUpperCase();
    final now = DemoArtworkStore.now();
    // 这名学生交过的作品先按作品归好，不逐份作品去翻整个作品库。
    final submitted = <String, List<Map<String, dynamic>>>{};
    for (final work in DemoArtworkStore.works()) {
      final taskId = _text(work['taskId']);
      if (taskId.isNotEmpty && DemoArtworkData.personOf(work) == person) {
        (submitted[taskId] ??= <Map<String, dynamic>>[]).add(work);
      }
    }
    final result = <Map<String, dynamic>>[];
    for (final task in DemoArtworkStore.tasks()) {
      final classes = task['classIds'];
      if (classes is! List || !classes.map((e) => '$e').contains(classId)) {
        continue;
      }
      final state = _taskStatus(
        task,
        submitted[_text(task['id'])] ?? const <Map<String, dynamic>>[],
        now,
      );
      if (status.isEmpty || status == 'ALL' || state == status) {
        result.add(_taskJson(task, status: state));
      }
    }
    return result;
  });

  // ── 教职：作品点评 ──────────────────────────────────────────────────
  marking.get('/school/teacher/artworks/statistics', (req) {
    final mine = _visibleWorks(req.account);
    final pending = mine.where((w) => !_reviewedFor(w, req.account)).toList();
    final overdue = pending
        .where(
          (w) => DemoArtworkData.isOverdue(
            {...w, 'review': null, 'teacherReviews': <Map<String, dynamic>>[]},
            DemoArtworkStore.now(),
            DemoArtworkStore.settings(),
          ),
        )
        .length;
    final reviewed = mine.length - pending.length;
    return <String, dynamic>{
      'total': mine.length,
      'pending': pending.length,
      'reviewed': reviewed,
      'overdue': overdue,
    };
  });

  marking.get('/school/teacher/artworks', (req) {
    final status = _statusFilter(req);
    final subject = req.str('subject');
    final campus = req.str('campus');
    final teacherFilter = req.str('teacherId');
    final archiveId = req.str('archiveId');
    var rows = _visibleWorks(req.account);
    if (req.boolOf('assigned')) {
      rows = rows
          .where((w) => DemoArtworkData.accessOf(req.account, w).canReview)
          .toList();
    }
    if (status != 'ALL') {
      rows = rows
          .where(
            (w) =>
                (_reviewedFor(w, req.account)
                    ? DemoArtworkData.statusReviewed
                    : DemoArtworkData.statusPending) ==
                status,
          )
          .toList();
    }
    if (subject.isNotEmpty) {
      rows = rows
          .where((w) => DemoArtworkData.text(w['subject']) == subject)
          .toList();
    }
    if (teacherFilter.isNotEmpty) {
      rows = rows
          .where(
            (w) =>
                DemoArtworkData.assignedTeacherIdsOf(w).contains(teacherFilter),
          )
          .toList();
    }
    if (campus.isNotEmpty) {
      rows = rows.where((w) {
        final person = _personOf(w);
        return person?.organizationName.contains(campus) ?? false;
      }).toList();
    }
    if (archiveId.isNotEmpty) {
      rows = rows.where((w) => _personOf(w)?.archiveId == archiveId).toList();
    }
    final matched = demoSearch(rows, req.str('keyword'), (w) {
      final person = _personOf(w);
      return <String>[
        _text(w['title']),
        _text(w['subject']),
        person?.name ?? '',
        person?.organizationName ?? '',
        DemoArtworkData.teacherName(_text(w['teacherId'])),
      ];
    });
    if (status == 'PENDING') {
      matched.sort(
        (a, b) => _text(a['createTime']).compareTo(_text(b['createTime'])),
      );
    }
    return _projectPage(
      matched,
      req,
      (w) => DemoArtworkStore.projectSummary(w, req.account),
    );
  });

  marking.get('/school/teacher/artworks/{id}', (req) {
    final work = _readableWork(req, req.param('id'));
    return DemoArtworkStore.projectDetail(work, req.account);
  });

  marking.post('/school/teacher/artworks/review', (req) {
    final account = req.account;
    final teacherId = _requireReviewTeacher(account);
    final body = req.bodyMap;
    final work = DemoArtworkStore.workById(_text(body['artworkId']));
    if (work == null) {
      throw const DemoApiException('没有找到这份作品', code: 404);
    }
    final access = DemoArtworkData.accessOf(account, work);
    if (!access.canReview) {
      throw const DemoApiException('当前身份不能保存任课老师点评', code: 403);
    }

    final score = _optionalNumber(body['score'], '分数须为数字，最多两位小数');
    final maxScore = _optionalNumber(body['maxScore'], '满分须为大于 0 的数字') ?? 100;
    final content = _text(body['content']);
    final requestLead = body['requestLeadReview'] == true;
    final voiceRef = _text(body['voiceUrl'] ?? body['voiceRef']);
    final voiceSeconds = (body['voiceSeconds'] as num?)?.toInt() ?? 0;
    final tagIds = req
        .listOf('tagIds')
        .map((e) => e.toString())
        .toSet()
        .toList();
    final dimensions = _parseDimensions(body['dimensions'], work);
    final tagResolutions = _parseResolutions(body['tagResolutions']);

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
    }

    final myTags = DemoArtworkStore.tagsOf(teacherId);
    final previous = DemoArtworkData.reviewsOf(
      work,
    ).where((review) => review['teacherId'] == teacherId).firstOrNull;
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
    DemoArtworkStore.saveTags(teacherId);

    final workId = _text(work['id']);
    final hasAnno = DemoArtworkStore.hasAnnotations(workId, teacherId);
    final reasons = DemoArtworkData.leadReasons(
      id: workId,
      requested: requestLead,
      score: score,
      maxScore: maxScore,
      recentFinals: DemoArtworkStore.recentFinalRatios(
        personIndex: DemoArtworkData.personOf(work),
        subject: _text(work['subject']),
        excludeId: workId,
      ),
      content: content,
      hasAnnotations: hasAnno,
      spotCheckPercent: DemoArtworkStore.settings().spotCheckPercent,
    );
    // 组长本人负责的作品不进复核池。
    final leaderId = DemoArtworkData.leaderOfSubject(
      _text(work['subject']),
    )?.id;
    final enterLead = leaderId != null;
    final completedLead =
        DemoArtworkData.leadStatusOf(work) == DemoArtworkData.leadDone;

    if (previous != null) {
      _rememberReview(
        work,
        previous,
        'TEACHER',
        DemoArtworkData.teacherName(teacherId),
      );
    }
    final savedReview = <String, dynamic>{
      'teacherId': teacherId,
      'score': score,
      'maxScore': maxScore,
      'content': content,
      'reviewedTime': DemoArtworkData.fmt(DemoArtworkStore.now()),
      'dimensions': dimensions,
      'tags': applied,
      'voiceRef': voiceRef,
      'voiceSeconds': voiceSeconds,
      'requestLeadReview': requestLead,
      'tagResolutions': tagResolutions,
    };
    if (teacherId == work['teacherId']) {
      work['review'] = savedReview;
      work.remove('seedReviewAt');
    } else {
      final others = DemoArtworkData.mapsOf(work['teacherReviews']).toList()
        ..removeWhere((review) => review['teacherId'] == teacherId);
      others.add(savedReview);
      work['teacherReviews'] = others;
    }
    if (enterLead &&
        !completedLead &&
        DemoArtworkData.teacherStageComplete(work)) {
      final auto = !DemoArtworkData.hasDemoAccount(leaderId);
      final entered = DemoArtworkStore.now();
      final lead = <String, dynamic>{
        'reasons': reasons,
        'enteredTime': DemoArtworkData.fmt(entered),
        'leaderId': leaderId,
        'action': null,
        'score': null,
        'reason': '',
        'content': '',
        'qualityStars': 0,
        'qualityNote': '',
        'time': '',
        if (auto)
          'seedLeadAt': DemoArtworkData.fmt(
            entered.add(DemoArtworkData.autoDelay),
          ),
      };
      work['leadReview'] = lead;
      if (auto &&
          !entered
              .add(DemoArtworkData.autoDelay)
              .isAfter(DemoArtworkStore.now())) {
        DemoArtworkSeed.autoLead(
          work,
          lead,
          at: entered.add(DemoArtworkData.autoDelay),
          recentFinals: DemoArtworkStore.recentFinalRatios(
            personIndex: DemoArtworkData.personOf(work),
            subject: _text(work['subject']),
            excludeId: workId,
          ),
        );
        lead.remove('seedLeadAt');
      }
    }
    DemoArtworkStore.saveWork(work);
    DemoArtworkStore.notifyStudentOfReview(work, reviewerId: teacherId);

    return <String, dynamic>{
      'artworkId': workId,
      'nextArtworkId': req.boolOf('next')
          ? _nextPending(account, workId)
          : null,
      'leadStatus': DemoArtworkData.leadStatusOf(work),
    };
  });

  marking.post('/school/teacher/artworks/{id}/supplement', (req) {
    final work = _readableWork(req, req.param('id'));
    final access = DemoArtworkData.accessOf(req.account, work);
    if (!access.canSupplement) {
      throw const DemoApiException('当前身份不能补充点评', code: 403);
    }
    if (!DemoArtworkData.isReviewed(work)) {
      throw const DemoApiException('责任老师点评后才能补充点评', code: 400);
    }
    final teacherId = req.account.teacherId ?? '';
    final content = _text(req.bodyMap['content']);
    if (content.runes.length < 5) {
      throw const DemoApiException('补充评语至少 5 个字', code: 400);
    }
    final supplements = DemoArtworkData.supplementsOf(work);
    supplements.add(<String, dynamic>{
      'teacherId': teacherId,
      'content': content,
      'time': DemoArtworkData.fmt(DemoArtworkStore.now()),
    });
    work['supplements'] = supplements;
    DemoArtworkStore.saveWork(work);
    return true;
  });

  marking.get('/school/teacher/artworks/{id}/annotations', (req) {
    final work = _readableWork(req, req.param('id'));
    final teacherId = _text(work['teacherId']);
    // 组长、校长可读责任老师的批注；责任老师读写自己的。
    final viewer = req.account.teacherId ?? '';
    final access = DemoArtworkData.accessOf(req.account, work);
    final owner = viewer == teacherId || access.leader || access.principal;
    if (!owner && !access.admin && !access.headTeacher) {
      throw const DemoApiException('没有权限查看批注', code: 403);
    }
    return <String, dynamic>{
      'strokes': DemoArtworkStore.strokesOf(_text(work['id']), teacherId),
    };
  });

  marking.post('/school/teacher/artworks/{id}/annotations', (req) {
    final teacherId = _requireReviewTeacher(req.account);
    final work = DemoArtworkStore.workById(req.param('id'));
    if (work == null || _text(work['teacherId']) != teacherId) {
      throw const DemoApiException('只有责任老师可以保存批注', code: 403);
    }
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
    final kept = <Map<String, dynamic>>[
      ...DemoArtworkStore.strokesOf(
        workId,
        teacherId,
      ).where((s) => s['imageIndex'] != imageIndex),
      ...strokes,
    ];
    DemoArtworkStore.saveAnnotations(workId, teacherId, kept);
    return true;
  });

  // ── 作品 ────────────────────────────────────────────────────────────
  marking.get('/school/teacher/tasks', (req) {
    final account = req.account;
    final teacherId = account.teacherId ?? '';
    final all = DemoArtworkStore.tasks().where((task) {
      if (account.role == DemoRole.principal ||
          account.role == DemoRole.admin) {
        return true;
      }
      return _text(task['teacherId']) == teacherId;
    });
    return <Map<String, dynamic>>[for (final task in all) _taskJson(task)];
  });

  marking.post('/school/teacher/tasks', (req) {
    final teacherId = _requireReviewTeacher(req.account);
    final body = req.bodyMap;
    final title = _text(body['title']);
    final subject = _text(body['subject']);
    final requirement = _text(body['requirement']);
    final dueTime = _text(body['dueTime']);
    final classIds = req.listOf('classIds').map((e) => e.toString()).toList();
    if (title.isEmpty) {
      throw const DemoApiException('请填写作品标题', code: 400);
    }
    if (!DemoArtworkData.subjects.contains(subject)) {
      throw const DemoApiException('请选择素描、色彩或速写', code: 400);
    }
    if (classIds.isEmpty) {
      throw const DemoApiException('请选择班级', code: 400);
    }
    final due = DemoArtworkData.parseTime(dueTime);
    if (due == null || !due.isAfter(DemoArtworkStore.now())) {
      throw const DemoApiException('截止时间需晚于当前时间', code: 400);
    }
    final teacher = DemoCampusData.staffById(teacherId);
    if (teacher?.subject != subject ||
        !classIds.every(
          (classId) =>
              DemoCampusData.classById(classId) != null &&
              teacher!.classIds.contains(classId),
        )) {
      throw const DemoApiException('请选择本人任教的科目和班级', code: 403);
    }
    final id = DemoStore.nextId('tk-');
    final task = <String, dynamic>{
      'id': id,
      'teacherId': teacherId,
      'classIds': classIds.toSet().toList(),
      'subject': subject,
      'title': title,
      'requirement': requirement,
      'dueTime': dueTime,
      'createTime': DemoArtworkData.fmt(DemoArtworkStore.now()),
      'referenceWorkId': _text(body['referenceWorkId']),
    };
    DemoArtworkStore.saveTask(task);
    return id;
  });

  // ── 组长复核 ────────────────────────────────────────────────────────
  marking.get('/school/leader/reviews/statistics', (req) {
    final queue = _leadQueue(req.account);
    final pending = queue
        .where(
          (w) =>
              DemoArtworkData.leadStatusOf(w) == DemoArtworkData.leadInReview,
        )
        .length;
    final overdue = queue
        .where(
          (w) => DemoArtworkData.isLeadOverdue(
            w,
            DemoArtworkStore.now(),
            DemoArtworkStore.settings(),
          ),
        )
        .length;
    final done = queue
        .where(
          (w) => DemoArtworkData.leadStatusOf(w) == DemoArtworkData.leadDone,
        )
        .length;
    final now = DemoArtworkStore.now();
    final weekStart = DemoArtworkData.dateOnly(
      now,
    ).subtract(const Duration(days: 6));
    final adjustedThisWeek = queue.where((work) {
      final lead = DemoArtworkData.leadOf(work);
      final time = DemoArtworkData.parseTime(lead?['time']);
      return lead?['action'] == 'ADJUST' &&
          time != null &&
          !time.isBefore(weekStart);
    }).length;
    return <String, dynamic>{
      'total': queue.length,
      'pending': pending,
      'overdue': overdue,
      'done': done,
      'adjustedThisWeek': adjustedThisWeek,
    };
  });

  marking.get('/school/leader/reviews', (req) {
    final status = req.str('status', 'PENDING').toUpperCase();
    final reason = req.str('reason').toUpperCase();
    final teacherFilter = req.str('teacherId');
    var rows = _leadQueue(req.account);
    if (status == 'PENDING' || status == 'IN_REVIEW') {
      rows = rows
          .where(
            (w) =>
                DemoArtworkData.leadStatusOf(w) == DemoArtworkData.leadInReview,
          )
          .toList();
    } else if (status == 'DONE') {
      rows = rows
          .where(
            (w) => DemoArtworkData.leadStatusOf(w) == DemoArtworkData.leadDone,
          )
          .toList();
    }
    if (reason.isNotEmpty) {
      rows = rows.where((w) {
        final reasons = DemoArtworkData.leadOf(w)?['reasons'];
        return reasons is List && reasons.map((e) => '$e').contains(reason);
      }).toList();
    }
    if (teacherFilter.isNotEmpty) {
      rows = rows
          .where(
            (w) =>
                DemoArtworkData.assignedTeacherIdsOf(w).contains(teacherFilter),
          )
          .toList();
    }
    return _projectPage(rows, req, (w) {
      final lead = DemoArtworkData.leadOf(w);
      return <String, dynamic>{
        ...DemoArtworkStore.projectSummary(w, req.account),
        'leadReasons': lead?['reasons'] ?? const <Object?>[],
        'enteredTime': lead?['enteredTime'] ?? '',
      };
    });
  });

  marking.post('/school/leader/reviews/{artworkId}', (req) {
    final account = req.account;
    if (account.groupLeaderSubjects.isEmpty) {
      throw const DemoApiException('只有教学组长可以提交复核', code: 403);
    }
    final work = DemoArtworkStore.workById(req.param('artworkId'));
    if (work == null) {
      throw const DemoApiException('没有找到这份作品', code: 404);
    }
    final access = DemoArtworkData.accessOf(account, work);
    if (!access.leader) {
      throw const DemoApiException('只能复核本组作品', code: 403);
    }
    if (!DemoArtworkData.teacherStageComplete(work)) {
      throw const DemoApiException('请等待全部任课老师完成点评', code: 400);
    }
    final body = req.bodyMap;
    final action = _text(body['action']).toUpperCase();
    if (!DemoArtworkData.actions.contains(action)) {
      throw const DemoApiException('请选择复核结果：维持、调分或补充评语', code: 400);
    }
    final stars = (body['qualityStars'] as num?)?.toInt() ?? 0;
    if (stars < 1 || stars > 5) {
      throw const DemoApiException('请为这次点评选择 1 至 5 星', code: 400);
    }
    final reason = _text(body['reason']);
    final content = _text(body['content']);
    final note = _text(body['qualityNote']);
    double? score;
    if (action == 'REVIEW') {
      score = _optionalNumber(body['score'], '请填写有效分数');
      final max = DemoArtworkData.maxScoreOf(work);
      if (score == null || score < 0 || score > max || !_twoDecimals(score)) {
        throw DemoApiException('分数须在 0 至 $max 之间', code: 400);
      }
      if (content.runes.length < 5) {
        throw const DemoApiException('组长评语至少 5 个字', code: 400);
      }
    }
    if (action == DemoArtworkData.actionAdjust) {
      if (reason.runes.length < DemoArtworkData.adjustReasonLength) {
        throw const DemoApiException('调分理由至少 10 个字', code: 400);
      }
      score = _optionalNumber(body['score'], '分数须为数字，最多两位小数');
      if (score == null) {
        throw const DemoApiException('请填写调整后的分数', code: 400);
      }
      final max = DemoArtworkData.maxScoreOf(work);
      if (score < 0 || score > max || !_twoDecimals(score)) {
        throw DemoApiException('分数须在 0 至 $max 之间，最多两位小数', code: 400);
      }
    }
    if (action == DemoArtworkData.actionSupplement &&
        content.runes.length < 5) {
      throw const DemoApiException('补充评语至少 5 个字', code: 400);
    }
    final lead =
        DemoArtworkData.leadOf(work) ??
        <String, dynamic>{
          'enteredTime': DemoArtworkData.fmt(DemoArtworkStore.now()),
          'reasons': <String>[],
        };
    if (_text(lead['action']).isNotEmpty) {
      _rememberReview(work, lead, 'LEADER', req.account.name);
    }
    lead
      ..['action'] = action
      ..['score'] = score
      ..['reason'] = reason
      ..['content'] = content
      ..['qualityStars'] = stars
      ..['qualityNote'] = note
      ..['time'] = DemoArtworkData.fmt(DemoArtworkStore.now())
      ..['leaderId'] = account.teacherId;
    lead.remove('seedLeadAt');
    work['leadReview'] = lead;
    DemoArtworkStore.saveWork(work);
    DemoArtworkStore.notifyLeadResult(work);
    return true;
  });

  // ── 校长 ────────────────────────────────────────────────────────────
  marking.post('/school/principal/artworks/{id}/comment', (req) {
    _requirePrincipal(req.account);
    final work = DemoArtworkStore.workById(req.param('id'));
    if (work == null) {
      throw const DemoApiException('没有找到这份作品', code: 404);
    }
    final content = _text(req.bodyMap['content']);
    if (content.runes.length < 5) {
      throw const DemoApiException('校长点评至少 5 个字', code: 400);
    }
    final score = _optionalNumber(req.bodyMap['score'], '请填写有效的校长评分');
    if (score != null &&
        (score < 0 ||
            score > DemoArtworkData.maxScoreOf(work) ||
            !_twoDecimals(score))) {
      throw const DemoApiException('校长评分须在作品满分范围内，最多两位小数', code: 400);
    }
    final comments = DemoArtworkData.principalCommentsOf(work).toList();
    for (final previous in comments.where(
      (c) => c['userId'] == req.account.userId,
    )) {
      _rememberReview(work, previous, 'PRINCIPAL', req.account.name);
    }
    comments.removeWhere((c) => c['userId'] == req.account.userId);
    comments.add(<String, dynamic>{
      'id': DemoStore.nextId('pc-'),
      'score': score,
      'userId': req.account.userId,
      'name': req.account.name,
      'content': content,
      'time': DemoArtworkData.fmt(DemoArtworkStore.now()),
    });
    work['principalComments'] = comments;
    DemoArtworkStore.saveWork(work);
    DemoArtworkStore.notifyPrincipalAction(
      work,
      featured: false,
      commented: true,
    );
    return true;
  });

  marking.post('/school/principal/artworks/{id}/feature', (req) {
    _requirePrincipal(req.account);
    final work = DemoArtworkStore.workById(req.param('id'));
    if (work == null) {
      throw const DemoApiException('没有找到这份作品', code: 404);
    }
    final featured = req.bodyMap['featured'] != false;
    final was = work['featured'] == true;
    work['featured'] = featured;
    work['featuredTime'] = featured
        ? DemoArtworkData.fmt(DemoArtworkStore.now())
        : '';
    work['featuredBy'] = featured ? req.account.name : '';
    DemoArtworkStore.saveWork(work);
    if (featured && !was) {
      DemoArtworkStore.notifyPrincipalAction(
        work,
        featured: true,
        commented: false,
      );
    }
    return true;
  });

  // ── 点评设置 ────────────────────────────────────────────────────────
  marking.get('/school/review-settings', (req) {
    _requireSettingsReader(req.account);
    final settings = DemoArtworkStore.settings();
    return <String, dynamic>{
      ...settings.toMap(),
      'leaders': <Map<String, dynamic>>[
        for (final teacher in DemoMarkingData.reviewTeachers)
          if (teacher.leader)
            <String, dynamic>{
              'id': teacher.id,
              'name': teacher.name,
              'subject': teacher.subject,
            },
      ],
    };
  });

  marking.post('/school/review-settings', (req) {
    if (req.account.role != DemoRole.admin &&
        req.account.role != DemoRole.principal) {
      throw const DemoApiException('只有教务或校长可以修改点评设置', code: 403);
    }
    final body = req.bodyMap;
    final percent =
        (body['spotCheckPercent'] as num?)?.toInt() ??
        DemoArtworkStore.settings().spotCheckPercent;
    if (percent < 10 || percent > 50) {
      throw const DemoApiException('抽查比例须在 10% 至 50% 之间', code: 400);
    }
    final reviewHours =
        (body['reviewHours'] as num?)?.toInt() ??
        DemoArtworkStore.settings().reviewHours;
    final leadHours =
        (body['leadHours'] as num?)?.toInt() ??
        DemoArtworkStore.settings().leadHours;
    if (reviewHours < 1 || leadHours < 1) {
      throw const DemoApiException('时限至少 1 小时', code: 400);
    }
    DemoArtworkStore.saveSettings(
      DemoReviewSettings(
        spotCheckPercent: percent,
        reviewHours: reviewHours,
        leadHours: leadHours,
      ),
    );
    return true;
  });

  // ── 教职：点评标签 ──────────────────────────────────────────────────
  marking.get('/school/teacher/tags', (req) {
    return <Map<String, dynamic>>[
      for (final tag in DemoArtworkStore.tagsOf(_teacherId(req)))
        <String, dynamic>{...tag},
    ];
  });

  marking.post('/school/teacher/tags', (req) {
    final teacherId = _teacherId(req);
    final tags = DemoArtworkStore.tagsOf(teacherId);
    final input = _tagInput(req, tags);
    if (tags.length >= _tagLimit) {
      throw const DemoApiException('最多可以创建 50 个标签', code: 400);
    }
    final id = DemoStore.nextId('tag-');
    tags.add(<String, dynamic>{'id': id, ...input, 'usageCount': 0});
    DemoArtworkStore.saveTags(teacherId);
    return id;
  });

  marking.post('/school/teacher/tags/update', (req) {
    final teacherId = _teacherId(req);
    final tags = DemoArtworkStore.tagsOf(teacherId);
    final id = req.str('id');
    final tag = tags.where((t) => t['id'] == id).firstOrNull;
    if (tag == null) {
      throw const DemoApiException('标签不存在，请刷新后重试', code: 404);
    }
    tag.addAll(_tagInput(req, tags, exceptId: id));
    DemoArtworkStore.saveTags(teacherId);
    return true;
  });

  marking.post('/school/teacher/tags/delete', (req) {
    final teacherId = _teacherId(req);
    final tags = DemoArtworkStore.tagsOf(teacherId);
    final id = req.str('id');
    final before = tags.length;
    tags.removeWhere((t) => t['id'] == id);
    if (tags.length == before) {
      throw const DemoApiException('标签不存在，请刷新后重试', code: 404);
    }
    DemoArtworkStore.saveTags(teacherId);
    return true;
  });
}

// ── 查询辅助 ──────────────────────────────────────────────────────────

/// 先分页，再整理字段：整理一条要查版本数、作品和学生信息，校长的列表有上千条，
/// 只整理当前页要返回的那些。
Map<String, dynamic> _projectPage(
  List<Map<String, dynamic>> rows,
  DemoRequest req,
  Map<String, dynamic> Function(Map<String, dynamic> work) project,
) {
  final page = demoPage(rows, req);
  page['records'] = <Map<String, dynamic>>[
    for (final row in page['records'] as List)
      project(row as Map<String, dynamic>),
  ];
  return page;
}

List<Map<String, dynamic>> _studentLatest(int personIndex) =>
    DemoArtworkStore.latestVersions(
      DemoArtworkStore.works().where(
        (w) => DemoArtworkData.personOf(w) == personIndex,
      ),
    );

List<Map<String, dynamic>> _visibleWorks(DemoAccount account) {
  final role = account.role;
  final all = DemoArtworkStore.works();
  if (role == DemoRole.principal || role == DemoRole.admin) {
    return all;
  }
  final teacherId = account.teacherId ?? '';
  if (role == DemoRole.headTeacher) {
    final classId = DemoCampusData.classes
        .where((c) => c.headTeacherId == teacherId)
        .map((c) => c.id)
        .toSet();
    return all
        .where(
          (w) => classId.contains(
            DemoArtworkData.classOf(DemoArtworkData.personOf(w)).id,
          ),
        )
        .toList();
  }
  if (role.teaches) {
    // 责任老师看自己的；组长额外能在详情里看本组，列表仍以自己负责为主，
    // 校长/管理员看全部。补充点评入口走详情。
    return all
        .where(
          (w) =>
              DemoArtworkData.accessOf(account, w).canReview ||
              DemoArtworkData.accessOf(account, w).leader,
        )
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

List<Map<String, dynamic>> _leadQueue(DemoAccount account) {
  if (account.groupLeaderSubjects.isEmpty) {
    throw const DemoApiException('只有教学组长可以查看复核池', code: 403);
  }
  final subjects = account.groupLeaderSubjects.toSet();
  return DemoArtworkStore.works().where((w) {
    final lead = DemoArtworkData.leadOf(w);
    if (lead == null) {
      return false;
    }
    final teacher = DemoArtworkData.teacherOf(_text(w['teacherId']));
    return teacher != null && subjects.contains(teacher.subject);
  }).toList()..sort(
    (a, b) => DemoArtworkData.text(DemoArtworkData.leadOf(b)?['enteredTime'])
        .compareTo(
          DemoArtworkData.text(DemoArtworkData.leadOf(a)?['enteredTime']),
        ),
  );
}

/// 教职接口读一份作品（学生详情接口的校验写在接口里）。
Map<String, dynamic> _readableWork(DemoRequest req, String id) {
  final work = DemoArtworkStore.workById(id);
  if (work == null) {
    throw const DemoApiException('没有找到这份作品，请返回列表刷新', code: 404);
  }
  final access = DemoArtworkData.accessOf(req.account, work);
  if (!access.canRead && !access.artTeacher) {
    // 非责任美术老师也可读详情以便补充点评。
    throw const DemoApiException('没有权限查看这份作品', code: 403);
  }
  if (!access.canRead && access.artTeacher) {
    return work;
  }
  if (!access.canRead) {
    throw const DemoApiException('没有权限查看这份作品', code: 403);
  }
  return work;
}

bool _reviewedFor(Map<String, dynamic> work, DemoAccount viewer) =>
    DemoArtworkData.accessOf(viewer, work).canReview
    ? DemoArtworkData.reviewedBy(work, viewer.teacherId)
    : DemoArtworkData.teacherStageComplete(work);

String? _nextPending(DemoAccount account, String currentId) {
  final pending =
      _visibleWorks(account)
          .where(
            (w) =>
                _text(w['id']) != currentId &&
                !DemoArtworkData.reviewedBy(w, account.teacherId) &&
                DemoArtworkData.accessOf(account, w).canReview,
          )
          .toList()
        ..sort(
          (a, b) => _text(a['createTime']).compareTo(_text(b['createTime'])),
        );
  return pending.isEmpty ? null : _text(pending.first['id']);
}

/// [submitted] 是这名学生为这份作品交过的作品。
String _taskStatus(
  Map<String, dynamic> task,
  List<Map<String, dynamic>> submitted,
  DateTime now,
) {
  if (submitted.isEmpty) {
    final due = DemoArtworkData.parseTime(task['dueTime']);
    if (due != null && due.isBefore(now)) {
      return 'OVERDUE';
    }
    return 'PENDING';
  }
  final current = submitted.reduce(
    (a, b) =>
        DemoArtworkData.versionOf(a) >= DemoArtworkData.versionOf(b) ? a : b,
  );
  if (DemoArtworkData.isReviewed(current)) {
    return 'REVIEWED';
  }
  return 'SUBMITTED';
}

Map<String, dynamic> _taskJson(Map<String, dynamic> task, {String? status}) =>
    <String, dynamic>{
      ...task,
      'teacherName': DemoArtworkData.teacherName(_text(task['teacherId'])),
      'status': ?status,
    };

// ── 身份 ──────────────────────────────────────────────────────────────

int _studentIndex(DemoRequest req) {
  final index = req.account.personIndex;
  if (index == null) {
    throw const DemoApiException('请使用学生账号查看作品档案', code: 403);
  }
  return index;
}

String _teacherId(DemoRequest req) {
  final account = req.account;
  if (!account.role.isStaff) {
    throw const DemoApiException('仅教师账号可以点评作品', code: 403);
  }
  return account.teacherId ?? 'u-${account.userId}';
}

String _requireReviewTeacher(DemoAccount account) {
  final teacherId = account.teacherId ?? '';
  if (!account.role.teaches || teacherId.isEmpty) {
    throw const DemoApiException('仅任课老师可以操作', code: 403);
  }
  return teacherId;
}

void _requirePrincipal(DemoAccount account) {
  if (account.role != DemoRole.principal) {
    throw const DemoApiException('只有校长可以执行此操作', code: 403);
  }
}

void _requireSettingsReader(DemoAccount account) {
  if (!account.role.isStaff) {
    throw const DemoApiException('没有权限查看点评设置', code: 403);
  }
}

DemoPerson? _personOf(Map<String, dynamic> work) {
  final index = DemoArtworkData.personOf(work);
  return DemoMarkingData.instance.persons
      .where((p) => p.index == index)
      .firstOrNull;
}

/// 作品所属学生的班级名称；查不到学生时为空。
String _classNameOf(Map<String, dynamic> work) => _personOf(work) == null
    ? ''
    : DemoArtworkData.classOf(DemoArtworkData.personOf(work)).name;

// ── 校验工具 ──────────────────────────────────────────────────────────

String _text(Object? value) => DemoArtworkData.text(value);

String _statusFilter(DemoRequest req) {
  final status = req.str('status', 'ALL').toUpperCase();
  if (!const {'ALL', 'PENDING', 'REVIEWED'}.contains(status)) {
    throw const DemoApiException('作品状态无效', code: 400);
  }
  return status;
}

bool _isPastOrToday(String drawingDate) {
  final day = DateTime.tryParse(drawingDate);
  if (day == null) {
    return false;
  }
  final today = DemoArtworkData.dateOnly(DemoArtworkStore.now());
  return !DemoArtworkData.dateOnly(day).isAfter(today);
}

bool _twoDecimals(double value) =>
    ((value * 100) - (value * 100).roundToDouble()).abs() < 1e-6;

double? _optionalNumber(Object? raw, String error) {
  if (raw == null || '$raw'.trim().isEmpty) {
    return null;
  }
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (value == null || !value.isFinite) {
    throw DemoApiException(error, code: 400);
  }
  return DemoArtworkData.round2(value);
}

Map<String, int> _parseDimensions(Object? raw, Map<String, dynamic> work) {
  final defs = DemoArtworkData.dimensionsOf(_text(work['subject']));
  if (raw == null) {
    return <String, int>{};
  }
  if (raw is! Map) {
    throw const DemoApiException('分项格式无效', code: 400);
  }
  final result = <String, int>{};
  for (final def in defs) {
    final value = raw[def.key];
    if (value == null) {
      continue;
    }
    final level = value is num ? value.toInt() : int.tryParse('$value');
    if (level == null || level < 1 || level > 5) {
      throw DemoApiException('${def.name}须为 1 至 5 级', code: 400);
    }
    result[def.key] = level;
  }
  return result;
}

List<Map<String, dynamic>> _parseResolutions(Object? raw) {
  if (raw is! List) {
    return const <Map<String, dynamic>>[];
  }
  return <Map<String, dynamic>>[
    for (final item in raw)
      if (item is Map)
        <String, dynamic>{
          'tag': _text(item['tag']),
          'resolved': item['resolved'] == true,
        },
  ];
}

Map<String, dynamic> _tagSnapshot(Map<String, dynamic> tag) =>
    <String, dynamic>{
      'id': tag['id'],
      'name': tag['name'],
      'explanation': tag['explanation'] ?? '',
      'color': tag['color'] ?? DemoArtworkData.problemColor,
      'dimension': tag['dimension'] ?? '',
    };

Map<String, dynamic> _tagInput(
  DemoRequest req,
  List<Map<String, dynamic>> existing, {
  String exceptId = '',
}) {
  final name = req.str('name').trim();
  final explanation = req.str('explanation');
  final color = req.str('color', DemoArtworkData.problemColor);
  final dimension = req.str('dimension');
  if (name.isEmpty || name.runes.length > 50) {
    throw const DemoApiException('请填写 1 至 50 个字的标签名称', code: 400);
  }
  if (explanation.runes.length > 500) {
    throw const DemoApiException('标签解释最多 500 个字', code: 400);
  }
  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
    throw const DemoApiException('请选择标签颜色', code: 400);
  }
  final lower = name.toLowerCase();
  if (existing.any(
    (t) => t['id'] != exceptId && _text(t['name']).toLowerCase() == lower,
  )) {
    throw const DemoApiException('已有同名标签，请换一个名称', code: 400);
  }
  return <String, dynamic>{
    'name': name,
    'explanation': explanation,
    'color': color,
    'dimension': dimension,
  };
}

List<Map<String, dynamic>> _normalizeStrokes(
  List<dynamic> raw,
  int imageIndex,
) {
  final strokes = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final points = item['points'];
    if (points is! List || points.isEmpty || points.length > _pointsPerStroke) {
      throw const DemoApiException('批注笔迹点数无效', code: 400);
    }
    final normalized = <List<double>>[];
    for (final p in points) {
      if (p is! List || p.length < 2) {
        continue;
      }
      final x = p[0] is num
          ? (p[0] as num).toDouble()
          : double.tryParse('${p[0]}');
      final y = p[1] is num
          ? (p[1] as num).toDouble()
          : double.tryParse('${p[1]}');
      if (x == null || y == null) {
        continue;
      }
      normalized.add(<double>[
        (x * 10000).round() / 10000,
        (y * 10000).round() / 10000,
      ]);
    }
    if (normalized.isEmpty) {
      continue;
    }
    strokes.add(<String, dynamic>{
      'color': _text(item['color']).isEmpty ? '#E5323B' : _text(item['color']),
      'width': (item['width'] as num?)?.toDouble() ?? 4,
      'imageIndex': imageIndex,
      'points': normalized,
    });
  }
  return strokes;
}

bool _isSupportedImage(Uint8List b) {
  bool at(int offset, List<int> signature) {
    if (b.length < offset + signature.length) {
      return false;
    }
    for (var i = 0; i < signature.length; i++) {
      if (b[offset + i] != signature[i]) {
        return false;
      }
    }
    return true;
  }

  return at(0, const [0xFF, 0xD8, 0xFF]) ||
      at(0, const [0x89, 0x50, 0x4E, 0x47]) ||
      at(0, const [0x47, 0x49, 0x46, 0x38]) ||
      (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
          at(8, const [0x57, 0x45, 0x42, 0x50]));
}

void _rememberReview(
  Map<String, dynamic> work,
  Map<String, dynamic> review,
  String role,
  String name,
) {
  final history = DemoArtworkData.mapsOf(work['reviewHistory']).toList();
  history.add({
    ...review,
    'role': role,
    'name': name,
    'time': review['reviewedTime'] ?? review['time'],
  });
  work['reviewHistory'] = history;
}
