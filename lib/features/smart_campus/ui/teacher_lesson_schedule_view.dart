// =============================================================================
// 任课老师端「授课课表」独立页面
//
// 入口：教师 dashboard 快捷区「授课课表」按钮 → controller.openMySchedule()
//      → mainView == mySchedule + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（68 高）：白→#F9EDFF 渐变；左 32 返回；居中 16/600
//      "授课课表" + 12/B6B5BB 副标题；右上角 "查看 / 编辑" 分段控制
//      （32 高白底 + #F3F2F3 边；激活段紫底 #8741FF / 白字）。
//   2. 控制条（64 高 #F5F6FA 灰底 12 圆角）：
//      - 左上：教学周第 N 周（16/600，N 用 #8741FF 紫）。
//      - 左下：legend 两枚 pill：⚫ #A773FF "大课"·灰副标"不可编辑"；
//             ⚫ #0CAC40 "小课"·灰副标"编辑模式下可点击"。
//      - 右侧：[◀ 本周 ▶] 周切换器 + "YYYY/MM/DD" 日历 pill。
//   3. 网格（930×N，1px #F3F2F3 描边，12 圆角）：与学生 / 管理员端共用同
//      4 主题课卡 + 时间冻结列 + 横滚日期区。左侧时间列由
//      `schoolTimeConfigList` 接口返回；课表数据来自任课老师端
//      `/app/school/v2/teacher/courseList`，已按 token 过滤为当前老师的课。
//      同时并行拉 `/app/school/v2/teacher/schoolSmallCourseApplyList`，把
//      「待审核 / 已驳回」的小课申请以幽灵卡形式叠到对应日期 / 节次格子里
//      （已通过的申请因 courseList 已包含，做 (classId,date,lineNum) 去重
//      避免双显示）。这些幽灵卡右上角用对应颜色徽章替代默认「小课」pill。
//   4. 编辑模式：
//      - 大课（紫）原样展示，不可编辑（与 admin 端不同：admin 端可拖动）；
//      - 小课（橙 / 蓝）变可点击；
//      - 不论本节当前是空、是小课、还是已经排了大课，卡片下方都会挂一枚
//        48 高 "申请小课" pill：教师可以直接在大课同节申请加排一节小课
//        （高三艺考生加练等场景）→ 打开右侧 [_ApplySmallLessonDrawer]，
//        提交触发 `/app/school/v2/teacher/schoolSmallCourseApplySave`。
//   5. 查看模式空格画 "空闲" 灰边占位；编辑模式下空格走"申请小课"。
//
// 颜色：白 / #F5F6FA 灰 / #F3F2F3 边 / #8741FF 主紫 / #6D6B75 副字 /
//      #B6B5BB 提示 / #774B09 橙文 / #0D3A6D 蓝文 / #7535BE 紫文
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../../core/widgets/segment_toggle.dart';
import '../../school/data/school_repository.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/teacher_repository.dart';
import '../data/schedule_color_palette.dart';
import '../data/schedule_course_card_builder.dart';
import '../data/schedule_slot_time.dart';
import '../data/schedule_teaching_week.dart';
import '../state/smart_campus_controller.dart';
import 'widgets/schedule_color_swatch_picker.dart';
import 'widgets/schedule_course_card.dart';
import 'widgets/schedule_grid_shell.dart';
import 'widgets/schedule_idle_slot.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 通用配色（与学生 / 管理员端 schedule 保持一致）----------------------

const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kCheckboxBorder = Color(0xFFCECED1);

const Color _kStatusGreen = Color(0xFF0CAC40);
const Color _kStatusPurple = Color(0xFFA773FF);

// 「我的小课申请」状态色（与 admin schedule 端 _kPendingBg/Fg 等保持一致），
// 用于课卡右上角的状态徽章替代默认「小课」pill。
const Color _kApplyPendingBg = Color(0xFFFFEDD3);
const Color _kApplyPendingFg = Color(0xFFFF6A00);
const Color _kApplyRejectedBg = Color(0xFFFFE5E5);
const Color _kApplyRejectedFg = Color(0xFFE83A3A);

enum _ScheduleMode { view, edit }

/// 「我的小课申请」状态：与后端 `status` 字段双向映射 —— 1 通过 / 2 驳回 /
/// 0 / null 待审核。和 admin schedule 端 `_ApplyStatus` 完全一致。
enum _ApplyStatus { pending, passed, rejected }

class _ScheduleCardData {
  const _ScheduleCardData({
    required this.display,
    this.raw,
    this.applyStatus,
    this.apply,
  });

  final ScheduleCourseCardData display;
  final Map<String, dynamic>? raw;
  final _ApplyStatus? applyStatus;
  final _ApplyContext? apply;

  ScheduleCourseCardKind get kind => display.kind;
  String get location => display.location;
  String get name => display.name;
  String get subline => display.subline;
  String? get capacity => display.capacity;
  Color? get bgColor => display.bgColor;
}

/// 「我的小课申请」幽灵卡的回看上下文，封装一条申请的关键参数 + 状态 / 理由。
///
/// 字段直接对应 `schoolSmallCourseApplyList` 接口里每条记录的核心字段（含
/// `courseData` 解开后的 child）。详情弹窗 / 重新申请抽屉都从这里取值，
/// 避免把 raw map 在多个调用点重新解析一次。
class _ApplyContext {
  const _ApplyContext({
    required this.applyId,
    required this.status,
    required this.classId,
    required this.lineNum,
    required this.dateIso,
    this.reason,
    this.classroomId,
    this.subjectId,
    this.colorHex,
    this.studentIds = const [],
  });

  final String applyId;
  final _ApplyStatus status;
  final String classId;
  final int lineNum;
  final String dateIso;

  /// 驳回理由（仅 [_ApplyStatus.rejected] 时通常有值）。
  final String? reason;
  final int? classroomId;
  final int? subjectId;
  final String? colorHex;

  /// `courseData` 中解析出的参与学生 id；重新申请时用于回填勾选。
  final List<String> studentIds;
}

typedef _TimeSlotData = ScheduleGridTimeSlot;
typedef _DayHeaderData = ScheduleGridDayHeader;

/// 节次时间配置（来自 `schoolTimeConfigList`）。
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

/// 兜底节次：API 拉不到 / 无配置时显示 5 节，与原 demo 节奏保持一致。
const List<_TimeConfig> _kDefaultTimeConfigs = [
  _TimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  _TimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  _TimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  _TimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  _TimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

/// 复用模式从当前 `currentWeek` 起补到第 [kScheduleTermTotalWeeks] 周。

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

  _ScheduleMode _mode = _ScheduleMode.view;

  final GlobalKey<ScheduleGridShellState> _scheduleGridKey =
      GlobalKey<ScheduleGridShellState>();

  /// 班级列表第一项 id（来自 teacher `/teacher/classList`，已基于 token
  /// 过滤为「我教的班级」）。仅用于驱动 `schoolTimeConfigList` 拉对应班级
  /// 的节次时间表 + 抽屉默认班级回填。抽屉自身会再调一次 `classList`
  /// 拿最新的我教的班级列表（大 + 小），无需在这里整张缓存。
  String? _firstClassId;

  /// 课表数据字典（id → 名称），仅给「我的小课申请」幽灵卡用 ——
  /// 申请记录里只有 id，没有 name / realname 等字段；要在画卡前把名字
  /// 补齐才能显示班级 / 教室 / 科目。
  ///
  /// 真实课表项（`courseList` 接口）后端已经把这些字段平铺好了，所以这套
  /// 字典只服务申请合并路径，不影响主流程。
  Map<String, String> _classNameById = const {};
  Map<int, String> _classroomNameById = const {};
  Map<int, String> _subjectNameById = const {};

  /// 课表左侧节次时间表（按 `lineNum` 升序）。
  List<_TimeConfig> _timeConfigs = const [];

  List<_TimeConfig> get _activeTimeConfigs =>
      _timeConfigs.isNotEmpty ? _timeConfigs : _kDefaultTimeConfigs;

  /// 当前周的网格数据，[7 天][N 节] → 多张课卡。
  late List<List<List<_ScheduleCardData>>> _serverCells;
  int _scheduleLoadGeneration = 0;

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _mondayOf(DateTime d) => scheduleMondayOf(d);

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
    final newWeekStart = _mondayOf(picked);
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
      final focus = ref.read(smartCampusControllerProvider).teacherScheduleFocus;
      DateTime weekStart = _weekStart;
      var weekNumber = _currentWeek;
      if (focus != null) {
        weekStart = scheduleMondayOf(focus.courseDate);
        weekNumber = scheduleTeachingWeekOf(weekStart);
        if (mounted) {
          setState(() {
            _weekStart = weekStart;
            _currentWeek = weekNumber;
          });
        }
      }
      // 先拉班级列表（驱动 timeConfig 用），再并行拉时间表 + 字典
      // （教室 / 科目，给申请幽灵卡补名字），最后拉课表。字典失败不会
      // 阻断 schedule 渲染，只是申请卡上的字段会缺。
      await _loadClasses();
      if (!mounted) return;
      await Future.wait([_loadTimeConfig(), _loadDirectories()]);
      if (!mounted) return;
      await _loadSchedule(weekStart: weekStart, weekNumber: weekNumber);
    });
  }

  Future<void> _applyScheduleFocus() async {
    final focus = ref.read(smartCampusControllerProvider).teacherScheduleFocus;
    if (focus == null || !mounted) return;

    final dayIdx = _dayIndex(_isoDate(focus.courseDate), _weekStart);
    if (dayIdx < 0) {
      ref.read(smartCampusControllerProvider.notifier).clearTeacherScheduleFocus();
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
          grid.scrollToDaySlot(
            dayIdx: dayIdx,
            slotIdx: slotIdx,
          )) {
        break;
      }
    }
    ref.read(smartCampusControllerProvider.notifier).clearTeacherScheduleFocus();
  }

  // —— 数据加载 ————————————————————————————————————————————————

  Future<void> _loadClasses() async {
    // 任课老师身份进入授课课表页 → 走 teacher 端 classList，后端基于 token
    // 自动过滤为「我教的班级」（含大班 + 小班），与 admin 端 classList 区分开。
    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.classList(isClassTeacher: 1);
    if (!mounted || !resp.isSuccess) return;
    final rows = _extractList(resp);
    String? firstId;
    final nameById = <String, String>{};
    for (final m in rows) {
      final id = _pickString(m, ['id', 'classId'], '');
      if (id.isEmpty) continue;
      firstId ??= id;
      final name = _pickString(m, [
        'name',
        'className',
        'fullName',
      ], '');
      if (name.isNotEmpty) nameById[id] = name;
    }
    if (!mounted) return;
    setState(() {
      _firstClassId = firstId;
      _classNameById = nameById;
    });
  }

  /// 拉教室 / 科目字典 —— 仅给「我的小课申请」幽灵卡补齐展示字段，与课表
  /// 主流程解耦：失败 / 慢都不会阻断 schedule 渲染。
  ///
  /// - 教室走 teacher `classroomList`，一次拿全量；
  /// - 科目走 user `subjectList(classId)`，必须按班级查 —— 接口不传 classId
  ///   后端实测不返回全量。所以这里对 `_classNameById` 里的每个班级并行
  ///   发 N 个请求，结果合并成一张大字典。教师通常只教若干班级 (<20)，
  ///   单次开页面的成本可控。
  Future<void> _loadDirectories() async {
    final teacherRepo = ref.read(teacherRepositoryProvider);
    final schoolRepo = ref.read(schoolRepositoryProvider);

    final classIds = _classNameById.keys.toList();
    final classroomFuture = teacherRepo.classroomList();
    final subjectFutures = <Future<ApiResponse>>[
      for (final cid in classIds) schoolRepo.subjectList(classId: cid),
    ];

    final classroomResp = await classroomFuture;
    final subjectResps = await Future.wait(subjectFutures);
    if (!mounted) return;

    final classroomMap = <int, String>{};
    if (classroomResp.isSuccess) {
      for (final m in _extractList(classroomResp)) {
        final rawId = m['id'] ?? m['classroomId'] ?? m['roomId'];
        final id = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        final name = _pickString(m, [
          'name',
          'classroomName',
          'roomName',
        ], '');
        if (id != null && name.isNotEmpty) classroomMap[id] = name;
      }
    }

    final subjectMap = <int, String>{};
    for (final resp in subjectResps) {
      if (!resp.isSuccess) continue;
      for (final m in _extractList(resp)) {
        final rawId = m['id'] ?? m['subjectId'];
        final id = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '');
        final name = _pickString(m, [
          'name',
          'subjectName',
        ], '');
        if (id != null && name.isNotEmpty) subjectMap[id] = name;
      }
    }

    if (!mounted) return;
    setState(() {
      _classroomNameById = classroomMap;
      _subjectNameById = subjectMap;
    });
  }

  /// 取课表左侧时间列表。`schoolTimeConfigList` 接口要求 `classId` 必填，
  /// 用班级列表第一项作为基准；为空时回退到 [_kDefaultTimeConfigs]。
  Future<void> _loadTimeConfig() async {
    final classId = _firstClassId;
    if (classId == null || classId.isEmpty) return;
    final repo = ref.read(schoolRepositoryProvider);
    final resp = await repo.schoolTimeConfigList(classId: classId);
    if (!mounted || !resp.isSuccess) return;
    final rows = _extractList(resp);
    final list = <_TimeConfig>[];
    for (final m in rows) {
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
    final repo = ref.read(teacherRepositoryProvider);
    final start = targetWeekStart;
    final end = start.add(const Duration(days: 6));
    // 并行：① 真实课表（已排定）； ② 我的小课申请列表（含审核中 / 已驳回，
    // 用来在课表上同步显示状态徽章）。已通过的申请会同步出现在 ① 里作为
    // 真实排课，所以 ② 的 passed 记录会被跳过避免双显示。
    //
    // size: 100 兜底单个老师近期的全部申请（学期内极少超过 100 条），暂不
    // 引入分页；超过时再加 current 循环。
    final results = await Future.wait([
      repo.courseList(beginDate: _isoDate(start), endDate: _isoDate(end)),
      repo.schoolSmallCourseApplyList(current: 1, size: 100),
    ]);
    if (!mounted || generation != _scheduleLoadGeneration) return;
    final courseResp = results[0];
    final applyResp = results[1];

    if (!courseResp.isSuccess) {
      setState(() {
        _weekStart = targetWeekStart;
        _currentWeek = targetWeekNumber;
        _serverCells = _emptyCells();
      });
      ref.read(smartCampusControllerProvider.notifier).clearTeacherScheduleFocus();
      return;
    }

    final cells = _emptyCells();
    final configs = _activeTimeConfigs;
    final rows = _extractCourseRows(courseResp);
    final smallSeq = <int, int>{};
    // 去重 key：'classId|date|lineNum'。courseList 已经吃掉的格子，apply
    // 列表里若有同 key 的项（理论上是 passed，但用 key 兜底更鲁棒）就不
    // 再叠一张幽灵卡上去。
    final realCourseKeys = <String>{};

    for (final entry in rows) {
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

      final cellKey = dayIdx * 1000 + slotIdx;
      final card = _parseCourseCard(m, smallSeq[cellKey] ?? 0);
      smallSeq[cellKey] = (smallSeq[cellKey] ?? 0) + 1;
      cells[dayIdx][slotIdx].add(card);

      // 记录已有排课的 (classId,date,lineNum)，给申请列表去重。
      final cid = _pickString(m, ['classId', 'cId'], '');
      final cdate = (dateStr.split('T').first);
      if (cid.isNotEmpty && cdate.isNotEmpty) {
        realCourseKeys.add('$cid|$cdate|$lineNum');
      }
    }

    if (applyResp.isSuccess) {
      _mergeApplyRecords(
        applyResp,
        weekStart: targetWeekStart,
        cells: cells,
        smallSeq: smallSeq,
        realCourseKeys: realCourseKeys,
      );
    }

    if (!mounted || generation != _scheduleLoadGeneration) return;
    setState(() {
      _weekStart = targetWeekStart;
      _currentWeek = targetWeekNumber;
      _serverCells = cells;
    });
    await _applyScheduleFocus();
  }

  /// 解析「我的小课申请」分页响应，把待审核 / 已驳回的项以幽灵卡形式插入
  /// [cells]，并通过 [realCourseKeys] 去重已经落地的项。
  ///
  /// 后端返回结构（实测 swagger 一致）：
  /// ```
  /// data.records: [
  ///   {
  ///     id, schoolId, classId, teacherId, subjectId, lineNum, color,
  ///     classroomId, status, reason, createTime, auditTime,
  ///     startDate, endDate,
  ///     courseData: "[{classId,classroomId,color,date,lineNum,
  ///                    subjectId,teacherId}, ...]"   // ← JSON 字符串
  ///   }
  /// ]
  /// ```
  /// `courseData` 是 **字符串化的 JSON 数组**，复用方式（本学期 / 后续 4 周
  /// / 后续 8 周）会展开成多条 child，按 child.date 落到对应日期 / 节次格。
  void _mergeApplyRecords(
    ApiResponse resp, {
    required DateTime weekStart,
    required List<List<List<_ScheduleCardData>>> cells,
    required Map<int, int> smallSeq,
    required Set<String> realCourseKeys,
  }) {
    final raw = resp.data;
    // 分页响应：data 通常是 {records: [...], total: N} 也可能直接是 List。
    List<dynamic> rows = const [];
    if (raw is Map) {
      final r = raw['records'] ?? raw['list'] ?? raw['data'];
      if (r is List) rows = r;
    } else if (raw is List) {
      rows = raw;
    }
    if (rows.isEmpty) return;

    final configs = _activeTimeConfigs;
    for (final item in rows) {
      if (item is! Map) continue;
      final apply = item.cast<String, dynamic>();
      final status = _parseApplyStatus(apply['status']);
      // 课表里只画「待审核」幽灵卡：
      //   - 已通过：courseList 已经返回真实排课，不重复渲染；
      //   - 已驳回：被驳回的不再占用课表格子，避免视觉污染；
      //     用户可以在右上角「申请记录」面板里看全部状态 + 重新申请。
      if (status != _ApplyStatus.pending) continue;

      // `courseData` 是 JSON 字符串；`courseList` 留作前向兼容（万一后端某
      // 个版本改成结构化数组）。两者都没有时退化为顶层 startDate + lineNum
      // 单点占位。
      //
      // 解码前先把雪花长 ID（>= 2^53，等价于长度 >= 16 的纯数字字面量）
      // 包成字符串：Dart Web 上 int = JS Number(double)，未引号大数会被
      // jsonDecode 截到相邻偶数，导致后面用 classId 反查班级名永远失败。
      final children = <Map<String, dynamic>>[];
      final cdRaw = apply['courseData'];
      if (cdRaw is String && cdRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(_preserveLongIds(cdRaw));
          if (decoded is List) {
            for (final c in decoded) {
              if (c is Map) children.add(c.cast<String, dynamic>());
            }
          }
        } catch (_) {
          // 静默忽略：坏数据不应让整条申请挂掉，下方 fallback 至少画一张
          // 顶层占位卡。
        }
      } else if (cdRaw is List) {
        for (final c in cdRaw) {
          if (c is Map) children.add(c.cast<String, dynamic>());
        }
      } else {
        final legacy = apply['courseList'];
        if (legacy is List) {
          for (final c in legacy) {
            if (c is Map) children.add(c.cast<String, dynamic>());
          }
        }
      }
      if (children.isEmpty) {
        children.add(<String, dynamic>{
          'date': _pickString(apply, ['startDate', 'applyDate'], ''),
          'lineNum': apply['lineNum'],
        });
      }

      for (final cm in children) {
        final dateStr = _pickString(cm, [
          'date',
          'classDate',
          'courseDate',
        ], '');
        final dayIdx = _dayIndex(dateStr, weekStart);
        if (dayIdx < 0) continue;

        final lnRaw = cm['lineNum'] ?? apply['lineNum'];
        final lineNum = lnRaw is int
            ? lnRaw
            : (int.tryParse(lnRaw?.toString() ?? '') ?? 0);
        if (lineNum < 1) continue;
        var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
        if (slotIdx < 0) {
          slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
        }

        // 去重：同 (classId,date,lineNum) 已有真实排课就跳过（多数是 passed
        // 走 courseList，少数极端场景下后端可能在 apply 列表里也回这条）。
        final cid = _pickString(cm, [
          'classId',
          'cId',
        ], _pickString(apply, ['classId'], ''));
        final cdate = dateStr.split('T').first;
        if (cid.isNotEmpty && cdate.isNotEmpty) {
          if (realCourseKeys.contains('$cid|$cdate|$lineNum')) continue;
        }

        // 合并外层（顶层 apply）+ 内层 child：内层 date/lineNum/classId 优先。
        // 同时强制 type=1 → 走小课卡解析分支，保证视觉是小课色 + 小课形状。
        final merged = <String, dynamic>{
          ...apply,
          ...cm,
          'type': 1,
        };

        // 用字典补齐展示字段：申请记录仅含 id，没有名称，需要按
        // (classId, classroomId, subjectId, teacherId) 反查字典。
        // 已有同名 key 时不覆盖（极少数 courseData 已自带的字段保留原值）。
        final className = _classNameById[cid];
        if (className != null && className.isNotEmpty) {
          merged.putIfAbsent('className', () => className);
        }
        final classroomIdRaw = cm['classroomId'] ?? apply['classroomId'];
        final classroomIdInt = classroomIdRaw is int
            ? classroomIdRaw
            : int.tryParse(classroomIdRaw?.toString() ?? '');
        if (classroomIdInt != null) {
          final classroomName = _classroomNameById[classroomIdInt];
          if (classroomName != null && classroomName.isNotEmpty) {
            merged.putIfAbsent('classroomName', () => classroomName);
          }
        }
        final subjectIdRaw = cm['subjectId'] ?? apply['subjectId'];
        final subjectIdInt = subjectIdRaw is int
            ? subjectIdRaw
            : int.tryParse(subjectIdRaw?.toString() ?? '');
        if (subjectIdInt != null) {
          final subjectName = _subjectNameById[subjectIdInt];
          if (subjectName != null && subjectName.isNotEmpty) {
            merged.putIfAbsent('subjectName', () => subjectName);
          }
        }
        // 教师：申请人就是当前登录的任课老师，直接走 shell 的 user 兜底；
        // 极端场景下 teacherId 与 shell.user.id 不一致也无所谓，因为这本
        // 来就是「我的申请」列表，UI 字段只是辅助显示。
        final shellUser = ref.read(shellControllerProvider).user;
        final teacherDisplayName = shellUser.realname.isNotEmpty
            ? shellUser.realname
            : shellUser.nickname;
        if (teacherDisplayName.isNotEmpty) {
          merged.putIfAbsent('teacherRealname', () => teacherDisplayName);
        }

        // 构造回看上下文，给详情对话框 + 重新申请抽屉用。classId 取已经
        // 做过雪花精度保留的 cid（_preserveLongIds 已处理过 courseData），
        // classroom / subject / color 兜底到外层 apply 字段。
        final applyId = _pickString(apply, ['id', 'applyId'], '');
        final applyReason = _pickString(apply, ['reason'], '');
        final applyCtx = _ApplyContext(
          applyId: applyId,
          status: status,
          classId: cid.isNotEmpty
              ? cid
              : _pickString(apply, ['classId'], ''),
          lineNum: lineNum,
          dateIso: cdate,
          reason: applyReason.isEmpty ? null : applyReason,
          classroomId: classroomIdInt,
          subjectId: subjectIdInt,
          colorHex: _pickString(merged, ['color'], ''),
        );

        final cellKey = dayIdx * 1000 + slotIdx;
        final smallIdx = smallSeq[cellKey] ?? 0;
        final card = _parseCourseCard(
          merged,
          smallIdx,
          applyStatus: status,
          apply: applyCtx,
        );
        smallSeq[cellKey] = smallIdx + 1;
        cells[dayIdx][slotIdx].add(card);
      }
    }
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

  List<List<List<_ScheduleCardData>>> _emptyCells() {
    final n = _activeTimeConfigs.length;
    return [
      for (var d = 0; d < 7; d++)
        [for (var s = 0; s < n; s++) <_ScheduleCardData>[]],
    ];
  }

  /// 把已缓存课表网格对齐到当前节次数量，避免 timeConfig 变更后
  /// slots 行数与 cells 列数不一致触发 RangeError。
  List<List<List<_ScheduleCardData>>> _normalizeCells(
    List<List<List<_ScheduleCardData>>> cells,
  ) {
    final slotCount = _activeTimeConfigs.length;
    return [
      for (var d = 0; d < 7; d++)
        [
          for (var s = 0; s < slotCount; s++)
            d < cells.length && s < cells[d].length
                ? cells[d][s]
                : <_ScheduleCardData>[],
        ],
    ];
  }

  /// 根据当前格子内最多课卡数算出每行高度（动态适配 1 / 2 / N 张课卡叠放）。
  /// 编辑模式下额外预留 56px：8 间距 + 48 高 "申请小课" pill，让"大课下方
  /// 也能申请小课"在每一节都成立。
  List<_TimeSlotData> _buildSlots(List<List<List<_ScheduleCardData>>> cells) {
    final configs = _activeTimeConfigs;
    return [
      for (var i = 0; i < configs.length; i++)
        _TimeSlotData(
          start: configs[i].start,
          end: configs[i].end,
          height: _calcSlotHeight(i, cells),
        ),
    ];
  }

  double _calcSlotHeight(
    int slotIdx,
    List<List<List<_ScheduleCardData>>> cells,
  ) {
    var maxCards = 1;
    for (var d = 0; d < cells.length; d++) {
      if (slotIdx < cells[d].length) {
        final n = cells[d][slotIdx].length;
        if (n > maxCards) maxCards = n;
      }
    }
    // 1 张：96 + 24 padding = 120；2 张：96 + 6 + 96 + 24 = 222；
    // N 张：120 + (N - 1) × 102（102 = 96 卡高 + 6 间距）。
    final base = 120.0 + (maxCards - 1) * 102.0;
    // 编辑模式下不论是否已有课卡，都在卡片下方挂"申请小课" pill（8 + 48）。
    if (_mode == _ScheduleMode.edit) return base + 56;
    return base;
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

  /// 把 courseList 单条记录翻译成 [_ScheduleCardData]。
  ///
  /// `type == 1` → 小课（同一格里第 0 张橙、第 1 张蓝循环）；`type == 0` → 大课。
  /// `color` 是 hex（含 `#`），存到卡片做背景覆盖；标题色按 kind 走语义色。
  ///
  /// 当 [applyStatus] 非空时，表示这条来自「我的小课申请」列表，会被透传
  /// 到 [_ScheduleCardData.applyStatus] 给卡片画状态徽章用；同时 [apply]
  /// 用来回看上下文（详情弹窗 / 重新申请抽屉预填）。
  _ScheduleCardData _parseCourseCard(
    Map<String, dynamic> json,
    int smallIdxInCell, {
    _ApplyStatus? applyStatus,
    _ApplyContext? apply,
  }) {
    final rawCopy = Map<String, dynamic>.from(json);
    return _ScheduleCardData(
      display: buildScheduleCourseCard(json, smallIdxInCell),
      raw: rawCopy,
      applyStatus: applyStatus,
      apply: apply,
    );
  }

  /// 当前周课表内，指定日期 + 节次是否已有小课（含待审核申请幽灵卡）。
  bool _slotHasSmallCourseAt(String dateIso, int lineNum) {
    final dayIdx = _dayIndex(dateIso);
    if (dayIdx < 0) return false;
    final configs = _activeTimeConfigs;
    var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
    if (slotIdx < 0) {
      slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
    }
    final cells = _normalizeCells(_serverCells);
    return cells[dayIdx][slotIdx].any(_isSmallScheduleCard);
  }

  bool _isSmallScheduleCard(_ScheduleCardData card) =>
      card.kind == ScheduleCourseCardKind.smallOrange ||
      card.kind == ScheduleCourseCardKind.smallBlue;

  /// 根据 `_weekStart` 拼出 7 天的 header（标签 + MM/DD + 是否今天）。
  List<_DayHeaderData> _buildDayHeaders() {
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
          return _DayHeaderData(
            weekdayLabel: labels[i],
            dateLabel:
                '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}',
            date: DateTime(d.year, d.month, d.day),
            today: isToday,
          );
        }(),
    ];
  }

  /// 把节次/日期组合成 "第N节 HH:MM-HH:MM· 周X yyyy-MM-dd" 形式（抽屉只读项）。
  String _slotLabel(int dayIdx, int slotIdx) {
    final configs = _activeTimeConfigs;
    final cfg = configs[slotIdx.clamp(0, configs.length - 1)];
    final day = _weekStart.add(Duration(days: dayIdx));
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '第${cfg.lineNum}节 ${cfg.start}-${cfg.end}· ${labels[dayIdx]} '
        '${_isoDate(day)}';
  }

  /// 编辑模式空格落点要传给抽屉的 lineNum：取该 slot 对应的 lineNum
  /// （API 配置可能是 1/2/3/5/6 这种非连续序列）。
  int _lineNumOf(int slotIdx) {
    final configs = _activeTimeConfigs;
    return configs[slotIdx.clamp(0, configs.length - 1)].lineNum;
  }

  /// 给「已驳回 / 待审核」申请幽灵卡拼一句只读时间标签：
  /// `第N节 HH:MM-HH:MM· 周X yyyy-MM-dd`。lineNum 在时间配置里找不到时
  /// 就直接用 `第${lineNum}节`，避免误导。dateIso 已是 yyyy-MM-dd。
  String _slotLabelForApply(_ApplyContext ctx) {
    final cfg = _activeTimeConfigs.firstWhere(
      (c) => c.lineNum == ctx.lineNum,
      orElse: () => _TimeConfig(lineNum: ctx.lineNum, start: '', end: ''),
    );
    final timeSegment = cfg.start.isNotEmpty && cfg.end.isNotEmpty
        ? ' ${cfg.start}-${cfg.end}'
        : '';
    String weekdayLabel = '';
    try {
      final d = DateTime.parse(ctx.dateIso);
      const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      // DateTime.weekday：周一=1 .. 周日=7
      weekdayLabel = labels[(d.weekday - 1).clamp(0, 6)];
    } catch (_) {
      weekdayLabel = '';
    }
    final prefix = weekdayLabel.isEmpty ? '' : '· $weekdayLabel ';
    return '第${ctx.lineNum}节$timeSegment$prefix${ctx.dateIso}';
  }

  /// 打开「我的小课申请记录」右侧抽屉：
  ///   - 列出我所有状态的申请（待审核 / 通过 / 驳回）
  ///   - 「驳回」记录可点击「重新申请」复用原参数二次提交
  ///   - 抽屉关闭后若提交过新申请，回到课表会重新拉一次课表 + 申请列表
  Future<void> _openApplyRecords() async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final reapplied = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: '关闭',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondary) {
        return DashboardScaleScope(
          data: scaleData,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: _ApplyRecordsDrawer(
                classNameById: _classNameById,
                classroomNameById: _classroomNameById,
                subjectNameById: _subjectNameById,
                onClose: () => Navigator.of(ctx).maybePop(),
                onRequestReapply: (apply) async {
                  Navigator.of(ctx).pop(true);
                  await _reapplySmallLesson(apply);
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondary, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );

    if (reapplied == true && mounted) {
      await _loadSchedule();
    }
  }

  /// 重新申请：以驳回申请的 classId / classroomId / subjectId /
  /// lineNum / date 作为初始值打开 [_ApplySmallLessonDrawer]，用户可以
  /// 直接点提交（同一参数），也可以微调日期 / 节次 / 复用方式后再交。
  Future<void> _reapplySmallLesson(_ApplyContext apply) async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final submitted = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: '关闭',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondary) {
        return DashboardScaleScope(
          data: scaleData,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: _ApplySmallLessonDrawer(
                slotLabel: _slotLabelForApply(apply),
                baseDateIso: apply.dateIso,
                lineNum: apply.lineNum,
                currentWeek: _currentWeek,
                initialClassId: apply.classId,
                initialClassroomId: apply.classroomId?.toString(),
                initialSubjectId: apply.subjectId?.toString(),
                initialStudentIds: apply.studentIds,
                slotHasSmallCourseAt: _slotHasSmallCourseAt,
                onCancel: () => Navigator.of(ctx).maybePop(),
                onSubmitted: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondary, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );

    if (submitted != true || !mounted) return;
    AppToast.show(context, '已提交教务审核');
    await _loadSchedule();
  }

  /// 编辑模式下点击空格 → 弹右侧 [_ApplySmallLessonDrawer]，提交时调
  /// `schoolSmallCourseApplySave` 写入一条申请，成功后重新拉取本周课表。
  Future<void> _onApplySmallLesson(int dayIdx, int slotIdx) async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final day = _weekStart.add(Duration(days: dayIdx));

    final submitted = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: '关闭',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondary) {
        return DashboardScaleScope(
          data: scaleData,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: _ApplySmallLessonDrawer(
                slotLabel: _slotLabel(dayIdx, slotIdx),
                baseDateIso: _isoDate(day),
                lineNum: _lineNumOf(slotIdx),
                currentWeek: _currentWeek,
                initialClassId: _firstClassId,
                slotHasSmallCourseAt: _slotHasSmallCourseAt,
                onCancel: () => Navigator.of(ctx).maybePop(),
                onSubmitted: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondary, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );

    if (submitted != true || !mounted) return;
    AppToast.show(context, '已提交教务审核');
    await _loadSchedule();
  }

  // —— Build ————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cells = _normalizeCells(_serverCells);
    final slots = _buildSlots(cells);
    final days = _buildDayHeaders();

    return SmartCampusSchedulePageShell(
      backgroundColor: _kCardBg,
      bodyScrollable: false,
      header: _TeacherScheduleHeader(
        onBack: widget.onBack,
        mode: _mode,
        onModeChanged: (m) => setState(() => _mode = m),
        onOpenApplyRecords: _openApplyRecords,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(ui(20), ui(0), ui(20), ui(12)),
            child: _TeacherScheduleControlBar(
              week: _currentWeek,
              weekDateLabel: _fmtDate(_weekStart),
              onPrev: _gotoPrev,
              onCurrent: _gotoCurrent,
              onNext: _gotoNext,
              onPickDate: _pickDate,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(0), ui(20), ui(20)),
              child: ScheduleGridShell(
                key: _scheduleGridKey,
                slots: slots,
                days: days,
                body: _DaysBodyArea(
                  mode: _mode,
                  slots: slots,
                  days: days,
                  cells: cells,
                  onApplySmallLesson: _onApplySmallLesson,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 顶部 banner：68 高，白→紫淡色渐变；居中标题 + 副标题；右上"查看/编辑"分段
// =============================================================================

class _TeacherScheduleHeader extends StatelessWidget {
  const _TeacherScheduleHeader({
    required this.onBack,
    required this.mode,
    required this.onModeChanged,
    required this.onOpenApplyRecords,
  });

  final VoidCallback onBack;
  final _ScheduleMode mode;
  final ValueChanged<_ScheduleMode> onModeChanged;

  /// 顶部右上「申请记录」按钮回调，打开「我的小课申请记录」抽屉，
  /// 内容由父页面注入完整字典（班级 / 教室 / 科目）+ 「重新申请」连接。
  final VoidCallback onOpenApplyRecords;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusScheduleTopBar(
      child: Stack(
        fit: StackFit.expand,
        children: [
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
            Positioned.fill(
              child: Center(
                child: Text(
                  '授课课表',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              right: ui(20),
              top: ui(18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ApplyRecordsButton(onTap: onOpenApplyRecords),
                  SizedBox(width: ui(10)),
                  _ViewEditSegment(mode: mode, onChanged: onModeChanged),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _ApplyRecordsButton extends StatelessWidget {
  const _ApplyRecordsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: ui(18),
              color: const Color(0xFF1C274C),
            ),
            SizedBox(width: ui(6)),
            Text(
              '申请记录',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewEditSegment extends StatelessWidget {
  const _ViewEditSegment({required this.mode, required this.onChanged});

  final _ScheduleMode mode;
  final ValueChanged<_ScheduleMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentToggle(
      selectedIndex: mode == _ScheduleMode.view ? 0 : 1,
      options: const [
        SegmentToggleOption(label: '查看'),
        SegmentToggleOption(label: '编辑'),
      ],
      onChanged: (i) =>
          onChanged(i == 0 ? _ScheduleMode.view : _ScheduleMode.edit),
    );
  }
}

// =============================================================================
// 控制条：教学周 + legend + 周切换 + 当周日期
// =============================================================================

class _TeacherScheduleControlBar extends StatelessWidget {
  const _TeacherScheduleControlBar({
    required this.week,
    required this.weekDateLabel,
    required this.onPrev,
    required this.onCurrent,
    required this.onNext,
    required this.onPickDate,
  });

  final int week;
  final String weekDateLabel;
  final VoidCallback onPrev;
  final VoidCallback onCurrent;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                SizedBox(height: ui(8)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LegendItem(
                      dotColor: _kStatusPurple,
                      label: '大课',
                      tail: '不可编辑',
                    ),
                    SizedBox(width: ui(16)),
                    const _LegendItem(
                      dotColor: _kStatusGreen,
                      label: '小课',
                      tail: '编辑模式下可点击',
                    ),
                  ],
                ),
              ],
            ),
          ),
          _WeekSwitcher(onPrev: onPrev, onCurrent: onCurrent, onNext: onNext),
          SizedBox(width: ui(8)),
          _ControlPill(
            onTap: onPickDate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekDateLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
                SizedBox(width: ui(8)),
                AppPickerAssetIcon(
                  AppAssets.iconScheduleCalendar,
                  imageSize: ui(18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.dotColor,
    required this.label,
    required this.tail,
  });

  final Color dotColor;
  final String label;
  final String tail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: ui(6),
                height: ui(6),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: ui(4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: ui(8)),
        Text(
          tail,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          ),
        ),
      ],
    );
  }
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: child,
      ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.onPrev,
    required this.onCurrent,
    required this.onNext,
  });

  final VoidCallback onPrev;
  final VoidCallback onCurrent;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(ui(8))),
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
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
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
    required this.mode,
    required this.slots,
    required this.days,
    required this.cells,
    required this.onApplySmallLesson,
  });

  final _ScheduleMode mode;
  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final List<List<List<_ScheduleCardData>>> cells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var slotIdx = 0; slotIdx < slots.length; slotIdx++)
          _DayBodyRow(
            slotIdx: slotIdx,
            slotEnd: slots[slotIdx].end,
            height: slots[slotIdx].height,
            mode: mode,
            days: days,
            rowCells: [
              for (var dayIdx = 0; dayIdx < days.length; dayIdx++)
                cells[dayIdx][slotIdx],
            ],
            onApplySmallLesson: onApplySmallLesson,
          ),
      ],
    );
  }
}

class _DayBodyRow extends StatelessWidget {
  const _DayBodyRow({
    required this.slotIdx,
    required this.slotEnd,
    required this.height,
    required this.mode,
    required this.days,
    required this.rowCells,
    required this.onApplySmallLesson,
  });

  final int slotIdx;
  final String slotEnd;
  final double height;
  final _ScheduleMode mode;
  final List<_DayHeaderData> days;
  final List<List<_ScheduleCardData>> rowCells;
  final void Function(int dayIdx, int slotIdx) onApplySmallLesson;

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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _CellContent(
                      slotIdx: slotIdx,
                      slotEnd: slotEnd,
                      slotHeight: height,
                      mode: mode,
                      slotDate: days[i].date,
                      cards: rowCells[i],
                      onApplySmallLesson: () => onApplySmallLesson(i, slotIdx),
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
    required this.slotIdx,
    required this.slotEnd,
    required this.slotHeight,
    required this.mode,
    required this.slotDate,
    required this.cards,
    required this.onApplySmallLesson,
  });

  final int slotIdx;
  final String slotEnd;
  final double slotHeight;
  final _ScheduleMode mode;
  final DateTime slotDate;
  final List<_ScheduleCardData> cards;
  final VoidCallback onApplySmallLesson;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEditing = mode == _ScheduleMode.edit;
    if (cards.isEmpty) {
      // 查看模式空格用斜线背景图占位；编辑模式画 "申请小课" pill。
      if (isEditing) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
          child: Align(
            alignment: Alignment.topCenter,
            child: _ApplySmallLessonButton(onTap: onApplySmallLesson),
          ),
        );
      }
      return const ScheduleIdleSlot();
    }
    // 编辑模式：无论本格当前是大课还是小课，都允许在卡片下方继续"申请小课"。
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
              ScheduleCourseCard(
                data: cards[i].display,
                editable: isEditing && _isSmall(cards[i].kind),
                isPast: isPast,
                topRightBadge: cards[i].applyStatus != null
                    ? _ApplyStatusBadge(status: cards[i].applyStatus!)
                    : null,
              ),
            ],
            if (isEditing) ...[
              SizedBox(height: ui(8)),
              _ApplySmallLessonButton(onTap: onApplySmallLesson),
            ],
          ],
        ),
      ),
    );
  }

  bool _isSmall(ScheduleCourseCardKind k) =>
      k == ScheduleCourseCardKind.smallOrange ||
      k == ScheduleCourseCardKind.smallBlue;
}

class _ApplySmallLessonButton extends StatelessWidget {
  const _ApplySmallLessonButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: double.infinity,
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.scheduleApplyCourse,
              width: ui(14),
              height: ui(14),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(6)),
            Text(
              '申请小课',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 课卡（4 主题）
// =============================================================================

/// 「我的小课申请」状态徽章（替换课卡右上角的「小课」pill）。
/// 颜色与 admin schedule 审核 tab 的 `_ApplyStatusBadge` 一致：
///   - 待审核：橙底橙字 (#FFEDD3 / #FF6A00)
///   - 已驳回：红底红字 (#FFE5E5 / #E83A3A)
/// 已通过的申请不会画到课表上（_loadSchedule 已去重），所以这里只覆盖
/// pending / rejected 两种态。
class _ApplyStatusBadge extends StatelessWidget {
  const _ApplyStatusBadge({required this.status});

  final _ApplyStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (label, bg, fg) = switch (status) {
      _ApplyStatus.pending => ('待审核', _kApplyPendingBg, _kApplyPendingFg),
      _ApplyStatus.rejected => ('已驳回', _kApplyRejectedBg, _kApplyRejectedFg),
      // 不会渲染，留作 fallback 保证 switch 穷举。
      _ApplyStatus.passed => ('已通过', _kApplyPendingBg, _kApplyPendingFg),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 15.24 / 12,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ui(40),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(18)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFA894EB) : Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: primary ? null : Border.all(color: _kBorderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(13),
            color: primary ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 18 / 13,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 「我的小课申请记录」右侧抽屉
//
// 入口：授课课表右上角「申请记录」按钮 → _openApplyRecords →
//      showGeneralDialog 右滑入场 → 本抽屉。
//
// 设计：宽 520，全高，白底；顶部 62 高 _DrawerHeader（3×15 紫竖条 + 标题
// 「我的小课申请记录」+ 关闭 X，底部 1px #F3F2F3 边）；表体为
// `teacherRepo.schoolSmallCourseApplyList(current:1,size:100)` 返回的记录列表，
// 一条申请一张卡片，按 `createTime` 倒序显示。每张卡片包含：
//   - 顶行：状态徽章（橙待审核 / 绿通过 / 红驳回）+ 班级 · 科目
//   - 时间：startDate ~ endDate · 共 N 次 · 第 lineNum 节
//   - 教室
//   - 申请时间（createTime）
//   - 驳回时额外渲染红底块「驳回理由：…」+ 右侧「重新申请」紫底按钮
//     点击「重新申请」会带着原 classId / classroomId / subjectId / color /
//     lineNum / 首次 date 打开 _ApplySmallLessonDrawer，用户可直接提交。
// =============================================================================
class _ApplyRecordsDrawer extends ConsumerStatefulWidget {
  const _ApplyRecordsDrawer({
    required this.classNameById,
    required this.classroomNameById,
    required this.subjectNameById,
    required this.onClose,
    required this.onRequestReapply,
  });

  /// 父页面缓存的班级 id → 名称字典（classId 是 String，雪花）。
  final Map<String, String> classNameById;

  /// 父页面缓存的教室 id → 名称字典（classroomId 是 int）。
  final Map<int, String> classroomNameById;

  /// 父页面缓存的科目 id → 名称字典（subjectId 是 int）。
  final Map<int, String> subjectNameById;

  final VoidCallback onClose;

  /// 「重新申请」按钮回调，参数即驳回申请的回看上下文；
  /// 父页面收到后会先关本抽屉、再打开申请抽屉预填同参数。
  final ValueChanged<_ApplyContext> onRequestReapply;

  @override
  ConsumerState<_ApplyRecordsDrawer> createState() =>
      _ApplyRecordsDrawerState();
}

class _ApplyRecordsDrawerState extends ConsumerState<_ApplyRecordsDrawer> {
  String? _error;
  List<_ApplyRecordItem> _records = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.schoolSmallCourseApplyList(current: 1, size: 100);
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _error = resp.displayMsg;
        _records = const [];
      });
      return;
    }
    final raw = resp.data;
    List<dynamic> rows = const [];
    if (raw is Map) {
      final r = raw['records'] ?? raw['list'] ?? raw['data'];
      if (r is List) rows = r;
    } else if (raw is List) {
      rows = raw;
    }
    final items = <_ApplyRecordItem>[];
    for (final r in rows) {
      if (r is! Map) continue;
      final m = r.cast<String, dynamic>();
      final item = _ApplyRecordItem.fromJson(m);
      if (item != null) items.add(item);
    }
    // 按 createTime 倒序：最新提交的排最前。createTime 字符串可直接字典序比较
    // （`yyyy-MM-dd HH:mm:ss`），无 createTime 的兜底排到最后。
    items.sort((a, b) => b.createTime.compareTo(a.createTime));
    setState(() {
      _records = items;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(520),
      height: double.infinity,
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DrawerHeader(title: '我的小课申请记录', onClose: widget.onClose),
          Expanded(child: _buildBody(context, ui)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, double Function(double) ui) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        child: Text(
          '暂无申请记录',
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(ui(20), ui(16), ui(20), ui(20)),
      itemCount: _records.length,
      separatorBuilder: (_, _) => SizedBox(height: ui(12)),
      itemBuilder: (ctx, i) {
        final r = _records[i];
        return _ApplyRecordCard(
          record: r,
          classNameById: widget.classNameById,
          classroomNameById: widget.classroomNameById,
          subjectNameById: widget.subjectNameById,
          onReapply: () => widget.onRequestReapply(r.toReapplyContext()),
        );
      },
    );
  }
}

/// 「我的小课申请记录」抽屉一张卡片对应的数据模型。
/// 字段一对一对应 `schoolSmallCourseApplyList` 单条记录里我们用得到的部分。
class _ApplyRecordItem {
  const _ApplyRecordItem({
    required this.id,
    required this.status,
    required this.classId,
    required this.classroomId,
    required this.subjectId,
    required this.lineNum,
    required this.startDate,
    required this.endDate,
    required this.occurrences,
    required this.firstDateIso,
    required this.colorHex,
    required this.reason,
    required this.createTime,
    this.studentIds = const [],
  });

  final String id;
  final _ApplyStatus status;
  final String classId;
  final int? classroomId;
  final int? subjectId;
  final int lineNum;
  final String startDate;
  final String endDate;
  final int occurrences;

  /// `courseData` 第一条的 date；为空时退化为 [startDate]。
  /// 「重新申请」会用它作为申请抽屉的 baseDateIso。
  final String firstDateIso;
  final String colorHex;
  final String reason;
  final String createTime;
  final List<String> studentIds;

  static _ApplyRecordItem? fromJson(Map<String, dynamic> m) {
    final id = _pickString(m, ['id', 'applyId'], '');
    if (id.isEmpty) return null;
    final statusRaw = m['status'];
    final status = _parseApplyStatus(statusRaw);
    final classId = _pickString(m, ['classId', 'cId'], '');
    final lineRaw = m['lineNum'];
    final lineNum = lineRaw is int
        ? lineRaw
        : (int.tryParse(lineRaw?.toString() ?? '') ?? 0);
    final classroomRaw = m['classroomId'];
    final classroomId = classroomRaw is int
        ? classroomRaw
        : int.tryParse(classroomRaw?.toString() ?? '');
    final subjectRaw = m['subjectId'];
    final subjectId = subjectRaw is int
        ? subjectRaw
        : int.tryParse(subjectRaw?.toString() ?? '');
    final startDate = _pickString(m, ['startDate'], '');
    final endDate = _pickString(m, ['endDate'], '');
    final colorHex = _pickString(m, ['color'], '');
    final reason = _pickString(m, ['reason'], '');
    final createTime = _pickString(m, ['createTime'], '');

    // 解 courseData 拿到「共 N 次」、firstDateIso 与参与学生。
    int occurrences = 0;
    String firstDateIso = startDate;
    final studentIds = <String>{};
    final cdRaw = m['courseData'];
    List<dynamic>? children;
    if (cdRaw is String && cdRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(_preserveLongIds(cdRaw));
        if (decoded is List) children = decoded;
      } catch (_) {}
    } else if (cdRaw is List) {
      children = cdRaw;
    }
    if (children != null) {
      occurrences = children.length;
      if (children.isNotEmpty && children.first is Map) {
        final first = (children.first as Map).cast<String, dynamic>();
        final d = _pickString(first, ['date'], '');
        if (d.isNotEmpty) firstDateIso = d;
      }
      for (final child in children) {
        if (child is Map) {
          studentIds.addAll(
            _extractStudentIdsFromCourseMap(child.cast<String, dynamic>()),
          );
        }
      }
    }

    return _ApplyRecordItem(
      id: id,
      status: status,
      classId: classId,
      classroomId: classroomId,
      subjectId: subjectId,
      lineNum: lineNum,
      startDate: startDate,
      endDate: endDate,
      occurrences: occurrences,
      firstDateIso: firstDateIso,
      colorHex: colorHex,
      reason: reason,
      createTime: createTime,
      studentIds: studentIds.toList(),
    );
  }

  _ApplyContext toReapplyContext() {
    return _ApplyContext(
      applyId: id,
      status: status,
      classId: classId,
      lineNum: lineNum,
      dateIso: firstDateIso,
      reason: reason.isEmpty ? null : reason,
      classroomId: classroomId,
      subjectId: subjectId,
      colorHex: colorHex,
      studentIds: studentIds,
    );
  }
}

class _ApplyRecordCard extends StatelessWidget {
  const _ApplyRecordCard({
    required this.record,
    required this.classNameById,
    required this.classroomNameById,
    required this.subjectNameById,
    required this.onReapply,
  });

  final _ApplyRecordItem record;
  final Map<String, String> classNameById;
  final Map<int, String> classroomNameById;
  final Map<int, String> subjectNameById;

  /// 仅 rejected 卡片底部「重新申请」按钮才会调用；其它状态不展示按钮。
  final VoidCallback onReapply;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isRejected = record.status == _ApplyStatus.rejected;
    final className = classNameById[record.classId] ?? '';
    final classroomName = record.classroomId == null
        ? ''
        : (classroomNameById[record.classroomId!] ?? '');
    final subjectName = record.subjectId == null
        ? ''
        : (subjectNameById[record.subjectId!] ?? '');
    final headRow = <String>[
      if (className.isNotEmpty) className,
      if (subjectName.isNotEmpty) subjectName,
    ].join(' · ');
    final dateLabel = _composeDateLabel();
    final timeRow = <String>[
      if (dateLabel.isNotEmpty) dateLabel,
      if (record.lineNum > 0) '第${record.lineNum}节',
    ].join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(14)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ApplyStatusBadge(status: record.status),
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  headRow.isEmpty ? '—' : headRow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 20 / 14,
                  ),
                ),
              ),
            ],
          ),
          if (timeRow.isNotEmpty) ...[
            SizedBox(height: ui(10)),
            _DetailLine(label: '时间', value: timeRow),
          ],
          if (classroomName.isNotEmpty) ...[
            SizedBox(height: ui(6)),
            _DetailLine(label: '教室', value: classroomName),
          ],
          if (record.createTime.isNotEmpty) ...[
            SizedBox(height: ui(6)),
            _DetailLine(label: '提交', value: record.createTime),
          ],
          if (isRejected && record.reason.isNotEmpty) ...[
            SizedBox(height: ui(12)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: ui(12),
                vertical: ui(10),
              ),
              decoration: BoxDecoration(
                color: _kApplyRejectedBg,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '驳回理由',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kApplyRejectedFg,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 16 / 12,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    record.reason,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 20 / 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isRejected) ...[
            SizedBox(height: ui(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogButton(label: '重新申请', primary: true, onTap: onReapply),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// `startDate ~ endDate · 共 N 次`；单次或起止相同时简化为 `date · 共 1 次`。
  String _composeDateLabel() {
    final s = record.startDate;
    final e = record.endDate;
    final n = record.occurrences;
    String dateSeg;
    if (s.isEmpty && e.isEmpty) {
      dateSeg = '';
    } else if (s.isEmpty) {
      dateSeg = e;
    } else if (e.isEmpty || s == e) {
      dateSeg = s;
    } else {
      dateSeg = '$s ~ $e';
    }
    if (n > 0) {
      return dateSeg.isEmpty ? '共 $n 次' : '$dateSeg · 共 $n 次';
    }
    return dateSeg;
  }
}

// =============================================================================
// 申请「小课」右侧抽屉
//
// 入口：编辑模式格子内的"申请小课" pill → _onApplySmallLesson →
//      showGeneralDialog 右滑入场 → 本抽屉。
//
// 设计：宽 600，全高，白底；顶部 62 高 _DrawerHeader（3×15 紫竖条 + "申请小课"
// 16/600 标题 + 关闭 X，底部 1px #F3F2F3 边）；表单 6 段：
//   1. 课程时间：只读 #F5F6FA 灰底 48 高
//   2. 班级：调 teacher.classList()（大 + 小全量），String id 下拉。
//   3. 参与学生：按所选班级调 teacher.studentList，`type` 与班级类型
//          对齐（0 大班 / 1 小班），勾选后写入 courseList[].studentIds。
//   4. 教室：调 teacher.classroomList，int id 下拉
//   5. 科目：调 user.subjectList(classId)，int id 下拉
//   6. 颜色：13 色色板 + 当前 hex chip
//   7. 是否复用：不复用 / 本学期所有 / 后续 4 周 / 后续 8 周
// 底部：560×48 紫色横向渐变 (#B68EFF→#8640FF) "提交教务审核" 按钮。
//
// 提交：调 `/app/school/v2/teacher/schoolSmallCourseApplySave`，
// 字段格式：
// ```json
// {
//   "classId": "...",       // String，雪花
//   "classroomId": 1,       // int
//   "subjectId": 1,         // int
//   "color": "#xxxxxx",
//   "lineNum": 1,
//   "startDate": "2026-05-08",
//   "endDate": "2026-05-08",
//   "courseList": [
//     {
//       "classId": "...",
//       "classroomId": 1,
//       "subjectId": 1,
//       "color": "#xxxxxx",
//       "date": "2026-05-08",
//       "lineNum": 1,
//       "teacherId": "..."   // String，当前任课老师 id（雪花）
//       "studentIds": ["..."] // 参与学生雪花 id 列表
//     }
//   ]
// }
// ```
//
// 时间字段全部使用 `yyyy-MM-dd`（不带时区后缀，按需求统一）。
// =============================================================================

// =============================================================================
// 申请小课抽屉（任课老师授课课表专用）
// =============================================================================

/// 任课老师「申请小课」默认选中色与色板首色。
const Color _kTeacherApplySmallLessonDefaultColor = Color(0xFFACFBBA);

final List<Color> _kTeacherApplySmallLessonPalette = <Color>[
  _kTeacherApplySmallLessonDefaultColor,
  ...scheduleColorPalette.sublist(1),
];

class _ApplySmallLessonDrawer extends ConsumerStatefulWidget {
  const _ApplySmallLessonDrawer({
    required this.slotLabel,
    required this.baseDateIso,
    required this.lineNum,
    required this.currentWeek,
    required this.onCancel,
    required this.onSubmitted,
    required this.slotHasSmallCourseAt,
    this.initialClassId,
    this.initialClassroomId,
    this.initialSubjectId,
    this.initialStudentIds,
  });

  /// 抽屉顶部只读"课程时间"展示，例如
  /// `第 1 节 08:00-08:40· 周一 2026-05-04`。
  final String slotLabel;

  /// 用户点击空格对应的当周日期（`yyyy-MM-dd`）。
  final String baseDateIso;

  /// 节次（与 schoolTimeConfigList.lineNum 对齐）。
  final int lineNum;

  /// 父页面当前显示的"教学周第 N 周"，复用模式按它计算还剩多少周。
  final int currentWeek;

  /// 父页面已知的默认班级（班级列表第一项）；非空时直接预选。
  final String? initialClassId;

  /// 「重新申请」场景下用驳回申请的原 classroomId 预选；
  /// 普通申请走列表第 1 项兜底。
  final String? initialClassroomId;

  /// 「重新申请」场景下用驳回申请的原 subjectId 预选；
  /// 等 _loadSubjects 拉完后会校验该 id 是否在当前班级科目里。
  final String? initialSubjectId;

  /// 「重新申请」场景下从 courseData 解析的参与学生 id，用于回填勾选。
  final List<String>? initialStudentIds;

  /// 查询当前周课表内指定日期 + 节次是否已有小课。
  final bool Function(String dateIso, int lineNum) slotHasSmallCourseAt;

  final VoidCallback onCancel;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ApplySmallLessonDrawer> createState() =>
      _ApplySmallLessonDrawerState();
}

class _ApplySmallLessonDrawerState
    extends ConsumerState<_ApplySmallLessonDrawer> {
  // 班级下拉 cache：(id, name, type)。`type` 与 studentList 请求体对齐：0 大班 / 1 小班。
  List<({String id, String name, int type})> _classes = const [];
  List<({String id, String name})> _classrooms = const [];
  List<({String id, String name})> _subjects = const [];
  List<({String id, String name, String studentNo})> _students = const [];

  String? _classId;
  String? _classroomId;
  String? _subjectId;
  final Set<String> _selectedStudentIds = <String>{};
  bool _loadingSubjects = false;
  bool _loadingStudents = false;

  Color _color = _kTeacherApplySmallLessonDefaultColor;
  String _reuse = '不复用';
  bool _submitting = false;

  static const List<String> _reuseOptions = <String>[
    '不复用',
    '本学期所有教学周',
    '后续 4 周',
    '后续 8 周',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  Future<void> _loadOptions() async {
    // 班级 / 教室均走 teacher 端接口。
    final teacherRepo = ref.read(teacherRepositoryProvider);
    final results = await Future.wait([
      teacherRepo.classList(isClassTeacher: 1),
      teacherRepo.classroomList(),
    ]);
    if (!mounted) return;
    setState(() {
      _classes = _toClassOptions(results[0]);
      _classrooms = _toOptions(
        results[1],
        idKeys: const ['id', 'classroomId', 'roomId'],
        nameKeys: const ['classroomName', 'roomName', 'name'],
      );
      // 父页面已选班级时优先回填；否则取列表第 1 项。
      final initial = widget.initialClassId;
      if (initial != null &&
          initial.isNotEmpty &&
          _classes.any((c) => c.id == initial)) {
        _classId = initial;
      } else {
        _classId ??= _classes.isNotEmpty ? _classes.first.id : null;
      }
      // 「重新申请」预填教室：用驳回申请的原 classroomId；不在当前列表里
      // 就回退到列表第 1 项，避免提交时引用一个不存在的 id。
      final initialRoom = widget.initialClassroomId;
      if (initialRoom != null &&
          initialRoom.isNotEmpty &&
          _classrooms.any((c) => c.id == initialRoom)) {
        _classroomId = initialRoom;
      } else {
        _classroomId ??= _classrooms.isNotEmpty ? _classrooms.first.id : null;
      }
      // 科目还没拉，先把「重新申请」希望预选的 id 兜在 _subjectId 里，
      // _loadSubjects 拉完后会校验它是否在当前班级科目里 → 不在就回退。
      if (widget.initialSubjectId != null &&
          widget.initialSubjectId!.isNotEmpty) {
        _subjectId = widget.initialSubjectId;
      }
    });
    await Future.wait([
      _loadSubjects(_classId),
      _loadStudents(_classId),
    ]);
  }

  Future<void> _loadStudents(String? classId) async {
    if (classId == null || classId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _students = const [];
        _selectedStudentIds.clear();
        _loadingStudents = false;
      });
      return;
    }

    setState(() => _loadingStudents = true);
    final classType = _classTypeFor(classId);
    final resp = await ref
        .read(teacherRepositoryProvider)
        .studentList(classId: classId, current: 1, size: 200, type: classType);
    if (!mounted) return;

    final rows = _extractList(resp);
    final students = <({String id, String name, String studentNo})>[];
    for (final m in rows) {
      final id = readSnowflakeId(m['id'] ?? m['userId'] ?? m['stuId']) ?? '';
      if (id.isEmpty) continue;
      final nickname = _pickString(m, ['nickname', 'nickName'], '');
      final realname = _pickString(m, ['realname', 'realName'], '');
      final name = nickname.isNotEmpty
          ? nickname
          : (realname.isNotEmpty
                ? realname
                : _pickString(m, ['name', 'stuName', 'studentName'], '未命名'));
      final studentNo = _pickString(m, [
        'no',
        'studentNo',
        'studentId',
        'stuNo',
        'stuId',
        'code',
        'studentCode',
      ], '');
      students.add((id: id, name: name, studentNo: studentNo));
    }

    final initial = (classId == widget.initialClassId)
        ? (widget.initialStudentIds ?? const <String>[])
        : const <String>[];
    final preselected = initial.isEmpty
        ? <String>{}
        : students
              .map((s) => s.id)
              .where((id) => initial.contains(id))
              .toSet();

    setState(() {
      _students = students;
      _selectedStudentIds
        ..clear()
        ..addAll(preselected);
      _loadingStudents = false;
    });
  }

  void _toggleStudent(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedStudentIds.add(id);
      } else {
        _selectedStudentIds.remove(id);
      }
    });
  }

  void _toggleAllStudents(bool selectAll) {
    setState(() {
      _selectedStudentIds
        ..clear()
        ..addAll(selectAll ? _students.map((s) => s.id) : const <String>[]);
    });
  }

  Future<void> _loadSubjects(String? classId) async {
    setState(() => _loadingSubjects = true);
    final repo = ref.read(schoolRepositoryProvider);
    final resp = await repo.subjectList(classId: classId);
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _subjects = const [];
        _subjectId = null;
        _loadingSubjects = false;
      });
      return;
    }
    final list = _toOptions(
      resp,
      idKeys: const ['id', 'subjectId'],
      nameKeys: const ['name', 'subjectName'],
    );
    setState(() {
      _subjects = list;
      // _subjectId 已被 _loadOptions 兜成「重新申请」希望预选的 id 时，
      // 这里校验是否在当前班级的科目列表里 —— 不在 / 为空就回退到第 1 项。
      if (_subjectId == null || !list.any((s) => s.id == _subjectId)) {
        _subjectId = list.isNotEmpty ? list.first.id : null;
      }
      _loadingSubjects = false;
    });
  }

  int _classTypeFor(String? classId) {
    if (classId == null || classId.isEmpty) return 0;
    for (final c in _classes) {
      if (c.id == classId) return c.type;
    }
    return 0;
  }

  List<({String id, String name, int type})> _toClassOptions(ApiResponse resp) {
    if (!resp.isSuccess) return const [];
    final rows = _extractList(resp);
    return [
      for (final m in rows)
        if (_pickString(m, const ['id', 'classId', 'cId'], '').isNotEmpty &&
            _pickString(
              m,
              const ['className', 'class', 'name', 'fullName'],
              '',
            ).isNotEmpty)
          (
            id: _pickString(m, const ['id', 'classId', 'cId'], ''),
            name: _pickString(
              m,
              const ['className', 'class', 'name', 'fullName'],
              '',
            ),
            type: _classTypeFromJson(m['type'] ?? m['classType'] ?? m['kind']),
          ),
    ];
  }

  List<({String id, String name})> _toOptions(
    ApiResponse resp, {
    required List<String> idKeys,
    required List<String> nameKeys,
  }) {
    if (!resp.isSuccess) return const [];
    final rows = _extractList(resp);
    return [
      for (final m in rows)
        if (_pickString(m, idKeys, '').isNotEmpty &&
            _pickString(m, nameKeys, '').isNotEmpty)
          (id: _pickString(m, idKeys, ''), name: _pickString(m, nameKeys, '')),
    ];
  }

  String get _hexLabel => scheduleColorToHex(_color);

  /// 根据 `_reuse` 选项展开成多个排课日期：
  ///   - 不复用 → 仅基准日 1 行
  ///   - 本学期所有教学周 → 从当前周开始补到第 [kScheduleTermTotalWeeks] 周
  ///   - 后续 4 周 → 基准日 + 4 个连续周（共 5 行）
  ///   - 后续 8 周 → 基准日 + 8 个连续周（共 9 行）
  List<DateTime> _computeReuseDates() {
    final base = DateTime.tryParse(widget.baseDateIso) ?? DateTime.now();
    return scheduleReuseDates(
      base: base,
      reuseMode: _reuse,
      currentWeek: widget.currentWeek,
    );
  }

  /// `2026-05-04` 格式（无时间，无时区）。
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_submitting) return;
    if (_classId == null || _classId!.isEmpty) {
      AppToast.show(context, '请先选择班级');
      return;
    }
    if (_classroomId == null || _classroomId!.isEmpty) {
      AppToast.show(context, '请先选择教室');
      return;
    }
    if (_subjectId == null || _subjectId!.isEmpty) {
      AppToast.show(context, '请先选择科目');
      return;
    }
    if (_selectedStudentIds.isEmpty) {
      AppToast.show(context, '请至少勾选一名参与学生');
      return;
    }

    final dates = _computeReuseDates();
    final hasExistingSmall = dates.any(
      (d) => widget.slotHasSmallCourseAt(_ymd(d), widget.lineNum),
    );
    if (hasExistingSmall) {
      final confirmed = await showConfirmDialog(
        context: context,
        title: '提示',
        content: '本时段已有小课，是否继续申请？',
        confirmLabel: '继续申请',
        cancelLabel: '取消',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _submitting = true);

    // classroomId / subjectId 后端期望 int；雪花长 classId / teacherId 走 String。
    final classroomNum = int.tryParse(_classroomId!);
    final subjectNum = int.tryParse(_subjectId!);

    // teacherId 取自当前登录的任课老师（shellState.user.id 是 myInfo.user.id 原文，
    // 雪花长以 String 承载，避免 web 端 JS Number 精度截断）。空串时省略，
    // 让后端按 token 自行解析。
    final teacherId = ref.read(shellControllerProvider).user.id;

    final color = _hexLabel;
    final studentIds = _selectedStudentIds.toList(growable: false);
    final courseList = <Map<String, dynamic>>[
      for (final d in dates)
        <String, dynamic>{
          'classId': _classId,
          'classroomId': classroomNum ?? _classroomId,
          'subjectId': subjectNum ?? _subjectId,
          'color': color,
          'date': _ymd(d),
          'lineNum': widget.lineNum,
          if (teacherId.isNotEmpty) 'teacherId': teacherId,
          'studentIds': studentIds,
        },
    ];

    final body = <String, dynamic>{
      'classId': _classId,
      'classroomId': classroomNum ?? _classroomId,
      'subjectId': subjectNum ?? _subjectId,
      'color': color,
      'lineNum': widget.lineNum,
      'startDate': _ymd(dates.first),
      'endDate': _ymd(dates.last),
      'courseList': courseList,
    };

    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.schoolSmallCourseApplySave(body);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg);
      return;
    }
    if (courseList.length > 1) {
      AppToast.show(context, '已提交申请（共 ${courseList.length} 周）');
    }
    widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(600),
      height: double.infinity,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            _DrawerHeader(title: '申请小课', onClose: widget.onCancel),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ui(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(
                      iconAsset: AppAssets.scheduleEditCourseTime,
                      label: '课程时间',
                    ),
                    SizedBox(height: ui(12)),
                    _ReadonlyField(text: widget.slotLabel),
                    SizedBox(height: ui(20)),
                    _SectionLabel(
                      iconAsset: AppAssets.scheduleEditClass,
                      label: '班级',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _classId ?? '',
                      items: [for (final c in _classes) c.id],
                      itemLabel: (id) {
                        if (id.isEmpty) return '选择班级';
                        return _classes
                            .firstWhere(
                              (c) => c.id == id,
                              orElse: () => (id: id, name: id, type: 0),
                            )
                            .name;
                      },
                      onChanged: (v) {
                        setState(() => _classId = v);
                        unawaited(Future.wait([
                          _loadSubjects(v),
                          _loadStudents(v),
                        ]));
                      },
                    ),
                    SizedBox(height: ui(20)),
                    _SectionLabel(
                      iconAsset: AppAssets.scheduleEditStudent,
                      label: '参与学生',
                    ),
                    SizedBox(height: ui(12)),
                    _SmallCourseStudentPicker(
                      students: _students,
                      selectedIds: _selectedStudentIds,
                      loading: _loadingStudents,
                      onToggle: _toggleStudent,
                      onToggleAll: _toggleAllStudents,
                    ),
                    SizedBox(height: ui(20)),
                    _SectionLabel(
                      iconAsset: AppAssets.scheduleEditClassroom,
                      label: '教室',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _classroomId ?? '',
                      items: [for (final c in _classrooms) c.id],
                      itemLabel: (id) {
                        if (id.isEmpty) return '选择教室';
                        return _classrooms
                            .firstWhere(
                              (c) => c.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) => setState(() => _classroomId = v),
                    ),
                    SizedBox(height: ui(20)),
                    _SectionLabel(
                      iconAsset: AppAssets.scheduleEditSubject,
                      label: '科目',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _subjectId ?? '',
                      items: [for (final s in _subjects) s.id],
                      itemLabel: (id) {
                        if (id.isEmpty) {
                          return _loadingSubjects ? '加载中…' : '选择科目';
                        }
                        return _subjects
                            .firstWhere(
                              (s) => s.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) => setState(() => _subjectId = v),
                    ),
                    SizedBox(height: ui(20)),
                    _SectionLabel(
                      iconAsset: AppAssets.scheduleEditColor,
                      label: '颜色',
                    ),
                    SizedBox(height: ui(12)),
                    ScheduleColorSwatchPicker(
                      colors: _kTeacherApplySmallLessonPalette,
                      selected: _color,
                      onSelect: (c) => setState(() => _color = c),
                    ),
                    SizedBox(height: ui(20)),
                    _SectionLabel(
                      iconAsset: AppAssets.scheduleEditRepeat,
                      label: '是否复用',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _reuse,
                      items: _reuseOptions,
                      itemLabel: (s) => s,
                      onChanged: (v) => setState(() => _reuse = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
              child: _SubmitGradientButton(
                label: _submitting ? '提交中…' : '提交教务审核',
                onTap: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉顶部 62 高 header：3×15 紫竖条 + 标题 + 关闭 X。
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(62),
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: ui(3.25),
            height: ui(15),
            decoration: BoxDecoration(
              color: _kPurple,
              borderRadius: BorderRadius.circular(ui(6)),
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w600,
              height: 1.2,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(ui(8)),
            child: Padding(
              padding: EdgeInsets.all(ui(8)),
              child: Icon(
                Icons.close_rounded,
                size: ui(18),
                color: _kTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          iconAsset,
          width: ui(16),
          height: ui(16),
          fit: BoxFit.contain,
        ),
        SizedBox(width: ui(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextSecondary,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 14,
        ),
      ),
    );
  }
}

class _SubmitGradientButton extends StatelessWidget {
  const _SubmitGradientButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: double.infinity,
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(16),
              color: Colors.white,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallCourseStudentPicker extends StatelessWidget {
  const _SmallCourseStudentPicker({
    required this.students,
    required this.selectedIds,
    required this.loading,
    required this.onToggle,
    required this.onToggleAll,
  });

  final List<({String id, String name, String studentNo})> students;
  final Set<String> selectedIds;
  final bool loading;
  final void Function(String id, bool selected) onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const listHeight = 220.0;
    final allSelected =
        !loading && students.isNotEmpty && selectedIds.length == students.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              loading
                  ? '学生加载中…'
                  : '已选 ${selectedIds.length} / ${students.length} 人',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
            ),
            const Spacer(),
            if (!loading && students.isNotEmpty)
              InkWell(
                onTap: () => onToggleAll(!allSelected),
                borderRadius: BorderRadius.circular(ui(6)),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(8),
                    vertical: ui(4),
                  ),
                  child: Text(
                    allSelected ? '取消全选' : '全选',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kPurple,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: ui(8)),
        SizedBox(
          height: ui(listHeight),
          child: Container(
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(8)),
              border: Border.all(color: _kBorderSoft),
            ),
            child: loading
                ? Center(
                    child: Text(
                      '学生加载中…',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  )
                : students.isEmpty
                ? Center(
                    child: Text(
                      '该班级暂无学生',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(12),
                      vertical: ui(8),
                    ),
                    itemCount: students.length,
                    separatorBuilder: (_, _) => SizedBox(height: ui(8)),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final checked = selectedIds.contains(student.id);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onToggle(student.id, !checked),
                        child: Row(
                          children: [
                            _ApplySmallLessonCheckbox(checked: checked),
                            SizedBox(width: ui(12)),
                            Text(
                              student.studentNo.isEmpty
                                  ? '—'
                                  : student.studentNo,
                              style: TextStyle(
                                fontSize: ui(12),
                                color: _kTextHint,
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                            SizedBox(width: ui(12)),
                            Expanded(
                              child: Text(
                                student.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: _kTextDark,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ApplySmallLessonCheckbox extends StatelessWidget {
  const _ApplySmallLessonCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(16),
      height: ui(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? _kPurple : Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(
          color: checked ? _kPurple : _kCheckboxBorder,
          width: 1,
        ),
      ),
      child: checked
          ? Icon(Icons.check, size: ui(10), color: Colors.white)
          : null,
    );
  }
}

// =============================================================================
// 通用 helpers（与 admin / 学生端一致的解析函数）
// =============================================================================

List<String> _extractStudentIdsFromCourseMap(Map<String, dynamic> map) {
  final raw = map['studentIds'];
  if (raw is! List) return const [];
  final ids = <String>[];
  for (final item in raw) {
    final sid = readSnowflakeId(item);
    if (sid != null && sid.isNotEmpty) ids.add(sid);
  }
  return ids;
}

/// `status`: 1 = 已通过；2 = 已驳回；0 / null / 其他 = 待审核。
/// 顶层 helper：申请记录抽屉的 `_ApplyRecordItem.fromJson` 是静态工厂方法，
/// 没法访问 state 的实例方法，所以放成 top-level。
_ApplyStatus _parseApplyStatus(dynamic raw) {
  final n = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
  if (n == 1) return _ApplyStatus.passed;
  if (n == 2) return _ApplyStatus.rejected;
  return _ApplyStatus.pending;
}

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

/// 在 `jsonDecode` 前把字符串里未加引号、长度 >= 16 的纯整数字面量补上引号。
///
/// 场景：雪花长 ID（19 位）超过 2^53，Dart Web 经 JS `Number` 解码会截到
/// 相邻偶数（精度丢失）；包成字符串后 jsonDecode 当 String 保留原样。
///
/// 正则要点：
/// - 前置 lookbehind `[:,\[\s]`：保证数字串紧跟在 `:` / `,` / `[` / 空白
///   后，排除已经被引号或属于其它 token 的数字串；
/// - 后置 lookahead  `[,}\]\s]`：保证数字串紧贴 `,` / `}` / `]` / 空白结
///   束，同理。
String _preserveLongIds(String input) {
  return input.replaceAllMapped(
    RegExp(r'(?<=[:,\[\s])(\d{16,})(?=[,}\]\s])'),
    (m) => '"${m.group(1)}"',
  );
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

/// 后端班级 `type`：0 / 含「大」= 大班；1 / 含「小」= 小班。
int _classTypeFromJson(dynamic raw) {
  if (raw == null) return 0;
  if (raw is int) return raw == 1 ? 1 : 0;
  final s = raw.toString().trim().toLowerCase();
  if (s.isEmpty) return 0;
  if (s == '1' || s.contains('小') || s == 'small') return 1;
  return 0;
}
