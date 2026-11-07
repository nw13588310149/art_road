// =============================================================================
// 管理员端「教师请假审批」独立页面
//
// 入口：admin 首页快捷区「教师请假审批」按钮 → controller.openDormLeaveApproval()
//      → mainView == dormLeaveApproval + role == admin → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高，4deg #F9EDFF→white 渐变，圆角 16）：
//      - 左 12 返回按钮 32×32 白底 outline #F3F2F3。
//      - 居中标题 "教师请假审批" 16/600 + 副标题
//        副标题「审批教职工的请假申请」
//   2. 3 张统计卡（100 高，flex 1 1 0，间距 12，196deg 渐变白底，圆角 12）：
//      A. 「待审批」紫渐变 #E7DCFF→white 73%
//      B. 「已通过」绿渐变 #DCFFE7→white 73%
//      C. 「已拒绝」红渐变 #FFE2DC→white 73%
//      数值 32 Barlow / 标签 14/500 black。
//   3. 提示行 12/#B6B5BB「默认由家长在小程序审批后再由班主任审批；已与
//      家长充分沟通的可选择班主任直接审批。补课协调以教务安排为准。」
//   4. 控制条：左侧白色 4 padding 圆角 8 容器套 4 枚 pill：
//      全部 / 待审批 / 已通过 / 已拒绝（激活态 #0B081A 黑底白字）；
//      右侧 "审批中 N 条" 标签（数字 #715EFE）+ 紫色渐变 "发起申请" 按钮。
//   5. 双列卡片网格（每张 477，padding 12 白底圆角 12，gap 16）：
//      · header：头像 40 + 姓名 14/500 + 工号 12/#B6B5BB + "病假" 12 +
//        "时长1天" 12/#6D6B75 + 状态徽章。
//      · 灰底信息块 #F5F6FA padding 16：请假时间 / 请假事由 / 联系电话 /
//        申请时间 / 交接说明（label 12/#B6B5BB + 值 12/#0B081A）。
//      · 仅"待审批"卡片 footer 多一行：紫渐变"通过" + 描边"驳回"，
//        "驳回"打开 GradientHeaderDialog 填理由。
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_response.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import '../data/teacher_leave_data.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = AppColors.page;
const Color _kBoardBg = AppColors.surfaceSubtle;
const Color _kBorderSoft = AppColors.lineSoft;
const Color _kTextDark = AppColors.ink;
const Color _kTextSecondary = AppColors.textSecondary;
const Color _kTextHint = AppColors.textPlaceholder;
const Color _kTextHintLight = AppColors.textTertiary;
const Color _kPurple = AppColors.brand;

// —— 状态 ————————————————————————————————————————————————————————
enum _StatusTab {
  all('全部'),
  pending('待审批'),
  approved('已通过'),
  rejected('已驳回');

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
  AppTone get tone => switch (this) {
    TeacherLeaveStatus.pending => AppTone.warning,
    TeacherLeaveStatus.approved => AppTone.success,
    TeacherLeaveStatus.rejected => AppTone.danger,
  };
}

// —— 顶级视图 ——————————————————————————————————————————————————————

class AdminDormLeaveApprovalView extends ConsumerStatefulWidget {
  const AdminDormLeaveApprovalView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminDormLeaveApprovalView> createState() =>
      _AdminDormLeaveApprovalViewState();
}

class _AdminDormLeaveApprovalViewState
    extends ConsumerState<AdminDormLeaveApprovalView> {
  _StatusTab _tab = _StatusTab.all;
  List<TeacherLeaveRecord> _requests = const [];
  int _pendingCount = 0;
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
    final repo = ref.read(adminRepositoryProvider);
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
      _loading = true;
      _loadError = null;
    });
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.teacherLeaveList(
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
      _requests = parseTeacherLeaveList(resp.data);
      _loading = false;
      _loadError = null;
    });
  }

  Future<void> _reloadAll() async {
    await Future.wait([_loadStats(), _loadList()]);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusSecondaryPageShell(
      backgroundColor: _kPageBg,
      bodyTopClipRadius: 8,
      header: AppPageHeader(
        title: '教职工请假审批',
        subtitle: '审批教职工的请假申请',
        onBack: widget.onBack,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsRow(
            pendingCount: _pendingCount,
            approvedCount: _approvedCount,
            rejectedCount: _rejectedCount,
          ),
          SizedBox(height: ui(16)),
          AppTabs<_StatusTab>(
            tabs: [
              for (final t in _StatusTab.values)
                AppTab(
                  value: t,
                  label: t.label,
                  count: switch (t) {
                    _StatusTab.all => null,
                    _StatusTab.pending => _pendingCount,
                    _StatusTab.approved => _approvedCount,
                    _StatusTab.rejected => _rejectedCount,
                  },
                ),
            ],
            value: _tab,
            onChanged: (t) {
              if (_tab == t) return;
              setState(() => _tab = t);
              unawaited(_loadList());
            },
          ),
          SizedBox(height: ui(16)),
          MainContentLoadingShell(
            loading: _loading && _requests.isEmpty,
            minHeight: ui(200),
            child: _CardsGrid(
              records: _requests,
              emptyMessage: _loadError ?? '暂无相关申请',
              onApprove: _onApprove,
              onReject: _onReject,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onApprove(TeacherLeaveRecord record) async {
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.teacherLeaveAudit(id: record.id, status: 1);
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg, type: AppToastType.error);
      return;
    }
    AppToast.show(context, '已通过 ${record.teacherName} 的${record.leaveType}申请');
    await _reloadAll();
  }

  Future<void> _onReject(TeacherLeaveRecord record) async {
    final reason = await _showRejectDialog(context, record: record);
    if (!mounted) return;
    if (reason == null || reason.trim().isEmpty) return;

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.teacherLeaveAudit(
      id: record.id,
      status: 2,
      auditReason: reason.trim(),
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.displayMsg, type: AppToastType.error);
      return;
    }
    AppToast.show(context, '已驳回 ${record.teacherName} 的${record.leaveType}申请');
    await _reloadAll();
  }
}

// —— Banner ————————————————————————————————————————————————————————

// —— 3 张统计卡 ——————————————————————————————————————————————————————

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
            backgroundAsset: AppAssets.adminStaffLeaveStatCard1,
            label: '待审批',
            value: pendingCount,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminStaffLeaveStatCard2,
            label: '已通过',
            value: approvedCount,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminStaffLeaveStatCard3,
            label: '已驳回',
            value: rejectedCount,
          ),
        ),
      ],
    );
  }
}

// —— 控制条：左 tabs + 右 "审批中 N 条" + 紫渐变 "发起申请" ——————————

// —— 卡片网格 ——————————————————————————————————————————————————————

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({
    required this.records,
    required this.emptyMessage,
    required this.onApprove,
    required this.onReject,
  });

  final List<TeacherLeaveRecord> records;
  final String emptyMessage;
  final ValueChanged<TeacherLeaveRecord> onApprove;
  final ValueChanged<TeacherLeaveRecord> onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      return AppCard(
        child: AppEmptyState(
          icon: Icons.event_note_outlined,
          title: emptyMessage,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gap = ui(16);
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

  final TeacherLeaveRecord record;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final showActions = record.status == TeacherLeaveStatus.pending;

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
                    label: '通过',
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

  final TeacherLeaveRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        _LeaveAvatar(name: record.teacherName, avatarUrl: record.headUrl),
        SizedBox(width: ui(8)),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                Text(
                  record.teacherName,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontWeight: AppFont.w500,
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

class _LeaveAvatar extends StatelessWidget {
  const _LeaveAvatar({required this.name, this.avatarUrl});

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

  final TeacherLeaveStatus status;

  @override
  Widget build(BuildContext context) {
    return AppStatusTag(label: status.label, tone: status.tone);
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.record});

  final TeacherLeaveRecord record;

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
          _InfoLine(label: '联系电话：', value: record.contact),
          SizedBox(height: ui(6)),
          _InfoLine(label: '申请时间：', value: record.appliedAt),
          SizedBox(height: ui(6)),
          _InfoLine(label: '交接说明：', value: record.handoff),
          if (record.status != TeacherLeaveStatus.pending) ...[
            if (record.auditTime.isNotEmpty) ...[
              SizedBox(height: ui(6)),
              _InfoLine(label: '审批时间：', value: record.auditTime),
            ],
            if (record.auditReason != null &&
                record.auditReason!.isNotEmpty) ...[
              SizedBox(height: ui(6)),
              _InfoLine(label: '审批意见：', value: record.auditReason!),
            ],
          ],
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
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontWeight: AppFont.w400,
            height: 1.5,
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

// —— 通过 / 驳回 按钮 ————————————————————————————————————————————

// —— 驳回弹窗 ————————————————————————————————————————————————————

Future<String?> _showRejectDialog(
  BuildContext context, {
  required TeacherLeaveRecord record,
}) {
  final controller = TextEditingController();
  return showScaledDialog<String>(
    context: context,
    barrierColor: AppColors.ink.withValues(alpha: 0.80),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return GradientHeaderDialog(
        title: '驳回申请',
        titlePaddingTop: 40,
        width: 428,
        contentPadding: EdgeInsets.fromLTRB(ui(40), ui(40), ui(40), ui(30)),
        actionBar: AppDialogActionBar(
          confirmLabel: '确认',
          cancelLabel: '取消',
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () => Navigator.of(dialogContext).pop(controller.text),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '教师 ${record.teacherName} · ${record.leaveType}',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextDark,
                fontWeight: AppFont.w500,
                height: 20 / 16,
              ),
            ),
            SizedBox(height: ui(15)),
            Text(
              '驳回说明',
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
                  hintText: '请输入',
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
  );
}
