// =============================================================================
// 管理员「签课管理」独立页面
//
// 入口：管理员首页快捷区「签课管理」→ controller.openSignManagement()
//      → mainView == signManagement → SmartCampusPage 路由到本视图。
// 返回：顶部 banner 左上角返回按钮 → onBack。
//
// 逻辑设计（与业务描述对齐）：
//
//   ┌ 大课管理 tab ─────────────────────────────────────────────────────────┐
//   │ 按班级 + 日期查询当日大课列表。                                        │
//   │ 每节大课卡：课程名 / 时间 / 教室 + 已签 M/N + 状态徽章。               │
//   │ 点击卡片展开学生名单：每人显示当前签到状态（正常/迟到/早退/请假/缺勤）   │
//   │ 管理员可直接点选修改单个学生状态（弹出 bottomSheet 选状态）。           │
//   │ 补签申请入口：底部「待审核补签 N 条」红点 → 打开右侧抽屉审核列表。      │
//   └───────────────────────────────────────────────────────────────────────┘
//
//   ┌ 小课管理 tab ─────────────────────────────────────────────────────────┐
//   │ 按班级 + 日期查询当日小课列表。                                        │
//   │ 五步签到进度条：                                                       │
//   │   ① 教师上课签到  ② 学生上课签到  ③ 教师下课签到                     │
//   │   ④ 学生下课签到  ⑤ 学生评价  ⑥ 管理员确认完成                      │
//   │ 进度条按步骤着色：已完成=紫 / 当前=橙动效 / 未到=灰。                  │
//   │ 待管理员确认的小课：底部渲染「确认完成」按钮 + 查看评价按钮。           │
//   │ 补签申请审核：右上角红角标 badge + 右侧抽屉（与大课共用 UI 组件）。     │
//   └───────────────────────────────────────────────────────────────────────┘
//
// 颜色：白卡 / #F5F6FA 浅灰 / #8741FF 主紫 / #FF323C 红 / #0CAC40 绿
//      / #F59E0B 橙黄 / #B6B5BB 灰 / #6D6B75 副字
// 字体：PingFang SC（中文）+ Barlow（时间数字）
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/segment_toggle.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../../core/widgets/smooth_circle_network_avatar.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import '../data/course_sign_data.dart';
import '../data/smart_campus_count_badge.dart';
import 'widgets/course_sign_status_picker.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ─── 调色板 ────────────────────────────────────────────────────────────────

const Color _kCardBg = Colors.white;
const Color _kPageBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLight = Color(0xFFA773FF);
const Color _kPurpleSoftBg = Color(0xFFEAE5FF);
const Color _kGreen = Color(0xFF0CAC40);
const Color _kGreenBg = Color(0xFFDFFCF0);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kOrangeBg = Color(0xFFFFF7E6);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedBg = Color(0xFFFFEEEF);

const double _kSignBadgeHeight = 22;
const double _kSignBadgeHorizontalPadding = 8;
const double _kSignBadgeBorderRadius = 6;
const double _kSignBadgeFontSize = 11;
const double _kSignBadgeGap = 6;

// ─── 入口视图 ──────────────────────────────────────────────────────────────

enum _SignTab { large, small }

class AdminSignManagementView extends StatefulWidget {
  const AdminSignManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AdminSignManagementView> createState() =>
      _AdminSignManagementViewState();
}

class _AdminSignManagementViewState extends State<AdminSignManagementView> {
  _SignTab _tab = _SignTab.large;
  int _pendingMakeupCount = 0;

  @override
  Widget build(BuildContext context) {
    return SmartCampusSecondaryPageShell(
      backgroundColor: Colors.transparent,
      bodyTopClipRadius: 8,
      header: _SignBanner(
        onBack: widget.onBack,
        selectedTab: _tab,
        onSelectTab: (t) {
          if (_tab == t) return;
          setState(() => _tab = t);
        },
        pendingMakeupCount: _pendingMakeupCount,
        onOpenMakeupAudit: _openMakeupAuditDrawer,
      ),
      bodyScrollable: false,
      body: IndexedStack(
        index: _tab == _SignTab.large ? 0 : 1,
        sizing: StackFit.expand,
        children: [
          _LargeClassTab(
            pendingMakeupCount: _pendingMakeupCount,
            onOpenMakeupAudit: _openMakeupAuditDrawer,
            onPendingMakeupChanged: (n) {
              if (_pendingMakeupCount != n) {
                setState(() => _pendingMakeupCount = n);
              }
            },
          ),
          _SmallClassTab(
            pendingMakeupCount: _pendingMakeupCount,
            onOpenMakeupAudit: _openMakeupAuditDrawer,
            onPendingMakeupChanged: (n) {
              if (_pendingMakeupCount != n) {
                setState(() => _pendingMakeupCount = n);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openMakeupAuditDrawer() async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: '关闭',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, _) {
        return DashboardScaleScope(
          data: scaleData,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: _MakeupAuditDrawer(
                onClose: () => Navigator.of(ctx).maybePop(),
                onAuditDone: (remaining) {
                  setState(() => _pendingMakeupCount = remaining);
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
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
}

// ─── banner ────────────────────────────────────────────────────────────────

class _SignBanner extends StatelessWidget {
  const _SignBanner({
    required this.onBack,
    required this.selectedTab,
    required this.onSelectTab,
    required this.pendingMakeupCount,
    required this.onOpenMakeupAudit,
  });

  final VoidCallback onBack;
  final _SignTab selectedTab;
  final ValueChanged<_SignTab> onSelectTab;
  final int pendingMakeupCount;
  final VoidCallback onOpenMakeupAudit;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(62),
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
          // 返回按钮
          Positioned(
            left: ui(12),
            top: ui(15),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                width: ui(32),
                height: ui(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          // 标题（居中）
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '签课管理',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  '大课一键入册 · 小课全流程签到 · 补签审核',
                  textAlign: TextAlign.center,
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
          // 右侧：大课 / 小课切换 + 补签审核入口
          Positioned(
            right: ui(12),
            top: ui(14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SegmentControl(selected: selectedTab, onSelect: onSelectTab),
                SizedBox(width: ui(8)),
                _MakeupBadgeButton(
                  count: pendingMakeupCount,
                  onTap: onOpenMakeupAudit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentControl extends StatelessWidget {
  const _SegmentControl({required this.selected, required this.onSelect});

  final _SignTab selected;
  final ValueChanged<_SignTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SegmentToggle(
      selectedIndex: selected == _SignTab.large ? 0 : 1,
      fontSize: 12,
      trackColor: _kPageBg,
      thumbColor: _kTextDark,
      options: const [
        SegmentToggleOption(label: '大课管理'),
        SegmentToggleOption(label: '小课管理'),
      ],
      onChanged: (i) => onSelect(i == 0 ? _SignTab.large : _SignTab.small),
    );
  }
}

class _MakeupBadgeButton extends StatelessWidget {
  const _MakeupBadgeButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: ui(32),
            padding: EdgeInsets.symmetric(horizontal: ui(12)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(8)),
              border: Border.all(color: _kBorderSoft),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppAssets.adminSignManagementMakeupAuditIcon,
                  width: ui(18),
                  height: ui(18),
                  fit: BoxFit.contain,
                ),
                SizedBox(width: ui(4)),
                Text(
                  '补签审核',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: Colors.black,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Positioned(
              right: ui(-6),
              top: ui(-6),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(4),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: _kRed,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Text(
                  smartCampusCountBadgeLabel(count)!,
                  style: TextStyle(
                    fontSize: ui(10),
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// 大课管理 Tab
// =============================================================================

class _LargeClassTab extends ConsumerStatefulWidget {
  const _LargeClassTab({
    required this.pendingMakeupCount,
    required this.onOpenMakeupAudit,
    required this.onPendingMakeupChanged,
  });

  final int pendingMakeupCount;
  final VoidCallback onOpenMakeupAudit;
  final ValueChanged<int> onPendingMakeupChanged;

  @override
  ConsumerState<_LargeClassTab> createState() => _LargeClassTabState();
}

class _LargeClassTabState extends ConsumerState<_LargeClassTab> {
  List<_ClassFilterOption> _classOptions = _kFallbackClassOptions;
  String? _selectedClassId;
  String _selectedDate = todayIsoDate();
  List<CourseSignSession> _sessions = const [];
  CourseSignStats _stats = const CourseSignStats();
  bool _loadingClasses = true;
  bool _loadingData = false;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    unawaited(_loadClasses());
  }

  Future<void> _loadClasses() async {
    setState(() => _loadingClasses = true);
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classList(type: 0);
    if (!mounted) return;

    final classes = resp.isSuccess
        ? parseCourseSignClassList(resp.data)
        : const <CourseSignClassOption>[];
    setState(() {
      _classOptions = _buildClassFilterOptions(classes);
      if (_selectedClassId != null &&
          !_classOptions.any((o) => o.id == _selectedClassId)) {
        _selectedClassId = null;
      }
      _loadingClasses = false;
    });
    await _loadSignData();
  }

  Future<void> _loadSignData() async {
    setState(() {
      _loadingData = true;
      _expandedIndex = null;
    });
    final classId = _selectedClassId ?? '';
    final repo = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repo.courseSignSum0(classId: classId, date: _selectedDate),
      repo.courseSignManager(classId: classId, date: _selectedDate, type: 0),
    ]);
    if (!mounted) return;

    final sumResp = results[0];
    final listResp = results[1];
    if (!sumResp.isSuccess && sumResp.msg.isNotEmpty) {
      AppToast.show(context, sumResp.msg, type: AppToastType.error);
    }
    if (!listResp.isSuccess && listResp.msg.isNotEmpty) {
      AppToast.show(context, listResp.msg, type: AppToastType.error);
    }

    final stats = sumResp.isSuccess
        ? CourseSignStats.fromJson(sumResp.data)
        : const CourseSignStats();
    final sessions = listResp.isSuccess
        ? sortCourseSignSessions(
            enrichCourseSignSessions(parseCourseSignSessionList(listResp.data)),
          )
        : const <CourseSignSession>[];

    widget.onPendingMakeupChanged(stats.pendingMakeupCount);
    setState(() {
      _stats = stats;
      _sessions = sessions;
      _loadingData = false;
    });
  }

  Future<void> _refreshStats() async {
    final classId = _selectedClassId ?? '';
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.courseSignSum0(
      classId: classId,
      date: _selectedDate,
    );
    if (!mounted || !resp.isSuccess) return;
    final stats = CourseSignStats.fromJson(resp.data);
    widget.onPendingMakeupChanged(stats.pendingMakeupCount);
    setState(() => _stats = stats);
  }

  Future<void> _updateStudentStatus(
    CourseSignSession session,
    int studentIdx,
    CourseSignStatus status,
  ) async {
    final student = session.students[studentIdx];
    if (student.studentId.isEmpty) {
      AppToast.show(context, '学生 ID 无效', type: AppToastType.error);
      return;
    }
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.courseSignUpdateSignStatus(
      courseId: session.courseId,
      studentId: student.studentId,
      status: status.code,
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(
        context,
        resp.msg.isNotEmpty ? resp.msg : '修改失败',
        type: AppToastType.error,
      );
      return;
    }
    setState(() => student.status = status);
    AppToast.show(context, '签到状态已更新', type: AppToastType.success);
    unawaited(_refreshStats());
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pageLoading =
        _loadingClasses || (_loadingData && _sessions.isEmpty);

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LargeClassStatsRow(
            stats: _stats,
            pendingMakeupCount: widget.pendingMakeupCount,
          ),
          SizedBox(height: ui(16)),
          _FilterBar(
            selectedClassId: _selectedClassId,
            selectedDate: _selectedDate,
            classOptions: _classOptions,
            loading: _loadingClasses,
            onClassChanged: (id) {
              if (id == _selectedClassId) return;
              setState(() => _selectedClassId = id);
              unawaited(_loadSignData());
            },
            onDateChanged: (v) {
              setState(() => _selectedDate = v);
              unawaited(_loadSignData());
            },
          ),
          SizedBox(height: ui(16)),
          MainContentLoadingShell(
            loading: pageLoading,
            minHeight: ui(200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildListSection(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildListSection(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    if (_loadingData && _sessions.isEmpty) {
      return const [];
    }
    if (_classOptions.length <= 1) {
      return [_EmptyHint(text: '暂无大班班级，请先在班级编组中创建')];
    }
    if (_sessions.isEmpty) {
      return [_EmptyHint(text: '所选日期暂无大课签到记录')];
    }

    final widgets = <Widget>[];
    for (var i = 0; i < _sessions.length; i++) {
      if (i > 0) widgets.add(SizedBox(height: ui(12)));
      final session = _sessions[i];
      widgets.add(
        _LargeClassSessionCard(
          session: session,
          expanded: _expandedIndex == i,
          onToggle: () => setState(
            () => _expandedIndex = _expandedIndex == i ? null : i,
          ),
          onChangeStudentStatus: (studentIdx, status) {
            unawaited(_updateStudentStatus(session, studentIdx, status));
          },
        ),
      );
    }
    if (widget.pendingMakeupCount > 0) {
      widgets.add(SizedBox(height: ui(12)));
      widgets.add(
        _PendingMakeupRow(
          count: widget.pendingMakeupCount,
          onTap: widget.onOpenMakeupAudit,
        ),
      );
    }
    return widgets;
  }
}

class _LargeClassStatsRow extends StatelessWidget {
  const _LargeClassStatsRow({
    required this.stats,
    required this.pendingMakeupCount,
  });

  final CourseSignStats stats;
  final int pendingMakeupCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final total = stats.courseCount;
    final signed = stats.signedCourseCount;
    final signedStudents = stats.studentSignedCount;
    final totalStudents = stats.studentShouldCount;
    return Row(
      children: [
        Expanded(
          child: SmartCampusStatCard(
            valueLabel: '$total',
            label: '今日大课节数',
            backgroundAsset: AppAssets.adminSignManagementStatCard1,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            valueLabel: '$signed',
            label: '已完成签到',
            backgroundAsset: AppAssets.adminSignManagementStatCard2,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            valueLabel: totalStudents > 0
                ? '$signedStudents/$totalStudents'
                : '$signedStudents',
            label: '学生已签/应签',
            backgroundAsset: AppAssets.adminSignManagementStatCard3,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            valueLabel: '$pendingMakeupCount',
            label: '待处理补签',
            backgroundAsset: AppAssets.adminSignManagementStatCard4,
          ),
        ),
      ],
    );
  }
}

class _SignClassNameBadge extends StatelessWidget {
  const _SignClassNameBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(_kSignBadgeHeight),
      padding: EdgeInsets.symmetric(horizontal: ui(_kSignBadgeHorizontalPadding)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(ui(_kSignBadgeBorderRadius)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(_kSignBadgeFontSize),
          color: _kTextSecondary,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _SignSessionHeaderBadges extends StatelessWidget {
  const _SignSessionHeaderBadges({
    required this.className,
    required this.signStatus,
  });

  final String className;
  final int signStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (className.isNotEmpty) ...[
          _SignClassNameBadge(label: className),
          SizedBox(width: ui(_kSignBadgeGap)),
        ],
        _SmallClassStatusBadge(signStatus: signStatus),
      ],
    );
  }
}

class _LargeClassSessionCard extends StatelessWidget {
  const _LargeClassSessionCard({
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.onChangeStudentStatus,
  });

  final CourseSignSession session;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(int studentIdx, CourseSignStatus status)
  onChangeStudentStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final signedCount = session.students.where((s) => s.status != null).length;
    final total = session.students.length;
    final teacherLabel = session.teacherName.isEmpty
        ? '任课教师'
        : session.teacherName;
    final subtitle = _largeClassSessionSubtitle(session);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(ui(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                session.courseName,
                                style: TextStyle(
                                  fontSize: ui(15),
                                  color: _kTextDark,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w600,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ui(6)),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: ui(10)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SignSessionHeaderBadges(
                        className: session.className,
                        signStatus: session.signStatus,
                      ),
                      SizedBox(height: ui(8)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SignProgressPill(signed: signedCount, total: total),
                          SizedBox(width: ui(6)),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: ui(18),
                            color: _kTextHint,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: _kBorderSoft,
              indent: ui(14),
              endIndent: ui(14),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(14), ui(12), ui(14), ui(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LargeClassTeacherRow(
                    teacherName: teacherLabel,
                    headUrl: session.teacherHeadUrl,
                    logoUrl: session.logoUrl,
                  ),
                  SizedBox(height: ui(12)),
                  Row(
                    children: [
                      Image.asset(
                        AppAssets.adminSignManagementStudentIcon,
                        width: ui(13),
                        height: ui(13),
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: ui(5)),
                      Text(
                        '学生签到（${session.students.length}人）',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextSecondary,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '点击状态可修改',
                        style: TextStyle(
                          fontSize: ui(10),
                          color: _kTextHint,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ui(10)),
                  if (session.students.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: ui(24)),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kPageBg,
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Text(
                        '暂无学生签到数据',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextHint,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 1,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < session.students.length; i++) ...[
                      if (i > 0) SizedBox(height: ui(8)),
                      _StudentSignRow(
                        student: session.students[i],
                        onChangeStatus: (s) => onChangeStudentStatus(i, s),
                      ),
                    ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LargeClassTeacherRow extends StatelessWidget {
  const _LargeClassTeacherRow({
    required this.teacherName,
    required this.headUrl,
    required this.logoUrl,
  });

  final String teacherName;
  final String headUrl;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final avatarUrl = headUrl.isNotEmpty ? headUrl : logoUrl;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          _MiniAvatar(
            seed: teacherName,
            size: ui(36),
            imageUrl: avatarUrl,
          ),
          SizedBox(width: ui(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacherName,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  '任课教师',
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.person_rounded, size: ui(16), color: _kPurple),
        ],
      ),
    );
  }
}

class _StudentSignRow extends StatelessWidget {
  const _StudentSignRow({required this.student, required this.onChangeStatus});

  final CourseSignStudent student;
  final ValueChanged<CourseSignStatus> onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          _MiniAvatar(
            seed: student.name,
            size: ui(32),
            imageUrl: student.headUrl,
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  student.studentNo,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          _StudentStatusChip(
            status: student.status,
            onTap: () async {
              final picked = await showCourseSignStatusPicker(
                context,
                studentName: student.name,
                studentNo: student.studentNo,
                headUrl: student.headUrl,
                current: student.status,
              );
              if (picked != null) onChangeStatus(picked);
            },
          ),
        ],
      ),
    );
  }
}

class _StudentStatusChip extends StatelessWidget {
  const _StudentStatusChip({required this.status, required this.onTap});

  final CourseSignStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final color = courseSignStatusFg(status);
    final bg = courseSignStatusBg(status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(4)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              courseSignStatusLabel(status),
              style: TextStyle(
                fontSize: ui(12),
                color: color,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
            SizedBox(width: ui(4)),
            Icon(Icons.edit_rounded, size: ui(11), color: color),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 小课管理 Tab
// =============================================================================

_SmallClassStep _deriveSmallClassStep(
  CourseSignSession session, {
  bool locallyConfirmed = false,
}) {
  if (locallyConfirmed || session.adminConfirmed) {
    return _SmallClassStep.adminConfirmed;
  }
  final step = session.signStep;
  if (step != null) {
    const mapping = [
      _SmallClassStep.notStarted,
      _SmallClassStep.teacherCheckedIn,
      _SmallClassStep.studentCheckedIn,
      _SmallClassStep.teacherCheckedOut,
      _SmallClassStep.studentCheckedOut,
      _SmallClassStep.studentEvaluated,
      _SmallClassStep.adminConfirmed,
    ];
    if (step >= 0 && step < mapping.length) return mapping[step];
    if (step >= mapping.length) return _SmallClassStep.adminConfirmed;
  }

  if (session.teacherCheckInTime == null) {
    return _SmallClassStep.notStarted;
  }
  final allStudentsIn =
      session.students.isNotEmpty &&
      session.students.every((s) => s.checkInTime != null);
  if (!allStudentsIn) return _SmallClassStep.studentCheckedIn;
  if (session.teacherCheckOutTime == null) {
    return _SmallClassStep.teacherCheckedOut;
  }
  final allStudentsOut = session.students.every((s) => s.checkOutTime != null);
  if (!allStudentsOut) return _SmallClassStep.studentCheckedOut;
  final allEvaluated = session.students.every(
    (s) =>
        s.evaluationRating != null || (s.evaluationNote?.isNotEmpty ?? false),
  );
  if (!allEvaluated) return _SmallClassStep.studentCheckedOut;
  return _SmallClassStep.studentEvaluated;
}

class _SmallClassTab extends ConsumerStatefulWidget {
  const _SmallClassTab({
    required this.pendingMakeupCount,
    required this.onOpenMakeupAudit,
    required this.onPendingMakeupChanged,
  });

  final int pendingMakeupCount;
  final VoidCallback onOpenMakeupAudit;
  final ValueChanged<int> onPendingMakeupChanged;

  @override
  ConsumerState<_SmallClassTab> createState() => _SmallClassTabState();
}

class _SmallClassTabState extends ConsumerState<_SmallClassTab> {
  List<_ClassFilterOption> _classOptions = _kFallbackClassOptions;
  String? _selectedClassId;
  String _selectedDate = todayIsoDate();
  List<CourseSignSession> _sessions = const [];
  CourseSignStats _stats = const CourseSignStats();
  final Set<String> _locallyConfirmedCourseIds = {};
  final Set<String> _submittingCourseIds = {};
  bool _loadingClasses = true;
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadClasses());
  }

  Future<void> _loadClasses() async {
    setState(() => _loadingClasses = true);
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.classList(type: 1);
    if (!mounted) return;

    final classes = resp.isSuccess
        ? parseCourseSignClassList(resp.data)
        : const <CourseSignClassOption>[];
    setState(() {
      _classOptions = _buildClassFilterOptions(classes);
      if (_selectedClassId != null &&
          !_classOptions.any((o) => o.id == _selectedClassId)) {
        _selectedClassId = null;
      }
      _loadingClasses = false;
    });
    await _loadSignData();
  }

  Future<void> _loadSignData() async {
    setState(() => _loadingData = true);
    final classId = _selectedClassId ?? '';
    final repo = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repo.courseSignSum1(classId: classId, date: _selectedDate),
      repo.courseSignManager(classId: classId, date: _selectedDate, type: 1),
    ]);
    if (!mounted) return;

    final sumResp = results[0];
    final listResp = results[1];
    if (!sumResp.isSuccess && sumResp.msg.isNotEmpty) {
      AppToast.show(context, sumResp.msg, type: AppToastType.error);
    }
    if (!listResp.isSuccess && listResp.msg.isNotEmpty) {
      AppToast.show(context, listResp.msg, type: AppToastType.error);
    }

    final stats = sumResp.isSuccess
        ? CourseSignStats.fromJson(sumResp.data)
        : const CourseSignStats();
    final sessions = listResp.isSuccess
        ? sortCourseSignSessions(
            enrichCourseSignSessions(parseCourseSignSessionList(listResp.data)),
          )
        : const <CourseSignSession>[];

    widget.onPendingMakeupChanged(stats.pendingMakeupCount);
    setState(() {
      _stats = stats;
      _sessions = sessions;
      _loadingData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pageLoading =
        _loadingClasses || (_loadingData && _sessions.isEmpty);

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SmallClassStatsRow(stats: _stats),
          SizedBox(height: ui(16)),
          _SmallClassFlowHint(),
          SizedBox(height: ui(16)),
          _FilterBar(
            selectedClassId: _selectedClassId,
            selectedDate: _selectedDate,
            classOptions: _classOptions,
            loading: _loadingClasses,
            onClassChanged: (id) {
              if (id == _selectedClassId) return;
              setState(() => _selectedClassId = id);
              unawaited(_loadSignData());
            },
            onDateChanged: (v) {
              setState(() => _selectedDate = v);
              unawaited(_loadSignData());
            },
          ),
          SizedBox(height: ui(16)),
          MainContentLoadingShell(
            loading: pageLoading,
            minHeight: ui(200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildListSection(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildListSection(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    if (_loadingData && _sessions.isEmpty) {
      return const [];
    }
    if (_classOptions.length <= 1) {
      return [_EmptyHint(text: '暂无小班班级，请先在班级编组中创建')];
    }
    if (_sessions.isEmpty) {
      return [_EmptyHint(text: '所选日期暂无小课签到记录')];
    }

    return [
      LayoutBuilder(
        builder: (context, constraints) {
          final spacing = ui(16);
          final cardWidth = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final session in _sessions)
                SizedBox(
                  width: cardWidth,
                  child: _SmallClassSessionCard(
                    session: session,
                    step: _deriveSmallClassStep(
                      session,
                      locallyConfirmed: _locallyConfirmedCourseIds.contains(
                        session.courseId,
                      ),
                    ),
                    confirming: _submittingCourseIds.contains(session.courseId),
                    onConfirm: () {
                      unawaited(_confirmCourse(session));
                    },
                    onViewEvaluation: () =>
                        unawaited(_loadAndShowEvaluation(session)),
                  ),
                ),
              if (widget.pendingMakeupCount > 0)
                SizedBox(
                  width: constraints.maxWidth,
                  child: _PendingMakeupRow(
                    count: widget.pendingMakeupCount,
                    onTap: widget.onOpenMakeupAudit,
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }

  Future<void> _confirmCourse(CourseSignSession session) async {
    if (session.courseId.isEmpty ||
        _submittingCourseIds.contains(session.courseId)) {
      return;
    }
    setState(() => _submittingCourseIds.add(session.courseId));
    final response = await ref
        .read(adminRepositoryProvider)
        .courseSignConfirm(courseId: session.courseId);
    if (!mounted) return;
    setState(() => _submittingCourseIds.remove(session.courseId));
    if (!response.isSuccess) {
      AppToast.show(
        context,
        response.displayMsg.isEmpty ? '确认失败' : response.displayMsg,
        type: AppToastType.error,
      );
      return;
    }
    setState(() => _locallyConfirmedCourseIds.add(session.courseId));
    AppToast.show(context, '课程已确认完成', type: AppToastType.success);
    await _loadSignData();
  }

  Future<void> _loadAndShowEvaluation(CourseSignSession session) async {
    final response = await ref
        .read(adminRepositoryProvider)
        .courseCommentList(courseId: session.courseId);
    if (!mounted) return;
    if (!response.isSuccess) {
      AppToast.show(
        context,
        response.displayMsg.isEmpty ? '评价加载失败' : response.displayMsg,
        type: AppToastType.error,
      );
      return;
    }
    final comments = parseCourseCommentList(response.data);
    _showEvaluationDialog(
      context,
      comments.isEmpty ? session : session.copyWith(students: comments),
    );
  }

  void _showEvaluationDialog(BuildContext context, CourseSignSession session) {
    final ui = DashboardScaleScope.of(context).ui;
    final evaluated = session.students
        .where(
          (s) =>
              s.evaluationRating != null ||
              (s.evaluationNote?.isNotEmpty ?? false),
        )
        .length;
    showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) => GradientHeaderDialog(
        title: '学生课后评价',
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$evaluated/${session.students.length} 人已评',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(12)),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: ui(360)),
              padding: EdgeInsets.all(ui(16)),
              decoration: BoxDecoration(
                color: _kPageBg,
                borderRadius: BorderRadius.circular(ui(12)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < session.students.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: ui(20),
                          thickness: 0.5,
                          color: _kBorderSoft,
                        ),
                      _StudentEvalBlock(student: session.students[i]),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: ui(16)),
            SizedBox(
              width: double.infinity,
              height: ui(44),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kBorderSoft),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ui(12)),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  '关闭',
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallClassStatsRow extends StatelessWidget {
  const _SmallClassStatsRow({required this.stats});

  final CourseSignStats stats;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final total = stats.courseCount;
    final completed = stats.completedCount;
    final pendingAdmin = stats.pendingAdminCount;
    final inProgress = stats.inProgressCount > 0
        ? stats.inProgressCount
        : (total - completed - pendingAdmin).clamp(0, total);
    return Row(
      children: [
        Expanded(
          child: SmartCampusStatCard(
            valueLabel: '$total',
            label: '今日小课总数',
            backgroundAsset: AppAssets.adminSignManagementStatCard1,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            valueLabel: '$inProgress',
            label: '进行中',
            backgroundAsset: AppAssets.adminSignManagementStatCard2,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            valueLabel: '$pendingAdmin',
            label: '待教务老师确认',
            backgroundAsset: AppAssets.adminSignManagementStatCard3,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            valueLabel: '$completed',
            label: '已完成',
            backgroundAsset: AppAssets.adminSignManagementStatCard4,
          ),
        ),
      ],
    );
  }
}

class _SmallClassFlowHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const steps = ['教师上课签', '学生上课签', '教师下课签', '学生下课签', '学生评价', '教务老师确认'];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPurpleSoftBg,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: ui(10),
                color: _kPurpleLight,
              ),
            Text(
              steps[i],
              style: TextStyle(
                fontSize: ui(11),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallClassSessionCard extends StatelessWidget {
  const _SmallClassSessionCard({
    required this.session,
    required this.step,
    required this.onConfirm,
    required this.onViewEvaluation,
    this.confirming = false,
  });

  final CourseSignSession session;
  final _SmallClassStep step;
  final VoidCallback onConfirm;
  final VoidCallback onViewEvaluation;
  final bool confirming;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isConfirmed = step == _SmallClassStep.adminConfirmed;
    final canConfirm = step == _SmallClassStep.studentEvaluated;
    final hasEval = step.index >= _SmallClassStep.studentEvaluated.index;
    final teacherLabel = session.teacherName.isEmpty
        ? '任课教师'
        : session.teacherName;
    final subtitle = _smallClassSessionSubtitle(session);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(
          color: canConfirm ? _kPurple.withValues(alpha: 0.35) : _kBorderSoft,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(ui(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  session.courseName,
                                  style: TextStyle(
                                    fontSize: ui(15),
                                    color: _kTextDark,
                                    fontFamily: 'PingFang SC',
                                    fontWeight: AppFont.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ui(6)),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kTextSecondary,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: ui(10)),
                    _SignSessionHeaderBadges(
                      className: session.className,
                      signStatus: session.signStatus,
                    ),
                  ],
                ),
                SizedBox(height: ui(12)),
                _SmallClassStepper(currentStep: step),
                SizedBox(height: ui(12)),
                _TimelineSection(
                  icon: Icons.person_rounded,
                  iconColor: _kPurple,
                  title: '$teacherLabel（教师）',
                  avatarUrl: session.teacherHeadUrl,
                  rows: [
                    _TimelineRow(
                      label: '上课签到',
                      time: session.teacherCheckInTime,
                      done: session.teacherCheckInTime != null,
                    ),
                    _TimelineRow(
                      label: '下课签到',
                      time: session.teacherCheckOutTime,
                      done: session.teacherCheckOutTime != null,
                    ),
                  ],
                ),
                SizedBox(height: ui(8)),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _kPageBg,
                    borderRadius: BorderRadius.circular(ui(8)),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(10),
                    vertical: ui(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            AppAssets.adminSignManagementStudentIcon,
                            width: ui(13),
                            height: ui(13),
                            fit: BoxFit.contain,
                          ),
                          SizedBox(width: ui(5)),
                          Expanded(
                            child: Text(
                              '学生（${session.students.length}人）',
                              style: TextStyle(
                                fontSize: ui(11),
                                color: _kTextSecondary,
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w500,
                                height: 1,
                              ),
                            ),
                          ),
                          const _StudentSignTimeColumnHeader(),
                        ],
                      ),
                      SizedBox(height: ui(8)),
                      for (var i = 0; i < session.students.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: ui(12),
                            thickness: 0.5,
                            color: _kBorderSoft,
                          ),
                        _StudentTimeRow(student: session.students[i]),
                      ],
                    ],
                  ),
                ),
                if (hasEval || canConfirm || isConfirmed) ...[
                  SizedBox(height: ui(12)),
                  Row(
                    children: [
                      if (hasEval) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onViewEvaluation,
                            icon: Icon(Icons.star_outline_rounded, size: ui(14)),
                            label: Text(
                              '查看评价',
                              style: TextStyle(
                                fontSize: ui(12),
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kPurple,
                              side: const BorderSide(color: _kPurple),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: ui(8)),
                            ),
                          ),
                        ),
                        if (canConfirm || isConfirmed)
                          SizedBox(width: ui(10)),
                      ],
                      if (canConfirm) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: confirming ? null : onConfirm,
                            icon: confirming
                                ? SizedBox(
                                    width: ui(14),
                                    height: ui(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: ui(14),
                                  ),
                            label: Text(
                              confirming ? '确认中…' : '确认完成',
                              style: TextStyle(
                                fontSize: ui(12),
                                fontFamily: 'PingFang SC',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kPurple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: ui(8)),
                            ),
                          ),
                        ),
                        if (isConfirmed) SizedBox(width: ui(10)),
                      ],
                      if (isConfirmed)
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(vertical: ui(8)),
                            decoration: BoxDecoration(
                              color: _kGreenBg,
                              borderRadius: BorderRadius.circular(ui(8)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: ui(14),
                                  color: _kGreen,
                                ),
                                SizedBox(width: ui(4)),
                                Text(
                                  '已确认完成',
                                  style: TextStyle(
                                    fontSize: ui(12),
                                    color: _kGreen,
                                    fontFamily: 'PingFang SC',
                                    fontWeight: AppFont.w500,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 教师签到区块 ──────────────────────────────────────────────────────────

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.rows,
    this.avatarUrl = '',
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<_TimelineRow> rows;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(8)),
      child: Row(
        children: [
          _MiniAvatar(seed: title, size: ui(30), imageUrl: avatarUrl),
          SizedBox(width: ui(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(5)),
                Row(
                  children: [
                    for (var row in rows) ...[
                      if (rows.indexOf(row) > 0) SizedBox(width: ui(16)),
                      _TimestampChip(
                        label: row.label,
                        time: row.time,
                        done: row.done,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow {
  const _TimelineRow({
    required this.label,
    required this.time,
    required this.done,
  });
  final String label;
  final String? time;
  final bool done;
}

class _TimestampChip extends StatelessWidget {
  const _TimestampChip({
    required this.label,
    required this.time,
    required this.done,
  });

  final String label;
  final String? time;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(11),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            height: 1,
          ),
        ),
        SizedBox(width: ui(4)),
        if (done) ...[
          Icon(Icons.check_circle_rounded, size: ui(12), color: _kGreen),
          SizedBox(width: ui(2)),
          Text(
            _formatSignClock(time),
            style: TextStyle(
              fontSize: ui(12),
              color: _kGreen,
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ] else
          Text(
            '—',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              height: 1,
            ),
          ),
      ],
    );
  }
}

class _TimelineLabel extends StatelessWidget {
  const _TimelineLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(10),
        color: color,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1,
      ),
    );
  }
}

// ── 学生签到行（含上课/下课时间戳）──────────────────────────────────────

class _StudentSignTimeColumnHeader extends StatelessWidget {
  const _StudentSignTimeColumnHeader();

  static double attendanceColWidth(double Function(double) ui) => ui(52);
  static double timeColWidth(double Function(double) ui) => ui(72);

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: attendanceColWidth(ui),
          child: const Center(
            child: _TimelineLabel(text: '考勤', color: _kTextHint),
          ),
        ),
        SizedBox(
          width: timeColWidth(ui),
          child: const Center(
            child: _TimelineLabel(text: '上课签到', color: _kTextHint),
          ),
        ),
        SizedBox(
          width: timeColWidth(ui),
          child: const Center(
            child: _TimelineLabel(text: '下课签到', color: _kTextHint),
          ),
        ),
      ],
    );
  }
}

class _StudentTimeRow extends StatelessWidget {
  const _StudentTimeRow({required this.student});

  final CourseSignStudent student;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        _MiniAvatar(
          seed: student.name,
          size: ui(28),
          imageUrl: student.headUrl,
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
              if (student.studentNo.isNotEmpty &&
                  student.studentNo != '--') ...[
                SizedBox(height: ui(2)),
                Text(
                  student.studentNo,
                  style: TextStyle(
                    fontSize: ui(10),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          width: _StudentSignTimeColumnHeader.attendanceColWidth(ui),
          child: Align(
            alignment: Alignment.center,
            child: _StudentAttendanceBadge(status: student.status),
          ),
        ),
        SizedBox(
          width: _StudentSignTimeColumnHeader.timeColWidth(ui),
          child: Center(
            child: _StudentTimeCell(time: student.checkInTime),
          ),
        ),
        SizedBox(
          width: _StudentSignTimeColumnHeader.timeColWidth(ui),
          child: Center(
            child: _StudentTimeCell(time: student.checkOutTime),
          ),
        ),
      ],
    );
  }
}

class _StudentAttendanceBadge extends StatelessWidget {
  const _StudentAttendanceBadge({required this.status});

  final CourseSignStatus? status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(3)),
      decoration: BoxDecoration(
        color: courseSignStatusBg(status),
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Text(
        courseSignStatusLabel(status),
        style: TextStyle(
          fontSize: ui(10),
          color: courseSignStatusFg(status),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _StudentTimeCell extends StatelessWidget {
  const _StudentTimeCell({required this.time});

  final String? time;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (time != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: ui(11), color: _kGreen),
          SizedBox(width: ui(3)),
          Text(
            _formatSignClock(time),
            style: TextStyle(
              fontSize: ui(12),
              color: _kGreen,
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      );
    }
    return Text(
      '未签到',
      style: TextStyle(
        fontSize: ui(11),
        color: _kTextHint,
        fontFamily: 'PingFang SC',
        height: 1,
      ),
    );
  }
}

class _SmallClassStepper extends StatelessWidget {
  const _SmallClassStepper({required this.currentStep});

  final _SmallClassStep currentStep;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const steps = [
      (label: '教师上课签', step: _SmallClassStep.teacherCheckedIn),
      (label: '学生上课签', step: _SmallClassStep.studentCheckedIn),
      (label: '教师下课签', step: _SmallClassStep.teacherCheckedOut),
      (label: '学生下课签', step: _SmallClassStep.studentCheckedOut),
      (label: '学生评价', step: _SmallClassStep.studentEvaluated),
      (label: '教务老师确认', step: _SmallClassStep.adminConfirmed),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: ui(9)),
                child: Row(
                  children: [
                    SizedBox(width: ui(6)),
                    Expanded(
                      child: Container(
                        height: ui(1),
                        color: currentStep.index >= steps[i].step.index
                            ? _kPurpleLight
                            : _kBorderHair,
                      ),
                    ),
                    SizedBox(width: ui(6)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _StepDot(
              label: steps[i].label,
              isDone: currentStep.index >= steps[i].step.index,
              isCurrent: currentStep == steps[i].step,
            ),
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.isDone,
    required this.isCurrent,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final Color dotColor;
    if (isDone) {
      dotColor = _kPurpleLight;
    } else if (isCurrent) {
      dotColor = _kOrange;
    } else {
      dotColor = _kBorderHair;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ui(20),
          height: ui(20),
          decoration: BoxDecoration(
            color: isDone ? _kPurpleLight : Colors.transparent,
            border: Border.all(color: dotColor, width: ui(2)),
            shape: BoxShape.circle,
          ),
          child: isDone
              ? Icon(Icons.check_rounded, size: ui(12), color: Colors.white)
              : null,
        ),
        SizedBox(height: ui(4)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: ui(9),
              color:
                  isDone ? _kPurpleLight : (isCurrent ? _kOrange : _kTextHint),
              fontFamily: 'PingFang SC',
              fontWeight: isDone ? AppFont.w500 : AppFont.w400,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _SmallClassStatusBadge extends StatelessWidget {
  const _SmallClassStatusBadge({required this.signStatus});

  final int signStatus;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final label = CourseSignFlowStatus.labelFor(signStatus);
    late Color color;
    late Color bg;
    if (signStatus == 6) {
      color = _kGreen;
      bg = _kGreenBg;
    } else if (signStatus == 5) {
      color = _kPurple;
      bg = _kPurpleSoftBg;
    } else if (signStatus == 7) {
      color = _kRed;
      bg = _kRedBg;
    } else if (signStatus == 0) {
      color = _kTextSecondary;
      bg = _kPageBg;
    } else if (signStatus >= 1 && signStatus <= 4) {
      color = _kOrange;
      bg = _kOrangeBg;
    } else {
      color = _kTextSecondary;
      bg = _kPageBg;
    }
    return Container(
      height: ui(_kSignBadgeHeight),
      padding: EdgeInsets.symmetric(horizontal: ui(_kSignBadgeHorizontalPadding)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(_kSignBadgeBorderRadius)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(_kSignBadgeFontSize),
          color: color,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 补签审核右侧抽屉
// =============================================================================

class _MakeupAuditDrawer extends ConsumerStatefulWidget {
  const _MakeupAuditDrawer({
    required this.onClose,
    required this.onAuditDone,
  });

  final VoidCallback onClose;
  final void Function(int remaining) onAuditDone;

  @override
  ConsumerState<_MakeupAuditDrawer> createState() => _MakeupAuditDrawerState();
}

class _MakeupAuditDrawerState extends ConsumerState<_MakeupAuditDrawer> {
  List<_MakeupRecord> _records = const [];
  bool _loading = true;
  String _error = '';

  /// 正在审批中的记录 id（防重复点击 + 局部 loading）。
  String _busyId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final res = await ref.read(adminRepositoryProvider).courseSignMakeupList();
    if (!mounted) return;
    if (res.isSuccess) {
      final rows = _extractMakeupRows(res.data);
      final records = rows
          .map(_MakeupRecord.fromManagerMap)
          .where((r) => r.id.isNotEmpty)
          .toList();
      setState(() {
        _records = records;
        _loading = false;
      });
      _reportPending();
    } else {
      setState(() {
        _records = const [];
        _loading = false;
        _error = res.msg.isNotEmpty ? res.msg : '补签申请加载失败';
      });
    }
  }

  void _reportPending() {
    final remaining = _records
        .where((r) => r.status == _MakeupStatus.pending)
        .length;
    widget.onAuditDone(remaining);
  }

  Future<void> _audit(int index, int status, {String auditReason = ''}) async {
    final record = _records[index];
    if (record.id.isEmpty || _busyId.isNotEmpty) return;
    setState(() => _busyId = record.id);
    final res = await ref
        .read(adminRepositoryProvider)
        .courseSignMakeupAudit(
          id: record.id,
          status: status,
          auditReason: auditReason,
        );
    if (!mounted) return;
    setState(() => _busyId = '');
    if (res.isSuccess) {
      setState(() {
        record.status = status == 1
            ? _MakeupStatus.approved
            : _MakeupStatus.rejected;
        if (status == 2) record.rejectReason = auditReason;
      });
      _reportPending();
      AppToast.show(
        context,
        status == 1 ? '已通过补签申请' : '已驳回补签申请',
        type: AppToastType.success,
      );
    } else {
      AppToast.show(
        context,
        res.msg.isNotEmpty ? res.msg : '操作失败，请重试',
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pending = _records
        .where((r) => r.status == _MakeupStatus.pending)
        .length;
    return Container(
      width: ui(520),
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(16)),
          bottomLeft: Radius.circular(ui(16)),
        ),
      ),
      child: Column(
        children: [
          // header
          Container(
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
                SizedBox(width: ui(8)),
                Text(
                  '补签申请审核',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(width: ui(8)),
                if (pending > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(6),
                      vertical: ui(2),
                    ),
                    decoration: BoxDecoration(
                      color: _kRed,
                      borderRadius: BorderRadius.circular(ui(8)),
                    ),
                    child: Text(
                      '$pending',
                      style: TextStyle(
                        fontSize: ui(11),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1,
                      ),
                    ),
                  ),
                const Spacer(),
                InkWell(
                  onTap: widget.onClose,
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
          ),
          // list
          Expanded(
            child: PageInitLoadingShell(
              loading: _loading && _records.isEmpty,
              child: _loading && _records.isEmpty
                  ? const SizedBox.shrink()
                  : _records.isEmpty
                ? Center(
                    child: Text(
                      _error.isNotEmpty ? _error : '暂无补签申请',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        ui(16),
                        ui(16),
                        ui(16),
                        ui(20),
                      ),
                      itemCount: _records.length,
                      separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                      itemBuilder: (ctx, i) => _MakeupAuditCard(
                        record: _records[i],
                        busy: _busyId == _records[i].id,
                        onApprove: () => _audit(i, 1),
                        onReject: (reason) =>
                            _audit(i, 2, auditReason: reason),
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

class _MakeupAuditCard extends StatelessWidget {
  const _MakeupAuditCard({
    required this.record,
    required this.onApprove,
    required this.onReject,
    this.busy = false,
  });

  final _MakeupRecord record;
  final VoidCallback onApprove;
  final void Function(String reason) onReject;

  /// 该卡审批中：禁用按钮，避免重复提交。
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isPending = record.status == _MakeupStatus.pending;
    final isApproved = record.status == _MakeupStatus.approved;
    return Container(
      padding: EdgeInsets.all(ui(14)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(
          color: isPending ? _kOrange.withValues(alpha: 0.4) : _kBorderSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头
          Row(
            children: [
              _MakeupStatusBadge(status: record.status),
              const Spacer(),
              Text(
                record.applyTime,
                style: TextStyle(
                  fontSize: ui(11),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(10)),
          // 申请人
          Row(
            children: [
              _MiniAvatar(
                seed: record.applicantName,
                size: ui(32),
                imageUrl: record.avatarUrl,
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            record.applicantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(13),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w600,
                              height: 1,
                            ),
                          ),
                        ),
                        if (record.studentNo.isNotEmpty) ...[
                          SizedBox(width: ui(6)),
                          Text(
                            record.studentNo,
                            style: TextStyle(
                              fontSize: ui(11),
                              color: _kTextHint,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: ui(2)),
                    Text(
                      record.applicantRole,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(11),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.signTypeLabel.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(6),
                    vertical: ui(2),
                  ),
                  decoration: BoxDecoration(
                    color: _kPurpleSoftBg,
                    borderRadius: BorderRadius.circular(ui(4)),
                  ),
                  child: Text(
                    record.signTypeLabel,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kPurple,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(10)),
          // 补签信息
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(10)),
            decoration: BoxDecoration(
              color: _kPageBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(label: '课程', value: record.courseName),
                SizedBox(height: ui(6)),
                _InfoLine(label: '补签课次', value: record.lessonDate),
                SizedBox(height: ui(6)),
                _InfoLine(
                  label: '补签理由',
                  value: record.reason.isEmpty ? '—' : record.reason,
                ),
                SizedBox(height: ui(6)),
                _InfoLine(
                  label: '类型',
                  value: record.classType == _ClassType.large ? '大课' : '小课',
                ),
              ],
            ),
          ),
          if (record.rejectReason != null &&
              record.rejectReason!.isNotEmpty) ...[
            SizedBox(height: ui(8)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: ui(10),
                vertical: ui(8),
              ),
              decoration: BoxDecoration(
                color: _kRedBg,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Text(
                '驳回原因：${record.rejectReason}',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kRed,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
            ),
          ],
          // 操作按钮（仅待审核状态）
          if (isPending) ...[
            SizedBox(height: ui(12)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _showRejectDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kRed,
                      side: const BorderSide(color: _kRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      padding: EdgeInsets.symmetric(vertical: ui(8)),
                    ),
                    child: Text(
                      '驳回',
                      style: TextStyle(
                        fontSize: ui(13),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ui(10)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      padding: EdgeInsets.symmetric(vertical: ui(8)),
                    ),
                    child: Text(
                      busy ? '处理中…' : '通过',
                      style: TextStyle(
                        fontSize: ui(13),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isApproved) ...[
            SizedBox(height: ui(10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: ui(14), color: _kGreen),
                SizedBox(width: ui(4)),
                Text(
                  '已通过审核',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kGreen,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final controller = TextEditingController();
    final ui = DashboardScaleScope.of(context).ui;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '驳回原因',
          style: TextStyle(
            fontSize: ui(15),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        content: AppTextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '请填写驳回原因…',
            hintStyle: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            contentPadding: EdgeInsets.all(ui(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(ctx).pop();
              onReject(reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ui(8)),
              ),
            ),
            child: Text('确认驳回', style: TextStyle(fontFamily: 'PingFang SC')),
          ),
        ],
      ),
    );
  }
}

class _MakeupStatusBadge extends StatelessWidget {
  const _MakeupStatusBadge({required this.status});

  final _MakeupStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (String label, Color color, Color bg) = switch (status) {
      _MakeupStatus.pending => ('待审核', _kOrange, _kOrangeBg),
      _MakeupStatus.approved => ('已通过', _kGreen, _kGreenBg),
      _MakeupStatus.rejected => ('已驳回', _kRed, _kRedBg),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(7), vertical: ui(3)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(11),
          color: color,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 共用小组件
// =============================================================================

const _kAllClasses = '全部班级';

class _ClassFilterOption {
  const _ClassFilterOption({required this.id, required this.label});

  /// `null` = 全部班级。
  final String? id;
  final String label;

  static const all = _ClassFilterOption(id: null, label: _kAllClasses);

  @override
  bool operator ==(Object other) =>
      other is _ClassFilterOption && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

const _kFallbackClassOptions = <_ClassFilterOption>[_ClassFilterOption.all];

List<_ClassFilterOption> _buildClassFilterOptions(
  List<CourseSignClassOption> classes,
) {
  return [
    _ClassFilterOption.all,
    ...classes.map((c) => _ClassFilterOption(id: c.id, label: c.name)),
  ];
}

class _ClassFilterField extends StatefulWidget {
  const _ClassFilterField({
    required this.options,
    required this.selectedClassId,
    required this.loading,
    required this.onChanged,
  });

  final List<_ClassFilterOption> options;
  final String? selectedClassId;
  final bool loading;
  final ValueChanged<String?> onChanged;

  @override
  State<_ClassFilterField> createState() => _ClassFilterFieldState();
}

class _ClassFilterFieldState extends State<_ClassFilterField> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  _ClassFilterOption get _selected => widget.options.firstWhere(
    (o) => o.id == widget.selectedClassId,
    orElse: () => _ClassFilterOption.all,
  );

  String get _label => widget.loading ? '加载班级…' : _selected.label;

  Future<void> _openMenu() async {
    if (widget.loading) return;
    final fieldCtx = _fieldKey.currentContext;
    if (fieldCtx == null) return;
    setState(() => _open = true);
    final selected = await showAppPopupSelector<_ClassFilterOption>(
      anchorContext: fieldCtx,
      items: widget.options,
      value: _selected,
      itemLabel: (o) => o.label,
      width: DashboardScaleScope.of(fieldCtx).ui(280),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null) widget.onChanged(selected.id);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      key: _fieldKey,
      onTap: _openMenu,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: ui(220),
        height: ui(44),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _label,
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedClassId,
    required this.selectedDate,
    required this.classOptions,
    required this.loading,
    required this.onClassChanged,
    required this.onDateChanged,
  });

  final String? selectedClassId;
  final String selectedDate;
  final List<_ClassFilterOption> classOptions;
  final bool loading;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        _ClassFilterField(
          options: classOptions,
          selectedClassId: selectedClassId,
          loading: loading,
          onChanged: onClassChanged,
        ),
        SizedBox(width: ui(10)),
        // 日期 picker pill
        InkWell(
          onTap: () async {
            final picked = await showAppDatePicker(
              context: context,
              initialDate: DateTime.tryParse(selectedDate) ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              helpText: '选择日期',
              cancelText: '取消',
              confirmText: '确定',
            );
            if (picked != null) {
              final iso =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              onDateChanged(iso);
            }
          },
          borderRadius: BorderRadius.circular(ui(12)),
          child: Container(
            height: ui(44),
            padding: EdgeInsets.symmetric(horizontal: ui(16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppPickerAssetIcon(
                  AppAssets.iconScheduleCalendar,
                  imageSize: ui(18),
                ),
                SizedBox(width: ui(10)),
                Text(
                  selectedDate,
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.2,
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(48)),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(13),
          color: _kTextHint,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

class _PendingMakeupRow extends StatelessWidget {
  const _PendingMakeupRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (count == 0) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(10)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
        decoration: BoxDecoration(
          color: _kOrangeBg,
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: _kOrange.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.pending_actions_rounded, size: ui(18), color: _kOrange),
            SizedBox(width: ui(8)),
            Text(
              '待审核补签申请  $count 条',
              style: TextStyle(
                fontSize: ui(13),
                color: _kOrange,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: ui(18), color: _kOrange),
          ],
        ),
      ),
    );
  }
}

class _SignProgressPill extends StatelessWidget {
  const _SignProgressPill({required this.signed, required this.total});

  final int signed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isAll = signed >= total && total > 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(4)),
      decoration: BoxDecoration(
        color: isAll ? _kGreenBg : _kOrangeBg,
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Text(
        '$signed / $total 已签',
        style: TextStyle(
          fontSize: ui(11),
          color: isAll ? _kGreen : _kOrange,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({
    required this.seed,
    required this.size,
    this.imageUrl = '',
  });

  final String seed;
  final double size;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final firstChar = seed.isNotEmpty ? seed.characters.first : '?';
    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFB98FFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        firstChar,
        style: TextStyle(
          fontSize: size * 0.4,
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
    return SmoothCircleNetworkAvatar(
      url: imageUrl,
      size: size,
      placeholder: fallback,
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
          width: ui(60),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
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
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// 评价弹窗内单个学生的评价卡。
class _StudentEvalBlock extends StatelessWidget {
  const _StudentEvalBlock({required this.student});

  final CourseSignStudent student;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final rating = student.evaluationRating;
    final hasEval =
        rating != null ||
        (student.evaluationNote?.isNotEmpty ?? false) ||
        (student.evaluationMastery?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _MiniAvatar(
              seed: student.name,
              size: ui(28),
              imageUrl: student.headUrl,
            ),
            SizedBox(width: ui(8)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  student.studentNo,
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    height: 1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (rating != null)
              Row(
                children: [
                  ...List.generate(5, (i) {
                    final filled = i < rating.floor();
                    final half = !filled && i < rating;
                    return Icon(
                      half ? Icons.star_half_rounded : Icons.star_rounded,
                      size: ui(14),
                      color: filled || half ? _kOrange : _kBorderSoft,
                    );
                  }),
                  SizedBox(width: ui(4)),
                  Text(
                    '$rating',
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kOrange,
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ],
              )
            else
              Text(
                '未评价',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  height: 1,
                ),
              ),
          ],
        ),
        if (hasEval) ...[
          SizedBox(height: ui(8)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(10)),
            decoration: BoxDecoration(
              color: _kPageBg,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (student.evaluationMastery?.isNotEmpty == true)
                  _EvalRow(label: '掌握程度', value: student.evaluationMastery!),
                if (student.evaluationNote?.isNotEmpty == true) ...[
                  if (student.evaluationMastery?.isNotEmpty == true)
                    SizedBox(height: ui(6)),
                  _EvalRow(label: '评价备注', value: student.evaluationNote!),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EvalRow extends StatelessWidget {
  const _EvalRow({required this.label, required this.value});

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
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 数据模型（管理员补签审核接口开放后可直接复用）
// =============================================================================

String _formatSignClock(String? raw) {
  final clock = pickCourseClock(raw);
  if (clock != null) return clock;
  final trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? '--' : trimmed;
}

String _largeClassSessionSubtitle(CourseSignSession session) {
  final parts = <String>[];
  if (session.lineNum > 0) {
    parts.add('第${session.lineNum}节');
  }
  final start = pickCourseClock(session.courseStartTime);
  final end = pickCourseClock(session.courseEndTime);
  if (start != null && end != null) {
    parts.add('$start - $end');
  } else if (session.timeRange.isNotEmpty) {
    parts.add(session.timeRange);
  }
  if (session.classroom.isNotEmpty && session.classroom != '--') {
    parts.add(session.classroom);
  }
  if (session.teacherName.isNotEmpty) {
    parts.add('任课：${session.teacherName}');
  }
  parts.add('${session.students.length}名学生');
  return parts.join(' · ');
}

String _smallClassSessionSubtitle(CourseSignSession session) {
  final parts = <String>[];
  if (session.lineNum > 0) {
    parts.add('第${session.lineNum}节');
  }
  final start = pickCourseClock(session.courseStartTime);
  final end = pickCourseClock(session.courseEndTime);
  if (start != null && end != null) {
    parts.add('$start - $end');
  } else if (session.timeRange.isNotEmpty) {
    parts.add(session.timeRange);
  }
  if (session.classroom.isNotEmpty && session.classroom != '--') {
    parts.add(session.classroom);
  }
  parts.add('${session.students.length}名学生');
  return parts.join(' · ');
}

enum _SmallClassStep {
  notStarted,
  teacherCheckedIn,
  studentCheckedIn,
  teacherCheckedOut,
  studentCheckedOut,
  studentEvaluated,
  adminConfirmed,
}

enum _ClassType { large, small }

enum _MakeupStatus { pending, approved, rejected }

class _MakeupRecord {
  _MakeupRecord({
    required this.id,
    required this.applicantName,
    required this.applicantRole,
    required this.courseName,
    required this.lessonDate,
    required this.reason,
    required this.classType,
    required this.applyTime,
    required this.status,
    this.signTypeLabel = '',
    this.avatarUrl = '',
    this.studentNo = '',
    this.rejectReason,
  });

  /// 补签申请记录 id（审批接口入参）。
  final String id;
  final String applicantName;
  final String applicantRole;
  final String courseName;
  final String lessonDate;
  final String reason;
  final _ClassType classType;
  final String applyTime;

  /// 补签类型（上课签/下课签/课堂补签）。
  final String signTypeLabel;

  /// 申请人头像（已 resolve 的完整地址）。
  final String avatarUrl;

  /// 学号。
  final String studentNo;
  _MakeupStatus status;
  String? rejectReason;

  static _MakeupRecord fromManagerMap(Map<dynamic, dynamic> m) {
    String s(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        final t = v.toString().trim();
        if (t.isNotEmpty && t != 'null') return t;
      }
      return '';
    }

    int i(List<String> keys) {
      for (final k in keys) {
        final v = int.tryParse(m[k]?.toString() ?? '');
        if (v != null) return v;
      }
      return 0;
    }

    final statusCode = i(['status', 'auditStatus']);
    final status = switch (statusCode) {
      1 => _MakeupStatus.approved,
      2 => _MakeupStatus.rejected,
      _ => _MakeupStatus.pending,
    };
    final type = i(['type', 'courseType', 'classType']);
    final date = s(['courseDate', 'date']);
    final line = i(['lineNum']);
    final lessonDate = [
      if (date.isNotEmpty) date,
      if (line > 0) '第$line节',
    ].join(' ');
    final className = s(['className']);
    final approveRemark = s(['approveRemark', 'auditReason', 'auditRemark']);
    final studentName = s([
      'studentName',
      'studentRealname',
      'studentNickname',
      'realname',
    ]);
    final head = s(['studentHeadUrl', 'headUrl', 'teacherHeadUrl']);
    return _MakeupRecord(
      id: s(['id']),
      applicantName: studentName.isNotEmpty ? studentName : '学生',
      applicantRole: className.isNotEmpty ? className : '学生',
      courseName: s(['subjectName', 'courseName', 'name']).isNotEmpty
          ? s(['subjectName', 'courseName', 'name'])
          : '未命名课程',
      lessonDate: lessonDate.isEmpty ? '—' : lessonDate,
      reason: s(['reason']),
      classType: type == 0 ? _ClassType.large : _ClassType.small,
      applyTime: s(['createTime', 'applyTime']),
      status: status,
      signTypeLabel: _makeupSignTypeLabel(s(['signType'])),
      avatarUrl: head.isEmpty ? '' : MediaUrl.resolve(head),
      studentNo: s(['studentNo', 'no']),
      rejectReason: (status == _MakeupStatus.rejected && approveRemark.isNotEmpty)
          ? approveRemark
          : null,
    );
  }
}

/// 归一化补签类型标签，兼容中文 / 数字串 / 异常值。
String _makeupSignTypeLabel(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '课堂补签';
  if (t.contains('上课')) return '上课签';
  if (t.contains('下课')) return '下课签';
  if (t == '1') return '上课签';
  if (t == '2') return '下课签';
  return '课堂补签';
}

/// 从分页响应中取出补签记录数组（`records` / `list` / `rows` 或数组）。
List<Map<dynamic, dynamic>> _extractMakeupRows(dynamic data) {
  if (data is List) {
    return data.whereType<Map<dynamic, dynamic>>().toList();
  }
  if (data is Map) {
    for (final key in ['records', 'list', 'rows']) {
      final v = data[key];
      if (v is List) return v.whereType<Map<dynamic, dynamic>>().toList();
    }
  }
  return const [];
}
