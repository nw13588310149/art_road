// =============================================================================
// 宿管端「按宿舍查寝」独立页面
//
// 入口：宿管 dashboard 快捷区「按宿舍查寝」按钮 →
//      controller.openDormCheckByRoom() → mainView == dormCheckByRoom +
//      role == dormManager → SmartCampusPage 路由到本视图。
//      返回：banner 左上角返回按钮 → onBack。
//
// 视觉（原版 970 设计宽，数值照原版同路径文件）：
//   1. 横幅：共享 [SmartCampusPageBanner]，只有居中标题「按宿舍查寝」。
//   2. 筛选行：楼栋 / 楼层两个 220×44 下拉（共享 [SmartCampusFilterDropdown]）。
//   3. 当前批次与截止时间 16/500（如「晚查寝 · 22:30 截止」）。
//   4. 4 张插图统计卡（共享 [SmartCampusStatCard]）：在册床位 / 已归寝 /
//      晚归 / 未打卡。
//   5. 多张宿舍卡（白底 16 圆角 + 12 padding）：
//      Header：65 高灰底条，36 紫色方块 icon + 房号 14/500 + 楼栋楼层 12/400 +
//             「N人·晚查寝·22:30前」12/#B6B5BB + 右侧 220×40 渐变按钮
//             「全员到寝」（全部打卡后置灰 #CECED1）。点击先弹确认。
//      Body：学生格子（#F5F6FA 12 圆角，padding 12）：40×40 方头像 +
//            姓名 14/500 + 学号·床位 12/#B6B5BB + 右侧 36 高状态下拉
//            (已打卡 / 未打卡 / 晚归 / 请假免检)。宽屏 3 列，窄横屏 2 列。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../school/data/school_config_data.dart';
import '../../school/state/school_config_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/dormitory_check_data.dart';
import '../state/dormitory_manager_controller.dart';
import 'widgets/smart_campus_filter_bar.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_square_avatar.dart';
import 'widgets/smart_campus_stat_card.dart';

// —— 颜色（原版色值；紫色统一为品牌紫）——————————————————————————————
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderLine = Color(0xFFCECED1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = AppColors.brand;
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
        final session = room.session.isEmpty ? '查寝' : room.session;
        return '$session · ${deadline.replaceAll('前', '')} 截止';
      }
    }
    if (checkConfig.eveningDeadline.isNotEmpty) {
      return '晚查寝 · ${checkConfig.eveningDeadline.replaceAll('前', '')} 截止';
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
    final names = [
      for (final s in room.students)
        if (s.status == DormitoryStudentCheckStatus.unchecked) s.name,
    ];
    final ok = await showAppConfirm(
      context: context,
      title: '${room.roomName} 全员到寝',
      message: names.isEmpty
          ? '本间宿舍的同学都已打卡。'
          : '将把以下 ${names.length} 位未打卡的同学标为已归寝：${names.join('、')}。标错的同学可在下方单独改回。',
      confirmLabel: '确认到寝',
    );
    if (!ok || !mounted) return;
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
    AppToast.show(context, '${room.roomName} 已标记全员到寝');
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
    AppToast.show(context, '已更新查寝状态');
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
    return SmartCampusSecondaryPageShell(
      bodyTopClipRadius: 8,
      header: SmartCampusPageBanner(title: '按宿舍查寝', onBack: widget.onBack),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    );
  }
}

// =============================================================================
// 筛选行：楼栋 + 楼层
// =============================================================================

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
        SmartCampusFilterDropdown<DormitoryBuildingOption>(
          value: selectedBuilding,
          items: buildingOptions,
          itemLabel: (o) => o.label,
          onChanged: onBuildingChanged,
        ),
        SizedBox(width: ui(12)),
        // 选了楼栋、楼层列表到位后才能选楼层（外观与原版一致，不置灰）。
        IgnorePointer(
          ignoring: !floorEnabled,
          child: SmartCampusFilterDropdown<DormitoryFloorOption>(
            value: selectedFloor,
            items: floorOptions,
            itemLabel: (o) => o.label,
            onChanged: onFloorChanged,
          ),
        ),
      ],
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
          AppPressable(
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
            label: '已归寝',
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
// 单个宿舍卡：header（房号 + 全员到寝）+ 学生格子网格
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
    return AppPressable(
      onTap: onTap,
      child: Container(
        width: ui(220),
        height: ui(40),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [AppColors.brandSoft, AppColors.brand],
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
              disabled ? '已全部打卡' : '全员到寝',
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

/// 学生格子网格。
///
/// 宿舍卡 padding 12 → 内宽 970 − 24 = 946；3 列 + 2 * 10 gap →
/// 每格 (946 − 20) / 3 ≈ 308.6，与原版写死的 308 一致。窄横屏（内宽不足
/// 900）放不下 3 列，改 2 列并等分，避免右侧空出半列。
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = ui(10);
        final columns = constraints.maxWidth >= ui(900) ? 3 : 2;
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in students)
              SizedBox(
                // 向下取整到 0.01，避免浮点误差把最后一列挤到下一行。
                width: (tileWidth * 100).floorToDouble() / 100,
                child: _RoomStudentTile(
                  student: s,
                  onChangeStatus: (n) => onChangeStatus(s, n),
                ),
              ),
          ],
        );
      },
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
          SmartCampusSquareAvatar(name: student.name, url: student.avatarUrl),
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
    return AppPressable(
      key: _fieldKey,
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
