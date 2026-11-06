// =============================================================================
// 任课老师 / 班主任 / 宿管「我的请假」独立页面
//
// 入口：dashboard 快捷区「我的请假」→ controller.openMyTeacherLeave()
//      → mainView == myTeacherLeave → SmartCampusPage 路由到本视图。
//
// 视觉：
//   1. banner（62 高，背景图 xiaoquan/bg.png，标题「我的请假」）
//   2. 3 张统计卡（背景图与学生端一致）：待审批 / 已通过 / 已拒绝
//   3. 控制条：4 状态 tabs + 右侧白底「发起请假」按钮（无搜索框）
//   4. 双列卡片网格（白底 + 右上角淡紫光晕，展示本人请假记录）
//   5. 点击「发起请假」→ 右侧抽屉表单（600 宽，与 APP 其他抽屉一致）
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/teacher_leave_data.dart';
import '../data/teacher_repository.dart';
import 'widgets/smart_campus_equal_height_grid.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextPlaceholder = Color(0xFFD1D1D1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kGreen = Color(0xFF0CAC40);
const Color _kGreenSoftBg = Color(0xFFE4FFED);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFFE4E5);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeSoftBg = Color(0xFFFFEDD3);

enum _StatusTab {
  all('全部'),
  pending('待审批'),
  approved('已通过'),
  rejected('已拒绝');

  const _StatusTab(this.label);
  final String label;

  int? get apiStatus => switch (this) {
    _StatusTab.pending => 0,
    _StatusTab.approved => 1,
    _StatusTab.rejected => 2,
    _StatusTab.all => null,
  };
}

extension _TeacherLeaveStatusStyle on TeacherLeaveStatus {
  Color get bg => switch (this) {
    TeacherLeaveStatus.pending => _kOrangeSoftBg,
    TeacherLeaveStatus.approved => _kGreenSoftBg,
    TeacherLeaveStatus.rejected => _kRedSoftBg,
  };

  Color get fg => switch (this) {
    TeacherLeaveStatus.pending => _kOrange,
    TeacherLeaveStatus.approved => _kGreen,
    TeacherLeaveStatus.rejected => _kRed,
  };
}

String _formatYmdHms(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

// —— 顶级视图 ——————————————————————————————————————————————————————

class TeacherMyLeaveView extends ConsumerStatefulWidget {
  const TeacherMyLeaveView({
    super.key,
    required this.onBack,
    this.title = '我的请假',
  });

  final VoidCallback onBack;
  final String title;

  @override
  ConsumerState<TeacherMyLeaveView> createState() => _TeacherMyLeaveViewState();
}

class _TeacherMyLeaveViewState extends ConsumerState<TeacherMyLeaveView> {
  _StatusTab _tab = _StatusTab.all;
  List<TeacherLeaveRecord> _records = const [];
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  String? _loadError;
  int _listToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadStats());
      unawaited(_loadList());
    });
  }

  Future<void> _loadStats() async {
    final repo = ref.read(teacherRepositoryProvider);
    final results = await Future.wait([
      repo.teacherLeaveList(current: 1, size: 1, status: 0),
      repo.teacherLeaveList(current: 1, size: 1, status: 1),
      repo.teacherLeaveList(current: 1, size: 1, status: 2),
    ]);
    if (!mounted) return;

    int total(ApiResponse resp) =>
        parseTeacherLeaveTotal(resp.data) ??
        (resp.isSuccess ? parseTeacherLeaveList(resp.data).length : 0);

    setState(() {
      _pendingCount = results[0].isSuccess ? total(results[0]) : 0;
      _approvedCount = results[1].isSuccess ? total(results[1]) : 0;
      _rejectedCount = results[2].isSuccess ? total(results[2]) : 0;
    });
  }

  Future<void> _loadList() async {
    final token = ++_listToken;
    setState(() {
      _loadError = null;
    });
    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.teacherLeaveList(
      current: 1,
      size: 200,
      status: _tab.apiStatus,
    );
    if (!mounted || token != _listToken) return;

    if (!resp.isSuccess) {
      setState(() {
        _records = const [];
        _loadError = resp.displayMsg;
      });
      return;
    }

    setState(() {
      _records = parseTeacherLeaveList(resp.data);
      _loadError = null;
    });
  }

  Future<void> _reloadAll() async {
    await Future.wait([_loadStats(), _loadList()]);
  }

  Future<void> _showApplyDrawer() async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: '关闭',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return DashboardScaleScope(
          data: scaleData,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: _LeaveApplyDrawer(
                onCancel: () => Navigator.of(ctx).maybePop(),
                onSubmitted: () {
                  Navigator.of(ctx).maybePop();
                  unawaited(_reloadAll());
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Future<void> _showLeaveDetail(TeacherLeaveRecord record) async {
    final response = await ref
        .read(teacherRepositoryProvider)
        .teacherLeaveDetail(id: record.id);
    if (!mounted) return;
    if (!response.isSuccess) {
      AppToast.show(context, response.displayMsg, type: AppToastType.error);
      return;
    }
    final detail = parseTeacherLeaveDetail(response.data) ?? record;
    final ui = DashboardScaleScope.of(context).ui;
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) => GradientHeaderDialog(
        title: '${detail.leaveType} · ${detail.status.label}',
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoLine(label: '请假时间：', value: detail.timeRange),
            SizedBox(height: ui(6)),
            _InfoLine(label: '请假时长：', value: detail.durationLabel),
            SizedBox(height: ui(6)),
            _InfoLine(label: '请假事由：', value: detail.reason),
            SizedBox(height: ui(6)),
            _InfoLine(label: '申请时间：', value: detail.appliedAt),
            SizedBox(height: ui(6)),
            _InfoLine(label: '交接说明：', value: detail.handoff),
            if (detail.status != TeacherLeaveStatus.pending) ...[
              if (detail.auditTime.isNotEmpty) ...[
                SizedBox(height: ui(6)),
                _InfoLine(label: '审批时间：', value: detail.auditTime),
              ],
              if (detail.auditReason != null &&
                  detail.auditReason!.isNotEmpty) ...[
                SizedBox(height: ui(6)),
                _InfoLine(label: '审批意见：', value: detail.auditReason!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusSecondaryPageShell(
      backgroundColor: _kPageBg,
      bodyTopClipRadius: 8,
      header: _Banner(onBack: widget.onBack, title: widget.title),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsRow(
            pendingCount: _pendingCount,
            approvedCount: _approvedCount,
            rejectedCount: _rejectedCount,
          ),
          SizedBox(height: ui(8)),
          Padding(
            padding: EdgeInsets.only(left: ui(8)),
            child: Text(
              '提交后由教务老师审批；审批结果将同步至本页。',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: ui(16)),
          _ControlBar(
            current: _tab,
            onTap: (t) {
              if (_tab == t) return;
              setState(() => _tab = t);
              unawaited(_loadList());
            },
            onCreate: _showApplyDrawer,
          ),
          SizedBox(height: ui(16)),
          _CardsGrid(
            records: _records,
            onOpen: _showLeaveDetail,
            emptyMessage: _loadError ?? '暂无相关申请',
          ),
        ],
      ),
    );
  }
}

// —— Banner ————————————————————————————————————————————————————————

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack, required this.title});

  final VoidCallback onBack;
  final String title;

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// —— 统计卡 ————————————————————————————————————————————————————————

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
  });

  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.studentLeaveStatCard1,
            label: '待审批',
            value: pendingCount,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.studentLeaveStatCard2,
            label: '已通过',
            value: approvedCount,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.studentLeaveStatCard3,
            label: '已拒绝',
            value: rejectedCount,
          ),
        ),
      ],
    );
  }
}

// —— 控制条 ————————————————————————————————————————————————————————

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.current,
    required this.onTap,
    required this.onCreate,
  });

  final _StatusTab current;
  final ValueChanged<_StatusTab> onTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          height: ui(44),
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _StatusTab.values.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    right: i == _StatusTab.values.length - 1 ? 0 : ui(4),
                  ),
                  child: _TabPill(
                    label: _StatusTab.values[i].label,
                    active: _StatusTab.values[i] == current,
                    onTap: () => onTap(_StatusTab.values[i]),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        _CreateLeaveButton(onTap: onCreate),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _CreateLeaveButton extends StatelessWidget {
  const _CreateLeaveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(13), ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.studentLeaveCreateApplyIcon,
              width: ui(16),
              height: ui(16),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(8)),
            Text(
              '发起请假',
              style: TextStyle(
                fontSize: ui(14),
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

// —— 卡片网格 ——————————————————————————————————————————————————————

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({
    required this.records,
    required this.emptyMessage,
    required this.onOpen,
  });

  final List<TeacherLeaveRecord> records;
  final String emptyMessage;
  final ValueChanged<TeacherLeaveRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: Text(
            emptyMessage,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
            ),
          ),
        ),
      );
    }
    return SmartCampusEqualHeightGrid(
      itemCount: records.length,
      spacing: 16,
      itemBuilder: (context, index) {
        final r = records[index];
        return _LeaveCard(record: r, onTap: () => onOpen(r));
      },
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.record, this.onTap});

  final TeacherLeaveRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: Colors.white),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    width: ui(64),
                    height: ui(52),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(ui(12)),
                      ),
                      gradient: RadialGradient(
                        center: Alignment.topRight,
                        radius: 0.38,
                        colors: [
                          const Color(0x2EF9EEFF),
                          const Color(0x00F9EEFF),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(ui(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          record.leaveType,
                          style: TextStyle(
                            fontSize: ui(16),
                            color: Colors.black,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(width: ui(12)),
                        Text(
                          record.durationLabel,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.1,
                          ),
                        ),
                        const Spacer(),
                        _StatusBadge(status: record.status),
                      ],
                    ),
                    SizedBox(height: ui(8)),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        padding: EdgeInsets.all(ui(16)),
                        decoration: BoxDecoration(
                          color: _kBoardBg,
                          borderRadius: BorderRadius.circular(ui(12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoLine(
                              label: '请假时间：',
                              value: record.timeRange,
                            ),
                            SizedBox(height: ui(6)),
                            _InfoLine(
                              label: '请假事由：',
                              value: record.reason,
                            ),
                            SizedBox(height: ui(6)),
                            _InfoLine(
                              label: '申请时间：',
                              value: record.appliedAt,
                            ),
                            SizedBox(height: ui(6)),
                            _InfoLine(
                              label: '交接说明：',
                              value: record.handoff,
                            ),
                            if (record.status !=
                                TeacherLeaveStatus.pending) ...[
                              if (record.auditTime.isNotEmpty) ...[
                                SizedBox(height: ui(6)),
                                _InfoLine(
                                  label: '审批时间：',
                                  value: record.auditTime,
                                ),
                              ],
                              if (record.auditReason != null &&
                                  record.auditReason!.isNotEmpty) ...[
                                SizedBox(height: ui(6)),
                                _InfoLine(
                                  label: '审批意见：',
                                  value: record.auditReason!,
                                ),
                              ],
                            ],
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TeacherLeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(12),
          color: status.fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 15.24 / 12,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 发起请假 · 右侧抽屉
// =============================================================================

class _LeaveApplyDrawer extends ConsumerStatefulWidget {
  const _LeaveApplyDrawer({
    required this.onCancel,
    required this.onSubmitted,
  });

  final VoidCallback onCancel;
  final VoidCallback onSubmitted;

  static String formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  ConsumerState<_LeaveApplyDrawer> createState() => _LeaveApplyDrawerState();
}

class _LeaveApplyDrawerState extends ConsumerState<_LeaveApplyDrawer> {
  static const _types = ['病假', '事假'];

  String _type = '病假';
  DateTime? _start;
  DateTime? _end;
  final _daysCtrl = TextEditingController();
  bool _daysDirty = false;
  final _handoffCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _daysCtrl.addListener(() {
      if (!_daysDirty) _daysDirty = true;
    });
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _handoffCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _typeCode => _type == '事假' ? 1 : 0;

  void _autoFillDays() {
    if (_start == null || _end == null) return;
    if (!_end!.isAfter(_start!)) return;
    final days = _end!.difference(_start!).inHours / 24.0;
    final label = days == days.floorToDouble()
        ? days.toStringAsFixed(0)
        : days.toStringAsFixed(1);
    _daysDirty = false;
    _daysCtrl.text = label;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_start ?? DateTime.now())
        : (_end ?? _start ?? DateTime.now());
    final pickedDate = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 2),
      helpText: isStart ? '选择开始日期' : '选择结束日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: isStart ? '选择开始时间' : '选择结束时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (pickedTime == null || !mounted) return;
    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
      if (!_daysDirty) _autoFillDays();
    });
  }

  Future<void> _submit() async {
    final start = _start;
    final end = _end;
    final reason = _reasonCtrl.text.trim();
    if (start == null || end == null) {
      AppToast.show(context, '请选择开始与结束时间');
      return;
    }
    if (!end.isAfter(start)) {
      AppToast.show(context, '结束时间需晚于开始时间');
      return;
    }
    final daysText = _daysCtrl.text.trim();
    if (daysText.isEmpty) {
      AppToast.show(context, '请填写时长');
      return;
    }
    if (reason.isEmpty) {
      AppToast.show(context, '请填写请假事由');
      return;
    }

    setState(() => _submitting = true);
    final resp = await ref.read(teacherRepositoryProvider).teacherLeaveSave(
      type: _typeCode,
      startTime: _formatYmdHms(start),
      endTime: _formatYmdHms(end),
      leaveDuration: daysText,
      leaveReason: reason,
      shiftHandover: _handoffCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!resp.isSuccess) {
      AppToast.show(
        context,
        resp.msg.isNotEmpty ? resp.msg : '提交失败，请重试',
        type: AppToastType.error,
      );
      return;
    }
    AppToast.show(context, '请假申请已提交');
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
            _DrawerHeader(onClose: widget.onCancel),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(ui(20), ui(8), ui(20), ui(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('请假类型'),
                    SizedBox(height: ui(12)),
                    PopupSelectorField<String>(
                      value: _type,
                      items: _types,
                      itemLabel: (s) => s,
                      onChanged: (v) => setState(() => _type = v),
                    ),
                    SizedBox(height: ui(20)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('开始时间'),
                              SizedBox(height: ui(12)),
                              _DateField(
                                value: _start,
                                placeholder: '年/月/日',
                                onTap: () => _pickDateTime(isStart: true),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: ui(32)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('结束时间'),
                              SizedBox(height: ui(12)),
                              _DateField(
                                value: _end,
                                placeholder: '年/月/日',
                                onTap: () => _pickDateTime(isStart: false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('时长（自动算，可手动修改）'),
                    SizedBox(height: ui(12)),
                    _TextInputField(
                      controller: _daysCtrl,
                      placeholder: '请输入时长（天）',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('顶班/交接说明'),
                    SizedBox(height: ui(12)),
                    _TextInputField(
                      controller: _handoffCtrl,
                      placeholder: '例如：由谁代值、钥匙与对讲机交接给谁',
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('请假事由'),
                    SizedBox(height: ui(12)),
                    _TextAreaField(
                      controller: _reasonCtrl,
                      placeholder: '输入请假理由',
                    ),
                    SizedBox(height: ui(28)),
                  ],
                ),
              ),
            ),
            _DrawerFooter(
              onCancel: widget.onCancel,
              onSubmit: _submitting ? null : _submit,
              submitting: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onClose});

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
            '发起请假',
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

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({
    required this.onCancel,
    required this.onSubmit,
    this.submitting = false,
  });

  final VoidCallback onCancel;
  final VoidCallback? onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorderSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(ui(12)),
              child: Container(
                height: ui(48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kBorderHair,
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 24 / 14,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: ui(24)),
          Expanded(
            child: InkWell(
              onTap: onSubmit,
              borderRadius: BorderRadius.circular(ui(12)),
              child: Container(
                height: ui(48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                  ),
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
                child: submitting
                    ? SizedBox(
                        width: ui(20),
                        height: ui(20),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '提交申请',
                        style: TextStyle(
                          fontSize: ui(14),
                          color: Colors.white,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 24 / 14,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: Colors.black,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 20 / 14,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final DateTime? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final filled = value != null;
    final text = filled
        ? _LeaveApplyDrawer.formatDateTime(value!)
        : placeholder;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBoardBg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  color: filled ? _kTextDark : _kTextPlaceholder,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 20 / 14,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: ui(16),
              color: _kTextHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _TextInputField extends StatelessWidget {
  const _TextInputField({
    required this.controller,
    required this.placeholder,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppTextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: ui(14),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 20 / 14,
      ),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(
          fontSize: ui(14),
          color: _kTextPlaceholder,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ui(16),
          vertical: ui(14),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ui(8)),
          borderSide: const BorderSide(color: _kBoardBg),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ui(8)),
          borderSide: const BorderSide(color: _kBoardBg),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ui(8)),
          borderSide: const BorderSide(color: _kPurple, width: 1),
        ),
      ),
    );
  }
}

class _TextAreaField extends StatelessWidget {
  const _TextAreaField({
    required this.controller,
    required this.placeholder,
  });

  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppTextField(
      controller: controller,
      minLines: 3,
      maxLines: 5,
      style: TextStyle(
        fontSize: ui(14),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 20 / 14,
      ),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(
          fontSize: ui(14),
          color: _kTextPlaceholder,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
        ),
        contentPadding: EdgeInsets.all(ui(16)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ui(8)),
          borderSide: const BorderSide(color: _kBoardBg),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ui(8)),
          borderSide: const BorderSide(color: _kBoardBg),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ui(8)),
          borderSide: const BorderSide(color: _kPurple, width: 1),
        ),
      ),
    );
  }
}
