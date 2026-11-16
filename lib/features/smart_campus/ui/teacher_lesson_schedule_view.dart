// =============================================================================
// 任课老师端「授课课表」独立页面
//
// 入口：教师 dashboard 快捷区「授课课表」按钮 → controller.openMySchedule()
//      → mainView == mySchedule + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 页面只读：课表由教务在「排课与课表」里统一排，老师在这里看自己每周的课。
//   1. 顶部 banner：返回 + 标题「授课课表」+ 副标题（第 N 周 · 起止日期）。
//   2. 控制条（浅灰底）：左侧「教学周第 N 周」，右侧 [◀ 本周 ▶] 周切换 +
//      日期按钮。
//   3. 网格：时间冻结列 + 横滚日期区，和学生 / 管理员端共用同一套课卡。左侧
//      时间列来自 `schoolTimeConfigList`；课表来自任课老师端
//      `/app/school/v2/teacher/courseList`，已按 token 过滤为当前老师的课。
//      没课的格子显示「空闲」占位。
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../school/data/school_repository.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/teacher_repository.dart';
import '../data/campus_format.dart';
import '../data/schedule_course_card_builder.dart';
import '../data/schedule_slot_time.dart';
import '../data/schedule_teaching_week.dart';
import '../state/smart_campus_controller.dart';
import 'widgets/schedule_course_card.dart';
import 'widgets/schedule_grid_shell.dart';
import 'widgets/schedule_idle_slot.dart';
import 'widgets/smart_campus_page_banner.dart';

const Color _kBorderSoft = AppColors.lineSoft;

typedef _TimeSlotData = ScheduleGridTimeSlot;
typedef _DayHeaderData = ScheduleGridDayHeader;
typedef _Cells = List<List<List<ScheduleCourseCardData>>>;

/// 节次时间配置（来自 `schoolTimeConfigList`）。
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

  /// 节次名称（上午 / 下午 / 晚上）。
  final String label;
}

/// 兜底节次：画室固定的上午 / 下午 / 晚上三段。
const List<_TimeConfig> _kDefaultTimeConfigs = [
  _TimeConfig(lineNum: 1, start: '08:30', end: '11:30', label: '上午'),
  _TimeConfig(lineNum: 2, start: '14:00', end: '17:00', label: '下午'),
  _TimeConfig(lineNum: 3, start: '19:00', end: '21:00', label: '晚上'),
];

// =============================================================================
// 入口 widget
// =============================================================================

class TeacherLessonScheduleView extends ConsumerStatefulWidget {
  const TeacherLessonScheduleView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherLessonScheduleView> createState() =>
      _TeacherLessonScheduleViewState();
}

class _TeacherLessonScheduleViewState
    extends ConsumerState<TeacherLessonScheduleView> {
  /// 当前显示的周一（用于日期范围 / 标签 / API begin/end）。
  late DateTime _weekStart;

  /// "教学周第 N 周" 的展示数字。与 [_weekStart] 联动，规则见
  /// [scheduleTeachingWeekOf] / [scheduleCurrentTeachingWeekAnchor]。
  int _currentWeek = kScheduleCurrentTeachingWeek;

  final GlobalKey<ScheduleGridShellState> _scheduleGridKey =
      GlobalKey<ScheduleGridShellState>();

  /// 班级列表第一项 id（来自 teacher `/teacher/classList`，已基于 token
  /// 过滤为「我教的班级」）。`schoolTimeConfigList` 要按班级取节次时间表。
  String? _firstClassId;

  /// 课表左侧节次时间表（按 `lineNum` 升序）。
  List<_TimeConfig> _timeConfigs = const [];

  List<_TimeConfig> get _activeTimeConfigs =>
      _timeConfigs.isNotEmpty ? _timeConfigs : _kDefaultTimeConfigs;

  /// 当前周的网格数据，[7 天][N 节] → 这一格里的课。
  late _Cells _serverCells;
  // 请求中的教学周可能早于画面提交。首屏资料加载完成后继续使用最后一次选择。
  ({DateTime start, int number})? _requestedWeek;
  int _scheduleLoadGeneration = 0;

  String _isoDate(DateTime d) => campusDate(d);

  String get _subtitle {
    final end = _weekStart.add(const Duration(days: 6));
    return '第 $_currentWeek 周 · ${campusMonthDay(_weekStart)} – '
        '${campusMonthDay(end)} · 课表由教务统一安排';
  }

  void _gotoPrev() {
    unawaited(
      _loadSchedule(
        weekStart: (_requestedWeek?.start ?? _weekStart).subtract(
          const Duration(days: 7),
        ),
        weekNumber: (_requestedWeek?.number ?? _currentWeek) - 1,
      ),
    );
  }

  void _gotoNext() {
    unawaited(
      _loadSchedule(
        weekStart: (_requestedWeek?.start ?? _weekStart).add(
          const Duration(days: 7),
        ),
        weekNumber: (_requestedWeek?.number ?? _currentWeek) + 1,
      ),
    );
  }

  void _gotoCurrent() {
    final anchor = scheduleCurrentTeachingWeekAnchor();
    unawaited(_loadSchedule(weekStart: anchor.monday, weekNumber: anchor.week));
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: '选择教学日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    final newWeekStart = scheduleMondayOf(picked);
    unawaited(
      _loadSchedule(
        weekStart: newWeekStart,
        weekNumber: scheduleTeachingWeekOf(newWeekStart),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _serverCells = _emptyCells();
    final anchor = scheduleCurrentTeachingWeekAnchor();
    _weekStart = anchor.monday;
    _currentWeek = anchor.week;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final focus = ref
          .read(smartCampusControllerProvider)
          .teacherScheduleFocus;
      if (focus != null) {
        final weekStart = scheduleMondayOf(focus.courseDate);
        final weekNumber = scheduleTeachingWeekOf(weekStart);
        if (mounted) {
          setState(() {
            _weekStart = weekStart;
            _currentWeek = weekNumber;
          });
        }
      }
      // 先拉班级列表（节次时间表要按班级取），再拉时间表，最后拉课表。
      await _loadClasses();
      if (!mounted) return;
      await _loadTimeConfig();
      if (!mounted) return;
      await _loadSchedule();
    });
  }

  Future<void> _applyScheduleFocus() async {
    final focus = ref.read(smartCampusControllerProvider).teacherScheduleFocus;
    if (focus == null || !mounted) return;

    final dayIdx = _dayIndex(_isoDate(focus.courseDate), _weekStart);
    if (dayIdx < 0) {
      ref
          .read(smartCampusControllerProvider.notifier)
          .clearTeacherScheduleFocus();
      return;
    }

    final configs = _activeTimeConfigs;
    var slotIdx = configs.indexWhere((c) => c.lineNum == focus.lineNum);
    if (slotIdx < 0) {
      slotIdx = (focus.lineNum - 1).clamp(0, configs.length - 1);
    }

    for (var attempt = 0; attempt < 4; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final grid = _scheduleGridKey.currentState;
      if (grid != null &&
          grid.scrollToDaySlot(dayIdx: dayIdx, slotIdx: slotIdx)) {
        break;
      }
    }
    ref
        .read(smartCampusControllerProvider.notifier)
        .clearTeacherScheduleFocus();
  }

  // —— 数据加载 ————————————————————————————————————————————————

  Future<void> _loadClasses() async {
    // 任课老师身份进入授课课表页 → 走 teacher 端 classList，后端基于 token
    // 自动过滤为「我教的班级」。
    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.classList(isClassTeacher: 1);
    if (!mounted || !resp.isSuccess) return;
    String? firstId;
    for (final m in _extractList(resp)) {
      final id = _pickString(m, ['id', 'classId'], '');
      if (id.isNotEmpty) {
        firstId = id;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _firstClassId = firstId);
  }

  /// 取课表左侧时间列表。`schoolTimeConfigList` 接口要求 `classId` 必填，
  /// 用班级列表第一项作为基准；为空时回退到 [_kDefaultTimeConfigs]。
  Future<void> _loadTimeConfig() async {
    final classId = _firstClassId;
    if (classId == null || classId.isEmpty) return;
    final repo = ref.read(schoolRepositoryProvider);
    final resp = await repo.schoolTimeConfigList(classId: classId);
    if (!mounted || !resp.isSuccess) return;
    final list = <_TimeConfig>[];
    for (final m in _extractList(resp)) {
      final lineNumRaw = m['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      final start = _trimToHm(
        _pickString(m, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
      );
      final end = _trimToHm(
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
    final targetWeekStart = weekStart ?? _requestedWeek?.start ?? _weekStart;
    final targetWeekNumber =
        weekNumber ?? _requestedWeek?.number ?? _currentWeek;
    _requestedWeek = (start: targetWeekStart, number: targetWeekNumber);
    final generation = ++_scheduleLoadGeneration;
    final repo = ref.read(teacherRepositoryProvider);
    final end = targetWeekStart.add(const Duration(days: 6));
    final courseResp = await repo.courseList(
      beginDate: _isoDate(targetWeekStart),
      endDate: _isoDate(end),
    );
    if (!mounted || generation != _scheduleLoadGeneration) return;

    if (!courseResp.isSuccess) {
      setState(() {
        _weekStart = targetWeekStart;
        _currentWeek = targetWeekNumber;
        _serverCells = _emptyCells();
      });
      ref
          .read(smartCampusControllerProvider.notifier)
          .clearTeacherScheduleFocus();
      return;
    }

    final cells = _emptyCells();
    final configs = _activeTimeConfigs;
    for (final entry in _extractCourseRows(courseResp)) {
      final m = entry.row;
      final dateStr = entry.dateKey.isNotEmpty
          ? entry.dateKey
          : _pickString(m, ['date', 'classDate', 'courseDate'], '');
      final dayIdx = _dayIndex(dateStr, targetWeekStart);
      if (dayIdx < 0) continue;

      final lineNumRaw = m['lineNum'];
      final lineNum = lineNumRaw is int
          ? lineNumRaw
          : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
      if (lineNum < 1) continue;
      var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
      if (slotIdx < 0) {
        slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
      }
      cells[dayIdx][slotIdx].add(
        buildScheduleCourseCard(m, subline: ScheduleCardSubline.className),
      );
    }

    setState(() {
      _weekStart = targetWeekStart;
      _currentWeek = targetWeekNumber;
      _serverCells = cells;
    });
    await _applyScheduleFocus();
  }

  /// `courseList` 的 `data` 既可能是按日期分组的 Map（新格式：
  /// `{"2026-05-11": [{...}, ...]}`），也可能是扁平 List（老格式）。
  /// 统一摊平成 `(dateKey, row)` 元组。
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
              list.add((dateKey: key, row: item.cast<String, dynamic>()));
            }
          }
        }
      }
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add((dateKey: '', row: item.cast<String, dynamic>()));
        }
      }
    }
    return list;
  }

  _Cells _emptyCells() {
    final n = _activeTimeConfigs.length;
    return [
      for (var d = 0; d < 7; d++)
        [for (var s = 0; s < n; s++) <ScheduleCourseCardData>[]],
    ];
  }

  /// 把已缓存课表网格对齐到当前节次数量，避免 timeConfig 变更后
  /// slots 行数与 cells 列数不一致触发 RangeError。
  _Cells _normalizeCells(_Cells cells) {
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

  /// 根据当前格子内最多课卡数算出每行高度。
  List<_TimeSlotData> _buildSlots(_Cells cells) {
    final configs = _activeTimeConfigs;
    return [
      for (var i = 0; i < configs.length; i++)
        _TimeSlotData(
          start: configs[i].start,
          end: configs[i].end,
          label: configs[i].label,
          height: _calcSlotHeight(i, cells),
        ),
    ];
  }

  double _calcSlotHeight(int slotIdx, _Cells cells) {
    var maxHeight = ScheduleIdleSlot.designSlotHeight;
    for (var d = 0; d < cells.length; d++) {
      if (slotIdx < cells[d].length) {
        final height = scheduleCourseCellHeight(cells[d][slotIdx]);
        if (height > maxHeight) maxHeight = height;
      }
    }
    return maxHeight;
  }

  /// 把后端返回的日期字符串归一化到当前周内的 [0..6]，否则返回 -1。
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

  /// 根据 `_weekStart` 拼出 7 天的 header（标签 + MM/DD + 是否今天）。
  List<_DayHeaderData> _buildDayHeaders() {
    final today = DateTime.now();
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = _weekStart.add(Duration(days: i));
          final isToday =
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
          return _DayHeaderData(
            weekdayLabel: campusWeekdayLabels[i],
            dateLabel: campusMonthDay(d),
            date: DateTime(d.year, d.month, d.day),
            today: isToday,
          );
        }(),
    ];
  }

  // —— Build ————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    final cells = _normalizeCells(_serverCells);
    final slots = _buildSlots(cells);
    final days = _buildDayHeaders();

    return SmartCampusSchedulePageShell(
      bodyScrollable: false,
      header: SmartCampusPageBanner(
        title: '授课课表',
        subtitle: _subtitle,
        onBack: widget.onBack,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          0,
          AppSpace.page,
          AppSpace.page,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              color: AppColors.surfaceSubtle,
              bordered: false,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s8,
              ),
              child: _TeacherScheduleControlBar(
                weekStart: _weekStart,
                week: _currentWeek,
                isCurrentWeek: _currentWeek == kScheduleCurrentTeachingWeek,
                onPrev: _gotoPrev,
                onCurrent: _gotoCurrent,
                onNext: _gotoNext,
                onPickDate: _pickDate,
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            Expanded(
              child: ScheduleGridShell(
                key: _scheduleGridKey,
                slots: slots,
                days: days,
                body: _DaysBodyArea(slots: slots, days: days, cells: cells),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 页头下方控制条：教学周 + 周切换 + 选日期
// =============================================================================

class _TeacherScheduleControlBar extends StatelessWidget {
  const _TeacherScheduleControlBar({
    required this.weekStart,
    required this.week,
    required this.isCurrentWeek,
    required this.onPrev,
    required this.onCurrent,
    required this.onNext,
    required this.onPickDate,
  });

  final DateTime weekStart;
  final int week;
  final bool isCurrentWeek;
  final VoidCallback onPrev;
  final VoidCallback onCurrent;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '教学周第 ',
              children: [
                TextSpan(
                  text: '$week',
                  style: const TextStyle(color: AppColors.brand),
                ),
                const TextSpan(text: ' 周'),
              ],
            ),
            style: AppText.title16,
          ),
        ),
        ScheduleGridWeekSwitcher(
          onPrev: onPrev,
          onCurrent: isCurrentWeek ? null : onCurrent,
          onNext: onNext,
          grouped: false,
        ),
        const SizedBox(width: AppSpace.s8),
        ScheduleGridDateButton(label: campusDate(weekStart), onTap: onPickDate),
      ],
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

  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final _Cells cells;

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
  final List<_DayHeaderData> days;
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
              width: ScheduleGridScope.dayWidthOf(context),
              height: ui(height),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _CellContent(
                      slotEnd: slotEnd,
                      slotDate: days[i].date,
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
    required this.slotEnd,
    required this.slotDate,
    required this.cards,
  });

  final String slotEnd;
  final DateTime slotDate;
  final List<ScheduleCourseCardData> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const ScheduleIdleSlot();
    }
    final isPast = isScheduleSlotPast(slotDate: slotDate, endHm: slotEnd);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(kScheduleCourseCellInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: kScheduleCourseCardGap),
              ScheduleCourseCard(data: cards[i], isPast: isPast),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 通用 helpers（与 admin / 学生端一致的解析函数）
// =============================================================================

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

List<Map<String, dynamic>> _extractList(ApiResponse resp) {
  dynamic raw = resp.data;
  // 兼容 `{ data: [...] }` / `{ data: { records, total } }` 多包一层。
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
      if (item is Map) item.cast<String, dynamic>(),
  ];
}

/// `09:00:00` → `09:00`（兼容已经是 `09:00` 的情况）。
String _trimToHm(String s) {
  if (s.isEmpty) return s;
  final parts = s.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return s;
}
