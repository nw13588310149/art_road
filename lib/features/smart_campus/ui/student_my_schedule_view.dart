// =============================================================================
// 学生端「我的课表」独立页面
//
// 入口：学生 dashboard 快捷区「我的课表」按钮 → controller.openMySchedule()
//      → mainView == mySchedule + role == student → SmartCampusPage 路由到本视图。
// 返回：顶部 banner 左上角返回按钮 → onBack（controller.backToDashboard）。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（68 高）：白→#F9EDFF 渐变；左 32 返回；居中「教学周第 12 周
//      03/12-03/17」（12 用 #8741FF 紫色）；右侧 [◀ 本周 ▶] 周切换器
//   2. 网格容器（930×632，1px #F3F2F3 描边，12 圆角）：
//      - 时间列（120 宽，冻结）：60 高表头（"日期 / 节次" + 27° 斜分割线，
//        #F5F6FA 底）；下方 5 个时段，每个时段中间显示 `08:00 ── 08:40`
//      - 日期区（横滚动 7 列 × 200 宽 = 1400，可视约 810）：60 高 7 个日期
//        表头（周一白底，其余 #F5F6FA）；下方 5 行课卡（高度 120/120/222/
//        128/128，222 行允许 2 卡纵向堆叠）
//   3. 课卡（176 宽 × 96/120 高）四种主题：
//      - 小课·橙：#FFEDD3 底，#774B09 标题，绿色状态点 + "小课" 白标签
//      - 小课·蓝：#D9EBFF 底，#0D3A6D 标题，绿色状态点 + "小课"
//      - 大课·紫标准：#E8D4FF 底（96h），#7535BE 标题，紫色点 + "大课"
//      - 大课·紫加长：#F6EFFE 底（120h），#7535BE 标题，紫色点 + "大课"
//
// 颜色：白 / #F5F6FA 灰 / #F3F2F3 边 / #8741FF 主紫 / #6D6B75 副字 /
//      #B6B5BB 提示
// 字体：PingFang SC（标题 16/正文 12-14）
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_toast.dart';
import '../../school/data/school_repository.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/student_repository.dart';
import '../data/schedule_course_card_builder.dart';
import '../data/schedule_slot_time.dart';
import '../data/schedule_teaching_week.dart';
import 'widgets/schedule_course_card.dart';
import 'widgets/schedule_grid_shell.dart';
import 'widgets/schedule_idle_slot.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 通用配色 ---------------------------------------------------------------

const Color _kCardBg = Colors.white;
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);

class _TimeConfig {
  const _TimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

const List<_TimeConfig> _kDefaultTimeConfigs = [
  _TimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  _TimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  _TimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  _TimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  _TimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

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

  List<_TimeConfig> get _activeTimeConfigs =>
      _timeConfigs.isNotEmpty ? _timeConfigs : _kDefaultTimeConfigs;

  String get _dateRangeLabel {
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    return '${_fmt(start)} - ${_fmt(end)}';
  }

  String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
        final schoolClass = _asMap(map?['schoolClass']);
        resolvedClassId = _pickString(schoolClass ?? {}, ['id', 'classId'], '');
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
      list.add(_TimeConfig(lineNum: lineNum, start: start, end: end));
    }
    list.sort((a, b) => a.lineNum.compareTo(b.lineNum));
    if (!mounted || list.isEmpty) return;
    setState(() {
      _timeConfigs = list;
      _serverCells = _normalizeCells(_serverCells);
    });
  }

  Future<void> _loadSchedule({
    DateTime? weekStart,
    int? weekNumber,
  }) async {
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
      if (resp.msg.isNotEmpty) {
        AppToast.show(context, resp.msg);
      }
      setState(() {
        _weekStart = targetWeekStart;
        _currentWeek = targetWeekNumber;
        _serverCells = _emptyCells();
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
      final card = buildScheduleCourseCard(flat, smallSeq[cellKey] ?? 0);
      smallSeq[cellKey] = (smallSeq[cellKey] ?? 0) + 1;
      cells[dayIdx][slotIdx].add(card);
    }

    if (!mounted || generation != _scheduleLoadGeneration) return;
    setState(() {
      _weekStart = targetWeekStart;
      _currentWeek = targetWeekNumber;
      _serverCells = cells;
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
    unawaited(
      _loadSchedule(
        weekStart: anchor.monday,
        weekNumber: anchor.week,
      ),
    );
  }

  List<ScheduleGridDayHeader> _buildDayHeaders() {
    final today = DateTime.now();
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = _weekStart.add(Duration(days: i));
          final isToday =
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
          return ScheduleGridDayHeader(
            weekdayLabel: labels[i],
            dateLabel:
                '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}',
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
    return 120.0 + (maxCards - 1) * 102.0;
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

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cells = _normalizeCells(_serverCells);
    final slots = _buildSlots(cells);
    final days = _buildDayHeaders();

    return SmartCampusSchedulePageShell(
      backgroundColor: _kCardBg,
      bodyScrollable: false,
      header: _ScheduleBanner(
        week: _currentWeek,
        dateRange: _dateRangeLabel,
        onBack: widget.onBack,
        onPrevWeek: _gotoPrev,
        onNextWeek: _gotoNext,
        onGotoCurrent: _gotoCurrent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(11), ui(20), ui(20)),
              child: PageInitLoadingShell(
                loading: !_initialLoadDone,
                child: ScheduleGridShell(
                  slots: slots,
                  days: days,
                  body: _DaysBodyArea(
                    slots: slots,
                    days: days,
                    cells: cells,
                  ),
                ),
              ),
            ),
          ),
        ],
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
// 顶部 banner：68 高，白→紫淡色渐变
// =============================================================================

class _ScheduleBanner extends StatelessWidget {
  const _ScheduleBanner({
    required this.week,
    required this.dateRange,
    required this.onBack,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onGotoCurrent,
  });

  final int week;
  final String dateRange;
  final VoidCallback onBack;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onGotoCurrent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusScheduleTopBar(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 返回按钮
          Positioned(
              left: ui(20),
              top: ui(20),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(ui(8)),
                child: Container(
                  width: ui(32),
                  height: ui(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ui(8)),
                    border: Border.all(color: _kBorderSoft),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: ui(20),
                    color: const Color(0xFF1C274C),
                  ),
                ),
              ),
            ),
            // 居中标题：教学周第 12 周 / 03/12 - 03/17
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: ui(16),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1,
                      ),
                      children: [
                        const TextSpan(text: '教学周第 '),
                        TextSpan(
                          text: '$week',
                          style: const TextStyle(color: _kPurple),
                        ),
                        const TextSpan(text: ' 周'),
                      ],
                    ),
                  ),
                  SizedBox(height: ui(6)),
                  Text(
                    dateRange,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            // 右侧周切换器
            Positioned(
              right: ui(20),
              top: ui(14),
              child: _WeekSwitcher(
                onPrev: onPrevWeek,
                onNext: onNextWeek,
                onCurrent: onGotoCurrent,
              ),
            ),
          ],
        ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.onPrev,
    required this.onNext,
    required this.onCurrent,
  });

  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCurrent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChevronButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
          SizedBox(width: ui(12)),
          InkWell(
            onTap: onCurrent,
            borderRadius: BorderRadius.circular(ui(4)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(2)),
              child: Text(
                '本周',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          _ChevronButton(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: SizedBox(
        width: ui(32),
        height: ui(32),
        child: Icon(icon, size: ui(18), color: const Color(0xFF1C274C)),
      ),
    );
  }
}

// =============================================================================
// 日期区：多行课卡
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
    return SizedBox(
      height: ui(height),
      child: Row(
        children: [
          for (var i = 0; i < rowCells.length; i++)
            SizedBox(
              width: ui(kScheduleGridDayColWidth),
              height: ui(height),
              // 用 Stack overlay 画底/左边线，避免 BoxDecoration.border 把
              // 子可用高度从 slot.height 减掉 1px——精确填满（120/222
              // 等行）时会触发 "BOTTOM OVERFLOWED BY 1.00 PIXELS"。
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _CellContent(
                      slotDate: days[i].date,
                      slotEnd: slotEnd,
                      cards: rowCells[i],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(height: 1, color: _kBorderSoft),
                    ),
                  ),
                  if (i != 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(width: 1, color: _kBorderSoft),
                      ),
                    ),
                ],
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
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) SizedBox(height: ui(6)),
              ScheduleCourseCard(data: cards[i], isPast: isPast),
            ],
          ],
        ),
      ),
    );
  }
}
