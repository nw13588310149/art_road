import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_home_data.dart';
import '../data/teacher_notice_data.dart';
import '../state/admin_home_controller.dart';
import '../state/admin_home_state.dart';
import '../state/smart_campus_controller.dart';
import '../state/smart_campus_state.dart';
import 'widgets/role_switcher_buttons.dart';
import 'widgets/smart_campus_avatar_role_badge.dart';
import 'widgets/smart_campus_home_card.dart';
import 'widgets/smart_campus_quick_actions_card.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 管理员智慧校园首页：970×~1100 双栏布局。
///
/// 左主栏（约 696 宽）自上而下：
/// 1. **8 项数据统计**：分两行各 4 卡，白底 + 24/500 数值（今日待办 4
///    用 `#8741FF` 紫高亮） + 12/PingFang 灰色标签。
/// 2. **管理端 10 项快捷入口卡**（697×255）：5×2 网格，每个 cell
///    `43.73 #EAE5FF` 圆角底 + `assets/images/new/智慧校园/管理员/*.png`
///    + 14/PingFang/500 文案；学生管理(1) → 教师管理(2) → 班级编辑(3) →
///    排课与课表(4) → 教师请假审批(5) → 人脸库(6) → 通知管理(7) →
///    群聊(8) → 校长信箱(9) → 校圈治理(10)。
/// 3. **数据看板**：白底卡 + 7 天紫色平滑曲线 + 浅紫渐变填充
///    （5 刻度 100/95/90/85/80/0 + 横轴 周一-周日）。
/// 4. **四端职能 + 工作提醒**：左右两白卡。
///    - 四端职能：4 tab（学生端/任课老师/班主任/宿管端）+ 滚动文案；
///    - 工作提醒：3 条预警卡，红色「预警」徽章 + 标题 + 副标题。
///
/// 整页主内容区统一滚动（左主栏 + 右栏同步），不再由中间左栏单独滚动。
/// - 顶部 72 圆形头像 + 姓名 16/500 + 绿点「运行中」+ 黄底「管理员」徽章；
/// - 「岗位 / 部门 / 权限」3 行键值；
/// - 「校级通知」title + 通知列表，每条卡含分类徽章
///   （教研室 / 场地 / 大师课）+ 内容 + 时间 + 红 / 灰未读点。
///
/// 不带 `onBack` —— 这就是 admin 角色下 `mainView == dashboard` 的根视图，
/// 不会被 `controller.backToDashboard()` 弹出。
class AdminHomeView extends ConsumerStatefulWidget {
  const AdminHomeView({
    super.key,
    required this.shellDisplayName,
    required this.avatarUrl,
    this.availableRoles = const [SmartCampusRole.admin],
    this.selectedRole = SmartCampusRole.admin,
    this.onSelectRole,
    this.onOpenGroupChat,
    this.onOpenPrincipalMailbox,
    this.onOpenSchoolCircle,
    this.onOpenStudentManagement,
    this.onOpenTeacherManagement,
    this.onOpenClassManagement,
    this.onOpenScheduleManagement,
    this.onOpenDormLeaveApproval,
    this.onOpenFaceLibrary,
    this.onOpenNotificationManagement,
    this.onOpenSignManagement,
  });

  final String shellDisplayName;
  final String avatarUrl;

  /// 当前用户在校内可切换的全部身份（admin / headTeacher / teacher /
  /// dormManager / student 子集）。一般来自
  /// `SmartCampusState.availableRoles`，由 `myInfo.role + teacherRole`
  /// 接口共同决定。仅含 `[admin]` 时右栏隐藏「身份切换」区。
  final List<SmartCampusRole> availableRoles;

  /// 当前已选身份。用于让右栏切换按钮高亮当前所在的身份（admin 默认）。
  final SmartCampusRole selectedRole;

  /// 切换身份回调。一般直接传 `SmartCampusController.selectRole`，
  /// state 写入后由 [SmartCampusPage] 重新路由到目标身份的大 dashboard。
  /// 为 `null` 时右栏隐藏「身份切换」区。
  final ValueChanged<SmartCampusRole>? onSelectRole;

  /// 「群聊」/ 「校长信箱」/ 「校圈治理」三个快捷入口共用全站对应页面：
  /// 由 [smartCampusPage] 传入对应的 `controller.openGroupChat` /
  /// `controller.openPrincipalMailbox` / `controller.openSchoolCircle`。
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenPrincipalMailbox;
  final VoidCallback? onOpenSchoolCircle;

  /// 「学生管理」管理端独立入口：进入 [AdminStudentManagementView]。
  final VoidCallback? onOpenStudentManagement;

  /// 「教师管理」管理端独立入口：进入 [AdminTeacherManagementView]。
  final VoidCallback? onOpenTeacherManagement;

  /// 「班级编辑 / 班级编组」管理端独立入口：进入 [AdminClassManagementView]。
  final VoidCallback? onOpenClassManagement;

  /// 「排课与课表」管理端独立入口：进入 [AdminScheduleManagementView]。
  final VoidCallback? onOpenScheduleManagement;

  /// 「教师请假审批」管理端独立入口：进入 [AdminDormLeaveApprovalView]。
  final VoidCallback? onOpenDormLeaveApproval;

  /// 「人脸库」管理端独立入口：进入 [AdminFaceLibraryView]。
  final VoidCallback? onOpenFaceLibrary;

  /// 「通知管理」管理端独立入口：进入 [AdminNotificationManagementView]。
  final VoidCallback? onOpenNotificationManagement;

  /// 「签课管理」管理端独立入口：进入 [AdminSignManagementView]。
  final VoidCallback? onOpenSignManagement;

  @override
  ConsumerState<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends ConsumerState<AdminHomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref
          .read(adminHomeControllerProvider.notifier)
          .initialize(widget.selectedRole),
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    assert(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            ref
                .read(adminHomeControllerProvider.notifier)
                .refresh(role: widget.selectedRole),
          );
        }
      });
      return true;
    }());
  }

  @override
  void didUpdateWidget(covariant AdminHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRole != widget.selectedRole) {
      unawaited(
        ref
            .read(adminHomeControllerProvider.notifier)
            .refresh(role: widget.selectedRole),
      );
    }
  }

  Future<void> _openNoticeDetail(AdminHomeNotice item) async {
    if (item.id.isEmpty) return;
    final detail = await ref
        .read(adminHomeControllerProvider.notifier)
        .loadNoticeDetail(item.id);
    if (!mounted) return;
    if (detail == null) {
      final error = ref.read(adminHomeControllerProvider).noticeError;
      AppToast.show(context, error.isEmpty ? '通知详情加载失败' : error);
      return;
    }
    await showNoticeDetailDialog<void>(
      context: context,
      builder: (ctx) => NoticeDetailGradientDialog(
        title: '通知详情',
        child: _AdminNoticeDetailBody(notice: detail),
      ),
    );
  }

  List<_StatItem> _statsRow1(AdminHomeSummary summary) => [
    _StatItem('${summary.studentCount}', '在籍学生'),
    _StatItem('${summary.teacherCount}', '任课老师'),
    _StatItem('${summary.classCount}', '本学期班级'),
    _StatItem(
      '${summary.toDoTodayCount}',
      '今日待办',
      highlight: summary.toDoTodayCount > 0,
    ),
  ];

  List<_StatItem> _statsRow2(AdminHomeSummary summary) => [
    _StatItem('${summary.leaveStatus0Count}', '教职工待审批请假'),
    _StatItem('${summary.smallCourseSignStatus5Count}', '小课待审核'),
    _StatItem('${summary.userFaceNotRecordedCount}', '人脸待补录'),
    _StatItem('${summary.postStatus0Count}', '今日校圈'),
  ];

  Widget _buildMainColumn(
    AdminHomeState homeState,
    double Function(double) ui,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatsRow(stats: _statsRow1(homeState.summary)),
        SizedBox(height: ui(12)),
        _StatsRow(stats: _statsRow2(homeState.summary)),
        SizedBox(height: ui(16)),
        _QuickActionsCard(
          selectedRole: widget.selectedRole,
          actionBadgeCounts: homeState.actionBadgeCounts,
          onOpenGroupChat: widget.onOpenGroupChat,
          onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
          onOpenSchoolCircle: widget.onOpenSchoolCircle,
          onOpenStudentManagement: widget.onOpenStudentManagement,
          onOpenTeacherManagement: widget.onOpenTeacherManagement,
          onOpenClassManagement: widget.onOpenClassManagement,
          onOpenScheduleManagement: widget.onOpenScheduleManagement,
          onOpenDormLeaveApproval: widget.onOpenDormLeaveApproval,
          onOpenFaceLibrary: widget.onOpenFaceLibrary,
          onOpenNotificationManagement: widget.onOpenNotificationManagement,
          onOpenSignManagement: widget.onOpenSignManagement,
        ),
        SizedBox(height: ui(16)),
        const _SectionTitle(title: '数据看板', trailing: '统计最近七日内学校使用人数'),
        SizedBox(height: ui(12)),
        _DataDashboardCard(chart: homeState.loginChart),
        SizedBox(height: ui(16)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SectionTitle(title: '四端职能'),
                  SizedBox(height: 12),
                  _FourEndsCard(),
                ],
              ),
            ),
            SizedBox(width: ui(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(title: '工作提醒'),
                  SizedBox(height: ui(12)),
                  _WorkRemindersCard(
                    reminders: homeState.workReminders,
                    loading: homeState.loading,
                    error: homeState.workRemindersError,
                    onRefresh: () => ref
                        .read(adminHomeControllerProvider.notifier)
                        .refresh(role: widget.selectedRole),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSidePanel(
    AdminHomeState homeState, {
    required bool fillHeight,
    required String institutionName,
  }) {
    return _AdminSidePanel(
      fillHeight: fillHeight,
      displayName: widget.shellDisplayName,
      avatarUrl: widget.avatarUrl,
      institutionName: institutionName,
      availableRoles: widget.availableRoles,
      selectedRole: widget.selectedRole,
      onSelectRole: widget.onSelectRole,
      notices: homeState.notices,
      noticesLoading: homeState.loading,
      noticeError: homeState.noticeError,
      onRefreshNotices: () => ref
          .read(adminHomeControllerProvider.notifier)
          .refresh(role: widget.selectedRole),
      onOpenNotices: widget.onOpenNotificationManagement,
      onNoticeTap: (item) => unawaited(_openNoticeDetail(item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      smartCampusControllerProvider.select((s) => s.dashboardRefreshEpoch),
      (previous, next) {
        if (previous == null || previous == next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            ref
                .read(adminHomeControllerProvider.notifier)
                .refresh(role: widget.selectedRole),
          );
        });
      },
    );

    final ui = DashboardScaleScope.of(context).ui;
    final homeState = ref.watch(adminHomeControllerProvider);
    final institutionName = ref.watch(shellControllerProvider).schoolName;

    return LayoutBuilder(
      builder: (context, constraints) {
        var cw = constraints.maxWidth;
        if (!cw.isFinite || cw == double.infinity || cw < 2) {
          final w = MediaQuery.sizeOf(context).width;
          cw = (w - ui(ShellLayoutSpec.sidebarWidth) - ui(16) * 2).clamp(
            240.0,
            20000.0,
          );
        }
        final isCompact = cw < ui(900);
        final sidebarWidth = ui(256);
        final contentGap = ui(16);
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : null;

        if (isCompact) {
          return SmartCampusHomeCard(
            height: maxH,
            color: Colors.transparent,
            clipContent: false,
            child: SingleChildScrollView(
              clipBehavior: Clip.none,
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMainColumn(homeState, ui),
                  SizedBox(height: contentGap),
                  _buildSidePanel(
                    homeState,
                    fillHeight: false,
                    institutionName: institutionName,
                  ),
                ],
              ),
            ),
          );
        }

        final mainWidth = math.max(0.0, cw - sidebarWidth - contentGap);

        // 宽屏：主内容区整体滚动，左主栏与右栏同步上移；透明圆角容器裁切。
        return SmartCampusHomeCard(
          height: maxH,
          color: Colors.transparent,
          clipContent: false,
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            physics: const ClampingScrollPhysics(),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: mainWidth,
                    child: _buildMainColumn(homeState, ui),
                  ),
                  SizedBox(width: contentGap),
                  SizedBox(
                    width: sidebarWidth,
                    child: _buildSidePanel(
                      homeState,
                      fillHeight: true,
                      institutionName: institutionName,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 数据
// ============================================================================

class _StatItem {
  const _StatItem(this.value, this.label, {this.highlight = false});

  final String value;
  final String label;
  final bool highlight;
}

class _QuickAction {
  const _QuickAction(
    this.label,
    this.iconAsset, {
    // ignore: unused_element_parameter
    this.badge,
  });

  final String label;
  final String iconAsset;

  /// 右上角红色角标（如 "10+"）。当前所有快捷入口默认不带角标，保留字段
  /// 与渲染逻辑以便后续按需启用某个入口的红点提醒。
  final String? badge;
}

const _quickActions = <_QuickAction>[
  _QuickAction('学生管理', 'assets/images/new/智慧校园/管理员/学生管理.png'),
  _QuickAction('教师管理', 'assets/images/new/智慧校园/管理员/教师管理.png'),
  _QuickAction('班级编辑', 'assets/images/new/智慧校园/管理员/班级编辑.png'),
  _QuickAction('排课与课表', 'assets/images/new/智慧校园/管理员/排课与课表.png'),
  _QuickAction('签课管理', 'assets/images/new/智慧校园/管理员/排课与课表.png'),
  _QuickAction('教师请假审批', 'assets/images/new/智慧校园/管理员/宿管请假审批.png'),
  _QuickAction('人脸库', 'assets/images/new/智慧校园/管理员/人脸库.png'),
  _QuickAction('通知管理', 'assets/images/new/智慧校园/管理员/通知管理.png'),
  _QuickAction('群聊', 'assets/images/new/智慧校园/管理员/群聊.png'),
  _QuickAction('校长信箱', 'assets/images/new/智慧校园/管理员/校长信箱.png'),
  _QuickAction('校圈治理', 'assets/images/new/智慧校园/管理员/校圈.png'),
];

const _mailboxQuickAction = _QuickAction(
  '校长信箱',
  'assets/images/new/智慧校园/管理员/校长信箱.png',
);

List<_QuickAction> _quickActionsForRole(SmartCampusRole role) {
  if (role == SmartCampusRole.principal) {
    final base = _quickActions.where((action) => action.label != '校长信箱');
    return [...base, _mailboxQuickAction];
  }
  return _quickActions;
}

const _overviewTwinCardHeight = 243.0;

const _fourEndsTabs = <String>['学生端', '任课老师', '班主任', '宿管端'];

const _fourEndsContent = <String, ({String title, String body})>{
  '学生端': (title: '核心场景', body: '课表、作业、成绩、课堂签到、请假与补课、查寝管理、校圈、我的班级、群聊'),
  '任课老师': (title: '核心场景', body: '授课课表、签课管理、学生名册、作业批改、考评管理、课堂签到、班级公告、群聊'),
  '班主任': (title: '核心场景', body: '班级工作台、请假审批、查寝历史、学生档案、家校沟通、班级通知、群聊'),
  '宿管端': (title: '核心场景', body: '查寝排班、晨晚查寝、查寝动态、补卡审核、请假审批、宿舍异常处理、宿舍人脸库、通知发布'),
};

const _managerEndContent = '学籍 / 排课与课表 / 人脸库 / 校圈治理 / 通知管理 / 校长信箱 / 校园数据看板';

// ============================================================================
// Section title
// ============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final titleWidget = Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        height: 1.2,
        fontWeight: AppFont.w500,
        color: const Color(0xFF1A1A1A),
        fontFamily: 'PingFang SC',
      ),
    );
    if (trailing == null) {
      return titleWidget;
    }
    return Row(
      children: [
        titleWidget,
        const Spacer(),
        Text(
          trailing!,
          style: TextStyle(
            fontSize: ui(12),
            height: 1.2,
            color: const Color(0xFF6D6B75),
            fontFamily: 'PingFang SC',
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 1. 管理端快捷入口（10 项）
// ============================================================================

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.selectedRole,
    this.actionBadgeCounts = const AdminHomeActionBadgeCounts(),
    this.onOpenGroupChat,
    this.onOpenPrincipalMailbox,
    this.onOpenSchoolCircle,
    this.onOpenStudentManagement,
    this.onOpenTeacherManagement,
    this.onOpenClassManagement,
    this.onOpenScheduleManagement,
    this.onOpenDormLeaveApproval,
    this.onOpenFaceLibrary,
    this.onOpenNotificationManagement,
    this.onOpenSignManagement,
  });

  final SmartCampusRole selectedRole;
  final AdminHomeActionBadgeCounts actionBadgeCounts;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenPrincipalMailbox;
  final VoidCallback? onOpenSchoolCircle;
  final VoidCallback? onOpenStudentManagement;
  final VoidCallback? onOpenTeacherManagement;
  final VoidCallback? onOpenClassManagement;
  final VoidCallback? onOpenScheduleManagement;
  final VoidCallback? onOpenDormLeaveApproval;
  final VoidCallback? onOpenFaceLibrary;
  final VoidCallback? onOpenNotificationManagement;
  final VoidCallback? onOpenSignManagement;

  VoidCallback? _resolveTap(String label) {
    switch (label) {
      case '群聊':
        return onOpenGroupChat;
      case '校长信箱':
        return onOpenPrincipalMailbox;
      case '校圈治理':
        return onOpenSchoolCircle;
      case '学生管理':
        return onOpenStudentManagement;
      case '教师管理':
        return onOpenTeacherManagement;
      case '班级编辑':
        return onOpenClassManagement;
      case '排课与课表':
        return onOpenScheduleManagement;
      case '签课管理':
        return onOpenSignManagement;
      case '教师请假审批':
        return onOpenDormLeaveApproval;
      case '人脸库':
        return onOpenFaceLibrary;
      case '通知管理':
        return onOpenNotificationManagement;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final actions = _quickActionsForRole(selectedRole);
    return SmartCampusQuickActionsCard(
      items: [
        for (final action in actions)
          SmartCampusQuickActionItem(
            label: action.label,
            assetPath: action.iconAsset,
            badgeLabel:
                action.label == '校长信箱' &&
                    selectedRole != SmartCampusRole.principal
                ? null
                : actionBadgeCounts.badgeLabelFor(action.label) ?? action.badge,
            onTap: _resolveTap(action.label),
          ),
      ],
    );
  }
}

// ============================================================================
// 2. 4 列统计卡
// ============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<_StatItem> stats;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(67),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            Expanded(child: _StatCard(item: stats[i])),
            if (i < stats.length - 1) SizedBox(width: ui(16)),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusHomeCard(
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Text(
                item.value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: smartCampusStatValueTextStyle(
                  ui,
                  color: item.highlight
                      ? const Color(0xFF8741FF)
                      : const Color(0xFF0B081A),
                ),
              ),
            ),
          ),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.0,
              color: const Color(0xFF6D6B75),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. 数据看板（紫色平滑曲线）
// ============================================================================

class _DataDashboardCard extends StatelessWidget {
  const _DataDashboardCard({required this.chart});

  final AdminHomeLoginChart chart;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final values = chart.values;
    final xLabels = chart.xLabels;
    final maxY = adminHomeLoginChartMaxY(values);
    final topPadding = ui(16);
    final yAxisWidth = ui(28);
    final chartGap = ui(8);
    final plotLeft = yAxisWidth + chartGap;

    return SmartCampusHomeCard(
      height: ui(261),
      padding: EdgeInsets.fromLTRB(ui(12), ui(20), ui(12), ui(16)),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  painter: _LineChartPainter(
                    values: values,
                    maxY: maxY,
                    topPadding: topPadding,
                    plotLeft: plotLeft,
                    yAxisWidth: yAxisWidth,
                    yLabelStyle: TextStyle(
                      fontSize: ui(12),
                      height: 1.0,
                      color: const Color(0xFFB6B5BB),
                      fontFamily: 'PingFang SC',
                    ),
                    valueLabelStyle: TextStyle(
                      fontSize: ui(11),
                      height: 1.0,
                      color: const Color(0xFF8741FF),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          SizedBox(height: ui(12)),
          Padding(
            padding: EdgeInsets.only(left: plotLeft),
            child: Row(
              children: [
                for (final x in xLabels)
                  Expanded(
                    child: Text(
                      x,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.2,
                        color: const Color(0xFF6D6B75),
                        fontFamily: 'PingFang SC',
                      ),
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

/// 7 点折线 + Y 轴刻度 + 浅紫渐变填充 + 紫色描边 + 白点紫边圆点 + 数值标注。
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.maxY,
    required this.topPadding,
    required this.plotLeft,
    required this.yAxisWidth,
    required this.yLabelStyle,
    required this.valueLabelStyle,
  });

  final List<double> values;
  final double maxY;
  final double topPadding;
  final double plotLeft;
  final double yAxisWidth;
  final TextStyle yLabelStyle;
  final TextStyle valueLabelStyle;

  double _yForValue(double value, double height) {
    return adminHomeLoginChartYForValue(
      value: value,
      height: height,
      topPadding: topPadding,
      maxY: maxY,
    );
  }

  void _paintYAxisGrid(Canvas canvas, Size size) {
    final maxV = maxY <= 0 ? 10.0 : maxY;
    final tickStep = maxV / 5;
    final gridPaint = Paint()
      ..color = const Color(0xFFE6E9F1)
      ..strokeWidth = 1;

    for (var i = 5; i >= 0; i--) {
      final tickValue = i == 0 ? 0.0 : tickStep * i;
      final y = _yForValue(tickValue, size.height);
      final start = Offset(plotLeft, y);
      final end = Offset(size.width, y);

      // 与班级工作台七日查寝一致：Y=0 实线基线，其余刻度虚线。
      if (i == 0) {
        canvas.drawLine(start, end, gridPaint);
      } else {
        _paintDashedGridLine(canvas, start, end, gridPaint);
      }
    }
  }

  static void _paintDashedGridLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segEnd = math.min(drawn + dashWidth, total);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * segEnd,
        paint,
      );
      drawn += dashWidth + dashSpace;
    }
  }

  void _paintYAxisLabels(Canvas canvas, Size size) {
    final maxV = maxY <= 0 ? 10.0 : maxY;
    final tickStep = maxV / 5;

    for (var i = 5; i >= 0; i--) {
      final tickValue = i == 0 ? 0.0 : tickStep * i;
      final y = _yForValue(tickValue, size.height);
      final label = i == 0 ? '0' : (tickStep * i).round().toString();

      final textPainter = TextPainter(
        text: TextSpan(text: label, style: yLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(yAxisWidth - textPainter.width, y - textPainter.height / 2),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    _paintYAxisGrid(canvas, size);

    final chartBottom = size.height;
    final plotWidth = math.max(size.width - plotLeft, 1.0);
    final pointCount = values.length;

    Offset pointAt(int i) {
      final y = _yForValue(values[i], size.height);
      final x = adminHomeLoginChartXForIndex(
        index: i,
        count: pointCount,
        plotLeft: plotLeft,
        plotWidth: plotWidth,
      );
      return Offset(x, y);
    }

    final pts = [for (var i = 0; i < values.length; i++) pointAt(i)];

    // 1. 折线路径（离散日数据用直线，避免 0 被平滑曲线抬高）
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }

    // 2. 填充：闭合到底部
    final fillPath = Path.from(linePath)
      ..lineTo(pts.last.dx, chartBottom)
      ..lineTo(pts.first.dx, chartBottom)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE7D9FF), Color(0x00E7D9FF)],
      ).createShader(Rect.fromLTWH(plotLeft, 0, plotWidth, chartBottom));
    canvas.drawPath(fillPath, fillPaint);

    // 3. 描边
    final strokePaint = Paint()
      ..color = const Color(0xFF8741FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, strokePaint);

    // 4. 圆点 + 数值标注
    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = const Color(0xFF8741FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      canvas.drawCircle(p, 4, dotFill);
      canvas.drawCircle(p, 4, dotStroke);

      final label = values[i].round().toString();
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: valueLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(p.dx - textPainter.width / 2, p.dy - textPainter.height - 6),
      );
    }

    _paintYAxisLabels(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values ||
      old.maxY != maxY ||
      old.topPadding != topPadding ||
      old.plotLeft != plotLeft;
}

// ============================================================================
// 4. 四端职能（tab + 文案）
// ============================================================================

class _FourEndsCard extends StatefulWidget {
  const _FourEndsCard();

  @override
  State<_FourEndsCard> createState() => _FourEndsCardState();
}

class _FourEndsCardState extends State<_FourEndsCard> {
  String _activeTab = _fourEndsTabs.first;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final content = _fourEndsContent[_activeTab]!;

    return SmartCampusHomeCard(
      height: ui(_overviewTwinCardHeight),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _fourEndsTabs.length; i++) ...[
                  _FourEndTab(
                    label: _fourEndsTabs[i],
                    active: _fourEndsTabs[i] == _activeTab,
                    onTap: () => setState(() => _activeTab = _fourEndsTabs[i]),
                  ),
                  if (i < _fourEndsTabs.length - 1) SizedBox(width: ui(12)),
                ],
              ],
            ),
          ),
          SizedBox(height: ui(20)),
          Text(
            content.title,
            style: TextStyle(
              fontSize: ui(14),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            content.body,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.66,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(20)),
          Text(
            '管理端',
            style: TextStyle(
              fontSize: ui(14),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            _managerEndContent,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.66,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _FourEndTab extends StatelessWidget {
  const _FourEndTab({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(8)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0B081A) : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              height: 1.2,
              color: active ? Colors.white : const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. 工作提醒
// ============================================================================

class _WorkRemindersCard extends StatelessWidget {
  const _WorkRemindersCard({
    required this.reminders,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final List<AdminHomeWorkReminder> reminders;
  final bool loading;
  final String error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusHomeCard(
      height: ui(_overviewTwinCardHeight),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: _buildBody(ui),
    );
  }

  Widget _buildBody(double Function(double) ui) {
    if (loading && reminders.isEmpty) {
      return Center(
        child: Text(
          '加载中…',
          style: TextStyle(
            fontSize: ui(12),
            height: 1.4,
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    if (error.isNotEmpty && reminders.isEmpty) {
      return Center(
        child: TextButton(
          onPressed: onRefresh,
          child: Text(
            '工作提醒加载失败，点击重试',
            style: TextStyle(fontSize: ui(12), fontFamily: 'PingFang SC'),
          ),
        ),
      );
    }
    if (reminders.isEmpty) {
      return Center(
        child: Text(
          '暂无工作提醒',
          style: TextStyle(
            fontSize: ui(12),
            height: 1.4,
            color: const Color(0xFFCECED1),
            fontFamily: 'PingFang SC',
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: reminders.length,
      separatorBuilder: (context, index) => SizedBox(height: ui(8)),
      itemBuilder: (context, index) =>
          _WorkReminderCard(item: reminders[index]),
    );
  }
}

class _WorkReminderCard extends StatelessWidget {
  const _WorkReminderCard({required this.item});

  final AdminHomeWorkReminder item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final subtitle = item.subtitle.trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(6),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(ui(4)),
                ),
                child: Text(
                  item.tag,
                  style: TextStyle(
                    fontSize: ui(10),
                    height: 1.2,
                    fontWeight: AppFont.w500,
                    color: const Color(0xFFFF323C),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
              SizedBox(width: ui(6)),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    height: 1.4,
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: ui(6)),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(12),
                height: 1.4,
                color: const Color(0xFFB6B5BB),
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 右侧栏：管理员档案 + 校级通知
// ============================================================================

class _AdminSidePanel extends StatelessWidget {
  const _AdminSidePanel({
    required this.fillHeight,
    required this.displayName,
    required this.avatarUrl,
    this.institutionName = '',
    required this.availableRoles,
    required this.selectedRole,
    required this.onSelectRole,
    required this.notices,
    required this.noticesLoading,
    required this.noticeError,
    required this.onRefreshNotices,
    required this.onOpenNotices,
    this.onNoticeTap,
  });

  final bool fillHeight;
  final String displayName;
  final String avatarUrl;
  final String institutionName;
  final List<SmartCampusRole> availableRoles;
  final SmartCampusRole selectedRole;
  final ValueChanged<SmartCampusRole>? onSelectRole;
  final List<AdminHomeNotice> notices;
  final bool noticesLoading;
  final String noticeError;
  final VoidCallback onRefreshNotices;
  final VoidCallback? onOpenNotices;
  final ValueChanged<AdminHomeNotice>? onNoticeTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 只有用户实际拥有 2+ 个身份（且上层传入了切换回调）时才显示「身份切换」
    // 区块。单身份 admin（普通校长 / 教务管理员）下隐藏，避免出现"只能切到
    // 自己"的无意义按钮。
    final showRoleSwitcher = onSelectRole != null && availableRoles.length > 1;
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _ProfileHeader(
          displayName: displayName,
          avatarUrl: avatarUrl,
          institutionName: institutionName,
          roleBadge: selectedRole.label,
          role: selectedRole,
        ),
        SizedBox(height: ui(20)),
        const _ProfileInfoRows(),
        if (showRoleSwitcher) ...[
          SizedBox(height: ui(20)),
          Text(
            '身份切换',
            style: TextStyle(
              fontSize: ui(14),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'PingFang SC',
            ),
          ),
          SizedBox(height: ui(10)),
          RoleSwitcherButtons(
            availableRoles: availableRoles,
            selectedRole: selectedRole,
            onSelectRole: onSelectRole!,
          ),
        ],
        SizedBox(height: ui(24)),
        Row(
          children: [
            Expanded(
              child: Text(
                '校级通知',
                style: TextStyle(
                  fontSize: ui(16),
                  height: 1.2,
                  fontWeight: AppFont.w500,
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
            if (onOpenNotices != null)
              TextButton(
                onPressed: onOpenNotices,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6D6B75),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '查看全部',
                  style: TextStyle(
                    fontSize: ui(11),
                    color: const Color(0xFF6D6B75),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: ui(12)),
        if (fillHeight)
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: _SchoolNoticeList(
                notices: notices,
                loading: noticesLoading,
                error: noticeError,
                onRefresh: onRefreshNotices,
                onNoticeTap: onNoticeTap,
              ),
            ),
          )
        else
          _SchoolNoticeList(
            notices: notices,
            loading: noticesLoading,
            error: noticeError,
            onRefresh: onRefreshNotices,
            onNoticeTap: onNoticeTap,
          ),
      ],
    );

    final card = SmartCampusHomeCard(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(20)),
      child: panel,
    );
    return fillHeight ? SizedBox.expand(child: card) : card;
  }
}

class _SchoolNoticeList extends StatelessWidget {
  const _SchoolNoticeList({
    required this.notices,
    required this.loading,
    required this.error,
    required this.onRefresh,
    this.onNoticeTap,
  });

  final List<AdminHomeNotice> notices;
  final bool loading;
  final String error;
  final VoidCallback onRefresh;
  final ValueChanged<AdminHomeNotice>? onNoticeTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (loading && notices.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(24)),
        child: Center(
          child: Text(
            '加载中…',
            style: TextStyle(fontSize: ui(12), color: const Color(0xFFB6B5BB)),
          ),
        ),
      );
    }
    if (error.isNotEmpty && notices.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(24)),
        child: Center(
          child: TextButton(
            onPressed: onRefresh,
            child: Text('通知加载失败，点击重试', style: TextStyle(fontSize: ui(12))),
          ),
        ),
      );
    }
    if (notices.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(24)),
        child: Center(
          child: Text(
            '暂无已发布通知',
            style: TextStyle(fontSize: ui(12), color: const Color(0xFFB6B5BB)),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < notices.length; i++) ...[
          if (i > 0) SizedBox(height: ui(8)),
          _SchoolNoticeCard(
            item: notices[i],
            onTap: onNoticeTap == null ? null : () => onNoticeTap!(notices[i]),
          ),
        ],
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.avatarUrl,
    this.institutionName = '',
    this.roleBadge = '教务老师',
    this.role = SmartCampusRole.admin,
  });

  final String displayName;
  final String avatarUrl;
  final String institutionName;
  final String roleBadge;
  final SmartCampusRole role;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: ui(72),
              height: ui(72),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEAE5FF),
                image: avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl.isEmpty
                  ? Center(
                      child: Text(
                        displayName.isEmpty
                            ? 'A'
                            : displayName.characters.first,
                        style: TextStyle(
                          fontSize: ui(28),
                          height: 1.0,
                          color: const Color(0xFF8741FF),
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: ui(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: ui(8)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName.isEmpty ? '教务老师' : displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(16),
                            height: 1.2,
                            fontWeight: AppFont.w500,
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ),
                      SizedBox(width: ui(6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(6),
                          vertical: ui(3),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ui(4)),
                          border: Border.all(
                            color: const Color(0xFFF3F2F3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: ui(6),
                              height: ui(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF12C58A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: ui(4)),
                            Text(
                              '运行中',
                              style: TextStyle(
                                fontSize: ui(11),
                                height: 1.0,
                                color: const Color(0xFF0B081A),
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (institutionName.trim().isNotEmpty) ...[
                    SizedBox(height: ui(4)),
                    Text(
                      institutionName.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.2,
                        color: const Color(0xFF6D6B75),
                        fontFamily: 'Source Han Sans SC',
                        fontWeight: AppFont.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SmartCampusAvatarRoleBadge(label: roleBadge, role: role),
      ],
    );
  }
}

class _ProfileInfoRows extends StatelessWidget {
  const _ProfileInfoRows();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(label: '岗位：', value: '教务老师'),
        SizedBox(height: 4),
        _InfoLine(label: '部门：', value: '教务处'),
        SizedBox(height: 4),
        _InfoLine(label: '权限：', value: '全校管理'),
      ],
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
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            height: 1.2,
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: ui(12),
              height: 1.2,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
      ],
    );
  }
}

class _SchoolNoticeCard extends StatelessWidget {
  const _SchoolNoticeCard({required this.item, this.onTap});

  final AdminHomeNotice item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tagStyle = teacherNoticeTagStyle(item.tag);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Container(
          padding: EdgeInsets.fromLTRB(ui(10), ui(10), ui(16), ui(10)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(6),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: tagStyle.background,
                      borderRadius: BorderRadius.circular(ui(4)),
                    ),
                    child: Text(
                      item.tag,
                      style: TextStyle(
                        fontSize: ui(10),
                        height: 1.2,
                        fontWeight: AppFont.w500,
                        color: tagStyle.foreground,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                  SizedBox(width: ui(6)),
                  Expanded(
                    child: Text(
                      item.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.4,
                        color: const Color(0xFF0B081A),
                        fontFamily: 'Source Han Sans SC',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Transform.translate(
                offset: Offset(0, ui(4)),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    item.time,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: ui(12),
                      height: 1.2,
                      color: const Color(0xFFCECED1),
                      fontFamily: 'Source Han Sans SC',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNoticeDetailBody extends StatelessWidget {
  const _AdminNoticeDetailBody({required this.notice});

  final TeacherNoticeListItem notice;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tagStyle = notice.tagStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          notice.title,
          style: TextStyle(
            fontSize: ui(15),
            color: const Color(0xFF0B081A),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1.5,
          ),
        ),
        SizedBox(height: ui(8)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
              decoration: BoxDecoration(
                color: tagStyle.background,
                borderRadius: BorderRadius.circular(ui(4)),
              ),
              child: Text(
                notice.tag,
                style: TextStyle(
                  fontSize: ui(12),
                  color: tagStyle.foreground,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
            if (notice.author.isNotEmpty && notice.author != '—') ...[
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  notice.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFF6D6B75),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: ui(16)),
        _AdminNoticeDetailRow(label: '类型', value: notice.type),
        _AdminNoticeDetailRow(label: '级别', value: notice.priority),
        _AdminNoticeDetailRow(label: '推送', value: notice.scopeLabel),
        _AdminNoticeDetailRow(
          label: '时间',
          value: notice.publishedAt.isNotEmpty
              ? notice.publishedAt
              : notice.time,
          isLast: true,
        ),
        SizedBox(height: ui(12)),
        Text(
          '内容：',
          style: TextStyle(
            fontSize: ui(13),
            color: const Color(0xFF6D6B75),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
        ),
        SizedBox(height: ui(6)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(10)),
          ),
          child: Text(
            notice.content.isEmpty ? '（暂无正文）' : notice.content,
            style: TextStyle(
              fontSize: ui(13),
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 22 / 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminNoticeDetailRow extends StatelessWidget {
  const _AdminNoticeDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : ui(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(44),
            child: Text(
              '$label：',
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFFB6B5BB),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
