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
//   2. 4 张统计卡（100 高）：待我审批 / 待家长确认 / 已通过 / 已驳回。
//   3. 黑底状态页签 + 324×44 搜索框 + 双列卡片网格（家长 → 班主任 stepper）；
//      卡片：40 方头像、方角状态标签、40 高「通过 / 驳回」按钮（主按钮在左）。
//
// 版式按音乐之路原版还原（横幅、页签、搜索、头像、标签用智慧校园共享组件）；
// 状态名称、「代家长确认并通过」和审批步骤是本工程的内容，保留。
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_response.dart';
import '../../../core/widgets/scaled_dialog.dart';
import 'widgets/smart_campus_dark_tabs.dart';
import 'widgets/smart_campus_filter_bar.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_square_avatar.dart';
import 'widgets/smart_campus_square_tag.dart';
import '../../shell/ui/shell_layout.dart';
import 'widgets/smart_campus_stat_card.dart';
import '../data/student_leave_data.dart';
import '../data/teacher_repository.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

// —— 颜色（原版色值；紫色统一为品牌紫）————————————————————————————————
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextHintLight = Color(0xFFCECED1);
const Color _kPurple = AppColors.brand;
const Color _kPurpleSoftBg = Color(0xFFDAD2FF);
const Color _kGreen = Color(0xFF12CE51);
const Color _kGreenSoftBg = Color(0xFFE4FFED);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFFE4E5);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeSoftBg = Color(0xFFFFEDD3);

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

  List<int>? get apiStatuses => switch (this) {
    _StatusTab.mine => StudentLeaveStatus.teacherPendingCodes,
    _StatusTab.reviewing => const [0],
    _StatusTab.approved => const [3],
    _StatusTab.rejected => const [2, 4],
    _ => null,
  };
}

extension _StudentLeaveStatusStyle on StudentLeaveStatus {
  Color get bg => switch (this) {
    StudentLeaveStatus.waitingParent => _kOrangeSoftBg,
    StudentLeaveStatus.waitingTeacher => _kPurpleSoftBg,
    StudentLeaveStatus.parentRejected => _kRedSoftBg,
    StudentLeaveStatus.approved => _kGreenSoftBg,
    StudentLeaveStatus.teacherRejected => _kRedSoftBg,
  };

  Color get fg => switch (this) {
    StudentLeaveStatus.waitingParent => _kOrange,
    StudentLeaveStatus.waitingTeacher => _kPurple,
    StudentLeaveStatus.parentRejected => _kRed,
    StudentLeaveStatus.approved => _kGreen,
    StudentLeaveStatus.teacherRejected => _kRed,
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
  final _searchCtrl = TextEditingController();
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final repo = ref.read(teacherRepositoryProvider);
    final results = await Future.wait([
      for (final tab in [
        _StatusTab.mine,
        _StatusTab.reviewing,
        _StatusTab.approved,
        _StatusTab.rejected,
      ])
        repo.headTeacherStudentLeaveList(
          current: 1,
          size: 1,
          statusList: tab.apiStatuses,
        ),
    ]);
    if (!mounted) return;

    int total(ApiResponse resp) => resp.isSuccess
        ? parseStudentLeaveTotal(resp.data) ??
              parseStudentLeaveList(resp.data).length
        : 0;

    setState(() {
      _pendingCount = total(results[0]);
      _reviewingCount = total(results[1]);
      _approvedCount = total(results[2]);
      _rejectedCount = total(results[3]);
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
      statusList: _tab.apiStatuses,
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
            .where((r) => r.status == StudentLeaveStatus.waitingParent)
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
      bodyTopClipRadius: 8,
      header: SmartCampusPageBanner(title: '请假审批', onBack: widget.onBack),
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
                current: _tab,
                searchController: _searchCtrl,
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
    required this.current,
    required this.onTap,
    required this.searchController,
    required this.onSearchChanged,
  });

  final _StatusTab current;
  final ValueChanged<_StatusTab> onTap;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 原版：左黑底状态页签（带描边）+ 右 324×44 搜索，两端对齐。
    final tabs = SmartCampusDarkTabs<_StatusTab>(
      segments: [
        for (final t in _StatusTab.values) AppSegment(value: t, label: t.label),
      ],
      value: current,
      onChanged: onTap,
    );
    final search = SmartCampusFilterSearchField(
      controller: searchController,
      hintText: '搜索姓名、学号、手机、宿舍、家长',
      onChanged: onSearchChanged,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // 6 个页签约 506 宽，1024 横屏下与 324 的搜索并排差二十多像素：
        // 搜索框收窄到剩余宽度，仍保持原版的一行；再窄才折行。
        if (constraints.maxWidth < ui(760)) {
          return SmartCampusFilterRow(
            useWrap: true,
            leading: tabs,
            search: search,
          );
        }
        return Row(
          children: [
            tabs,
            SizedBox(width: ui(12)),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: search),
            ),
          ],
        );
      },
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
        color: Colors.white,
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
                  child: _CardActionButton(
                    // 家长还没确认时班主任可以代为确认，按钮写明后果。
                    label: record.status == StudentLeaveStatus.waitingParent
                        ? '代家长确认并通过'
                        : '通过',
                    isPrimary: true,
                    onTap: onApprove,
                  ),
                ),
                SizedBox(width: ui(12)),
                Expanded(
                  child: _CardActionButton(
                    label: '驳回',
                    isPrimary: false,
                    onTap: onReject,
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
    // 原版 40 方头像、圆角 8，没有照片时浅紫底 + 姓氏。
    return SmartCampusSquareAvatar(
      name: name,
      url: avatarUrl?.trim() ?? '',
      size: 40,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final StudentLeaveStatus status;

  @override
  Widget build(BuildContext context) {
    // 原版方角状态标签：内距 4×2、圆角 4、12 号字（行高 15.24）。
    return SmartCampusSquareTag(
      label: status.label,
      background: status.bg,
      foreground: status.fg,
      height: 19.24,
      horizontalPadding: 4,
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
            color: Color(0xFFF7F2FF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: ui(8),
            height: ui(8),
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
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
                ? Colors.white
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

/// 原版卡片操作按钮：高 40、圆角 8、14 号字；主按钮品牌紫渐变，次按钮白底描边。
class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [AppColors.brandSoft, AppColors.brand],
                )
              : null,
          color: isPrimary ? null : Colors.white,
          border: Border.all(color: _kBorderSoft, width: 1),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(14),
            color: isPrimary ? Colors.white : _kTextDark,
            fontWeight: AppFont.w400,
            height: 24 / 14,
          ),
        ),
      ),
    );
  }
}

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
    barrierColor: Colors.black.withValues(alpha: 0.80),
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
