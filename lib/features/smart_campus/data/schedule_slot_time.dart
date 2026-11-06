/// 课表节次时间判断（管理员 / 教师 / 学生周课表共用）。
DateTime? parseScheduleHmOnDate(DateTime date, String hm) {
  final trimmed = hm.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(date.year, date.month, date.day, h, m);
}

/// 判断某一格课程是否已结束，用于统一灰色展示。
///
/// [slotDate] 仅取年月日；[endHm] 为节次结束时间（如 `08:40`）。
bool isScheduleSlotPast({
  required DateTime slotDate,
  required String endHm,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(slotDate.year, slotDate.month, slotDate.day);
  if (day.isBefore(today)) return true;
  if (day.isAfter(today)) return false;
  final end = parseScheduleHmOnDate(day, endHm);
  if (end == null) return false;
  return clock.isAfter(end);
}
