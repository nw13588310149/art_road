/// 演示数据的时间基准。
///
/// 过去发生的事（发帖、消息、通知、请假、点评、提交）以 [now] 为基准倒推，
/// 保证无论几点打开演示，都不会出现凌晨上课、凌晨发帖之类的时间，且永远不晚于
/// 真实当前时间（界面上的「x 分钟前」不会出现负数）：
/// - 08:30–21:30 之间：就是真实当前时间；
/// - 21:30 之后：当天 21:30；
/// - 08:30 之前：前一天 21:30。
///
/// 课表这类按日排程的数据不要用它推算，直接用固定的白天时段（见 [daySlots]）。
abstract final class DemoClock {
  static const _dayStart = Duration(hours: 8, minutes: 30);
  static const _dayEnd = Duration(hours: 21, minutes: 30);

  /// 画室一天的固定上课时段（开始、结束），课表、签到、考试安排共用。
  static const daySlots = <(String, String)>[
    ('08:30', '11:30'),
    ('14:00', '17:00'),
    ('19:00', '21:00'),
  ];

  static DateTime now([DateTime? real]) {
    final current = real ?? DateTime.now();
    final midnight = DateTime(current.year, current.month, current.day);
    final sinceMidnight = current.difference(midnight);
    if (sinceMidnight < _dayStart) {
      return midnight.subtract(const Duration(days: 1)).add(_dayEnd);
    }
    if (sinceMidnight > _dayEnd) {
      return midnight.add(_dayEnd);
    }
    return current;
  }

  /// 以 [now] 为基准往前推 [ago]；推到夜间时落回前一个白天的 21:30 之前。
  static DateTime ago(Duration ago, [DateTime? real]) {
    var t = now(real).subtract(ago);
    final midnight = DateTime(t.year, t.month, t.day);
    final sinceMidnight = t.difference(midnight);
    if (sinceMidnight < _dayStart) {
      t = midnight.subtract(const Duration(days: 1)).add(_dayEnd).subtract(
        _dayStart - sinceMidnight,
      );
    } else if (sinceMidnight > _dayEnd) {
      t = midnight.add(_dayEnd).subtract(sinceMidnight - _dayEnd);
    }
    return t;
  }
}
