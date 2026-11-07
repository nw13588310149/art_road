import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../../core/widgets/dashboard_course_notice_card.dart';
import '../../school/data/school_repository.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/state/shell_state.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/campus_format.dart';
import '../data/course_sign_data.dart';
import '../data/course_teacher_index_data.dart';
import '../data/head_teacher_index_data.dart';
import '../data/schedule_course_card_builder.dart';
import '../data/smart_campus_count_badge.dart';
import '../data/smart_campus_dashboard_data.dart';
import '../data/student_dormitory_data.dart';
import '../data/student_index_data.dart';
import '../data/student_leave_data.dart';
import '../data/student_exam_schedule_data.dart';
import '../data/student_repository.dart';
import '../data/teacher_leave_data.dart';
import '../data/teacher_notice_data.dart';
import '../data/teacher_repository.dart';
import '../state/smart_campus_controller.dart';
import '../state/smart_campus_state.dart';
import 'widgets/role_switcher_buttons.dart';
import 'widgets/smart_campus_home_card.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'widgets/smart_campus_quick_action_icon.dart';
import 'widgets/smart_campus_quick_actions_card.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

part 'student_dashboard.dart';

/// 用于尚未迁移完成的快捷按钮：弹一个轻提示，避免"点了没反应"。
/// 真实视图迁移到 Flutter 后再把对应 onTap 替换成具体回调。
void _showActionPending(BuildContext context, String label) {
  AppToast.show(context, '「$label」页面迁移中');
}

/// 任课老师 / 班主任端的智慧校园首页布局。
///
/// 与学生端 / 管理员端走的是不同的视觉系统：
/// - 顶部 6 张统计卡（4 个数值 + 「本周课时」 + 紫色「下一节」）
/// - 中间为 `#EFF3FC` 浅紫面板，承载 8 宫功能矩阵
/// - 右栏 256 宽白底面板（排版对齐管理员首页右栏）：头像 + 运行中胶囊 +
///   岗位/权限/职责 + 「身份切换」+ 校级通知列表
///
/// `selectedRole` 来自全局 `smartCampusControllerProvider`，dashboard 内
/// 「任课老师 ↔ 班主任」tab 走 **本地 `_localTab` + 全局 `onSelectRole`** 双轨：
///   - 本地 `_localTab`：负责立刻切换 UI（任何账号都能点），由 `_selectTab`
///     的 `setState` 立即写入。
///   - 全局 `onSelectRole = controller.selectRole`：负责持久化身份。
///     - 多身份教师（任课 + 班主任）：`selectRole` 写入 state，进出子页
///       再返回仍保持当前 tab；进入子页前会再次同步本地 tab。
///     - 仅单身份教师：`selectRole` 对无权限身份会被 ignore，本地 tab
///       仅作一次性预览，重新进入 dashboard 后回到自身角色。
///   - `didUpdateWidget` 仅在 `widget.selectedRole` 真正发生变化时才把
///     `_localTab` 同步为 `widget.selectedRole`，避免没变化时把已经切到的
///     本地预览打回去。
class TeacherDashboardLayout extends ConsumerStatefulWidget {
  const TeacherDashboardLayout({
    super.key,
    required this.selectedRole,
    required this.shellDisplayName,
    required this.avatarUrl,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.availableRoles = const [
      SmartCampusRole.teacher,
      SmartCampusRole.headTeacher,
    ],
    this.onOpenCheckIn,
    this.onOpenMyHomework,
    this.onOpenMyGrades,
    this.onOpenGroupChat,
    this.onOpenSchoolCircle,
    this.onOpenLeaveManagement,
    this.onOpenDormCheck,
    this.onOpenClassAttendance,
    this.onOpenStudentRoster,
    this.onOpenHomeworkReview,
    this.onOpenExamReview,
    this.onOpenMyTeacherLeave,
    this.onOpenLeaveApproval,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
    this.onSelectRole,
    this.roleSwitcher,
  });

  final SmartCampusRole selectedRole;

  /// 当前用户实际可用的全部身份。由 `SmartCampusState.availableRoles`
  /// 提供，来自 `myInfo.role` + `/teacher/teacherRole` 的合并解析结果。
  /// 决定右栏「身份切换」按钮组渲染哪些按钮（默认兜底为「任课老师 +
  /// 班主任」两枚，保持以前的演示行为）。
  final List<SmartCampusRole> availableRoles;
  final String shellDisplayName;
  final String avatarUrl;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;

  /// 班主任专属：进入「班级工作台」三 Tab 页面（与学生「我的班级」分开）。
  final VoidCallback onOpenClassWorkbench;
  final void Function({TeacherScheduleFocusTarget? focus}) onOpenMySchedule;

  /// 学生端「课堂签到」入口；老师端没这个按钮，传 null 即可，
  /// `_TeacherActionPanel` 会在 label 命中但回调为空时走兜底 SnackBar。
  final VoidCallback? onOpenCheckIn;

  /// 学生端「我的作业」入口；老师端没这个按钮，传 null 即可。
  final VoidCallback? onOpenMyHomework;

  /// 学生端「我的考试」入口；老师端没这个按钮，传 null 即可。
  final VoidCallback? onOpenMyGrades;

  /// 「群聊」入口（学生 / 教师 / 班主任 共用同一个聊天页面）。
  final VoidCallback? onOpenGroupChat;

  /// 「校圈」入口：学生 / 教师 / 班主任 / 宿管 共用，进入智慧校园内嵌
  /// [CirclePage]（mainView == schoolCircle）。
  final VoidCallback? onOpenSchoolCircle;

  /// 学生端「请假管理」入口（"请假补课"页面）；其他角色入口名为
  /// "请假审批" / "宿管请假"，走各自独立路由。
  final VoidCallback? onOpenLeaveManagement;

  /// 学生端「查寝管理」入口：仅展示本人查寝记录 + 申请补卡。
  final VoidCallback? onOpenDormCheck;

  /// 任课老师 / 班主任「签课管理」入口：进入签到总览页（5 项统计 +
  /// 最近签课记录 + 今日课程 + 大课/小课签到操作面板）。
  final VoidCallback? onOpenClassAttendance;

  /// 任课老师 / 班主任「学生名册」入口：进入名册总览页（班级 dropdown +
  /// 搜索 + 当前/男/女 3 张统计卡 + 学生卡 3 列网格）。
  final VoidCallback? onOpenStudentRoster;

  /// 任课老师 / 班主任「作业批改」入口：进入"作业与批改"总览页（4 状态 tabs +
  /// 班级 dropdown + 累计/本学期/本月 toggle + 6 项统计 + 左作业列表 + 右
  /// 当前作业的提交学生表，并通过右抽屉发布作业 / 查看历史发布记录 /
  /// 进入作业点评）。
  final VoidCallback? onOpenHomeworkReview;

  /// 任课老师 / 班主任「考评管理」入口：进入"考评管理"总览页（5 状态 tabs +
  /// 班级 dropdown + 累计/本学期/本月 + 6 项统计 + 左考试列表（N/M 提交比）+
  /// 右考试详情(月考同步说明 + 4 项指标 + 学生提交表)，仅查看不可新建考试，
  /// 通过右抽屉查看历史月考 / 进入评分点评）。
  final VoidCallback? onOpenExamReview;

  /// 任课老师 / 班主任「我的请假」入口：查看本人请假记录并发起申请。
  final VoidCallback? onOpenMyTeacherLeave;

  /// 班主任「请假审批」入口：进入审批本班学生请假申请的页面（4 张统计卡 +
  /// 提示与备案说明 + 6 状态 tabs + 搜索框 + 双列申请卡片，审批中卡片
  /// 底部"通过 / 驳回"按钮，"驳回"打开 `GradientHeaderDialog` 弹窗）。
  final VoidCallback? onOpenLeaveApproval;

  /// 班主任「查寝历史」入口：按自然日查看本班住宿生晚查寝/晨查寝打卡
  /// 汇总（顶部 banner + 14 天日期条 + 4 张统计卡 + 晚查寝/晨查寝 tabs +
  /// 宿舍口径 / 学生口径混合卡片网格）。
  final VoidCallback? onOpenDormHistory;

  /// 班主任「家校沟通」入口：与本班学生家长就请假、成绩、心理等进行
  /// 文字沟通（banner + 3 张统计卡 + 全部/未读/待回复 tabs + 搜索 +
  /// 家长对话卡 3 列网格 + 点击进入对话详情弹窗）。
  final VoidCallback? onOpenHomeSchool;

  /// 切换 dashboard 中「任课老师 / 班主任」tab 时的回调：通常由
  /// [SmartCampusPage] 传 `controller.selectRole`，让管理员的切换持久化到
  /// 全局 state；普通教师没有班主任权限时 `selectRole` 会被忽略，UI 也
  /// 不会切换——这是合理的业务约束。
  final ValueChanged<SmartCampusRole>? onSelectRole;

  /// 管理员等多身份用户使用的悬浮身份切换器；教师/班主任传 null。
  final Widget? roleSwitcher;

  @override
  ConsumerState<TeacherDashboardLayout> createState() =>
      _TeacherDashboardLayoutState();
}

class _TeacherDashboardLayoutState
    extends ConsumerState<TeacherDashboardLayout> {
  late SmartCampusRole _localTab;
  List<SmartCampusStatCardData> _stats = const [];
  List<SmartCampusQuickActionData> _actions = const [];
  CourseTeacherIndexRes? _courseTeacherIndex;
  List<_BoardItemData> _headTeacherTodos = const [];
  List<_BoardItemData> _headTeacherRecent = const [];

  @override
  void initState() {
    super.initState();
    _localTab = _coerceRole(widget.selectedRole);
    _syncPlaceholderData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHomeData());
  }

  @override
  void reassemble() {
    super.reassemble();
    assert(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadHomeData();
      });
      return true;
    }());
  }

  void _syncPlaceholderData() {
    final data = smartCampusDashboardDataForRole(_localTab);
    _stats = data.stats;
    _actions = data.actions;
    _headTeacherTodos = const [];
    _headTeacherRecent = const [];
    _courseTeacherIndex = null;
  }

  @override
  void didUpdateWidget(covariant TeacherDashboardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRole != widget.selectedRole) {
      _localTab = _coerceRole(widget.selectedRole);
      _syncPlaceholderData();
      _loadHomeData();
      return;
    }
    // teacherRole 接口晚于用户点「任课老师」时，selectRole 曾因
    // availableRoles 未就绪被忽略；身份列表补齐后把本地 tab 写回全局，
    // 避免进子页再返回后被 initState 拉回班主任。
    if (!_sameTeacherRoleList(
      oldWidget.availableRoles,
      widget.availableRoles,
    )) {
      _persistLocalTabToGlobal();
    }
  }

  bool _sameTeacherRoleList(List<SmartCampusRole> a, List<SmartCampusRole> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /// 把 dashboard 内当前 tab（任课 / 班主任）同步到
  /// [SmartCampusController.selectedRole]，供子页返回后仍能恢复。
  void _persistLocalTabToGlobal() {
    final role = _localTab;
    if (!widget.availableRoles.contains(role)) {
      return;
    }
    if (widget.selectedRole == role) {
      return;
    }
    widget.onSelectRole?.call(role);
  }

  VoidCallback _guardedNav(VoidCallback action) {
    return () {
      _persistLocalTabToGlobal();
      action();
    };
  }

  void Function({TeacherScheduleFocusTarget? focus}) _guardedScheduleNav(
    void Function({TeacherScheduleFocusTarget? focus}) action,
  ) {
    return ({TeacherScheduleFocusTarget? focus}) {
      _persistLocalTabToGlobal();
      action(focus: focus);
    };
  }

  VoidCallback? _guardedNavOptional(VoidCallback? action) {
    if (action == null) {
      return null;
    }
    return _guardedNav(action);
  }

  // 仅允许 tab 在 teacher / headTeacher 之间切换；其他角色容错回退到 teacher。
  SmartCampusRole _coerceRole(SmartCampusRole role) {
    if (role == SmartCampusRole.teacher ||
        role == SmartCampusRole.headTeacher) {
      return role;
    }
    return SmartCampusRole.teacher;
  }

  void _selectTab(SmartCampusRole role) {
    // 跨端身份（admin / dormManager / student）：本地预览没意义（教师
    // dashboard 不能渲染管理员视图），直接交给 controller 切换 state，
    // SmartCampusPage 会重新路由到目标身份的大 dashboard，本 widget 卸载。
    if (role != SmartCampusRole.teacher &&
        role != SmartCampusRole.headTeacher) {
      widget.onSelectRole?.call(role);
      return;
    }
    if (_localTab == role) {
      return;
    }
    // 立刻给 UI 一个回应（任何账号都能点）；
    // 同时把切换持久化给 controller：admin / 多身份教师会写入 state，
    // 单身份的普通教师被 ignore（仅保留本地预览效果）。
    setState(() {
      _localTab = role;
      _syncPlaceholderData();
    });
    widget.onSelectRole?.call(role);
    // teacherRole 尚未返回时 selectRole 可能暂时无效，待 availableRoles
    // 更新后由 didUpdateWidget 再次持久化。
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (_localTab == SmartCampusRole.headTeacher) {
      await _loadHeadTeacherHome();
    } else {
      await _loadCourseTeacherHome();
    }
  }

  Future<void> _loadCourseTeacherHome() async {
    if (!mounted) return;
    final repo = ref.read(teacherRepositoryProvider);
    final now = DateTime.now();
    final weekRange = _currentWeekDateRange(now);

    try {
      final results = await Future.wait([
        repo.courseTeacherIndex(),
        repo.courseList(beginDate: weekRange.$1, endDate: weekRange.$2),
        repo.teacherLeaveList(current: 1, size: 200, status: 0),
      ]);
      if (!mounted) return;

      final indexResp = results[0];
      final weekResp = results[1];
      final myLeaveResp = results[2];
      final weekCount = weekResp.isSuccess
          ? countWeekCoursesFromCourseList(weekResp.data)
          : null;

      if (!indexResp.isSuccess) {
        if (indexResp.msg.isNotEmpty) {
          AppToast.show(context, indexResp.msg);
        }
        return;
      }

      final index = parseCourseTeacherIndexRes(indexResp.data);
      final myLeavePendingCount = myLeaveResp.isSuccess
          ? parseTeacherLeavePendingCount(myLeaveResp.data)
          : 0;
      final base = smartCampusDashboardDataForRole(SmartCampusRole.teacher);
      setState(() {
        _courseTeacherIndex = index;
        _stats = buildCourseTeacherStats(
          index: index,
          weekCourseCount: weekCount,
        );
        _actions = _applyActionBadges(
          base.actions,
          buildCourseTeacherActionBadges(
            index,
            myLeavePendingCount: myLeavePendingCount,
          ),
        );
      });
    } catch (_) {
      // 保留占位统计，避免首页空白。
    }
  }

  Future<void> _loadHeadTeacherHome() async {
    if (!mounted) return;
    final repo = ref.read(teacherRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.headTeacherIndex(),
        repo.teacherLeaveList(current: 1, size: 200, status: 0),
      ]);
      if (!mounted) return;

      final indexResp = results[0];
      final myLeaveResp = results[1];
      if (!indexResp.isSuccess) {
        if (indexResp.msg.isNotEmpty) {
          AppToast.show(context, indexResp.msg);
        }
        return;
      }

      final index = parseHeadTeacherIndexRes(indexResp.data);
      final myLeavePendingCount = myLeaveResp.isSuccess
          ? parseTeacherLeavePendingCount(myLeaveResp.data)
          : 0;
      final base = smartCampusDashboardDataForRole(SmartCampusRole.headTeacher);
      setState(() {
        _stats = buildHeadTeacherStats(index);
        _actions = _applyActionBadges(
          base.actions,
          buildHeadTeacherActionBadges(
            index,
            myLeavePendingCount: myLeavePendingCount,
          ),
        );
        _headTeacherTodos = _mapHeadTeacherBoardItems(
          buildHeadTeacherTodoBoardItems(index),
        );
        _headTeacherRecent = _mapHeadTeacherBoardItems(
          buildHeadTeacherRecentBoardItems(index),
        );
      });
    } catch (_) {
      // 保留占位统计，避免首页空白。
    }
  }

  List<SmartCampusQuickActionData> _applyActionBadges(
    List<SmartCampusQuickActionData> base,
    Map<String, int> badges,
  ) {
    return [
      for (final item in base)
        SmartCampusQuickActionData(
          label: item.label,
          icon: item.icon,
          background: item.background,
          foreground: item.foreground,
          badge: badges[item.label] ?? item.badge,
          imagePath: item.imagePath,
        ),
    ];
  }

  List<_BoardItemData> _mapHeadTeacherBoardItems(
    List<HeadTeacherBoardItem> items,
  ) {
    return [
      for (final item in items)
        _BoardItemData(
          time: item.time,
          title: item.title,
          tag: item.tag,
          status: item.status,
        ),
    ];
  }

  void _handleHeadTeacherTodoTap(String tag) {
    _persistLocalTabToGlobal();
    switch (tag) {
      case '请假':
        widget.onOpenLeaveApproval?.call();
      case '班级':
        widget.onOpenClassWorkbench();
    }
  }

  (String, String) _currentWeekDateRange(DateTime now) {
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final sunday = monday.add(const Duration(days: 6));
    return (_isoDate(monday), _isoDate(sunday));
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      smartCampusControllerProvider.select((s) => s.dashboardRefreshEpoch),
      (previous, next) {
        if (previous == null || previous == next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadHomeData();
        });
      },
    );

    final ui = DashboardScaleScope.of(context).ui;
    final data = smartCampusDashboardDataForRole(_localTab);
    final institutionName = ref.watch(shellControllerProvider).schoolName;
    final onOpenPrincipalMailbox = _guardedNav(widget.onOpenPrincipalMailbox);
    final onOpenMyClass = _guardedNav(widget.onOpenMyClass);
    final onOpenClassWorkbench = _guardedNav(widget.onOpenClassWorkbench);
    final onOpenMySchedule = _guardedScheduleNav(widget.onOpenMySchedule);
    final onOpenCheckIn = _guardedNavOptional(widget.onOpenCheckIn);
    final onOpenMyHomework = _guardedNavOptional(widget.onOpenMyHomework);
    final onOpenMyGrades = _guardedNavOptional(widget.onOpenMyGrades);
    final onOpenGroupChat = _guardedNavOptional(widget.onOpenGroupChat);
    final onOpenSchoolCircle = _guardedNavOptional(widget.onOpenSchoolCircle);
    final onOpenLeaveManagement = _guardedNavOptional(
      widget.onOpenLeaveManagement,
    );
    final onOpenDormCheck = _guardedNavOptional(widget.onOpenDormCheck);
    final onOpenClassAttendance = _guardedNavOptional(
      widget.onOpenClassAttendance,
    );
    final onOpenStudentRoster = _guardedNavOptional(widget.onOpenStudentRoster);
    final onOpenHomeworkReview = _guardedNavOptional(
      widget.onOpenHomeworkReview,
    );
    final onOpenExamReview = _guardedNavOptional(widget.onOpenExamReview);
    final onOpenMyTeacherLeave = _guardedNavOptional(
      widget.onOpenMyTeacherLeave,
    );
    final onOpenLeaveApproval = _guardedNavOptional(widget.onOpenLeaveApproval);
    final onOpenDormHistory = _guardedNavOptional(widget.onOpenDormHistory);
    final onOpenHomeSchool = _guardedNavOptional(widget.onOpenHomeSchool);

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
        final mainWidth = isCompact
            ? cw
            : math.max(0.0, cw - sidebarWidth - contentGap);

        if (isCompact) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.roleSwitcher != null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: widget.roleSwitcher,
                  ),
                  SizedBox(height: ui(12)),
                ],
                _TeacherMainColumn(
                  data: data,
                  stats: _stats,
                  actions: _actions,
                  courseTeacherIndex: _courseTeacherIndex,
                  headTeacherTodos: _headTeacherTodos,
                  headTeacherRecent: _headTeacherRecent,
                  width: mainWidth,
                  fillRemaining: false,
                  onOpenPrincipalMailbox: onOpenPrincipalMailbox,
                  onOpenMyClass: onOpenMyClass,
                  onOpenClassWorkbench: onOpenClassWorkbench,
                  onOpenMySchedule: onOpenMySchedule,
                  onOpenCheckIn: onOpenCheckIn,
                  onOpenMyHomework: onOpenMyHomework,
                  onOpenMyGrades: onOpenMyGrades,
                  onOpenGroupChat: onOpenGroupChat,
                  onOpenSchoolCircle: onOpenSchoolCircle,
                  onOpenLeaveManagement: onOpenLeaveManagement,
                  onOpenDormCheck: onOpenDormCheck,
                  onOpenClassAttendance: onOpenClassAttendance,
                  onOpenStudentRoster: onOpenStudentRoster,
                  onOpenHomeworkReview: onOpenHomeworkReview,
                  onOpenExamReview: onOpenExamReview,
                  onOpenMyTeacherLeave: onOpenMyTeacherLeave,
                  onOpenLeaveApproval: onOpenLeaveApproval,
                  onOpenDormHistory: onOpenDormHistory,
                  onOpenHomeSchool: onOpenHomeSchool,
                  onHeadTeacherTodoTap: _handleHeadTeacherTodoTap,
                ),
                SizedBox(height: ui(16)),
                _TeacherSidebar(
                  data: data,
                  selectedTab: _localTab,
                  onTabSelected: _selectTab,
                  availableRoles: widget.availableRoles,
                  shellDisplayName: widget.shellDisplayName,
                  avatarUrl: widget.avatarUrl,
                  institutionName: institutionName,
                  fillHeight: false,
                ),
              ],
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: mainWidth,
              child: _TeacherMainColumn(
                data: data,
                stats: _stats,
                actions: _actions,
                courseTeacherIndex: _courseTeacherIndex,
                headTeacherTodos: _headTeacherTodos,
                headTeacherRecent: _headTeacherRecent,
                width: mainWidth,
                fillRemaining: true,
                onOpenPrincipalMailbox: onOpenPrincipalMailbox,
                onOpenMyClass: onOpenMyClass,
                onOpenClassWorkbench: onOpenClassWorkbench,
                onOpenMySchedule: onOpenMySchedule,
                onOpenCheckIn: onOpenCheckIn,
                onOpenMyHomework: onOpenMyHomework,
                onOpenMyGrades: onOpenMyGrades,
                onOpenGroupChat: onOpenGroupChat,
                onOpenSchoolCircle: onOpenSchoolCircle,
                onOpenLeaveManagement: onOpenLeaveManagement,
                onOpenDormCheck: onOpenDormCheck,
                onOpenClassAttendance: onOpenClassAttendance,
                onOpenStudentRoster: onOpenStudentRoster,
                onOpenHomeworkReview: onOpenHomeworkReview,
                onOpenExamReview: onOpenExamReview,
                onOpenMyTeacherLeave: onOpenMyTeacherLeave,
                onOpenLeaveApproval: onOpenLeaveApproval,
                onOpenDormHistory: onOpenDormHistory,
                onOpenHomeSchool: onOpenHomeSchool,
                onHeadTeacherTodoTap: _handleHeadTeacherTodoTap,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: sidebarWidth,
              child: _TeacherSidebar(
                data: data,
                selectedTab: _localTab,
                onTabSelected: _selectTab,
                availableRoles: widget.availableRoles,
                shellDisplayName: widget.shellDisplayName,
                avatarUrl: widget.avatarUrl,
                institutionName: institutionName,
                fillHeight: true,
              ),
            ),
            if (widget.roleSwitcher != null)
              Positioned(
                top: ui(6),
                right: sidebarWidth + ui(8),
                child: widget.roleSwitcher!,
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// 主区：顶部统计行 + 中间浅紫面板（功能矩阵）
// =============================================================================

class _TeacherMainColumn extends StatelessWidget {
  const _TeacherMainColumn({
    required this.data,
    required this.stats,
    required this.actions,
    this.courseTeacherIndex,
    this.headTeacherTodos = const [],
    this.headTeacherRecent = const [],
    required this.width,
    required this.fillRemaining,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.onOpenCheckIn,
    this.onOpenMyHomework,
    this.onOpenMyGrades,
    this.onOpenGroupChat,
    this.onOpenSchoolCircle,
    this.onOpenLeaveManagement,
    this.onOpenDormCheck,
    this.onOpenClassAttendance,
    this.onOpenStudentRoster,
    this.onOpenHomeworkReview,
    this.onOpenExamReview,
    this.onOpenMyTeacherLeave,
    this.onOpenLeaveApproval,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
    this.onHeadTeacherTodoTap,
  });

  final SmartCampusDashboardData data;
  final List<SmartCampusStatCardData> stats;
  final List<SmartCampusQuickActionData> actions;
  final CourseTeacherIndexRes? courseTeacherIndex;
  final List<_BoardItemData> headTeacherTodos;
  final List<_BoardItemData> headTeacherRecent;
  final double width;
  final bool fillRemaining;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenClassWorkbench;
  final void Function({TeacherScheduleFocusTarget? focus}) onOpenMySchedule;
  final VoidCallback? onOpenCheckIn;
  final VoidCallback? onOpenMyHomework;
  final VoidCallback? onOpenMyGrades;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenSchoolCircle;
  final VoidCallback? onOpenLeaveManagement;
  final VoidCallback? onOpenDormCheck;
  final VoidCallback? onOpenClassAttendance;
  final VoidCallback? onOpenStudentRoster;
  final VoidCallback? onOpenHomeworkReview;
  final VoidCallback? onOpenExamReview;
  final VoidCallback? onOpenMyTeacherLeave;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenHomeSchool;
  final void Function(String tag)? onHeadTeacherTodoTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final actionPanel = _TeacherActionPanel(
      data: data,
      actions: actions,
      onOpenPrincipalMailbox: onOpenPrincipalMailbox,
      onOpenMyClass: onOpenMyClass,
      onOpenClassWorkbench: onOpenClassWorkbench,
      onOpenMySchedule: onOpenMySchedule,
      onOpenCheckIn: onOpenCheckIn,
      onOpenMyHomework: onOpenMyHomework,
      onOpenMyGrades: onOpenMyGrades,
      onOpenGroupChat: onOpenGroupChat,
      onOpenSchoolCircle: onOpenSchoolCircle,
      onOpenLeaveManagement: onOpenLeaveManagement,
      onOpenDormCheck: onOpenDormCheck,
      onOpenClassAttendance: onOpenClassAttendance,
      onOpenStudentRoster: onOpenStudentRoster,
      onOpenHomeworkReview: onOpenHomeworkReview,
      onOpenExamReview: onOpenExamReview,
      onOpenMyTeacherLeave: onOpenMyTeacherLeave,
      onOpenLeaveApproval: onOpenLeaveApproval,
      onOpenDormHistory: onOpenDormHistory,
      onOpenHomeSchool: onOpenHomeSchool,
    );

    // 任课老师：当前课程 + 今日课表；班主任：待办提醒 + 近期动态。
    Widget bottomSection({required bool fill}) {
      if (data.role == SmartCampusRole.headTeacher) {
        return _HeadTeacherBoardSection(
          fillRemaining: fill,
          todoItems: headTeacherTodos,
          recentItems: headTeacherRecent,
          onTodoItemTap: onHeadTeacherTodoTap,
        );
      }
      return _TeacherScheduleSection(
        fillRemaining: fill,
        onOpenSchedule: onOpenMySchedule,
        courseTeacherIndex: courseTeacherIndex,
      );
    }

    if (fillRemaining) {
      // 父级 (Stack > Positioned(top:0,bottom:0)) 提供了有界高度。
      // 让底部双卡 Expanded 撑满剩余空间。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          _TeacherStatRow(stats: stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          Expanded(child: bottomSection(fill: true)),
        ],
      );
    }

    // 紧凑模式（compact）：父级高度无界，整个主列交给滚动容器承载。
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeacherStatRow(stats: stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          bottomSection(fill: false),
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _TeacherStatRow extends StatelessWidget {
  const _TeacherStatRow({required this.stats, required this.width});

  final List<SmartCampusStatCardData> stats;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: width.isFinite && width > 0 ? width : null,
      height: 67,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s16),
            Expanded(child: _TeacherStatCard(item: stats[i])),
          ],
        ],
      ),
    );
  }
}

/// 学生与教职看板共用的居中指标，数值在上、标签在下。
class _TeacherStatCard extends StatelessWidget {
  const _TeacherStatCard({required this.item});

  final SmartCampusStatCardData item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final countdown = item.label == '距离省统考';
    final highlight = item.label == '下一节' || item.label == '待办';
    return SmartCampusHomeCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s8,
        vertical: AppSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: smartCampusHomeStatValue(
                value: item.value,
                ui: ui,
                color: highlight ? AppColors.brand : AppColors.ink,
                numberColor: countdown ? AppColors.brand : null,
                suffixFontSize: countdown ? 14 : null,
              ),
            ),
          ),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.caption12.copyWith(
              color: AppColors.textSecondary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherActionPanel extends StatelessWidget {
  const _TeacherActionPanel({
    required this.data,
    required this.actions,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenClassWorkbench,
    required this.onOpenMySchedule,
    this.onOpenCheckIn,
    this.onOpenMyHomework,
    this.onOpenMyGrades,
    this.onOpenGroupChat,
    this.onOpenSchoolCircle,
    this.onOpenLeaveManagement,
    this.onOpenDormCheck,
    this.onOpenClassAttendance,
    this.onOpenStudentRoster,
    this.onOpenHomeworkReview,
    this.onOpenExamReview,
    this.onOpenMyTeacherLeave,
    this.onOpenLeaveApproval,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
  });

  final SmartCampusDashboardData data;
  final List<SmartCampusQuickActionData> actions;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenClassWorkbench;
  final void Function({TeacherScheduleFocusTarget? focus}) onOpenMySchedule;
  final VoidCallback? onOpenCheckIn;
  final VoidCallback? onOpenMyHomework;
  final VoidCallback? onOpenMyGrades;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenSchoolCircle;
  final VoidCallback? onOpenLeaveManagement;
  final VoidCallback? onOpenDormCheck;
  final VoidCallback? onOpenClassAttendance;
  final VoidCallback? onOpenStudentRoster;
  final VoidCallback? onOpenHomeworkReview;
  final VoidCallback? onOpenExamReview;
  final VoidCallback? onOpenMyTeacherLeave;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenHomeSchool;

  VoidCallback? _onTapForLabel(String label) {
    switch (label) {
      case '校长信箱':
        return onOpenPrincipalMailbox;
      case '我的班级':
        return onOpenMyClass;
      case '班级工作台':
        // 班主任专属入口：进入独立三 Tab 工作台（概况 / 学生管理 / 成绩），
        // 与学生「我的班级」简版页面分开，避免 selectedRole 误判路由到学生页。
        return onOpenClassWorkbench;
      // "授课课表"是老师端 label，"我的课表"是学生端 label，
      // 但都对应同一个 mainView 切换 (`openMySchedule`)。
      case '授课课表':
      case '我的课表':
        return () => onOpenMySchedule();
      // 学生端独有：课堂签到。老师端没这个按钮，回调可能为 null，由
      // 未配置路由的按钮由 [SmartCampusQuickActionsCard] 兜底弹"页面迁移中"SnackBar。
      case '课堂签到':
        return onOpenCheckIn;
      // 学生端独有：我的作业。老师端的 "作业批改" 是另一条入口，单独处理。
      case '我的作业':
        return onOpenMyHomework;
      // 学生端独有：我的考试，进入「我的考试」总览页（全部考试 + 我的成绩）。
      case '我的考试':
        return onOpenMyGrades;
      // 五端共用：群聊（任一角色点击都进入同一聊天主界面）。
      case '群聊':
        return onOpenGroupChat;
      // 五端共用：「校圈」→ controller.openSchoolCircle() → 智慧校园内嵌页。
      case '校圈':
        return onOpenSchoolCircle;
      // 学生端「我的请假」与教师端同名；学生传 onOpenLeaveManagement，教师传
      // onOpenMyTeacherLeave，按非空回调区分。
      case '我的请假':
        return onOpenLeaveManagement ?? onOpenMyTeacherLeave;
      // 学生端独有：「我的查寝」→ 进入个人查寝/补卡页面。
      case '我的查寝':
        return onOpenDormCheck;
      // 任课老师/班主任专属：「签课管理」→ 进入授课签到总览页（5 项统计 +
      // 最近签课记录 + 今日课程 + 大课/小课双模签到操作面板）。
      case '签课管理':
        return onOpenClassAttendance;
      // 任课老师/班主任专属：「学生名册」→ 进入名册总览页（班级 dropdown +
      // 搜索 + 当前/男/女 3 张统计卡 + 学生卡 3 列网格）。
      case '学生名册':
        return onOpenStudentRoster;
      // 任课老师/班主任专属：「作业批改」→ 进入"作业与批改"总览页（4 状态
      // tabs + 班级 dropdown + 累计/本学期/本月 toggle + 6 项统计 + 左作业
      // 列表 + 右当前作业的提交学生表，支持发布作业 / 历史发布记录 /
      // 作业点评 3 个右抽屉）。
      case '作业批改':
        return onOpenHomeworkReview;
      // 任课老师/班主任专属：「考评管理」→ 进入"考评管理"总览页（5 状态
      // tabs + 班级 dropdown + 累计/本学期/本月 + 6 项统计 + 左考试列表
      // (N/M 提交比) + 右考试详情(月考同步说明 + 4 项指标 + 学生提交表)；
      // 仅可查看与评分，不可新建考试，通过右抽屉历史月考 / 评分 进入操作）。
      case '考评管理':
        return onOpenExamReview;
      // 班主任专属：「请假审批」→ 进入审批本班学生请假申请的总览页（4 张
      // 统计卡 + 提示与备案说明 + 6 状态 tabs + 搜索 + 双列申请卡片，审批中
      // 卡片底部"通过 / 驳回"按钮，"驳回"打开 GradientHeaderDialog 弹窗）。
      case '请假审批':
        return onOpenLeaveApproval;
      // 班主任专属：「查寝历史」→ 进入按自然日查看本班住宿生晚查寝/晨查寝
      // 打卡汇总的总览页（顶部 banner + 14 天日期条 + 4 张统计卡 +
      // 晚查寝 / 晨查寝 tabs + 宿舍口径 / 学生口径混合卡片网格）。
      case '查寝历史':
        return onOpenDormHistory;
      // 班主任专属：「家校沟通」→ 进入与本班学生家长就请假/成绩/心理等
      // 进行文字沟通的总览页（banner + 3 张统计卡 + 全部/未读/待回复 tabs
      // + 搜索 + 家长对话卡 3 列网格 + 点击进入对话详情弹窗）。
      case '家校沟通':
        return onOpenHomeSchool;
      default:
        return null;
    }
  }

  String? _badgeLabelFor(SmartCampusQuickActionData item) {
    if (item.label == '群聊') return null;
    return smartCampusCountBadgeLabel(item.badge);
  }

  @override
  Widget build(BuildContext context) {
    return SmartCampusQuickActionsCard(
      iconSize: kSmartCampusQuickActionIconSize,
      items: [
        for (final item in actions)
          SmartCampusQuickActionItem(
            label: item.label,
            assetPath: item.imagePath ?? '',
            badgeLabel: _badgeLabelFor(item),
            onTap:
                _onTapForLabel(item.label) ??
                () => _showActionPending(context, item.label),
          ),
      ],
    );
  }
}

// =============================================================================
// 右栏：头像 + 运行中 + 岗位信息 + Tab + 通知
// =============================================================================

class _TeacherSidebar extends StatelessWidget {
  const _TeacherSidebar({
    required this.data,
    required this.shellDisplayName,
    required this.avatarUrl,
    required this.fillHeight,
    this.shellUser = const ShellUser(),
    this.studentDormBedLabel,
    this.institutionName = '',
    this.selectedTab,
    this.onTabSelected,
    this.availableRoles = const [
      SmartCampusRole.teacher,
      SmartCampusRole.headTeacher,
    ],
  });

  final SmartCampusDashboardData data;
  // 学生端无身份切换：两者均为 null 时整个切换区不渲染。
  final SmartCampusRole? selectedTab;
  final ValueChanged<SmartCampusRole>? onTabSelected;

  /// 来自 [TeacherDashboardLayout.availableRoles]。当包含 teacher /
  /// headTeacher 之外的身份（admin / dormManager / student）时，使用通
  /// 用的 [RoleSwitcherButtons]；只剩任课老师 + 班主任两枚时退回原先的
  /// 固定 2 Tab，保留单身份教师"本地预览"的演示体验。
  final List<SmartCampusRole> availableRoles;
  final String shellDisplayName;
  final String avatarUrl;
  final ShellUser shellUser;

  /// 学生端侧栏「宿舍」文案；`null` 表示尚未加载。
  final String? studentDormBedLabel;

  /// 当前绑定学校名称（`schoolList.name`）。
  final String institutionName;
  final bool fillHeight;

  /// 判断是否需要走"通用多身份"切换器：只要 availableRoles 出现 teacher /
  /// headTeacher 之外的成员（典型场景：管理员账户、跨端老师），就升级到
  /// 全量按钮列表。
  bool get _hasExtraRoles {
    for (final role in availableRoles) {
      if (role != SmartCampusRole.teacher &&
          role != SmartCampusRole.headTeacher) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final showRoleSwitcher = selectedTab != null && onTabSelected != null;
    final noticePanel = _TeacherNoticePanel(
      role: selectedTab ?? data.role,
      fallbackNotices: data.notices,
    );

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        _TeacherProfileHeader(
          data: data,
          shellDisplayName: shellDisplayName,
          avatarUrl: avatarUrl,
          institutionName: institutionName,
        ),
        SizedBox(height: ui(20)),
        _TeacherProfileInfoRows(
          data: data,
          shellUser: shellUser,
          studentDormBedLabel: studentDormBedLabel,
        ),
        if (showRoleSwitcher) ...[
          SizedBox(height: ui(20)),
          Text('身份切换', style: AppText.body14Strong),
          SizedBox(height: ui(10)),
          // 多身份用户（admin / 跨端教师）走通用按钮组；普通「任课老师 +
          // 班主任」仍走原 2 Tab，保留单身份教师本地预览班主任视图的体验。
          _hasExtraRoles
              ? RoleSwitcherButtons(
                  availableRoles: availableRoles,
                  selectedRole: selectedTab!,
                  onSelectRole: onTabSelected!,
                )
              : _TeacherRoleTabs(
                  selected: selectedTab!,
                  onChanged: onTabSelected!,
                ),
        ],
        SizedBox(height: ui(24)),
        Text('校级通知', style: AppText.title16),
        SizedBox(height: ui(12)),
        if (fillHeight)
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: noticePanel,
            ),
          )
        else
          noticePanel,
      ],
    );

    final card = SmartCampusHomeCard(
      padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(20)),
      child: panel,
    );
    return fillHeight ? SizedBox.expand(child: card) : card;
  }
}

class _TeacherProfileHeader extends StatelessWidget {
  const _TeacherProfileHeader({
    required this.data,
    required this.shellDisplayName,
    required this.avatarUrl,
    this.institutionName = '',
  });

  final SmartCampusDashboardData data;
  final String shellDisplayName;
  final String avatarUrl;
  final String institutionName;

  @override
  Widget build(BuildContext context) {
    final profile = data.profile;
    final displayName = shellDisplayName.isNotEmpty
        ? shellDisplayName
        : profile.name;
    final isStudent = data.role == SmartCampusRole.student;
    final isHeadTeacher = data.role == SmartCampusRole.headTeacher;
    final roleLabel = isStudent ? '学生' : (isHeadTeacher ? '班主任' : '任课老师');
    final statusLabel = isStudent ? '在校' : '在岗';
    final name = displayName.isEmpty ? roleLabel : displayName;
    return Row(
      children: [
        AppAvatar(name: name, url: avatarUrl, size: 56),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(name, style: AppText.title16),
                  AppTag(label: roleLabel, tone: AppTone.brand),
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              Row(
                children: [
                  AppStatusTag(label: statusLabel, tone: AppTone.success),
                  if (institutionName.trim().isNotEmpty) ...[
                    const SizedBox(width: AppSpace.s8),
                    Flexible(
                      child: Text(
                        institutionName.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 侧栏资料行：学生写专业方向、擅长科目、宿舍与目标院校；老师写任教科目与
/// 班级（来自 `teacherRole` / `classList`，班主任另写所带班级）。
class _TeacherProfileInfoRows extends ConsumerStatefulWidget {
  const _TeacherProfileInfoRows({
    required this.data,
    this.shellUser = const ShellUser(),
    this.studentDormBedLabel,
  });

  final SmartCampusDashboardData data;
  final ShellUser shellUser;
  final String? studentDormBedLabel;

  @override
  ConsumerState<_TeacherProfileInfoRows> createState() =>
      _TeacherProfileInfoRowsState();
}

class _TeacherProfileInfoRowsState
    extends ConsumerState<_TeacherProfileInfoRows> {
  String _subject = '';
  List<String> _teachingClasses = const [];
  List<String> _headClasses = const [];

  bool get _isStudent => widget.data.role == SmartCampusRole.student;

  @override
  void initState() {
    super.initState();
    if (!_isStudent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadStaffInfo());
    }
  }

  Future<void> _loadStaffInfo() async {
    final repo = ref.read(teacherRepositoryProvider);
    final results = await Future.wait([
      repo.teacherRole(),
      repo.classList(),
      repo.classList(isHeadTeacher: 1),
    ]);
    if (!mounted) return;
    List<String> names(ApiResponse resp) {
      final raw = resp.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['records'] ?? raw['list']) : null);
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (item is Map && (item['name']?.toString() ?? '').isNotEmpty)
            item['name'].toString(),
      ];
    }

    var subject = '';
    final role = results[0].data;
    final first = role is List && role.isNotEmpty ? role.first : role;
    if (first is Map) {
      subject = first['subjectName']?.toString() ?? '';
    }
    setState(() {
      _subject = subject;
      _teachingClasses = results[1].isSuccess ? names(results[1]) : const [];
      _headClasses = results[2].isSuccess ? names(results[2]) : const [];
    });
  }

  List<(String, String)> _lines() {
    String display(String value) => value.trim().isEmpty ? '—' : value.trim();
    if (_isStudent) {
      final user = widget.shellUser;
      return [
        ('专业方向', display(user.primary)),
        ('擅长科目', display(user.secondary)),
        ('性别', display(user.gender)),
        if (widget.studentDormBedLabel != null)
          ('宿舍', display(widget.studentDormBedLabel!)),
        ('目标院校', display(user.targetSchool)),
      ];
    }
    final isHead = widget.data.role == SmartCampusRole.headTeacher;
    return [
      if (isHead) ('所带班级', display(_headClasses.join('、'))),
      ('任教科目', display(_subject)),
      ('任教班级', display(_teachingClasses.join('、'))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text(lines[i].$1, style: AppText.caption12),
              ),
              Expanded(
                child: Text(
                  lines[i].$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12.copyWith(color: AppColors.ink),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TeacherRoleTabs extends StatelessWidget {
  const _TeacherRoleTabs({required this.selected, required this.onChanged});

  final SmartCampusRole selected;
  final ValueChanged<SmartCampusRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSegmented<SmartCampusRole>(
      expand: true,
      size: AppControlSize.sm,
      segments: const [
        AppSegment(value: SmartCampusRole.teacher, label: '任课老师'),
        AppSegment(value: SmartCampusRole.headTeacher, label: '班主任'),
      ],
      value: selected,
      onChanged: onChanged,
    );
  }
}

class _TeacherNoticePanel extends ConsumerStatefulWidget {
  const _TeacherNoticePanel({
    required this.role,
    required this.fallbackNotices,
  });

  final SmartCampusRole role;
  final List<SmartCampusNoticeData> fallbackNotices;

  @override
  ConsumerState<_TeacherNoticePanel> createState() =>
      _TeacherNoticePanelState();
}

class _TeacherNoticePanelState extends ConsumerState<_TeacherNoticePanel> {
  List<TeacherNoticeListItem> _notices = const [];

  bool get _usesNoticeApi =>
      widget.role == SmartCampusRole.teacher ||
      widget.role == SmartCampusRole.headTeacher ||
      widget.role == SmartCampusRole.student;

  @override
  void initState() {
    super.initState();
    if (_usesNoticeApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotices());
    }
  }

  @override
  void didUpdateWidget(covariant _TeacherNoticePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role && _usesNoticeApi) {
      _loadNotices();
    }
  }

  Future<void> _loadNotices() async {
    if (!_usesNoticeApi) return;
    try {
      final ApiResponse resp;
      if (widget.role == SmartCampusRole.student) {
        resp = await ref.read(studentRepositoryProvider).noticeList(size: 20);
      } else {
        final repo = ref.read(teacherRepositoryProvider);
        resp = widget.role == SmartCampusRole.headTeacher
            ? await repo.headTeacherNoticeList(size: 20)
            : await repo.courseTeacherNoticeList(size: 20);
      }
      if (!mounted) return;
      if (!resp.isSuccess) {
        setState(() {
          _notices = const [];
        });
        return;
      }
      setState(() {
        _notices = parseTeacherNoticeList(resp.data);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notices = const [];
      });
    }
  }

  Future<void> _openNoticeDetail(TeacherNoticeListItem item) async {
    final ApiResponse resp;
    if (widget.role == SmartCampusRole.student) {
      resp = await ref
          .read(studentRepositoryProvider)
          .noticeDetail(id: item.id);
    } else {
      resp = await ref
          .read(teacherRepositoryProvider)
          .noticeDetail(id: item.id);
    }
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, resp.msg.isNotEmpty ? resp.msg : '通知详情加载失败');
      return;
    }
    final detail = parseTeacherNoticeDetail(resp.data);
    if (detail == null) {
      AppToast.show(context, '通知详情加载失败');
      return;
    }
    await showNoticeDetailDialog<void>(
      context: context,
      builder: (ctx) => NoticeDetailGradientDialog(
        title: '通知详情',
        child: _TeacherSchoolNoticeDetailBody(notice: detail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_usesNoticeApi) {
      return _TeacherNoticeList(items: _notices, onTap: _openNoticeDetail);
    }
    return _TeacherNoticeFallbackList(notices: widget.fallbackNotices);
  }
}

class _TeacherNoticeFallbackList extends StatelessWidget {
  const _TeacherNoticeFallbackList({required this.notices});

  final List<SmartCampusNoticeData> notices;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (notices.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(24)),
        child: Center(
          child: Text(
            '暂无已发布通知',
            style: TextStyle(
              fontSize: ui(12),
              color: AppColors.textPlaceholder,
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < notices.length; i++) ...[
          if (i > 0) SizedBox(height: ui(8)),
          _TeacherNoticeCard(item: notices[i]),
        ],
      ],
    );
  }
}

class _TeacherNoticeList extends StatelessWidget {
  const _TeacherNoticeList({required this.items, required this.onTap});

  final List<TeacherNoticeListItem> items;
  final ValueChanged<TeacherNoticeListItem> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(24)),
        child: Center(
          child: Text(
            '暂无已发布通知',
            style: TextStyle(
              fontSize: ui(12),
              color: AppColors.textPlaceholder,
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: ui(8)),
          _TeacherNoticeCard(
            item: SmartCampusNoticeData(
              tag: items[i].tag,
              title: items[i].previewText,
              time: items[i].time,
              tagForeground: items[i].tagStyle.foreground,
              tagBackground: items[i].tagStyle.background,
              unread: items[i].priority.isNotEmpty && items[i].priority != '普通',
            ),
            onTap: () => onTap(items[i]),
          ),
        ],
      ],
    );
  }
}

class _TeacherSchoolNoticeDetailBody extends StatelessWidget {
  const _TeacherSchoolNoticeDetailBody({required this.notice});

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
            fontSize: ui(16),
            color: AppColors.ink,
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
                    color: AppColors.textSecondary,
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: ui(16)),
        _TeacherNoticeDetailRow(label: '类型', value: notice.type),
        _TeacherNoticeDetailRow(label: '级别', value: notice.priority),
        _TeacherNoticeDetailRow(label: '推送', value: notice.scopeLabel),
        _TeacherNoticeDetailRow(
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
            color: AppColors.textSecondary,
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
        ),
        SizedBox(height: ui(6)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(ui(10)),
          ),
          child: Text(
            notice.content.isEmpty ? '（暂无正文）' : notice.content,
            style: TextStyle(
              fontSize: ui(13),
              color: AppColors.ink,
              fontWeight: AppFont.w400,
              height: 22 / 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherNoticeDetailRow extends StatelessWidget {
  const _TeacherNoticeDetailRow({
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
                color: AppColors.textPlaceholder,
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
                color: AppColors.ink,
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

class _TeacherNoticeCard extends StatelessWidget {
  const _TeacherNoticeCard({required this.item, this.onTap});

  final SmartCampusNoticeData item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = item.tag.trim() == '紧急' ? AppTone.danger : AppTone.neutral;
    return AppPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTag(label: item.tag, tone: tone),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body13.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                campusListTimeOf(item.time, fallback: item.time),
                style: AppText.caption12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 当前课程 + 今日课表（白色双卡区）
//
// 视觉与班主任端 `_HeadTeacherBoardSection` 保持一致：
//   - 标题在白卡之外（"当前课程" / "今日课表"），无额外操作按钮
//   - 顶部 ui(12) 间距 + 标题→白卡 ui(20)
//   - 数据来自 `/app/school/v2/teacher/courseList`（当日）+ `schoolTimeConfigList`（节次时间）
//   - 白卡 padding 12 / radius 16 / 浅阴影
//   - 白卡内部子卡与首页课程卡一致：复用 [DashboardCourseNoticeCard]（即 AppCourseCard，高度随内容；已结束标签灰度）
//   - 时间 Barlow 18 + 状态；科目标签 + 大小课标签；任课老师头像 + 名称 + 副行提示文案
//   - 数据为空时白卡保留，并展示占位文案
// =============================================================================

class _LessonRowData {
  const _LessonRowData({
    required this.avatarSeed,
    required this.teacherName,
    required this.courseName,
    required this.courseColor,
    required this.courseBg,
    required this.tag,
    required this.tagDotColor,
    required this.hint,
    required this.isSmallCourse,
    this.avatarUrl = '',
    this.logoUrl = '',
  });

  /// 头像姓氏取自这里（任课老师姓名优先）。
  final String avatarSeed;

  /// 任课老师照片；为空时头像显示 [avatarSeed] 的姓氏。
  final String avatarUrl;

  /// 班级 logo，学生端（student_dashboard.dart）仍会传入；课程卡头像不再使用。
  final String logoUrl;
  final String teacherName;
  final String courseName;
  final Color courseColor;
  final Color courseBg;
  final String tag;
  final Color tagDotColor;
  final String hint;
  final bool isSmallCourse;
}

class _LessonScheduleData {
  const _LessonScheduleData({
    required this.time,
    required this.startTime,
    required this.endTime,
    required this.phase,
    required this.teachers,
    this.courseDate,
    this.lineNum = 0,
  });

  final String time;
  final String startTime;
  final String endTime;
  final _LessonSlotPhase phase;
  final List<_LessonRowData> teachers;
  final DateTime? courseDate;
  final int lineNum;

  TeacherScheduleFocusTarget? get scheduleFocus {
    final date = courseDate;
    if (date == null || lineNum <= 0) return null;
    return TeacherScheduleFocusTarget(
      courseDate: DateTime(date.year, date.month, date.day),
      lineNum: lineNum,
    );
  }

  bool get isPast => phase == _LessonSlotPhase.ended;

  DashboardCourseRunState get runState => switch (phase) {
    _LessonSlotPhase.ended => DashboardCourseRunState.ended,
    _LessonSlotPhase.inProgress => DashboardCourseRunState.inProgress,
    _LessonSlotPhase.upcoming => DashboardCourseRunState.upcoming,
  };
}

class _DashboardTimeConfig {
  const _DashboardTimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

/// 画室固定的上午 / 下午 / 晚上三段（接口未返回节次时兜底）。
const List<_DashboardTimeConfig> _kDefaultDashboardTimeConfigs = [
  _DashboardTimeConfig(lineNum: 1, start: '08:30', end: '11:30'),
  _DashboardTimeConfig(lineNum: 2, start: '14:00', end: '17:00'),
  _DashboardTimeConfig(lineNum: 3, start: '19:00', end: '21:00'),
];

enum _LessonSlotPhase { inProgress, upcoming, ended }

class _TeacherScheduleSection extends ConsumerStatefulWidget {
  const _TeacherScheduleSection({
    this.fillRemaining = false,
    this.onOpenSchedule,
    this.courseTeacherIndex,
  });

  /// true：父级提供有界高度，宽屏下双卡通过 `Expanded(cardsRow)` 撑满剩余高度。
  final bool fillRemaining;
  final void Function({TeacherScheduleFocusTarget? focus})? onOpenSchedule;
  final CourseTeacherIndexRes? courseTeacherIndex;

  @override
  ConsumerState<_TeacherScheduleSection> createState() =>
      _TeacherScheduleSectionState();
}

class _TeacherScheduleSectionState
    extends ConsumerState<_TeacherScheduleSection> {
  _LessonScheduleData? _currentLesson;
  List<_LessonScheduleData> _todayLessons = const [];
  int _scheduleLoadGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.courseTeacherIndex != null) {
        _applyCourseTeacherIndex(widget.courseTeacherIndex);
      }
      // 任课老师首页由父级统一拉 courseTeacherIndex；此处不再并行请求
      // courseList，避免两路数据短暂不一致。
    });
  }

  Future<void> _applyCourseTeacherIndex(CourseTeacherIndexRes? index) async {
    if (!mounted || index == null) return;
    final gen = ++_scheduleLoadGen;
    final teacherRepo = ref.read(teacherRepositoryProvider);
    final schoolRepo = ref.read(schoolRepositoryProvider);
    try {
      final built = await _buildScheduleFromCourseTeacherIndex(
        index: index,
        schoolRepo: schoolRepo,
        teacherRepo: teacherRepo,
        timeConfigs: _kDefaultDashboardTimeConfigs,
        now: DateTime.now(),
      );
      if (!mounted || gen != _scheduleLoadGen) return;
      setState(() {
        _currentLesson = built.current;
        _todayLessons = built.today;
      });
    } catch (_) {
      if (!mounted || gen != _scheduleLoadGen) return;
      setState(() {
        _currentLesson = null;
        _todayLessons = const [];
      });
    }
  }

  @override
  void didUpdateWidget(covariant _TeacherScheduleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseTeacherIndex != widget.courseTeacherIndex) {
      _applyCourseTeacherIndex(widget.courseTeacherIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.onOpenSchedule;
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 620;
        final fill = widget.fillRemaining && twoColumns;
        void openLesson(_LessonScheduleData lesson) =>
            open?.call(focus: lesson.scheduleFocus);
        final current = _TodayLessonsBoard(
          title: '当前课程',
          emptyLabel: '暂无当前课程',
          lessons: [?_currentLesson],
          fillHeight: fill,
          onTapLesson: open == null ? null : openLesson,
        );
        final today = _TodayLessonsBoard(
          lessons: _todayLessons,
          fillHeight: fill,
          onOpenAll: open == null ? null : () => open(),
          onTapLesson: open == null ? null : openLesson,
        );
        if (twoColumns) {
          return Row(
            crossAxisAlignment: fill
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              Expanded(child: current),
              const SizedBox(width: AppSpace.s16),
              Expanded(child: today),
            ],
          );
        }
        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            current,
            const SizedBox(height: AppSpace.s16),
            today,
          ],
        );
        return widget.fillRemaining
            ? SingleChildScrollView(child: column)
            : column;
      },
    );
  }
}

/// 首页「今日课表」：当天全部课程，进行中的一节高亮；与首页课程卡、课堂签到
/// 用同一组件（[AppCourseCard]）和同一份课表数据。
class _TodayLessonsBoard extends StatelessWidget {
  const _TodayLessonsBoard({
    required this.lessons,
    this.title = '今日课表',
    this.emptyLabel = '今天没有课程',
    this.fillHeight = false,
    this.onOpenAll,
    this.onTapLesson,
    this.moreLabel = '查看课表',
  });

  final List<_LessonScheduleData> lessons;
  final String title;
  final String emptyLabel;
  final bool fillHeight;
  final VoidCallback? onOpenAll;
  final void Function(_LessonScheduleData lesson)? onTapLesson;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    final running = lessons
        .where((l) => l.phase == _LessonSlotPhase.inProgress)
        .length;
    final subtitle = lessons.isEmpty
        ? '今天没有课'
        : '共 ${lessons.length} 节${running > 0 ? ' · $running 节进行中' : ''}';
    final Widget body = lessons.isEmpty
        ? AppEmptyState(
            icon: Icons.event_available_outlined,
            title: emptyLabel,
            description: '可以在课表里查看本周其他安排',
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * AppSpace.s12) /
                  columns;
              return Wrap(
                spacing: AppSpace.s12,
                runSpacing: AppSpace.s12,
                children: [
                  for (final lesson in lessons)
                    SizedBox(
                      width: width,
                      child: _LessonScheduleCard(
                        data: lesson,
                        selected: lesson.phase == _LessonSlotPhase.inProgress,
                        onTap: onTapLesson == null
                            ? null
                            : () => onTapLesson!(lesson),
                      ),
                    ),
                ],
              );
            },
          );
    final card = AppCard(
      padding: const EdgeInsets.all(AppSpace.s12),
      child: fillHeight ? SingleChildScrollView(child: body) : body,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        AppSectionHeader(
          title: title,
          subtitle: lessons.isEmpty ? null : subtitle,
          onMore: onOpenAll,
          moreLabel: moreLabel,
        ),
        const SizedBox(height: AppSpace.s12),
        if (fillHeight) Expanded(child: card) else card,
      ],
    );
  }
}

class _BuiltDashboardSchedule {
  const _BuiltDashboardSchedule({this.current, required this.today});

  final _LessonScheduleData? current;
  final List<_LessonScheduleData> today;
}

Future<_BuiltDashboardSchedule> _buildScheduleFromCourseTeacherIndex({
  required CourseTeacherIndexRes index,
  required SchoolRepository schoolRepo,
  required TeacherRepository teacherRepo,
  required List<_DashboardTimeConfig> timeConfigs,
  required DateTime now,
}) async {
  var configs = timeConfigs;
  final classResp = await teacherRepo.classList(isClassTeacher: 1);
  if (classResp.isSuccess) {
    String? classId;
    for (final m in _scheduleExtractList(classResp)) {
      final id = _schedulePickString(m, ['id', 'classId'], '');
      if (id.isNotEmpty) {
        classId = id;
        break;
      }
    }
    if (classId != null && classId.isNotEmpty) {
      final tcResp = await schoolRepo.schoolTimeConfigList(classId: classId);
      if (tcResp.isSuccess) {
        final parsed = _parseDashboardTimeConfigs(tcResp);
        if (parsed.isNotEmpty) configs = parsed;
      }
    }
  }

  return _buildDashboardScheduleFromIndex(
    index: index,
    timeConfigs: configs,
    now: now,
  );
}

_BuiltDashboardSchedule _buildDashboardScheduleFromIndex({
  required CourseTeacherIndexRes index,
  required List<_DashboardTimeConfig> timeConfigs,
  required DateTime now,
}) {
  _LessonScheduleData lessonFromRow(
    Map<String, dynamic> row,
    _LessonSlotPhase phase,
  ) {
    final times = _resolveRowTimes(row, timeConfigs);
    final start = times.start;
    final end = times.end;
    return _LessonScheduleData(
      time: start.isNotEmpty && end.isNotEmpty ? '$start - $end' : '—',
      startTime: start,
      endTime: end,
      phase: phase,
      teachers: [_lessonRowFromCourse(row, start, end)],
      courseDate: _courseDateFromRow(row, now),
      lineNum: times.lineNum,
    );
  }

  _LessonScheduleData? current;
  final currentRow = _resolveTeacherCurrentCourseRow(
    index: index,
    timeConfigs: timeConfigs,
    now: now,
  );
  if (currentRow != null) {
    final times = _resolveRowTimes(currentRow, timeConfigs);
    final phase = _slotPhase(now, times.start, times.end);
    current = lessonFromRow(currentRow, phase);
  }

  final todayEntries = <({int sortKey, _LessonScheduleData lesson})>[];
  for (final row in index.todayCourseList) {
    final times = _resolveRowTimes(row, timeConfigs);
    final phase = _slotPhase(now, times.start, times.end);
    todayEntries.add((
      sortKey: _dashboardCourseSortKey(row, times.start),
      lesson: lessonFromRow(row, phase),
    ));
  }
  todayEntries.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  final today = todayEntries.map((e) => e.lesson).toList(growable: false);

  return _BuiltDashboardSchedule(current: current, today: today);
}

/// 首页「当前课程」：优先 API `currentCourse`，否则从今日课表中找进行中时段。
Map<String, dynamic>? _resolveTeacherCurrentCourseRow({
  required CourseTeacherIndexRes index,
  required List<_DashboardTimeConfig> timeConfigs,
  required DateTime now,
}) {
  if (index.currentCourse != null) {
    return index.currentCourse;
  }
  for (final row in index.todayCourseList) {
    final times = _resolveRowTimes(row, timeConfigs);
    if (_slotPhase(now, times.start, times.end) ==
        _LessonSlotPhase.inProgress) {
      return row;
    }
  }
  return null;
}

class _ResolvedRowTimes {
  const _ResolvedRowTimes({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

class _DashboardSlotGroup {
  _DashboardSlotGroup({
    required this.lineNum,
    required this.start,
    required this.end,
    required this.sortKey,
  });

  final int lineNum;
  final String start;
  final String end;
  final int sortKey;
  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
}

_ResolvedRowTimes _resolveRowTimes(
  Map<String, dynamic> row,
  List<_DashboardTimeConfig> configs,
) {
  final lineNumRaw = row['lineNum'];
  final lineNum = lineNumRaw is int
      ? lineNumRaw
      : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);

  var start =
      pickCourseClock(
        _schedulePickString(row, [
          'courseStartTime',
          'timeBegin',
          'startTime',
          'beginTime',
          'start',
        ], ''),
      ) ??
      '';
  var end =
      pickCourseClock(
        _schedulePickString(row, [
          'courseEndTime',
          'timeEnd',
          'endTime',
          'finishTime',
          'end',
        ], ''),
      ) ??
      '';

  _DashboardTimeConfig? configForLineNum() {
    if (lineNum <= 0) return null;
    for (final c in configs) {
      if (c.lineNum == lineNum) return c;
    }
    if (lineNum <= configs.length) return configs[lineNum - 1];
    return null;
  }

  if (end.isEmpty) {
    final matched = configForLineNum();
    if (matched != null) {
      end = matched.end;
      if (start.isEmpty) start = matched.start;
    }
  }

  if (start.isEmpty) {
    final matched = configForLineNum();
    if (matched != null) {
      start = matched.start;
      if (end.isEmpty) end = matched.end;
    }
  }

  return _ResolvedRowTimes(
    lineNum: lineNum,
    start: _trimDashboardHm(start),
    end: _trimDashboardHm(end),
  );
}

DateTime? _courseDateFromRow(Map<String, dynamic> row, DateTime reference) {
  final startDt = parseCourseDateTime(
    _schedulePickString(row, ['courseStartTime'], ''),
    reference: reference,
  );
  if (startDt != null) {
    return DateTime(startDt.year, startDt.month, startDt.day);
  }
  for (final key in ['date', 'classDate', 'courseDate']) {
    final raw = _schedulePickString(row, [key], '');
    if (raw.isEmpty) continue;
    final parsed = DateTime.tryParse(raw.split('T').first);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  return null;
}

int _dashboardCourseSortKey(Map<String, dynamic> row, String startHm) {
  final startDt = parseCourseDateTime(
    _schedulePickString(row, ['courseStartTime'], ''),
  );
  if (startDt != null) return startDt.millisecondsSinceEpoch;
  return _hmSortKey(startHm);
}

_LessonRowData _lessonRowFromCourse(
  Map<String, dynamic> row,
  String start,
  String end,
) {
  final typeRaw = row['type'];
  final type = typeRaw is int
      ? typeRaw
      : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
  final isSmall = type == 1;

  final className = _schedulePickString(row, ['className', 'class'], '');
  final teacher = _schedulePickString(row, [
    'teacherRealname',
    'teacherName',
    'realname',
    'realName',
    'teacherNickname',
    'teacher',
  ], '');
  final subjectName = _schedulePickString(row, [
    'subjectName',
    'courseName',
    'subject',
    'name',
  ], '—');
  final classroom = _schedulePickString(row, [
    'classroomName',
    'roomName',
    'classroom',
  ], '');

  final displayName = className.isNotEmpty
      ? className
      : (teacher.isNotEmpty ? teacher : '—');
  final avatarSeed = teacher.isNotEmpty ? teacher : displayName;

  var courseColor = isSmall ? AppColors.success : AppColors.brand;
  var courseBg = isSmall ? AppColors.successSoft : AppColors.brandTint;
  var tagDotColor = courseColor;

  final hex = _schedulePickString(row, ['color'], '');
  final parsed = _parseDashboardHexColor(hex);
  if (parsed != null) {
    courseColor = parsed;
    courseBg = parsed.withValues(alpha: 0.14);
    tagDotColor = parsed;
  }

  final mins = _minutesBetweenHm(start, end);
  final hintParts = <String>[];
  if (mins > 0) hintParts.add('$mins分钟');
  if (classroom.isNotEmpty) hintParts.add(classroom);
  final hint = hintParts.isEmpty ? '—' : hintParts.join('·');

  return _LessonRowData(
    avatarSeed: avatarSeed,
    logoUrl: resolveScheduleLogoUrl(row),
    avatarUrl: resolveScheduleTeacherHeadUrl(row),
    teacherName: displayName,
    courseName: subjectName,
    courseColor: courseColor,
    courseBg: courseBg,
    tag: isSmall ? '小课' : '大课',
    tagDotColor: tagDotColor,
    hint: hint,
    isSmallCourse: isSmall,
  );
}

List<_DashboardTimeConfig> _parseDashboardTimeConfigs(ApiResponse resp) {
  final list = <_DashboardTimeConfig>[];
  for (final m in _scheduleExtractList(resp)) {
    final lineNumRaw = m['lineNum'];
    final lineNum = lineNumRaw is int
        ? lineNumRaw
        : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
    if (lineNum < 1) continue;
    final start = _trimDashboardHm(
      _schedulePickString(m, [
        'timeBegin',
        'startTime',
        'beginTime',
        'start',
      ], ''),
    );
    final end = _trimDashboardHm(
      _schedulePickString(m, ['timeEnd', 'endTime', 'finishTime', 'end'], ''),
    );
    if (start.isEmpty || end.isEmpty) continue;
    list.add(_DashboardTimeConfig(lineNum: lineNum, start: start, end: end));
  }
  list.sort((a, b) => a.lineNum.compareTo(b.lineNum));
  return list;
}

List<Map<String, dynamic>> _scheduleExtractList(ApiResponse resp) {
  dynamic raw = resp.data;
  if (raw is Map && raw.containsKey('data')) {
    final d = raw['data'];
    if (d is List) {
      raw = d;
    } else if (d is Map) {
      raw = d;
    }
  }
  final list = raw is List
      ? raw
      : (raw is Map && raw['records'] is List
            ? raw['records'] as List
            : (raw is Map && raw['list'] is List
                  ? raw['list'] as List
                  : const []));
  return [
    for (final item in list)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

String _schedulePickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

String _trimDashboardHm(String s) {
  if (s.isEmpty) return s;
  final parts = s.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return s;
}

int _hmSortKey(String hm) {
  final dt = _parseTodayHm(hm);
  if (dt == null) return 0;
  return dt.hour * 60 + dt.minute;
}

DateTime? _parseTodayHm(String hm) {
  final parts = hm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, h, m);
}

int _minutesBetweenHm(String start, String end) {
  final s = _parseTodayHm(start);
  final e = _parseTodayHm(end);
  if (s == null || e == null) return 0;
  return e.difference(s).inMinutes;
}

_LessonSlotPhase _slotPhase(DateTime now, String startHm, String endHm) {
  return switch (resolveDashboardCourseRunState(now, startHm, endHm)) {
    DashboardCourseRunState.ended => _LessonSlotPhase.ended,
    DashboardCourseRunState.inProgress => _LessonSlotPhase.inProgress,
    DashboardCourseRunState.upcoming => _LessonSlotPhase.upcoming,
  };
}

Color? _parseDashboardHexColor(String hex) {
  var s = hex.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(v);
}

/// 与 [_LessonScheduleCard] 单节课时的自然高度一致，空态与有课时白卡高度不跳。

class _LessonScheduleCard extends StatelessWidget {
  const _LessonScheduleCard({
    required this.data,
    this.onTap,
    this.selected = false,
  });

  final _LessonScheduleData data;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final row = data.teachers.first;
    return AppCourseCard(
      startTime: data.startTime,
      endTime: data.endTime,
      subject: row.courseName,
      isSmallCourse: row.isSmallCourse,
      teacherName: row.teacherName,
      subtitle: row.hint,
      status: switch (data.phase) {
        _LessonSlotPhase.ended => AppCourseStatus.ended,
        _LessonSlotPhase.inProgress => AppCourseStatus.inProgress,
        _LessonSlotPhase.upcoming => AppCourseStatus.upcoming,
      },
      classKindDotColor: data.isPast ? null : row.tagDotColor,
      avatar: AppAvatar(
        name: row.avatarSeed,
        url: row.avatarUrl,
        size: AppCourseCard.avatarSize,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}

// =============================================================================
// 班主任端：待办提醒 + 近期动态（白色双卡区）
//
// 与「当前课程 / 今日课表」共用同一外层布局（标题行 + 白卡 + Expanded 撑满）。
// 左卡聚焦需处理事项（请假审批 / 查寝异常 / 家校未读）；右卡展示班级侧最新动态。
// =============================================================================

class _BoardItemData {
  const _BoardItemData({
    required this.time,
    required this.title,
    required this.tag,
    this.status = '',
  });

  final String time;

  /// 正文（主标题，最多两行）。
  final String title;
  final String tag;

  /// 待处理状态（待我审批 / 待家长确认 / 待审核），近期动态为空。
  final String status;
}

class _HeadTeacherBoardSection extends StatelessWidget {
  const _HeadTeacherBoardSection({
    this.fillRemaining = false,
    this.todoItems = const [],
    this.recentItems = const [],
    this.onTodoItemTap,
  });

  /// true：父级提供有界高度，宽屏下双卡通过 `Expanded(cardsRow)` 撑满剩余高度。
  final bool fillRemaining;
  final List<_BoardItemData> todoItems;
  final List<_BoardItemData> recentItems;
  final void Function(String tag)? onTodoItemTap;

  @override
  Widget build(BuildContext context) {
    Widget column(String title, Widget panel, {required bool fill}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        AppSectionHeader(title: title),
        const SizedBox(height: AppSpace.s12),
        if (fill) Expanded(child: panel) else panel,
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        // 两块面板并排至少各需约 280 宽；更窄时上下排列。
        final stackVertically = !cw.isFinite || cw < 560;
        final todo = _BoardPanel(
          items: todoItems,
          emptyTitle: '暂无待办',
          emptyDescription: '学生请假、补卡与查寝异常会出现在这里',
          scrollable: fillRemaining && !stackVertically,
          onItemTap: onTodoItemTap,
        );
        final recent = _BoardPanel(
          items: recentItems,
          emptyTitle: '暂无近期动态',
          emptyDescription: '家校沟通、班级通知与审批记录会出现在这里',
          scrollable: fillRemaining && !stackVertically,
        );
        if (stackVertically) {
          final stacked = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              column('待办提醒', todo, fill: false),
              const SizedBox(height: AppSpace.s16),
              column('近期动态', recent, fill: false),
            ],
          );
          return fillRemaining
              ? SingleChildScrollView(child: stacked)
              : stacked;
        }
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: column('待办提醒', todo, fill: fillRemaining)),
            const SizedBox(width: AppSpace.s16),
            Expanded(child: column('近期动态', recent, fill: fillRemaining)),
          ],
        );
        return fillRemaining ? row : IntrinsicHeight(child: row);
      },
    );
  }
}

class _BoardPanel extends StatelessWidget {
  const _BoardPanel({
    required this.items,
    required this.emptyTitle,
    required this.emptyDescription,
    this.scrollable = false,
    this.onItemTap,
  });

  final List<_BoardItemData> items;
  final String emptyTitle;
  final String emptyDescription;
  final bool scrollable;
  final void Function(String tag)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final Widget body = items.isEmpty
        ? AppEmptyState(
            icon: Icons.task_alt_rounded,
            title: emptyTitle,
            description: emptyDescription,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpace.s8),
                _BoardItemCard(
                  data: items[i],
                  onTap: onItemTap == null
                      ? null
                      : () => onItemTap!(items[i].tag),
                ),
              ],
            ],
          );
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s12),
      child: scrollable ? SingleChildScrollView(child: body) : body,
    );
  }
}

/// 待办 / 动态条目：正文两行做主标题，下方类别标签 + 状态，时间靠右。
class _BoardItemCard extends StatelessWidget {
  const _BoardItemCard({required this.data, this.onTap});

  final _BoardItemData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body14,
            ),
            const SizedBox(height: AppSpace.s8),
            Row(
              children: [
                if (data.tag.isNotEmpty) AppTag(label: data.tag),
                if (data.status.isNotEmpty) ...[
                  const SizedBox(width: AppSpace.s8),
                  AppStatusTag(label: data.status, tone: AppTone.warning),
                ],
                const Spacer(),
                if (data.time.isNotEmpty)
                  Text(data.time, style: AppText.caption12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
