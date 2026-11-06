import 'smart_campus_dashboard_data.dart';

/// 学生 dashboard 快捷入口角标（我的作业 / 我的考试 / 我的请假）。
class StudentDashboardBadges {
  const StudentDashboardBadges({
    this.homeworkPending = 0,
    this.examPending = 0,
    this.leavePending = 0,
  });

  /// 待交作业（对齐首页统计「待交作业」/`homeworkCount`）。
  final int homeworkPending;

  /// 待考考试（`myExamList` tab=1 或 `phase.isPending`）。
  final int examPending;

  /// 审批中请假（待家长 / 待班主任审批）。
  final int leavePending;

  StudentDashboardBadges merge({
    int? homeworkPending,
    int? examPending,
    int? leavePending,
  }) {
    return StudentDashboardBadges(
      homeworkPending: homeworkPending ?? this.homeworkPending,
      examPending: examPending ?? this.examPending,
      leavePending: leavePending ?? this.leavePending,
    );
  }
}

/// 从 `student/index` 解析角标字段（多 key 兜底，兼容后端命名差异）。
StudentDashboardBadges parseStudentDashboardBadgesFromIndex(dynamic raw) {
  final map = _coerceIndexMap(raw);
  return StudentDashboardBadges(
    homeworkPending: _pickInt(
      map,
      ['homeworkCount', 'pendingHomeworkCount', 'homeworkPendingCount'],
    ),
    examPending: _pickInt(
      map,
      ['examCount', 'pendingExamCount', 'myExamCount', 'todoExamCount'],
    ),
    leavePending: _pickInt(
      map,
      [
        'leaveCount',
        'pendingLeaveCount',
        'studentLeaveCount',
        'leaveStatus1Count',
      ],
    ),
  );
}

Map<String, int> buildStudentActionBadges(StudentDashboardBadges badges) {
  return <String, int>{
    '我的作业': badges.homeworkPending,
    '我的考试': badges.examPending,
    '我的请假': badges.leavePending,
  };
}

List<SmartCampusQuickActionData> applyStudentActionBadges(
  List<SmartCampusQuickActionData> base,
  StudentDashboardBadges badges,
) {
  final badgeMap = buildStudentActionBadges(badges);
  return [
    for (final item in base)
      SmartCampusQuickActionData(
        label: item.label,
        icon: item.icon,
        background: item.background,
        foreground: item.foreground,
        badge: badgeMap[item.label] ?? item.badge,
        imagePath: item.imagePath,
      ),
  ];
}

Map<String, dynamic> _coerceIndexMap(dynamic raw) {
  var current = raw;
  for (var depth = 0; depth < 4; depth++) {
    if (current is! Map) return const {};
    final map = Map<String, dynamic>.from(current);
    if (map.containsKey('todayCourseCount') ||
        map.containsKey('homeworkCount') ||
        map.containsKey('avgScore')) {
      return map;
    }
    if (map['data'] is Map) {
      current = map['data'];
      continue;
    }
    return map;
  }
  return const {};
}

int _pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final v = map[key];
    if (v == null) continue;
    if (v is int) return v;
    final n = int.tryParse(v.toString());
    if (n != null) return n;
  }
  return 0;
}
