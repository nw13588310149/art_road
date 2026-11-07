// =============================================================================
// 班主任端「请假审批」独立页面
//
// 入口：班主任 dashboard 快捷区「请假审批」按钮 → controller.openLeaveApproval()
//      → mainView == leaveApproval + role == headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高，背景图 xiaoquan/bg.png，圆角 16，标题「请假审批」；
//      左 12 返回按钮 32×32 白底 outline #F3F2F3）。
//   2. 4 张统计卡（100 高）：待审批 / 审批中 / 已通过 / 已拒绝。
//   3. Tabs row + 搜索框 + 双列卡片网格（家长 → 班主任 stepper）。
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/scaled_dialog.dart';
import 'widgets/smart_campus_page_banner.dart';
import '../../shell/ui/shell_layout.dart';
import 'widgets/smart_campus_stat_card.dart';
import '../data/student_leave_data.dart';
import '../data/teacher_repository.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kBoardBg = AppColors.surfaceSubtle;
const Color _kBorderSoft = AppColors.lineSoft;
const Color _kBorderHair = AppColors.line;
const Color _kTextDark = AppColors.ink;
const Color _kTextSecondary = AppColors.textSecondary;
const Color _kTextHint = AppColors.textPlaceholder;
const Color _kTextHintLight = AppColors.textTertiary;
const Color _kTextPlaceholder = AppColors.textPlaceholder;
const Color _kPurple = AppColors.brand;
const Color _kGreen = AppColors.success;
const Color _kGreenSoftBg = AppColors.successSoft;
const Color _kRed = AppColors.danger;
const Color _kRedSoftBg = AppColors.dangerSoft;
const Color _kOrange = AppColors.warning;
const Color _kOrangeSoftBg = AppColors.warningSoft;

// —— 状态枚举 ——————————————————————————————————————————————————————
enum _StatusTab {
  all('全部'),
  mine('待我审批'),
  reviewing('待家长确认'),
  approved('已通过'),
  rejected('已驳回'),
  withdrawn('已撤销');

  const _StatusTab(this.label);
  final String label;

  int? get apiStatus => switch (this) {
    _StatusTab.approved => 3,
    _ => null,
  };
}

extension _StudentLeaveStepStyle on StudentLeaveStepStatus {
  Color get color => switch (this) {
    StudentLeaveStepStatus.pending => _kOrange,
    StudentLeaveStepStatus.approved => _kGreen,
    StudentLeaveStepStatus.rejected => _kRed,
  };

  Color get softBg => switch (this) {
    StudentLeaveStepStatus.pending => _kOrangeSoftBg,
    StudentLeaveStepStatus.approved => _kGreenSoftBg,
    StudentLeaveStepStatus.rejected => _kRedSoftBg,
  };
}

// —— 顶级视图 ——————————————————————————————————————————————————————

class TeacherLeaveApprovalView extends ConsumerStatefulWidget {
  const TeacherLeaveApprovalView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherLeaveApprovalView> createState() =>
      _TeacherLeaveApprovalViewState();
}

class _TeacherLeaveApprovalViewState
    extends ConsumerState<TeacherLeaveApprovalView> {
  _StatusTab _tab = _StatusTab.all;
  String _searchQuery = '';
  List<StudentLeaveRecord> _requests = const [];
  int _pendingCount = 0;
  int _reviewingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  bool _loading = false;
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
      repo.headTeacherStudentLeaveList(current: 1, size: 1, status: 1),
      repo.headTeacherStudentLeaveList(current: 1, size: 1, status: 0),
      repo.headTeacherStudentLeaveList(current: 1, size: 1, status: 3),
      repo.headTeacherStudentLeaveList(current: 1, size: 1, status: 2),
      repo.headTeacherStudentLeaveList(current: 1, size: 1, status: 4),
    ]);
    if (!mounted) return;

    int total(ApiResponse resp) =>
        parseStudentLeaveTotal(resp.data) ??
        (resp.isSuccess ? parseStudentLeaveList(resp.data).length : 0);

    setState(() {
      _pendingCount = results[0].isSuccess ? total(results[0]) : 0;
      _reviewingCount = results[1].isSuccess ? total(results[1]) : 0;
      _approvedCount = results[2].isSuccess ? total(results[2]) : 0;
      _rejectedCount =
          (results[3].isSuccess ? total(results[3]) : 0) +
          (results[4].isSuccess ? total(results[4]) : 0);
    });
  }

  Future<void> _loadList() async {
    final token = ++_listToken;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.headTeacherStudentLeaveList(
      current: 1,
      size: 200,
      status: _tab.apiStatus,
    );
    if (!mounted || token != _listToken) return;

    if (!resp.isSuccess) {
      setState(() {
        _requests = const [];
        _loading = false;
        _loadError = resp.displayMsg;
      });
      return;
    }

    setState(() {
      _requests = _filterTab(parseStudentLeaveList(resp.data));
      _loading = false;
      _loadError = null;
    });
  }

  List<StudentLeaveRecord> _filterSearch(List<StudentLeaveRecord> source) {
    final q = _searchQuery.trim();
    if (q.isEmpty) return source;
    final lower = q.toLowerCase();
    bool hit(String value) {
      if (value.isEmpty || value == '—') return false;
      return value.toLowerCase().contains(lower);
    }

    return source
        .where(
          (r) =>
              hit(r.studentName) ||
              hit(r.studentNo) ||
              hit(r.leaveType) ||
              hit(r.reason) ||
              hit(r.note),
        )
        .toList();
  }

  List<StudentLeaveRecord> _filterTab(List<StudentLeaveRecord> source) {
    return switch (_tab) {
      _StatusTab.all => source,
      _StatusTab.mine => source.where((r) => r.status.canTeacherAudit).toList(),
      _StatusTab.reviewing =>
        source
            .where(
              (r) =>
                  r.status == StudentLeaveStatus.waitingParent ||
                  r.status == StudentLeaveStatus.waitingTeacher,
            )
            .toList(),
      _StatusTab.approved =>
        source.where((r) => r.status == StudentLeaveStatus.approved).toList(),
      _StatusTab.rejected =>
        source
            .where(
              (r) =>
                  r.status == StudentLeaveStatus.parentRejected ||
                  r.status == StudentLeaveStatus.teacherRejected,
            )
            .toList(),
      _StatusTab.withdrawn => const [],
    };
  }

  Future<void> _reloadAll() async {
    await Future.wait([_loadStats(), _loadList()]);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pageLoading = _loading && _requests.isEmpty;
    final displayRecords = _filterSearch(_requests);
    return SmartCampusSecondaryPageShell(
      header: AppPageHeader(
        title: '请假审批',
        subtitle: '本班学生的请假申请：家长确认后由你审批，已和家长沟通好的也可直接审批',
        onBack: widget.onBack,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatsRow(
                pendingCount: _pendingCount,
                reviewingCount: _reviewingCount,
                approvedCount: _approvedCount,
                rejectedCount: _rejectedCount,
              ),
              SizedBox(height: ui(16)),
              _TabsRow(
                counts: {
                  _StatusTab.mine: _pendingCount,
                  _StatusTab.reviewing: _reviewingCount,
                  _StatusTab.approved: _approvedCount,
                  _StatusTab.rejected: _rejectedCount,
                },
                current: _tab,
                searchValue: _searchQuery,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onTap: (t) {
                  if (_tab == t) return;
                  setState(() => _tab = t);
                  unawaited(_loadList());
                },
              ),
              SizedBox(height: ui(16)),
              _CardsGrid(
                records: displayRecords,
                emptyMessage: pageLoading
                    ? ''
                    : (_loadError ??
                          (_searchQuery.trim().isNotEmpty &&
                                  _requests.isNotEmpty
                              ? '未找到匹配申请'
                              : '暂无相关申请')),
                onApprove: _onApprove,
                onReject: _onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onApprove(StudentLeaveRecord record) async {
    final defaultReason = record.status == StudentLeaveStatus.waitingParent
        ? kHeadTeacherLeaveApproveReasonWithoutParent
        : kHeadTeacherLeaveApproveReasonDefault;
    final reason = await _showTeacherAuditReasonDialog(
      context,
      record: record,
      title: '通过申请',
      fieldLabel: '审批意见',
      initialText: defaultReason,
    );
    if (!mounted) return;
    if (reason == null || reason.trim().isEmpty) return;

    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.headTeacherStudentLeaveAudit(
      id: record.id,
      status: 3,
      teacherAuditReason: reason.trim(),
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg, type: AppToastType.error);
      return;
    }
    AppToast.show(context, '已通过 ${record.studentName} 的${record.leaveType}申请');
    await _reloadAll();
  }

  Future<void> _onReject(StudentLeaveRecord record) async {
    final reason = await _showTeacherAuditReasonDialog(
      context,
      record: record,
      title: '驳回申请',
      fieldLabel: '审批意见',
      initialText: kHeadTeacherLeaveRejectReasonDefault,
    );
    if (!mounted) return;
    if (reason == null || reason.trim().isEmpty) return;

    final repo = ref.read(teacherRepositoryProvider);
    final resp = await repo.headTeacherStudentLeaveAudit(
      id: record.id,
      status: 4,
      teacherAuditReason: reason.trim(),
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg, type: AppToastType.error);
      return;
    }
    AppToast.show(context, '已驳回 ${record.studentName} 的${record.leaveType}申请');
    await _reloadAll();
  }
}

// —— Banner ————————————————————————————————————————————————————————

// —— 4 张统计卡 ——————————————————————————————————————————————————————

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.pendingCount,
    required this.reviewingCount,
    required this.approvedCount,
    required this.rejectedCount,
  });

  final int pendingCount;
  final int reviewingCount;
  final int approvedCount;
  final int rejectedCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.headTeacherLeaveApprovalStatPending,
            label: '待我审批',
            value: pendingCount,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.headTeacherLeaveApprovalStatReviewing,
            label: '待家长确认',
            value: reviewingCount,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.headTeacherLeaveApprovalStatApproved,
            label: '已通过',
            value: approvedCount,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.headTeacherLeaveApprovalStatRejected,
            label: '已驳回',
            value: rejectedCount,
          ),
        ),
      ],
    );
  }
}

// —— Tabs row + 搜索框 ——————————————————————————————————————————————

class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.counts,
    required this.current,
    required this.onTap,
    required this.searchValue,
    required this.onSearchChanged,
  });

  final Map<_StatusTab, int> counts;
  final _StatusTab current;
  final ValueChanged<_StatusTab> onTap;
  final String searchValue;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: AppTabs<_StatusTab>(
                tabs: [
                  for (final t in _StatusTab.values)
                    AppTab(value: t, label: t.label, count: counts[t]),
                ],
                value: current,
                onChanged: onTap,
              ),
            ),
          ),
          SizedBox(width: ui(16)),
          Container(
            width: (constraints.maxWidth * 0.28).clamp(ui(120), ui(260)),
            height: ui(40),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            padding: EdgeInsets.fromLTRB(ui(14), 0, ui(24), 0),
            child: Row(
              children: [
                AppAssetGraphic(
                  AppAssets.shellV2Search,
                  width: ui(16),
                  height: ui(16),
                  fit: BoxFit.contain,
                ),
                SizedBox(width: ui(8)),
                Expanded(
                  child: _LeaveApprovalSearchField(
                    value: searchValue,
                    onChanged: onSearchChanged,
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

class _LeaveApprovalSearchField extends StatefulWidget {
  const _LeaveApprovalSearchField({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_LeaveApprovalSearchField> createState() =>
      _LeaveApprovalSearchFieldState();
}

class _LeaveApprovalSearchFieldState extends State<_LeaveApprovalSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _LeaveApprovalSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: widget.value.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppTextField(
      controller: _controller,
      onChanged: widget.onChanged,
      cursorColor: _kPurple,
      cursorWidth: 1.5,
      cursorHeight: ui(16),
      style: TextStyle(
        fontSize: ui(14),
        color: _kTextDark,
        fontWeight: AppFont.w400,
        height: 1.2,
      ),
      decoration: InputDecoration(
        hintText: '搜索姓名、学号、手机、宿舍、家长',
        hintStyle: TextStyle(
          fontSize: ui(14),
          color: _kTextPlaceholder,
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
    );
  }
}

// —— 卡片网格 ——————————————————————————————————————————————————————

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({
    required this.records,
    required this.emptyMessage,
    required this.onApprove,
    required this.onReject,
  });

  final List<StudentLeaveRecord> records;
  final String emptyMessage;
  final ValueChanged<StudentLeaveRecord> onApprove;
  final ValueChanged<StudentLeaveRecord> onReject;

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
              fontWeight: AppFont.w400,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gap = ui(16);
        // 970 设计宽下两列每张 477，gap 16；自适应：尽量两列。
        final cardWidth = (w - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in records)
              SizedBox(
                width: cardWidth,
                child: _LeaveCard(
                  record: r,
                  onApprove: () => onApprove(r),
                  onReject: () => onReject(r),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.record,
    required this.onApprove,
    required this.onReject,
  });

  final StudentLeaveRecord record;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final showActions = record.status.canTeacherAudit;

    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(record: record),
          SizedBox(height: ui(8)),
          _CardBody(record: record),
          if (showActions) ...[
            SizedBox(height: ui(8)),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '驳回',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    expand: true,
                    onTap: onReject,
                  ),
                ),
                SizedBox(width: ui(12)),
                Expanded(
                  child: AppButton(
                    label: record.status == StudentLeaveStatus.waitingParent
                        ? '代家长确认并通过'
                        : '通过',
                    size: AppButtonSize.sm,
                    expand: true,
                    onTap: onApprove,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.record});

  final StudentLeaveRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final avatar = record.headUrl;
    return Row(
      children: [
        _StudentAvatar(name: record.studentName, avatarUrl: avatar),
        SizedBox(width: ui(8)),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                Text(
                  record.studentName,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontWeight: AppFont.w500,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: ui(4)),
                Text(
                  record.studentNo,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontWeight: AppFont.w400,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: ui(12)),
                Text(
                  record.leaveType,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontWeight: AppFont.w400,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: ui(12)),
                Text(
                  record.durationLabel,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontWeight: AppFont.w400,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        _StatusBadge(status: record.status),
      ],
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppAvatar(name: name, url: avatarUrl?.trim() ?? '', size: ui(40));
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final StudentLeaveStatus status;

  @override
  Widget build(BuildContext context) {
    return AppStatusTag(
      label: status.label,
      tone: switch (status) {
        StudentLeaveStatus.waitingParent ||
        StudentLeaveStatus.waitingTeacher => AppTone.warning,
        StudentLeaveStatus.approved => AppTone.success,
        StudentLeaveStatus.parentRejected ||
        StudentLeaveStatus.teacherRejected => AppTone.danger,
      },
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.record});

  final StudentLeaveRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(16)),
      decoration: BoxDecoration(
        color: _kBoardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(label: '请假时间：', value: record.timeRange),
          SizedBox(height: ui(6)),
          _InfoLine(label: '请假事由：', value: record.reason),
          SizedBox(height: ui(6)),
          _InfoLine(label: '申请时间：', value: record.appliedAt),
          SizedBox(height: ui(6)),
          _InfoLine(label: '申请路径：', value: record.path),
          SizedBox(height: ui(8)),
          _StepperBar(
            parent: record.parentStep,
            headTeacher: record.headTeacherStep,
          ),
          SizedBox(height: ui(8)),
          _InfoLine(label: '备注：', value: record.note),
        ],
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
        SizedBox(
          width: ui(64),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// —— 审批 stepper：家长 → 班主任 ————————————————————————————————————

class _StepperBar extends StatelessWidget {
  const _StepperBar({required this.parent, required this.headTeacher});

  final StudentLeaveStepStatus parent;
  final StudentLeaveStepStatus headTeacher;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(28),
      child: Row(
        children: [
          _StepNode(label: '家长', status: parent, isFirst: true),
          Expanded(
            child: Container(height: ui(1), color: _kBorderHair),
          ),
          _StepNode(label: '班主任', status: headTeacher, isFirst: false),
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.label,
    required this.status,
    required this.isFirst,
  });

  final String label;
  final StudentLeaveStepStatus status;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: ui(14),
          height: ui(14),
          decoration: const BoxDecoration(
            color: AppColors.brandWash,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: ui(8),
            height: ui(8),
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 1),
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontWeight: AppFont.w400,
            height: 1.0,
          ),
        ),
        SizedBox(width: ui(8)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
          decoration: BoxDecoration(
            color: status == StudentLeaveStepStatus.approved
                ? AppColors.surface
                : status.softBg,
            borderRadius: BorderRadius.circular(ui(4)),
          ),
          child: Text(
            status.label,
            style: TextStyle(
              fontSize: ui(12),
              color: status == StudentLeaveStepStatus.approved
                  ? _kTextHint
                  : status.color,
              fontWeight: AppFont.w400,
              height: 15.24 / 12,
            ),
          ),
        ),
      ],
    );
  }
}

// —— 审批中卡片 通过 / 驳回 按钮 ————————————————————————————————————

// —— 审批意见弹窗（通过 / 驳回共用，默认预填审核理由） ——————————————————

Future<String?> _showTeacherAuditReasonDialog(
  BuildContext context, {
  required StudentLeaveRecord record,
  required String title,
  required String fieldLabel,
  required String initialText,
}) {
  final controller = TextEditingController(text: initialText);
  return showScaledDialog<String>(
    context: context,
    barrierColor: AppColors.ink.withValues(alpha: 0.80),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return GradientHeaderDialog(
        title: title,
        titlePaddingTop: 40,
        width: 428,
        contentPadding: EdgeInsets.fromLTRB(ui(40), ui(40), ui(40), ui(30)),
        actionBar: AppDialogActionBar(
          confirmLabel: '确认',
          cancelLabel: '取消',
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () {
            final text = controller.text.trim();
            if (text.isEmpty) {
              AppToast.show(dialogContext, '请填写审批意见');
              return;
            }
            Navigator.of(dialogContext).pop(text);
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '学生 ${record.studentName}（${record.studentNo}）· ${record.leaveType}',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextDark,
                fontWeight: AppFont.w500,
                height: 20 / 16,
              ),
            ),
            SizedBox(height: ui(15)),
            Text(
              fieldLabel,
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontWeight: AppFont.w500,
                height: 20 / 14,
              ),
            ),
            SizedBox(height: ui(15)),
            Container(
              height: ui(80),
              padding: EdgeInsets.symmetric(
                horizontal: ui(16),
                vertical: ui(12),
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderSoft, width: 1),
              ),
              child: AppTextField(
                controller: controller,
                autofocus: true,
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
                  hintText: '请输入审批意见',
                  hintStyle: TextStyle(
                    fontSize: ui(14),
                    color: _kTextHintLight,
                    fontWeight: AppFont.w400,
                    height: 20 / 14,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
