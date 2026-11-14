/// 作品点评链的统一读写入口：种子按「现在」生成且不落盘，写入只存差异，
/// 平台消息、首页与阅卷接口都从这里读。
///
/// 键名带 `v3`（见 [DemoArtworkData]）；旧的 `v2` 键不再读取。
library;

import 'dart:collection';

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
  static Map<String, Map<String, dynamic>>? _seedById;

  /// 每次写入加一。合并后的作品与作品、它们的索引，以及「下一次代办时间」都按它判断
  /// 是否过期。
  static int _revision = 0;
  static _Snapshot? _works;
  static _Snapshot? _tasks;

  /// 上一次扫描代点评、代复核时的写入版本和差异表，以及当时还没到点的最早一个时间。
  static int _autoRevision = -1;
  static Object? _autoSource;
  static DateTime? _autoNextDue;

  /// 测试用：合并种子与差异的次数。列表接口一次请求只该合并一次，不能逐条重新合并。
  static int debugMergeCount = 0;

  /// 测试用：被代点评、代复核改动过的作品累计份数。
  static int debugAutoApplied = 0;

  /// 测试注入「现在」；传 `null` 恢复 [DemoClock]。会清掉种子缓存，种子按新的时间重算。
  static void setNow(DateTime? value) {
    _nowOverride = value;
    clearCache();
  }

  /// 测试用：把「现在」拨到 [value]，种子不重算，用来模拟演示开着一段时间后代点评、
  /// 代复核陆续到点。
  static void advanceNow(DateTime value) {
    _nowOverride = value;
  }

  /// 清空种子缓存（「重置演示数据」后调用，下次按新的「现在」重算）。
  static void clearCache() {
    _seed = null;
    _seedById = null;
    _works = null;
    _tasks = null;
    _revision++;
  }

  static DateTime now() => _nowOverride ?? DemoClock.now();

  /// 同一次运行里复用首次生成的种子；跨天重启会重新进进程再生成。
  static DemoArtworkSeedResult _ensureSeed() =>
      _seed ??= DemoArtworkSeed.build(now());

  static Map<String, Map<String, dynamic>> _seedIndex() =>
      _seedById ??= <String, Map<String, dynamic>>{
        for (final work in _ensureSeed().works)
          DemoArtworkData.text(work['id']): work,
      };

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

  /// 把已经到点的代点评、代复核落下来（各个读取入口都会先调用，通常不需要单独调）。
  static void sync() => _applyAutoActions();

  /// 合并种子与差异后的全部作品（新的在前）；读取前先把到点的代点评、代复核落下来。
  ///
  /// 列表里的每份作品都是只读的（改它会抛错）。要改某份作品，用 [workById] 取一份
  /// 可写的副本，改完交给 [saveWork]。
  static List<Map<String, dynamic>> works() {
    _applyAutoActions();
    return List<Map<String, dynamic>>.of(_worksSnapshot().items);
  }

  /// 种子与差异合并后的只读快照。一千多份作品合并一次要几毫秒，列表接口又会逐条
  /// 查版本数和作品，所以按写入版本缓存，有写入才重新合并。
  static _Snapshot _worksSnapshot() {
    final overrides = _workOverrides();
    final cached = _works;
    if (cached != null && cached.fresh(_revision, overrides)) {
      return cached;
    }
    debugMergeCount++;
    final byId = <String, Map<String, dynamic>>{};
    for (final entry in _seedIndex().entries) {
      final override = overrides[entry.key];
      byId[entry.key] = _freeze(override is Map ? override : entry.value);
    }
    for (final entry in overrides.entries) {
      final value = entry.value;
      if (value is Map && !byId.containsKey(entry.key)) {
        byId[entry.key] = _freeze(value);
      }
    }
    final items = byId.values.toList()..sort(_newestFirst);
    final byRoot = <String, List<Map<String, dynamic>>>{};
    for (final work in items) {
      (byRoot[DemoArtworkData.rootOf(work)] ??= <Map<String, dynamic>>[]).add(
        work,
      );
    }
    for (final chain in byRoot.values) {
      if (chain.length > 1) {
        chain.sort(
          (a, b) => DemoArtworkData.versionOf(
            a,
          ).compareTo(DemoArtworkData.versionOf(b)),
        );
      }
    }
    return _works = _Snapshot(
      revision: _revision,
      source: overrides,
      items: items,
      byId: byId,
      byRoot: byRoot,
    );
  }

  static int _newestFirst(Map<String, dynamic> a, Map<String, dynamic> b) =>
      DemoArtworkData.text(
        b['createTime'],
      ).compareTo(DemoArtworkData.text(a['createTime']));

  /// 一份可写的副本；改完用 [saveWork] 存回去才生效。
  static Map<String, dynamic>? workById(String id) {
    final wanted = id.trim();
    if (wanted.isEmpty) {
      return null;
    }
    _applyAutoActions();
    final work = _worksSnapshot().byId[wanted];
    return work == null ? null : _clone(work);
  }

  /// 「种子 + 差异」里这份作品的当前状态，不拷贝、只读；代办扫描中途也能用。
  static Map<String, dynamic>? _currentById(String id) {
    final wanted = id.trim();
    if (wanted.isEmpty) {
      return null;
    }
    final override = _workOverrides()[wanted];
    return override is Map ? _typed(override) : _seedIndex()[wanted];
  }

  /// 不拷贝地遍历「种子 + 差异」的当前状态（只读）；代办扫描中途也能用。
  static Iterable<Map<String, dynamic>> _current() sync* {
    final overrides = _workOverrides();
    final seeded = _seedIndex();
    for (final entry in seeded.entries) {
      final override = overrides[entry.key];
      yield override is Map ? _typed(override) : entry.value;
    }
    for (final entry in overrides.entries) {
      final value = entry.value;
      if (value is Map && !seeded.containsKey(entry.key)) {
        yield _typed(value);
      }
    }
  }

  static Map<String, dynamic> _typed(Map raw) => raw is Map<String, dynamic>
      ? raw
      : raw.map((k, v) => MapEntry(k.toString(), v));

  /// 全部作品（新的在前），每条只读。
  static List<Map<String, dynamic>> tasks() =>
      List<Map<String, dynamic>>.of(_tasksSnapshot().items);

  static _Snapshot _tasksSnapshot() {
    final overrides = _taskOverrides();
    final cached = _tasks;
    if (cached != null && cached.fresh(_revision, overrides)) {
      return cached;
    }
    final byId = <String, Map<String, dynamic>>{};
    for (final task in _ensureSeed().tasks) {
      final id = DemoArtworkData.text(task['id']);
      final override = overrides[id];
      if (override == false) continue;
      byId[id] = _freeze(override is Map ? override : task);
    }
    for (final entry in overrides.entries) {
      final value = entry.value;
      if (value is Map && !byId.containsKey(entry.key)) {
        byId[entry.key] = _freeze(value);
      }
    }
    return _tasks = _Snapshot(
      revision: _revision,
      source: overrides,
      items: byId.values.toList()..sort(_newestFirst),
      byId: byId,
    );
  }

  /// 只读。
  static Map<String, dynamic>? taskById(String id) =>
      _tasksSnapshot().byId[id.trim()];

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
    _revision++;
    DemoStore.save(DemoArtworkData.worksKey);
  }

  static void saveTask(Map<String, dynamic> task) {
    final id = DemoArtworkData.text(task['id']);
    if (id.isEmpty) {
      return;
    }
    _taskOverrides()[id] = _clone(task);
    _revision++;
    DemoStore.save(DemoArtworkData.tasksKey);
  }

  static void deleteTask(String id) {
    _taskOverrides()[id] = false;
    _revision++;
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

  /// 同一条改画链上的全部版本（第 1 版在前），每份只读。
  static List<Map<String, dynamic>> versionsOf(Map<String, dynamic> work) {
    _applyAutoActions();
    final chain = _worksSnapshot().byRoot[DemoArtworkData.rootOf(work)];
    return chain == null
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.of(chain);
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
          DemoArtworkData.versionOf(work) >
              DemoArtworkData.versionOf(current)) {
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
        _current()
            .where(
              (w) =>
                  DemoArtworkData.personOf(w) == personIndex &&
                  DemoArtworkData.text(w['subject']) == subject &&
                  DemoArtworkData.text(w['id']) != excludeId &&
                  DemoArtworkData.isReviewed(w) &&
                  DemoArtworkData.finalScoreOf(w) != null,
            )
            .toList()
          ..sort(_newestFirst);
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
      'reviews': access.seesReview
          ? [
              for (final item in DemoArtworkData.reviewsOf(work))
                {
                  ...item,
                  'teacherName': DemoArtworkData.teacherName(
                    DemoArtworkData.text(item['teacherId']),
                  ),
                  'mine': viewer.teacherId == item['teacherId'],
                  'reviewed': true,
                  'annotations': strokesOf(
                    DemoArtworkData.text(work['id']),
                    DemoArtworkData.text(item['teacherId']),
                  ),
                },
            ]
          : <Map<String, dynamic>>[],
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
        for (final def in DemoArtworkData.dimensionsOf(
          DemoArtworkData.text(work['subject']),
        ))
          <String, dynamic>{'key': def.key, 'name': def.name},
      ],
      'overdue': DemoArtworkData.isOverdue(work, at, settings),
      'leadOverdue': DemoArtworkData.isLeadOverdue(work, at, settings),
      'access': <String, dynamic>{
        'canReview': access.canReview,
        'canSupplement': access.canSupplement,
        'canLeadReview':
            access.leader && DemoArtworkData.teacherStageComplete(work),
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
      'myReviewed': DemoArtworkData.reviewsOf(
        work,
      ).any((review) => review['teacherId'] == viewer.teacherId),
      'teacherCount': {
        teacherId,
        ...(work['teacherIds'] as List? ?? []),
        ...DemoArtworkData.reviewsOf(work).map((review) => review['teacherId']),
      }.length,
      'reviewedCount': DemoArtworkData.reviewsOf(work).length,
      'teacherMean': DemoArtworkData.teacherMeanOf(work),
      'requiredFullScore': DemoArtworkData.maxScoreOf(work),
    };
  }

  // ── 消息 ─────────────────────────────────────────────────────────────

  static const targetArtwork = 2;

  static String noticesKey(String userId) => 'notices:v2:$userId';

  /// 一个账号的完整消息种子（学情、校园、书刊等），由平台接口登记。没登记时（只起了
  /// 阅卷接口的测试）退回到只有作品消息的 [seedArtworkNotices]。
  static List<Map<String, dynamic>> Function(DemoAccount account)? noticeSeeder;

  /// 给某个用户追加一条消息；对方还没打开过消息列表时也能看到（先落种子再追加）。
  ///
  /// 「学生提交」「老师点评」这两种消息在种子里本来就有一条（最近一份待点评、最近一次
  /// 点评）。对方的列表如果是这一刻才按当前数据生成的，种子里那条说的就是同一件事，
  /// 这时传 [seedMayCover] 为 true，不再追加第二条。
  static void appendNotice({
    required String userId,
    required String content,
    int targetType = targetArtwork,
    String targetId = '',
    DateTime? time,
    bool seedMayCover = false,
  }) {
    if (userId.isEmpty || content.isEmpty) {
      return;
    }
    final key = noticesKey(userId);
    var seededNow = false;
    final list = DemoStore.list(key, () {
      seededNow = true;
      return seedNoticesForUserId(userId);
    });
    if (seedMayCover &&
        seededNow &&
        targetId.isNotEmpty &&
        list.any(
          (n) =>
              n['targetType'] == targetType &&
              '${n['targetId']}' == targetId &&
              n['read'] != true,
        )) {
      return;
    }
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
    final name = DemoArtworkData.studentName(DemoArtworkData.personOf(work));
    for (final teacherId in DemoArtworkData.assignedTeacherIdsOf(work)) {
      final userId = DemoArtworkData.userIdOfTeacher(teacherId);
      if (userId == null) continue;
      appendNotice(
        userId: userId,
        content: '【作品】$name提交了《${work['title']}》，请尽快点评。',
        targetId: DemoArtworkData.text(work['id']),
        seedMayCover: true,
      );
    }
  }

  static void notifyStudentOfReview(
    Map<String, dynamic> work, {
    String? reviewerId,
  }) {
    final userId = DemoArtworkData.userIdOfStudent(
      DemoArtworkData.personOf(work),
    );
    if (userId == null) return;
    final id = reviewerId ?? DemoArtworkData.text(work['teacherId']);
    final teacher = DemoArtworkData.teacherName(id);
    final review = DemoArtworkData.reviewsOf(
      work,
    ).where((r) => r['teacherId'] == id).firstOrNull;
    final clause = _firstClause(DemoArtworkData.text(review?['content']));
    appendNotice(
      userId: userId,
      content:
          '【作品】$teacher老师点评了你的《${work['title']}》'
          '${clause.isEmpty ? '，可以查看分数与评语。' : '：$clause。'}',
      targetId: DemoArtworkData.text(work['id']),
      seedMayCover: true,
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
          (a, b) =>
              DemoArtworkData.text(
                DemoArtworkData.reviewOf(b)?['reviewedTime'],
              ).compareTo(
                DemoArtworkData.text(
                  DemoArtworkData.reviewOf(a)?['reviewedTime'],
                ),
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

  /// [appendNotice] 在对方的消息列表尚未生成时用它生成：与对方自己打开消息时看到的
  /// 是同一份种子，不会因为先收到一条作品消息就少了其他消息。
  static List<Map<String, dynamic>> seedNoticesForUserId(String userId) {
    final account = DemoAccounts.all
        .where((a) => a.userId == userId)
        .firstOrNull;
    if (account == null) {
      return <Map<String, dynamic>>[];
    }
    return (noticeSeeder ?? seedArtworkNotices)(account);
  }

  // ── 无演示账号老师的代点评 / 代复核 ─────────────────────────────────

  /// 没有演示账号的老师、组长，由演示后端按固定时延代点评、代复核，链路不会卡住。
  ///
  /// 每次读取前都会调用，所以先不拷贝地扫一遍，只展开已经到点的作品；都没到点时
  /// 记下最近的一个时间，在那之前只要没有新的写入就直接返回。种子作品和用户新交的
  /// 作品走同一套流程。
  static void _applyAutoActions() {
    final overrides = _workOverrides();
    final at = now();
    final nextDue = _autoNextDue;
    if (_autoRevision == _revision &&
        identical(_autoSource, overrides) &&
        (nextDue == null || at.isBefore(nextDue))) {
      return;
    }

    final spotCheckPercent = settings().spotCheckPercent;
    // 消息放到扫描结束、状态落定之后再发：生成对方的消息种子时会回头读作品库。
    final notices = <void Function()>[];
    DateTime? upcoming;
    void waitFor(DateTime time) {
      if (upcoming == null || time.isBefore(upcoming!)) {
        upcoming = time;
      }
    }

    var changed = false;
    void visit(String id, Map<String, dynamic> source) {
      final reviewed = source['review'] is Map;
      DateTime? reviewAt;
      if (!reviewed) {
        reviewAt = DemoArtworkData.parseTime(source['seedReviewAt']);
        if (reviewAt != null &&
            DemoArtworkData.hasDemoAccount(
              DemoArtworkData.text(source['teacherId']),
            )) {
          // 有演示账号的老师自己来点评。
          reviewAt = null;
        }
      }
      final coTimes = DemoArtworkData.mapOf(source['seedCoReviewsAt']) ?? {};
      final coDue = <String>[];
      for (final entry in coTimes.entries) {
        final due = DemoArtworkData.parseTime(entry.value);
        if (due == null || DemoArtworkData.reviewedBy(source, entry.key)) {
          continue;
        }
        if (due.isAfter(at)) {
          waitFor(due);
        } else {
          coDue.add(entry.key);
        }
      }
      final leadAt = reviewed ? _autoLeadAt(source['leadReview']) : null;
      if (reviewAt == null && leadAt == null && coDue.isEmpty) {
        return;
      }
      final reviewDue = reviewAt != null && !reviewAt.isAfter(at);
      final leadDue = leadAt != null && !leadAt.isAfter(at);
      if (!reviewDue && !leadDue && coDue.isEmpty) {
        waitFor((reviewAt ?? leadAt)!);
        return;
      }

      final work = _clone(source);
      if (reviewAt != null && reviewDue) {
        _autoReview(work, reviewAt, spotCheckPercent);
        notices.add(() => notifyStudentOfReview(work));
      }
      for (final teacherId in coDue) {
        final due = DemoArtworkData.parseTime(coTimes[teacherId])!;
        final reviews = DemoArtworkData.mapsOf(work['teacherReviews']).toList();
        reviews.add(
          DemoArtworkSeed.autoReview({
            ...work,
            'teacherId': teacherId,
          }, at: due),
        );
        work['teacherReviews'] = reviews;
        coTimes.remove(teacherId);
        notices.add(() => notifyStudentOfReview(work, reviewerId: teacherId));
      }
      if (coDue.isNotEmpty) {
        work['seedCoReviewsAt'] = coTimes;
        final leaderId = DemoArtworkData.leaderOfSubject(
          DemoArtworkData.text(work['subject']),
        )?.id;
        if (DemoArtworkData.teacherStageComplete(work) &&
            work['leadReview'] == null &&
            leaderId != null) {
          work['leadReview'] = <String, dynamic>{
            'leaderId': leaderId,
            'enteredTime': DemoArtworkData.fmt(at),
            'reasons': <String>[],
            'action': null,
            'score': null,
            'content': '',
            'reason': '',
            'qualityStars': 0,
            'qualityNote': '',
            'time': '',
            if (!DemoArtworkData.hasDemoAccount(leaderId))
              'seedLeadAt': DemoArtworkData.fmt(
                at.add(DemoArtworkData.autoDelay),
              ),
          };
        }
      }
      // 复核记录可能是刚才代点评时生成的，也可能早就在等。
      final lead = work['leadReview'];
      final due = _autoLeadAt(lead);
      if (lead is Map<String, dynamic> && due != null) {
        if (due.isAfter(at)) {
          waitFor(due);
        } else {
          DemoArtworkSeed.autoLead(
            work,
            lead,
            at: due,
            recentFinals: _recentFinalRatiosRaw(
              personIndex: DemoArtworkData.personOf(work),
              subject: DemoArtworkData.text(work['subject']),
              excludeId: id,
            ),
          );
          lead.remove('seedLeadAt');
          notices.add(() => notifyLeadResult(work));
        }
      }
      overrides[id] = work;
      changed = true;
      debugAutoApplied++;
    }

    final seeded = _seedIndex();
    for (final entry in seeded.entries) {
      final override = overrides[entry.key];
      visit(entry.key, override is Map ? _typed(override) : entry.value);
    }
    for (final entry in overrides.entries.toList()) {
      final value = entry.value;
      if (value is Map && !seeded.containsKey(entry.key)) {
        visit(entry.key, _typed(value));
      }
    }

    if (changed) {
      _revision++;
      DemoStore.save(DemoArtworkData.worksKey);
    }
    _autoRevision = _revision;
    _autoSource = overrides;
    _autoNextDue = upcoming;
    for (final notify in notices) {
      notify();
    }
  }

  /// 这条复核记录等着后端代复核的时间；已经复核、或组长有演示账号（等本人来复核）
  /// 时为 null。
  static DateTime? _autoLeadAt(Object? lead) {
    if (lead is! Map || DemoArtworkData.text(lead['action']).isNotEmpty) {
      return null;
    }
    final at = DemoArtworkData.parseTime(lead['seedLeadAt']);
    if (at == null ||
        DemoArtworkData.hasDemoAccount(
          DemoArtworkData.text(lead['leaderId']),
        )) {
      return null;
    }
    return at;
  }

  /// 代点评：写入点评，并按规则判断是否进入复核池。
  static void _autoReview(
    Map<String, dynamic> work,
    DateTime reviewAt,
    int spotCheckPercent,
  ) {
    final id = DemoArtworkData.text(work['id']);
    final teacherId = DemoArtworkData.text(work['teacherId']);
    final parent = _currentById(DemoArtworkData.text(work['parentId']));
    final review = DemoArtworkSeed.autoReview(
      work,
      at: reviewAt,
      previousTags: parent == null
          ? const <Map<String, dynamic>>[]
          : DemoArtworkData.tagsOf(DemoArtworkData.reviewOf(parent)),
      previousScore: parent == null
          ? null
          : DemoArtworkData.finalScoreOf(parent),
    );
    work['review'] = review;
    work.remove('seedReviewAt');
    if (!DemoArtworkData.teacherStageComplete(work)) return;

    // 组长本人负责的作品不进复核池。
    final leaderId = DemoArtworkData.leaderIdFor(teacherId);
    if (leaderId == null) {
      return;
    }
    final score = review['score'];
    final reasons = DemoArtworkData.leadReasons(
      id: id,
      requested: review['requestLeadReview'] == true,
      score: score is num ? score.toDouble() : null,
      maxScore: DemoArtworkData.maxScoreOf(work),
      recentFinals: _recentFinalRatiosRaw(
        personIndex: DemoArtworkData.personOf(work),
        subject: DemoArtworkData.text(work['subject']),
        excludeId: id,
      ),
      content: DemoArtworkData.text(review['content']),
      hasAnnotations: hasAnnotations(id, teacherId),
      spotCheckPercent: spotCheckPercent,
    );
    if (reasons.isEmpty && work['teacherIds'] == null) return;
    work['leadReview'] = <String, dynamic>{
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
      if (!DemoArtworkData.hasDemoAccount(leaderId))
        'seedLeadAt': DemoArtworkData.fmt(
          reviewAt.add(DemoArtworkData.autoDelay),
        ),
    };
  }

  /// 深拷贝成只读结构：快照里的作品被误改时立刻抛错，而不是悄悄改坏缓存。
  static Map<String, dynamic> _freeze(Map raw) =>
      UnmodifiableMapView<String, dynamic>(<String, dynamic>{
        for (final entry in raw.entries)
          entry.key.toString(): _freezeValue(entry.value),
      });

  static Object? _freezeValue(Object? value) {
    if (value is Map) {
      return _freeze(value);
    }
    if (value is List) {
      return UnmodifiableListView<Object?>(<Object?>[
        for (final item in value) _freezeValue(item),
      ]);
    }
    return value;
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

/// 种子与差异合并后的只读快照，带按 id、按改画链的索引。
class _Snapshot {
  _Snapshot({
    required this.revision,
    required this.source,
    required this.items,
    required this.byId,
    this.byRoot = const <String, List<Map<String, dynamic>>>{},
  });

  /// 合并时的写入版本。
  final int revision;

  /// 合并时用的差异表。「重置演示数据」后 [DemoStore] 会换一张新表，据此判断过期。
  final Map<String, dynamic> source;

  /// 新的在前。
  final List<Map<String, dynamic>> items;
  final Map<String, Map<String, dynamic>> byId;

  /// 改画链：根作品 id → 各版本（第 1 版在前）。
  final Map<String, List<Map<String, dynamic>>> byRoot;

  bool fresh(int revision, Map<String, dynamic> source) =>
      this.revision == revision && identical(this.source, source);
}
