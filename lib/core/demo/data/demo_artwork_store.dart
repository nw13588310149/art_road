/// 作品点评链的统一读写入口：种子按「现在」生成且不落盘，写入只存差异，
/// 平台消息、首页与阅卷接口都从这里读。
///
/// 键名带 `v3`（见 [DemoArtworkData]）；旧的 `v2` 键不再读取。
library;

import '../demo_accounts.dart';
import '../demo_clock.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';
import 'demo_artwork_data.dart';
import 'demo_artwork_seed.dart';
import 'demo_marking_data.dart';

abstract final class DemoArtworkStore {
  static DateTime? _nowOverride;
  static DemoArtworkSeedResult? _seed;
  static DateTime? _seedNow;

  /// 测试注入「现在」；传 `null` 恢复 [DemoClock]。会清掉种子缓存。
  static void setNow(DateTime? value) {
    _nowOverride = value;
    clearCache();
  }

  /// 清空种子缓存（「重置演示数据」后调用，下次按新的「现在」重算）。
  static void clearCache() {
    _seed = null;
    _seedNow = null;
  }

  static DateTime now() => _nowOverride ?? DemoClock.now();

  static DemoArtworkSeedResult _ensureSeed() {
    final current = now();
    if (_seed != null && _seedNow != null) {
      if (_nowOverride != null) {
        if (_seedNow == _nowOverride) {
          return _seed!;
        }
      } else {
        // 同一次运行里复用首次生成的种子；跨天重启会重新进进程再生成。
        return _seed!;
      }
    }
    _seedNow = _nowOverride ?? current;
    _seed = DemoArtworkSeed.build(current);
    return _seed!;
  }

  // ── 差异存储 ─────────────────────────────────────────────────────────

  /// `{id: work}`，只存用户新交或被改动过的作品。
  static Map<String, dynamic> _workOverrides() =>
      DemoStore.map(DemoArtworkData.worksKey, () => <String, dynamic>{});

  static Map<String, dynamic> _taskOverrides() =>
      DemoStore.map(DemoArtworkData.tasksKey, () => <String, dynamic>{});

  static Map<String, dynamic> _annotationOverrides() => DemoStore.map(
    '${DemoArtworkData.annotationsKey}:diff',
    () => <String, dynamic>{},
  );

  static Map<String, dynamic> settingsMap() => DemoStore.map(
    DemoArtworkData.settingsKey,
    () => const DemoReviewSettings().toMap(),
  );

  static DemoReviewSettings settings() =>
      DemoReviewSettings.fromMap(settingsMap());

  static void saveSettings(DemoReviewSettings value) {
    final map = settingsMap();
    map
      ..clear()
      ..addAll(value.toMap());
    DemoStore.save(DemoArtworkData.settingsKey);
  }

  // ── 读取 ─────────────────────────────────────────────────────────────

  /// 合并种子与差异后的全部作品（新的在前）；读取时会推进无演示账号老师的代点评。
  static List<Map<String, dynamic>> works() {
    _applyAutoActions();
    return _mergedWorks();
  }

  static List<Map<String, dynamic>> _mergedWorks() {
    final seed = _ensureSeed();
    final overrides = _workOverrides();
    final merged = <String, Map<String, dynamic>>{};
    for (final work in seed.works) {
      final id = DemoArtworkData.text(work['id']);
      merged[id] = _clone(work);
    }
    for (final entry in overrides.entries) {
      final value = entry.value;
      if (value is Map) {
        merged[entry.key] = _clone(value);
      }
    }
    final list = merged.values.toList()
      ..sort(
        (a, b) => DemoArtworkData.text(
          b['createTime'],
        ).compareTo(DemoArtworkData.text(a['createTime'])),
      );
    return list;
  }

  static Map<String, dynamic>? workById(String id) {
    final wanted = id.trim();
    if (wanted.isEmpty) {
      return null;
    }
    for (final work in works()) {
      if (DemoArtworkData.text(work['id']) == wanted) {
        return work;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _workByIdRaw(String id) {
    final wanted = id.trim();
    if (wanted.isEmpty) {
      return null;
    }
    for (final work in _mergedWorks()) {
      if (DemoArtworkData.text(work['id']) == wanted) {
        return work;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> tasks() {
    final seed = _ensureSeed();
    final overrides = _taskOverrides();
    final merged = <String, Map<String, dynamic>>{};
    for (final task in seed.tasks) {
      merged[DemoArtworkData.text(task['id'])] = _clone(task);
    }
    for (final entry in overrides.entries) {
      final value = entry.value;
      if (value is Map) {
        merged[entry.key] = _clone(value);
      }
    }
    final list = merged.values.toList()
      ..sort(
        (a, b) => DemoArtworkData.text(
          b['createTime'],
        ).compareTo(DemoArtworkData.text(a['createTime'])),
      );
    return list;
  }

  static Map<String, dynamic>? taskById(String id) {
    final wanted = id.trim();
    if (wanted.isEmpty) {
      return null;
    }
    for (final task in tasks()) {
      if (DemoArtworkData.text(task['id']) == wanted) {
        return task;
      }
    }
    return null;
  }

  /// `{artworkId: {teacherId: [stroke…]}}`
  static Map<String, dynamic> annotations() {
    final seed = _ensureSeed();
    final merged = <String, dynamic>{};
    for (final entry in seed.annotations.entries) {
      merged[entry.key] = _cloneValue(entry.value);
    }
    for (final entry in _annotationOverrides().entries) {
      merged[entry.key] = _cloneValue(entry.value);
    }
    return merged;
  }

  static List<Map<String, dynamic>> strokesOf(
    String artworkId,
    String teacherId,
  ) {
    final byTeacher = annotations()[artworkId];
    if (byTeacher is! Map) {
      return const <Map<String, dynamic>>[];
    }
    return DemoArtworkData.mapsOf(byTeacher[teacherId]);
  }

  static bool hasAnnotations(String artworkId, String teacherId) =>
      strokesOf(artworkId, teacherId).isNotEmpty;

  static List<Map<String, dynamic>> tagsOf(String teacherId) {
    return DemoStore.list(
      DemoArtworkData.tagsKey(teacherId),
      () => DemoArtworkData.seedTags(teacherId, works()),
    );
  }

  static Map<String, dynamic> uploads() =>
      DemoStore.map(DemoArtworkData.uploadsKey, () => <String, dynamic>{});

  // ── 写入 ─────────────────────────────────────────────────────────────

  /// 整条覆盖种子里的同 id 作品（或追加新作品）。
  static void saveWork(Map<String, dynamic> work) {
    final id = DemoArtworkData.text(work['id']);
    if (id.isEmpty) {
      return;
    }
    _workOverrides()[id] = _clone(work);
    DemoStore.save(DemoArtworkData.worksKey);
  }

  static void saveTask(Map<String, dynamic> task) {
    final id = DemoArtworkData.text(task['id']);
    if (id.isEmpty) {
      return;
    }
    _taskOverrides()[id] = _clone(task);
    DemoStore.save(DemoArtworkData.tasksKey);
  }

  static void saveAnnotations(
    String artworkId,
    String teacherId,
    List<Map<String, dynamic>> strokes,
  ) {
    final all = _annotationOverrides();
    final byTeacher = all[artworkId] is Map
        ? _clone(all[artworkId] as Map)
        : <String, dynamic>{};
    byTeacher[teacherId] = <Map<String, dynamic>>[
      for (final stroke in strokes) _clone(stroke),
    ];
    all[artworkId] = byTeacher;
    DemoStore.save('${DemoArtworkData.annotationsKey}:diff');
  }

  static void saveTags(String teacherId) {
    DemoStore.save(DemoArtworkData.tagsKey(teacherId));
  }

  static void saveUploads() {
    DemoStore.save(DemoArtworkData.uploadsKey);
  }

  // ── 同链版本 ─────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> versionsOf(Map<String, dynamic> work) {
    final root = DemoArtworkData.rootOf(work);
    final chain =
        works().where((w) => DemoArtworkData.rootOf(w) == root).toList()
          ..sort(
            (a, b) => DemoArtworkData.versionOf(
              a,
            ).compareTo(DemoArtworkData.versionOf(b)),
          );
    return chain;
  }

  /// 学生列表：每条链只保留最新一版，并带 `versionCount`。
  static List<Map<String, dynamic>> latestVersions(
    Iterable<Map<String, dynamic>> source,
  ) {
    final best = <String, Map<String, dynamic>>{};
    final counts = <String, int>{};
    for (final work in source) {
      final root = DemoArtworkData.rootOf(work);
      counts[root] = (counts[root] ?? 0) + 1;
      final current = best[root];
      if (current == null ||
          DemoArtworkData.versionOf(work) > DemoArtworkData.versionOf(current)) {
        best[root] = work;
      }
    }
    return <Map<String, dynamic>>[
      for (final work in best.values)
        <String, dynamic>{
          ...work,
          'versionCount': counts[DemoArtworkData.rootOf(work)] ?? 1,
        },
    ]..sort(
      (a, b) => DemoArtworkData.text(
        b['createTime'],
      ).compareTo(DemoArtworkData.text(a['createTime'])),
    );
  }

  /// 该生此前同科作品的最终分占满分比例（0–1），新的在前；不含 [excludeId]。
  static List<double> recentFinalRatios({
    required int personIndex,
    required String subject,
    String excludeId = '',
  }) {
    _applyAutoActions();
    return _recentFinalRatiosRaw(
      personIndex: personIndex,
      subject: subject,
      excludeId: excludeId,
    );
  }

  static List<double> _recentFinalRatiosRaw({
    required int personIndex,
    required String subject,
    String excludeId = '',
  }) {
    final list =
        _mergedWorks()
            .where(
              (w) =>
                  DemoArtworkData.personOf(w) == personIndex &&
                  DemoArtworkData.text(w['subject']) == subject &&
                  DemoArtworkData.text(w['id']) != excludeId &&
                  DemoArtworkData.isReviewed(w) &&
                  DemoArtworkData.finalScoreOf(w) != null,
            )
            .toList()
          ..sort(
            (a, b) => DemoArtworkData.text(
              b['createTime'],
            ).compareTo(DemoArtworkData.text(a['createTime'])),
          );
    return <double>[
      for (final work in list)
        DemoArtworkData.finalScoreOf(work)! / DemoArtworkData.maxScoreOf(work),
    ];
  }

  // ── 可见范围投影 ─────────────────────────────────────────────────────

  /// 按查看者裁剪后的详情字段（含时间线、版本、分项定义）。
  static Map<String, dynamic> projectDetail(
    Map<String, dynamic> work,
    DemoAccount viewer,
  ) {
    final access = DemoArtworkData.accessOf(viewer, work);
    final review = DemoArtworkData.reviewOf(work);
    final lead = DemoArtworkData.leadOf(work);
    final settings = DemoArtworkStore.settings();
    final at = now();

    Map<String, dynamic>? projectedReview;
    if (review != null && access.seesReview) {
      projectedReview = <String, dynamic>{
        ...review,
        'teacherName': DemoArtworkData.teacherName(
          DemoArtworkData.text(review['teacherId']),
        ),
        'mine':
            viewer.teacherId != null &&
            viewer.teacherId == DemoArtworkData.text(review['teacherId']),
        'reviewed': true,
        'annotations': strokesOf(
          DemoArtworkData.text(work['id']),
          DemoArtworkData.text(review['teacherId']),
        ),
      };
    }

    Map<String, dynamic>? projectedLead;
    if (lead != null) {
      projectedLead = <String, dynamic>{
        'enteredTime': lead['enteredTime'],
        'leaderId': lead['leaderId'],
        'leaderName': DemoArtworkData.teacherName(
          DemoArtworkData.text(lead['leaderId']),
        ),
        'action': lead['action'],
        'score': lead['score'],
        'reason': access.seesLeadResult ? lead['reason'] : '',
        'content': access.seesLeadResult ? lead['content'] : '',
        'time': lead['time'],
        if (access.seesLeadReasons) 'reasons': lead['reasons'],
        if (access.seesQuality) 'qualityStars': lead['qualityStars'],
        if (access.seesQuality) 'qualityNote': lead['qualityNote'],
      };
    }

    final versions = versionsOf(work);
    return <String, dynamic>{
      'work': projectSummary(work, viewer),
      'images': <Map<String, dynamic>>[
        for (final image in DemoArtworkData.imagesOf(work))
          <String, dynamic>{
            'id': DemoArtworkData.text(image['id']),
            'url': DemoMedia.url(DemoArtworkData.text(image['ref'])),
            'ref': DemoArtworkData.text(image['ref']),
          },
      ],
      'review': projectedReview,
      // 兼容旧界面：把责任老师点评放进 reviews 列表。
      'reviews': projectedReview == null
          ? const <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[projectedReview],
      'supplements': access.seesReview
          ? <Map<String, dynamic>>[
              for (final item in DemoArtworkData.supplementsOf(work))
                <String, dynamic>{
                  ...item,
                  'teacherName': DemoArtworkData.teacherName(
                    DemoArtworkData.text(item['teacherId']),
                  ),
                },
            ]
          : const <Map<String, dynamic>>[],
      'leadReview': projectedLead,
      'principalComments': access.seesPrincipal
          ? DemoArtworkData.principalCommentsOf(work)
          : const <Map<String, dynamic>>[],
      'timeline': DemoArtworkData.timelineOf(work),
      'versions': <Map<String, dynamic>>[
        for (final version in versions) projectSummary(version, viewer),
      ],
      'dimensions': <Map<String, dynamic>>[
        for (final def
            in DemoArtworkData.dimensionsOf(DemoArtworkData.text(work['subject'])))
          <String, dynamic>{'key': def.key, 'name': def.name},
      ],
      'overdue': DemoArtworkData.isOverdue(work, at, settings),
      'leadOverdue': DemoArtworkData.isLeadOverdue(work, at, settings),
      'access': <String, dynamic>{
        'canReview': access.canReview,
        'canSupplement': access.canSupplement,
        'canComment': access.canComment,
        'canFeature': access.canFeature,
        'seesLeadReasons': access.seesLeadReasons,
        'seesQuality': access.seesQuality,
      },
    };
  }

  static Map<String, dynamic> projectSummary(
    Map<String, dynamic> work,
    DemoAccount viewer, {
    int? versionCount,
  }) {
    final person = DemoArtworkData.personOf(work);
    final personInfo = DemoMarkingData.instance.persons
        .where((p) => p.index == person)
        .firstOrNull;
    final teacherId = DemoArtworkData.text(work['teacherId']);
    final taskId = DemoArtworkData.text(work['taskId']);
    final task = taskId.isEmpty ? null : taskById(taskId);
    final images = DemoArtworkData.imagesOf(work);
    final cover = images.isEmpty
        ? ''
        : DemoMedia.url(DemoArtworkData.text(images.first['ref']));
    final status = DemoArtworkData.statusOf(work);
    final leadStatus = DemoArtworkData.leadStatusOf(work);
    final settings = DemoArtworkStore.settings();
    final at = now();
    final count = versionCount ?? versionsOf(work).length;
    final comments = DemoArtworkData.principalCommentsOf(work);
    return <String, dynamic>{
      'id': work['id'],
      'rootId': DemoArtworkData.rootOf(work),
      'version': DemoArtworkData.versionOf(work),
      'versionCount': count,
      'parentId': work['parentId'] ?? '',
      'title': work['title'],
      'subject': work['subject'],
      'drawingDate': work['drawingDate'],
      'createTime': work['createTime'],
      'description': work['description'] ?? '',
      'status': status,
      'leadStatus': leadStatus,
      'reviewed': status == DemoArtworkData.statusReviewed,
      'imageCount': images.length,
      'coverUrl': cover,
      'finalScore': DemoArtworkData.finalScoreOf(work),
      'maxScore': DemoArtworkData.maxScoreOf(work),
      'taskId': taskId,
      'taskTitle': task == null ? '' : DemoArtworkData.text(task['title']),
      'teacherId': teacherId,
      'teacherName': DemoArtworkData.teacherName(teacherId),
      'hasPrincipalComment': comments.isNotEmpty,
      'featured': work['featured'] == true,
      'featuredTime': work['featuredTime'] ?? '',
      'overdue': DemoArtworkData.isOverdue(work, at, settings),
      'leadOverdue': DemoArtworkData.isLeadOverdue(work, at, settings),
      'personIndex': person,
      'archiveId': personInfo?.archiveId ?? '',
      'studentNo': personInfo?.studentNo ?? '',
      'studentName': personInfo?.name ?? DemoArtworkData.studentName(person),
      'organizationName': personInfo?.organizationName ?? '',
      'avatarUrl': '',
      'myReviewed':
          viewer.teacherId != null &&
          viewer.teacherId == teacherId &&
          DemoArtworkData.isReviewed(work),
      // 旧字段兼容：责任老师一人。
      'teacherCount': 1,
      'reviewedCount': DemoArtworkData.isReviewed(work) ? 1 : 0,
    };
  }

  // ── 消息 ─────────────────────────────────────────────────────────────

  static const targetArtwork = 2;

  static String noticesKey(String userId) => 'notices:v2:$userId';

  /// 给某个用户追加一条消息；对方还没打开过消息列表时也能看到（先落种子再追加）。
  static void appendNotice({
    required String userId,
    required String content,
    int targetType = targetArtwork,
    String targetId = '',
    DateTime? time,
  }) {
    if (userId.isEmpty || content.isEmpty) {
      return;
    }
    final key = noticesKey(userId);
    final list = DemoStore.list(key, () => seedNoticesForUserId(userId));
    final nextId =
        list
            .map((n) => (n['id'] as num?)?.toInt() ?? 0)
            .fold<int>(0, (a, b) => a > b ? a : b) +
        1;
    list.insert(0, <String, dynamic>{
      'id': nextId,
      'targetType': targetType,
      'targetId': targetId,
      'content': content,
      'createTime': DemoArtworkData.fmt(time ?? now()),
      'read': false,
    });
    DemoStore.save(key);
  }

  static void notifyTeacherOfSubmit(Map<String, dynamic> work) {
    final teacherId = DemoArtworkData.text(work['teacherId']);
    final userId = DemoArtworkData.userIdOfTeacher(teacherId);
    if (userId == null) {
      return;
    }
    final name = DemoArtworkData.studentName(DemoArtworkData.personOf(work));
    appendNotice(
      userId: userId,
      content: '【作品】$name提交了《${work['title']}》，请尽快点评。',
      targetId: DemoArtworkData.text(work['id']),
    );
  }

  static void notifyStudentOfReview(Map<String, dynamic> work) {
    final userId = DemoArtworkData.userIdOfStudent(
      DemoArtworkData.personOf(work),
    );
    if (userId == null) {
      return;
    }
    final teacher = DemoArtworkData.teacherName(
      DemoArtworkData.text(work['teacherId']),
    );
    final review = DemoArtworkData.reviewOf(work);
    final clause = _firstClause(DemoArtworkData.text(review?['content']));
    appendNotice(
      userId: userId,
      content:
          '【作品】$teacher老师点评了你的《${work['title']}》'
          '${clause.isEmpty ? '，可以查看分数与评语。' : '：$clause。'}',
      targetId: DemoArtworkData.text(work['id']),
    );
  }

  static void notifyLeadResult(Map<String, dynamic> work) {
    final lead = DemoArtworkData.leadOf(work);
    final action = DemoArtworkData.text(lead?['action']);
    if (lead == null || action.isEmpty) {
      return;
    }
    final leader = DemoArtworkData.teacherName(
      DemoArtworkData.text(lead['leaderId']),
    );
    final title = DemoArtworkData.text(work['title']);
    final id = DemoArtworkData.text(work['id']);
    final teacherUser = DemoArtworkData.userIdOfTeacher(
      DemoArtworkData.text(work['teacherId']),
    );
    final studentUser = DemoArtworkData.userIdOfStudent(
      DemoArtworkData.personOf(work),
    );
    String text;
    switch (action) {
      case DemoArtworkData.actionAdjust:
        text = '【作品】$leader组长调整了《$title》的分数，请查看复核结果。';
      case DemoArtworkData.actionSupplement:
        text = '【作品】$leader组长补充点评了《$title》，请查看。';
      default:
        text = '【作品】$leader组长复核了《$title》，维持原点评。';
    }
    if (teacherUser != null) {
      appendNotice(userId: teacherUser, content: text, targetId: id);
    }
    if (action != DemoArtworkData.actionKeep && studentUser != null) {
      appendNotice(userId: studentUser, content: text, targetId: id);
    }
  }

  static void notifyPrincipalAction(
    Map<String, dynamic> work, {
    required bool featured,
    required bool commented,
  }) {
    if (!featured && !commented) {
      return;
    }
    final title = DemoArtworkData.text(work['title']);
    final id = DemoArtworkData.text(work['id']);
    final person = DemoArtworkData.personOf(work);
    final recipients = <String>{
      ?DemoArtworkData.userIdOfStudent(person),
      ?DemoArtworkData.userIdOfTeacher(DemoArtworkData.text(work['teacherId'])),
      ?DemoArtworkData.userIdOfTeacher(
        DemoArtworkData.classOf(person).headTeacherId,
      ),
    };
    final content = featured
        ? '【作品】校长将《$title》推荐到优秀作品墙。'
        : '【作品】校长点评了《$title》，请查看。';
    for (final userId in recipients) {
      appendNotice(userId: userId, content: content, targetId: id);
    }
  }

  /// 平台消息种子里与作品相关的部分；完整种子仍由 platform fixtures 组装。
  static List<Map<String, dynamic>> seedArtworkNotices(DemoAccount account) {
    final notices = <Map<String, dynamic>>[];
    final role = account.role;
    final personIndex = account.personIndex;
    if (role == DemoRole.student && personIndex != null) {
      final latest = works()
          .where(
            (w) =>
                DemoArtworkData.personOf(w) == personIndex &&
                DemoArtworkData.isReviewed(w),
          )
          .toList();
      if (latest.isNotEmpty) {
        latest.sort(
          (a, b) => DemoArtworkData.text(
            DemoArtworkData.reviewOf(b)?['reviewedTime'],
          ).compareTo(
            DemoArtworkData.text(DemoArtworkData.reviewOf(a)?['reviewedTime']),
          ),
        );
        final work = latest.first;
        final teacher = DemoArtworkData.teacherName(
          DemoArtworkData.text(work['teacherId']),
        );
        final clause = _firstClause(
          DemoArtworkData.text(DemoArtworkData.reviewOf(work)?['content']),
        );
        notices.add(<String, dynamic>{
          'id': 1,
          'targetType': targetArtwork,
          'targetId': DemoArtworkData.text(work['id']),
          'content':
              '【作品】$teacher老师点评了你的《${work['title']}》'
              '${clause.isEmpty ? '，可以查看分数与评语。' : '：$clause。'}',
          'createTime': _noticeTime(
            DemoArtworkData.parseTime(
              DemoArtworkData.reviewOf(work)?['reviewedTime'],
            ),
            const Duration(hours: 20),
          ),
          'read': false,
        });
      }
    }
    final teacherId = account.teacherId;
    if (teacherId != null && role.teaches) {
      final pending = works()
          .where(
            (w) =>
                DemoArtworkData.text(w['teacherId']) == teacherId &&
                !DemoArtworkData.isReviewed(w),
          )
          .toList();
      if (pending.isNotEmpty) {
        pending.sort(
          (a, b) => DemoArtworkData.text(
            b['createTime'],
          ).compareTo(DemoArtworkData.text(a['createTime'])),
        );
        final work = pending.first;
        notices.add(<String, dynamic>{
          'id': 1,
          'targetType': targetArtwork,
          'targetId': DemoArtworkData.text(work['id']),
          'content':
              '【作品】${DemoArtworkData.studentName(DemoArtworkData.personOf(work))}'
              '提交了《${work['title']}》，你还有 ${pending.length} 件作品待点评。',
          'createTime': _noticeTime(
            DemoArtworkData.parseTime(work['createTime']),
            const Duration(hours: 4),
          ),
          'read': false,
        });
      }
    }
    return notices;
  }

  /// 仅作品相关的消息种子（[appendNotice] 在列表尚未初始化时调用）。
  static List<Map<String, dynamic>> seedNoticesForUserId(String userId) {
    final account = DemoAccounts.all.where((a) => a.userId == userId).firstOrNull;
    if (account == null) {
      return <Map<String, dynamic>>[];
    }
    return seedArtworkNotices(account);
  }

  // ── 无演示账号老师的代点评 / 代复核 ─────────────────────────────────

  static void _applyAutoActions() {
    final seed = _ensureSeed();
    final at = now();
    final overrides = _workOverrides();
    var changed = false;

    for (final raw in seed.works) {
      final id = DemoArtworkData.text(raw['id']);
      final current = overrides[id] is Map
          ? _clone(overrides[id] as Map)
          : _clone(raw);

      // 种子里尚未到点评时间的作品：到点后由后端代点评。
      final reviewAt = DemoArtworkData.parseTime(current['seedReviewAt']);
      if (!DemoArtworkData.isReviewed(current) &&
          reviewAt != null &&
          !reviewAt.isAfter(at) &&
          !DemoArtworkData.hasDemoAccount(
            DemoArtworkData.text(current['teacherId']),
          )) {
        final parentId = DemoArtworkData.text(current['parentId']);
        final parent = parentId.isEmpty ? null : _workByIdRaw(parentId);
        current['review'] = DemoArtworkSeed.autoReview(
          current,
          at: reviewAt,
          previousTags: parent == null
              ? const <Map<String, dynamic>>[]
              : DemoArtworkData.tagsOf(DemoArtworkData.reviewOf(parent)),
          previousScore: parent == null
              ? null
              : DemoArtworkData.finalScoreOf(parent),
        );
        current.remove('seedReviewAt');
        final leaderId = DemoArtworkData.leaderIdFor(
          DemoArtworkData.text(current['teacherId']),
        );
        if (leaderId != null) {
          final reasons = DemoArtworkData.leadReasons(
            id: id,
            requested:
                DemoArtworkData.reviewOf(current)?['requestLeadReview'] == true,
            score: DemoArtworkData.reviewOf(current)?['score'] is num
                ? (DemoArtworkData.reviewOf(current)!['score'] as num)
                      .toDouble()
                : null,
            maxScore: DemoArtworkData.maxScoreOf(current),
            recentFinals: _recentFinalRatiosRaw(
              personIndex: DemoArtworkData.personOf(current),
              subject: DemoArtworkData.text(current['subject']),
              excludeId: id,
            ),
            content: DemoArtworkData.text(
              DemoArtworkData.reviewOf(current)?['content'],
            ),
            hasAnnotations: hasAnnotations(
              id,
              DemoArtworkData.text(current['teacherId']),
            ),
            spotCheckPercent: settings().spotCheckPercent,
          );
          if (reasons.isNotEmpty) {
            current['leadReview'] = <String, dynamic>{
              'reasons': reasons,
              'enteredTime': DemoArtworkData.fmt(reviewAt),
              'leaderId': leaderId,
              'action': null,
              'score': null,
              'reason': '',
              'content': '',
              'qualityStars': 0,
              'qualityNote': '',
              'time': '',
              'seedLeadAt': DemoArtworkData.fmt(
                reviewAt.add(DemoArtworkData.autoDelay),
              ),
            };
          }
        }
        overrides[id] = current;
        changed = true;
      }

      final lead = DemoArtworkData.leadOf(current);
      final leadAt = DemoArtworkData.parseTime(lead?['seedLeadAt']);
      if (lead != null &&
          DemoArtworkData.text(lead['action']).isEmpty &&
          leadAt != null &&
          !leadAt.isAfter(at) &&
          !DemoArtworkData.hasDemoAccount(
            DemoArtworkData.text(lead['leaderId']),
          )) {
        DemoArtworkSeed.autoLead(
          current,
          lead,
          at: leadAt,
          recentFinals: _recentFinalRatiosRaw(
            personIndex: DemoArtworkData.personOf(current),
            subject: DemoArtworkData.text(current['subject']),
            excludeId: id,
          ),
        );
        lead.remove('seedLeadAt');
        overrides[id] = current;
        changed = true;
      }
    }

    // 用户新交、责任老师没有演示账号：到点代点评。
    for (final entry in overrides.entries.toList()) {
      final current = entry.value;
      if (current is! Map) {
        continue;
      }
      final work = _clone(current);
      final reviewAt = DemoArtworkData.parseTime(work['seedReviewAt']);
      if (DemoArtworkData.isReviewed(work) ||
          reviewAt == null ||
          reviewAt.isAfter(at)) {
        continue;
      }
      if (DemoArtworkData.hasDemoAccount(
        DemoArtworkData.text(work['teacherId']),
      )) {
        continue;
      }
      // 种子作品已在上面处理；这里只处理纯差异里的新交作品。
      final inSeed = seed.works.any(
        (w) => DemoArtworkData.text(w['id']) == entry.key,
      );
      if (inSeed) {
        continue;
      }
      final parentId = DemoArtworkData.text(work['parentId']);
      final parent = parentId.isEmpty ? null : _workByIdRaw(parentId);
      work['review'] = DemoArtworkSeed.autoReview(
        work,
        at: reviewAt,
        previousTags: parent == null
            ? const <Map<String, dynamic>>[]
            : DemoArtworkData.tagsOf(DemoArtworkData.reviewOf(parent)),
        previousScore: parent == null
            ? null
            : DemoArtworkData.finalScoreOf(parent),
      );
      work.remove('seedReviewAt');
      final leaderId = DemoArtworkData.leaderIdFor(
        DemoArtworkData.text(work['teacherId']),
      );
      if (leaderId != null) {
        final reasons = DemoArtworkData.leadReasons(
          id: DemoArtworkData.text(work['id']),
          requested: work['review']?['requestLeadReview'] == true,
          score: work['review']?['score'] is num
              ? (work['review']['score'] as num).toDouble()
              : null,
          maxScore: DemoArtworkData.maxScoreOf(work),
          recentFinals: _recentFinalRatiosRaw(
            personIndex: DemoArtworkData.personOf(work),
            subject: DemoArtworkData.text(work['subject']),
            excludeId: DemoArtworkData.text(work['id']),
          ),
          content: DemoArtworkData.text(work['review']?['content']),
          hasAnnotations: false,
          spotCheckPercent: settings().spotCheckPercent,
        );
        if (reasons.isNotEmpty) {
          final autoLead = !DemoArtworkData.hasDemoAccount(leaderId);
          final lead = <String, dynamic>{
            'reasons': reasons,
            'enteredTime': DemoArtworkData.fmt(reviewAt),
            'leaderId': leaderId,
            'action': null,
            'score': null,
            'reason': '',
            'content': '',
            'qualityStars': 0,
            'qualityNote': '',
            'time': '',
            if (autoLead)
              'seedLeadAt': DemoArtworkData.fmt(
                reviewAt.add(DemoArtworkData.autoDelay),
              ),
          };
          work['leadReview'] = lead;
          if (autoLead &&
              !reviewAt.add(DemoArtworkData.autoDelay).isAfter(at)) {
            DemoArtworkSeed.autoLead(
              work,
              lead,
              at: reviewAt.add(DemoArtworkData.autoDelay),
              recentFinals: _recentFinalRatiosRaw(
                personIndex: DemoArtworkData.personOf(work),
                subject: DemoArtworkData.text(work['subject']),
                excludeId: DemoArtworkData.text(work['id']),
              ),
            );
            lead.remove('seedLeadAt');
          }
        }
      }
      overrides[entry.key] = work;
      changed = true;
      notifyStudentOfReview(work);
    }

    if (changed) {
      DemoStore.save(DemoArtworkData.worksKey);
    }
  }

  static Map<String, dynamic> _clone(Map raw) =>
      raw.map((k, v) => MapEntry(k.toString(), _cloneValue(v)));

  static Object? _cloneValue(Object? value) {
    if (value is Map) {
      return _clone(value);
    }
    if (value is List) {
      return <Object?>[for (final item in value) _cloneValue(item)];
    }
    return value;
  }

  static String _firstClause(String text) {
    final clause = text.split(RegExp('[。；;！？]')).first.trim();
    return clause.isEmpty ? text.trim() : clause;
  }

  static String _noticeTime(DateTime? event, Duration lag) {
    final base = event ?? now();
    final stamped = base.add(lag);
    final capped = stamped.isAfter(now()) ? now() : stamped;
    return DemoArtworkData.fmt(capped);
  }
}
