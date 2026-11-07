// =============================================================================
// 学生端「我的请假」独立页面
//
// 入口：学生 dashboard 快捷区「请假管理」按钮 → controller.openLeaveManagement()
//      → mainView == leaveManagement + role == student → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 渐变，左 32 返回 + 中"请假管理"
//      16px/600 + 副标题 12px/#B6B5BB（默认审批流程说明）。
//   2. 三色统计卡（100 高）：
//      A. 紫渐变 196deg #E7DCFF→white：「待审批」14px + 32px 数值 1
//      B. 绿渐变 196deg #DCFFE7→white：「已通过」14px + 32px 数值 2
//      C. 红渐变 196deg #FFE2DC→white：「已拒绝」14px + 32px 数值 1
//      右下角各放一个对应色 24~54 半透明几何装饰。
//   3. Tabs row（44 高）：白底圆角 8 容器，5 个 pill：
//      全部 / 审批中 / 已通过 / 已拒绝 / 已撤销，激活态 #0B081A 黑底白字 14/500，
//      未激活 #6D6B75 14/500 透明底；右侧白底「发起申请」（padding 8×12/13，
//      描边 #F3F2F3，文字 #0B081A 16/500 + 日历加号图标 16）。
//      点击「发起申请」→ 右侧抽屉 _LeaveApplyDrawer（600 宽，紫渐变提交按钮）。
//   4. 双列卡片网格（每张 477 宽，padding 12，白底 + 右上角淡紫渐变，
//      圆角 12，gap 16）：
//      · header 一行：类型 16/500「病假/事假」+ "时长4小时" 12/#6D6B75 +
//        右侧状态徽章 12/4×2 padding（审批中紫底紫字 / 已通过 #E4FFED+#12CE51 /
//        已拒绝 #FFE4E5+#FF323C / 已撤销 灰底灰字）。
//      · 内嵌灰底卡（#F5F6FA，padding 16）：5 行 label-value
//        （请假时间 / 请假事由 / 申请时间 / 路径 / 备注）；
//        中间一段 horizontal stepper（多节点；连接线仅在相邻节点之间）：
//           发起 [已发起] ───── 家长 [已通过] ───── 班主任 [待审批/已通过/已拒绝]
//        进度点：未到为白底灰描边，激活/到达态使用对应色填充（待审批用 #FF6A00
//        橙；通过用 #12CE51 绿；拒绝用 #FF323C 红）。
//      · footer：审批中卡多一行 40 高描边按钮"撤销申请"。
//
// 颜色 / 字体：
//   主紫 #715EFE / 主紫渐变 270deg #9585FF→#715EFE；卡片白底 + 右上角 #F9EEFF 光晕；
//   状态徽章配色见上；字体 PingFang SC，数字 32 用 Barlow（与 Figma 一致）。
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/student_leave_data.dart';
import '../data/student_repository.dart';
import 'widgets/smart_campus_equal_height_grid.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = AppColors.page;
const Color _kBoardBg = AppColors.surfaceSubtle;
const Color _kBorderSoft = AppColors.lineSoft;
const Color _kBorderHair = AppColors.line;
const Color _kTextDark = AppColors.ink;
const Color _kTextSecondary = AppColors.textSecondary;
const Color _kTextHint = AppColors.textPlaceholder;
const Color _kTextDivider = AppColors.textTertiary;
const Color _kPurple = AppColors.brand;
const Color _kGreen = AppColors.success;
const Color _kRed = AppColors.danger;
const Color _kRedSoftBg = AppColors.dangerSoft;
const Color _kOrange = AppColors.warning;
const Color _kOrangeSoftBg = AppColors.warningSoft;

// —— 顶级视图 ——————————————————————————————————————————————————————

class StudentLeaveManagementView extends ConsumerStatefulWidget {
  const StudentLeaveManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StudentLeaveManagementView> createState() =>
      _StudentLeaveManagementViewState();
}

class _StudentLeaveManagementViewState
    extends ConsumerState<StudentLeaveManagementView> {
  _StatusTab _tab = _StatusTab.all;
  List<_LeaveRecord> _records = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loadList()));
  }

  Future<void> _loadList() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final resp = await ref
          .read(studentRepositoryProvider)
          .studentLeaveList(current: 1, size: 200);
      if (!mounted) return;

      if (!resp.isSuccess) {
        setState(() {
          _records = const [];
          _loading = false;
          _loadError = resp.displayMsg;
        });
        return;
      }

      final rows = parseStudentLeaveList(resp.data);
      setState(() {
        _records = [for (final r in rows) _mapLeaveRecord(r)];
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _records = const [];
        _loading = false;
        _loadError = '加载失败，请重试';
      });
    }
  }

  Future<void> _showDetail(String id) async {
    final resp = await ref
        .read(studentRepositoryProvider)
        .studentLeaveDetail(id: id);
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg);
      return;
    }
    final detail = parseStudentLeaveDetail(resp.data);
    if (detail == null) {
      AppToast.show(context, '未获取到请假详情');
      return;
    }
    final record = _mapLeaveRecord(detail);
    final ui = DashboardScaleScope.of(context).ui;
    await showScaledDialog<void>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.18),
      builder: (ctx) => GradientHeaderDialog(
        title: '${record.type} · ${record.statusLabel}',
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LabelRow(label: '请假时间：', value: record.timeRange),
            SizedBox(height: ui(6)),
            _LabelRow(label: '请假时长：', value: record.durationLabel),
            SizedBox(height: ui(6)),
            _LabelRow(label: '请假事由：', value: record.reason),
            SizedBox(height: ui(6)),
            _LabelRow(label: '申请时间：', value: record.appliedAt),
            SizedBox(height: ui(6)),
            _LabelRow(label: '请假路径：', value: record.flowPath),
            SizedBox(height: ui(8)),
            _ApprovalStepper(steps: record.steps),
            SizedBox(height: ui(8)),
            _LabelRow(label: '请假备注：', value: record.note),
          ],
        ),
      ),
    );
  }

  /// 弹出右侧抽屉发起请假，提交后追加到 _records 顶部。
  /// 真实接入时换成 API call，并以服务器返回的记录刷新列表。
  ///
  /// 注意：`showGeneralDialog` 通过 root Navigator 推 route，新子树**不在原
  /// dashboard 的祖先链**上，所以必须显式把 [DashboardScaleScope] 注入到
  /// `pageBuilder` 中，否则 drawer 内 `DashboardScaleScope.of(context)` 会
  /// 抛 "DashboardScaleScope not found in widget tree."。
  Future<void> _showApplyDrawer() async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    final result = await showGeneralDialog<_LeaveApplyResult>(
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
              child: _LeaveApplyDrawer(
                onCancel: () => Navigator.of(ctx).maybePop(),
                onSubmit: (data) => Navigator.of(ctx).pop(data),
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

    if (!mounted || result == null) return;

    setState(() => _submitting = true);
    final reason = result.note.isEmpty
        ? result.reason
        : '${result.reason}\n${result.note}';
    final resp = await ref
        .read(studentRepositoryProvider)
        .studentLeaveSave(
          startTime: result.start,
          endTime: result.end,
          leaveDuration: result.durationLabel,
          leaveReason: reason,
          type: studentLeaveTypeToApi(result.type),
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg);
      return;
    }

    AppToast.show(context, '请假申请已提交，等待审批');
    setState(() => _tab = _StatusTab.reviewing);
    await _loadList();
  }

  List<_LeaveRecord> get _visible {
    return _records.where((r) {
      switch (_tab) {
        case _StatusTab.all:
          return true;
        case _StatusTab.reviewing:
          return r.status == _LeaveStatus.reviewing;
        case _StatusTab.approved:
          return r.status == _LeaveStatus.approved;
        case _StatusTab.rejected:
          return r.status == _LeaveStatus.rejected;
        case _StatusTab.withdrawn:
          return r.status == _LeaveStatus.withdrawn;
      }
    }).toList();
  }

  int _countOf(_LeaveStatus s) => _records.where((r) => r.status == s).length;

  int _countOfTab(_StatusTab t) => switch (t) {
    _StatusTab.all => _records.length,
    _StatusTab.reviewing => _countOf(_LeaveStatus.reviewing),
    _StatusTab.approved => _countOf(_LeaveStatus.approved),
    _StatusTab.rejected => _countOf(_LeaveStatus.rejected),
    _StatusTab.withdrawn => _countOf(_LeaveStatus.withdrawn),
  };

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pageLoading = _loading && _records.isEmpty;
    return SmartCampusSecondaryPageShell(
      backgroundColor: _kPageBg,
      bodyTopClipRadius: 8,
      header: AppPageHeader(
        title: '我的请假',
        subtitle: '先由家长确认，再由班主任审批；已和家长沟通好的可直接交班主任审批',
        onBack: widget.onBack,
        actions: [
          AppButton(
            label: '发起请假',
            icon: Icons.add_rounded,
            size: AppButtonSize.sm,
            onTap: _submitting ? null : _showApplyDrawer,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MainContentLoadingShell(
            loading: pageLoading,
            preserveChrome: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsRow(
                  reviewing: _countOf(_LeaveStatus.reviewing),
                  approved: _countOf(_LeaveStatus.approved),
                  rejected: _countOf(_LeaveStatus.rejected),
                ),
                SizedBox(height: ui(12)),
                AppTabs<_StatusTab>(
                  tabs: [
                    for (final t in _StatusTab.values)
                      AppTab(value: t, label: t.label, count: _countOfTab(t)),
                  ],
                  value: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
                SizedBox(height: ui(12)),
                if (_loadError != null)
                  _ErrorState(message: _loadError!, onRetry: _loadList)
                else if (!pageLoading)
                  _LeaveCardsGrid(records: _visible, onTap: _showDetail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Banner：返回 + 标题 + 副标题
// =============================================================================

// =============================================================================
// 三色统计卡
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.reviewing,
    required this.approved,
    required this.rejected,
  });

  final int reviewing;
  final int approved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.studentLeaveStatCard1,
            label: '审批中',
            value: reviewing,
            valueSuffix: '条',
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.studentLeaveStatCard2,
            label: '已通过',
            value: approved,
            valueSuffix: '条',
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.studentLeaveStatCard3,
            label: '已拒绝',
            value: rejected,
            valueSuffix: '条',
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Tabs + 发起申请 row
// =============================================================================

enum _StatusTab { all, reviewing, approved, rejected, withdrawn }

extension on _StatusTab {
  String get label {
    switch (this) {
      case _StatusTab.all:
        return '全部';
      case _StatusTab.reviewing:
        return '审批中';
      case _StatusTab.approved:
        return '已通过';
      case _StatusTab.rejected:
        return '已拒绝';
      case _StatusTab.withdrawn:
        return '已撤销';
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: AppErrorState(
        title: '请假记录加载失败',
        description: message,
        onRetry: onRetry,
      ),
    );
  }
}

// =============================================================================
// 卡片网格
// =============================================================================

class _LeaveCardsGrid extends StatelessWidget {
  const _LeaveCardsGrid({required this.records, required this.onTap});

  final List<_LeaveRecord> records;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _EmptyState();
    }
    return SmartCampusEqualHeightGrid(
      itemCount: records.length,
      spacing: 16,
      itemBuilder: (context, index) {
        final r = records[index];
        return _LeaveCard(record: r, onTap: () => onTap(r.id));
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: AppEmptyState(
        icon: Icons.event_note_outlined,
        title: '这里还没有请假记录',
        description: '需要请假时点右上角「发起请假」',
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.record, required this.onTap});

  final _LeaveRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Padding(
            padding: EdgeInsets.all(ui(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeaderRow(record: record),
                SizedBox(height: ui(8)),
                Expanded(child: _CardBoardBody(record: record)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({required this.record});

  final _LeaveRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Text(
          record.type,
          style: TextStyle(
            fontSize: ui(16),
            color: AppColors.ink,
            fontWeight: AppFont.w500,
            height: 1.1,
          ),
        ),
        SizedBox(width: ui(12)),
        Text(
          record.durationLabel.startsWith('时长')
              ? record.durationLabel
              : '时长 ${record.durationLabel}',
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontWeight: AppFont.w400,
            height: 1.1,
          ),
        ),
        const Spacer(),
        _StatusBadge(status: record.status),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      _LeaveStatus.reviewing => const AppStatusTag(
        label: '审批中',
        tone: AppTone.brand,
      ),
      _LeaveStatus.approved => const AppStatusTag(
        label: '已通过',
        tone: AppTone.success,
      ),
      _LeaveStatus.rejected => const AppStatusTag(
        label: '已拒绝',
        tone: AppTone.danger,
      ),
      _LeaveStatus.withdrawn => const AppStatusTag(label: '已撤销'),
    };
  }
}

class _CardBoardBody extends StatelessWidget {
  const _CardBoardBody({required this.record});

  final _LeaveRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
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
          _LabelRow(label: '请假时间：', value: record.timeRange),
          SizedBox(height: ui(6)),
          _LabelRow(label: '请假事由：', value: record.reason),
          SizedBox(height: ui(6)),
          _LabelRow(label: '申请时间：', value: record.appliedAt),
          SizedBox(height: ui(6)),
          _LabelRow(label: '请假路径：', value: record.flowPath),
          SizedBox(height: ui(8)),
          _ApprovalStepper(steps: record.steps),
          SizedBox(height: ui(8)),
          _LabelRow(label: '请假备注：', value: record.note),
          const Spacer(),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.value});

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
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 审批 stepper（家长 → 班主任）
// =============================================================================

class _ApprovalStepper extends StatelessWidget {
  const _ApprovalStepper({required this.steps});

  final List<_ApprovalStep> steps;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _ApprovalNodeView(step: steps[i]),
            if (i < steps.length - 1)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ui(8)),
                  child: Container(height: 1, color: _kBorderHair),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ApprovalNodeView extends StatelessWidget {
  const _ApprovalNodeView({required this.step});

  final _ApprovalStep step;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (
      Color dot,
      Color halo,
      Color labelBg,
      Color labelFg,
    ) = switch (step.state) {
      _StepState.pending => (
        _kOrange,
        const Color(0xFFFFF1D9),
        _kOrangeSoftBg,
        _kOrange,
      ),
      _StepState.passed => (
        _kGreen,
        const Color(0xFFEFFFE7),
        AppColors.surface,
        _kTextHint,
      ),
      _StepState.rejected => (
        _kRed,
        const Color(0xFFFFE5E7),
        _kRedSoftBg,
        _kRed,
      ),
      _StepState.dim => (
        _kTextDivider,
        Colors.transparent,
        AppColors.surface,
        _kTextHint,
      ),
    };

    final hasHalo = step.state != _StepState.dim;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: ui(14),
          height: ui(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasHalo)
                Container(
                  width: ui(14),
                  height: ui(14),
                  decoration: BoxDecoration(
                    color: halo,
                    borderRadius: BorderRadius.circular(ui(7)),
                  ),
                ),
              Container(
                width: ui(9),
                height: ui(9),
                decoration: BoxDecoration(
                  color: step.state == _StepState.dim ? AppColors.surface : dot,
                  borderRadius: BorderRadius.circular(ui(5)),
                  border: Border.all(
                    color: step.state == _StepState.dim
                        ? _kTextDivider
                        : AppColors.surface,
                    width: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: ui(8)),
        Text(
          step.title,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(width: ui(6)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(ui(4)),
          ),
          child: Text(
            step.label,
            style: TextStyle(
              fontSize: ui(12),
              color: labelFg,
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 数据模型 + API 映射
// =============================================================================

enum _LeaveStatus { reviewing, approved, rejected, withdrawn }

enum _StepState { pending, passed, rejected, dim }

class _ApprovalStep {
  const _ApprovalStep({
    required this.title,
    required this.label,
    required this.state,
  });

  final String title;
  final String label;
  final _StepState state;

  _ApprovalStep copyWith({String? label, _StepState? state}) => _ApprovalStep(
    title: title,
    label: label ?? this.label,
    state: state ?? this.state,
  );
}

class _LeaveRecord {
  const _LeaveRecord({
    required this.id,
    required this.type,
    required this.durationLabel,
    required this.timeRange,
    required this.reason,
    required this.appliedAt,
    required this.flowPath,
    required this.steps,
    required this.note,
    required this.status,
  });

  final String id;
  final String type; // 病假 / 事假 / 公假 ...
  final String durationLabel; // "4小时" / "1天"
  final String timeRange;
  final String reason;
  final String appliedAt;
  final String flowPath; // "家长小程序 - 班主任"
  final List<_ApprovalStep> steps;
  final String note;
  final _LeaveStatus status;

  _LeaveRecord copyWith({_LeaveStatus? status, List<_ApprovalStep>? steps}) =>
      _LeaveRecord(
        id: id,
        type: type,
        durationLabel: durationLabel,
        timeRange: timeRange,
        reason: reason,
        appliedAt: appliedAt,
        flowPath: flowPath,
        steps: steps ?? this.steps,
        note: note,
        status: status ?? this.status,
      );

  String get statusLabel => switch (status) {
    _LeaveStatus.reviewing => '审批中',
    _LeaveStatus.approved => '已通过',
    _LeaveStatus.rejected => '已拒绝',
    _LeaveStatus.withdrawn => '已撤销',
  };
}

_LeaveRecord _mapLeaveRecord(StudentLeaveRecord source) {
  final duration = source.duration.trim();
  final durationLabel = duration.isEmpty || duration == '—'
      ? '—'
      : duration.replaceFirst(RegExp(r'^时长'), '');

  return _LeaveRecord(
    id: source.id,
    type: source.leaveType,
    durationLabel: durationLabel,
    timeRange: source.timeRange,
    reason: source.reason,
    appliedAt: source.appliedAt,
    flowPath: source.path,
    steps: _buildLeaveApprovalSteps(source),
    note: source.note,
    status: _leaveStatusFromApi(source.status),
  );
}

/// 审批进度节点：首位固定「发起」，其余按 [StudentLeaveRecord.path] 解析。
List<_ApprovalStep> _buildLeaveApprovalSteps(StudentLeaveRecord source) {
  final steps = <_ApprovalStep>[
    const _ApprovalStep(title: '发起', label: '已发起', state: _StepState.passed),
  ];

  final segments = _parseLeaveFlowPathSegments(source.path);
  if (segments.isEmpty) {
    steps.addAll(_defaultApprovalPathSteps(source));
    return steps;
  }

  final seenTitles = <String>{'发起'};
  for (final segment in segments) {
    final step = _approvalStepForFlowSegment(segment, source);
    if (step == null || seenTitles.contains(step.title)) {
      continue;
    }
    seenTitles.add(step.title);
    steps.add(step);
  }

  if (steps.length == 1) {
    steps.addAll(_defaultApprovalPathSteps(source));
  }
  return steps;
}

List<_ApprovalStep> _defaultApprovalPathSteps(StudentLeaveRecord source) {
  return [
    _ApprovalStep(
      title: '家长',
      label: source.parentStep.label,
      state: _stepStateFromApi(source.parentStep),
    ),
    _ApprovalStep(
      title: '班主任',
      label: _headTeacherStepLabel(source),
      state: _headTeacherStepState(source),
    ),
  ];
}

List<String> _parseLeaveFlowPathSegments(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return const [];
  }
  return trimmed
      .split(RegExp(r'[→➔\->\-—]+'))
      .map((segment) => segment.trim())
      .where(
        (segment) => segment.isNotEmpty && !_isInitiateFlowSegment(segment),
      )
      .toList();
}

bool _isInitiateFlowSegment(String segment) {
  final normalized = segment.trim();
  return normalized == '发起' ||
      normalized.contains('学生发起') ||
      normalized.endsWith('发起');
}

_ApprovalStep? _approvalStepForFlowSegment(
  String segment,
  StudentLeaveRecord source,
) {
  final normalized = segment.trim();
  if (normalized.isEmpty || _isInitiateFlowSegment(normalized)) {
    return null;
  }

  if (normalized.contains('家长')) {
    return _ApprovalStep(
      title: '家长',
      label: source.parentStep.label,
      state: _stepStateFromApi(source.parentStep),
    );
  }
  if (normalized.contains('班主任')) {
    return _ApprovalStep(
      title: '班主任',
      label: _headTeacherStepLabel(source),
      state: _headTeacherStepState(source),
    );
  }

  return _ApprovalStep(title: normalized, label: '待处理', state: _StepState.dim);
}

_LeaveStatus _leaveStatusFromApi(StudentLeaveStatus status) {
  return switch (status) {
    StudentLeaveStatus.waitingParent ||
    StudentLeaveStatus.waitingTeacher => _LeaveStatus.reviewing,
    StudentLeaveStatus.approved => _LeaveStatus.approved,
    StudentLeaveStatus.parentRejected ||
    StudentLeaveStatus.teacherRejected => _LeaveStatus.rejected,
  };
}

_StepState _stepStateFromApi(StudentLeaveStepStatus step) {
  return switch (step) {
    StudentLeaveStepStatus.pending => _StepState.pending,
    StudentLeaveStepStatus.approved => _StepState.passed,
    StudentLeaveStepStatus.rejected => _StepState.rejected,
  };
}

_StepState _headTeacherStepState(StudentLeaveRecord source) {
  return switch (source.status) {
    StudentLeaveStatus.waitingParent => _StepState.dim,
    StudentLeaveStatus.waitingTeacher => _StepState.pending,
    StudentLeaveStatus.approved => _StepState.passed,
    StudentLeaveStatus.teacherRejected => _StepState.rejected,
    StudentLeaveStatus.parentRejected => _StepState.dim,
  };
}

String _headTeacherStepLabel(StudentLeaveRecord source) {
  return switch (source.status) {
    StudentLeaveStatus.waitingParent => '未开始',
    StudentLeaveStatus.waitingTeacher => source.headTeacherStep.label,
    StudentLeaveStatus.approved => source.headTeacherStep.label,
    StudentLeaveStatus.teacherRejected => source.headTeacherStep.label,
    StudentLeaveStatus.parentRejected => '未开始',
  };
}

// =============================================================================
// 发起请假 · 右侧抽屉
//   · 整体 600 宽，从右滑入；与 dorm 端共用同一布局，但裁剪掉「顶班/交接说明」
//     字段（学生不需要），并把"作业标题"换成「请假类型」单选下拉。
//   · 时长根据开始/结束时间自动计算（向上取小时整数），用户可手动覆盖。
//   · 提交按钮在校验通过后回调 `_LeaveApplyResult` 给父级，由父级新增记录。
// =============================================================================

class _LeaveApplyResult {
  const _LeaveApplyResult({
    required this.type,
    required this.start,
    required this.end,
    required this.durationLabel,
    required this.reason,
    required this.note,
  });

  final String type;
  final DateTime start;
  final DateTime end;
  final String durationLabel;
  final String reason;
  final String note;
}

class _LeaveApplyDrawer extends StatefulWidget {
  const _LeaveApplyDrawer({required this.onCancel, required this.onSubmit});

  final VoidCallback onCancel;
  final ValueChanged<_LeaveApplyResult> onSubmit;

  static String formatDateTime(DateTime dt) {
    return formatStudentLeaveDateTime(dt);
  }

  @override
  State<_LeaveApplyDrawer> createState() => _LeaveApplyDrawerState();
}

class _LeaveApplyDrawerState extends State<_LeaveApplyDrawer> {
  static const _types = ['病假', '事假'];

  String _type = '病假';
  DateTime? _start;
  DateTime? _end;
  final _hoursCtrl = TextEditingController();
  bool _hoursDirty = false; // 用户是否手动改过时长
  final _reasonCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hoursCtrl.addListener(() {
      // 用户开始输入后，自动算时长不再覆盖
      if (!_hoursDirty) _hoursDirty = true;
    });
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _reasonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _autoFillHours() {
    if (_start == null || _end == null) return;
    if (!_end!.isAfter(_start!)) return;
    final minutes = _end!.difference(_start!).inMinutes;
    final hours = (minutes / 60);
    final label = hours == hours.floorToDouble()
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    _hoursDirty = false;
    _hoursCtrl.text = label;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_start ?? DateTime.now())
        : (_end ?? _start ?? DateTime.now());
    // 用项目主紫 #715EFE 覆盖 Material picker 的默认配色，与 dorm 端补卡
    // 表单保持视觉一致；同时把 day-period chip / hour-minute 按钮等用到的
    // primaryContainer 一并改成淡紫底，避免 Material 默认的 tonalSurface 色。
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
      if (!_hoursDirty) _autoFillHours();
    });
  }

  void _onSubmit() {
    final start = _start;
    final end = _end;
    final reason = _reasonCtrl.text.trim();
    if (start == null || end == null) {
      _toast('请选择开始与结束时间');
      return;
    }
    if (!end.isAfter(start)) {
      _toast('结束时间需晚于开始时间');
      return;
    }
    final hoursText = _hoursCtrl.text.trim();
    if (hoursText.isEmpty) {
      _toast('请填写时长');
      return;
    }
    if (reason.isEmpty) {
      _toast('请填写请假事由');
      return;
    }
    final durationLabel = hoursText.endsWith('小时') ? hoursText : '$hoursText小时';

    widget.onSubmit(
      _LeaveApplyResult(
        type: _type,
        start: start,
        end: end,
        durationLabel: durationLabel,
        reason: reason,
        note: _noteCtrl.text.trim(),
      ),
    );
  }

  void _toast(String msg) {
    AppToast.show(context, msg);
  }

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
                      controller: _hoursCtrl,
                      placeholder: '请输入时长（小时）',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('请假事由'),
                    SizedBox(height: ui(12)),
                    _TextAreaField(
                      controller: _reasonCtrl,
                      placeholder: '请输入请假理由',
                    ),
                    SizedBox(height: ui(20)),
                    _FieldLabel('备注（选填）'),
                    SizedBox(height: ui(12)),
                    _TextAreaField(
                      controller: _noteCtrl,
                      placeholder: '补充说明，例如已与班主任沟通、需课代表代收作业等',
                    ),
                    SizedBox(height: ui(28)),
                  ],
                ),
              ),
            ),
            _DrawerFooter(onCancel: widget.onCancel, onSubmit: _onSubmit),
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
  const _DrawerFooter({required this.onCancel, required this.onSubmit});

  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
                    colors: [AppColors.brandSoft, AppColors.brand],
                  ),
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
                child: Text(
                  '提交申请',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: AppColors.surface,
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
        color: AppColors.ink,
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
                  color: filled ? _kTextDark : _kTextHint,
                  fontWeight: AppFont.w400,
                  height: 20 / 14,
                ),
              ),
            ),
            AppPickerAssetIcon(
              AppAssets.iconScheduleCalendar,
              imageSize: ui(18),
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
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBoardBg),
      ),
      alignment: Alignment.center,
      child: AppTextField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontWeight: AppFont.w400,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _TextAreaField extends StatelessWidget {
  const _TextAreaField({required this.controller, required this.placeholder});

  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(72),
      padding: EdgeInsets.fromLTRB(ui(16), ui(12), ui(16), ui(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBoardBg),
      ),
      child: AppTextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontWeight: AppFont.w400,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
