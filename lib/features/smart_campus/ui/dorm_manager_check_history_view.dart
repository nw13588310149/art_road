// =============================================================================
// 宿管端「查寝历史」独立页面
//
// 入口：宿管 dashboard 快捷区「查寝历史」按钮 → controller.openDormHistory()
//      → mainView == dormHistory + role == dormManager → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 设计原则：与「按宿舍查寝」(`dorm_manager_check_by_room_view.dart`) 保持
// 视觉语言的一致性，但因为本页是审计场景、单日动辄 50+ 条记录，所以
// **正文区采用表格列表**而非卡片网格 —— 让宿管在一屏内能扫到尽可能多的
// 记录。共用语言：
//   - banner 白→#F9EDFF 渐变 + 居中标题 + 副标题
//   - 14 天日历条（白底 16 圆角 + 灰底 8 圆角 cells，今日紫底白字）
//   - 4 张 100 高彩色渐变统计卡（橙 / 绿 / 红 / 紫 + 右上 32×32 白底图标）
//   - 状态徽章配色：正常 #A773FF / 请假免检 #1CD097 / 迟到 #325BFF /
//     未打卡 #FF323C
//
// 表格区列：学生 | 宿舍/床位 | 状态 | 查寝日期 | 打卡时间 | 操作
//
// 页面结构（自上而下）：
//   banner → 4 张统计卡 → 14 天日期条 → 宿舍楼/楼层筛选 → 表格列表
//
// 在 by-room 视图基础之上额外补充的「历史能力」：
//   1. 日期切换 → 即时刷新统计卡 + 列表
//   2. 日内晨/晚两轮**混在同一列表**里通过「场次」列区分（用户反馈不再做
//      tab 切换，直接横铺更高效）
//   3. 当日无记录时显示空状态卡片
//
// 数据流：按日期、宿舍楼和楼层调用 dormitoryCheckHistory + dormitoryCheckStat。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/dormitory_check_data.dart';
import '../data/student_dormitory_data.dart' show DormitoryDetailStudentProfile;
import '../services/dormitory_export_saver.dart';
import '../state/dormitory_manager_controller.dart';
import '../../school/data/school_config_data.dart';
import '../../school/state/school_config_controller.dart';
import 'widgets/dormitory_detail_dialog.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextDarker = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextMuted = Color(0xFF71717A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kCalendarHint = Color(0xFFE6E9F1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSolid = Color(0xFFA773FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kBlue = Color(0xFF325BFF);
const Color _kGreen = Color(0xFF1CD097);

// —— 历史卡状态徽章（与 by-room 视图底部完全一致）—————————————————
enum _HistoryStatus {
  normal('正常', _kPurpleSolid),
  absent('未打卡', _kRed),
  missing('缺勤', _kRed),
  late_('晚归', _kBlue);

  const _HistoryStatus(this.label, this.bg);
  final String label;
  final Color bg;

  static _HistoryStatus fromLabel(String label) {
    return switch (label) {
      '正常' || '已打卡' => _HistoryStatus.normal,
      '晚归' => _HistoryStatus.late_,
      '缺勤' => _HistoryStatus.missing,
      '未打卡' => _HistoryStatus.absent,
      _ => fromCheckStatus(DormitoryStudentCheckStatus.fromApi(label)),
    };
  }

  static _HistoryStatus fromCheckStatus(DormitoryStudentCheckStatus status) {
    return switch (status) {
      DormitoryStudentCheckStatus.normal => _HistoryStatus.normal,
      DormitoryStudentCheckStatus.lateReturn => _HistoryStatus.late_,
      DormitoryStudentCheckStatus.absent => _HistoryStatus.missing,
      DormitoryStudentCheckStatus.unchecked => _HistoryStatus.absent,
    };
  }
}

class _CalendarDay {
  const _CalendarDay({
    required this.date,
    required this.weekdayLabel,
    required this.dayLabel,
  });

  final DateTime date;
  final String weekdayLabel; // 一 / 二 / 今 等
  final String dayLabel; // 02 / 17 等

  String get isoDate {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

// =============================================================================
// 顶级视图
// =============================================================================

class DormManagerCheckHistoryView extends ConsumerStatefulWidget {
  const DormManagerCheckHistoryView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<DormManagerCheckHistoryView> createState() =>
      _DormManagerCheckHistoryViewState();
}

class _DormManagerCheckHistoryViewState
    extends ConsumerState<DormManagerCheckHistoryView> {
  late List<_CalendarDay> _days;
  late int _selectedDayIndex;

  DormitoryBuildingOption _selectedBuilding = DormitoryBuildingOption.all;
  DormitoryFloorOption _selectedFloor = DormitoryFloorOption.all;

  @override
  void initState() {
    super.initState();
    _days = _buildDays(DateTime.now());
    _selectedDayIndex = 6;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  String get _selectedDateText => _days[_selectedDayIndex].isoDate;

  Future<void> _bootstrap() async {
    await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .loadManagedBuildings();
    await _reloadAll();
  }

  Future<void> _loadFloors(String buildingId) async {
    await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .loadFloors(buildingId);
  }

  Future<void> _reloadAll() async {
    final buildingId = _selectedBuilding.id.isEmpty
        ? null
        : _selectedBuilding.id;
    final floorId = _selectedFloor.id.isEmpty ? null : _selectedFloor.id;
    await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .loadHistory(
          buildingId: buildingId,
          floorId: floorId,
          date: _selectedDateText,
        );
  }

  Future<void> _exportHistory() async {
    final buildingId = _selectedBuilding.id.isEmpty
        ? null
        : _selectedBuilding.id;
    final floorId = _selectedFloor.id.isEmpty ? null : _selectedFloor.id;
    final bytes = await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .exportHistory(
          buildingId: buildingId,
          floorId: floorId,
          date: _selectedDateText,
        );
    if (!mounted) return;
    if (bytes == null) {
      AppToast.show(context, '导出失败，请稍后重试');
      return;
    }
    if (bytes.isEmpty) {
      AppToast.show(context, '当前筛选条件下暂无可导出的查寝记录');
      return;
    }
    final result = await saveDormitoryExport(
      bytes: bytes,
      suggestedName: '查寝记录_$_selectedDateText.xlsx',
    );
    if (!mounted || result.cancelled) return;
    if (result.ok) {
      AppToast.show(context, '查寝记录已导出');
    } else {
      AppToast.show(context, result.error ?? '保存失败');
    }
  }

  Future<void> _showCheckDetail(DormitoryCheckHistoryItem item) async {
    if (item.id.isEmpty) return;
    final apiFields = await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .loadCheckDetail(item.id);
    if (!mounted) return;
    final checkConfig =
        ref.read(schoolDormitoryCheckConfigProvider).valueOrNull ??
        SchoolDormitoryCheckConfig.empty;
    var fields = apiFields.isEmpty
        ? buildDormitoryCheckDetailFieldsFromHistoryItem(item)
        : mergeDormitoryCheckDetailFields(fields: apiFields, item: item);
    fields = enrichDormitoryDetailRequiredTime(
      fields: fields,
      checkType: item.checkType,
      recordDeadline: item.deadline,
      config: checkConfig,
    );
    if (fields.isEmpty) {
      AppToast.show(context, '未获取到查寝详情');
      return;
    }
    await showDormitoryDetailDialog(
      context,
      title: '${item.studentName} · 查寝详情',
      fields: fields,
      studentProfile: DormitoryDetailStudentProfile(
        name: item.studentName,
        avatarUrl: item.avatarUrl,
        subtitle: item.studentSubtitle,
      ),
    );
  }

  Future<void> _handleException(DormitoryCheckHistoryItem item) async {
    final remark = await showDialog<String>(
      context: context,
      builder: (ctx) => _ExceptionHandleDialog(studentName: item.studentName),
    );
    if (!mounted || remark == null) return;
    final response = await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .handleException(item: item, handleStatus: 1, remark: remark);
    if (!mounted) return;
    AppToast.show(context, response.isSuccess ? '异常已处理' : response.displayMsg);
  }

  Future<void> _onBuildingChanged(DormitoryBuildingOption option) async {
    setState(() {
      _selectedBuilding = option;
      _selectedFloor = DormitoryFloorOption.all;
    });
    await _loadFloors(option.id);
    await _reloadAll();
  }

  Future<void> _onFloorChanged(DormitoryFloorOption option) async {
    setState(() => _selectedFloor = option);
    await _reloadAll();
  }

  void _onTapDay(int index) {
    setState(() => _selectedDayIndex = index);
    unawaited(_reloadAll());
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final managerState = ref.watch(dormitoryManagerControllerProvider);
    final stat = managerState.historyStat;
    final historyItems = managerState.historyItems;
    final loadError = managerState.error;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(
              onBack: widget.onBack,
              onExport: managerState.exporting ? null : _exportHistory,
            ),
            SizedBox(height: ui(16)),
            _StatsRow(
              beds: stat.bedCount,
              normal: stat.normalCount,
              lateReturn: stat.lateCount,
              absent: stat.notCheckedCount,
            ),
            SizedBox(height: ui(16)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateStripCard(
                  days: _days,
                  selectedIndex: _selectedDayIndex,
                  dateText: _selectedDateText,
                  statText: '共 ${historyItems.length} 条',
                  onTapDay: _onTapDay,
                ),
                SizedBox(height: ui(16)),
                _FilterRow(
                  buildingOptions: managerState.managedBuildings,
                  floorOptions: managerState.floorOptions,
                  selectedBuilding: _selectedBuilding,
                  selectedFloor: _selectedFloor,
                  floorEnabled:
                      _selectedBuilding.id.isNotEmpty &&
                      !managerState.loadingFloors,
                  onBuildingChanged: (v) => unawaited(_onBuildingChanged(v)),
                  onFloorChanged: (v) => unawaited(_onFloorChanged(v)),
                ),
                SizedBox(height: ui(16)),
                if (loadError.isNotEmpty)
                  _LoadErrorHint(message: loadError, onRetry: _reloadAll)
                else if (historyItems.isEmpty)
                  const _EmptyState()
                else
                  _HistoryTable(
                    items: historyItems,
                    onHandleException: _handleException,
                    onTapDetail: (item) => unawaited(_showCheckDetail(item)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner
// =============================================================================

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack, this.onExport});

  final VoidCallback onBack;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        image: DecorationImage(
          image: AssetImage(AppAssets.xiaoquanHeaderBg),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                width: ui(32),
                height: ui(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(56)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '查寝历史',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onExport != null)
            Positioned(
              right: ui(12),
              top: 0,
              bottom: 0,
              child: Center(
                child: InkWell(
                  onTap: onExport,
                  borderRadius: BorderRadius.circular(ui(8)),
                  child: Container(
                    height: ui(32),
                    padding: EdgeInsets.symmetric(horizontal: ui(12)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(8)),
                      border: Border.all(color: _kBorderSoft),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '导出',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kPurple,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                      ),
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

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.buildingOptions,
    required this.floorOptions,
    required this.selectedBuilding,
    required this.selectedFloor,
    required this.floorEnabled,
    required this.onBuildingChanged,
    required this.onFloorChanged,
  });

  final List<DormitoryBuildingOption> buildingOptions;
  final List<DormitoryFloorOption> floorOptions;
  final DormitoryBuildingOption selectedBuilding;
  final DormitoryFloorOption selectedFloor;
  final bool floorEnabled;
  final ValueChanged<DormitoryBuildingOption> onBuildingChanged;
  final ValueChanged<DormitoryFloorOption> onFloorChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        _DormitorySelectField<DormitoryBuildingOption>(
          value: selectedBuilding,
          items: buildingOptions,
          itemLabel: (o) => o.label,
          width: ui(220),
          menuWidth: ui(280),
          onChanged: onBuildingChanged,
        ),
        SizedBox(width: ui(12)),
        _DormitorySelectField<DormitoryFloorOption>(
          value: selectedFloor,
          items: floorOptions,
          itemLabel: (o) => o.label,
          width: ui(220),
          menuWidth: ui(280),
          enabled: floorEnabled,
          onChanged: onFloorChanged,
        ),
      ],
    );
  }
}

class _DormitorySelectField<T> extends StatefulWidget {
  const _DormitorySelectField({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.width,
    required this.menuWidth,
    required this.onChanged,
    this.enabled = true,
  });

  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final double width;
  final double menuWidth;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  State<_DormitorySelectField<T>> createState() =>
      _DormitorySelectFieldState<T>();
}

class _DormitorySelectFieldState<T> extends State<_DormitorySelectField<T>> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    if (!widget.enabled) return;
    final fieldCtx = _fieldKey.currentContext;
    if (fieldCtx == null) return;
    setState(() => _open = true);
    final selected = await showAppPopupSelector<T>(
      anchorContext: fieldCtx,
      items: widget.items,
      value: widget.value,
      itemLabel: widget.itemLabel,
      width: widget.menuWidth,
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      key: _fieldKey,
      onTap: _openMenu,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: widget.width,
        height: ui(44),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.itemLabel(widget.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.2,
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(18),
                color: const Color(0xFFC6C6C6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorHint extends StatelessWidget {
  const _LoadErrorHint({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(32), horizontal: ui(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(12)),
          InkWell(
            onTap: () => unawaited(onRetry()),
            child: Text(
              '重试',
              style: TextStyle(
                fontSize: ui(13),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 14 天日期条
// =============================================================================

class _DateStripCard extends StatelessWidget {
  const _DateStripCard({
    required this.days,
    required this.selectedIndex,
    required this.dateText,
    required this.statText,
    required this.onTapDay,
  });

  final List<_CalendarDay> days;
  final int selectedIndex;
  final String dateText;
  final String statText;
  final ValueChanged<int> onTapDay;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dateText,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
              SizedBox(width: ui(6)),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(16),
                color: _kTextDarker,
              ),
              const Spacer(),
              Text(
                statText,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(14)),
          LayoutBuilder(
            builder: (context, c) {
              const cellCount = 14;
              final gap = ui(6);
              final totalGap = gap * (cellCount - 1);
              final cellW = (c.maxWidth - totalGap) / cellCount;
              return Row(
                children: List.generate(cellCount, (i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == cellCount - 1 ? 0 : gap,
                    ),
                    child: SizedBox(
                      width: cellW,
                      child: _CalendarCell(
                        day: days[i],
                        selected: i == selectedIndex,
                        onTap: () => onTapDay(i),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final _CalendarDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = selected ? _kPurple : _kCardGreyBg;
    final weekdayColor = selected ? _kCalendarHint : _kTextHint;
    final dayColor = selected ? Colors.white : _kTextDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(59),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.weekdayLabel,
              style: TextStyle(
                fontSize: ui(12),
                color: weekdayColor,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(7)),
            Text(
              day.dayLabel,
              style: TextStyle(
                fontSize: ui(16),
                color: dayColor,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 4 张统计卡（沿用 by-room 视图的彩色渐变 + 右上图标容器风格）
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.beds,
    required this.normal,
    required this.lateReturn,
    required this.absent,
  });

  final int beds;
  final int normal;
  final int lateReturn;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.dormCheckStatCard1,
            label: '记录总数',
            value: beds,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.dormCheckStatCard2,
            label: '正常',
            value: normal,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.dormCheckStatCard3,
            label: '晚归',
            value: lateReturn,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.dormCheckStatCard4,
            label: '未打卡',
            value: absent,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 历史记录表格：学生 | 宿舍/床位 | 状态 | 查寝日期 | 打卡时间 | 操作
// =============================================================================

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({
    required this.items,
    required this.onHandleException,
    required this.onTapDetail,
  });

  final List<DormitoryCheckHistoryItem> items;
  final ValueChanged<DormitoryCheckHistoryItem> onHandleException;
  final ValueChanged<DormitoryCheckHistoryItem> onTapDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: ui(40),
            padding: EdgeInsets.symmetric(horizontal: ui(16)),
            decoration: const BoxDecoration(color: _kCardGreyBg),
            child: Row(
              children: [
                Expanded(flex: 22, child: const _HeaderText('学生')),
                Expanded(flex: 28, child: const _HeaderText('宿舍 / 床位')),
                Expanded(flex: 12, child: const _HeaderText('状态')),
                Expanded(flex: 16, child: const _HeaderText('查寝日期')),
                Expanded(flex: 14, child: const _HeaderText('打卡时间')),
                Expanded(
                  flex: 14,
                  child: const _HeaderText(
                    '操作',
                    alignment: Alignment.centerRight,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0)
              const Divider(height: 1, thickness: 1, color: _kBorderSoft),
            _HistoryTableRow(
              item: items[i],
              zebra: i.isOdd,
              onHandleException: onHandleException,
              onTapDetail: onTapDetail,
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTableRow extends StatelessWidget {
  const _HistoryTableRow({
    required this.item,
    required this.zebra,
    required this.onHandleException,
    required this.onTapDetail,
  });

  final DormitoryCheckHistoryItem item;
  final bool zebra;
  final ValueChanged<DormitoryCheckHistoryItem> onHandleException;
  final ValueChanged<DormitoryCheckHistoryItem> onTapDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final status = _HistoryStatus.fromLabel(item.statusLabel);
    final badgeText = item.statusLabel.isNotEmpty
        ? item.statusLabel
        : status.label;
    return Material(
      color: zebra ? const Color(0xFFFAFAFC) : Colors.white,
      child: InkWell(
        onTap: item.id.isEmpty ? null : () => onTapDetail(item),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 22,
                child: Row(
                  children: [
                    _StudentAvatar(
                      name: item.studentName,
                      url: item.avatarUrl,
                    ),
                    SizedBox(width: ui(8)),
                    Expanded(
                      child: _TwoLineCell(
                        primary: item.studentName,
                        secondary: item.studentSubtitle.isNotEmpty
                            ? item.studentSubtitle
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 28,
                child: _TwoLineCell(
                  primary: item.dormName.isEmpty ? '—' : item.dormName,
                  secondary: item.bedName.isNotEmpty ? item.bedLabel : null,
                ),
              ),
              Expanded(
                flex: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusBadge(text: badgeText, bg: status.bg),
                ),
              ),
              Expanded(
                flex: 16,
                child: Text(
                  item.checkDate.isEmpty ? '—' : item.checkDate,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  item.checkTime.isEmpty ? '—' : item.checkTime,
                  style: TextStyle(
                    fontSize: ui(12),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                    color: item.status == DormitoryStudentCheckStatus.lateReturn
                        ? _kRed
                        : _kTextDark,
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: _RowActions(
                  item: item,
                  onHandleException: onHandleException,
                  onTapDetail: onTapDetail,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.primary, this.secondary});

  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        if (secondary != null && secondary!.isNotEmpty) ...[
          SizedBox(height: ui(2)),
          Text(
            secondary!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({required this.name, required this.url});

  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final size = ui(36);
    final radius = ui(8);
    final initial = name.isEmpty ? '·' : name.characters.first;

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE7D9FF),
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: ui(12),
            color: _kPurple,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      );
    }

    if (url.isEmpty) return fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.bg});

  final String text;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(12),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1,
        ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.item,
    required this.onHandleException,
    required this.onTapDetail,
  });

  final DormitoryCheckHistoryItem item;
  final ValueChanged<DormitoryCheckHistoryItem> onHandleException;
  final ValueChanged<DormitoryCheckHistoryItem> onTapDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget action;
    if (item.needsExceptionHandle) {
      action = TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: () => onHandleException(item),
        child: Text(
          '处理',
          style: TextStyle(
            fontSize: ui(12),
            color: _kPurple,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      );
    } else if (item.handleStatus > 0) {
      action = Text(
        '已处理',
        style: TextStyle(
          fontSize: ui(12),
          color: _kGreen,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1,
        ),
      );
    } else {
      action = TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: item.id.isEmpty ? null : () => onTapDetail(item),
        child: Text(
          '详情',
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: action,
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {this.alignment = Alignment.centerLeft});

  final String text;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Align(
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(12),
          color: _kTextMuted,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1,
        ),
      ),
    );
  }
}

class _ExceptionHandleDialog extends StatefulWidget {
  const _ExceptionHandleDialog({required this.studentName});

  final String studentName;

  @override
  State<_ExceptionHandleDialog> createState() => _ExceptionHandleDialogState();
}

class _ExceptionHandleDialogState extends State<_ExceptionHandleDialog> {
  final _remarkCtrl = TextEditingController();

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('异常处理 · ${widget.studentName}'),
      content: TextField(
        controller: _remarkCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: '填写处理说明',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_remarkCtrl.text.trim()),
          child: const Text('确认处理'),
        ),
      ],
    );
  }
}

// =============================================================================
// 空状态（当日 + 当前 session 无记录）
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(48)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '当日暂无查寝记录',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 14 天日历构建
// =============================================================================

List<_CalendarDay> _buildDays(DateTime today) {
  // 沿用 teacher 端布局：今日固定在 index 6，前 6 天 + 今 + 后 7 天，共 14 天。
  const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
  return List<_CalendarDay>.generate(14, (i) {
    final d = today.add(Duration(days: i - 6));
    final isToday = i == 6;
    final wd = (d.weekday - 1) % 7;
    return _CalendarDay(
      date: d,
      weekdayLabel: isToday ? '今' : weekdayLabels[wd],
      dayLabel: d.day.toString().padLeft(2, '0'),
    );
  });
}
