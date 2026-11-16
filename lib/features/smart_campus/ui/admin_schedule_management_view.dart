// =============================================================================
// 管理员端「排课与课表」独立页面
//
// 入口：admin dashboard 快捷区「排课与课表」按钮 →
//      controller.openScheduleManagement() → mainView == scheduleManagement +
//      role == admin → SmartCampusPage 路由到本视图。
//
// 页面只有一张周课表，按班级查看和调整：
//   1. 顶部 banner：返回 + 标题「排课与课表」。
//   2. 班级下拉（左）+ 查看 / 编辑 分段（右）。
//   3. 控制条（浅灰底）：教学周 + 编辑说明 + ◀ 本周 ▶ + 日期按钮。
//   4. 网格：与学生 / 老师端共用课卡 + 时间冻结列 + 横滚日期区。
//      - 编辑模式下空格出现「排课」按钮，打开右侧 [_AdminEditCourseDrawer]，
//        提交调 `courseBatchSave`；
//      - 长按课卡可以拖到别的格子（先删后加），左滑课卡可以删除。
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../school/data/school_repository.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import '../data/schedule_color_palette.dart';
import '../data/campus_format.dart';
import '../data/schedule_course_card_builder.dart';
import '../data/schedule_slot_time.dart';
import '../data/schedule_teaching_week.dart';
import 'widgets/schedule_course_card.dart';
import 'widgets/schedule_grid_shell.dart';
import 'widgets/schedule_idle_slot.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

// ---- 通用配色 -----------------------------------------------------------

const Color _kInnerGray = AppColors.surfaceSubtle;
const Color _kBorderSoft = AppColors.lineSoft;
const Color _kTextDark = AppColors.ink;
const Color _kTextSecondary = AppColors.textSecondary;
const Color _kPurple = AppColors.brand;

// 列与行尺寸 — 网格壳层见 schedule_grid_shell.dart

enum _ScheduleMode { view, edit }

class AdminScheduleManagementView extends ConsumerStatefulWidget {
  const AdminScheduleManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminScheduleManagementView> createState() =>
      _AdminScheduleManagementViewState();
}

class _AdminScheduleManagementViewState
    extends ConsumerState<AdminScheduleManagementView> {
  /// 当前显示的周一（用于日期范围 / 标签 / API begin/end）。
  late DateTime _weekStart;

  /// "教学周第 N 周" 的展示数字。与 [_weekStart] 联动，规则见
  /// [scheduleTeachingWeekOf] / [scheduleCurrentTeachingWeekAnchor]。
  int _currentWeek = kScheduleCurrentTeachingWeek;

  _ScheduleMode _mode = _ScheduleMode.view;

  /// 班级下拉数据（来自 `classList`）。后端 `schoolTimeConfigList` /
  /// `courseList` 都要求 classId 必填，所以默认进入 = 班级列表第 1 项；
  /// 列表为空前用空字符串占位，加载完成后自动回填。
  List<({String id, String name})> _classes = const [];
  String? _selectedClassId;
  bool _classesLoading = true;

  /// 课表网格的实际数据（[7 天][N 节] → 多张课卡）。
  late List<List<List<_ScheduleCardData>>> _serverCells;
  // 请求中的教学周可能早于画面提交。首屏资料加载完成后继续使用最后一次选择。
  ({DateTime start, int number})? _requestedWeek;
  int _scheduleLoadGeneration = 0;

  /// 课表左侧节次时间表（来自 `schoolTimeConfigList`），按 `lineNum` 升序。
  /// API 未返回时退回 [_kDefaultTimeConfigs] 的 5 节兜底。
  List<_TimeConfig> _timeConfigs = const [];

  List<_TimeConfig> get _activeTimeConfigs =>
      _timeConfigs.isNotEmpty ? _timeConfigs : _kDefaultTimeConfigs;

  String _fmtDate(DateTime d) => campusDate(d);

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _mondayOf(DateTime d) => scheduleMondayOf(d);

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
    if (picked == null) return;
    final newMonday = _mondayOf(picked);
    unawaited(
      _loadSchedule(
        weekStart: newMonday,
        weekNumber: scheduleTeachingWeekOf(newMonday),
      ),
    );
  }

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

  /// 编辑模式下点击空格 → 弹右侧 [_AdminEditCourseDrawer]，提交时调
  /// `courseBatchSave` 写入一条排课，成功后重新拉取本周课表。
  Future<void> _onAddCourse(int dayIdx, int slotIdx) async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final day = _weekStart.add(Duration(days: dayIdx));
    final isoDate = _isoDate(day);

    final submitted = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: '关闭',
      barrierDismissible: true,
      barrierColor: AppColors.ink.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, animation, secondary) {
        return DashboardScaleScope(
          data: scaleData,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: _AdminEditCourseDrawer(
                slotLabel: _slotLabel(dayIdx, slotIdx),
                dateIso: isoDate,
                lineNum: _lineNumOf(slotIdx),
                currentWeek: _currentWeek,
                initialClassId: _selectedClassId,
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
    AppToast.show(context, '已写入课表');
    await _loadSchedule();
  }

  /// 编辑模式下删除已有课程：确认弹窗可选「仅本节」或按周循环删除，再调
  /// `courseDelete`（循环模式会按日期范围拉课表并批量匹配同节课程）。
  Future<void> _onDeleteCourse(_ScheduleCardData card) async {
    final raw = card.raw;
    if (raw == null) return;
    final id = _pickString(raw, ['id'], '');
    if (id.isEmpty) return;

    final location = card.location.isNotEmpty ? card.location : '—';
    final subline = card.subline.trim();
    final deleteScope = await _showDeleteCourseConfirmDialog(
      context,
      courseName: card.name,
      location: location,
      subline: subline,
    );
    if (deleteScope == null || !mounted) return;

    final ids = await _resolveDeleteCourseIds(
      raw: raw,
      deleteScope: deleteScope,
    );
    if (!mounted) return;
    if (ids.isEmpty) return;

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.courseDelete(ids);
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(
        context,
        resp.displayMsg.isNotEmpty ? resp.displayMsg : '删除失败，请重试',
      );
      return;
    }
    if (ids.length > 1) {
      AppToast.show(context, '已删除 ${ids.length} 节「${card.name}」');
    } else {
      AppToast.show(context, '已删除「${card.name}」');
    }
    await _loadSchedule();
  }

  /// 按删除范围展开目标日期，再从 `courseList` 匹配同班级 / 节次 / 教师 /
  /// 科目 / 教室的重复排课 id；「仅删除本节」直接返回当前 id。
  Future<List<String>> _resolveDeleteCourseIds({
    required Map<String, dynamic> raw,
    required String deleteScope,
  }) async {
    final id = _pickString(raw, ['id'], '');
    if (id.isEmpty) return const [];

    if (deleteScope == '仅删除本节') {
      return [id];
    }

    final dateStr = _pickString(raw, ['date', 'classDate', 'courseDate'], '');
    final base =
        DateTime.tryParse(dateStr.split('T').first) ??
        DateTime.tryParse(dateStr);
    if (base == null) return [id];

    final dates = _computeScheduleReuseDates(
      base: base,
      reuseMode: deleteScope,
      currentWeek: _currentWeek,
    );
    if (dates.length <= 1) return [id];

    final dateSet = dates.map(_isoDate).toSet();
    final classId = _pickString(raw, ['classId'], _selectedClassId ?? '');
    if (classId.isEmpty) return [id];

    final lineNumRaw = raw['lineNum'];
    final lineNum = lineNumRaw is int
        ? lineNumRaw
        : int.tryParse(lineNumRaw?.toString() ?? '');
    if (lineNum == null) return [id];

    final teacherId = _pickString(raw, ['teacherId'], '');
    final subjectId = raw['subjectId']?.toString() ?? '';
    final classroomId = raw['classroomId']?.toString() ?? '';

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.courseList(
      classId: classId,
      beginDate: _isoDate(dates.first),
      endDate: _isoDate(dates.last),
    );
    if (!resp.isSuccess) return [id];

    final ids = <String>[];
    for (final entry in _extractCourseRows(resp)) {
      final m = entry.row;
      final recordId = _pickString(m, ['id'], '');
      if (recordId.isEmpty) continue;

      final recordDate = _normalizeCourseDateIso(
        entry.dateKey.isNotEmpty
            ? entry.dateKey
            : _pickString(m, ['date', 'classDate', 'courseDate'], ''),
      );
      if (!dateSet.contains(recordDate)) continue;

      final recordLineRaw = m['lineNum'];
      final recordLine = recordLineRaw is int
          ? recordLineRaw
          : int.tryParse(recordLineRaw?.toString() ?? '');
      if (recordLine != lineNum) continue;

      if (_pickString(m, ['classId'], '') != classId) continue;
      if (teacherId.isNotEmpty &&
          _pickString(m, ['teacherId'], '') != teacherId) {
        continue;
      }
      if (subjectId.isNotEmpty && m['subjectId']?.toString() != subjectId) {
        continue;
      }
      if (classroomId.isNotEmpty &&
          m['classroomId']?.toString() != classroomId) {
        continue;
      }

      ids.add(recordId);
    }

    if (!ids.contains(id)) ids.add(id);
    return ids;
  }

  /// 编辑模式下，把某节课从 `(sourceDay, sourceSlot)` 拖到
  /// `(targetDay, targetSlot)`：
  ///   1. 同格直接 no-op；
  ///   2. 乐观更新本地 `_serverCells`；
  ///   3. 调 `courseDelete(oldId)` 删旧课、`courseBatchSave(newRow)` 写一条新课
  ///      （只覆盖当前周这一节，其它周不动）；
  ///   4. 任一步失败回滚本地状态并提示；成功后 `_loadSchedule()` 拿新 id 同步。
  Future<void> _onDropCard(
    _DragPayload payload,
    int targetDay,
    int targetSlot,
  ) async {
    if (payload.sourceDay == targetDay && payload.sourceSlot == targetSlot) {
      return;
    }
    final raw = payload.card.raw;
    if (raw == null) return;
    if (_selectedClassId == null || _selectedClassId!.isEmpty) return;

    final configs = _activeTimeConfigs;
    if (targetSlot < 0 || targetSlot >= configs.length) return;
    final cellsNow = _serverCells;
    final newLineNum = configs[targetSlot].lineNum;
    final newDate = _isoDate(_weekStart.add(Duration(days: targetDay)));

    final backup = _cloneCells(cellsNow);

    setState(() {
      final src = cellsNow[payload.sourceDay][payload.sourceSlot];
      // 优先按 indexInSlot 移除，避免同卡多次拖动时找错；越界再回退到 identical 匹配。
      if (payload.indexInSlot < src.length &&
          identical(src[payload.indexInSlot], payload.card)) {
        src.removeAt(payload.indexInSlot);
      } else {
        src.removeWhere((c) => identical(c, payload.card));
      }
      cellsNow[targetDay][targetSlot].add(payload.card);
    });

    final repo = ref.read(adminRepositoryProvider);
    final oldId = _pickString(raw, ['id'], '');
    var ok = true;
    String? errMsg;

    if (oldId.isNotEmpty) {
      final del = await repo.courseDelete([oldId]);
      if (!del.isSuccess) {
        ok = false;
        errMsg = del.msg;
      }
    }
    if (ok) {
      final classId = _pickString(raw, ['classId'], _selectedClassId ?? '');
      final teacherId = _pickString(raw, ['teacherId'], '');
      final newRow = <String, dynamic>{
        if (classId.isNotEmpty) 'classId': classId,
        if (teacherId.isNotEmpty) 'teacherId': teacherId,
        if (raw['classroomId'] != null) 'classroomId': raw['classroomId'],
        if (raw['subjectId'] != null) 'subjectId': raw['subjectId'],
        if ((raw['color'] ?? '').toString().isNotEmpty) 'color': raw['color'],
        // 日期用 yyyy-MM-dd，和 _onAddCourse 写入的一致。
        'date': newDate,
        'lineNum': newLineNum,
      };
      final save = await repo.courseBatchSave([newRow]);
      if (!save.isSuccess) {
        ok = false;
        errMsg = save.msg;
      }
    }

    if (!mounted) return;
    if (!ok) {
      setState(() => _serverCells = backup);
      AppToast.show(
        context,
        (errMsg == null || errMsg.isEmpty) ? '移动失败，请重试' : errMsg,
      );
      return;
    }
    // 不再立刻 _loadSchedule()：后端 courseDelete 偶有落库延迟，
    // 重新拉回的列表里可能仍带着刚移走的那条记录，导致源格"鬼影"复现。
    // 这里只把本地 raw 同步到新位置，乐观更新已经把卡片从源格搬走，
    // UI 与意图保持一致；下次切周 / 切班时会自然 reload 拿到权威状态。
    raw['date'] = newDate;
    raw['lineNum'] = newLineNum;
    AppToast.show(context, '已移动');
  }

  /// `_serverCells` 三维结构的浅克隆（外两层新建 List，最内层 `_ScheduleCardData`
  /// 是不可变值，直接共享即可），用于拖动失败回滚。
  List<List<List<_ScheduleCardData>>> _cloneCells(
    List<List<List<_ScheduleCardData>>> cells,
  ) {
    return [
      for (final day in cells)
        [
          for (final slot in day) [...slot],
        ],
    ];
  }

  @override
  void initState() {
    super.initState();
    _serverCells = _emptyCells();
    final anchor = scheduleCurrentTeachingWeekAnchor();
    _weekStart = anchor.monday;
    _currentWeek = anchor.week;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 接口要求 classId 必填 → 必须先拉班级列表，拿到第 1 项作为默认班级，
      // 再依次拉左侧时间表（按 classId 维度）+ 课表，保证 lineNum → slotIdx
      // 映射在解析课表前到位。
      await _loadClasses();
      if (!mounted) return;
      if (_classes.isNotEmpty && _selectedClassId == null) {
        setState(() => _selectedClassId = _classes.first.id);
      }
      await _loadTimeConfig();
      if (!mounted) return;
      _loadSchedule();
    });
  }

  // —— 数据加载 ————————————————————————————————————————————————

  /// 取课表左侧时间列表。`schoolTimeConfigList` 接口 `classId` 必填，
  /// 班级未就绪时直接跳过、走 [_kDefaultTimeConfigs] 兜底。
  ///
  /// 后端字段：`timeBegin` / `timeEnd` 是 `HH:MM:SS` 字符串（也兼容
  /// `startTime` / `beginTime` 这些历史字段名），UI 上只显示 `HH:MM`。
  Future<void> _loadTimeConfig() async {
    if (_selectedClassId == null || _selectedClassId!.isEmpty) return;
    final repo = ref.read(schoolRepositoryProvider);
    final resp = await repo.schoolTimeConfigList(classId: _selectedClassId);
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

  /// `HH:MM:SS` / `HH:MM` 都归一化成 `HH:MM`。
  String _trimToHm(String s) {
    if (s.isEmpty) return s;
    final parts = s.split(':');
    if (parts.length < 2) return s;
    return '${parts[0]}:${parts[1]}';
  }

  Future<void> _loadClasses() async {
    setState(() => _classesLoading = true);
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classList();
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() => _classesLoading = false);
      return;
    }
    final list = <({String id, String name})>[];
    for (final m in _extractList(resp)) {
      final id = _pickString(m, ['id', 'classId'], '');
      final name = _pickString(m, ['name', 'className', 'fullName'], '');
      if (id.isNotEmpty && name.isNotEmpty) {
        list.add((id: id, name: name));
      }
    }
    if (!mounted) return;
    setState(() {
      _classes = list;
      _classesLoading = false;
      if (list.isNotEmpty &&
          (_selectedClassId == null ||
              !list.any((c) => c.id == _selectedClassId))) {
        _selectedClassId = list.first.id;
      }
    });
  }

  Future<void> _loadSchedule({
    DateTime? weekStart,
    int? weekNumber,
    String? classId,
  }) async {
    final targetWeekStart = weekStart ?? _requestedWeek?.start ?? _weekStart;
    final targetWeekNumber =
        weekNumber ?? _requestedWeek?.number ?? _currentWeek;
    _requestedWeek = (start: targetWeekStart, number: targetWeekNumber);
    final targetClassId = classId ?? _selectedClassId;
    // classId 必填：班级未就绪时先把网格清空，避免无意义请求。
    if (targetClassId == null || targetClassId.isEmpty) {
      setState(() => _serverCells = _emptyCells());
      return;
    }
    final generation = ++_scheduleLoadGeneration;
    final repo = ref.read(adminRepositoryProvider);
    final start = targetWeekStart;
    final end = start.add(const Duration(days: 6));
    final resp = await repo.courseList(
      classId: targetClassId,
      beginDate: _isoDate(start),
      endDate: _isoDate(end),
    );
    if (!mounted || generation != _scheduleLoadGeneration) return;
    if (!resp.isSuccess) {
      setState(() {
        _weekStart = targetWeekStart;
        _currentWeek = targetWeekNumber;
        _serverCells = _emptyCells();
      });
      return;
    }

    final cells = _emptyCells();
    final configs = _activeTimeConfigs;
    final rows = _extractCourseRows(resp);
    for (final entry in rows) {
      final m = entry.row;
      // 优先用日期分组的 key（API 新格式 data: {"2026-05-11": [...]}），
      // 回退到 row 自身的 date 字段（兼容老的扁平 List 格式）。
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
      // 用 lineNum 在 configs 中查找；非连续 lineNum 也能正确落格。
      var slotIdx = configs.indexWhere((c) => c.lineNum == lineNum);
      if (slotIdx < 0) {
        slotIdx = (lineNum - 1).clamp(0, configs.length - 1);
      }

      cells[dayIdx][slotIdx].add(_parseCourseCard(m));
    }

    if (!mounted || generation != _scheduleLoadGeneration) return;
    setState(() {
      _weekStart = targetWeekStart;
      _currentWeek = targetWeekNumber;
      _serverCells = cells;
    });
  }

  /// `courseList` 的 `data` 既可能是按日期分组的 Map（新格式：
  /// `{"2026-05-11": [{...}, ...], "2026-05-12": [...]}`），也可能是
  /// 扁平 List（老格式）。统一摊平成 `(dateKey, row)` 元组。
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

  /// 课卡堆叠决定行高。
  List<_TimeSlotData> _buildSlots(List<List<List<_ScheduleCardData>>> cells) {
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

  double _calcSlotHeight(
    int slotIdx,
    List<List<List<_ScheduleCardData>>> cells,
  ) {
    var maxHeight = ScheduleIdleSlot.designSlotHeight;
    for (var d = 0; d < cells.length; d++) {
      if (slotIdx < cells[d].length) {
        final height = scheduleCourseCellHeight(
          cells[d][slotIdx].map((card) => card.display),
        );
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

  /// 把 courseList 单条记录翻译成 [_ScheduleCardData]。
  ///
  /// 字段映射对齐后端真实回包：
  /// ```json
  /// {
  ///   "subjectName": "素描",
  ///   "teacherRealname": "李静",
  ///   "teacherNickname": "李老师",
  ///   "className": "联考冲刺1班",
  ///   "classroomName": "艺术楼101",
  ///   "color": "#D2C4FF",
  ///   ...
  /// }
  /// ```
  ///
  /// `color` 是 hex（含 `#`），存到卡片做背景覆盖；标题色按背景亮度自适应。
  _ScheduleCardData _parseCourseCard(Map<String, dynamic> json) {
    return _ScheduleCardData(
      display: buildScheduleCourseCard(
        json,
        subline: ScheduleCardSubline.teacher,
      ),
      raw: Map<String, dynamic>.from(json),
    );
  }

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
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusSchedulePageShell(
      bodyScrollable: false,
      header: SmartCampusPageBanner(
        title: '排课与课表',
        subtitle: '按班级查看与调整周课表',
        onBack: widget.onBack,
      ),
      body: _buildSchedule(ui),
    );
  }

  Widget _buildSchedule(double Function(num) ui) {
    final cells = _normalizeCells(_serverCells);
    final slots = _buildSlots(cells);
    final days = _buildDayHeaders();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(ui(20), ui(0), ui(20), ui(12)),
          child: Row(
            children: [
              _ScheduleClassFilterField(
                options: _classes,
                selectedClassId: _selectedClassId,
                loading: _classesLoading,
                onChanged: (picked) async {
                  if (picked.id == _selectedClassId) return;
                  setState(() => _selectedClassId = picked.id);
                  // 班级一变：先按新班重拉左侧时间表（节次可能不同），
                  // 再按新 configs 拉课表，保证 lineNum 落格正确。
                  await _loadTimeConfig();
                  if (!mounted) return;
                  await _loadSchedule(classId: picked.id);
                },
              ),
              const Spacer(),
              _ViewEditSegment(
                mode: _mode,
                onChanged: (next) => setState(() => _mode = next),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(12)),
          child: AppCard(
            color: AppColors.surfaceSubtle,
            bordered: false,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12,
              vertical: AppSpace.s8,
            ),
            child: _ScheduleControlBar(
              week: _currentWeek,
              weekDateLabel: _fmtDate(_weekStart),
              onPrev: _gotoPrev,
              onCurrent: _gotoCurrent,
              onNext: _gotoNext,
              onPickDate: _pickDate,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(20)),
            child: ScheduleGridShell(
              slots: slots,
              days: days,
              body: _DaysBodyArea(
                mode: _mode,
                slots: slots,
                days: days,
                cells: cells,
                onAddCourse: _onAddCourse,
                onDropCard: _onDropCard,
                onDeleteCourse: _onDeleteCourse,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 班级下拉 + 查看 / 编辑
// =============================================================================

/// 班级下拉（[AppSelect]）。
class _ScheduleClassFilterField extends StatelessWidget {
  const _ScheduleClassFilterField({
    required this.options,
    required this.selectedClassId,
    required this.loading,
    required this.onChanged,
  });

  final List<({String id, String name})> options;
  final String? selectedClassId;
  final bool loading;
  final ValueChanged<({String id, String name})> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasSelected = options.any((o) => o.id == selectedClassId);
    return SizedBox(
      width: 200,
      child: AppSelect<String>(
        enabled: !loading && options.isNotEmpty,
        hint: loading ? '班级加载中' : '选择班级',
        options: [
          for (final o in options) AppSelectOption(value: o.id, label: o.name),
        ],
        value: hasSelected ? selectedClassId : null,
        onChanged: (id) {
          for (final o in options) {
            if (o.id == id) onChanged(o);
          }
        },
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
    return AppSegmented<_ScheduleMode>(
      size: AppControlSize.sm,
      segments: const [
        AppSegment(value: _ScheduleMode.view, label: '查看'),
        AppSegment(value: _ScheduleMode.edit, label: '编辑'),
      ],
      value: mode,
      onChanged: onChanged,
    );
  }
}

// =============================================================================
// 控制条：第 N 周 + 编辑说明 + 周切换 + 选日期
// =============================================================================

class _ScheduleControlBar extends StatelessWidget {
  const _ScheduleControlBar({
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
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
              const SizedBox(height: AppSpace.s4),
              Text(
                '编辑时点空白格排课，长按课卡拖到别的时间，左滑删除',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12,
              ),
            ],
          ),
        ),
        ScheduleGridWeekSwitcher(
          onPrev: onPrev,
          onCurrent: week == kScheduleCurrentTeachingWeek ? null : onCurrent,
          onNext: onNext,
          grouped: false,
        ),
        const SizedBox(width: AppSpace.s8),
        ScheduleGridDateButton(label: weekDateLabel, onTap: onPickDate),
      ],
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
    required this.onAddCourse,
    required this.onDropCard,
    required this.onDeleteCourse,
  });

  final _ScheduleMode mode;
  final List<_TimeSlotData> slots;
  final List<_DayHeaderData> days;
  final List<List<List<_ScheduleCardData>>> cells;
  final void Function(int dayIdx, int slotIdx) onAddCourse;
  final Future<void> Function(
    _DragPayload payload,
    int targetDay,
    int targetSlot,
  )
  onDropCard;
  final Future<void> Function(_ScheduleCardData card) onDeleteCourse;

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
            onAddCourse: onAddCourse,
            onDropCard: onDropCard,
            onDeleteCourse: onDeleteCourse,
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
    required this.onAddCourse,
    required this.onDropCard,
    required this.onDeleteCourse,
  });

  final int slotIdx;
  final String slotEnd;
  final double height;
  final _ScheduleMode mode;
  final List<_DayHeaderData> days;
  final List<List<_ScheduleCardData>> rowCells;
  final void Function(int dayIdx, int slotIdx) onAddCourse;
  final Future<void> Function(
    _DragPayload payload,
    int targetDay,
    int targetSlot,
  )
  onDropCard;
  final Future<void> Function(_ScheduleCardData card) onDeleteCourse;

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
                      dayIdx: i,
                      slotIdx: slotIdx,
                      slotEnd: slotEnd,
                      mode: mode,
                      slotDate: days[i].date,
                      cards: rowCells[i],
                      onAddCourse: () => onAddCourse(i, slotIdx),
                      onDropCard: onDropCard,
                      onDeleteCourse: onDeleteCourse,
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
    required this.dayIdx,
    required this.slotIdx,
    required this.slotEnd,
    required this.mode,
    required this.slotDate,
    required this.cards,
    required this.onAddCourse,
    required this.onDropCard,
    required this.onDeleteCourse,
  });

  final int dayIdx;
  final int slotIdx;
  final String slotEnd;
  final _ScheduleMode mode;
  final DateTime slotDate;
  final List<_ScheduleCardData> cards;
  final VoidCallback onAddCourse;
  final Future<void> Function(
    _DragPayload payload,
    int targetDay,
    int targetSlot,
  )
  onDropCard;
  final Future<void> Function(_ScheduleCardData card) onDeleteCourse;

  @override
  Widget build(BuildContext context) {
    final isEditing = mode == _ScheduleMode.edit;
    // 编辑模式下整个格子都做拖动落点；查看模式不接收拖动。
    if (!isEditing) {
      return _buildBody(context, hovering: false);
    }
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        // 拖回原格不算移动；返回 false 让悬停高亮也不亮起。
        final p = details.data;
        return !(p.sourceDay == dayIdx && p.sourceSlot == slotIdx);
      },
      onAcceptWithDetails: (details) {
        onDropCard(details.data, dayIdx, slotIdx);
      },
      builder: (ctx, candidate, rejected) {
        return _buildBody(ctx, hovering: candidate.isNotEmpty);
      },
    );
  }

  Widget _buildBody(BuildContext context, {required bool hovering}) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEditing = mode == _ScheduleMode.edit;
    final radius = ui(8);
    Widget wrapHover(Widget child) {
      if (!hovering) return child;
      // 拖动悬停时给整个格子叠一层紫色虚框 + 高亮底，提示可放置。
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(8),
                ),
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: _kPurple, width: 1.4),
                ),
              ),
            ),
          ),
          child,
        ],
      );
    }

    if (cards.isEmpty) {
      return wrapHover(
        isEditing
            ? Padding(
                padding: const EdgeInsets.all(kScheduleCourseCellInset),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ScheduleCourseCellAction(
                    label: '排课',
                    onTap: onAddCourse,
                  ),
                ),
              )
            : const ScheduleIdleSlot(),
      );
    }
    final isPast = isScheduleSlotPast(slotDate: slotDate, endHm: slotEnd);
    return wrapHover(
      Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(kScheduleCourseCellInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: kScheduleCourseCardGap),
                _DraggableScheduleCard(
                  card: cards[i],
                  isEditing: isEditing,
                  isPast: isPast,
                  sourceDay: dayIdx,
                  sourceSlot: slotIdx,
                  indexInSlot: i,
                  onDelete: isEditing ? () => onDeleteCourse(cards[i]) : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 编辑模式下课卡可以长按拖动（`LongPressDraggable`）；查看模式是静态的
/// [ScheduleCourseCard]。
class _DraggableScheduleCard extends StatelessWidget {
  const _DraggableScheduleCard({
    required this.card,
    required this.isEditing,
    required this.isPast,
    required this.sourceDay,
    required this.sourceSlot,
    required this.indexInSlot,
    this.onDelete,
  });

  final _ScheduleCardData card;
  final bool isEditing;
  final bool isPast;
  final int sourceDay;
  final int sourceSlot;
  final int indexInSlot;
  final VoidCallback? onDelete;

  bool get _draggable => isEditing && card.raw != null;

  bool get _deletable {
    if (onDelete == null || card.raw == null) return false;
    return _pickString(card.raw!, ['id'], '').isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final deleteHandler = _deletable ? onDelete : null;
    Widget courseCard = ScheduleCourseCard(data: card.display, isPast: isPast);
    if (deleteHandler != null) {
      courseCard = ScheduleCourseSwipeDelete(
        cardHeight: kScheduleCourseCardHeight,
        widthDesign: kScheduleCourseCardWidth,
        onDelete: deleteHandler,
        child: courseCard,
      );
    }

    if (!_draggable) return courseCard;

    final payload = _DragPayload(
      sourceDay: sourceDay,
      sourceSlot: sourceSlot,
      indexInSlot: indexInSlot,
      card: card,
    );
    // LongPressDraggable.feedback 会被渲染到全局 Overlay，脱离当前 widget 树，
    // 必须把 DashboardScaleScope 数据捕获后重新注入，否则内部用 `ui()` 缩放
    // 的子组件会 assert "DashboardScaleScope not found"。
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    return LongPressDraggable<_DragPayload>(
      data: payload,
      delay: const Duration(milliseconds: 220),
      hapticFeedbackOnStart: true,
      feedback: DashboardScaleScope(
        data: scaleData,
        child: SizedBox(
          width: kScheduleCourseCardWidth,
          child: _DragFeedback(card: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.32, child: courseCard),
      child: courseCard,
    );
  }
}

/// 长按拖动跟随手指的浮起卡。`Material` 透明背景仅用来给文字提供 ancestry。
/// 外层必须由调用方再裹一层 [DashboardScaleScope]（feedback 走 Overlay
/// 树，会丢失原祖先环境）。
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.card});

  final _ScheduleCardData card;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ScheduleCourseCard(data: card.display),
      ),
    );
  }
}

// =============================================================================
// 数据模型 - 课表
// =============================================================================

class _ScheduleCardData {
  const _ScheduleCardData({required this.display, this.raw});

  final ScheduleCourseCardData display;
  final Map<String, dynamic>? raw;

  String get location => display.location;
  String get name => display.name;
  String get subline => display.subline;
}

/// 课表拖拽时随手携带的数据。`sourceDay/sourceSlot/indexInSlot` 用于在
/// 乐观更新里精确把卡片从旧格子里挪走。
class _DragPayload {
  const _DragPayload({
    required this.sourceDay,
    required this.sourceSlot,
    required this.indexInSlot,
    required this.card,
  });

  final int sourceDay;
  final int sourceSlot;
  final int indexInSlot;
  final _ScheduleCardData card;
}

typedef _TimeSlotData = ScheduleGridTimeSlot;
typedef _DayHeaderData = ScheduleGridDayHeader;

/// 课表左侧时间配置：API `schoolTimeConfigList` 返回结构 → `_TimeConfig`。
class _TimeConfig {
  const _TimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
    this.label = '',
  });

  /// 节次名称（上午 / 下午 / 晚上）。
  final String label;

  final int lineNum;
  final String start;
  final String end;
}

/// API 拉取失败 / 未返回时的兜底节次配置（5 节）。
const List<_TimeConfig> _kDefaultTimeConfigs = [
  _TimeConfig(lineNum: 1, start: '08:30', end: '11:30', label: '上午'),
  _TimeConfig(lineNum: 2, start: '14:00', end: '17:00', label: '下午'),
  _TimeConfig(lineNum: 3, start: '19:00', end: '21:00', label: '晚上'),
];

// =============================================================================
// 排课编辑右侧抽屉（管理员）：课程时间只读 + 班级 / 教室 / 复用，
// 提交时调 `courseBatchSave`（课程色用色板首色紫色）。
// =============================================================================

class _AdminEditCourseDrawer extends ConsumerStatefulWidget {
  const _AdminEditCourseDrawer({
    required this.slotLabel,
    required this.dateIso,
    required this.lineNum,
    required this.currentWeek,
    required this.onCancel,
    required this.onSubmitted,
    this.initialClassId,
  });

  final String slotLabel;
  final String dateIso;
  final int lineNum;

  /// 父页面当前显示的"教学周第 N 周"。复用为「本学期所有教学周」时，
  /// 用它计算还剩多少周（按 [kScheduleTermTotalWeeks] 总周数兜底 18 周）。
  final int currentWeek;

  final VoidCallback onCancel;
  final VoidCallback onSubmitted;

  /// 父页面正在浏览的班级 id；非空时打开抽屉时直接预选此班级。
  final String? initialClassId;

  @override
  ConsumerState<_AdminEditCourseDrawer> createState() =>
      _AdminEditCourseDrawerState();
}

/// 删除课程时可选的循环范围（与新增排课「是否复用」选项对齐，首项为仅本节）。
const List<String> _kDeleteCourseScopeOptions = <String>[
  '仅删除本节',
  '本学期所有教学周',
  '后续 4 周',
  '后续 8 周',
];

List<DateTime> _computeScheduleReuseDates({
  required DateTime base,
  required String reuseMode,
  required int currentWeek,
}) {
  return scheduleReuseDates(
    base: base,
    reuseMode: reuseMode,
    currentWeek: currentWeek,
  );
}

String _normalizeCourseDateIso(dynamic raw) {
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty) return '';
  final d = DateTime.tryParse(s) ?? DateTime.tryParse(s.split('T').first);
  if (d == null) return '';
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

Future<String?> _showDeleteCourseConfirmDialog(
  BuildContext context, {
  required String courseName,
  required String location,
  required String subline,
}) {
  var selectedScope = _kDeleteCourseScopeOptions.first;
  final detail = subline.isEmpty ? '' : '\n$subline';
  return showScaledDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierColor: AppColors.ink.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: StatefulBuilder(
          builder: (localContext, setLocalState) {
            return Container(
              width: ui(420),
              padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(ui(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '删除课程',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: AppColors.ink,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                  SizedBox(height: ui(12)),
                  Text(
                    '确认删除「$courseName」（$location）？$detail\n'
                    '删除后对应节次课表将清空，操作不可恢复。',
                    style: TextStyle(
                      fontSize: ui(14),
                      height: 1.6,
                      color: AppColors.textSecondary,
                      fontWeight: AppFont.w400,
                    ),
                  ),
                  SizedBox(height: ui(20)),
                  Text(
                    '删除范围',
                    style: TextStyle(
                      fontSize: ui(14),
                      color: _kTextDark,
                      fontWeight: AppFont.w500,
                    ),
                  ),
                  SizedBox(height: ui(12)),
                  PopupSelectorField<String>(
                    value: selectedScope,
                    items: _kDeleteCourseScopeOptions,
                    itemLabel: (s) => s,
                    onChanged: (v) => setLocalState(() => selectedScope = v),
                  ),
                  SizedBox(height: ui(24)),
                  AppDialogActionBar(
                    cancelLabel: '取消',
                    confirmLabel: '删除',
                    onCancel: () => Navigator.of(dialogContext).pop(),
                    onConfirm: () =>
                        Navigator.of(dialogContext).pop(selectedScope),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class _AdminEditCourseDrawerState
    extends ConsumerState<_AdminEditCourseDrawer> {
  // 班级 / 教室 / 教师 / 科目下拉的 cache：(label, id)。下拉用 label 做用户
  // 选择，提交时拿对应 id（雪花 long → String）拼到 courseBatchSave 的 body。
  List<({String id, String name})> _classes = const [];
  List<({String id, String name})> _classrooms = const [];
  List<({String id, String name})> _teachers = const [];
  List<({String id, String name})> _subjects = const [];

  String? _classId;
  String? _classroomId;
  String? _teacherId;

  /// 科目下拉当前选中（来自 `subjectList`）。`subjectId` 在 API 里是 int，
  /// 这里以 String 形式管理，提交时再 `int.tryParse` 转回。
  String? _subjectId;
  bool _loadingSubjects = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOptions();
    });
  }

  Future<void> _loadOptions() async {
    final repo = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repo.classList(),
      repo.classroomList(),
      repo.teacherList(),
    ]);
    if (!mounted) return;
    setState(() {
      _classes = _toOptions(
        results[0],
        idKeys: const ['id', 'classId', 'cId'],
        nameKeys: const ['className', 'class', 'name', 'fullName'],
      );
      _classrooms = _toOptions(
        results[1],
        idKeys: const ['id', 'classroomId', 'roomId'],
        nameKeys: const ['classroomName', 'roomName', 'name'],
      );
      _teachers = _toOptions(
        results[2],
        idKeys: const ['id', 'teacherId', 'userId'],
        nameKeys: const ['realname', 'realName', 'nickname', 'name'],
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
      _classroomId ??= _classrooms.isNotEmpty ? _classrooms.first.id : null;
      _teacherId ??= _teachers.isNotEmpty ? _teachers.first.id : null;
    });
    // 班级 id 就绪后立刻拉对应班级的可选科目。
    _loadSubjects(_classId);
  }

  /// 班级科目下拉拉取：subjectList 接口需要 classId（雪花 String）。
  /// 班级一变就重拉；选中项不在新列表里时回退到第一项。
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
      if (_subjectId == null || !list.any((s) => s.id == _subjectId)) {
        _subjectId = list.isNotEmpty ? list.first.id : null;
      }
      _loadingSubjects = false;
    });
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

  String get _defaultCourseColorHex =>
      scheduleColorToHex(scheduleDefaultPickerColor);

  Future<void> _submit() async {
    if (_submitting) return;
    if (_classId == null || _classroomId == null || _teacherId == null) {
      AppToast.show(context, '请先选择班级 / 教室 / 教师');
      return;
    }
    if (_subjectId == null || _subjectId!.isEmpty) {
      AppToast.show(context, '请先选择科目');
      return;
    }
    setState(() => _submitting = true);

    // 后端要求 classroomId / subjectId 是 int；雪花长 classId / teacherId
    // 走 String。复用模式下按 [_reuse] 选项把基准日期 ±N 周生成多行同节次
    // 同班级的排课，一次性提交给 courseBatchSave。
    final classroomNum = int.tryParse(_classroomId!);
    final subjectNum = int.tryParse(_subjectId!);
    final dates = _computeReuseDates();
    final rows = <Map<String, dynamic>>[
      for (final d in dates)
        <String, dynamic>{
          'classId': _classId,
          'classroomId': classroomNum ?? _classroomId,
          'color': _defaultCourseColorHex,
          'date': _formatIsoDate(d),
          'lineNum': widget.lineNum,
          'subjectId': subjectNum ?? _subjectId,
          'teacherId': _teacherId,
        },
    ];

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.courseBatchSave(rows);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg);
      return;
    }
    if (rows.length > 1) {
      AppToast.show(context, '已写入课表（共 ${rows.length} 周）');
    }
    widget.onSubmitted();
  }

  /// 根据 `_reuse` 选项展开成多个排课日期：
  ///   - 不复用 → 仅基准日 1 行
  ///   - 本学期所有教学周 → 从当前周开始补到第 [kScheduleTermTotalWeeks] 周
  ///   - 后续 4 周 → 基准日 + 4 个连续周（共 5 行）
  ///   - 后续 8 周 → 基准日 + 8 个连续周（共 9 行）
  /// 每个克隆都是基准日 +N×7 天，节次 / 班级 / 教师 / 教室 / 颜色 / 科目
  /// 完全复用。
  List<DateTime> _computeReuseDates() {
    final base = DateTime.tryParse(widget.dateIso) ?? DateTime.now();
    return _computeScheduleReuseDates(
      base: base,
      reuseMode: _reuse,
      currentWeek: widget.currentWeek,
    );
  }

  /// `2026-05-04T00:00:00.000+00:00` 格式（与 `widget.dateIso` 一致），后端
  /// `courseBatchSave` 直接吃这个串。
  String _formatIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(600),
      height: double.infinity,
      child: Container(
        color: AppColors.surface,
        child: Column(
          children: [
            _DrawerHeader(title: '排课', onClose: widget.onCancel),
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
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) {
                        setState(() => _classId = v);
                        // 班级一变科目跟着重拉。
                        _loadSubjects(v);
                      },
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
                      iconAsset: AppAssets.scheduleEditTeacher,
                      label: '教师',
                    ),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _teacherId ?? '',
                      items: [for (final t in _teachers) t.id],
                      itemLabel: (id) {
                        if (id.isEmpty) return '选择教师';
                        return _teachers
                            .firstWhere(
                              (t) => t.id == id,
                              orElse: () => (id: id, name: id),
                            )
                            .name;
                      },
                      onChanged: (v) => setState(() => _teacherId = v),
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
                label: _submitting ? '提交中…' : '提交保存',
                onTap: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      children: [
        SizedBox(
          width: ui(16),
          height: ui(16),
          child: Image.asset(
            iconAsset,
            width: ui(16),
            height: ui(16),
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(width: ui(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
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
            colors: <Color>[AppColors.brandSoft, AppColors.brand],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(16),
              color: AppColors.surface,
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 通用 helpers
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
