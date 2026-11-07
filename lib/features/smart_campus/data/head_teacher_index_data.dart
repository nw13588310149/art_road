/// 班主任端「班级工作台 / 首页」`headTeacherIndex` 数据模型。
library;

import '../../../core/network/snowflake_id.dart';

import 'smart_campus_dashboard_data.dart';

class HeadTeacherClassItem {
  const HeadTeacherClassItem({
    required this.classId,
    required this.className,
    required this.studentCount,
  });

  final String classId;
  final String className;
  final int studentCount;

  factory HeadTeacherClassItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['classId'] ?? json['id'];
    final id = rawId == null ? '' : readSnowflakeId(rawId) ?? rawId.toString();
    return HeadTeacherClassItem(
      classId: id,
      className: _pickString(json, ['className', 'name'], '未命名班级'),
      studentCount: _asInt(json['studentCount']) ?? 0,
    );
  }
}

/// `headTeacherIndex` 待办 / 近期动态条目（`todoList` / `recentList`）。
class HeadTeacherFeedItem {
  const HeadTeacherFeedItem({
    required this.title,
    required this.desc,
    required this.tag,
    this.time = '',
  });

  /// 状态（待我审批 / 待家长确认 / 待审核）；近期动态为空。
  final String title;
  final String desc;
  final String tag;

  /// 「今天 09:40」「11-05 08:10」。
  final String time;

  factory HeadTeacherFeedItem.fromJson(Map<String, dynamic> json) {
    return HeadTeacherFeedItem(
      title: _pickString(json, ['title'], ''),
      desc: _pickString(json, ['desc', 'description', 'subtitle'], ''),
      tag: _pickString(json, ['tag'], ''),
      time: _pickString(json, ['time'], ''),
    );
  }

  HeadTeacherBoardItem toBoardItem() {
    final hasTime = time.isNotEmpty;
    return HeadTeacherBoardItem(
      time: hasTime ? time : title,
      title: desc,
      tag: tag,
      status: hasTime ? title : '',
    );
  }
}

class HeadTeacherIndexRes {
  const HeadTeacherIndexRes({
    required this.chatUnreadCount,
    required this.chatWaitingCount,
    required this.classList,
    required this.pendingLeaveCount,
    required this.pendingMakeupCount,
    required this.todayAbnormalDormCount,
    required this.todoList,
    required this.recentList,
  });

  final int chatUnreadCount;
  final int chatWaitingCount;
  final List<HeadTeacherClassItem> classList;
  final int pendingLeaveCount;
  final int pendingMakeupCount;
  final int todayAbnormalDormCount;
  final List<HeadTeacherFeedItem> todoList;
  final List<HeadTeacherFeedItem> recentList;

  static const zero = HeadTeacherIndexRes(
    chatUnreadCount: 0,
    chatWaitingCount: 0,
    classList: [],
    pendingLeaveCount: 0,
    pendingMakeupCount: 0,
    todayAbnormalDormCount: 0,
    todoList: [],
    recentList: [],
  );

  int get totalStudentCount =>
      classList.fold<int>(0, (sum, c) => sum + c.studentCount);

  String get classNamesLabel {
    if (classList.isEmpty) return '—';
    return classList.map((c) => c.className).join('、');
  }

  int get pendingTodoCount =>
      pendingLeaveCount + pendingMakeupCount + todayAbnormalDormCount;
}

List<SmartCampusStatCardData> buildHeadTeacherStats(HeadTeacherIndexRes res) {
  return [
    SmartCampusStatCardData(label: '在籍学生', value: '${res.totalStudentCount}'),
    SmartCampusStatCardData(label: '待批请假', value: '${res.pendingLeaveCount}'),
    SmartCampusStatCardData(
      label: '查寝异常',
      value: '${res.todayAbnormalDormCount}',
    ),
    SmartCampusStatCardData(label: '家校未读', value: '${res.chatUnreadCount}'),
    SmartCampusStatCardData(label: '待回复', value: '${res.chatWaitingCount}'),
    SmartCampusStatCardData(
      label: '待办',
      value: '${res.pendingTodoCount}',
      highlight: res.pendingTodoCount > 0,
    ),
  ];
}

class HeadTeacherBoardItem {
  const HeadTeacherBoardItem({
    required this.time,
    required this.title,
    required this.tag,
    this.status = '',
  });

  final String time;

  /// 正文（主标题，最多两行）。
  final String title;

  /// 类别（请假 / 补卡 / 查寝 / 家校 / 班级）。
  final String tag;

  /// 待处理状态（待我审批 / 待家长确认 / 待审核），近期动态为空。
  final String status;
}

List<HeadTeacherBoardItem> buildHeadTeacherTodoBoardItems(
  HeadTeacherIndexRes res,
) {
  if (res.todoList.isNotEmpty) {
    return [for (final item in res.todoList) item.toBoardItem()];
  }

  final items = <HeadTeacherBoardItem>[];
  if (res.pendingLeaveCount > 0) {
    items.add(
      HeadTeacherBoardItem(
        time: '',
        title: '${res.pendingLeaveCount} 条学生请假申请待处理',
        tag: '请假',
        status: '待审批',
      ),
    );
  }
  if (res.pendingMakeupCount > 0) {
    items.add(
      HeadTeacherBoardItem(
        time: '',
        title: '${res.pendingMakeupCount} 条查寝补卡申请待处理',
        tag: '补卡',
        status: '待审核',
      ),
    );
  }
  if (res.todayAbnormalDormCount > 0) {
    items.add(
      HeadTeacherBoardItem(
        time: '',
        title: '${res.todayAbnormalDormCount} 条查寝异常待跟进',
        tag: '查寝',
        status: '需处理',
      ),
    );
  }
  return items;
}

List<HeadTeacherBoardItem> buildHeadTeacherRecentBoardItems(
  HeadTeacherIndexRes res,
) {
  if (res.recentList.isNotEmpty) {
    return [for (final item in res.recentList) item.toBoardItem()];
  }

  final items = <HeadTeacherBoardItem>[];
  if (res.chatWaitingCount > 0) {
    items.add(
      HeadTeacherBoardItem(
        time: '',
        title: '${res.chatWaitingCount} 位家长的留言待回复',
        tag: '家校',
      ),
    );
  }
  if (res.chatUnreadCount > 0) {
    items.add(
      HeadTeacherBoardItem(
        time: '',
        title: '家校沟通有 ${res.chatUnreadCount} 条未读消息',
        tag: '家校',
      ),
    );
  }
  if (res.classList.isNotEmpty) {
    items.add(
      HeadTeacherBoardItem(
        time: '',
        title: '所带班级：${res.classNamesLabel}',
        tag: '班级',
      ),
    );
  }
  return items;
}

Map<String, int> buildHeadTeacherActionBadges(
  HeadTeacherIndexRes res, {
  int myLeavePendingCount = 0,
}) {
  return <String, int>{
    '请假审批': res.pendingLeaveCount,
    '我的请假': myLeavePendingCount,
    '家校沟通': res.chatUnreadCount,
  };
}

HeadTeacherIndexRes parseHeadTeacherIndexRes(dynamic raw) {
  if (raw is! Map) return HeadTeacherIndexRes.zero;
  var m = Map<String, dynamic>.from(raw);
  if (m['data'] is Map) {
    m = Map<String, dynamic>.from(m['data'] as Map);
  }

  final classRaw = m['classList'];
  final classes = classRaw is List
      ? classRaw
            .whereType<Map>()
            .map(
              (e) =>
                  HeadTeacherClassItem.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
      : const <HeadTeacherClassItem>[];

  return HeadTeacherIndexRes(
    chatUnreadCount: _asInt(m['chatUnreadCount']) ?? 0,
    chatWaitingCount: _asInt(m['chatWaitingCount']) ?? 0,
    classList: classes,
    pendingLeaveCount: _asInt(m['pendingLeaveCount']) ?? 0,
    pendingMakeupCount: _asInt(m['pendingMakeupCount']) ?? 0,
    todayAbnormalDormCount: _asInt(m['todayAbnormalDormCount']) ?? 0,
    todoList: _parseFeedList(m['todoList']),
    recentList: _parseFeedList(m['recentList']),
  );
}

List<HeadTeacherFeedItem> _parseFeedList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => HeadTeacherFeedItem.fromJson(Map<String, dynamic>.from(e)))
      .where((item) => item.title.isNotEmpty || item.desc.isNotEmpty)
      .toList();
}

int? _asInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  return int.tryParse(raw.toString());
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}
