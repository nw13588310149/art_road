// =============================================================================
// 任课老师 / 班主任端「签课管理」独立页面
//
// 入口：教师 dashboard 快捷区「签课管理」按钮 → controller.openClassAttendance()
//      → mainView == classAttendance + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 渐变；左 32 返回；居中 "签课管理"
//      16/600；右上 "历史记录" pill（紫色时钟 icon + 12/600 黑字）。
//   2. "签课数据统计" section header（18/500 #1A1A1A）+ 右侧 44 高 3 段
//      pill 切换器：总数据 / 本学期 / 本月（激活段 #0B081A 黑底白字 6 圆角）。
//   3. 5 张统计卡（一行平铺，white 100 高，12 圆角）：签课节次数 /
//      正常签到 / 学生迟到 / 缺勤人次 / 出勤率（紫色）。
//      第一张右上加紫色渐变装饰圈，与 Figma 一致。
//   4. "最近签课记录" section + 右侧"查看全部 ›"链接 → 一行 3 张
//      312 宽白卡：时间 18/600 + 日期 12/400；课名；
//      第N节 副标；右侧 40 头像；底部 50 高灰底统计（应到/实到/签到方式）。
//   5. 双列：
//      · 左 340 宽 "今日课程" 面板（白底 16 圆角 12 padding）：日期 16/500
//        + 多张 316×104 时间段卡（基础样式与首页课程卡完全共用，仅选中态
//        追加阴影）。点卡片切换右侧 active class。
//      · 右 614 宽 "签到操作" 面板：614×465 白底 16 圆角，顶部
//        "第N节·HH:MM-HH:MM" + 班级 + 课名 + 课时·教室；中部 #F5F6FA 灰底
//        "班级学生"块（4 状态 chip：出勤/缺勤/迟到/请假 + 学生网格，点击头像
//        弹窗选择状态）；下方提示带（"待完成全班签课" + 说明文案）；最底紫色
//        渐变"一键完成全班签到"按钮。
//
// 颜色：白卡 / #F5F6FA 灰底 / #F3F2F3 边 / #715EFE 主紫 /
//      #0CAC40 出勤绿 / #FF323C 缺勤红 / #325BFF 请假蓝 / #B6B5BB 提示
// 字体：PingFang SC（标题 16/18 / 正文 12/14）+ Barlow（时间 18 / 数值 32）
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/course_subject_tag.dart';
import '../../../core/widgets/dashboard_course_notice_card.dart'
    show DashboardCourseRunState;
import '../data/course_sign_data.dart';
import '../data/teacher_attendance_data.dart';
import '../state/teacher_attendance_controller.dart';
import 'course_sign_countdown.dart';
import 'widgets/course_sign_status_picker.dart';
import '../data/campus_format.dart';
import '../../home/ui/widgets/home_course_notice_card.dart';
import '../../shell/ui/shell_layout.dart';
import 'widgets/smart_campus_dark_tabs.dart';
import 'widgets/smart_campus_filter_bar.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

// ---- 配色（原版色值；紫色统一为品牌紫）--------------------------------------
const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = AppColors.brand;
const Color _kPurpleSoftHint = AppColors.brandWash; // 待签课提示带 bg
const Color _kEndedTagBg = Color(0xFFE6E9F1);
const Color _kStatusPresent = Color(0xFF0CAC40); // 实到

// 各区块最低高度（Figma 设计值），避免数据加载前后页面高度跳动。
const double _kRecentRecordSectionMinHeight = 178;
const double _kSignActionPanelMinHeight = 465;
const double _kHistoryListMinHeight = 320;

// ---- 数据模型 ---------------------------------------------------------------

/// 课程进行状态：影响今日课程卡的底色（已结束=灰，进行中=淡紫）以及
/// 角标文本（已结束 / 进行中 / 待开始）。
enum _ClassRunState { ended, inProgress, upcoming }

/// 学生考勤状态（UI 展示用）；点击头像弹窗选择，不循环切换。
enum _AttendStatus { present, late, leave, absent, missing }

class _StudentAttend {
  _StudentAttend({
    this.studentId = '',
    required this.name,
    this.studentNo = '--',
    this.headUrl = '',
    required this.status,
    this.remark = '',
  });

  final String studentId;
  final String name;
  final String studentNo;
  final String headUrl;
  _AttendStatus status;
  final String remark;
}

class _AttendClass {
  _AttendClass({
    required this.courseId,
    required this.periodIndex,
    required this.startTime,
    required this.endTime,
    required this.teacherName,
    required this.courseName,
    required this.duration,
    required this.location,
    required this.runState,
    required this.signStatus,
    required this.signStatusLabel,
    required this.students,
    this.teacherCheckInTime,
    this.logoUrl = '',
    this.teacherHeadUrl = '',
    this.colorHex = '',
    this.className = '',
  });

  final String courseId;
  final int periodIndex;
  final String startTime;
  final String endTime;
  final String teacherName;
  final String courseName;
  final String duration;
  final String location;
  final _ClassRunState runState;
  final int signStatus;
  final String signStatusLabel;
  final String? teacherCheckInTime;
  final String logoUrl;
  final String teacherHeadUrl;
  final String colorHex;
  final String className;

  /// 班级学生名单。
  final List<_StudentAttend> students;

  /// 课程卡片头像：任课老师头像，缺失时由头像组件显示老师姓氏。
  String get cardAvatarUrl => teacherHeadUrl;

  String get cardAvatarSeed =>
      teacherName.isNotEmpty ? teacherName : courseName;
}

class _StatItem {
  const _StatItem({
    required this.value,
    required this.label,
    this.valueColor = _kTextDark,
  });

  final String value;
  final String label;
  final Color valueColor;
}

class _RecentRecord {
  const _RecentRecord({
    required this.time,
    required this.date,
    required this.courseName,
    required this.periodLabel,
    required this.subtitle,
    required this.logoUrl,
    required this.avatarSeed,
    required this.expected,
    required this.present,
    required this.method,
    required this.signInClock,
    required this.signStatusLabel,
    required this.hasAttendanceCounts,
  });

  final String time;
  final String date;
  final String courseName;
  final String periodLabel;
  final String subtitle;
  final String logoUrl;
  final String avatarSeed;
  final int expected;
  final int present;
  final String method;
  final String signInClock;
  final String signStatusLabel;
  final bool hasAttendanceCounts;
}

List<_StatItem> _statsFromSummary(TeacherAttendanceSummary summary) {
  final rate = summary.attendanceRate;
  final rateLabel = rate % 1 == 0
      ? '${rate.toStringAsFixed(0)}%'
      : '${rate.toStringAsFixed(1)}%';
  return [
    _StatItem(value: '${summary.totalCount}', label: '签课节次数'),
    _StatItem(value: '${summary.normalCount}', label: '正常签到'),
    _StatItem(value: '${summary.lateCount}', label: '学生迟到'),
    _StatItem(value: '${summary.absentCount}', label: '缺勤人次'),
    _StatItem(value: rateLabel, label: '出勤率（正常 + 迟到）', valueColor: _kPurple),
  ];
}

_RecentRecord _recentRecordFromHistory(TeacherSignHistoryItem item) {
  return _RecentRecord(
    time: item.time.isEmpty ? '--:--' : item.time,
    date: _dateOnly(item.date),
    courseName: item.courseName,
    periodLabel: item.lineNum > 0 ? '第${item.lineNum}节' : '签课记录',
    subtitle: item.subtitle,
    logoUrl: item.logoUrl,
    avatarSeed: item.avatarSeed,
    expected: item.shouldCount,
    present: item.presentCount,
    method: item.method,
    signInClock: item.signInClock,
    signStatusLabel: item.signStatusLabel,
    hasAttendanceCounts: item.hasAttendanceCounts,
  );
}

// =============================================================================
// 入口 widget
// =============================================================================

class TeacherClassAttendanceView extends ConsumerStatefulWidget {
  const TeacherClassAttendanceView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherClassAttendanceView> createState() =>
      _TeacherClassAttendanceViewState();
}

class _TeacherClassAttendanceViewState
    extends ConsumerState<TeacherClassAttendanceView>
    with WidgetsBindingObserver {
  /// 0 = 总数据 / 1 = 本学期 / 2 = 本月。切换后重新拉取对应时间范围统计。
  int _selectedTabIdx = 0;

  /// 双列右侧 active class 索引；默认指向"进行中"那节课。
  int _activeClassIdx = 0;

  /// 用户是否手动点过某节课。未手动选择时，默认选中"接下来时间第一节"
  /// （即第一节尚未结束的课），而不是列表第一节。
  bool _userPickedCourse = false;

  /// 是否切到「历史记录」子页面（banner 右上"历史记录"按钮 / "查看全部"
  /// 链接触发）。子页面 banner 的返回按钮把它置回 false，回到本主页。
  bool _showHistory = false;

  /// 历史记录子页面的搜索文本（课程、节次、教室）。
  String _historyQuery = '';

  Timer? _runStateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runStateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(teacherAttendanceControllerProvider.notifier);
      await notifier.initialize();
      notifier.startLiveSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _runStateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_showHistory) {
      unawaited(
        ref.read(teacherAttendanceControllerProvider.notifier).resumeSync(),
      );
    }
  }

  void _selectClass(int idx, List<_AttendClass> classes) {
    if (_activeClassIdx == idx && _userPickedCourse) return;
    setState(() {
      _activeClassIdx = idx;
      _userPickedCourse = true;
    });
    final course = classes[idx];
    if (course.courseId.isNotEmpty) {
      unawaited(
        ref
            .read(teacherAttendanceControllerProvider.notifier)
            .selectCourse(course.courseId),
      );
    }
  }

  Future<void> _pickStudentStatus(_AttendClass course, int studentIdx) async {
    final student = course.students[studentIdx];
    final picked = await showCourseSignStatusPicker(
      context,
      studentName: student.name,
      studentNo: student.studentNo,
      headUrl: student.headUrl,
      current: _courseSignStatusOf(student.status),
    );
    if (picked == null || !mounted) return;
    final response = await ref
        .read(teacherAttendanceControllerProvider.notifier)
        .updateStudentStatus(
          courseId: course.courseId,
          studentId: student.studentId,
          status: picked,
        );
    if (!mounted) return;
    AppToast.show(
      context,
      response.isSuccess ? '签到状态已更新' : response.displayMsg,
      type: response.isSuccess ? AppToastType.success : AppToastType.error,
    );
  }

  Future<void> _bulkSign(_AttendClass course) async {
    final response = await ref
        .read(teacherAttendanceControllerProvider.notifier)
        .bulkSign(course.courseId);
    if (!mounted) return;
    AppToast.show(
      context,
      response.isSuccess ? '已完成全班签到' : response.displayMsg,
      type: response.isSuccess ? AppToastType.success : AppToastType.error,
    );
  }

  void _openHistory() {
    if (_showHistory) return;
    ref.read(teacherAttendanceControllerProvider.notifier).stopLiveSync();
    setState(() => _showHistory = true);
    unawaited(
      ref.read(teacherAttendanceControllerProvider.notifier).loadHistory(),
    );
  }

  void _closeHistory() {
    if (!_showHistory) return;
    setState(() => _showHistory = false);
    ref.read(teacherAttendanceControllerProvider.notifier).startLiveSync();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final attendance = ref.watch(teacherAttendanceControllerProvider);
    final classes = attendance.todayCourses
        .map(_attendClassFromSession)
        .toList();
    final selectedId = attendance.selectedCourseId;
    // 默认选中"接下来时间第一节"（第一节未结束的课）；用户手动点过后用其选择。
    var defaultActiveIdx = classes.indexWhere(
      (item) => item.runState != _ClassRunState.ended,
    );
    if (defaultActiveIdx < 0) defaultActiveIdx = 0;
    var activeIdx = classes.isEmpty
        ? 0
        : (_userPickedCourse
              ? _activeClassIdx.clamp(0, classes.length - 1)
              : defaultActiveIdx);
    if (selectedId != null && selectedId.isNotEmpty) {
      final matched = classes.indexWhere((item) => item.courseId == selectedId);
      if (matched >= 0) {
        activeIdx = matched;
      }
    }
    final recentRecords = attendance.recentRecords
        .map(_recentRecordFromHistory)
        .toList(growable: false);
    if (_showHistory) {
      return _HistoryView(
        onBack: _closeHistory,
        query: _historyQuery,
        onQueryChanged: (v) => setState(() => _historyQuery = v),
        records: attendance.historyRecords,
        loading: attendance.loadingHistory,
        error: attendance.historyError,
      );
    }
    final stats = _statsFromSummary(attendance.summary);
    return SmartCampusSecondaryPageShell(
      header: SmartCampusPageBanner(
        title: '签课管理',
        onBack: widget.onBack,
        actions: [_BannerHistoryButton(onTap: _openHistory)],
      ),
      bodyScrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsHeaderRow(
            tabIdx: _selectedTabIdx,
            onTab: (i) {
              setState(() => _selectedTabIdx = i);
              unawaited(
                ref
                    .read(teacherAttendanceControllerProvider.notifier)
                    .selectRange(TeacherAttendanceRange.values[i]),
              );
            },
          ),
          SizedBox(height: ui(12)),
          _StatsRow(stats: stats),
          SizedBox(height: ui(16)),
          _SectionHeaderRow(
            title: '最近签课记录',
            trailingLabel: '查看全部',
            onTrailingTap: _openHistory,
          ),
          SizedBox(height: ui(12)),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: ui(_kRecentRecordSectionMinHeight),
            ),
            child: recentRecords.isEmpty
                ? _AttendanceEmptyPanel(
                    loading: false,
                    message: '暂无最近签课记录',
                    expand: true,
                  )
                : _RecentRecordsRow(records: recentRecords),
          ),
          SizedBox(height: ui(16)),
          // 双列：今日课程 + 签到操作（空态也保留结构，避免加载后高度突变）
          LayoutBuilder(
            builder: (context, c) {
              final emptyMessage = attendance.error.isNotEmpty
                  ? attendance.error
                  : '今日暂无课程';
              final actionPanel = classes.isEmpty
                  ? _SignActionEmptyPanel(loading: false, message: emptyMessage)
                  : _ActionPanelSwitcher(
                      data: classes[activeIdx],
                      onPickStudentStatus: (idx) =>
                          _pickStudentStatus(classes[activeIdx], idx),
                      onBulkSign: () => _bulkSign(classes[activeIdx]),
                    );
              final isCompact = c.maxWidth < ui(720);
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('今日课程'),
                    SizedBox(height: ui(12)),
                    _TodayClassesPanel(
                      title: _todayPanelTitle(),
                      classes: classes,
                      activeIdx: activeIdx,
                      emptyMessage: emptyMessage,
                      onSelect: (idx) => _selectClass(idx, classes),
                    ),
                    SizedBox(height: ui(16)),
                    _SectionTitle('签到操作'),
                    SizedBox(height: ui(12)),
                    actionPanel,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: ui(340),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('今日课程'),
                        SizedBox(height: ui(12)),
                        _TodayClassesPanel(
                          title: _todayPanelTitle(),
                          classes: classes,
                          activeIdx: activeIdx,
                          emptyMessage: emptyMessage,
                          onSelect: (idx) => _selectClass(idx, classes),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: ui(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('签到操作'),
                        SizedBox(height: ui(12)),
                        actionPanel,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _todayPanelTitle() => campusDateWithWeekday(DateTime.now());
}

// =============================================================================
// 顶部 banner（62 高）：共享 SmartCampusPageBanner + 右侧「历史记录」按钮
// =============================================================================

/// 原版横幅右侧「历史记录」：高 34、白底描边、圆角 8，16 号品牌紫时钟图标 +
/// 12/600 文字。
class _BannerHistoryButton extends StatelessWidget {
  const _BannerHistoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: ui(34),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: ui(16), color: _kPurple),
            SizedBox(width: ui(4)),
            Text(
              '历史记录',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 签课数据统计 header（标题 + 3 段 tab 切换器）
// =============================================================================

class _StatsHeaderRow extends StatelessWidget {
  const _StatsHeaderRow({required this.tabIdx, required this.onTab});

  final int tabIdx;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const labels = ['总数据', '本学期', '本月'];
    return Row(
      children: [
        Expanded(
          child: Text(
            '签课数据统计',
            style: TextStyle(
              fontSize: ui(18),
              color: _kTextSection,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
        // 原版黑底页签（带描边）：容器高 44、选项高 36。
        SmartCampusDarkTabs<int>(
          segments: [
            for (var i = 0; i < labels.length; i++)
              AppSegment(value: i, label: labels[i]),
          ],
          value: tabIdx,
          onChanged: onTab,
        ),
      ],
    );
  }
}

// =============================================================================
// 5 张统计卡（一行平铺，white 100 高）
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<_StatItem> stats;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) SizedBox(width: ui(12)),
          Expanded(child: _StatCard(item: stats[i])),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 原版统计卡：白底、高 100、圆角 12、内距 16；标签 14/500，数值 Barlow 24。
    return Container(
      height: ui(100),
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(16)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 「出勤率（正常 + 迟到）」在窄横屏下放不进一行，允许折成两行。
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(14),
              color: Colors.black,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: smartCampusStatValueTextStyle(ui, color: item.valueColor),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// section 公共 header
// =============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(18),
        color: _kTextSection,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1,
      ),
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.title,
    required this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final String trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(child: _SectionTitle(title)),
        InkWell(
          onTap: onTrailingTap,
          borderRadius: BorderRadius.circular(ui(6)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextSecondary,
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
                SizedBox(width: ui(2)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: ui(16),
                  color: const Color(0xFFCECED1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 最近签课记录（一行 3 张 312 宽白卡）
// =============================================================================

class _RecentRecordsRow extends StatelessWidget {
  const _RecentRecordsRow({required this.records});

  final List<_RecentRecord> records;

  /// 固定一行 3 列：每列等宽（1/3）。不足 3 条用空位占位，卡片不拉伸，
  /// 因此只有 2 条时占据 2/3 宽度，最后一列留空。
  static const int _slots = 3;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _slots; i++) ...[
          if (i > 0) SizedBox(width: ui(16)),
          Expanded(
            child: i < records.length
                ? _RecentRecordCard(record: records[i])
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _AttendanceEmptyPanel extends StatelessWidget {
  const _AttendanceEmptyPanel({
    required this.loading,
    required this.message,
    this.expand = false,
  });

  final bool loading;
  final String message;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final content = loading
        ? const AppLoadingIndicator()
        : Text(
            message.isEmpty ? '暂无数据' : message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontWeight: AppFont.w400,
            ),
          );
    return Container(
      width: double.infinity,
      padding: expand ? null : EdgeInsets.symmetric(vertical: ui(28)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      alignment: Alignment.center,
      child: content,
    );
  }
}

class _RecentRecordCard extends StatelessWidget {
  const _RecentRecordCard({required this.record});

  final _RecentRecord record;

  @override
  Widget build(BuildContext context) {
    return _TeacherSignRecordCard(
      time: record.time,
      headerTrailing: record.date,
      courseName: record.courseName,
      subtitle: record.subtitle,
      avatarSeed: record.avatarSeed,
      logoUrl: record.logoUrl,
      expected: record.expected,
      present: record.present,
      method: record.method,
      signInClock: record.signInClock,
      signStatusLabel: record.signStatusLabel,
      hasAttendanceCounts: record.hasAttendanceCounts,
    );
  }
}

class _TeacherSignRecordCard extends StatelessWidget {
  const _TeacherSignRecordCard({
    required this.time,
    required this.headerTrailing,
    required this.courseName,
    required this.subtitle,
    required this.avatarSeed,
    this.logoUrl = '',
    required this.expected,
    required this.present,
    required this.method,
    this.signInClock = '',
    this.signStatusLabel = '',
    this.hasAttendanceCounts = false,
  });

  final String time;
  final String headerTrailing;
  final String courseName;
  final String subtitle;
  final String avatarSeed;
  final String logoUrl;
  final int expected;
  final int present;
  final String method;
  final String signInClock;
  final String signStatusLabel;
  final bool hasAttendanceCounts;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: ui(18),
                  color: _kTextSection,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const Spacer(),
              Text(
                headerTrailing,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          // 头像与课名/节次同行：头像在左，课名/节次在右。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(seed: avatarSeed, size: ui(40)),
              SizedBox(width: ui(6)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextDark,
                        fontWeight: AppFont.w600,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          if (hasAttendanceCounts)
            _SignRecordStatsPanel(
              expected: expected,
              present: present,
              method: method,
            )
          else
            _TeacherSignHistoryStatsPanel(
              signInClock: signInClock,
              signStatusLabel: signStatusLabel,
            ),
        ],
      ),
    );
  }
}

class _TeacherSignHistoryStatsPanel extends StatelessWidget {
  const _TeacherSignHistoryStatsPanel({
    required this.signInClock,
    required this.signStatusLabel,
  });

  final String signInClock;
  final String signStatusLabel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: ui(50)),
      padding: EdgeInsets.only(top: ui(11), bottom: ui(10)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _RecordStatCol(
              '签课时间',
              signInClock.isEmpty ? '--:--' : signInClock,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: _RecordStatCol(
              '签课状态',
              signStatusLabel.isEmpty ? '--' : signStatusLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignRecordStatsPanel extends StatelessWidget {
  const _SignRecordStatsPanel({
    required this.expected,
    required this.present,
    required this.method,
  });

  final int expected;
  final int present;
  final String method;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final expectedText = expected < 0 ? '' : '$expected\u4eba';
    final presentText = present < 0 ? '' : '$present\u4eba';
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: ui(50)),
      padding: EdgeInsets.only(top: ui(11), bottom: ui(10)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _RecordStatCol('应到', expectedText)),
          SizedBox(width: ui(12)),
          Expanded(child: _RecordStatCol('实到', presentText)),
          SizedBox(width: ui(12)),
          Expanded(child: _RecordStatCol('签到方式', method)),
        ],
      ),
    );
  }
}

class _RecordStatCol extends StatelessWidget {
  const _RecordStatCol(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasValue = value.trim().isNotEmpty;
    final displayValue = hasValue ? value : '--';
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(5)),
        Text(
          displayValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(12),
            color: hasValue ? _kTextDark : _kTextHint,
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 今日课程面板（左 340 宽）
// =============================================================================

class _TodayClassesPanel extends StatelessWidget {
  const _TodayClassesPanel({
    required this.title,
    required this.classes,
    required this.activeIdx,
    required this.onSelect,
    this.emptyMessage = '今日暂无课程',
  });

  final String title;
  final List<_AttendClass> classes;
  final int activeIdx;
  final ValueChanged<int> onSelect;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEmpty = classes.isEmpty;
    return Container(
      // 空态固定高度；有课时最低高度与右侧「签到操作」面板保持一致。
      width: double.infinity,
      height: isEmpty ? ui(_kSignActionPanelMinHeight) : null,
      constraints: isEmpty
          ? null
          : BoxConstraints(minHeight: ui(_kSignActionPanelMinHeight)),
      padding: EdgeInsets.all(ui(12)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        image: const DecorationImage(
          image: AssetImage(AppAssets.adminFaceLibraryEntryCardBg),
          fit: BoxFit.cover,
        ),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextSection,
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
          if (isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextHint,
                    fontWeight: AppFont.w400,
                    height: 20 / 13,
                  ),
                ),
              ),
            )
          else ...[
            SizedBox(height: ui(12)),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: ui(104) * 5 + ui(8) * 4),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < classes.length; i++) ...[
                      if (i > 0) SizedBox(height: ui(8)),
                      _TodayClassCard(
                        data: classes[i],
                        isActive: i == activeIdx,
                        onTap: () => onSelect(i),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayClassCard extends StatelessWidget {
  const _TodayClassCard({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  final _AttendClass data;
  final bool isActive;
  final VoidCallback onTap;

  DashboardCourseRunState _runState() => switch (data.runState) {
    _ClassRunState.ended => DashboardCourseRunState.ended,
    _ClassRunState.inProgress => DashboardCourseRunState.inProgress,
    _ClassRunState.upcoming => DashboardCourseRunState.upcoming,
  };

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final displayName = data.className.isNotEmpty
        ? data.className
        : data.courseName;
    // 原版 104 高课程卡。核心的 DashboardCourseNoticeCard 现在渲染组件库课程卡，
    // 这里直接用首页已移植回来的同一份原版卡片。
    return AppPressable(
      onTap: onTap,
      selected: isActive,
      child: HomeCourseNoticeCard(
        startTime: data.startTime,
        endTime: data.endTime,
        runState: _runState(),
        displayName: displayName,
        subjectName: data.courseName,
        subtitle: '${data.signStatusLabel}·${data.location}',
        isSelected: isActive,
        avatar: _Avatar(
          seed: data.cardAvatarSeed,
          size: ui(40),
          imageUrl: data.cardAvatarUrl,
        ),
      ),
    );
  }
}

// =============================================================================
// 签到操作
// =============================================================================

class _ActionPanelSwitcher extends StatelessWidget {
  const _ActionPanelSwitcher({
    required this.data,
    required this.onPickStudentStatus,
    required this.onBulkSign,
  });

  final _AttendClass data;
  final ValueChanged<int> onPickStudentStatus;
  final VoidCallback onBulkSign;

  @override
  Widget build(BuildContext context) {
    return _SignInActionShell(
      child: _ClassSignPanel(
        data: data,
        onPickStudentStatus: onPickStudentStatus,
        onBulkSign: onBulkSign,
      ),
    );
  }
}

/// 签到操作外框。
class _SignInActionShell extends StatelessWidget {
  const _SignInActionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: ui(_kSignActionPanelMinHeight)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: child,
    );
  }
}

class _SignActionEmptyPanel extends StatelessWidget {
  const _SignActionEmptyPanel({required this.loading, required this.message});

  final bool loading;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return _SignInActionShell(
      child: SizedBox(
        height: ui(_kSignActionPanelMinHeight),
        child: Center(
          child: loading
              ? const AppLoadingIndicator()
              : Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextHint,
                    fontWeight: AppFont.w400,
                    height: 20 / 13,
                  ),
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// 签课面板（614 宽 × 465 高）：班级名单 + 一键签课
// =============================================================================

class _ClassSignPanel extends StatelessWidget {
  const _ClassSignPanel({
    required this.data,
    required this.onPickStudentStatus,
    required this.onBulkSign,
  });

  final _AttendClass data;
  final ValueChanged<int> onPickStudentStatus;
  final VoidCallback onBulkSign;

  int _countOf(_AttendStatus s) =>
      data.students.where((e) => e.status == s).length;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bulkSignCompleted = _isSignCompleted(data);
    return Padding(
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：第N节·HH:MM-HH:MM（时间紫色）+ 右上角倒计时 / 已结束角标
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '第${data.periodIndex}节·${data.startTime}-${data.endTime}',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextSection,
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
              ),
              if (data.runState == _ClassRunState.ended)
                const _SignActionEndedBadge()
              else
                CourseSignCountdownBadge(
                  startTime: data.startTime,
                  endTime: data.endTime,
                ),
            ],
          ),
          SizedBox(height: ui(10)),
          // 班级信息行：头像 + 班级名（后接科目标签）+ 时长·教室
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(
                seed: data.cardAvatarSeed,
                size: ui(40),
                imageUrl: data.cardAvatarUrl,
              ),
              SizedBox(width: ui(6)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            data.className.isNotEmpty
                                ? data.className
                                : data.teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(14),
                              color: _kTextDark,
                              fontWeight: AppFont.w600,
                              height: 1,
                            ),
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        CourseSubjectTag(name: data.courseName),
                      ],
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      '${data.duration}·${data.location}',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(16)),
          // 班级学生（灰底面板）
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(16)),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '班级学生',
                        style: TextStyle(
                          fontSize: ui(16),
                          color: Colors.black,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 20 / 16,
                        ),
                      ),
                    ),
                    Text(
                      '点击头像可更改状态',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ui(8)),
                // 4 状态 chip（出勤/缺勤/迟到/请假，与后端 status 0–3 一致）
                Wrap(
                  spacing: ui(8),
                  runSpacing: ui(8),
                  children: [
                    _StatusChip(
                      label: CourseSignStatus.present.label,
                      count: _countOf(_AttendStatus.present),
                      dotColor: courseSignStatusFg(CourseSignStatus.present),
                    ),
                    _StatusChip(
                      label: CourseSignStatus.absent.label,
                      count: _countOf(_AttendStatus.absent),
                      dotColor: courseSignStatusFg(CourseSignStatus.absent),
                    ),
                    _StatusChip(
                      label: CourseSignStatus.late.label,
                      count: _countOf(_AttendStatus.late),
                      dotColor: courseSignStatusFg(CourseSignStatus.late),
                    ),
                    _StatusChip(
                      label: CourseSignStatus.leave.label,
                      count: _countOf(_AttendStatus.leave),
                      dotColor: courseSignStatusFg(CourseSignStatus.leave),
                    ),
                  ],
                ),
                SizedBox(height: ui(12)),
                // 学生网格：根据面板宽度自动分行，最多 8 列。
                _StudentAttendGrid(
                  students: data.students,
                  onTapStudent: onPickStudentStatus,
                ),
              ],
            ),
          ),
          SizedBox(height: ui(12)),
          if (!bulkSignCompleted) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(12), ui(8)),
              decoration: BoxDecoration(
                color: _kPurpleSoftHint,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderSoft, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '待完成全班签课',
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontWeight: AppFont.w500,
                      height: 20 / 13,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  Text(
                    '可先核对名单并修改状态，再点击下方完成全班签到；完成后学生端展示到课结果。',
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 12 / 11,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ui(12)),
            InkWell(
              onTap: onBulkSign,
              borderRadius: BorderRadius.circular(ui(12)),
              child: Container(
                width: double.infinity,
                height: ui(48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [AppColors.brandSoft, AppColors.brand],
                  ),
                  borderRadius: BorderRadius.circular(ui(12)),
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: ui(20),
                      color: Colors.white,
                    ),
                    SizedBox(width: ui(4)),
                    Text(
                      '一键完成全班签到',
                      style: TextStyle(
                        fontSize: ui(14),
                        color: Colors.white,
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(12), ui(8)),
              decoration: BoxDecoration(
                color: const Color(0xFFE4FFED),
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderSoft, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '已完成全班签到',
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kStatusPresent,
                      fontWeight: AppFont.w500,
                      height: 20 / 13,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  Text(
                    '当前状态：${data.signStatusLabel}。可在上方名单中查看或调整个别学生签到状态。',
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 14 / 11,
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

/// 签到操作面板右上角「已结束」状态角标（课程结束后替换倒计时）。
class _SignActionEndedBadge extends StatelessWidget {
  const _SignActionEndedBadge();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(4)),
      decoration: BoxDecoration(
        color: _kEndedTagBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        '已结束',
        style: TextStyle(
          fontSize: ui(12),
          color: _kTextSecondary,
          fontWeight: AppFont.w400,
          height: 1,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.dotColor,
  });

  final String label;
  final int count;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(24),
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(8),
            height: ui(8),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            '$count',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentAttendGrid extends StatelessWidget {
  const _StudentAttendGrid({
    required this.students,
    required this.onTapStudent,
  });

  final List<_StudentAttend> students;
  final ValueChanged<int> onTapStudent;

  static const int _maxColumns = 8;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cellWidth = ui(_StudentAttendCell.width);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / cellWidth).floor().clamp(
          1,
          _maxColumns,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var start = 0; start < students.length; start += columns) ...[
              if (start > 0) SizedBox(height: ui(12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var index = start; index < start + columns; index++)
                    if (index < students.length)
                      _StudentAttendCell(
                        student: students[index],
                        onTap: () => onTapStudent(index),
                      )
                    else
                      SizedBox(width: cellWidth),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StudentAttendCell extends StatelessWidget {
  const _StudentAttendCell({required this.student, required this.onTap});

  static const width = 60.0;

  final _StudentAttend student;
  final VoidCallback onTap;

  Color _dotColorFor(_AttendStatus s) {
    return switch (s) {
      _AttendStatus.present => courseSignStatusFg(CourseSignStatus.present),
      _AttendStatus.absent => courseSignStatusFg(CourseSignStatus.absent),
      _AttendStatus.late => courseSignStatusFg(CourseSignStatus.late),
      _AttendStatus.leave => courseSignStatusFg(CourseSignStatus.leave),
      _AttendStatus.missing => _kTextHint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(20)),
      child: SizedBox(
        width: ui(width),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _Avatar(
                  seed: student.name,
                  size: ui(36),
                  imageUrl: student.headUrl,
                ),
                Positioned(
                  right: ui(-1),
                  bottom: ui(-1),
                  child: Container(
                    width: ui(8),
                    height: ui(8),
                    decoration: BoxDecoration(
                      color: _dotColorFor(student.status),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ui(4)),
            Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontWeight: AppFont.w400,
                height: 20 / 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 简易头像（颜色 hash + 首字母占位，避免 Figma `placehold.co` 出网图）
// =============================================================================

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed, required this.size, this.imageUrl = ''});

  final String seed;
  final double size;
  final String imageUrl;

  /// 原版占位：紫色实底圆 + 白色首字。
  Widget _fallback(String initial) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.brandSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = seed.isEmpty ? '?' : seed.characters.first.toUpperCase();
    final resolved = imageUrl.trim().isEmpty
        ? ''
        : MediaUrl.resolve(imageUrl.trim());
    if (resolved.isEmpty) return _fallback(initial);
    final placeholder = _fallback(initial);
    return ClipOval(
      child: AppImage(
        src: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: placeholder,
        error: placeholder,
      ),
    );
  }
}

// =============================================================================
// 初始 demo 数据
// =============================================================================

_AttendClass _attendClassFromSession(CourseSignSession session) {
  final rangeParts = session.timeRange.split(RegExp(r'\s*-\s*'));
  final startRaw = session.courseStartTime.isNotEmpty
      ? session.courseStartTime
      : (rangeParts.isNotEmpty ? rangeParts.first : '');
  final endRaw = session.courseEndTime.isNotEmpty
      ? session.courseEndTime
      : (rangeParts.length > 1 ? rangeParts.last : '');
  final start = _displayCourseClock(startRaw);
  final end = _displayCourseClock(endRaw);
  final runState = _runStateFromCourseTimes(startRaw, endRaw, start, end);
  final startMinutes = _minutesOf(start);
  final endMinutes = _minutesOf(end);
  final students = session.students
      .map(
        (student) => _StudentAttend(
          studentId: student.studentId,
          name: student.name,
          studentNo: student.studentNo,
          headUrl: student.headUrl,
          status: switch (student.status) {
            CourseSignStatus.present => _AttendStatus.present,
            CourseSignStatus.late => _AttendStatus.late,
            CourseSignStatus.leave => _AttendStatus.leave,
            CourseSignStatus.absent => _AttendStatus.absent,
            null => _AttendStatus.missing,
          },
          remark: student.remark,
        ),
      )
      .toList();
  return _AttendClass(
    courseId: session.courseId,
    periodIndex: session.lineNum > 0 ? session.lineNum : 1,
    startTime: start,
    endTime: end,
    teacherName: session.teacherName,
    courseName: session.courseName,
    duration: _durationLabel(startMinutes, endMinutes),
    location: session.classroom,
    runState: runState,
    signStatus: session.signStatus,
    signStatusLabel: CourseSignFlowStatus.labelFor(session.signStatus),
    teacherCheckInTime: session.teacherCheckInTime,
    logoUrl: session.logoUrl,
    teacherHeadUrl: session.teacherHeadUrl,
    colorHex: session.colorHex,
    className: session.className,
    students: students,
  );
}

_ClassRunState _runStateFromCourseTimes(
  String startRaw,
  String endRaw,
  String startClock,
  String endClock,
) {
  final now = DateTime.now();
  final startDt = parseCourseDateTime(startRaw);
  final endDt = parseCourseDateTime(endRaw);
  if (startDt != null && endDt != null) {
    if (now.isBefore(startDt)) return _ClassRunState.upcoming;
    if (now.isAfter(endDt)) return _ClassRunState.ended;
    return _ClassRunState.inProgress;
  }
  if (startDt != null) {
    if (now.isBefore(startDt)) return _ClassRunState.upcoming;
    return _ClassRunState.inProgress;
  }

  final startMinutes = _minutesOf(startClock);
  final endMinutes = _minutesOf(endClock);
  if (startMinutes == null) return _ClassRunState.upcoming;
  final nowMinutes = now.hour * 60 + now.minute;
  if (endMinutes != null) {
    if (nowMinutes > endMinutes) return _ClassRunState.ended;
    if (nowMinutes >= startMinutes) return _ClassRunState.inProgress;
    return _ClassRunState.upcoming;
  }
  if (nowMinutes >= startMinutes) return _ClassRunState.inProgress;
  return _ClassRunState.upcoming;
}

CourseSignStatus? _courseSignStatusOf(_AttendStatus status) {
  return switch (status) {
    _AttendStatus.present => CourseSignStatus.present,
    _AttendStatus.late => CourseSignStatus.late,
    _AttendStatus.leave => CourseSignStatus.leave,
    _AttendStatus.absent => CourseSignStatus.absent,
    _AttendStatus.missing => null,
  };
}

bool _isSignCompleted(_AttendClass data) {
  if (data.signStatus >= CourseSignFlowStatus.signed.code) {
    return true;
  }
  if (data.students.isNotEmpty &&
      data.students.every(
        (student) => student.status != _AttendStatus.missing,
      )) {
    return true;
  }
  return false;
}

String _displayCourseClock(String raw) =>
    pickCourseClock(raw) ?? _clockPart(raw);

String _clockPart(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '--:--';
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(trimmed);
  if (match == null) return '--:--';
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

int? _minutesOf(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return hour * 60 + minute;
}

String _durationLabel(int? start, int? end) {
  if (start == null || end == null || end <= start) return '课表课程';
  return '${end - start}分钟';
}

// =============================================================================
// 历史记录 子页面
//   - 顶部 banner（白→#F9EDFF 渐变 16 圆角，左 32 返回 + 居中 "历史记录"）
//   - 控制条（44 高）：左侧「共 N 条」，右侧 324×44 白底搜索框
//     （占位 "课程、班级、节次"）
//   - 多个日期 section：日期 16/500 + 一行最多 3 张 312 宽签课卡
//     （时间 + 节次 / 课名 + 班级 / 头像 / 灰底应到-实到-签到方式）
// =============================================================================

class _HistoryRecord {
  const _HistoryRecord({
    required this.time,
    required this.periodLabel,
    required this.courseName,
    required this.subtitle,
    required this.logoUrl,
    required this.avatarSeed,
    required this.className,
    required this.expected,
    required this.present,
    required this.method,
    required this.signInClock,
    required this.signStatusLabel,
    required this.hasAttendanceCounts,
  });

  final String time;
  final String periodLabel;
  final String courseName;
  final String subtitle;
  final String logoUrl;
  final String avatarSeed;
  final String className;
  final int expected;
  final int present;
  final String method;
  final String signInClock;
  final String signStatusLabel;
  final bool hasAttendanceCounts;
}

class _HistoryDay {
  const _HistoryDay({required this.date, required this.records});
  final String date;
  final List<_HistoryRecord> records;
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({
    required this.onBack,
    required this.query,
    required this.onQueryChanged,
    required this.records,
    required this.loading,
    required this.error,
  });

  final VoidCallback onBack;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<TeacherSignHistoryItem> records;
  final bool loading;
  final String error;

  bool _matchQuery(_HistoryRecord r) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    return r.courseName.toLowerCase().contains(q) ||
        r.periodLabel.toLowerCase().contains(q) ||
        r.className.toLowerCase().contains(q) ||
        r.subtitle.toLowerCase().contains(q) ||
        r.signStatusLabel.toLowerCase().contains(q) ||
        r.method.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final filteredDays = <_HistoryDay>[];
    var totalCount = 0;
    for (final day in _historyDaysFromRecords(records)) {
      final keep = day.records.where(_matchQuery).toList();
      if (keep.isNotEmpty) {
        filteredDays.add(_HistoryDay(date: day.date, records: keep));
        totalCount += keep.length;
      }
    }
    return SmartCampusSecondaryPageShell(
      header: SmartCampusPageBanner(title: '历史记录', onBack: onBack),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistoryFilterRow(
            total: totalCount,
            query: query,
            onQueryChanged: onQueryChanged,
          ),
          SizedBox(height: ui(12)),
          if (loading && filteredDays.isEmpty)
            const SizedBox.shrink()
          else if (error.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: ui(_kHistoryListMinHeight),
              ),
              child: _AttendanceEmptyPanel(
                loading: false,
                message: error,
                expand: true,
              ),
            )
          else if (filteredDays.isEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: ui(_kHistoryListMinHeight),
              ),
              child: _HistoryEmptyState(query: query),
            )
          else
            for (var i = 0; i < filteredDays.length; i++) ...[
              if (i > 0) SizedBox(height: ui(16)),
              _HistoryDaySection(day: filteredDays[i]),
            ],
        ],
      ),
    );
  }
}

List<_HistoryDay> _historyDaysFromRecords(
  List<TeacherSignHistoryItem> records,
) {
  final grouped = <String, List<_HistoryRecord>>{};
  for (final item in records) {
    final date = _dateOnly(item.date);
    grouped
        .putIfAbsent(date.isEmpty ? '日期未知' : date, () => [])
        .add(
          _HistoryRecord(
            time: item.time.isEmpty ? '--:--' : item.time,
            periodLabel: item.lineNum > 0 ? '第${item.lineNum}节' : '签课记录',
            courseName: item.courseName,
            subtitle: item.subtitle,
            logoUrl: item.logoUrl,
            avatarSeed: item.avatarSeed,
            className: item.className,
            expected: item.shouldCount,
            present: item.presentCount,
            method: item.method,
            signInClock: item.signInClock,
            signStatusLabel: item.signStatusLabel,
            hasAttendanceCounts: item.hasAttendanceCounts,
          ),
        );
  }
  return [
    for (final entry in grouped.entries)
      _HistoryDay(date: entry.key, records: entry.value),
  ];
}

String _dateOnly(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 10) return trimmed.substring(0, 10);
  return trimmed;
}

class _HistoryFilterRow extends StatelessWidget {
  const _HistoryFilterRow({
    required this.total,
    required this.query,
    required this.onQueryChanged,
  });

  final int total;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    // 左边是条数，右边是 324×44 搜索框。
    return Row(
      children: [
        Expanded(child: _HistorySummaryBar(total: total)),
        _HistorySearchField(initialText: query, onChanged: onQueryChanged),
      ],
    );
  }
}

class _HistorySummaryBar extends StatelessWidget {
  const _HistorySummaryBar({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: ui(12), fontWeight: AppFont.w400, height: 1),
        children: [
          const TextSpan(
            text: '共 ',
            style: TextStyle(color: _kTextHint),
          ),
          TextSpan(
            text: '$total',
            style: const TextStyle(color: _kTextDark),
          ),
          const TextSpan(
            text: ' 条',
            style: TextStyle(color: _kTextHint),
          ),
        ],
      ),
    );
  }
}

class _HistorySearchField extends StatefulWidget {
  const _HistorySearchField({
    required this.initialText,
    required this.onChanged,
  });

  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<_HistorySearchField> createState() => _HistorySearchFieldState();
}

class _HistorySearchFieldState extends State<_HistorySearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SmartCampusFilterSearchField(
      controller: _controller,
      hintText: '课程、班级、节次',
      onChanged: widget.onChanged,
    );
  }
}

class _HistoryDaySection extends StatelessWidget {
  const _HistoryDaySection({required this.day});

  final _HistoryDay day;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          day.date,
          style: TextStyle(
            fontSize: ui(16),
            color: _kTextSection,
            fontWeight: AppFont.w500,
            height: 1,
          ),
        ),
        SizedBox(height: ui(12)),
        Wrap(
          spacing: ui(16),
          runSpacing: ui(16),
          children: [
            for (final r in day.records)
              SizedBox(
                width: ui(312),
                child: _HistoryRecordCard(record: r),
              ),
          ],
        ),
      ],
    );
  }
}

class _HistoryRecordCard extends StatelessWidget {
  const _HistoryRecordCard({required this.record});

  final _HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    return _TeacherSignRecordCard(
      time: record.time,
      headerTrailing: record.periodLabel,
      courseName: record.courseName,
      subtitle: record.subtitle,
      avatarSeed: record.avatarSeed,
      logoUrl: record.logoUrl,
      expected: record.expected,
      present: record.present,
      method: record.method,
      signInClock: record.signInClock,
      signStatusLabel: record.signStatusLabel,
      hasAttendanceCounts: record.hasAttendanceCounts,
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasQuery = query.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: ui(40), color: _kTextHint),
          SizedBox(height: ui(12)),
          Text(
            hasQuery ? '没有符合条件的签课记录' : '暂无历史签课记录',
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
