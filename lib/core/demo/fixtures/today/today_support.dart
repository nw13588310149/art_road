/// 今日看板演示接口的公共部分：当天状态、内部取数、步骤与图表的 JSON 写法。
library;

import 'dart:async';

import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';

typedef Json = Map<String, dynamic>;

String todayDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String todayShortDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const todayWeekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

int? todayMinutes(String clock) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(clock);
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

String todayClock(Object? raw) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch('${raw ?? ''}');
  return match == null
      ? ''
      : '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

Json todayMap(Object? raw) => raw is Map
    ? raw.map((key, value) => MapEntry('$key', value))
    : <String, dynamic>{};

List<Json> todayRows(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if (item is Map) todayMap(item),
];

int todayInt(Object? raw) =>
    raw is num ? raw.round() : int.tryParse('${raw ?? ''}') ?? 0;

double? todayNum(Object? raw) =>
    raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');

String todayText(Object? raw) {
  final text = '${raw ?? ''}'.trim();
  return text == 'null' ? '' : text;
}

/// 分数的写法：整数不带小数点。
String todayScore(num? value) {
  if (value == null) return '—';
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

/// 一次请求里的上下文：是谁、现在几点、当天已经勾了什么。
class TodayContext {
  TodayContext(this.req, {DateTime? now})
    : now = now ?? DateTime.now(),
      account = req.account {
    date = todayDate(this.now);
    state = TodayDemoState.of(account, date);
  }

  final DemoRequest req;
  final DemoAccount account;
  final DateTime now;
  late final String date;
  late final Json state;

  int get nowMinutes => now.hour * 60 + now.minute;

  /// 今天已经处理掉的审批、回复条数（各项「第一次看到的数量 − 现在的数量」之和）。
  int handledToday = 0;

  /// 调平台接口（`/app/*`，POST）。接口不存在或业务失败时返回 null，
  /// 看板缺这一块内容，其余照常。
  Future<Object?> platform(String path, [Json body = const {}]) =>
      _call(DemoBackend.platform, 'POST', path, body: body);

  /// 调平台接口里用 GET 的那一部分（书刊）。
  Future<Object?> platformGet(String path, [Json query = const {}]) =>
      _call(DemoBackend.platform, 'GET', path, query: query);

  /// 调阅卷接口（GET）。
  Future<Object?> marking(String path, [Json query = const {}]) =>
      _call(DemoBackend.marking, 'GET', path, query: query);

  Future<Object?> _call(
    DemoRouter router,
    String method,
    String path, {
    Json query = const {},
    Json body = const {},
  }) async {
    final match = router.match(method, path);
    if (match == null) return null;
    try {
      return await match.handler(
        DemoRequest(
          method: method,
          path: path,
          query: query,
          body: body,
          headers: <String, dynamic>{'app-token': req.token},
          pathParams: match.params,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 与账号、日期绑定的稳定随机数：同一天多次打开数字不变。
  int seeded(String key, int min, int max, {int dayOffset = 0}) {
    final day = todayDate(now.add(Duration(days: dayOffset)));
    var hash = 0x811c9dc5;
    for (final unit in '${account.mobile}|$day|$key'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return min + hash % (max - min + 1);
  }

  /// 当天第一次看到的数量。之后数量变小，差值就是今天处理掉的。
  int baseline(String id, int current) {
    final map = todayMap(state['baseline']);
    final stored = map['count:$id'];
    if (stored is num && stored >= current) return stored.toInt();
    map['count:$id'] = current;
    state['baseline'] = map;
    TodayDemoState.save();
    return current;
  }

  bool isDone(String id) => TodayDemoState.ids(state, 'done').contains(id);
  bool isSkipped(String id) =>
      TodayDemoState.ids(state, 'skipped').contains(id);
  bool isSnoozed(String id) =>
      TodayDemoState.ids(state, 'snoozed').contains(id);
  bool isFollowed(String id) =>
      TodayDemoState.ids(state, 'followed').contains(id);
}

/// 今日看板的可写状态：每个账号一份，跨天后清空当天的勾选。
abstract final class TodayDemoState {
  static const _key = 'today_board';

  static Json _all() => DemoStore.map(_key, () => <String, dynamic>{});

  static Json of(DemoAccount account, String date) {
    final all = _all();
    final stored = all[account.mobile];
    if (stored is Map && stored['date'] == date) {
      return stored as Json;
    }
    final fresh = <String, dynamic>{
      'date': date,
      'done': <dynamic>[],
      'skipped': <dynamic>[],
      'snoozed': <dynamic>[],
      'followed': <dynamic>[],
      'custom': <dynamic>[],
      'practice': 0,
      'baseline': <String, dynamic>{},
      // 用法提示看过一次就不再出现，不随日期清空。
      'tipSeen': stored is Map && stored['tipSeen'] == true,
    };
    all[account.mobile] = fresh;
    return fresh;
  }

  static List<dynamic> ids(Json state, String key) {
    final value = state[key];
    if (value is List) return value;
    final list = <dynamic>[];
    state[key] = list;
    return list;
  }

  static void toggle(Json state, String key, String id, bool on) {
    final list = ids(state, key);
    list.remove(id);
    if (on) list.add(id);
  }

  static void save() => DemoStore.save(_key);
}

// ───────────────────────── 步骤 ─────────────────────────

/// 时段：上午、下午、晚上；没有时间的归到「随时可做」。
String todaySlotOf(String clock) {
  final minutes = todayMinutes(clock);
  if (minutes == null) return 'anytime';
  if (minutes < 12 * 60) return 'morning';
  if (minutes < 18 * 60) return 'afternoon';
  return 'evening';
}

/// 一件要做的事。[status]：todo 未开始、doing 进行中、done 已完成、overdue 已超时、
/// skipped 今天不做。[manual] 为 true 时由本人打勾，否则跟着业务数据自动变化。
Json todayStep({
  required String id,
  required String kind,
  required String title,
  String detail = '',
  String time = '',
  String endTime = '',
  String slot = '',
  String deadline = '',
  String status = 'todo',
  bool required = true,
  bool manual = false,
  String tag = '',
  String tagTone = 'neutral',
  String subject = '',
  String source = '',
  int minutes = 0,
  Json? progress,
  List<String> guide = const <String>[],
  Json? action,
  bool custom = false,
}) => <String, dynamic>{
  'id': id,
  'kind': kind,
  'title': title,
  'detail': detail,
  'time': time,
  'endTime': endTime,
  'slot': slot.isEmpty ? todaySlotOf(time) : slot,
  'deadline': deadline,
  'status': status,
  'required': required,
  'manual': manual,
  'tag': tag,
  'tagTone': tagTone,
  'subject': subject,
  'source': source,
  'minutes': minutes,
  'progress': progress,
  'guide': guide,
  'action': action,
  'custom': custom,
  'snoozed': false,
};

/// 一件按数量计的事（审批、回复、审核）：还有 [current] 条没处理。
///
/// 当天处理掉的算作进度，全部处理完显示为已完成；当天一直没有的不出现。
Json? todayCountStep(
  TodayContext ctx, {
  required String id,
  required String kind,
  required String title,
  required String detail,
  required String doneDetail,
  required String unit,
  required int current,
  required String source,
  required List<String> guide,
  required Json action,
  int overdue = 0,
  String slot = 'anytime',
}) {
  final initial = ctx.baseline(id, current);
  if (initial == 0) return null;
  ctx.handledToday += initial - current;
  return todayStep(
    id: id,
    kind: kind,
    title: title,
    detail: current == 0 ? doneDetail : detail,
    slot: slot,
    status: current == 0
        ? 'done'
        : (overdue > 0 ? 'overdue' : (current < initial ? 'doing' : 'todo')),
    tag: overdue > 0 && current > 0 ? '超时 $overdue $unit' : '',
    tagTone: 'danger',
    progress: todayProgress(initial - current, initial, unit),
    source: source,
    guide: guide,
    action: action,
  );
}

Json todayProgress(int done, int total, String unit) => <String, dynamic>{
  'done': done,
  'total': total,
  'unit': unit,
};

Json actionRoute(String label, String route, [Json? arguments]) =>
    <String, dynamic>{
      'label': label,
      'type': 'route',
      'route': route,
      'arguments': arguments,
    };

/// 打开智慧校园里的一个视图，[entry] 是客户端 `CampusEntry` 的名字。
Json actionCampus(String label, String entry) => <String, dynamic>{
  'label': label,
  'type': 'campus',
  'entry': entry,
};

/// 打开一份教学报表，[report] 是客户端 `TeachingReport` 的名字。
Json actionReport(
  String label,
  String report, {
  String parameter = '',
  String campus = '',
}) => <String, dynamic>{
  'label': label,
  'type': 'report',
  'report': report,
  'parameter': parameter,
  'campus': campus,
};

Json actionUpload(
  String label, {
  String taskId = '',
  String parentId = '',
  required String title,
  required String subject,
}) => <String, dynamic>{
  'label': label,
  'type': 'upload',
  'taskId': taskId,
  'parentId': parentId,
  'title': title,
  'subject': subject,
};

Json actionSchedule(String label) => <String, dynamic>{
  'label': label,
  'type': 'schedule',
};

/// 打开画室工具箱里的一个工具，[tool] 是工具名称或 key。
Json actionTool(String label, String tool) => <String, dynamic>{
  'label': label,
  'type': 'tool',
  'tool': tool,
};

Json actionGallery(String label, String subject, [String keyword = '']) =>
    <String, dynamic>{
      'label': label,
      'type': 'gallery',
      'subject': subject,
      'keyword': keyword,
    };

Json actionPracticeLog(String label) => <String, dynamic>{
  'label': label,
  'type': 'practiceLog',
};

// ───────────────────────── 图表 ─────────────────────────

Json _chart(
  String id,
  String type,
  String title, {
  String subtitle = '',
  String caption = '',
  String empty = '',
  Json? action,
  Json? headline,
  required Json body,
}) => <String, dynamic>{
  'id': id,
  'type': type,
  'title': title,
  'subtitle': subtitle,
  'caption': caption,
  'empty': empty,
  'action': action,
  'headline': headline,
  ...body,
};

/// 图表上方的一个大数字：这张图最想让人记住的那个数。
Json chartHeadline(
  String value, {
  String unit = '',
  String label = '',
  String delta = '',
  bool deltaGood = true,
}) => <String, dynamic>{
  'value': value,
  'unit': unit,
  'label': label,
  'delta': delta,
  'deltaGood': deltaGood,
};

/// 页面顶部的一张数字卡。[tone]：purple / pink / teal / amber / blue。
/// [ratio] 不为空时在数字旁边画一个进度环；[trend] 是这个数近几天的值（最后一个
/// 是今天），给出时画一排小柱子。两个都给时画小柱子。
Json todayHighlight(
  String id,
  String label,
  String value, {
  String unit = '',
  String caption = '',
  required String icon,
  required String tone,
  double? ratio,
  List<num>? trend,
  Json? action,
}) => <String, dynamic>{
  'id': id,
  'label': label,
  'value': value,
  'unit': unit,
  'caption': caption,
  'icon': icon,
  'tone': tone,
  'ratio': ratio,
  'trend': trend,
  'action': action,
};

/// 进度条列表：每行一个名字、一个比例和一句说明。
/// [tone]：brand / good / caution / bad。
Json chartMeters(
  String id,
  String title, {
  String subtitle = '',
  String caption = '',
  String empty = '',
  Json? action,
  required List<Json> rows,
}) => _chart(
  id,
  'meters',
  title,
  subtitle: subtitle,
  caption: caption,
  empty: empty,
  action: action,
  body: {'rows': rows},
);

Json meterRow(
  String label,
  num value,
  num max, {
  String text = '',
  String caption = '',
  String tone = 'brand',
  String tag = '',
  String tagTone = 'caution',
}) => <String, dynamic>{
  'label': label,
  'value': value,
  'max': max,
  'text': text,
  'caption': caption,
  'tone': tone,
  'tag': tag,
  'tagTone': tagTone,
};

/// 柱状图：一组同类数量按类别比较。[total] 不为空时在柱子后面画出计划量。
Json chartColumns(
  String id,
  String title, {
  String subtitle = '',
  String caption = '',
  String unit = '',
  String empty = '',
  Json? action,
  Json? headline,
  required List<Json> items,
}) => _chart(
  id,
  'columns',
  title,
  subtitle: subtitle,
  caption: caption,
  empty: empty,
  action: action,
  headline: headline,
  body: {'unit': unit, 'items': items},
);

Json columnItem(
  String label,
  num? value, {
  num? total,
  bool emphasis = false,
  String note = '',
}) => <String, dynamic>{
  'label': label,
  'value': value,
  'total': total,
  'emphasis': emphasis,
  'note': note,
};

/// 折线图：一个数量随时间的变化，可带一条目标线。
Json chartLine(
  String id,
  String title, {
  String subtitle = '',
  String caption = '',
  String unit = '',
  num? target,
  String targetLabel = '',
  String empty = '',
  Json? action,
  Json? headline,
  required List<Json> points,
}) => _chart(
  id,
  'line',
  title,
  subtitle: subtitle,
  caption: caption,
  empty: empty,
  action: action,
  headline: headline,
  body: {
    'unit': unit,
    'target': target,
    'targetLabel': targetLabel,
    'points': points,
  },
);

Json linePoint(String label, num? value, [String note = '']) =>
    <String, dynamic>{'label': label, 'value': value, 'note': note};

/// 分段条：一个整体分成几部分。[tone]：good / caution / bad / neutral / brand。
Json chartParts(
  String id,
  String title, {
  String subtitle = '',
  String caption = '',
  String unit = '',
  String empty = '',
  Json? action,
  Json? headline,
  required List<Json> parts,
}) => _chart(
  id,
  'parts',
  title,
  subtitle: subtitle,
  caption: caption,
  empty: empty,
  action: action,
  headline: headline,
  body: {'unit': unit, 'parts': parts},
);

Json partItem(String label, num value, String tone) => <String, dynamic>{
  'label': label,
  'value': value,
  'tone': tone,
};

// ───────────────────────── 汇总 ─────────────────────────

const _slotOrder = ['urgent', 'morning', 'afternoon', 'evening', 'anytime'];

const _slotTitles = {
  'urgent': '优先处理',
  'morning': '上午',
  'afternoon': '下午',
  'evening': '晚上',
  'anytime': '今天内完成',
};

const _slotCaptions = {
  'urgent': '已经超时，先把这些处理掉',
  'morning': '12:00 前',
  'afternoon': '12:00 – 18:00',
  'evening': '18:00 之后',
  'anytime': '没有固定时间，抽空完成',
};

/// 把步骤套上当天的勾选状态，再按时段分组、算出进度和下一步。
Json todayAssemble(
  TodayContext ctx, {
  required String title,
  required List<Json> steps,
  required List<Json> charts,
  required List<Json> shortcuts,
  required String streakLabel,
  required int streakDays,
  List<Json> highlights = const <Json>[],
  Json? people,
}) {
  final all = <Json>[...steps, ..._customSteps(ctx)];
  for (final step in all) {
    _applyState(ctx, step);
  }

  final active = [
    for (final step in all)
      if (step['status'] != 'skipped') step,
  ];
  final done = active.where((s) => s['status'] == 'done').length;
  final overdue = active.where((s) => s['status'] == 'overdue').length;

  final groups = <Json>[];
  for (final slot in _slotOrder) {
    final items = [
      for (final step in all)
        if (_groupOf(step) == slot) step,
    ]..sort(_byTime);
    if (items.isEmpty) continue;
    groups.add(<String, dynamic>{
      'id': slot,
      'title': _slotTitles[slot],
      'caption': _slotCaptions[slot],
      'steps': items,
    });
  }

  final focus = _focus(ctx, active);
  final week = _weekColumns(ctx, done: done, total: active.length);
  return <String, dynamic>{
    'date': ctx.date,
    'role': ctx.account.roleKey,
    'title': title,
    'tipSeen': ctx.state['tipSeen'] == true,
    'summary': <String, dynamic>{
      'total': active.length,
      'done': done,
      'remaining': active.length - done,
      'overdue': overdue,
      'streakDays':
          streakDays + (active.isNotEmpty && done == active.length ? 1 : 0),
      'streakLabel': streakLabel,
    },
    'focusStepId': focus?.$1 ?? '',
    'focusReason': focus?.$2 ?? '',
    'highlights': highlights,
    'groups': groups,
    'charts': [week, ...charts],
    'people': people,
    'shortcuts': shortcuts,
  };
}

/// 超时的事单独排在前面；推迟过的放到晚上。
String _groupOf(Json step) {
  if (step['status'] == 'overdue') return 'urgent';
  if (step['snoozed'] == true) return 'evening';
  return todayText(step['slot']);
}

int _byTime(Json a, Json b) {
  final at = todayMinutes(todayText(a['time'])) ?? 24 * 60;
  final bt = todayMinutes(todayText(b['time'])) ?? 24 * 60;
  if (at != bt) return at.compareTo(bt);
  // 同一时间里必做的在前。
  return (a['required'] == true ? 0 : 1).compareTo(
    b['required'] == true ? 0 : 1,
  );
}

void _applyState(TodayContext ctx, Json step) {
  final id = todayText(step['id']);
  if (ctx.isSkipped(id)) {
    step['status'] = 'skipped';
    return;
  }
  if (step['manual'] == true) {
    if (ctx.isDone(id)) {
      step['status'] = 'done';
    } else if (step['status'] != 'overdue') {
      // 有结束时间、过了点还没勾的，算超时。
      final end = todayMinutes(todayText(step['endTime']));
      step['status'] =
          step['required'] == true && end != null && ctx.nowMinutes > end
          ? 'overdue'
          : 'todo';
    }
  }
  if (ctx.isSnoozed(id) && step['status'] == 'todo') {
    step['snoozed'] = true;
  }
}

List<Json> _customSteps(TodayContext ctx) => [
  for (final item in TodayDemoState.ids(ctx.state, 'custom'))
    if (item is Map)
      todayStep(
        id: todayText(item['id']),
        kind: 'custom',
        title: todayText(item['title']),
        detail: todayText(item['detail']),
        time: todayText(item['time']),
        slot: todayText(item['slot']),
        required: false,
        manual: true,
        source: '自己添加的安排',
        tag: '自己添加',
        custom: true,
      ),
];

/// 下一步：超时的优先，其次是正在进行的，再是接下来必做的，最后是建议做的。
(String, String)? _focus(TodayContext ctx, List<Json> steps) {
  Json? pick(bool Function(Json) test) {
    final found = [
      for (final s in steps)
        if (test(s)) s,
    ]..sort(_byTime);
    return found.isEmpty ? null : found.first;
  }

  bool open(Json s) => s['status'] == 'todo' || s['status'] == 'doing';
  final overdue = pick((s) => s['status'] == 'overdue');
  if (overdue != null) {
    return (todayText(overdue['id']), '已经超时，先把它处理掉');
  }
  final doing = pick((s) => s['status'] == 'doing');
  if (doing != null) {
    final time = todayText(doing['time']);
    return (
      todayText(doing['id']),
      time.isEmpty ? '正在进行，接着做完' : '正在进行，$time 开始的',
    );
  }
  final required = pick((s) => open(s) && s['required'] == true);
  if (required != null) {
    return (todayText(required['id']), _reason(ctx, required));
  }
  final optional = pick(open);
  if (optional != null) {
    return (todayText(optional['id']), '必做的都完成了，可以再做这一项');
  }
  return null;
}

String _reason(TodayContext ctx, Json step) {
  final deadline = todayText(step['deadline']);
  if (deadline.startsWith(ctx.date)) {
    return '今天 ${todayClock(deadline)} 截止';
  }
  final time = todayText(step['time']);
  final start = todayMinutes(time);
  if (start != null) {
    final wait = start - ctx.nowMinutes;
    if (wait > 0 && wait <= 90) return '$time 开始，还有 $wait 分钟';
    if (wait > 0) return '接下来 $time 开始';
  }
  return '今天要完成，现在可以开始';
}

/// 近七天每天完成了几项：前六天是稳定的模拟数，今天是实际进度。
Json _weekColumns(TodayContext ctx, {required int done, required int total}) {
  var weekDone = 0;
  var weekTotal = 0;
  final items = <Json>[];
  for (var offset = -6; offset <= 0; offset++) {
    final day = ctx.now.add(Duration(days: offset));
    final label = offset == 0 ? '今天' : todayWeekdays[day.weekday - 1];
    final dayTotal = offset == 0
        ? total
        : ctx.seeded('week-total', 6, 9, dayOffset: offset);
    final dayDone = offset == 0
        ? done
        : dayTotal - ctx.seeded('week-missed', 0, 2, dayOffset: offset) ~/ 2;
    weekDone += dayDone;
    weekTotal += dayTotal;
    items.add(
      columnItem(
        label,
        dayDone,
        total: dayTotal,
        emphasis: offset == 0,
        note: '${todayShortDate(day)} 完成 $dayDone / $dayTotal 件',
      ),
    );
  }
  return chartColumns(
    'week',
    '近 7 天完成',
    subtitle: '共完成 $weekDone / $weekTotal 件',
    unit: '件',
    headline: chartHeadline(
      weekTotal == 0 ? '—' : '${(weekDone * 100 / weekTotal).round()}',
      unit: '%',
      label: '完成率',
    ),
    items: items,
  );
}

/// 近七天的一条序列：前六天是稳定的模拟数，[today] 是当天的实际值。
List<Json> todayWeekSeries(
  TodayContext ctx,
  String key, {
  required int min,
  required int max,
  required num? today,
  String unit = '',
}) => [
  for (var offset = -6; offset <= 0; offset++)
    () {
      final day = ctx.now.add(Duration(days: offset));
      final num? value = offset == 0
          ? today
          : ctx.seeded(key, min, max, dayOffset: offset);
      return linePoint(
        todayShortDate(day),
        value,
        value == null ? '' : '${todayShortDate(day)} ${todayScore(value)}$unit',
      );
    }(),
];

Json todayShortcut(String label, String icon, Json action) => <String, dynamic>{
  'label': label,
  'icon': icon,
  'action': action,
};
