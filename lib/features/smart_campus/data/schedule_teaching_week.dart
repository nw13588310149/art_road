/// 课表「教学周」展示规则（管理员 / 任课老师 / 学生端统一）。
///
/// 后端未单独返回教学周编号；约定「今天所在周」固定展示为
/// [kScheduleCurrentTeachingWeek]，其它周按与本周的周差推算。
const int kScheduleCurrentTeachingWeek = 12;

/// 本学期总教学周数（复用「本学期所有教学周」时上限）。
const int kScheduleTermTotalWeeks = 18;

/// 把任意日期归一化到所在 ISO 周的周一。
DateTime scheduleMondayOf(DateTime date) {
  final pure = DateTime(date.year, date.month, date.day);
  return pure.subtract(Duration(days: pure.weekday - 1));
}

/// 由任意周一对应该学期的教学周序号（1-based）。
int scheduleTeachingWeekOf(
  DateTime weekStart, {
  DateTime? referenceNow,
}) {
  final monday = scheduleMondayOf(weekStart);
  final todayMonday = scheduleMondayOf(referenceNow ?? DateTime.now());
  final deltaWeeks = monday.difference(todayMonday).inDays ~/ 7;
  return kScheduleCurrentTeachingWeek + deltaWeeks;
}

/// 「回到本周」时的教学周与周一。
({DateTime monday, int week}) scheduleCurrentTeachingWeekAnchor({
  DateTime? referenceNow,
}) {
  final now = referenceNow ?? DateTime.now();
  final monday = scheduleMondayOf(now);
  return (monday: monday, week: kScheduleCurrentTeachingWeek);
}

/// 排课 / 删课「是否复用」选项 → 额外复制周数。
int scheduleReuseExtraWeeks(String mode, int currentWeek) {
  switch (mode) {
    case '本学期所有教学周':
      return (kScheduleTermTotalWeeks - currentWeek).clamp(
        0,
        kScheduleTermTotalWeeks,
      );
    case '后续 4 周':
      return 4;
    case '后续 8 周':
      return 8;
    case '不复用':
    case '仅删除本节':
    default:
      return 0;
  }
}

/// 根据复用模式展开多个排课日期（含基准日）。
List<DateTime> scheduleReuseDates({
  required DateTime base,
  required String reuseMode,
  required int currentWeek,
}) {
  final extraWeeks = scheduleReuseExtraWeeks(reuseMode, currentWeek);
  final pure = DateTime(base.year, base.month, base.day);
  return [
    for (var i = 0; i <= extraWeeks; i++) pure.add(Duration(days: i * 7)),
  ];
}
