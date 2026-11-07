// =============================================================================
// 学生端「我的课表」
//
// 入口：学生工作台「我的课表」→ controller.openMySchedule()；页头返回 → onBack。
//
// - 页头：标题「我的课表」，副标题「第 12 周 · 11-02 – 11-08 · 联考冲刺1班 · 城东校区」，
//   右侧上一周 / 本周 / 下一周。
// - 网格：左侧上午 / 下午 / 晚上三个固定节次，右侧 7 天等分一屏放下；今天这一列表头
//   用浅紫底标出。课程卡写课程名、任课老师和教室（校区在页头）。
// - 课表与首页、课堂签到读同一份 `student/courseList`。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

import '../../../core/network/api_response.dart';
import '../../school/data/school_repository.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/campus_format.dart';
import '../data/schedule_course_card_builder.dart';
import '../data/schedule_slot_time.dart';
import '../data/schedule_teaching_week.dart';
import '../data/student_repository.dart';
import 'widgets/schedule_course_card.dart';
import 'widgets/schedule_grid_shell.dart';
import 'widgets/schedule_idle_slot.dart';
import 'widgets/smart_campus_page_banner.dart';

class _TimeConfig {
  const _TimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
    this.label = '',
  });

  final int lineNum;
  final String start;
  final String end;
  final String label;
}

/// 接口未返回节次时的兜底：画室固定的上午 / 下午 / 晚上三段。
const List<_TimeConfig> _kDefaultTimeConfigs = [
  _TimeConfig(lineNum: 1, start: '08:30', end: '11:30', label: '上午'),
  _TimeConfig(lineNum: 2, start: '14:00', end: '17:00', label: '下午'),
  _TimeConfig(lineNum: 3, start: '19:00', end: '21:00', label: '晚上'),
];

/// 单元格上下留白与卡片间距。
const double _kCellPadding = 6;

class StudentMyScheduleView extends ConsumerStatefulWidget {
  const StudentMyScheduleView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StudentMyScheduleView> createState() =>
      _StudentMyScheduleViewState();
}

class _StudentMyScheduleViewState extends ConsumerState<StudentMyScheduleView> {
  late DateTime _weekStart;
  int _currentWeek = kScheduleCurrentTeachingWeek;

  List<_TimeConfig> _timeConfigs = const [];
  late List<List<List<ScheduleCourseCardData>>> _serverCells;
  int _scheduleLoadGeneration = 0;
  bool _initialLoadDone = false;
  String _loadError = '';

  /// 「联考冲刺1班 · 城东校区」，来自 `mySchoolClass`。
  String _classLabel = '';

  List<_TimeConfig> get _activeTimeConfigs =>
      _timeConfigs.isNotEmpty ? _timeConfigs : _kDefaultTimeConfigs;

  String get _subtitle {
    final end = _weekStart.add(const Duration(days: 6));
    return [
      '第 $_currentWeek 周',
      '${campusMonthDay(_weekStart)} – ${campusMonthDay(end)}',
      if (_classLabel.isNotEmpty) _classLabel,
    ].join(' · ');
  }

  String _isoDate(DateTime d) => campusDate(d);

  @override
  void initState() {
    super.initState();
    _serverCells = _emptyCells();
    final anchor = scheduleCurrentTeachingWeekAnchor();
    _weekStart = anchor.monday;
    _currentWeek = anchor.week;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadTimeConfigs();
    await _loadSchedule();
  }

  Future<void> _loadTimeConfigs({String? classId}) async {
    var resolvedClassId = classId;
    if (resolvedClassId == null || resolvedClassId.isEmpty) {
      final classResp = await ref
          .read(studentRepositoryProvider)
          .mySchoolClass();
      if (classResp.isSuccess) {
        final map = _asMap(classResp.data);
        final schoolClass = _asMap(map?['schoolClass']) ?? const {};
        resolvedClassId = _pickString(schoolClass, ['id', 'classId'], '');
        final name = _pickString(schoolClass, ['name', 'groupName'], '');
        final campus =
            RegExp(r'\S+校区')
                .firstMatch(_pickString(schoolClass, ['description'], ''))
                ?.group(0) ??
            '';
        if (mounted) {
          setState(() {
            _classLabel = [name, campus].where((s) => s.isNotEmpty).join(' · ');
          });
        }
      }
    }
    if (resolvedClassId == null || resolvedClassId.isEmpty) return;

    final resp = await ref
        .read(schoolRepositoryProvider)
        .schoolTimeConfigList(classId: resolvedClassId);
    if (!mounted || !resp.isSuccess) return;

    final list = <_TimeConfig>[];
    for (final m in _extractList(resp)) {
      final lineNumRaw = m['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      final start = _trimHm(
        _pickString(m, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
      );
      final end = _trimHm(
        _pickString(m, ['timeEnd', 'endTime', 'finishTime', 'end'], ''),
      );
      if (start.isEmpty || end.isEmpty) continue;
      list.add(
        _TimeConfig(
          lineNum: lineNum,
          start: start,
          end: end,
          label: _pickString(m, ['name', 'lineName'], ''),
        ),
      );
    }
    list.sort((a, b) => a.lineNum.compareTo(b.lineNum));
    if (!mounted || list.isEmpty) return;
    setState(() {
      _timeConfigs = list;
      _serverCells = _normalizeCells(_serverCells);
    });
  }

  Future<void> _loadSchedule({DateTime? weekStart, int? weekNumber}) async {
    final targetWeekStart = weekStart ?? _weekStart;
    final targetWeekNumber = weekNumber ?? _currentWeek;
    final generation = ++_scheduleLoadGeneration;

    final start = targetWeekStart;
    final end = start.add(const Duration(days: 6));
    final resp = await ref
        .read(studentRepositoryProvider)
        .courseList(beginDate: _isoDate(start), endDate: _isoDate(end));
    if (!mounted || generation != _scheduleLoadGeneration) return;

    if (!resp.isSuccess) {
      setState(() {
        _weekStart = targetWeekStart;
        _currentWeek = targetWeekNumber;
        _serverCells = _emptyCells();
        _loadError = resp.msg.isEmpty ? '课表暂时没有加载出来' : resp.msg;
        _initialLoadDone = true;
      });
      return;
    }

    final rows = _extractCourseRows(resp);
    if (rows.isNotEmpty) {
      final first = _flattenCourseRow(rows.first.row);
      final classId = _pickString(first, ['classId'], '');
      if (classId.isNotEmpty && _timeConfigs.isEmpty) {
        await _loadTimeConfigs(classId: classId);
        if (!mounted || generation != _scheduleLoadGeneration) return;
      }
    }

    final cells = _emptyCells();
    final configs = _activeTimeConfigs;
    final smallSeq = <int, int>{};

    for (final entry in rows) {
      final flat = _flattenCourseRow(entry.row);
      final dateStr = entry.dateKey.isNotEmpty
          ? entry.dateKey
          : _pickString(flat, ['date', 'classDate', 'courseDate'], '');
      final dayIdx = _dayIndex(dateStr, targetWeekStart);
      if (dayIdx < 0) continue;

      final lineNumRaw = flat['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
      if (slotIdx < 0) {
        slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
      }

      final cellKey = dayIdx * 1000 + slotIdx;
      final card = buildScheduleCourseCard(
        flat,
        smallSeq[cellKey] ?? 0,
        subline: ScheduleCardSubline.teacher,
      );
      smallSeq[cellKey] = (smallSeq[cellKey] ?? 0) + 1;
      cells[dayIdx][slotIdx].add(card);
    }

    if (!mounted || generation != _scheduleLoadGeneration) return;
    setState(() {
      _weekStart = targetWeekStart;
      _currentWeek = targetWeekNumber;
      _serverCells = cells;
      _loadError = '';
      _initialLoadDone = true;
    });
  }

  void _gotoPrev() {
    unawaited(
      _loadSchedule(
        weekStart: _weekStart.subtract(const Duration(days: 7)),
        weekNumber: _currentWeek - 1,
      ),
    );
  }

  void _gotoNext() {
    unawaited(
      _loadSchedule(
        weekStart: _weekStart.add(const Duration(days: 7)),
        weekNumber: _currentWeek + 1,
      ),
    );
  }

  void _gotoCurrent() {
    final anchor = scheduleCurrentTeachingWeekAnchor();
    unawaited(_loadSchedule(weekStart: anchor.monday, weekNumber: anchor.week));
  }

  List<ScheduleGridDayHeader> _buildDayHeaders() {
    final today = DateTime.now();
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = _weekStart.add(Duration(days: i));
          final isToday =
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
          return ScheduleGridDayHeader(
            weekdayLabel: campusWeekdayLabels[i],
            dateLabel: campusMonthDay(d),
            date: DateTime(d.year, d.month, d.day),
            today: isToday,
          );
        }(),
    ];
  }

  List<ScheduleGridTimeSlot> _buildSlots(
    List<List<List<ScheduleCourseCardData>>> cells,
  ) {
    final configs = _activeTimeConfigs;
    return [
      for (var i = 0; i < configs.length; i++)
        ScheduleGridTimeSlot(
          start: configs[i].start,
          end: configs[i].end,
          label: configs[i].label,
          height: _calcSlotHeight(i, cells),
        ),
    ];
  }

  double _calcSlotHeight(
    int slotIdx,
    List<List<List<ScheduleCourseCardData>>> cells,
  ) {
    var maxCards = 1;
    for (var d = 0; d < cells.length; d++) {
      if (slotIdx < cells[d].length) {
        final n = cells[d][slotIdx].length;
        if (n > maxCards) maxCards = n;
      }
    }
    return maxCards * (kScheduleCourseCardHeight + _kCellPadding) +
        _kCellPadding;
  }

  List<List<List<ScheduleCourseCardData>>> _emptyCells() {
    final n = _activeTimeConfigs.length;
    return [
      for (var d = 0; d < 7; d++)
        [for (var s = 0; s < n; s++) <ScheduleCourseCardData>[]],
    ];
  }

  List<List<List<ScheduleCourseCardData>>> _normalizeCells(
    List<List<List<ScheduleCourseCardData>>> cells,
  ) {
    final slotCount = _activeTimeConfigs.length;
    return [
      for (var d = 0; d < 7; d++)
        [
          for (var s = 0; s < slotCount; s++)
            d < cells.length && s < cells[d].length
                ? cells[d][s]
                : <ScheduleCourseCardData>[],
        ],
    ];
  }

  int _dayIndex(String dateStr, [DateTime? weekStart]) {
    if (dateStr.isEmpty) return -1;
    DateTime? d = DateTime.tryParse(dateStr);
    if (d == null) {
      final iso = dateStr.split('T').first;
      d = DateTime.tryParse(iso);
    }
    if (d == null) return -1;
    final dn = DateTime(d.year, d.month, d.day);
    final anchor = weekStart ?? _weekStart;
    final ws = DateTime(anchor.year, anchor.month, anchor.day);
    final diff = dn.difference(ws).inDays;
    return (diff < 0 || diff > 6) ? -1 : diff;
  }

  Widget _buildContent(List<List<List<ScheduleCourseCardData>>> cells) {
    if (_loadError.isNotEmpty) {
      return AppCard(
        child: Center(
          child: AppErrorState(
            title: '课表加载失败',
            description: _loadError,
            onRetry: () => unawaited(_loadSchedule()),
          ),
        ),
      );
    }
    final empty = cells.every((day) => day.every((slot) => slot.isEmpty));
    if (empty) {
      return const AppCard(
        child: Center(
          child: AppEmptyState(
            icon: Icons.event_available_outlined,
            title: '这一周没有课程',
            description: '画室排课后会显示在这里，可切换到其他周查看',
          ),
        ),
      );
    }
    final slots = _buildSlots(cells);
    final days = _buildDayHeaders();
    return ScheduleGridShell(
      slots: slots,
      days: days,
      body: _DaysBodyArea(slots: slots, days: days, cells: cells),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cells = _normalizeCells(_serverCells);
    final weekEnd = _weekStart.add(const Duration(days: 6));
    return SmartCampusSchedulePageShell(
      bodyScrollable: false,
      header: SmartCampusScheduleTopBar(
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: '教学周第 ',
                        children: [
                          TextSpan(
                            text: '$_currentWeek',
                            style: const TextStyle(color: AppColors.brand),
                          ),
                          const TextSpan(text: ' 周'),
                        ],
                      ),
                      style: AppText.title16,
                    ),
                    Text(
                      [
                        '${campusMonthDay(_weekStart)} – ${campusMonthDay(weekEnd)}',
                        if (_classLabel.isNotEmpty) _classLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                  ],
                ),
              ),
            ),
            AppPageHeader(
              title: '我的课表',
              subtitle: _subtitle,
              onBack: widget.onBack,
              actions: [
                AppIconButton(
                  icon: Icons.chevron_left_rounded,
                  semanticLabel: '上一周',
                  size: AppButtonSize.sm,
                  onTap: _gotoPrev,
                ),
                AppButton(
                  label: '本周',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  onTap: _currentWeek == kScheduleCurrentTeachingWeek
                      ? null
                      : _gotoCurrent,
                ),
                AppIconButton(
                  icon: Icons.chevron_right_rounded,
                  semanticLabel: '下一周',
                  size: AppButtonSize.sm,
                  onTap: _gotoNext,
                ),
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          AppSpace.s4,
          AppSpace.page,
          AppSpace.page,
        ),
        child: PageInitLoadingShell(
          loading: !_initialLoadDone,
          child: _buildContent(cells),
        ),
      ),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _extractList(ApiResponse resp) {
  dynamic raw = resp.data;
  if (raw is Map && raw.containsKey('data')) {
    final d = raw['data'];
    if (d is List) {
      raw = d;
    } else if (d is Map) {
      raw = d;
    }
  }
  final list = raw is List
      ? raw
      : (raw is Map && raw['records'] is List
            ? raw['records'] as List
            : (raw is Map && raw['list'] is List
                  ? raw['list'] as List
                  : const []));
  return [
    for (final item in list)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _trimHm(String value) {
  if (value.isEmpty) return value;
  final parts = value.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return value;
}

Map<String, dynamic> _flattenCourseRow(Map<String, dynamic> row) {
  final flat = Map<String, dynamic>.from(row);

  void mergeNested(String key, List<MapEntry<String, String>> fieldMap) {
    final nested = row[key];
    if (nested is! Map) return;
    final m = Map<String, dynamic>.from(nested);
    for (final entry in fieldMap) {
      final v = m[entry.key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      flat.putIfAbsent(entry.value, () => s);
    }
  }

  mergeNested('teacher', [
    const MapEntry('realname', 'teacherRealname'),
    const MapEntry('realName', 'teacherRealname'),
    const MapEntry('nickname', 'teacherNickname'),
    const MapEntry('name', 'teacherName'),
  ]);
  mergeNested('subject', [
    const MapEntry('name', 'subjectName'),
    const MapEntry('subjectName', 'subjectName'),
  ]);
  mergeNested('schoolClass', [
    const MapEntry('name', 'className'),
    const MapEntry('className', 'className'),
    const MapEntry('id', 'classId'),
  ]);
  mergeNested('schoolClassroom', [
    const MapEntry('name', 'classroomName'),
    const MapEntry('roomName', 'classroomName'),
  ]);

  return flat;
}

List<({String dateKey, Map<String, dynamic> row})> _extractCourseRows(
  ApiResponse resp,
) {
  final raw = resp.data;
  final list = <({String dateKey, Map<String, dynamic> row})>[];
  if (raw is Map) {
    for (final entry in raw.entries) {
      final v = entry.value;
      final key = entry.key.toString();
      if (v is List) {
        for (final item in v) {
          if (item is Map) {
            list.add((dateKey: key, row: Map<String, dynamic>.from(item)));
          }
        }
      }
    }
  } else if (raw is List) {
    for (final item in raw) {
      if (item is Map) {
        list.add((dateKey: '', row: Map<String, dynamic>.from(item)));
      }
    }
  }
  return list;
}

// =============================================================================
// 日期区：每格纵向排列课程卡
// =============================================================================

class _DaysBodyArea extends StatelessWidget {
  const _DaysBodyArea({
    required this.slots,
    required this.days,
    required this.cells,
  });

  final List<ScheduleGridTimeSlot> slots;
  final List<ScheduleGridDayHeader> days;
  final List<List<List<ScheduleCourseCardData>>> cells;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var slotIdx = 0; slotIdx < slots.length; slotIdx++)
          _DayBodyRow(
            slotEnd: slots[slotIdx].end,
            height: slots[slotIdx].height,
            days: days,
            rowCells: [
              for (var dayIdx = 0; dayIdx < days.length; dayIdx++)
                cells[dayIdx][slotIdx],
            ],
          ),
      ],
    );
  }
}

class _DayBodyRow extends StatelessWidget {
  const _DayBodyRow({
    required this.slotEnd,
    required this.height,
    required this.days,
    required this.rowCells,
  });

  final String slotEnd;
  final double height;
  final List<ScheduleGridDayHeader> days;
  final List<List<ScheduleCourseCardData>> rowCells;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final width = ScheduleGridScope.dayWidthOf(context);
    return SizedBox(
      height: ui(height),
      child: Row(
        children: [
          for (var i = 0; i < rowCells.length; i++)
            Container(
              width: width,
              height: ui(height),
              foregroundDecoration: BoxDecoration(
                border: Border(
                  bottom: const BorderSide(color: AppColors.lineSoft),
                  left: i == 0
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.lineSoft),
                ),
              ),
              child: _CellContent(
                slotDate: days[i].date,
                slotEnd: slotEnd,
                cards: rowCells[i],
              ),
            ),
        ],
      ),
    );
  }
}

class _CellContent extends StatelessWidget {
  const _CellContent({
    required this.slotDate,
    required this.slotEnd,
    required this.cards,
  });

  final DateTime slotDate;
  final String slotEnd;
  final List<ScheduleCourseCardData> cards;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (cards.isEmpty) {
      return const ScheduleIdleSlot();
    }
    final isPast = isScheduleSlotPast(slotDate: slotDate, endHm: slotEnd);
    return Padding(
      padding: EdgeInsets.all(ui(_kCellPadding)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(height: ui(_kCellPadding)),
            ScheduleCourseCard(data: cards[i], isPast: isPast),
          ],
        ],
      ),
    );
  }
}
