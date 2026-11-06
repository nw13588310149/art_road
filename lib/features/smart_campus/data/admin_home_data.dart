import 'dart:math' as math;

import 'admin_notice_data.dart';
import 'smart_campus_count_badge.dart';

class AdminHomeSummary {
  const AdminHomeSummary({
    this.studentCount = 0,
    this.teacherCount = 0,
    this.classCount = 0,
    this.toDoTodayCount = 0,
    this.leaveStatus0Count = 0,
    this.smallCourseSignStatus5Count = 0,
    this.userFaceNotRecordedCount = 0,
    this.postStatus0Count = 0,
  });

  final int studentCount;
  final int teacherCount;
  final int classCount;
  final int toDoTodayCount;
  final int leaveStatus0Count;
  final int smallCourseSignStatus5Count;
  final int userFaceNotRecordedCount;
  final int postStatus0Count;

  factory AdminHomeSummary.fromJson(dynamic raw) {
    final json = _coerceIndexSumMap(raw);
    return AdminHomeSummary(
      studentCount: _readInt(json['studentCount']),
      teacherCount: _readInt(json['teacherCount']),
      classCount: _readInt(json['classCount']),
      toDoTodayCount: _readInt(json['toDoTodayCount']),
      leaveStatus0Count: _readInt(json['leaveStatus0Count']),
      smallCourseSignStatus5Count: _readInt(
        json['smallCourseSignStatus5Count'],
      ),
      userFaceNotRecordedCount: _readInt(json['userFaceNotRecordedCount']),
      postStatus0Count: _readInt(json['postStatus0Count']),
    );
  }
}

/// 管理员首页快捷入口角标数量（与顶部统计 / 分页 total 对齐）。
class AdminHomeActionBadgeCounts {
  const AdminHomeActionBadgeCounts({
    this.scheduleApply = 0,
    this.teacherLeave = 0,
    this.signReview = 0,
    this.faceAudit = 0,
    this.postReview = 0,
    this.principalMailboxPending = 0,
  });

  /// 排课与课表：`schoolSmallCourseApplyList` status=0 total。
  final int scheduleApply;

  /// 教师请假审批：`indexSum.leaveStatus0Count`（教职工待审批请假）。
  final int teacherLeave;

  /// 签课管理：`indexSum.smallCourseSignStatus5Count`（小课待审核）。
  final int signReview;

  /// 人脸库：`schoolUserFaceSum.status0Count`（待审核）。
  final int faceAudit;

  /// 校圈治理：`indexSum.postStatus0Count`（今日校圈）。
  final int postReview;

  /// 校长信箱：`headmaster/principalMailboxList` status=0 total（待回复）。
  final int principalMailboxPending;

  factory AdminHomeActionBadgeCounts.fromSummary({
    required AdminHomeSummary summary,
    required int scheduleApply,
    required int faceAudit,
    int principalMailboxPending = 0,
  }) {
    return AdminHomeActionBadgeCounts(
      scheduleApply: scheduleApply,
      teacherLeave: summary.leaveStatus0Count,
      signReview: summary.smallCourseSignStatus5Count,
      faceAudit: faceAudit,
      postReview: summary.postStatus0Count,
      principalMailboxPending: principalMailboxPending,
    );
  }

  String? badgeLabelFor(String actionLabel) {
    switch (actionLabel) {
      case '排课与课表':
        return smartCampusCountBadgeLabel(scheduleApply);
      case '教师请假审批':
        return smartCampusCountBadgeLabel(teacherLeave);
      case '签课管理':
        return smartCampusCountBadgeLabel(signReview);
      case '人脸库':
        return smartCampusCountBadgeLabel(faceAudit);
      case '校圈治理':
        return smartCampusCountBadgeLabel(postReview);
      case '校长信箱':
        return smartCampusCountBadgeLabel(principalMailboxPending);
      default:
        return null;
    }
  }
}

Map<String, dynamic> _coerceIndexSumMap(dynamic raw) {
  var current = raw;
  for (var depth = 0; depth < 4; depth++) {
    if (current is! Map) return const {};
    final map = Map<String, dynamic>.from(current);
    if (_looksLikeIndexSumRes(map)) return map;
    if (map['data'] is Map) {
      current = map['data'];
      continue;
    }
    return map;
  }
  return const {};
}

bool _looksLikeIndexSumRes(Map<String, dynamic> json) {
  const keys = [
    'studentCount',
    'leaveStatus0Count',
    'postStatus0Count',
    'smallCourseSignStatus5Count',
    'toDoTodayCount',
  ];
  return keys.any(json.containsKey);
}

class AdminHomeNotice {
  const AdminHomeNotice({
    required this.id,
    required this.tag,
    required this.text,
    required this.time,
    required this.highlighted,
  });

  final String id;
  final String tag;
  final String text;
  final String time;
  final bool highlighted;

  factory AdminHomeNotice.fromRecord(AdminNoticeRecord record) {
    final text = formatNoticePreviewText(record.title, record.content);
    return AdminHomeNotice(
      id: record.id,
      tag: record.type.trim().isEmpty ? '通知' : record.type,
      text: text,
      time: record.time,
      highlighted: record.priority != AdminNoticePriority.normal,
    );
  }
}

List<AdminHomeNotice> parseAdminHomeNotices(dynamic raw) {
  return parseAdminNoticeList(raw)
      .where((record) => record.status == AdminNoticeStatus.published)
      .map(AdminHomeNotice.fromRecord)
      .toList(growable: false);
}

/// 管理员首页「工作提醒」单条记录（`workReminders` 接口）。
class AdminHomeWorkReminder {
  const AdminHomeWorkReminder({
    required this.tag,
    required this.title,
    required this.subtitle,
  });

  final String tag;
  final String title;
  final String subtitle;

  factory AdminHomeWorkReminder.fromJson(Map<String, dynamic> json) {
    final tag = _pickString(json, const [
      'tag',
      'type',
      'label',
      'badge',
    ], '预警');
    final title = _pickString(json, const [
      'title',
      'name',
      'remindTitle',
      'mainTitle',
    ], '');
    final subtitle = _pickString(json, const [
      'subtitle',
      'subTitle',
      'content',
      'description',
      'remark',
      'detail',
    ], '');
    return AdminHomeWorkReminder(
      tag: tag.isEmpty ? '预警' : tag,
      title: title,
      subtitle: subtitle,
    );
  }
}

List<AdminHomeWorkReminder> parseAdminHomeWorkReminders(dynamic raw) {
  return [
    for (final row in _coerceWorkReminderRows(raw))
      AdminHomeWorkReminder.fromJson(row),
  ].where((item) => item.title.isNotEmpty).toList(growable: false);
}

List<Map<String, dynamic>> _coerceWorkReminderRows(dynamic raw) {
  dynamic list = raw;
  if (list is Map && list['data'] is List) {
    list = list['data'];
  } else if (list is Map) {
    for (final key in const ['records', 'list', 'rows', 'items']) {
      if (list[key] is List) {
        list = list[key];
        break;
      }
    }
  }
  if (list is! List) return const [];

  return [
    for (final item in list)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

/// 管理员首页「数据看板」近 7 日登录曲线。
class AdminHomeLoginChart {
  const AdminHomeLoginChart({this.points = const []});

  final List<AdminHomeLoginChartPoint> points;

  List<double> get values =>
      points.map((point) => point.count.toDouble()).toList(growable: false);

  List<String> get xLabels =>
      points.map((point) => point.weekdayLabel).toList(growable: false);
}

class AdminHomeLoginChartPoint {
  const AdminHomeLoginChartPoint({
    required this.loginDate,
    required this.count,
    required this.weekdayLabel,
  });

  final String loginDate;
  final int count;
  final String weekdayLabel;
}

const _adminHomeWeekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

AdminHomeLoginChart parseAdminHomeLoginChart(
  dynamic raw, {
  required String startDate,
  required String endDate,
}) {
  final start = _parseAdminHomeIsoDate(startDate);
  final end = _parseAdminHomeIsoDate(endDate);
  if (start == null || end == null || start.isAfter(end)) {
    return const AdminHomeLoginChart();
  }

  final countByDate = <String, int>{};
  for (final row in _coerceLoginChartRows(raw)) {
    final date = row['loginDate']?.toString().trim() ?? '';
    if (date.isEmpty) continue;
    countByDate[date] = _readInt(row['count']);
  }

  final points = <AdminHomeLoginChartPoint>[];
  for (
    var day = start;
    !day.isAfter(end);
    day = day.add(const Duration(days: 1))
  ) {
    final iso = formatAdminHomeIsoDate(day);
    points.add(
      AdminHomeLoginChartPoint(
        loginDate: iso,
        count: countByDate[iso] ?? 0,
        weekdayLabel: _adminHomeWeekdayLabels[day.weekday - 1],
      ),
    );
  }
  return AdminHomeLoginChart(points: points);
}

/// 登录人数 Y 轴上限：全 0 时默认 10，否则向上取整到 5 的倍数。
double adminHomeLoginChartMaxY(List<double> values) {
  if (values.isEmpty) return 10;
  final max = values.reduce((a, b) => a > b ? a : b);
  if (max <= 0) return 10;
  return ((max / 5).ceil() * 5).toDouble();
}

/// 数据看板折线图：将数值映射到画布 Y（与 [_LineChartPainter] 共用）。
double adminHomeLoginChartYForValue({
  required double value,
  required double height,
  required double topPadding,
  required double maxY,
}) {
  final maxV = maxY <= 0 ? 10.0 : maxY;
  final plotHeight = math.max(height - topPadding, 1.0);
  final ratio = maxV == 0 ? 0.0 : (value.clamp(0.0, maxV) / maxV);
  return height - ratio * plotHeight;
}

/// 数据看板折线图：第 [index] 个数据点 X，与下方等分 weekday 标签中线对齐。
double adminHomeLoginChartXForIndex({
  required int index,
  required int count,
  required double plotLeft,
  required double plotWidth,
}) {
  if (count <= 0) return plotLeft;
  if (count == 1) return plotLeft + plotWidth / 2;
  return plotLeft + (index + 0.5) * plotWidth / count;
}

List<String> buildAdminHomeLoginChartYLabels(double maxY) {
  final top = maxY <= 0 ? 10 : maxY;
  final step = top / 5;
  return [
    for (var i = 5; i >= 0; i--) i == 0 ? '0' : (step * i).round().toString(),
  ];
}

List<Map<String, dynamic>> _coerceLoginChartRows(dynamic raw) {
  dynamic list = raw;
  if (list is Map && list['data'] is List) {
    list = list['data'];
  }
  if (list is! List) return const [];

  return [
    for (final item in list)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

DateTime? _parseAdminHomeIsoDate(String raw) {
  final parts = raw.trim().split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String formatAdminHomeIsoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// 数据看板查询区间：含今天在内共 7 天（`startDate` … `endDate`）。
({String startDate, String endDate}) adminHomeLast7DaysDateRange({
  DateTime? anchor,
}) {
  final end = anchor ?? DateTime.now();
  final endDate = DateTime(end.year, end.month, end.day);
  final startDate = endDate.subtract(const Duration(days: 6));
  return (
    startDate: formatAdminHomeIsoDate(startDate),
    endDate: formatAdminHomeIsoDate(endDate),
  );
}

int _readInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

/// 分页接口 `total` / `totalCount` 等字段（小课申请待审核角标等）。
int? parseAdminPageTotal(dynamic raw) {
  var current = raw;
  for (var depth = 0; depth < 4; depth++) {
    if (current is! Map) return null;
    final map = Map<String, dynamic>.from(current);
    for (final key in ['total', 'totalCount', 'recordsTotal', 'count']) {
      final value = map[key];
      if (value == null) continue;
      if (value is int) return value;
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    final nested = map['data'];
    if (nested is! Map) return null;
    current = nested;
  }
  return null;
}

/// 人脸库统计 `schoolUserFaceSum` → 待审核数量（`status0Count`）。
int parseAdminFaceSumPendingCount(dynamic raw) {
  var current = raw;
  for (var depth = 0; depth < 4; depth++) {
    if (current is! Map) return 0;
    final map = Map<String, dynamic>.from(current);
    if (map.containsKey('status0Count')) {
      return _readInt(map['status0Count']);
    }
    final nested = map['data'];
    if (nested is! Map) return 0;
    current = nested;
  }
  return 0;
}

int parseAdminListPendingTotal(dynamic raw) {
  final total = parseAdminPageTotal(raw);
  if (total != null) return total;

  var current = raw;
  for (var depth = 0; depth < 4; depth++) {
    if (current is List) return current.length;
    if (current is! Map) return 0;
    final map = Map<String, dynamic>.from(current);
    for (final key in ['records', 'list', 'rows', 'items']) {
      final rows = map[key];
      if (rows is List) return rows.length;
    }
    final nested = map['data'];
    if (nested is! Map && nested is! List) return 0;
    current = nested;
  }
  return 0;
}
