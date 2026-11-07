/// 智慧校园统一的日期、时间与数量写法（见设计规范第 7 节）：
/// 日期 `YYYY-MM-DD`，列表时间 `MM-DD HH:mm`，不显示秒；同一天的时间段只写
/// 一次日期；中文单位前留一个半角空格。
library;

const List<String> campusWeekdayLabels = [
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// 接口时间（`yyyy-MM-dd HH:mm:ss`、ISO 字符串或 [DateTime]）转 [DateTime]。
DateTime? campusParseTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final text = raw.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text)?.toLocal();
}

/// `2026-11-07`。
String campusDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// `11-07`。
String campusMonthDay(DateTime d) => '${_two(d.month)}-${_two(d.day)}';

/// `14:05`。
String campusClock(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// `2026-11-07 14:05`。
String campusDateTime(DateTime d) => '${campusDate(d)} ${campusClock(d)}';

/// 列表时间 `11-07 14:05`。
String campusListTime(DateTime d) => '${campusMonthDay(d)} ${campusClock(d)}';

/// `2026-11-07 周六`。
String campusDateWithWeekday(DateTime d) =>
    '${campusDate(d)} ${campusWeekdayLabels[d.weekday - 1]}';

/// 接口时间转列表写法 `MM-DD HH:mm`；解析不了时原样返回（去掉秒）。
String campusListTimeOf(Object? raw, {String fallback = ''}) {
  final t = campusParseTime(raw);
  if (t != null) return campusListTime(t);
  return _stripSeconds(raw?.toString().trim() ?? '', fallback);
}

/// 接口时间转 `YYYY-MM-DD HH:mm`；解析不了时原样返回（去掉秒）。
String campusDateTimeOf(Object? raw, {String fallback = ''}) {
  final t = campusParseTime(raw);
  if (t != null) return campusDateTime(t);
  return _stripSeconds(raw?.toString().trim() ?? '', fallback);
}

/// 接口时间转 `YYYY-MM-DD`。
String campusDateOf(Object? raw, {String fallback = ''}) {
  final t = campusParseTime(raw);
  if (t != null) return campusDate(t);
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null') return fallback;
  return text.replaceAll('/', '-').replaceAll('.', '-');
}

/// 时间段：同一天写成 `11-07 14:00–17:00`，跨天写成 `11-07 14:00 – 11-08 17:00`。
String campusRange(Object? start, Object? end, {String fallback = '—'}) {
  final s = campusParseTime(start);
  final e = campusParseTime(end);
  if (s == null && e == null) return fallback;
  if (s == null) return campusListTime(e!);
  if (e == null) return campusListTime(s);
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  if (sameDay) {
    return '${campusMonthDay(s)} ${campusClock(s)}–${campusClock(e)}';
  }
  return '${campusListTime(s)} – ${campusListTime(e)}';
}

/// 「2天」「3.5小时」「2」→「2 天」「3.5 小时」「2 天」；[prefix] 为「时长」时
/// 输出「时长 2 天」。
String campusDuration(String raw, {String prefix = '', String unit = '天'}) {
  var text = raw.trim();
  if (text.isEmpty || text == '—' || text == 'null') return '—';
  text = text.replaceFirst(RegExp(r'^时长\s*'), '');
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) {
    text = '$text$unit';
  }
  text = text.replaceAllMapped(
    RegExp(r'(\d)\s*([\u4e00-\u9fa5])'),
    (m) => '${m[1]} ${m[2]}',
  );
  return prefix.isEmpty ? text : '$prefix $text';
}

/// 分数写法与全应用 `formatScore` 一致：保留一位小数，整数不带 `.0`
/// （`81.0` → `81`，`92.46` → `92.5`）；为空时返回 [fallback]。
String campusScore(num? score, {String fallback = '—'}) {
  if (score == null) return fallback;
  final rounded = (score * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

String _stripSeconds(String text, String fallback) {
  if (text.isEmpty || text == 'null') return fallback;
  return text.replaceAllMapped(RegExp(r'(\d{1,2}:\d{2}):\d{2}'), (m) => m[1]!);
}
