/// 任课老师端首页 `courseTeacherIndex` 数据模型与展示映射。
library;

import 'smart_campus_dashboard_data.dart';

class CourseTeacherIndexRes {
  const CourseTeacherIndexRes({
    required this.todayCourseCount,
    required this.pendingHomeworkCount,
    required this.todayCourseList,
    this.currentCourse,
    this.nextCourse,
  });

  final int todayCourseCount;
  final int pendingHomeworkCount;
  final List<Map<String, dynamic>> todayCourseList;
  final Map<String, dynamic>? currentCourse;
  final Map<String, dynamic>? nextCourse;

  static const zero = CourseTeacherIndexRes(
    todayCourseCount: 0,
    pendingHomeworkCount: 0,
    todayCourseList: [],
  );

  /// 顶部统计「待签课」：`todayCourseList` 中 `signStatus` 未签（0 / 空）的数量。
  int get pendingSignCount => countUnsignedTeacherCourses(todayCourseList);
}

CourseTeacherIndexRes parseCourseTeacherIndexRes(dynamic raw) {
  if (raw is! Map) return CourseTeacherIndexRes.zero;
  var m = Map<String, dynamic>.from(raw);
  if (m['data'] is Map) {
    m = Map<String, dynamic>.from(m['data'] as Map);
  }

  final todayRaw = m['todayCourseList'];
  final today = todayRaw is List
      ? todayRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
      : const <Map<String, dynamic>>[];

  Map<String, dynamic>? mapCourse(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  return CourseTeacherIndexRes(
    todayCourseCount: _asInt(m['todayCourseCount']) ?? today.length,
    pendingHomeworkCount: _asInt(m['pendingHomeworkCount']) ?? 0,
    todayCourseList: today,
    currentCourse: mapCourse(m['currentCourse']),
    nextCourse: mapCourse(m['nextCourse']),
  );
}

int countUnsignedTeacherCourses(List<Map<String, dynamic>> courses) {
  var count = 0;
  for (final course in courses) {
    final raw = course['signStatus'];
    final status = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (status == null || status == 0) count++;
  }
  return count;
}

String formatTeacherNextCourseTime(Map<String, dynamic>? course) {
  if (course == null) return '0';
  final raw = course['courseStartTime'] ??
      course['startTime'] ??
      course['timeBegin'] ??
      course['beginTime'];
  if (raw == null) return '0';
  final text = raw.toString().trim();
  if (text.isEmpty) return '0';

  final dt = DateTime.tryParse(text);
  if (dt != null) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  if (text.length >= 5 && text.contains(':')) {
    return text.substring(0, 5);
  }
  return text;
}

List<SmartCampusStatCardData> buildCourseTeacherStats({
  required CourseTeacherIndexRes index,
  int? weekCourseCount,
}) {
  final unsigned = index.pendingSignCount;
  final pendingTodo = index.pendingHomeworkCount + unsigned;

  return [
    SmartCampusStatCardData(
      label: '今日授课',
      value: '${index.todayCourseCount}',
    ),
    SmartCampusStatCardData(
      label: '待批改',
      value: '${index.pendingHomeworkCount}',
    ),
    SmartCampusStatCardData(
      label: '待签课',
      value: '$unsigned',
    ),
    SmartCampusStatCardData(
      label: '待办事项',
      value: '$pendingTodo',
    ),
    SmartCampusStatCardData(
      label: '本周课时',
      value: '${weekCourseCount ?? 0}',
    ),
    SmartCampusStatCardData(
      label: '下一节',
      value: formatTeacherNextCourseTime(index.nextCourse),
      highlight: index.nextCourse != null,
    ),
  ];
}

Map<String, int> buildCourseTeacherActionBadges(
  CourseTeacherIndexRes index, {
  int myLeavePendingCount = 0,
}) {
  return <String, int>{
    '作业批改': index.pendingHomeworkCount,
    '签课管理': index.pendingSignCount,
    '我的请假': myLeavePendingCount,
  };
}

int countWeekCoursesFromCourseList(dynamic raw) {
  final rows = _extractCourseRows(raw);
  return rows.length;
}

List<Map<String, dynamic>> _extractCourseRows(dynamic raw) {
  final list = <Map<String, dynamic>>[];
  if (raw is Map) {
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
      }
    }
    final records = raw['records'] ?? raw['list'] ?? raw['rows'] ?? raw['data'];
    if (records is List) {
      for (final item in records) {
        if (item is Map) list.add(Map<String, dynamic>.from(item));
      }
    }
  } else if (raw is List) {
    for (final item in raw) {
      if (item is Map) list.add(Map<String, dynamic>.from(item));
    }
  }
  return list;
}

int? _asInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  return int.tryParse(raw.toString());
}
