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
//        12/#B6B5BB「教师须在教师端提交申请；本页为管理端教务审批台。」
//   2. 3 张统计卡（100 高，flex 1 1 0，间距 12，196deg 渐变白底，圆角 12）：
//      A. 「待审批」紫渐变 #E7DCFF→white 73%
//      B. 「已通过」绿渐变 #DCFFE7→white 73%
//      C. 「已拒绝」红渐变 #FFE2DC→white 73%
//      数值 32 Barlow / 标签 14/500 black。
//   3. 提示行 12/#B6B5BB「默认由家长在小程序审批后再由班主任审批；已与
//      家长充分沟通的可选择班主任直接审批。补课协调以教务安排为准。」
//   4. 控制条：左侧白色 4 padding 圆角 8 容器套 4 枚 pill：
//      全部 / 待审批 / 已通过 / 已拒绝（激活态 #0B081A 黑底白字）；
//      右侧 "审批中 N 条" 标签（数字 #8741FF）+ 紫色渐变 "发起申请" 按钮。
//   5. 双列卡片网格（每张 477，padding 12 白底圆角 12，gap 16）：
//      · header：头像 40 + 姓名 14/500 + 工号 12/#B6B5BB + "病假" 12 +
//        "时长1天" 12/#6D6B75 + 状态徽章。
//      · 灰底信息块 #F5F6FA padding 16：请假时间 / 请假事由 / 联系电话 /
//        申请时间 / 交接说明（label 12/#B6B5BB + 值 12/#0B081A）。
//      · 仅"待审批"卡片 footer 多一行：紫渐变"通过" + 描边"驳回"，
//        "驳回"打开 GradientHeaderDialog 填理由。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_response.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import '../data/teacher_leave_data.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextHintLight = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kGreen = Color(0xFF0CAC40);
const Color _kGreenSoftBg = Color(0xFFE4FFED);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFFE4E5);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeSoftBg = Color(0xFFFFEDD3);

// —— 状态 ————————————————————————————————————————————————————————
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
        _loadError =
            resp.displayMsg;
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
      header: _Banner(onBack: widget.onBack),
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
                '教师提交申请后由教务老师在本页审批；批准或拒绝后将同步至教师端。',
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
    final resp = await repo.teacherLeaveAudit(
      id: record.id,
      status: 1,
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(
        context,
        resp.displayMsg,
        type: AppToastType.error,
      );
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
      AppToast.show(
        context,
        resp.displayMsg,
        type: AppToastType.error,
      );
      return;
    }
    AppToast.show(
      context,
      '已驳回 ${record.teacherName} 的${record.leaveType}申请',
    );
    await _reloadAll();
  }
}

// —— Banner ————————————————————————————————————————————————————————

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
                    '教师请假审批',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  Text(
                    '教师须在教师端提交请假申请；本页为管理端统一审批入口，与学生请假、班主任审批流程相互独立。',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            label: '已拒绝',
            value: rejectedCount,
          ),
        ),
      ],
    );
  }
}

// —— 控制条：左 tabs + 右 "审批中 N 条" + 紫渐变 "发起申请" ——————————

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.current,
    required this.onTap,
  });

  final _StatusTab current;
  final ValueChanged<_StatusTab> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      // 用 minHeight 而不是固定 height：fixed 44 + 中文字行高 1.0 会上下
      // 截顶（图：待审批 / 已通过 / 已拒绝 像被切了一刀）。
      constraints: BoxConstraints(minHeight: ui(44)),
      padding: EdgeInsets.fromLTRB(ui(4), ui(4), ui(3), ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _StatusTab.values.length; i++) ...[
            if (i != 0) SizedBox(width: ui(8)),
            _TabPill(
              label: _StatusTab.values[i].label,
              active: _StatusTab.values[i] == current,
              onTap: () => onTap(_StatusTab.values[i]),
            ),
          ],
        ],
      ),
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
        // 中文 PingFang SC 行高 1.2 留出 0.2em 内边距；padding 收到 vertical 7
        // 让 36 高内容能完整放下文字，避免上下被切。
        padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(7)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.2,
          ),
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
                    label: '通过',
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
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.0,
                  ),
                ),
                if (record.contact != '—') ...[
                  SizedBox(width: ui(4)),
                  Text(
                    record.contact,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.0,
                    ),
                  ),
                ],
                SizedBox(width: ui(12)),
                Text(
                  record.leaveType,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
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
                    fontFamily: 'PingFang SC',
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
    final initial = name.isNotEmpty ? name.characters.first : '·';
    final placeholder = Container(
      width: ui(40),
      height: ui(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDAD2FF),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(16),
          height: 1.0,
          fontWeight: AppFont.w600,
          color: _kPurple,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
    final url = avatarUrl?.trim() ?? '';
    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: Image.network(
        url,
        width: ui(40),
        height: ui(40),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
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
            fontFamily: 'PingFang SC',
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

// —— 通过 / 驳回 按钮 ————————————————————————————————————————————

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(40),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: isPrimary ? null : Colors.white,
          border: Border.all(color: _kBorderSoft, width: 1),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: isPrimary ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 24 / 14,
          ),
        ),
      ),
    );
  }
}

// —— 驳回弹窗 ————————————————————————————————————————————————————

Future<String?> _showRejectDialog(
  BuildContext context, {
  required TeacherLeaveRecord record,
}) {
  final controller = TextEditingController();
  return showScaledDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.80),
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
                fontFamily: 'PingFang SC',
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
                fontFamily: 'PingFang SC',
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
                color: Colors.white,
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
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 20 / 14,
                ),
                decoration: InputDecoration(
                  hintText: '请输入',
                  hintStyle: TextStyle(
                    fontSize: ui(14),
                    color: _kTextHintLight,
                    fontFamily: 'PingFang SC',
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
