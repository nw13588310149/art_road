// =============================================================================
// 宿管端「按宿舍查寝」独立页面
//
// 入口：宿管 dashboard 快捷区「按宿舍查寝」按钮 →
//      controller.openDormCheckByRoom() → mainView == dormCheckByRoom +
//      role == dormManager → SmartCampusPage 路由到本视图。
//      返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高 + 4deg #F9EDFF→white 渐变 + 圆角 16 + 顶部居中
//      "按宿舍查寝" 16/600 + 副标题 12/#B6B5BB 操作说明；左 12 返回 32×32
//      白底 outline #F3F2F3）。
//   2. 顶部当前查寝截止时间 16/500（如 "2026-04-22 23:00前"）。
//      按需求**去掉**了 Figma 右侧 "晨查寝 / 晚查寝" 分段切换。
//   3. 4 张统计卡（100 高，196° 彩色渐变 + 右上 32×32 白底图标）：
//      A. 在册床位 12 — 橙渐变 + 绿色 home icon
//      B. 正常口径 10 — 绿渐变 + 同图标
//      C. 晚归 2     — 红渐变 + 紫色 alert
//      D. 未打卡 1   — 红渐变 + 紫色 alert
//   4. 多张宿舍卡（白底 16 圆角 + 12 padding）：
//      Header：紫色方块 icon + 「宿舍 A-901」14/500 + 「女生公寓A座·6层」
//             12/400 + 「N人·晚查寝·22:30前」12/#B6B5BB +
//             右侧 220×40「一键打卡」按钮（紫渐变 #B68EFF→#8640FF 或置灰
//             #CECED1）。
//      Body：3 列学生格子（#F5F6FA 12 圆角，padding 12）：40×40 头像 +
//            姓名 14/500 + 学号 12/#B6B5BB + 右侧状态 dropdown
//            (已打卡 / 未打卡 / 晚归 / 请假免检)。
//   5. 底部 3 列查寝历史卡（width 312，padding 12，207° #FAF0FF→white
//      渐变，圆角 16）：
//      · Barlow 18/600「晨查寝 / 晚查寝」+ 状态徽章
//        （正常 #A773FF / 未打卡 #FF323C / 迟到 #325BFF）
//      · 「女生宿舍3号楼 612」13/#6D6B75 + 日期 12/#B6B5BB
//      · 灰底块 50 高：规定时间 / 打卡时间 两列居中
//      · 底部 "备注：…" 12/#B6B5BB。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/dormitory_check_data.dart';
import '../state/dormitory_manager_controller.dart';
import '../../school/data/school_config_data.dart';
import '../../school/state/school_config_controller.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderLine = Color(0xFFCECED1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoftBg = Color(0xFFE7D9FF);

// =============================================================================
// 顶级视图
// =============================================================================

class DormManagerCheckByRoomView extends ConsumerStatefulWidget {
  const DormManagerCheckByRoomView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<DormManagerCheckByRoomView> createState() =>
      _DormManagerCheckByRoomViewState();
}

class _DormManagerCheckByRoomViewState
    extends ConsumerState<DormManagerCheckByRoomView> {
  final _checkDate = dormitoryCheckDateParam();

  DormitoryBuildingOption _selectedBuilding = DormitoryBuildingOption.all;
  DormitoryFloorOption _selectedFloor = DormitoryFloorOption.all;

  String _deadlineText(
    List<DormitoryRoomCheck> rooms,
    SchoolDormitoryCheckConfig checkConfig,
  ) {
    for (final room in rooms) {
      final deadline = _roomDeadline(room, checkConfig);
      if (deadline.isNotEmpty && deadline != '—') {
        return '$_checkDate $deadline';
      }
    }
    if (checkConfig.eveningDeadline.isNotEmpty) {
      return '$_checkDate ${checkConfig.eveningDeadline}';
    }
    return '$_checkDate 查寝';
  }

  String _roomDeadline(
    DormitoryRoomCheck room,
    SchoolDormitoryCheckConfig checkConfig,
  ) {
    return resolveDormitoryRequiredDeadline(
      recordDeadline: room.deadline,
      checkType: room.session,
      config: checkConfig,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

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
        .loadRoomChecks(
          buildingId: buildingId,
          floorId: floorId,
          date: _checkDate,
        );
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

  Future<void> _checkInAll(DormitoryRoomCheck room) async {
    final resp = await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .checkInRoom(
          room: room,
          date: _checkDate,
          buildingId: _selectedBuilding.id.isEmpty
              ? null
              : _selectedBuilding.id,
          floorId: _selectedFloor.id.isEmpty ? null : _selectedFloor.id,
        );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg);
      return;
    }
    AppToast.show(context, '${room.roomName} 已一键打卡');
  }

  Future<void> _updateStudentStatus(
    DormitoryRoomStudent student,
    DormitoryStudentCheckStatus next,
  ) async {
    final resp = await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .updateStudentCheckStatus(
          student: student,
          status: next,
          date: _checkDate,
          buildingId: _selectedBuilding.id.isEmpty
              ? null
              : _selectedBuilding.id,
          floorId: _selectedFloor.id.isEmpty ? null : _selectedFloor.id,
        );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg);
      return;
    }
    AppToast.show(context, '已经修改');
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = ref.watch(dormitoryManagerControllerProvider);
    final checkConfig =
        ref.watch(schoolDormitoryCheckConfigProvider).valueOrNull ??
        SchoolDormitoryCheckConfig.empty;
    final stat = state.roomCheckStat;
    final rooms = state.roomChecks;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(16)),
            _FilterRow(
              buildingOptions: state.managedBuildings,
              floorOptions: state.floorOptions,
              selectedBuilding: _selectedBuilding,
              selectedFloor: _selectedFloor,
              floorEnabled:
                  _selectedBuilding.id.isNotEmpty && !state.loadingFloors,
              onBuildingChanged: (v) => unawaited(_onBuildingChanged(v)),
              onFloorChanged: (v) => unawaited(_onFloorChanged(v)),
            ),
            SizedBox(height: ui(12)),
            Padding(
              padding: EdgeInsets.only(left: ui(4)),
              child: Text(
                _deadlineText(rooms, checkConfig),
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(height: ui(16)),
            _StatsRow(
              beds: stat.bedCount,
              normal: stat.normalCount,
              lateReturn: stat.lateCount,
              absent: stat.notCheckedCount,
            ),
            SizedBox(height: ui(16)),
            if (state.roomCheckError.isNotEmpty)
              _LoadErrorHint(message: state.roomCheckError, onRetry: _reloadAll)
            else if (rooms.isEmpty)
              _EmptyRoomsHint()
            else
              for (var i = 0; i < rooms.length; i++) ...[
                if (i > 0) SizedBox(height: ui(16)),
                _RoomCard(
                  room: rooms[i],
                  deadlineLabel: _roomDeadline(rooms[i], checkConfig),
                  onCheckInAll:
                      rooms[i].allChecked ||
                          state.submittingRoomIds.contains(rooms[i].roomId)
                      ? null
                      : () => unawaited(_checkInAll(rooms[i])),
                  onChangeStatus: (student, next) =>
                      unawaited(_updateStudentStatus(student, next)),
                ),
              ],
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
  const _Banner({required this.onBack});

  final VoidCallback onBack;

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
                    '按宿舍查寝',
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

/// 与管理员「教师管理」[_ClassFilterField] 一致的下拉触发器样式。
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
                size: ui(22),
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
        borderRadius: BorderRadius.circular(ui(12)),
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

class _EmptyRoomsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(32)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Center(
        child: Text(
          '暂无查寝数据',
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 4 张统计卡
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
            label: '在册床位',
            value: beds,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.dormCheckStatCard2,
            label: '正常口径',
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
// 单个宿舍卡：header（房号 + 一键打卡）+ 学生格子网格
// =============================================================================

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.deadlineLabel,
    required this.onCheckInAll,
    required this.onChangeStatus,
  });

  final DormitoryRoomCheck room;
  final String deadlineLabel;
  final VoidCallback? onCheckInAll;
  final void Function(
    DormitoryRoomStudent student,
    DormitoryStudentCheckStatus next,
  )
  onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoomHeader(
            room: room,
            deadlineLabel: deadlineLabel,
            onCheckInAll: onCheckInAll,
          ),
          SizedBox(height: ui(12)),
          _RoomStudentGrid(
            students: room.students,
            onChangeStatus: onChangeStatus,
          ),
        ],
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({
    required this.room,
    required this.deadlineLabel,
    required this.onCheckInAll,
  });

  final DormitoryRoomCheck room;
  final String deadlineLabel;

  /// 为 `null` 时按钮置灰（已完成全员打卡时）。
  final VoidCallback? onCheckInAll;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(65),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      decoration: BoxDecoration(
        color: _kCardGreyBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 紫色方块 icon（用 home icon 表示宿舍）。
          Container(
            width: ui(36),
            height: ui(36),
            decoration: BoxDecoration(
              color: _kPurpleSoftBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.home_rounded, size: ui(22), color: _kPurple),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      room.roomName,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(width: ui(12)),
                    Text(
                      room.buildingDesc,
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
                SizedBox(height: ui(4)),
                Text(
                  '${room.students.length}人·${room.session}·$deadlineLabel',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
          _CheckInAllButton(onTap: onCheckInAll),
        ],
      ),
    );
  }
}

class _CheckInAllButton extends StatelessWidget {
  const _CheckInAllButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(220),
        height: ui(40),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                ),
          color: disabled ? _kBorderLine : null,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fact_check_outlined, size: ui(18), color: Colors.white),
            SizedBox(width: ui(6)),
            Text(
              '一键打卡',
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 学生格子网格（固定 3 列）。
///
/// 宿舍卡 padding 12 → 内宽 970 − 24 = 946；3 列 + 2 * 10 gap →
/// 每格 (946 − 20) / 3 ≈ 308.6，与 Figma 308 一致，所以这里直接写 308。
class _RoomStudentGrid extends StatelessWidget {
  const _RoomStudentGrid({
    required this.students,
    required this.onChangeStatus,
  });

  final List<DormitoryRoomStudent> students;
  final void Function(
    DormitoryRoomStudent student,
    DormitoryStudentCheckStatus next,
  )
  onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Wrap(
      spacing: ui(10),
      runSpacing: ui(10),
      children: [
        for (final s in students)
          SizedBox(
            width: ui(308),
            child: _RoomStudentTile(
              student: s,
              onChangeStatus: (n) => onChangeStatus(s, n),
            ),
          ),
      ],
    );
  }
}

class _RoomStudentTile extends StatelessWidget {
  const _RoomStudentTile({required this.student, required this.onChangeStatus});

  final DormitoryRoomStudent student;
  final ValueChanged<DormitoryStudentCheckStatus> onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardGreyBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(name: student.name, url: student.avatarUrl),
          SizedBox(width: ui(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  '${student.studentNo} · ${student.bedName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          _StatusDropdown(current: student.status, onChange: onChangeStatus),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.url});

  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = name.isEmpty ? '·' : name.characters.first;
    return Container(
      width: ui(40),
      height: ui(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        image: url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: url.isNotEmpty
          ? null
          : Text(
              initial,
              style: TextStyle(
                fontSize: ui(16),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.0,
              ),
            ),
    );
  }
}

/// 学生状态触发器（36 高紫边胶囊，匹配 Figma）。点击后弹出**全局通用**的
/// [PopupSelectorPanel] 样式弹层（白底 12 圆角 + 多层柔和阴影 + 紫色高亮 +
/// check icon），与请假申请 / 申请小课等表单的下拉视觉保持一致。
///
/// 触发器宽度自适应文案，弹层宽度固定为 120（保证「请假免检」4 字 + check
/// icon 不被裁切）。
class _StatusDropdown extends StatefulWidget {
  const _StatusDropdown({required this.current, required this.onChange});

  final DormitoryStudentCheckStatus current;
  final ValueChanged<DormitoryStudentCheckStatus> onChange;

  @override
  State<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<_StatusDropdown> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    final ctx = _fieldKey.currentContext;
    if (ctx == null) return;
    final ui = DashboardScaleScope.of(context).ui;
    setState(() => _open = true);
    final selected = await showAppPopupSelector<DormitoryStudentCheckStatus>(
      anchorContext: ctx,
      items: DormitoryStudentCheckStatus.values,
      value: widget.current,
      itemLabel: (s) => s.apiValue,
      width: ui(120),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null && selected != widget.current) {
      widget.onChange(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      key: _fieldKey,
      borderRadius: BorderRadius.circular(ui(8)),
      onTap: _openMenu,
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderLine, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.current.apiValue,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
            SizedBox(width: ui(4)),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(22),
                color: _kTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
