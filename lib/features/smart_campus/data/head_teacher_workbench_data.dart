import 'package:flutter/material.dart';

import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';

/// 班主任班级工作台 · 七日查寝每日正常人数。
class DormNormalStatDay {
  const DormNormalStatDay({
    required this.date,
    required this.normalCount,
    required this.weekdayLabel,
  });

  final String date;
  final int normalCount;
  final String weekdayLabel;
}

/// 班主任重点关注学生。
class FocusStudentItem {
  const FocusStudentItem({
    required this.studentId,
    required this.studentName,
    required this.avatarChar,
    this.studentHeadUrl,
    required this.classId,
    required this.className,
    required this.tag,
    required this.reason,
    required this.time,
  });

  final String studentId;
  final String studentName;
  final String avatarChar;
  final String? studentHeadUrl;
  final String classId;
  final String className;
  final String tag;
  final String reason;
  final String time;

  factory FocusStudentItem.fromJson(Map<String, dynamic> json) {
    final studentId =
        pickFirstSnowflakeId(json, ['studentId', 'userId']) ?? '';
    final name = _pickString(json, [
      'studentName',
      'realname',
      'studentNickname',
      'name',
      'nickname',
    ]);
    final headUrlRaw = _pickString(json, [
      'studentHeadUrl',
      'headUrl',
      'avatarUrl',
      'avatar',
      'headImg',
    ]);
    final studentHeadUrl =
        headUrlRaw.isNotEmpty ? MediaUrl.resolve(headUrlRaw) : null;
    final avatarCharRaw = _pickString(json, ['avatarChar', 'headChar']);
    final avatarChar = avatarCharRaw.isNotEmpty
        ? avatarCharRaw.characters.first
        : (name.isNotEmpty ? name.characters.first : '—');
    return FocusStudentItem(
      studentId: studentId,
      studentName: name.isNotEmpty ? name : '—',
      avatarChar: avatarChar,
      studentHeadUrl: studentHeadUrl,
      classId: pickFirstSnowflakeId(json, ['classId']) ?? '',
      className: _pickString(json, ['className', 'class']),
      tag: _pickString(json, ['tag', 'focusTag', 'label']),
      reason: _pickString(json, ['reason', 'desc', 'remark', 'content']),
      time: _pickString(json, ['time', 'createTime', 'updateTime', 'focusTime']),
    );
  }
}

const List<String> kFocusStudentPresetTags = [
  '心理关注',
  '考勤关注',
  '学业关注',
  '行为关注',
];

/// 最近 7 个自然日（含今天）的 `yyyy-MM-dd` 区间。
(String beginDate, String endDate) headTeacherWorkbenchLastSevenDaysRange([
  DateTime? anchor,
]) {
  final end = anchor ?? DateTime.now();
  final endDate = DateTime(end.year, end.month, end.day);
  final beginDate = endDate.subtract(const Duration(days: 6));
  return (headTeacherWorkbenchIsoDate(beginDate), headTeacherWorkbenchIsoDate(endDate));
}

String headTeacherWorkbenchIsoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime? headTeacherWorkbenchParseIsoDate(String raw) {
  final parts = raw.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String headTeacherWorkbenchWeekdayLabel(DateTime date) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[date.weekday - DateTime.monday];
}

List<DormNormalStatDay> parseDormNormalStat(
  dynamic raw, {
  required String beginDate,
  required String endDate,
}) {
  final countsByDate = <String, int>{};
  final list = _unwrapList(raw);
  for (final item in list) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final date = _pickString(map, ['date', 'checkDate', 'statDate', 'day']);
    if (date.isEmpty) continue;
    countsByDate[date] = _pickInt(map, [
      'normalCount',
      'normalNum',
      'count',
      'value',
      'num',
    ]);
  }

  final begin = headTeacherWorkbenchParseIsoDate(beginDate);
  final end = headTeacherWorkbenchParseIsoDate(endDate);
  if (begin == null || end == null) return const [];

  final days = <DormNormalStatDay>[];
  for (var i = 0; i < 7; i++) {
    final date = begin.add(Duration(days: i));
    if (date.isAfter(end)) break;
    final iso = headTeacherWorkbenchIsoDate(date);
    days.add(
      DormNormalStatDay(
        date: iso,
        normalCount: countsByDate[iso] ?? 0,
        weekdayLabel: headTeacherWorkbenchWeekdayLabel(date),
      ),
    );
  }
  return days;
}

/// 七日查寝 UI 预览用模拟数据（按最近 7 个自然日顺序）。
const List<int> kDormNormalStatMockCounts = [1, 55, 0, 231, 75, 16, 33];

List<DormNormalStatDay> mockDormNormalStatDays([DateTime? anchor]) {
  final (beginDate, endDate) = headTeacherWorkbenchLastSevenDaysRange(anchor);
  final begin = headTeacherWorkbenchParseIsoDate(beginDate);
  final end = headTeacherWorkbenchParseIsoDate(endDate);
  if (begin == null || end == null) return const [];

  final days = <DormNormalStatDay>[];
  for (var i = 0; i < 7; i++) {
    final date = begin.add(Duration(days: i));
    if (date.isAfter(end)) break;
    days.add(
      DormNormalStatDay(
        date: headTeacherWorkbenchIsoDate(date),
        normalCount: i < kDormNormalStatMockCounts.length
            ? kDormNormalStatMockCounts[i]
            : 0,
        weekdayLabel: headTeacherWorkbenchWeekdayLabel(date),
      ),
    );
  }
  return days;
}

List<int> buildDormNormalStatAxisTicks(int maxCount) {
  if (maxCount <= 0) {
    return const [10, 8, 6, 4, 2, 0];
  }
  final ceiling = ((maxCount * 1.15) / 5).ceil() * 5;
  final step = (ceiling / 5).ceil().clamp(1, 99999);
  return [for (var i = 5; i >= 0; i--) step * i];
}

List<FocusStudentItem> parseFocusStudentList(dynamic raw) {
  final list = _unwrapList(raw);
  return list
      .whereType<Map>()
      .map((item) => FocusStudentItem.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.studentId.isNotEmpty)
      .toList();
}

(Color background, Color text) focusStudentTagColors(String tag) {
  final normalized = tag.trim();
  if (normalized.contains('心理')) {
    return (const Color(0xFF8741FF), Colors.white);
  }
  if (normalized.contains('考勤') || normalized.contains('查寝')) {
    return (const Color(0xFF325BFF), Colors.white);
  }
  if (normalized.contains('学业') || normalized.contains('成绩')) {
    return (const Color(0xFFDBEE49), const Color(0xFF0B081A));
  }
  return (const Color(0xFFDBEE49), const Color(0xFF0B081A));
}

String formatFocusStudentTime(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final now = DateTime.now();
  final today = headTeacherWorkbenchIsoDate(now);
  if (trimmed.startsWith(today)) {
    final hm = trimmed.length >= 16 ? trimmed.substring(11, 16) : '';
    return hm.isNotEmpty ? '今天 $hm' : '今天';
  }
  if (trimmed.length >= 16) {
    return trimmed.substring(5, 16).replaceFirst('-', '月').replaceFirst(' ', '日 ');
  }
  return trimmed;
}

List<dynamic> _unwrapList(dynamic raw) {
  if (raw is List) return raw;
  if (raw is! Map) return const [];
  final map = Map<String, dynamic>.from(raw);
  for (final key in ['list', 'records', 'items', 'data', 'statList']) {
    final value = map[key];
    if (value is List) return value;
  }
  return const [];
}

int _pickInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is int) return value;
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return 0;
}

String _pickString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}
