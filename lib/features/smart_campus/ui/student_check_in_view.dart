// =============================================================================
// 学生端「课堂考勤」独立页面
//
// 入口：学生 dashboard 快捷区「课堂考勤」按钮 → controller.openCheckIn()
//      → mainView == checkIn + role == student → SmartCampusPage 路由到本视图。
// 返回：顶部 banner 左上角返回按钮 → onBack。
//
// 上课由任课老师签课，学生不用自己签到；这一页只读，用来看自己的到课情况。
//   1. 顶部 banner：返回 + 标题「课堂考勤」+ 右侧「历史记录」按钮。
//   2. 统计卡（一行平铺）：应到课次 / 正常 / 迟到 / 请假 / 缺勤 / 出勤率。
//   3. 双列：左 340「今日课程」（复用首页课程卡，点选一节课），右侧「到课
//      情况」（这节课的时间、老师、教室，以及老师签课后本人的考勤结果）。
//   4. 「最近课堂记录」白卡网格（一行 3 张）：日期 + 考勤结果 + 课程 + 签课
//      时间与方式 + 备注。
//   5. 「历史记录」右侧抽屉：按时间范围、日期、结果筛选；另一页是补签申请。
//
// 颜色：白卡 / #F5F6FA 浅灰 / #715EFE 主紫 / 缺勤红 / 出勤绿 / 提示灰
// 字体：PingFang SC（标题 16~18 / 正文 12~14）+ Barlow（日期 / 时间）
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/course_subject_tag.dart';
import '../../../core/widgets/dashboard_course_notice_card.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/student_check_in_data.dart';
import '../state/student_check_in_controller.dart';
import '../state/student_check_in_state.dart';
import 'course_sign_countdown.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

const Color _kCardBg = AppColors.surface;
const Color _kInnerGray = AppColors.surfaceSubtle;
const Color _kBorderSoft = AppColors.lineSoft;
const Color _kTextDark = AppColors.ink;
const Color _kTextSection = AppColors.ink;
const Color _kTextSecondary = AppColors.textSecondary;
const Color _kTextHint = AppColors.textPlaceholder;
const Color _kTextDivider = AppColors.textTertiary;
const Color _kPurple = AppColors.brand;
const Color _kPurpleSoftBg = AppColors.brandTint;
const Color _kStatusGreen = AppColors.success;
const Color _kAttendRed = AppColors.danger;

/// 学生端是否展示「申请补签」入口（缺勤记录卡片右下角按钮）。
const bool _kStudentMakeupSignEnabled = false;

class StudentCheckInView extends ConsumerStatefulWidget {
  const StudentCheckInView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StudentCheckInView> createState() => _StudentCheckInViewState();
}

class _StudentCheckInViewState extends ConsumerState<StudentCheckInView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(studentCheckInControllerProvider.notifier);
      await notifier.initialize();
      notifier.startLiveSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(studentCheckInControllerProvider.notifier).resumeSync(),
      );
    }
  }

  Future<void> _applyMakeup(StudentSignRecordItem record) async {
    if (record.courseId.isEmpty) {
      AppToast.show(context, '缺少课程信息，无法申请补签', type: AppToastType.error);
      return;
    }
    final reason = await showScaledDialog<String>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.18),
      builder: (ctx) => _MakeupReasonDialog(courseName: record.subjectName),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    final response = await ref
        .read(studentCheckInControllerProvider.notifier)
        .submitMakeup(courseId: record.courseId, reason: reason.trim());
    if (!mounted) return;
    AppToast.show(
      context,
      response.isSuccess
          ? '补签申请已提交'
          : (response.displayMsg.isNotEmpty ? response.displayMsg : '补签申请失败'),
      type: response.isSuccess ? AppToastType.success : AppToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final checkIn = ref.watch(studentCheckInControllerProvider);
    final selected = checkIn.selectedCourse;
    final recentRecords = checkIn.recentRecords
        .map(_recentRecordFromItem)
        .toList(growable: false);

    return SmartCampusSecondaryPageShell(
      bodyTopClipRadius: 8,
      bodyScrollable: false,
      header: SmartCampusPageBanner(
        titleHorizontalInset: 128,
        title: '课堂考勤',
        subtitle: '上课由任课老师签课，在这里查看自己的到课情况',
        onBack: widget.onBack,
        actions: [
          AppButton(
            label: '历史记录',
            icon: Icons.history_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: _openHistoryDrawer,
          ),
        ],
      ),
      body: PageInitLoadingShell(
        loading: checkIn.loading,
        child: SingleChildScrollView(
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatsRow(stats: _statsFromSummary(checkIn.stats)),
              SizedBox(height: ui(12)),
              // 双列：今日课程 + 到课情况
              LayoutBuilder(
                builder: (context, c) {
                  final isCompact = c.maxWidth < ui(720);
                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('今日课程'),
                        SizedBox(height: ui(12)),
                        _TodayClassesPanel(
                          title: checkIn.todayTitle,
                          courses: checkIn.todayCourses,
                          selectedCourseId: checkIn.selectedCourseId,
                          onSelect: (course) => ref
                              .read(studentCheckInControllerProvider.notifier)
                              .selectCourse(course.courseId),
                        ),
                        SizedBox(height: ui(16)),
                        _SectionTitle('到课情况'),
                        SizedBox(height: ui(12)),
                        _AttendancePanel(course: selected),
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
                              title: checkIn.todayTitle,
                              courses: checkIn.todayCourses,
                              selectedCourseId: checkIn.selectedCourseId,
                              onSelect: (course) => ref
                                  .read(
                                    studentCheckInControllerProvider.notifier,
                                  )
                                  .selectCourse(course.courseId),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: ui(16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle('到课情况'),
                            SizedBox(height: ui(12)),
                            _AttendancePanel(course: selected),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: ui(16)),
              const _SectionTitle('最近课堂记录'),
              SizedBox(height: ui(12)),
              if (recentRecords.isEmpty)
                AppCard(
                  child: checkIn.error.isNotEmpty
                      ? AppErrorState(
                          title: '课堂记录加载失败',
                          description: checkIn.error,
                        )
                      : const AppEmptyState(
                          icon: Icons.event_note_outlined,
                          title: '暂无最近课堂记录',
                          description: '上完课后到课情况会出现在这里',
                        ),
                )
              else
                _RecentRecordsGrid(
                  records: recentRecords,
                  onApplyMakeup: _kStudentMakeupSignEnabled
                      ? (record) {
                          StudentSignRecordItem? item;
                          for (final r in checkIn.recentRecords) {
                            if (r.courseId == record.courseId) {
                              item = r;
                              break;
                            }
                          }
                          if (item == null) {
                            AppToast.show(
                              context,
                              '缺少课程信息，无法申请补签',
                              type: AppToastType.error,
                            );
                            return;
                          }
                          unawaited(_applyMakeup(item));
                        }
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHistoryDrawer() async {
    ref.read(studentCheckInControllerProvider.notifier).stopLiveSync();
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    await Future.wait([
      ref
          .read(studentCheckInControllerProvider.notifier)
          .loadHistory(range: StudentCheckInHistoryRange.month),
      ref.read(studentCheckInControllerProvider.notifier).loadMakeupList(),
    ]);
    if (!mounted) return;
    await showGeneralDialog<void>(
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
              child: _CheckInHistoryDrawer(
                onClose: () => Navigator.of(ctx).maybePop(),
                onApplyMakeup: _applyMakeup,
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
    if (mounted) {
      ref.read(studentCheckInControllerProvider.notifier).startLiveSync();
    }
  }
}

// =============================================================================
// 顶部 banner
// =============================================================================

// =============================================================================
// 5 项统计卡
// =============================================================================

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
    return AppCard(
      radius: 12,
      bordered: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      child: Column(
        children: [
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: smartCampusStatValueTextStyle(ui, color: item.valueColor),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.caption12.copyWith(
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 今日课程面板（左侧 340 宽）
// =============================================================================

class _TodayClassesPanel extends StatelessWidget {
  const _TodayClassesPanel({
    required this.title,
    required this.courses,
    required this.selectedCourseId,
    required this.onSelect,
  });

  final String title;
  final List<StudentTodayCourse> courses;
  final String? selectedCourseId;
  final ValueChanged<StudentTodayCourse> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEmpty = courses.isEmpty;
    return Container(
      // 空态固定高度；有课时最低高度与右侧"到课情况"面板（274）保持一致。
      height: isEmpty ? ui(274) : null,
      constraints: isEmpty ? null : BoxConstraints(minHeight: ui(274)),
      padding: EdgeInsets.all(ui(12)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            const Expanded(
              child: Center(
                child: AppEmptyState(
                  icon: Icons.event_available_outlined,
                  title: '今天没有课',
                  description: '有课的日子会在这里显示到课情况',
                ),
              ),
            )
          else ...[
            SizedBox(height: ui(12)),
            for (var i = 0; i < courses.length; i++) ...[
              if (i > 0) SizedBox(height: ui(8)),
              _TodayClassCard(
                course: courses[i],
                selected: courses[i].courseId == selectedCourseId,
                onTap: () => onSelect(courses[i]),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TodayClassCard extends StatelessWidget {
  const _TodayClassCard({
    required this.course,
    required this.selected,
    required this.onTap,
  });

  final StudentTodayCourse course;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final runState = switch (course.phase) {
      StudentCourseSlotPhase.ended => DashboardCourseRunState.ended,
      StudentCourseSlotPhase.inProgress => DashboardCourseRunState.inProgress,
      StudentCourseSlotPhase.upcoming => DashboardCourseRunState.upcoming,
    };
    return DashboardCourseNoticeCard(
      startTime: course.timeStart,
      endTime: course.timeEnd,
      subjectName: course.subjectName,
      displayName: course.teacherName,
      subtitle: '${course.durationLabel} · ${course.location}',
      avatar: AppAvatar(
        name: course.teacherName,
        url: course.teacherHeadUrl,
        size: AppCourseCard.avatarSize,
      ),
      runState: runState,
      isSelected: selected,
      onTap: onTap,
    );
  }
}

// =============================================================================
// 到课情况面板：选中的那节课，以及老师签课后本人的考勤结果
// =============================================================================

class _AttendancePanel extends StatelessWidget {
  const _AttendancePanel({required this.course});

  final StudentTodayCourse? course;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final data = course;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: ui(274)),
      padding: EdgeInsets.all(ui(12)),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
      ),
      child: data == null
          ? SizedBox(
              height: ui(250),
              child: Center(
                child: Text(
                  '选择左侧的一节课，查看到课情况',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextHint,
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: ui(16),
                            fontWeight: AppFont.w500,
                            height: 1.2,
                          ),
                          children: [
                            TextSpan(
                              text: '${data.periodLabel}·',
                              style: const TextStyle(color: _kTextSection),
                            ),
                            TextSpan(
                              text: data.timeRange,
                              style: const TextStyle(color: _kPurple),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CourseSignCountdownBadge(
                      startTime: data.timeStart,
                      endTime: data.timeEnd,
                    ),
                  ],
                ),
                SizedBox(height: ui(12)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(ui(12)),
                  decoration: BoxDecoration(
                    color: _kInnerGray,
                    borderRadius: BorderRadius.circular(ui(12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _Avatar(
                            seed: data.teacherName,
                            size: ui(40),
                            imageUrl: data.teacherHeadUrl,
                          ),
                          SizedBox(width: ui(10)),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        data.teacherName,
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
                                    CourseSubjectTag(name: data.subjectName),
                                  ],
                                ),
                                SizedBox(height: ui(4)),
                                Text(
                                  '${data.durationLabel}·${data.location}',
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
                      _AttendResult(course: data),
                    ],
                  ),
                ),
                SizedBox(height: ui(12)),
                Text(
                  '上课由任课老师签课，不用自己签到。记录有出入可以找班主任核对。',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontWeight: AppFont.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }
}

/// 一节课的考勤结果：老师签课前说明现在的阶段，签课后显示本人的结果。
class _AttendResult extends StatelessWidget {
  const _AttendResult({required this.course});

  final StudentTodayCourse course;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final status = course.attendStatus;
    final String title;
    final String detail;
    final AppTone tone;
    if (status != null) {
      title = studentAttendStatusLabel(status);
      tone = _attendTone(status);
      final clock = pickCourseClock(course.signInTime);
      detail = [
        if (clock != null) '签课时间 $clock',
        if (course.remark.isNotEmpty) course.remark,
      ].join(' · ');
    } else {
      tone = AppTone.neutral;
      (title, detail) = switch (course.phase) {
        StudentCourseSlotPhase.upcoming => ('还没上课', '上课后由任课老师签课'),
        StudentCourseSlotPhase.inProgress => ('上课中', '任课老师签课后，这里显示到课情况'),
        StudentCourseSlotPhase.ended => ('等待签课', '任课老师还没有签课'),
      };
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Text(
            '到课情况',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(width: ui(8)),
          AppTag(label: title, tone: tone),
          SizedBox(width: ui(8)),
          Expanded(
            child: Text(
              detail.isEmpty ? '任课老师已签课' : detail,
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
      ),
    );
  }
}

/// 考勤结果的标签色：正常绿、迟到琥珀、请假紫、缺勤红。
AppTone _attendTone(int status) => switch (status) {
  1 => AppTone.danger,
  2 => AppTone.warning,
  3 => AppTone.brand,
  _ => AppTone.success,
};

// =============================================================================
// 最近课堂记录卡（312 宽，3 列网格）
// =============================================================================

class _RecentRecordData {
  const _RecentRecordData({
    this.courseId = '',
    required this.date,
    required this.status,
    required this.studentName,
    required this.teacherName,
    required this.duration,
    required this.location,
    required this.timeStart,
    required this.timeEnd,
    required this.startCard,
    required this.method,
    required this.note,
    this.avatarUrl = '',
    this.className = '',
    this.lineNum = 0,
  });

  final String courseId;
  final String date;

  /// 考勤结果：0 正常 / 1 缺勤 / 2 迟到 / 3 请假。
  final int status;
  final String studentName;
  final String teacherName;
  final String duration;
  final String location;
  final String timeStart;
  final String timeEnd;

  /// 老师登记到课的时间。null = "-"
  final String? startCard;

  /// 签到方式（"老师签课" / "刷脸签到"）
  final String? method;

  /// 备注（不带前缀；展示时补 "备注：" 前缀）
  final String note;

  /// 任课老师头像（相对/绝对地址，空则回退首字母）。
  final String avatarUrl;

  /// 所属班级名。
  final String className;

  /// 节次序号。
  final int lineNum;

  bool get isAbsent => status == 1;

  /// 副信息行：班级 · 第N节 · 教室（缺项自动省略）。
  String get metaLine {
    final parts = <String>[
      if (className.isNotEmpty) className,
      if (lineNum > 0) '第$lineNum节',
      if (location.isNotEmpty && location != '—') location,
    ];
    return parts.join(' · ');
  }
}

class _RecentRecordsGrid extends StatelessWidget {
  const _RecentRecordsGrid({required this.records, this.onApplyMakeup});

  final List<_RecentRecordData> records;
  final ValueChanged<_RecentRecordData>? onApplyMakeup;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Wrap(
      spacing: ui(16),
      runSpacing: ui(16),
      children: [
        for (final r in records)
          SizedBox(
            width: ui(312),
            child: _RecentRecordCard(
              data: r,
              onApplyMakeup: onApplyMakeup == null
                  ? null
                  : () => onApplyMakeup!(r),
            ),
          ),
      ],
    );
  }
}

class _RecentRecordCard extends StatelessWidget {
  const _RecentRecordCard({required this.data, this.onApplyMakeup});

  final _RecentRecordData data;
  final VoidCallback? onApplyMakeup;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isAbsent = data.isAbsent;
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
          // 日期 + 状态
          Row(
            children: [
              Expanded(
                child: Text(
                  data.date,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextSection,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
              AppTag(
                label: studentAttendStatusLabel(data.status),
                tone: _attendTone(data.status),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          // 头像 + 科目
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                seed: data.studentName,
                size: ui(40),
                imageUrl: data.avatarUrl,
              ),
              SizedBox(width: ui(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.studentName,
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
                      data.metaLine,
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
          // 状态行：缺勤时占位"这节课没有到"，其他显示签课时间与方式
          if (isAbsent)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: ui(16)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kInnerGray,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Text(
                '这节课没有到',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            )
          else
            _AttendStatsRow(startCard: data.startCard, method: data.method),
          SizedBox(height: ui(8)),
          Text(
            '备注：${data.note}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          // 缺勤：右下角"申请补签"按钮（课表日期图标 + 按钮风格）
          if (isAbsent && onApplyMakeup != null) ...[
            SizedBox(height: ui(10)),
            Align(
              alignment: Alignment.centerRight,
              child: _MakeupApplyButton(onTap: onApplyMakeup),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryDrawerRecordCard extends StatelessWidget {
  const _HistoryDrawerRecordCard({required this.data, this.onApplyMakeup});

  final _RecentRecordData data;
  final VoidCallback? onApplyMakeup;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isAbsent = data.isAbsent;
    final tone = _attendTone(data.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardCourseNoticeCard(
          startTime: data.timeStart.isNotEmpty ? data.timeStart : '--:--',
          endTime: data.timeEnd.isNotEmpty ? data.timeEnd : '--:--',
          subjectName: data.studentName,
          displayName: data.teacherName,
          subtitle: '${data.duration} · ${data.location}',
          avatar: AppAvatar(
            name: data.teacherName,
            url: data.avatarUrl,
            size: AppCourseCard.avatarSize,
          ),
          runState: DashboardCourseRunState.ended,
          statusBadgeLabel: studentAttendStatusLabel(data.status),
          statusBadgeBackground: tone.background,
          statusBadgeTextColor: tone.foreground,
        ),
        if (isAbsent && onApplyMakeup != null) ...[
          SizedBox(height: ui(8)),
          Align(
            alignment: Alignment.centerRight,
            child: _MakeupApplyButton(onTap: onApplyMakeup),
          ),
        ],
      ],
    );
  }
}

class _MakeupApplyButton extends StatelessWidget {
  const _MakeupApplyButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.scheduleEditCourseTime,
              width: ui(14),
              height: ui(14),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(6)),
            Text(
              '申请补签',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
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

class _AttendStatsRow extends StatelessWidget {
  const _AttendStatsRow({required this.startCard, required this.method});

  final String? startCard;
  final String? method;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(11)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(label: '签课时间', value: startCard ?? '-'),
          ),
          Expanded(
            child: _StatColumn(label: '签到方式', value: method ?? '-'),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(5)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 通用：tag、头像、段标题
// =============================================================================

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed, required this.size, this.imageUrl});

  final String seed;
  final double size;

  /// 头像图片地址（相对/绝对），为空或加载失败时回退首字母。
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = (imageUrl == null || imageUrl!.trim().isEmpty)
        ? ''
        : MediaUrl.resolve(imageUrl!);
    if (resolved.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          resolved,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final firstChar = seed.isNotEmpty ? seed.characters.first : '?';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.brandSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        firstChar,
        style: TextStyle(
          fontSize: size * 0.4,
          color: AppColors.surface,
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      title,
      style: TextStyle(
        fontSize: ui(16),
        color: _kTextSection,
        fontWeight: AppFont.w500,
        height: 1,
      ),
    );
  }
}

// =============================================================================
// 「签到历史」右侧抽屉
//
// 入口：顶部 banner 右上「历史记录」按钮 → _openHistoryDrawer →
//      showGeneralDialog 右滑入场 → 本抽屉。
//
// 视觉：
//   - 宽 520，全高，白底，左上 16px 圆角（视觉上 align right 时左边露出）
//   - 顶部 62 高 _HistoryDrawerHeader（3×15 紫竖条 + 标题 + 关闭 X）
//   - 筛选区：
//       · 时间范围 pill 组：本周 / 本月 / 本学期（选中态 = 紫底白字）
//       · 日期筛选：日历 picker（选中后按单日调历史接口；可清除恢复范围）
//       · 状态 tabs：全部 / 正常 / 缺勤（选中态 = 白底加粗 + 紫色文字）
//   - 汇总条：「共 N 条 · 正常 m · 缺勤 k」，缺勤用红色突出
//   - 列表区：垂直列出 [_HistoryDrawerRecordCard]（复用首页课程卡 104 高样式），间距 12
//   - 空态：居中"暂无签到记录"灰字
// =============================================================================

enum _HistoryDrawerTab { signHistory, makeup }

enum _HistoryTimeRange { week, month, semester }

_HistoryTimeRange _historyRangeOf(StudentCheckInHistoryRange range) {
  return switch (range) {
    StudentCheckInHistoryRange.week => _HistoryTimeRange.week,
    StudentCheckInHistoryRange.month => _HistoryTimeRange.month,
    StudentCheckInHistoryRange.semester => _HistoryTimeRange.semester,
  };
}

StudentCheckInHistoryRange _apiRangeOf(_HistoryTimeRange range) {
  return switch (range) {
    _HistoryTimeRange.week => StudentCheckInHistoryRange.week,
    _HistoryTimeRange.month => StudentCheckInHistoryRange.month,
    _HistoryTimeRange.semester => StudentCheckInHistoryRange.semester,
  };
}

enum _HistoryStatusFilter { all, normal, absent }

enum _MakeupStatusFilter { all, pending, approved, rejected }

const double _kHistoryFilterControlHeight = 38;

class _CheckInHistoryDrawer extends ConsumerStatefulWidget {
  const _CheckInHistoryDrawer({
    required this.onClose,
    required this.onApplyMakeup,
  });

  final VoidCallback onClose;
  final Future<void> Function(StudentSignRecordItem record) onApplyMakeup;

  @override
  ConsumerState<_CheckInHistoryDrawer> createState() =>
      _CheckInHistoryDrawerState();
}

class _CheckInHistoryDrawerState extends ConsumerState<_CheckInHistoryDrawer> {
  _HistoryDrawerTab _tab = _HistoryDrawerTab.signHistory;
  StudentCheckInHistoryRange _range = StudentCheckInHistoryRange.month;
  String? _selectedDate;
  _HistoryStatusFilter _status = _HistoryStatusFilter.all;
  _MakeupStatusFilter _makeupStatus = _MakeupStatusFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadSignHistory());
  }

  int? get _apiStatusFilter => switch (_status) {
    _HistoryStatusFilter.all => null,
    _HistoryStatusFilter.normal => 0,
    _HistoryStatusFilter.absent => 1,
  };

  int? get _apiMakeupStatusFilter => switch (_makeupStatus) {
    _MakeupStatusFilter.all => null,
    _MakeupStatusFilter.pending => 0,
    _MakeupStatusFilter.approved => 1,
    _MakeupStatusFilter.rejected => 2,
  };

  Future<void> _reloadSignHistory() {
    return ref
        .read(studentCheckInControllerProvider.notifier)
        .loadHistory(
          range: _range,
          status: _apiStatusFilter,
          date: _selectedDate,
        );
  }

  List<({StudentSignRecordItem item, _RecentRecordData card})>
  _filteredHistoryEntries(StudentCheckInState checkIn) {
    final headById = _teacherHeadById(checkIn);
    final entries = <({StudentSignRecordItem item, _RecentRecordData card})>[];
    for (final item in checkIn.historyRecords) {
      entries.add((
        item: item,
        card: _recentRecordFromItem(
          item,
          headFallback: headById[item.teacherId] ?? '',
        ),
      ));
    }
    return entries;
  }

  Future<void> _reloadMakeupList() {
    return ref
        .read(studentCheckInControllerProvider.notifier)
        .loadMakeupList(status: _apiMakeupStatusFilter);
  }

  Future<void> _showMakeupDetail(StudentCourseSignMakeupItem item) async {
    final fields = await ref
        .read(studentCheckInControllerProvider.notifier)
        .loadMakeupDetail(item.id);
    if (!mounted) return;
    await _showCourseSignMakeupDetailDialog(
      context,
      title: '补签申请详情',
      fields: fields,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final checkIn = ref.watch(studentCheckInControllerProvider);
    final filteredEntries = _filteredHistoryEntries(checkIn);
    final filtered = filteredEntries.map((e) => e.card).toList(growable: false);
    final absentCount = filtered.where((r) => r.isAbsent).length;
    final normalCount = filtered.length - absentCount;
    final emptyMessage = checkIn.historyError.isNotEmpty
        ? checkIn.historyError
        : '暂无考勤记录';
    final makeupItems = checkIn.makeupRecords;
    return Container(
      width: ui(520),
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui(16)),
          bottomLeft: Radius.circular(ui(16)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HistoryDrawerHeader(
            onClose: widget.onClose,
            tab: _tab,
            onTabChanged: (tab) {
              setState(() => _tab = tab);
              if (tab == _HistoryDrawerTab.makeup) {
                unawaited(_reloadMakeupList());
              }
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _tab == _HistoryDrawerTab.signHistory ? 0 : 1,
              sizing: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HistoryFilterBar(
                      range: _historyRangeOf(_range),
                      selectedDate: _selectedDate,
                      status: _status,
                      onRangeChanged: (r) {
                        setState(() {
                          _range = _apiRangeOf(r);
                          _selectedDate = null;
                        });
                        unawaited(_reloadSignHistory());
                      },
                      onDateChanged: (date) {
                        setState(() => _selectedDate = date);
                        unawaited(_reloadSignHistory());
                      },
                      onStatusChanged: (s) {
                        setState(() => _status = s);
                        unawaited(_reloadSignHistory());
                      },
                    ),
                    _HistorySummaryBar(
                      total: filtered.length,
                      normal: normalCount,
                      absent: absentCount,
                    ),
                    Expanded(
                      child: PageInitLoadingShell(
                        loading: checkIn.loadingHistory,
                        child: filtered.isEmpty
                            ? (checkIn.loadingHistory
                                  ? const SizedBox.shrink()
                                  : _HistoryEmpty(message: emptyMessage))
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  ui(16),
                                  ui(12),
                                  ui(16),
                                  ui(20),
                                ),
                                itemCount: filteredEntries.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: ui(12)),
                                itemBuilder: (ctx, i) {
                                  final entry = filteredEntries[i];
                                  final card = entry.card;
                                  final item = entry.item;
                                  return _HistoryDrawerRecordCard(
                                    data: card,
                                    onApplyMakeup:
                                        _kStudentMakeupSignEnabled &&
                                            card.isAbsent
                                        ? () => widget.onApplyMakeup(item)
                                        : null,
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MakeupFilterBar(
                      status: _makeupStatus,
                      onStatusChanged: (s) {
                        setState(() => _makeupStatus = s);
                        unawaited(_reloadMakeupList());
                      },
                    ),
                    _MakeupSummaryBar(total: makeupItems.length),
                    Expanded(
                      child: PageInitLoadingShell(
                        loading: checkIn.loadingMakeup,
                        child: makeupItems.isEmpty
                            ? (checkIn.loadingMakeup
                                  ? const SizedBox.shrink()
                                  : _HistoryEmpty(
                                      message: checkIn.makeupError.isNotEmpty
                                          ? checkIn.makeupError
                                          : '暂无补签申请',
                                    ))
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  ui(16),
                                  ui(12),
                                  ui(16),
                                  ui(20),
                                ),
                                itemCount: makeupItems.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: ui(12)),
                                itemBuilder: (ctx, i) {
                                  final item = makeupItems[i];
                                  return _CourseSignMakeupCard(
                                    item: item,
                                    onTap: () =>
                                        unawaited(_showMakeupDetail(item)),
                                  );
                                },
                              ),
                      ),
                    ),
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

class _HistoryDrawerHeader extends StatelessWidget {
  const _HistoryDrawerHeader({
    required this.onClose,
    required this.tab,
    required this.onTabChanged,
  });

  final VoidCallback onClose;
  final _HistoryDrawerTab tab;
  final ValueChanged<_HistoryDrawerTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(8)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                '历史记录',
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
          SizedBox(height: ui(12)),
          _HistorySlidingToggle(
            selectedIndex: tab == _HistoryDrawerTab.signHistory ? 0 : 1,
            labels: const ['签到历史', '补签申请'],
            onChanged: (index) => onTabChanged(
              index == 0
                  ? _HistoryDrawerTab.signHistory
                  : _HistoryDrawerTab.makeup,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySlidingToggle extends StatelessWidget {
  const _HistorySlidingToggle({
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  static const Duration _duration = Duration(milliseconds: 180);
  static const Curve _curve = Curves.easeOut;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final count = labels.length;
    final safeIndex = count == 0 ? 0 : selectedIndex.clamp(0, count - 1);
    final thumbAlignX = count <= 1 ? 0.0 : (safeIndex / (count - 1)) * 2 - 1;
    final textStyle = TextStyle(fontSize: ui(13), height: 1);

    return Container(
      height: ui(_kHistoryFilterControlHeight),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      padding: EdgeInsets.all(ui(3)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Opacity(
                    opacity: 0,
                    child: Text(label, style: textStyle, maxLines: 1),
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: AnimatedAlign(
              duration: _duration,
              curve: _curve,
              alignment: Alignment(thumbAlignX, 0),
              child: FractionallySizedBox(
                widthFactor: count == 0 ? 1 : 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(ui(8)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Center(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        style: textStyle.copyWith(
                          color: i == safeIndex ? _kPurple : _kTextSecondary,
                          fontWeight: i == safeIndex
                              ? AppFont.w500
                              : AppFont.w400,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.range,
    required this.selectedDate,
    required this.status,
    required this.onRangeChanged,
    required this.onDateChanged,
    required this.onStatusChanged,
  });

  final _HistoryTimeRange range;
  final String? selectedDate;
  final _HistoryStatusFilter status;
  final ValueChanged<_HistoryTimeRange> onRangeChanged;
  final ValueChanged<String?> onDateChanged;
  final ValueChanged<_HistoryStatusFilter> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '时间范围',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          Row(
            children: [
              _HistoryRangePill(
                label: '本周',
                selected: range == _HistoryTimeRange.week,
                onTap: () => onRangeChanged(_HistoryTimeRange.week),
              ),
              SizedBox(width: ui(8)),
              _HistoryRangePill(
                label: '本月',
                selected: range == _HistoryTimeRange.month,
                onTap: () => onRangeChanged(_HistoryTimeRange.month),
              ),
              SizedBox(width: ui(8)),
              _HistoryRangePill(
                label: '本学期',
                selected: range == _HistoryTimeRange.semester,
                onTap: () => onRangeChanged(_HistoryTimeRange.semester),
              ),
            ],
          ),
          SizedBox(height: ui(14)),
          Text(
            '日期筛选',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          _HistoryDatePickerField(
            selectedDate: selectedDate,
            onDateChanged: onDateChanged,
          ),
          SizedBox(height: ui(14)),
          Container(
            height: ui(_kHistoryFilterControlHeight),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(10)),
            ),
            padding: EdgeInsets.all(ui(3)),
            child: Row(
              children: [
                _HistoryStatusTab(
                  label: '全部',
                  selected: status == _HistoryStatusFilter.all,
                  onTap: () => onStatusChanged(_HistoryStatusFilter.all),
                ),
                _HistoryStatusTab(
                  label: '正常',
                  selected: status == _HistoryStatusFilter.normal,
                  onTap: () => onStatusChanged(_HistoryStatusFilter.normal),
                ),
                _HistoryStatusTab(
                  label: '缺勤',
                  selected: status == _HistoryStatusFilter.absent,
                  onTap: () => onStatusChanged(_HistoryStatusFilter.absent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDatePickerField extends StatelessWidget {
  const _HistoryDatePickerField({
    required this.selectedDate,
    required this.onDateChanged,
  });

  final String? selectedDate;
  final ValueChanged<String?> onDateChanged;

  String _isoDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final trimmed = selectedDate?.trim() ?? '';
    final hasDate = trimmed.isNotEmpty;
    return InkWell(
      onTap: () async {
        final picked = await showAppDatePicker(
          context: context,
          initialDate: hasDate
              ? (DateTime.tryParse(trimmed) ?? DateTime.now())
              : DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
          helpText: '选择日期',
          cancelText: '取消',
          confirmText: '确定',
        );
        if (picked != null) {
          onDateChanged(_isoDate(picked));
        }
      },
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(_kHistoryFilterControlHeight),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          children: [
            AppPickerAssetIcon(
              AppAssets.iconScheduleCalendar,
              imageSize: ui(18),
            ),
            SizedBox(width: ui(8)),
            Expanded(
              child: Text(
                hasDate ? trimmed : '选择日期',
                style: TextStyle(
                  fontSize: ui(13),
                  color: hasDate ? _kTextDark : _kTextSecondary,
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ),
            if (hasDate)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onDateChanged(null),
                child: Padding(
                  padding: EdgeInsets.all(ui(4)),
                  child: Icon(
                    Icons.close_rounded,
                    size: ui(16),
                    color: _kTextSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRangePill extends StatelessWidget {
  const _HistoryRangePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Container(
          height: ui(_kHistoryFilterControlHeight),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _kPurple : AppColors.surface,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: selected ? _kPurple : _kBorderSoft),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(13),
              color: selected ? AppColors.surface : _kTextSecondary,
              fontWeight: selected ? AppFont.w500 : AppFont.w400,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryStatusTab extends StatelessWidget {
  const _HistoryStatusTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(ui(8)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(13),
              color: selected ? _kPurple : _kTextSecondary,
              fontWeight: selected ? AppFont.w500 : AppFont.w400,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySummaryBar extends StatelessWidget {
  const _HistorySummaryBar({
    required this.total,
    required this.normal,
    required this.absent,
  });

  final int total;
  final int normal;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(12), ui(16), 0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: ui(12),
            fontWeight: AppFont.w400,
            height: 1,
          ),
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
            const TextSpan(
              text: '   ·   ',
              style: TextStyle(color: _kTextDivider),
            ),
            const TextSpan(
              text: '正常 ',
              style: TextStyle(color: _kTextHint),
            ),
            TextSpan(
              text: '$normal',
              style: const TextStyle(color: _kStatusGreen),
            ),
            const TextSpan(
              text: '   ·   ',
              style: TextStyle(color: _kTextDivider),
            ),
            const TextSpan(
              text: '缺勤 ',
              style: TextStyle(color: _kTextHint),
            ),
            TextSpan(
              text: '$absent',
              style: const TextStyle(color: _kAttendRed),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({this.message = '暂无签到记录'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: ui(48),
            color: _kTextDivider,
          ),
          SizedBox(height: ui(12)),
          Text(
            message,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MakeupFilterBar extends StatelessWidget {
  const _MakeupFilterBar({required this.status, required this.onStatusChanged});

  final _MakeupStatusFilter status;
  final ValueChanged<_MakeupStatusFilter> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '审批状态',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          Container(
            height: ui(_kHistoryFilterControlHeight),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(10)),
            ),
            padding: EdgeInsets.all(ui(3)),
            child: Row(
              children: [
                _HistoryStatusTab(
                  label: '全部',
                  selected: status == _MakeupStatusFilter.all,
                  onTap: () => onStatusChanged(_MakeupStatusFilter.all),
                ),
                _HistoryStatusTab(
                  label: '待审批',
                  selected: status == _MakeupStatusFilter.pending,
                  onTap: () => onStatusChanged(_MakeupStatusFilter.pending),
                ),
                _HistoryStatusTab(
                  label: '已通过',
                  selected: status == _MakeupStatusFilter.approved,
                  onTap: () => onStatusChanged(_MakeupStatusFilter.approved),
                ),
                _HistoryStatusTab(
                  label: '已驳回',
                  selected: status == _MakeupStatusFilter.rejected,
                  onTap: () => onStatusChanged(_MakeupStatusFilter.rejected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MakeupSummaryBar extends StatelessWidget {
  const _MakeupSummaryBar({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(12), ui(16), 0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: ui(12),
            fontWeight: AppFont.w400,
            height: 1,
          ),
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
              text: ' 条补签申请',
              style: TextStyle(color: _kTextHint),
            ),
          ],
        ),
      ),
    );
  }
}

/// 补签卡副信息：班级 · 上课日期 · 第N节（缺项自动省略）。
String _makeupMetaLine(StudentCourseSignMakeupItem item) {
  final parts = <String>[
    if (item.className.isNotEmpty) item.className,
    if (item.courseDate.isNotEmpty) item.courseDate,
    if (item.lineNum > 0) '第${item.lineNum}节',
  ];
  return parts.isEmpty ? '课堂补签申请' : parts.join(' · ');
}

class _CourseSignMakeupCard extends StatelessWidget {
  const _CourseSignMakeupCard({required this.item, required this.onTap});

  final StudentCourseSignMakeupItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (Color bg, Color fg) = switch (item.status) {
      0 => (AppColors.warningSoft, AppColors.warning),
      1 => (AppColors.successSoft, _kStatusGreen),
      2 => (AppColors.dangerSoft, _kAttendRed),
      _ => (_kInnerGray, _kTextSecondary),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(16)),
      child: Container(
        padding: EdgeInsets.all(ui(12)),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(
                  seed: item.courseName,
                  size: ui(36),
                  imageUrl: item.teacherHeadUrl,
                ),
                SizedBox(width: ui(8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kTextSection,
                          fontWeight: AppFont.w600,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: ui(4)),
                      Text(
                        _makeupMetaLine(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextHint,
                          fontWeight: AppFont.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ui(8)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(6),
                    vertical: ui(2),
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(ui(4)),
                  ),
                  child: Text(
                    item.displayStatus,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: fg,
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ui(10)),
            Row(
              children: [
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
                    item.signTypeLabel,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kPurple,
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(width: ui(8)),
                Expanded(
                  child: Text(
                    '申请于 ${item.createTime.isEmpty ? '—' : item.createTime}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontWeight: AppFont.w400,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCourseSignMakeupDetailDialog(
  BuildContext context, {
  required String title,
  required List<({String label, String value})> fields,
}) {
  final ui = DashboardScaleScope.of(context).ui;
  return showScaledDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withValues(alpha: 0.18),
    builder: (ctx) => GradientHeaderDialog(
      title: title,
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(16)),
            decoration: BoxDecoration(
              color: _kInnerGray,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(6)),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: ui(13), height: 1.5),
                      children: [
                        TextSpan(
                          text: '${fields[i].label}：',
                          style: TextStyle(
                            color: _kTextHint,
                            fontWeight: AppFont.w400,
                          ),
                        ),
                        TextSpan(
                          text: fields[i].value.isEmpty ? '—' : fields[i].value,
                          style: TextStyle(
                            color: _kTextDark,
                            fontWeight: AppFont.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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

// =============================================================================
// API 数据映射
// =============================================================================

List<_StatItem> _statsFromSummary(StudentCheckInStat stat) {
  final rate = stat.attendanceRate;
  final rateLabel = rate % 1 == 0
      ? '${rate.toStringAsFixed(0)}%'
      : '${rate.toStringAsFixed(1)}%';
  return [
    _StatItem(value: '${stat.totalCount}', label: '应到课次'),
    _StatItem(value: '${stat.normalCount}', label: '正常'),
    _StatItem(value: '${stat.lateCount}', label: '迟到'),
    _StatItem(value: '${stat.leaveCount}', label: '请假'),
    _StatItem(value: '${stat.absentCount}', label: '缺勤'),
    _StatItem(value: rateLabel, label: '出勤率（正常 + 迟到）', valueColor: _kPurple),
  ];
}

/// 从日期时间串中提取「时:分:秒」（或「时:分」），去除年月日。
/// 例：`2026-06-18 01:26:42` → `01:26:42`。
String? _timeOnly(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'(\d{1,2}:\d{2}(?::\d{2})?)').firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}

_RecentRecordData _recentRecordFromItem(
  StudentSignRecordItem item, {
  String headFallback = '',
}) {
  final start = _timeOnly(item.studentSignInTime);
  final avatarUrl = item.teacherHeadUrl.isNotEmpty
      ? item.teacherHeadUrl
      : headFallback;
  return _RecentRecordData(
    courseId: item.courseId,
    date: item.date,
    status: item.attendStatus,
    studentName: item.subjectName,
    teacherName: item.teacherName,
    duration: item.durationLabel,
    location: item.location,
    timeStart: item.timeStart,
    timeEnd: item.timeEnd,
    startCard: item.isAbsent
        ? null
        : (start == null || start.isEmpty ? '-' : start),
    method: item.method.isEmpty ? null : item.method,
    note: item.note.isEmpty
        ? (item.isAbsent ? '老师签课时没有到，记为缺勤' : '无')
        : item.note,
    avatarUrl: avatarUrl,
    className: item.className,
    lineNum: item.lineNum,
  );
}

/// 汇总 `teacherId → 头像` 映射：从已带头像的「今日课程 / 最近记录」中收集，
/// 用于给「签到历史」等头像字段为空的列表回填教师头像。
Map<String, String> _teacherHeadById(StudentCheckInState checkIn) {
  final map = <String, String>{};
  for (final c in checkIn.todayCourses) {
    if (c.teacherId.isNotEmpty && c.teacherHeadUrl.isNotEmpty) {
      map.putIfAbsent(c.teacherId, () => c.teacherHeadUrl);
    }
  }
  for (final r in checkIn.recentRecords) {
    if (r.teacherId.isNotEmpty && r.teacherHeadUrl.isNotEmpty) {
      map.putIfAbsent(r.teacherId, () => r.teacherHeadUrl);
    }
  }
  return map;
}

class _MakeupReasonDialog extends StatefulWidget {
  const _MakeupReasonDialog({required this.courseName});

  final String courseName;

  @override
  State<_MakeupReasonDialog> createState() => _MakeupReasonDialogState();
}

class _MakeupReasonDialogState extends State<_MakeupReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final canSubmit = _controller.text.trim().isNotEmpty;
    return GradientHeaderDialog(
      title: '申请补签',
      width: 460,
      actionBar: AppDialogActionBar(
        confirmLabel: '提交申请',
        cancelLabel: '取消',
        confirmEnabled: canSubmit,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () {
          final text = _controller.text.trim();
          if (text.isEmpty) return;
          Navigator.of(context).pop(text);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.courseName,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          SizedBox(height: ui(16)),
          Text(
            '补签原因',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          TextField(
            controller: _controller,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '请填写补签原因',
              filled: true,
              fillColor: _kInnerGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ui(8)),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(ui(12)),
            ),
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
