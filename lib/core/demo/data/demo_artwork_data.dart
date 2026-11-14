/// 作品点评链演示数据的定义与规则：责任老师点评 → 组长复核 → 校长点评与推优，
/// 加上改画版本、分项评价和作业关联（口径见 `docs/美育集3.0实施规格.md` 第 1、2 节）。
///
/// 一份作品：
/// ```
/// id, rootId, version(1 起), parentId(上一版 id，没有为空)
/// personIndex, title, subject, drawingDate, createTime, description,
/// images[{id, ref}], taskId(自主练习为空), teacherId(责任老师)
/// review: null | {teacherId, score|null, maxScore, content, reviewedTime,
///   dimensions{key: 1..5}, tags[{id, name, explanation, color, dimension}],
///   voiceRef, voiceSeconds, requestLeadReview, tagResolutions[{tag, resolved}]}
/// supplements[{teacherId, content, time}]
/// leadReview: null | {reasons[], enteredTime, leaderId, action: null|KEEP|ADJUST|
///   SUPPLEMENT, score, reason, content, qualityStars, qualityNote, time}
/// principalComments[{id, userId, name, content, time}]
/// featured, featuredTime, featuredBy
/// ```
/// 状态、最终分、是否超时与时间线不落盘，读取时由本文件里的规则计算。
/// 种子见 `demo_artwork_seed.dart`，读写入口见 `demo_artwork_store.dart`。
library;

import '../demo_accounts.dart';
import 'demo_campus_data.dart';
import 'demo_marking_data.dart';

class DemoDimensionDef {
  const DemoDimensionDef(this.key, this.name);

  final String key;
  final String name;
}

/// 点评设置：抽查比例与两个时限，教务可改。
class DemoReviewSettings {
  const DemoReviewSettings({
    this.spotCheckPercent = 20,
    this.reviewHours = 24,
    this.leadHours = 48,
  });

  factory DemoReviewSettings.fromMap(Map<String, dynamic> map) {
    int read(String key, int fallback) {
      final value = map[key];
      return value is num ? value.toInt() : fallback;
    }

    return DemoReviewSettings(
      spotCheckPercent: read('spotCheckPercent', 20),
      reviewHours: read('reviewHours', 24),
      leadHours: read('leadHours', 48),
    );
  }

  /// 抽查比例（百分数，10–50）。
  final int spotCheckPercent;

  /// 点评时限：从提交算起的小时数。
  final int reviewHours;

  /// 复核时限：从进入复核池算起的小时数。
  final int leadHours;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'spotCheckPercent': spotCheckPercent,
    'reviewHours': reviewHours,
    'leadHours': leadHours,
  };
}

/// 查看者与一份作品的关系，决定能看到什么、能做什么（规格 2.2 的可见范围表）。
class DemoArtworkAccess {
  const DemoArtworkAccess({
    this.owner = false,
    this.responsible = false,
    this.leader = false,
    this.principal = false,
    this.admin = false,
    this.headTeacher = false,
    this.artTeacher = false,
  });

  /// 提交这份作品的学生本人。
  final bool owner;

  /// 责任老师。
  final bool responsible;

  /// 这份作品所在科目组的组长。
  final bool leader;
  final bool principal;
  final bool admin;

  /// 学生所在班级的班主任。
  final bool headTeacher;

  /// 查看者是美术科目老师（可以补充点评）。
  final bool artTeacher;

  bool get staff => responsible || leader || principal || admin || headTeacher;

  bool get canRead => owner || staff;

  /// 老师点评（分数、分项、标签、评语、批注、语音）。
  bool get seesReview => canRead;

  /// 进入复核的原因：学生和班主任看不到，只知道「复核中」。
  bool get seesLeadReasons => responsible || leader || principal || admin;

  /// 复核结果（维持 / 调分及理由 / 补充评语）。
  bool get seesLeadResult => canRead;

  /// 点评质量星级与意见：老师本人、组长、校长与管理员。
  bool get seesQuality => responsible || leader || principal || admin;

  /// 校长点评与优秀作品标记。
  bool get seesPrincipal => canRead;

  bool get canReview => responsible;

  /// 非责任老师的补充点评，不计分。
  bool get canSupplement => artTeacher && !responsible;

  /// 校长可以点评和推优，不改分；管理员只读。
  bool get canComment => principal;
  bool get canFeature => principal;
}

abstract final class DemoArtworkData {
  // v3：点评链数据模型，旧的 v2 键不再读取。
  static const worksKey = 'artworks:v3';
  static const tasksKey = 'artwork_tasks:v3';
  static const annotationsKey = 'artwork_annotations:v3';
  static const uploadsKey = 'artwork_uploads:v3';
  static const settingsKey = 'review_settings:v3';

  static String tagsKey(String teacherId) => 'artwork_tags:v3:$teacherId';

  static const statusReviewed = 'REVIEWED';
  static const statusPending = 'PENDING';

  static const leadNone = 'NONE';
  static const leadInReview = 'IN_REVIEW';
  static const leadDone = 'DONE';

  static const reasonRequested = 'REQUESTED';
  static const reasonScoreAnomaly = 'SCORE_ANOMALY';
  static const reasonBrief = 'BRIEF';
  static const reasonSpotCheck = 'SPOT_CHECK';
  static const reasons = <String>[
    reasonRequested,
    reasonScoreAnomaly,
    reasonBrief,
    reasonSpotCheck,
  ];

  static const actionKeep = 'KEEP';
  static const actionAdjust = 'ADJUST';
  static const actionSupplement = 'SUPPLEMENT';
  static const actions = <String>[actionKeep, actionAdjust, actionSupplement];

  /// 分数异常：与最近同科最终分均值的差不少于满分的 15%。
  static const anomalyRatio = 0.15;

  /// 分数异常至少要有的历史次数，以及参与均值的最近次数。
  static const anomalyMinHistory = 2;
  static const anomalyHistory = 5;

  /// 点评过简：评语少于 20 字且没有批注。
  static const briefLength = 20;

  /// 调分理由的最少字数。
  static const adjustReasonLength = 10;

  /// 没有演示账号的老师、组长由演示后端代为处理的固定时延。
  static const autoDelay = Duration(seconds: 60);

  static const subjects = <String>['素描', '色彩', '速写'];

  // ── 时间 ─────────────────────────────────────────────────────────────

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String fmt(DateTime d) =>
      '${ymd(d)} ${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  static DateTime? parseTime(Object? raw) {
    final value = text(raw);
    return value.isEmpty ? null : DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 画室周日休息，不上课、不交作品，也不计入点评与复核的时限。
  static bool isSchoolDay(DateTime d) => d.weekday != DateTime.sunday;

  /// [start] 之后 [hours] 小时的截止时刻；周日整天不计时。
  static DateTime deadline(DateTime start, int hours) {
    var at = start;
    var remaining = Duration(hours: hours);
    while (true) {
      if (!isSchoolDay(at)) {
        at = DateTime(at.year, at.month, at.day + 1);
        continue;
      }
      final nextSunday = DateTime(
        at.year,
        at.month,
        at.day + (DateTime.sunday - at.weekday),
      );
      final available = nextSunday.difference(at);
      if (remaining <= available) {
        return at.add(remaining);
      }
      remaining -= available;
      at = DateTime(nextSunday.year, nextSunday.month, nextSunday.day + 1);
    }
  }

  // ── 读取工具（兼容种子数据与 JSON 往返后的结构） ─────────────────────

  static String text(Object? value) {
    final result = value?.toString().trim() ?? '';
    return result == 'null' ? '' : result;
  }

  static Map<String, dynamic>? mapOf(Object? raw) =>
      raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v)) : null;

  static List<Map<String, dynamic>> mapsOf(Object? raw) {
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[
      for (final item in raw)
        if (item is Map) item.map((k, v) => MapEntry(k.toString(), v)),
    ];
  }

  static Map<String, dynamic>? reviewOf(Map<String, dynamic> work) =>
      mapOf(work['review']);

  static Map<String, dynamic>? leadOf(Map<String, dynamic> work) =>
      mapOf(work['leadReview']);

  static List<Map<String, dynamic>> imagesOf(Map<String, dynamic> work) =>
      mapsOf(work['images']);

  static List<Map<String, dynamic>> tagsOf(Map<String, dynamic>? review) =>
      mapsOf(review?['tags']);

  static List<Map<String, dynamic>> supplementsOf(Map<String, dynamic> work) =>
      mapsOf(work['supplements']);

  static List<Map<String, dynamic>> principalCommentsOf(
    Map<String, dynamic> work,
  ) => mapsOf(work['principalComments']);

  static int personOf(Map<String, dynamic> work) =>
      (work['personIndex'] as num?)?.toInt() ?? 0;

  static int versionOf(Map<String, dynamic> work) =>
      (work['version'] as num?)?.toInt() ?? 1;

  static String rootOf(Map<String, dynamic> work) {
    final root = text(work['rootId']);
    return root.isEmpty ? text(work['id']) : root;
  }

  static double round2(double value) => (value * 100).round() / 100;

  // ── 状态（读取时计算） ───────────────────────────────────────────────

  // 下面几个判断在列表筛选里逐条调用，直接读字段，不经 [reviewOf] / [leadOf]
  // 拷贝一份。
  static String statusOf(Map<String, dynamic> work) =>
      isReviewed(work) ? statusReviewed : statusPending;

  static bool isReviewed(Map<String, dynamic> work) => work['review'] is Map;

  static String leadStatusOf(Map<String, dynamic> work) {
    final lead = work['leadReview'];
    if (lead is! Map || !isReviewed(work)) {
      return leadNone;
    }
    return text(lead['action']).isEmpty ? leadInReview : leadDone;
  }

  /// 组长调分后取组长的分数，否则取责任老师的分数；未点评或没有打分时为 null。
  static double? finalScoreOf(Map<String, dynamic> work) {
    final review = work['review'];
    if (review is! Map) {
      return null;
    }
    final lead = work['leadReview'];
    if (lead is Map &&
        text(lead['action']) == actionAdjust &&
        lead['score'] is num) {
      return (lead['score'] as num).toDouble();
    }
    final score = review['score'];
    return score is num ? score.toDouble() : null;
  }

  static double maxScoreOf(Map<String, dynamic> work) {
    final review = work['review'];
    final max = review is Map ? review['maxScore'] : null;
    return max is num && max > 0 ? max.toDouble() : 100;
  }

  /// 待点评且提交超过点评时限。
  static bool isOverdue(
    Map<String, dynamic> work,
    DateTime now,
    DemoReviewSettings settings,
  ) {
    if (isReviewed(work)) {
      return false;
    }
    final created = parseTime(work['createTime']);
    return created != null &&
        now.isAfter(deadline(created, settings.reviewHours));
  }

  /// 复核中且进入复核池超过复核时限。
  static bool isLeadOverdue(
    Map<String, dynamic> work,
    DateTime now,
    DemoReviewSettings settings,
  ) {
    if (leadStatusOf(work) != leadInReview) {
      return false;
    }
    final entered = parseTime(leadOf(work)?['enteredTime']);
    return entered != null &&
        now.isAfter(deadline(entered, settings.leadHours));
  }

  // ── 进入复核池的规则 ─────────────────────────────────────────────────

  /// 字符串的 32 位固定散列（FNV-1a）：各端结果一致，不随运行平台变化。
  static int hash32(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash = (hash ^ unit) & 0xFFFFFFFF;
      // 32 位乘法拆成高低 16 位，Web 端也不会丢精度。
      hash =
          ((hash & 0xFFFF) * 0x01000193 +
              ((((hash >>> 16) * 0x01000193) & 0xFFFF) << 16)) &
          0xFFFFFFFF;
    }
    return hash;
  }

  /// 作品 id 的固定散列值（0–99），与抽查比例比较。
  static int spotHash(String id) => hash32(id) % 100;

  static bool isSpotChecked(String id, int percent) => spotHash(id) < percent;

  /// 老师保存点评时判断是否进入复核池：满足任一条即进入，返回全部命中的原因。
  ///
  /// [recentFinals] 是该生此前同科作品的最终分占满分的比例（0–1），新的在前。
  static List<String> leadReasons({
    required String id,
    required bool requested,
    required double? score,
    required double maxScore,
    required List<double> recentFinals,
    required String content,
    required bool hasAnnotations,
    required int spotCheckPercent,
  }) {
    final result = <String>[];
    if (requested) {
      result.add(reasonRequested);
    }
    if (score != null &&
        maxScore > 0 &&
        recentFinals.length >= anomalyMinHistory) {
      final recent = recentFinals.take(anomalyHistory).toList();
      final mean = recent.reduce((a, b) => a + b) / recent.length;
      if ((score / maxScore - mean).abs() >= anomalyRatio - 1e-9) {
        result.add(reasonScoreAnomaly);
      }
    }
    if (content.trim().runes.length < briefLength && !hasAnnotations) {
      result.add(reasonBrief);
    }
    if (isSpotChecked(id, spotCheckPercent)) {
      result.add(reasonSpotCheck);
    }
    return result;
  }

  // ── 老师、班级与责任 ─────────────────────────────────────────────────

  static DemoTeacher? teacherOf(String teacherId) {
    for (final teacher in DemoMarkingData.reviewTeachers) {
      if (teacher.id == teacherId) {
        return teacher;
      }
    }
    return null;
  }

  static bool isReviewTeacher(String teacherId) => teacherOf(teacherId) != null;

  static String teacherName(String teacherId) =>
      teacherOf(teacherId)?.name ??
      DemoCampusData.staffById(teacherId)?.name ??
      '老师';

  /// 科目组的组长。
  static DemoTeacher? leaderOfSubject(String subject) {
    for (final teacher in DemoMarkingData.reviewTeachers) {
      if (teacher.leader && teacher.subject == subject) {
        return teacher;
      }
    }
    return null;
  }

  /// 负责复核 [teacherId] 的组长；组长本人负责的作品不进复核池，返回 null。
  static String? leaderIdFor(String teacherId) {
    final teacher = teacherOf(teacherId);
    if (teacher == null || teacher.leader) {
      return null;
    }
    return leaderOfSubject(teacher.subject)?.id;
  }

  /// 有演示账号、需要演示的人亲自操作的老师。
  static bool hasDemoAccount(String teacherId) => DemoAccounts.all.any(
    (account) => account.role.teaches && account.teacherId == teacherId,
  );

  /// 在校学生：38 号休学，不交作品。
  static bool isActiveStudent(int personIndex) => personIndex != 38;

  static DemoCampusClass classOf(int personIndex) =>
      DemoCampusData.classOfPerson(personIndex);

  /// 责任老师 = 班级该科目的任课老师（按课表）；其他科目归到素描老师名下。
  static String responsibleTeacherId(String classId, String subject) {
    final slots = DemoCampusData.timetableOf(classId);
    for (final wanted in <String>[subject, '素描']) {
      for (final slot in slots) {
        if (slot.courseName == wanted) {
          return slot.teacherId;
        }
      }
    }
    return 't-1';
  }

  /// 平台用户 id（只有带演示账号的人才收得到消息）。
  static String? userIdOfTeacher(String teacherId) {
    final userId = DemoCampusData.staffById(teacherId)?.userId;
    if (userId == null) {
      return null;
    }
    return DemoAccounts.all.any((a) => a.userId == userId) ? userId : null;
  }

  static String? userIdOfStudent(int personIndex) =>
      personIndex == DemoAccounts.student.personIndex
      ? DemoAccounts.student.userId
      : null;

  static String studentName(int personIndex) {
    for (final person in DemoMarkingData.instance.persons) {
      if (person.index == personIndex) {
        return person.name;
      }
    }
    return '学生';
  }

  /// 查看者与作品的关系（规格 2.2）。
  static DemoArtworkAccess accessOf(
    DemoAccount viewer,
    Map<String, dynamic> work,
  ) {
    final role = viewer.role;
    final person = personOf(work);
    if (role == DemoRole.student) {
      return DemoArtworkAccess(owner: viewer.personIndex == person);
    }
    final teacherId = text(work['teacherId']);
    final viewerTeacher = viewer.teacherId ?? '';
    final group = teacherOf(teacherId)?.subject ?? '';
    final headTeacherId = person > 0 && person <= 40
        ? classOf(person).headTeacherId
        : '';
    return DemoArtworkAccess(
      responsible: viewerTeacher.isNotEmpty && viewerTeacher == teacherId,
      leader: group.isNotEmpty && viewer.groupLeaderSubjects.contains(group),
      principal: role == DemoRole.principal,
      admin: role == DemoRole.admin,
      headTeacher: viewerTeacher.isNotEmpty && viewerTeacher == headTeacherId,
      artTeacher: isReviewTeacher(viewerTeacher),
    );
  }

  // ── 分项 ─────────────────────────────────────────────────────────────

  static const levelLabels = <String>['待加强', '一般', '合格', '良好', '优秀'];

  static const _dimensions = <String, List<DemoDimensionDef>>{
    '素描': [
      DemoDimensionDef('composition', '构图'),
      DemoDimensionDef('form', '造型'),
      DemoDimensionDef('value', '明暗'),
      DemoDimensionDef('rendering', '刻画'),
    ],
    '色彩': [
      DemoDimensionDef('composition', '构图'),
      DemoDimensionDef('form', '造型'),
      DemoDimensionDef('color', '色彩关系'),
      DemoDimensionDef('rendering', '刻画'),
    ],
    '速写': [
      DemoDimensionDef('composition', '构图'),
      DemoDimensionDef('gesture', '比例动态'),
      DemoDimensionDef('line', '线条'),
      DemoDimensionDef('rendering', '刻画'),
    ],
  };

  /// 科目的四项分项；三科以外的自定义科目没有分项。
  static List<DemoDimensionDef> dimensionsOf(String subject) =>
      _dimensions[subject] ?? const <DemoDimensionDef>[];

  // ── 时间线 ───────────────────────────────────────────────────────────

  /// 按时间排的事件：提交、点评、补充点评、复核、校长点评、推优。
  /// 复核原因与质量星级不进时间线，由各端按可见范围单独返回。
  static List<Map<String, dynamic>> timelineOf(Map<String, dynamic> work) {
    final events = <Map<String, dynamic>>[];
    Map<String, dynamic> event(
      String role,
      String type,
      String name,
      Object? time, {
      String content = '',
      Object? score,
      Object? fromScore,
      Object? toScore,
    }) => <String, dynamic>{
      'role': role,
      'type': type,
      'name': name,
      'time': text(time),
      'content': content,
      'score': score is num ? score.toDouble() : null,
      'fromScore': fromScore is num ? fromScore.toDouble() : null,
      'toScore': toScore is num ? toScore.toDouble() : null,
    };

    final version = versionOf(work);
    events.add(
      event(
        'STUDENT',
        'SUBMIT',
        studentName(personOf(work)),
        work['createTime'],
        content: version > 1 ? '改画重交，第 $version 版' : '提交作品',
      ),
    );
    final review = reviewOf(work);
    if (review != null) {
      events.add(
        event(
          'TEACHER',
          'REVIEW',
          teacherName(text(review['teacherId'])),
          review['reviewedTime'],
          content: text(review['content']),
          score: review['score'],
        ),
      );
      for (final item in supplementsOf(work)) {
        events.add(
          event(
            'TEACHER',
            'SUPPLEMENT',
            teacherName(text(item['teacherId'])),
            item['time'],
            content: text(item['content']),
          ),
        );
      }
      final lead = leadOf(work);
      final action = text(lead?['action']);
      if (lead != null && action.isNotEmpty) {
        final leader = teacherName(text(lead['leaderId']));
        switch (action) {
          case actionAdjust:
            events.add(
              event(
                'LEADER',
                'LEAD_ADJUST',
                leader,
                lead['time'],
                content: text(lead['reason']),
                score: lead['score'],
                fromScore: review['score'],
                toScore: lead['score'],
              ),
            );
          case actionSupplement:
            events.add(
              event(
                'LEADER',
                'LEAD_SUPPLEMENT',
                leader,
                lead['time'],
                content: text(lead['content']),
              ),
            );
          default:
            events.add(
              event(
                'LEADER',
                'LEAD_KEEP',
                leader,
                lead['time'],
                content: text(lead['content']),
                score: review['score'],
              ),
            );
        }
      }
    }
    for (final comment in principalCommentsOf(work)) {
      events.add(
        event(
          'PRINCIPAL',
          'PRINCIPAL_COMMENT',
          text(comment['name']),
          comment['time'],
          content: text(comment['content']),
        ),
      );
    }
    if (work['featured'] == true) {
      events.add(
        event(
          'PRINCIPAL',
          'FEATURE',
          text(work['featuredBy']),
          work['featuredTime'],
          content: '推荐到优秀作品墙',
        ),
      );
    }
    // 同一时刻的事件保持上面的先后顺序。
    final indexed = <(int, Map<String, dynamic>)>[
      for (var i = 0; i < events.length; i++) (i, events[i]),
    ];
    indexed.sort((a, b) {
      final byTime = text(a.$2['time']).compareTo(text(b.$2['time']));
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
    return <Map<String, dynamic>>[for (final item in indexed) item.$2];
  }

  // ── 标签 ─────────────────────────────────────────────────────────────

  /// 点评标签两类，接口以颜色区分：亮点绿色，问题琥珀色（与 `ArtworkRules` 一致）。
  static const highlightColor = '#3B9A6E';
  static const problemColor = '#B9770F';

  static bool isHighlightTag(String name, String color) =>
      color.toUpperCase() == highlightColor || name == '细节出彩';

  static String tagId(String teacherId, int index) => '$teacherId-tag-$index';

  /// 名称、解释、颜色、所属分项（可为空）。
  static const standardTags = <(String, String, String, String)>[
    (
      '结构错误',
      '形体比例或透视关系不准确。先用辅助线核对大的比例和骨点位置，再深入刻画。',
      problemColor,
      'form',
    ),
    (
      '明暗层次弱',
      '黑白灰关系没有拉开，暗部与亮部之间的过渡层次不足，画面显得发平。',
      problemColor,
      'value',
    ),
    (
      '构图失衡',
      '主体位置或大小不合适，画面重心偏移。动笔前先用小构图推敲布局。',
      problemColor,
      'composition',
    ),
    (
      '线条生硬',
      '线条缺少轻重、虚实变化，转折处可以更有节奏，避免描边式的均匀线条。',
      problemColor,
      'line',
    ),
    (
      '色调不统一',
      '画面冷暖倾向不明确，局部颜色跳出整体色调，注意环境色的相互影响。',
      problemColor,
      'color',
    ),
    ('细节出彩', '局部刻画深入到位，质感与空间表现准确，值得在后续作品中保持。', highlightColor, 'rendering'),
    ('透视错误', '近大远小和消失点不统一，先确定视平线和主要透视线再起形。', problemColor, 'form'),
  ];

  /// 各老师自己加的标签（序号 8）。
  static const exclusiveTags = <String, (String, String, String, String)>{
    't-2': ('暗部偏闷', '暗部笔触过于平涂，缺少反光和细微变化。', problemColor, 'value'),
    't-3': ('环境色不足', '物体暗部和投影缺少周围环境色的影响，颜色显得孤立。', problemColor, 'color'),
    't-4': (
      '动态僵硬',
      '人物重心和动势不明确，动作像摆拍，先用几根动态线确定姿态。',
      problemColor,
      'gesture',
    ),
    't-5': ('画面偏灰', '颜色纯度不足，亮部和暗部都偏灰，注意保留色彩的饱和度。', problemColor, 'color'),
    't-6': ('比例失调', '头身比例或四肢长短不准，先定头顶、脚底和重心线。', problemColor, 'gesture'),
  };

  static List<(String, String, String, String)> tagDefs(String teacherId) =>
      <(String, String, String, String)>[
        ...standardTags,
        ?exclusiveTags[teacherId],
      ];

  /// 点评里保存的标签快照（序号从 1 开始）。
  static Map<String, dynamic>? tagSnapshot(String teacherId, int index) {
    final defs = tagDefs(teacherId);
    if (index < 1 || index > defs.length) {
      return null;
    }
    final def = defs[index - 1];
    return <String, dynamic>{
      'id': tagId(teacherId, index),
      'name': def.$1,
      'explanation': def.$2,
      'color': def.$3,
      'dimension': def.$4,
    };
  }

  /// 演示前的历史用量（这些老师此前点评过的作品不在演示列表里）。
  static const _historyUsage = <int>[12, 9, 5, 8, 4, 7, 3, 2];

  /// 老师的标签库；用量 = 历史用量 + 在 [works] 里的使用次数。
  static List<Map<String, dynamic>> seedTags(
    String teacherId,
    List<Map<String, dynamic>> works,
  ) {
    final defs = tagDefs(teacherId);
    final history = isReviewTeacher(teacherId);
    final used = <String, int>{};
    if (history) {
      for (final work in works) {
        final review = reviewOf(work);
        if (review == null || text(review['teacherId']) != teacherId) {
          continue;
        }
        for (final tag in tagsOf(review)) {
          final id = text(tag['id']);
          used[id] = (used[id] ?? 0) + 1;
        }
      }
    }
    return <Map<String, dynamic>>[
      for (var i = 0; i < defs.length; i++)
        <String, dynamic>{
          'id': tagId(teacherId, i + 1),
          'name': defs[i].$1,
          'explanation': defs[i].$2,
          'color': defs[i].$3,
          'dimension': defs[i].$4,
          'usageCount': history
              ? _historyUsage[i] + (used[tagId(teacherId, i + 1)] ?? 0)
              : 0,
        },
    ];
  }

  // ── 点评小结 ─────────────────────────────────────────────────────────

  /// 标签对应的练习建议：建议文字、范画科目、范画关键词、工具箱工具。
  static const _advice = <String, (String, String, String, String)>{
    '结构错误': ('起形时用辅助线核对比例和骨点，完成后镜像翻转检查形准。', '素描', '结构', '镜像'),
    '明暗层次弱': ('眯眼概括黑白灰三大关系，先拉开明暗交界线两侧的对比。', '素描', '明暗', '明度检查'),
    '构图失衡': ('动笔前先画 2–3 个小构图，确定主体的位置与大小。', '素描', '构图', '构图网格'),
    '线条生硬': ('多练长线条的轻重虚实，衣纹注意疏密与节奏。', '速写', '线条', '速写计时'),
    '色调不统一': ('先定整体色调，再用环境色统一画面的冷暖关系。', '色彩', '色调', '取色色卡'),
    '透视错误': ('先确定视平线和消失点，椭圆注意近宽远窄的透视变化。', '素描', '透视', '透视辅助'),
    '环境色不足': ('暗部与投影里加入周围的环境色，让物体融入空间。', '色彩', '环境色', '取色色卡'),
    '暗部偏闷': ('暗部加入反光与冷暖变化，避免一遍平涂。', '素描', '暗部', '明度检查'),
    '动态僵硬': ('先用几根动态线确定重心与动势，再刻画细节。', '速写', '动态', '速写计时'),
    '画面偏灰': ('提高亮部颜色的纯度，暗部用补色调暗而不是加黑。', '色彩', '色调', '冷暖'),
    '比例失调': ('先定头顶、脚底和重心线，再用头长去量全身比例。', '速写', '比例', '人体比例'),
  };

  /// 学生的点评小结：高频问题、练习建议、分项水平、问题解决率、连续练习天数与
  /// 近 7 天提交数。分数与标签只统计已点评的作品。
  ///
  /// 问题解决率 = 改画时被标为「已改善」的问题标签数 ÷ 改画时逐个标记过的问题标签数。
  static Map<String, dynamic> insightsOf(
    List<Map<String, dynamic>> works,
    DateTime now,
  ) {
    final stats = <String, _TagStat>{};
    final subjectScores = <String, List<double>>{};
    final finals = <double>[];
    var reviewedCount = 0;
    var problemTags = 0;
    var markedTags = 0;
    var resolvedTags = 0;
    final reviewed = <Map<String, dynamic>>[];
    for (final work in works) {
      final review = reviewOf(work);
      if (review == null) {
        continue;
      }
      reviewed.add(work);
      reviewedCount++;
      final subject = text(work['subject']);
      final score = finalScoreOf(work);
      if (score != null) {
        final percent = score / maxScoreOf(work) * 100;
        finals.add(percent);
        subjectScores.putIfAbsent(subject, () => <double>[]).add(percent);
      }
      final time = text(review['reviewedTime']);
      for (final tag in tagsOf(review)) {
        final name = text(tag['name']);
        if (name.isEmpty) {
          continue;
        }
        final color = text(tag['color']);
        if (!isHighlightTag(name, color)) {
          problemTags++;
        }
        final stat = stats.putIfAbsent(name, () => _TagStat(name));
        stat.count++;
        stat.subjects[subject] = (stat.subjects[subject] ?? 0) + 1;
        if (time.compareTo(stat.latest) >= 0) {
          stat.latest = time;
          stat.color = color;
          stat.explanation = text(tag['explanation']);
        }
      }
      for (final item in mapsOf(review['tagResolutions'])) {
        markedTags++;
        if (item['resolved'] == true) {
          resolvedTags++;
          stats[text(item['tag'])]?.resolved++;
        }
      }
    }
    final ranked = stats.values.toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : b.latest.compareTo(a.latest);
      });

    final means = <String, double>{
      for (final entry in subjectScores.entries)
        entry.key: round2(
          entry.value.reduce((a, b) => a + b) / entry.value.length,
        ),
    };
    final bySubject = means.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 分项水平：每科最近 10 份已点评作品的分项等级均值。
    reviewed.sort(
      (a, b) => text(
        reviewOf(b)?['reviewedTime'],
      ).compareTo(text(reviewOf(a)?['reviewedTime'])),
    );
    final dimensionLevels = <Map<String, dynamic>>[];
    for (final subject in subjects) {
      final defs = dimensionsOf(subject);
      final sums = <String, double>{};
      final counts = <String, int>{};
      var samples = 0;
      for (final work in reviewed) {
        if (text(work['subject']) != subject) {
          continue;
        }
        final dims = mapOf(reviewOf(work)?['dimensions']);
        if (dims == null || dims.isEmpty) {
          continue;
        }
        if (samples >= 10) {
          break;
        }
        samples++;
        for (final def in defs) {
          final level = dims[def.key];
          if (level is num) {
            sums[def.key] = (sums[def.key] ?? 0) + level;
            counts[def.key] = (counts[def.key] ?? 0) + 1;
          }
        }
      }
      if (samples == 0) {
        continue;
      }
      dimensionLevels.add(<String, dynamic>{
        'subject': subject,
        'sampleCount': samples,
        'items': <Map<String, dynamic>>[
          for (final def in defs)
            <String, dynamic>{
              'key': def.key,
              'name': def.name,
              'level': counts[def.key] == null
                  ? null
                  : round2(sums[def.key]! / counts[def.key]!),
            },
        ],
      });
    }

    return <String, dynamic>{
      'reviewedCount': reviewedCount,
      'averageScore': finals.isEmpty
          ? null
          : round2(finals.reduce((a, b) => a + b) / finals.length),
      'bestSubject': bySubject.isEmpty ? '' : bySubject.first.key,
      'weakestSubject': bySubject.length < 2 ? '' : bySubject.last.key,
      'topTags': <Map<String, dynamic>>[
        for (final stat in ranked.take(5))
          <String, dynamic>{
            'name': stat.name,
            'color': stat.color,
            'count': stat.count,
            'explanation': stat.explanation,
            'positive': isHighlightTag(stat.name, stat.color),
            'resolvedCount': stat.resolved,
          },
      ],
      'suggestions': <Map<String, dynamic>>[
        for (final stat
            in ranked.where((s) => !isHighlightTag(s.name, s.color)).take(3))
          _suggestionOf(stat),
      ],
      'dimensionLevels': dimensionLevels,
      'problemTagCount': problemTags,
      'markedTagCount': markedTags,
      'resolvedTagCount': resolvedTags,
      'resolveRate': markedTags == 0
          ? null
          : round2(resolvedTags / markedTags),
      'streakDays': streakDays(works, now),
      'recentSubmitCount': recentSubmitCount(works, now),
    };
  }

  /// 连续练习天数：截至今天，连续有作品提交的在校日数（周日不算断）。
  /// 今天还没交时从上一个在校日算起。
  static int streakDays(List<Map<String, dynamic>> works, DateTime now) {
    final days = <String>{
      for (final work in works)
        if (text(work['createTime']).length >= 10)
          text(work['createTime']).substring(0, 10),
    };
    var day = dateOnly(now);
    var streak = 0;
    var first = true;
    while (true) {
      if (!isSchoolDay(day)) {
        day = DateTime(day.year, day.month, day.day - 1);
        continue;
      }
      if (days.contains(ymd(day))) {
        streak++;
      } else if (!first) {
        break;
      }
      first = false;
      day = DateTime(day.year, day.month, day.day - 1);
      if (streak > 400) {
        break;
      }
    }
    return streak;
  }

  /// 近 7 天（含今天）提交的作品数，改画的每一版都算一次提交。
  static int recentSubmitCount(List<Map<String, dynamic>> works, DateTime now) {
    final today = dateOnly(now);
    final from = ymd(DateTime(today.year, today.month, today.day - 6));
    final to = ymd(today);
    return works.where((work) {
      final created = text(work['createTime']);
      if (created.length < 10) {
        return false;
      }
      final day = created.substring(0, 10);
      return day.compareTo(from) >= 0 && day.compareTo(to) <= 0;
    }).length;
  }

  static Map<String, dynamic> _suggestionOf(_TagStat stat) {
    final advice = _advice[stat.name];
    final dominant =
        (stat.subjects.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => e.key)
            .firstWhere(subjects.contains, orElse: () => advice?.$2 ?? '素描');
    return <String, dynamic>{
      'tag': stat.name,
      'color': stat.color,
      'count': stat.count,
      'text':
          advice?.$1 ??
          (stat.explanation.isNotEmpty
              ? stat.explanation
              : '对照老师的点评，挑选同类范画针对性练习。'),
      'gallerySubject': dominant,
      'galleryKeyword': advice?.$3 ?? stat.name,
      'tool': advice?.$4 ?? '',
    };
  }
}

class _TagStat {
  _TagStat(this.name);

  final String name;
  int count = 0;
  int resolved = 0;
  String color = '';
  String explanation = '';
  String latest = '';
  final Map<String, int> subjects = <String, int>{};
}
