import 'package:flutter/foundation.dart';

Map<String, dynamic> _map(Object? raw) => raw is Map
    ? raw.map((key, value) => MapEntry('$key', value))
    : const <String, dynamic>{};

List<Map<String, dynamic>> _rows(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if (item is Map) _map(item),
];

String _str(Object? raw) {
  final text = '${raw ?? ''}'.trim();
  return text == 'null' ? '' : text;
}

int _int(Object? raw) =>
    raw is num ? raw.round() : int.tryParse(_str(raw)) ?? 0;

double? _num(Object? raw) =>
    raw is num ? raw.toDouble() : double.tryParse(_str(raw));

/// 一件事的状态。
enum TodayStepStatus {
  todo('未开始'),
  doing('进行中'),
  done('已完成'),
  overdue('已超时'),
  skipped('今天不做');

  const TodayStepStatus(this.label);

  final String label;

  static TodayStepStatus parse(Object? raw) => switch (_str(raw)) {
    'doing' => TodayStepStatus.doing,
    'done' => TodayStepStatus.done,
    'overdue' => TodayStepStatus.overdue,
    'skipped' => TodayStepStatus.skipped,
    _ => TodayStepStatus.todo,
  };

  /// 还没做完：未开始、进行中、已超时。
  bool get open =>
      this == TodayStepStatus.todo ||
      this == TodayStepStatus.doing ||
      this == TodayStepStatus.overdue;
}

/// 点一下之后去哪里。[type]：route / campus / report / upload / schedule / tool /
/// gallery / practiceLog。
@immutable
class TodayAction {
  const TodayAction({
    required this.label,
    required this.type,
    this.route = '',
    this.arguments,
    this.entry = '',
    this.report = '',
    this.parameter = '',
    this.campus = '',
    this.taskId = '',
    this.parentId = '',
    this.title = '',
    this.subject = '',
    this.tool = '',
    this.keyword = '',
  });

  static TodayAction? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = _map(raw);
    final type = _str(json['type']);
    if (type.isEmpty) return null;
    final arguments = json['arguments'];
    return TodayAction(
      label: _str(json['label']),
      type: type,
      route: _str(json['route']),
      arguments: arguments is Map ? _map(arguments) : null,
      entry: _str(json['entry']),
      report: _str(json['report']),
      parameter: _str(json['parameter']),
      campus: _str(json['campus']),
      taskId: _str(json['taskId']),
      parentId: _str(json['parentId']),
      title: _str(json['title']),
      subject: _str(json['subject']),
      tool: _str(json['tool']),
      keyword: _str(json['keyword']),
    );
  }

  final String label;
  final String type;
  final String route;
  final Map<String, dynamic>? arguments;

  /// `CampusEntry` 的名字。
  final String entry;

  /// `TeachingReport` 的名字，以及报表参数与校区。
  final String report;
  final String parameter;
  final String campus;

  /// 上传作品：交老师布置的作品（[taskId]）或改画重交（[parentId]）。
  final String taskId;
  final String parentId;
  final String title;
  final String subject;

  /// 画室工具的名称或 key；范画库的关键词。
  final String tool;
  final String keyword;
}

/// 做到第几个、一共几个。
@immutable
class TodayProgress {
  const TodayProgress({
    required this.done,
    required this.total,
    this.unit = '',
  });

  static TodayProgress? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final total = _int(raw['total']);
    if (total <= 0) return null;
    return TodayProgress(
      done: _int(raw['done']).clamp(0, total),
      total: total,
      unit: _str(raw['unit']),
    );
  }

  final int done;
  final int total;
  final String unit;

  double get ratio => total == 0 ? 0 : done / total;
}

/// 清单里的一件事。
@immutable
class TodayStep {
  const TodayStep({
    required this.id,
    required this.kind,
    required this.title,
    this.detail = '',
    this.time = '',
    this.endTime = '',
    this.status = TodayStepStatus.todo,
    this.required = true,
    this.manual = false,
    this.tag = '',
    this.tagTone = 'neutral',
    this.subject = '',
    this.source = '',
    this.minutes = 0,
    this.progress,
    this.guide = const <String>[],
    this.action,
    this.custom = false,
    this.snoozed = false,
  });

  factory TodayStep.fromJson(Object? raw) {
    final json = _map(raw);
    final guide = json['guide'];
    return TodayStep(
      id: _str(json['id']),
      kind: _str(json['kind']),
      title: _str(json['title']),
      detail: _str(json['detail']),
      time: _str(json['time']),
      endTime: _str(json['endTime']),
      status: TodayStepStatus.parse(json['status']),
      required: json['required'] != false,
      manual: json['manual'] == true,
      tag: _str(json['tag']),
      tagTone: _str(json['tagTone']),
      subject: _str(json['subject']),
      source: _str(json['source']),
      minutes: _int(json['minutes']),
      progress: TodayProgress.tryParse(json['progress']),
      guide: [
        if (guide is List)
          for (final line in guide)
            if (_str(line).isNotEmpty) _str(line),
      ],
      action: TodayAction.tryParse(json['action']),
      custom: json['custom'] == true,
      snoozed: json['snoozed'] == true,
    );
  }

  final String id;

  /// lesson / homework / revise / practice / reading / critique / dorm / review / lead /
  /// approval / supervise / follow / message / patrol / punch / note / custom。
  final String kind;
  final String title;
  final String detail;

  /// `HH:mm`，没有固定时间时为空。
  final String time;
  final String endTime;
  final TodayStepStatus status;

  /// 必做（学校或老师安排的）；否则是建议做的。
  final bool required;

  /// 由本人打勾；否则跟着业务数据自动完成。
  final bool manual;
  final String tag;

  /// danger / warning / neutral。
  final String tagTone;
  final String subject;

  /// 这件事是哪里来的（老师布置、课表、点评建议…）。
  final String source;

  /// 建议用时（分钟），0 表示不显示。
  final int minutes;
  final TodayProgress? progress;

  /// 「怎么做」的几步。
  final List<String> guide;
  final TodayAction? action;

  /// 本人添加的安排，可以删除。
  final bool custom;

  /// 已推迟到晚上。
  final bool snoozed;

  bool get done => status == TodayStepStatus.done;

  /// 起止时间的写法：08:30–11:30。
  String get timeRange =>
      endTime.isEmpty || time.isEmpty ? time : '$time–$endTime';

  TodayStep copyWith({TodayStepStatus? status}) => TodayStep(
    id: id,
    kind: kind,
    title: title,
    detail: detail,
    time: time,
    endTime: endTime,
    status: status ?? this.status,
    required: required,
    manual: manual,
    tag: tag,
    tagTone: tagTone,
    subject: subject,
    source: source,
    minutes: minutes,
    progress: progress,
    guide: guide,
    action: action,
    custom: custom,
    snoozed: snoozed,
  );
}

/// 一个时段的事：优先处理、上午、下午、晚上、今天内完成。
@immutable
class TodayGroup {
  const TodayGroup({
    required this.id,
    required this.title,
    this.caption = '',
    this.steps = const <TodayStep>[],
  });

  factory TodayGroup.fromJson(Object? raw) {
    final json = _map(raw);
    return TodayGroup(
      id: _str(json['id']),
      title: _str(json['title']),
      caption: _str(json['caption']),
      steps: [
        for (final step in _rows(json['steps'])) TodayStep.fromJson(step),
      ],
    );
  }

  final String id;
  final String title;
  final String caption;
  final List<TodayStep> steps;
}

/// 当天的进度。
@immutable
class TodaySummary {
  const TodaySummary({
    this.total = 0,
    this.done = 0,
    this.remaining = 0,
    this.overdue = 0,
    this.streakDays = 0,
    this.streakLabel = '',
  });

  factory TodaySummary.fromJson(Object? raw) {
    final json = _map(raw);
    return TodaySummary(
      total: _int(json['total']),
      done: _int(json['done']),
      remaining: _int(json['remaining']),
      overdue: _int(json['overdue']),
      streakDays: _int(json['streakDays']),
      streakLabel: _str(json['streakLabel']),
    );
  }

  final int total;
  final int done;

  /// 还没做完的件数：导航角标用它。
  final int remaining;
  final int overdue;
  final int streakDays;
  final String streakLabel;

  bool get allDone => total > 0 && remaining == 0;
}

/// 页面顶部的一张数字卡：一个图标、一个数字和一句说明。
@immutable
class TodayHighlight {
  const TodayHighlight({
    required this.id,
    required this.label,
    required this.value,
    this.unit = '',
    this.caption = '',
    this.icon = '',
    this.tone = 'purple',
    this.ratio,
    this.trend = const <double>[],
    this.action,
  });

  factory TodayHighlight.fromJson(Object? raw) {
    final json = _map(raw);
    return TodayHighlight(
      id: _str(json['id']),
      label: _str(json['label']),
      value: _str(json['value']),
      unit: _str(json['unit']),
      caption: _str(json['caption']),
      icon: _str(json['icon']),
      tone: _str(json['tone']),
      ratio: _num(json['ratio'])?.clamp(0.0, 1.0),
      trend: [
        if (json['trend'] is List)
          for (final value in json['trend'] as List)
            if (value is num && value >= 0) value.toDouble(),
      ],
      action: TodayAction.tryParse(json['action']),
    );
  }

  final String id;
  final String label;
  final String value;
  final String unit;
  final String caption;

  /// 图标的名字，界面按名字取图标。
  final String icon;

  /// purple / pink / teal / amber。
  final String tone;

  /// 0–1，不为空时在数字旁边画一个进度环。
  final double? ratio;

  /// 近几天的数，最后一个是今天；不少于两个时在数字旁边画一排小柱子。
  final List<double> trend;
  final TodayAction? action;
}

/// 图表上方的大数字。
@immutable
class TodayHeadline {
  const TodayHeadline({
    required this.value,
    this.unit = '',
    this.label = '',
    this.delta = '',
    this.deltaGood = true,
  });

  static TodayHeadline? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final value = _str(raw['value']);
    if (value.isEmpty) return null;
    return TodayHeadline(
      value: value,
      unit: _str(raw['unit']),
      label: _str(raw['label']),
      delta: _str(raw['delta']),
      deltaGood: raw['deltaGood'] != false,
    );
  }

  final String value;
  final String unit;
  final String label;

  /// 与上一期的差值，如「较上一份 +2」。
  final String delta;
  final bool deltaGood;
}

// ───────────────────────── 图表 ─────────────────────────

/// 图表共有的部分。
@immutable
sealed class TodayChart {
  const TodayChart({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.caption = '',
    this.empty = '',
    this.action,
    this.headline,
  });

  /// 不认识的类型返回 null，页面跳过它。
  static TodayChart? tryParse(Object? raw) {
    final json = _map(raw);
    final id = _str(json['id']);
    final title = _str(json['title']);
    final subtitle = _str(json['subtitle']);
    final caption = _str(json['caption']);
    final empty = _str(json['empty']);
    final action = TodayAction.tryParse(json['action']);
    final headline = TodayHeadline.tryParse(json['headline']);
    return switch (_str(json['type'])) {
      'meters' => TodayMetersChart(
        id: id,
        title: title,
        subtitle: subtitle,
        caption: caption,
        empty: empty,
        action: action,
        headline: headline,
        rows: [
          for (final row in _rows(json['rows']))
            TodayMeterRow(
              label: _str(row['label']),
              value: _num(row['value']) ?? 0,
              max: _num(row['max']) ?? 0,
              text: _str(row['text']),
              caption: _str(row['caption']),
              tone: _str(row['tone']),
              tag: _str(row['tag']),
            ),
        ],
      ),
      'columns' => TodayColumnsChart(
        id: id,
        title: title,
        subtitle: subtitle,
        caption: caption,
        empty: empty,
        action: action,
        headline: headline,
        unit: _str(json['unit']),
        items: [
          for (final item in _rows(json['items']))
            TodayColumnItem(
              label: _str(item['label']),
              value: _num(item['value']),
              total: _num(item['total']),
              emphasis: item['emphasis'] == true,
              note: _str(item['note']),
            ),
        ],
      ),
      'line' => TodayLineChart(
        id: id,
        title: title,
        subtitle: subtitle,
        caption: caption,
        empty: empty,
        action: action,
        headline: headline,
        unit: _str(json['unit']),
        target: _num(json['target']),
        targetLabel: _str(json['targetLabel']),
        points: [
          for (final point in _rows(json['points']))
            TodayLinePoint(
              label: _str(point['label']),
              value: _num(point['value']),
              note: _str(point['note']),
            ),
        ],
      ),
      'parts' => TodayPartsChart(
        id: id,
        title: title,
        subtitle: subtitle,
        caption: caption,
        empty: empty,
        action: action,
        headline: headline,
        unit: _str(json['unit']),
        parts: [
          for (final part in _rows(json['parts']))
            TodayPart(
              label: _str(part['label']),
              value: _num(part['value']) ?? 0,
              tone: _str(part['tone']),
            ),
        ],
      ),
      'rooms' => TodayRoomsChart(
        id: id,
        title: title,
        subtitle: subtitle,
        caption: caption,
        empty: empty,
        action: action,
        headline: headline,
        rooms: [
          for (final room in _rows(json['rooms']))
            TodayRoom(
              building: _str(room['building']),
              name: _str(room['name']),
              checked: _int(room['checked']),
              total: _int(room['total']),
              state: _str(room['state']),
            ),
        ],
      ),
      'compare' => TodayCompareChart(
        id: id,
        title: title,
        subtitle: subtitle,
        caption: caption,
        empty: empty,
        action: action,
        headline: headline,
        columns: [
          if (json['columns'] is List)
            for (final column in json['columns'] as List) _str(column),
        ],
        rows: [
          for (final row in _rows(json['rows']))
            TodayCompareRow(
              label: _str(row['label']),
              cells: [
                for (final cell in _rows(row['cells']))
                  TodayCompareCell(
                    value: _num(cell['value']) ?? 0,
                    max: _num(cell['max']) ?? 0,
                    text: _str(cell['text']),
                  ),
              ],
            ),
        ],
      ),
      _ => null,
    };
  }

  final String id;
  final String title;
  final String subtitle;

  /// 图下面的一句结论。
  final String caption;

  /// 没有数据时的说明。
  final String empty;
  final TodayAction? action;

  /// 图上方的大数字：这张图最想让人记住的那个数。
  final TodayHeadline? headline;

  /// 没有可画的数据。
  bool get isEmpty;

  /// 读屏与表格视图用的文字版：每行一条。
  List<String> get table;
}

/// 进度条列表：每行一个名字和一个比例。
class TodayMetersChart extends TodayChart {
  const TodayMetersChart({
    required super.id,
    required super.title,
    super.subtitle,
    super.caption,
    super.empty,
    super.action,
    super.headline,
    required this.rows,
  });

  final List<TodayMeterRow> rows;

  @override
  bool get isEmpty => rows.isEmpty;

  @override
  List<String> get table => [
    for (final row in rows)
      [
        row.label,
        row.text,
        row.caption,
        row.tag,
      ].where((t) => t.isNotEmpty).join('，'),
  ];
}

@immutable
class TodayMeterRow {
  const TodayMeterRow({
    required this.label,
    required this.value,
    required this.max,
    this.text = '',
    this.caption = '',
    this.tone = 'brand',
    this.tag = '',
  });

  final String label;
  final double value;
  final double max;
  final String text;
  final String caption;

  /// brand / good / caution / bad。
  final String tone;
  final String tag;

  double get ratio => max <= 0 ? 0 : (value / max).clamp(0.0, 1.0);
}

/// 柱状图：一组同类数量。
class TodayColumnsChart extends TodayChart {
  const TodayColumnsChart({
    required super.id,
    required super.title,
    super.subtitle,
    super.caption,
    super.empty,
    super.action,
    super.headline,
    this.unit = '',
    required this.items,
  });

  final String unit;
  final List<TodayColumnItem> items;

  @override
  bool get isEmpty => items.every((item) => item.value == null);

  @override
  List<String> get table => [
    for (final item in items)
      if (item.value != null)
        item.note.isNotEmpty
            ? item.note
            : '${item.label} ${_trim(item.value!)}$unit',
  ];
}

@immutable
class TodayColumnItem {
  const TodayColumnItem({
    required this.label,
    this.value,
    this.total,
    this.emphasis = false,
    this.note = '',
  });

  final String label;

  /// 为空表示这一格没有数据。
  final double? value;

  /// 计划量；有它时在柱子后面画一条浅色的底。
  final double? total;

  /// 要突出的一根（通常是今天）。
  final bool emphasis;

  /// 点按时显示的一句话。
  final String note;
}

/// 折线图：一个数量随时间的变化。
class TodayLineChart extends TodayChart {
  const TodayLineChart({
    required super.id,
    required super.title,
    super.subtitle,
    super.caption,
    super.empty,
    super.action,
    super.headline,
    this.unit = '',
    this.target,
    this.targetLabel = '',
    required this.points,
  });

  final String unit;
  final double? target;
  final String targetLabel;
  final List<TodayLinePoint> points;

  @override
  bool get isEmpty => points.where((p) => p.value != null).length < 2;

  @override
  List<String> get table => [
    for (final point in points)
      if (point.value != null)
        point.note.isNotEmpty
            ? point.note
            : '${point.label} ${_trim(point.value!)}$unit',
  ];
}

@immutable
class TodayLinePoint {
  const TodayLinePoint({required this.label, this.value, this.note = ''});

  final String label;
  final double? value;
  final String note;
}

/// 分段条：一个整体分成几部分。
class TodayPartsChart extends TodayChart {
  const TodayPartsChart({
    required super.id,
    required super.title,
    super.subtitle,
    super.caption,
    super.empty,
    super.action,
    super.headline,
    this.unit = '',
    required this.parts,
  });

  final String unit;
  final List<TodayPart> parts;

  double get total => parts.fold(0, (sum, part) => sum + part.value);

  @override
  bool get isEmpty => total <= 0;

  @override
  List<String> get table => [
    for (final part in parts) '${part.label} ${_trim(part.value)}$unit',
  ];
}

@immutable
class TodayPart {
  const TodayPart({required this.label, required this.value, this.tone = ''});

  final String label;
  final double value;

  /// good / caution / bad / neutral / brand。
  final String tone;
}

/// 宿舍状态格：每间宿舍一格。
class TodayRoomsChart extends TodayChart {
  const TodayRoomsChart({
    required super.id,
    required super.title,
    super.subtitle,
    super.caption,
    super.empty,
    super.action,
    super.headline,
    required this.rooms,
  });

  final List<TodayRoom> rooms;

  @override
  bool get isEmpty => rooms.isEmpty;

  @override
  List<String> get table => [
    for (final room in rooms)
      '${room.building} ${room.name} ${room.stateLabel} ${room.checked}/${room.total}',
  ];
}

@immutable
class TodayRoom {
  const TodayRoom({
    required this.building,
    required this.name,
    required this.checked,
    required this.total,
    required this.state,
  });

  final String building;
  final String name;
  final int checked;
  final int total;

  /// done 全部已查、pending 有人没打卡、issue 有晚归或缺勤。
  final String state;

  String get stateLabel => switch (state) {
    'issue' => '有晚归或缺勤',
    'pending' => '有人没打卡',
    _ => '已查完',
  };
}

/// 对比表：每行一个对象，每列一个指标，数字旁带一条细进度条。
class TodayCompareChart extends TodayChart {
  const TodayCompareChart({
    required super.id,
    required super.title,
    super.subtitle,
    super.caption,
    super.empty,
    super.action,
    super.headline,
    required this.columns,
    required this.rows,
  });

  final List<String> columns;
  final List<TodayCompareRow> rows;

  @override
  bool get isEmpty => rows.isEmpty;

  @override
  List<String> get table => [
    for (final row in rows)
      [
        row.label,
        for (var i = 0; i < row.cells.length && i < columns.length; i++)
          '${columns[i]} ${row.cells[i].text}',
      ].join('，'),
  ];
}

@immutable
class TodayCompareRow {
  const TodayCompareRow({required this.label, required this.cells});

  final String label;
  final List<TodayCompareCell> cells;
}

@immutable
class TodayCompareCell {
  const TodayCompareCell({
    required this.value,
    required this.max,
    required this.text,
  });

  final double value;
  final double max;
  final String text;

  double get ratio => max <= 0 ? 0 : (value / max).clamp(0.0, 1.0);
}

String _trim(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

// ───────────────────────── 人与事 ─────────────────────────

/// 需要跟进的人或事（需要关注的学生、教学跟进）。
@immutable
class TodayPeople {
  const TodayPeople({
    required this.title,
    this.empty = '',
    this.followLabel = '已跟进',
    this.rows = const <TodayPerson>[],
  });

  static TodayPeople? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = _map(raw);
    return TodayPeople(
      title: _str(json['title']),
      empty: _str(json['empty']),
      followLabel: _str(json['followLabel']),
      rows: [
        for (final row in _rows(json['rows']))
          TodayPerson(
            id: _str(row['id']),
            name: _str(row['name']),
            detail: _str(row['detail']),
            value: _str(row['value']),
            followed: row['followed'] == true,
            action: TodayAction.tryParse(row['action']),
          ),
      ],
    );
  }

  final String title;
  final String empty;
  final String followLabel;
  final List<TodayPerson> rows;
}

@immutable
class TodayPerson {
  const TodayPerson({
    required this.id,
    required this.name,
    this.detail = '',
    this.value = '',
    this.followed = false,
    this.action,
  });

  final String id;
  final String name;
  final String detail;
  final String value;
  final bool followed;
  final TodayAction? action;
}

@immutable
class TodayShortcut {
  const TodayShortcut({
    required this.label,
    required this.icon,
    required this.action,
  });

  final String label;

  /// 图标的名字，界面按名字取图标。
  final String icon;
  final TodayAction action;
}

/// 一个身份当天的看板。
@immutable
class TodayBoard {
  const TodayBoard({
    required this.date,
    required this.role,
    this.title = '',
    this.summary = const TodaySummary(),
    this.focusStepId = '',
    this.focusReason = '',
    this.tipSeen = true,
    this.highlights = const <TodayHighlight>[],
    this.groups = const <TodayGroup>[],
    this.charts = const <TodayChart>[],
    this.people,
    this.shortcuts = const <TodayShortcut>[],
  });

  factory TodayBoard.fromJson(Object? raw) {
    final json = _map(raw);
    return TodayBoard(
      date: _str(json['date']),
      role: _str(json['role']),
      title: _str(json['title']),
      summary: TodaySummary.fromJson(json['summary']),
      focusStepId: _str(json['focusStepId']),
      focusReason: _str(json['focusReason']),
      tipSeen: json['tipSeen'] != false,
      highlights: [
        for (final item in _rows(json['highlights']))
          TodayHighlight.fromJson(item),
      ],
      groups: [
        for (final group in _rows(json['groups'])) TodayGroup.fromJson(group),
      ],
      charts: [
        for (final chart in _rows(json['charts'])) ?TodayChart.tryParse(chart),
      ],
      people: TodayPeople.tryParse(json['people']),
      shortcuts: [
        for (final item in _rows(json['shortcuts']))
          if (TodayAction.tryParse(item['action']) case final action?)
            TodayShortcut(
              label: _str(item['label']),
              icon: _str(item['icon']),
              action: action,
            ),
      ],
    );
  }

  /// `yyyy-MM-dd`。
  final String date;
  final String role;
  final String title;
  final TodaySummary summary;

  /// 下一步要做的那件事，以及为什么先做它。
  final String focusStepId;
  final String focusReason;

  /// 用法提示是否看过。
  final bool tipSeen;

  /// 顶部的数字卡，最多四张。
  final List<TodayHighlight> highlights;
  final List<TodayGroup> groups;
  final List<TodayChart> charts;
  final TodayPeople? people;
  final List<TodayShortcut> shortcuts;

  Iterable<TodayStep> get steps sync* {
    for (final group in groups) {
      yield* group.steps;
    }
  }

  TodayStep? get focus {
    for (final step in steps) {
      if (step.id == focusStepId) return step;
    }
    return null;
  }

  TodayChart? chart(String id) {
    for (final chart in charts) {
      if (chart.id == id) return chart;
    }
    return null;
  }
}
