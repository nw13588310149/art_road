// =============================================================================
// 班主任端「查寝历史」独立页面
//
// 入口：班主任 dashboard 快捷区「查寝历史」按钮 → controller.openDormHistory()
//      → mainView == dormHistory + role == headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高, 紫白渐变 #F9EDFF→white, 圆角 16, 顶部居中 "查寝历史
//      记录" 16/600 + 副标题 12/#B6B5BB「按自然日查看本班住宿生晚查寝
//      打卡汇总；数据与「查寝动态」演示同源。查寝老师打卡在专用端完成。」；
//      左 12 返回 32×32 白底 outline #F3F2F3）。
//   2. 日期条卡（970×110，圆角 16，白底）：
//      - 顶部 12,12 处 `2026-04-17` 14/500 + 下拉小箭头（演示）；
//      - 右侧 `应统计 N 人，当日流水 M 条。` 12 hint；
//      - 底部 14 个正方形圆角 8 灰底 cells（顶部 `星期` 12 hint /
//        底部 `日期` 16 Barlow/600），第 7 个 "日 / 今" 紫底白字。
//   3. 2 张统计卡（白底圆角 12）：晚查寝已归寝 / 晚查寝待关注。
//   4. 卡片网格 3 列（每张 312 宽，padding 12，白底，圆角 16，gap 16）：
//      - 宿舍口径卡：晨查寝 / 晚查寝 18 Barlow/600 标题 + 大色块状态徽章
//        正常 #A773FF / 未打卡 #FF323C / 迟到 #325BFF 全为白字；下行
//        宿舍 13/#6D6B75 + 日期；灰底块同；底部 备注。
//      - 学生口径卡：头像 40 + 姓名 14/500 + 学号 12/#B6B5BB +
//        "查寝" 12/#6D6B75 + 状态徽章 16 高（正常 #DAD2FF/#8741FF /
//        未打卡 #FEE4E8/#FF323C）；下行 宿舍 12 + 日期；灰底块 #F5F6FA
//        H50 居中两列：规定时间 / 打卡时间；底部 备注。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import 'widgets/smart_campus_stat_card.dart';
import '../data/student_dormitory_data.dart' show DormitoryDetailStudentProfile;
import '../data/teacher_dormitory_data.dart';
import '../data/dormitory_check_data.dart';
import '../state/teacher_dormitory_controller.dart';
import '../../school/data/school_config_data.dart';
import '../../school/state/school_config_controller.dart';
import 'widgets/dormitory_detail_dialog.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoftBg = Color(0xFFDAD2FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFEE4E8);
const Color _kBlue = Color(0xFF325BFF);
const Color _kCalendarHint = Color(0xFFE6E9F1);

// —— 学生口径状态（仅出现 正常 / 未打卡 两种） ——————————————————————
enum _StudentStatus {
  normal('正常', _kPurpleSoftBg, _kPurple),
  absent('未打卡', _kRedSoftBg, _kRed);

  const _StudentStatus(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}

// —— 宿舍口径状态（实色徽章）—————————————————————————————————————
enum _DormStatus {
  normal('正常', Color(0xFFA773FF)),
  absent('未打卡', _kRed),
  late_('迟到', _kBlue);

  const _DormStatus(this.label, this.solidBg);
  final String label;
  final Color solidBg;
}

enum _Session { morning, evening }

// —— 数据模型 ——————————————————————————————————————————————————
class _DormRecord {
  const _DormRecord({
    required this.session,
    required this.status,
    required this.dormName,
    required this.date,
    required this.requiredTime,
    required this.punchTime,
    required this.note,
  });

  final _Session session;
  final _DormStatus status;
  final String dormName;
  final String date;
  final String requiredTime;
  final String punchTime;
  final String note;

  String get titleText => session == _Session.morning ? '晨查寝' : '晚查寝';
}

class _StudentRecord {
  const _StudentRecord({
    required this.id,
    required this.session,
    required this.studentName,
    required this.studentNo,
    required this.headUrl,
    required this.status,
    required this.dormName,
    required this.date,
    required this.requiredTime,
    required this.punchTime,
    required this.note,
  });

  final String id;
  final _Session session;
  final String studentName;
  final String studentNo;
  final String headUrl;
  final _StudentStatus status;
  final String dormName;
  final String date;
  final String requiredTime;
  final String punchTime;
  final String note;
}

// —— 日历日 ————————————————————————————————————————————————————
class _CalendarDay {
  const _CalendarDay({
    required this.date,
    required this.weekdayLabel,
    required this.dayLabel,
    this.isToday = false,
  });

  final DateTime date;
  final String weekdayLabel;
  final String dayLabel;
  final bool isToday;
}

// —— 顶级视图 ——————————————————————————————————————————————————

class TeacherDormHistoryView extends ConsumerStatefulWidget {
  const TeacherDormHistoryView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherDormHistoryView> createState() =>
      _TeacherDormHistoryViewState();
}

class _TeacherDormHistoryViewState
    extends ConsumerState<TeacherDormHistoryView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(teacherDormitoryControllerProvider.notifier).initialize(),
    );
  }

  Future<void> _showCheckDetail(_StudentRecord record) async {
    if (record.id.isEmpty) return;
    final fields = await ref
        .read(teacherDormitoryControllerProvider.notifier)
        .loadCheckDetail(record.id);
    if (!mounted) return;
    if (fields.isEmpty) {
      AppToast.show(context, '未获取到查寝详情');
      return;
    }
    final checkConfig =
        ref.read(schoolDormitoryCheckConfigProvider).valueOrNull ??
        SchoolDormitoryCheckConfig.empty;
    final enrichedFields = enrichDormitoryDetailRequiredTime(
      fields: fields,
      checkType: record.session == _Session.morning ? '晨查寝' : '晚查寝',
      recordDeadline: record.requiredTime,
      config: checkConfig,
    );
    final rawAvatar = record.headUrl.trim();
    final avatarUrl =
        rawAvatar.isNotEmpty ? MediaUrl.resolve(rawAvatar) : '';
    final subtitle = record.studentNo.isNotEmpty && record.studentNo != '--'
        ? record.studentNo
        : record.dormName;
    await showDormitoryDetailDialog(
      context,
      title: '${record.studentName} · 查寝详情',
      fields: enrichedFields,
      studentProfile: DormitoryDetailStudentProfile(
        name: record.studentName,
        avatarUrl: avatarUrl,
        subtitle: subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = ref.watch(teacherDormitoryControllerProvider);
    final checkConfig =
        ref.watch(schoolDormitoryCheckConfigProvider).valueOrNull ??
        SchoolDormitoryCheckConfig.empty;
    final days = _historyCalendarDays(DateTime.now());
    final selectedDayIndex = days.indexWhere(
      (day) => teacherDormitoryIsoDate(day.date) == state.selectedDate,
    );
    final students = _historyStudentRecords(state.historyItems, checkConfig);
    final filteredStudents = students
        .where((record) => record.session == _Session.evening)
        .toList(growable: false);
    final exceptionCount = state.stat.lateCount + state.stat.absentCount;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(12)),
            _DateStripCard(
              days: days,
              selectedIndex: selectedDayIndex < 0 ? 6 : selectedDayIndex,
              dateText: state.selectedDate,
              statText:
                  '应统计 ${state.stat.studentCount} 人，当日流水 ${state.historyItems.length} 条。',
              onTapDay: (i) => ref
                  .read(teacherDormitoryControllerProvider.notifier)
                  .selectHistoryDate(days[i].date),
            ),
            SizedBox(height: ui(16)),
            _StatsRow(
              eveningReturned: state.stat.normalCount,
              eveningWatch: exceptionCount,
            ),
            SizedBox(height: ui(16)),
            _CardsGrid(
              dormRecords: const [],
              students: filteredStudents,
              onStudentTap: (record) => unawaited(_showCheckDetail(record)),
            ),
          ],
        ),
      ),
    );
  }
}

List<_CalendarDay> _historyCalendarDays(DateTime now) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var offset = -6; offset <= 7; offset++)
      () {
        final date = today.add(Duration(days: offset));
        return _CalendarDay(
          date: date,
          weekdayLabel: weekdays[date.weekday - 1],
          dayLabel: offset == 0 ? '今' : date.day.toString(),
          isToday: offset == 0,
        );
      }(),
  ];
}

List<_StudentRecord> _historyStudentRecords(
  List<TeacherDormitoryHistoryItem> items,
  SchoolDormitoryCheckConfig checkConfig,
) {
  return [
    for (final item in items)
      _StudentRecord(
        id: item.id,
        session: item.isMorning ? _Session.morning : _Session.evening,
        studentName: item.studentName,
        studentNo: item.studentNo,
        headUrl: item.avatarUrl,
        status: item.status == TeacherDormitoryStatus.normal
            ? _StudentStatus.normal
            : _StudentStatus.absent,
        dormName: item.dormName.isEmpty ? '未分配宿舍' : item.dormName,
        date: item.checkDate,
        requiredTime: resolveDormitoryRequiredDeadline(
          recordDeadline: '',
          checkType: item.isMorning ? '晨查寝' : '晚查寝',
          config: checkConfig,
        ),
        punchTime: item.checkTime,
        note: item.status == TeacherDormitoryStatus.late ? '晚归' : '无',
      ),
  ];
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
      decoration: smartCampusPageBannerDecoration(ui),
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
                    '查寝历史记录',
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
                    '按自然日查看本班住宿生晚查寝打卡汇总；数据与「查寝动态」演示同源。查寝老师打卡在专用端完成。',
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

// —— 日期条卡 ——————————————————————————————————————————————————

class _DateStripCard extends StatelessWidget {
  const _DateStripCard({
    required this.days,
    required this.selectedIndex,
    required this.dateText,
    required this.statText,
    required this.onTapDay,
  });

  final List<_CalendarDay> days;
  final int selectedIndex;
  final String dateText;
  final String statText;
  final ValueChanged<int> onTapDay;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                dateText,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
              SizedBox(width: ui(6)),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(16),
                color: const Color(0xFF1A1A1A),
              ),
              const Spacer(),
              Text(
                statText,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(14)),
          // 14 天日期条
          LayoutBuilder(
            builder: (context, constraints) {
              const cellCount = 14;
              const gap = 6.0;
              final scaledGap = ui(gap);
              final totalGap = scaledGap * (cellCount - 1);
              final cellSize = (constraints.maxWidth - totalGap) / cellCount;
              return Row(
                children: List.generate(cellCount, (i) {
                  final day = days[i];
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == cellCount - 1 ? 0 : scaledGap,
                    ),
                    child: SizedBox(
                      width: cellSize,
                      height: cellSize,
                      child: _CalendarCell(
                        day: day,
                        selected: selected,
                        onTap: () => onTapDay(i),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final _CalendarDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = selected ? _kPurple : _kCardGreyBg;
    final weekdayColor = selected ? _kCalendarHint : _kTextHint;
    final dayColor = selected ? Colors.white : _kTextDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.weekdayLabel,
              style: TextStyle(
                fontSize: ui(12),
                color: weekdayColor,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
            SizedBox(height: ui(7)),
            Text(
              day.dayLabel,
              style: TextStyle(
                fontSize: ui(16),
                color: dayColor,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// —— 4 张统计卡 ————————————————————————————————————————————————

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.eveningReturned,
    required this.eveningWatch,
  });

  final int eveningReturned;
  final int eveningWatch;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '晚查寝 · 已归寝口径',
            value: eveningReturned,
            subtitle: '正常/免检/补卡过',
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _StatCard(
            title: '晚查寝 · 待关注',
            value: eveningWatch,
            subtitle: '晚归/未打卡',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final int value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(88),
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: smartCampusStatValueTextStyle(ui),
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: ui(2)),
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.0,
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

// —— 卡片网格 ——————————————————————————————————————————————————

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({
    required this.dormRecords,
    required this.students,
    this.onStudentTap,
  });

  final List<_DormRecord> dormRecords;
  final List<_StudentRecord> students;
  final ValueChanged<_StudentRecord>? onStudentTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (dormRecords.isEmpty && students.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: Text(
            '所选日期暂无查寝记录',
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
        const columns = 3;
        const gap = 16.0;
        final scaledGap = ui(gap);
        final cardWidth =
            (constraints.maxWidth - scaledGap * (columns - 1)) / columns;
        // 顺序：宿舍口径在前，学生口径在后（与 Figma 第一行就是 3 张
        // 宿舍口径卡 + 后续行学生口径一致；当前 tab 切换时仅显示同 session 的
        // 数据）。
        final widgets = <Widget>[];
        for (final r in dormRecords) {
          widgets.add(
            SizedBox(
              width: cardWidth,
              child: _DormCard(record: r),
            ),
          );
        }
        for (final r in students) {
          widgets.add(
            SizedBox(
              width: cardWidth,
              child: _StudentCard(
                record: r,
                onTap: onStudentTap == null || r.id.isEmpty
                    ? null
                    : () => onStudentTap!(r),
              ),
            ),
          );
        }
        return Wrap(
          spacing: scaledGap,
          runSpacing: scaledGap,
          children: widgets,
        );
      },
    );
  }
}

// —— 宿舍口径卡 ————————————————————————————————————————————————

class _DormCard extends StatelessWidget {
  const _DormCard({required this.record});

  final _DormRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                record.titleText,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              _DormStatusBadge(status: record.status),
            ],
          ),
          SizedBox(height: ui(4)),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.dormName,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
              ),
              Text(
                record.date,
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
          SizedBox(height: ui(12)),
          _TimeBlock(
            requiredTime: record.requiredTime,
            punchTime: record.punchTime,
          ),
          SizedBox(height: ui(10)),
          Text(
            '备注：${record.note}',
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
    );
  }
}

class _DormStatusBadge extends StatelessWidget {
  const _DormStatusBadge({required this.status});

  final _DormStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.solidBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(12),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

// —— 学生口径卡 ————————————————————————————————————————————————

/// 查寝历史学生头像：相对路径经 [MediaUrl.resolve] 补全后加载。
class _DormStudentAvatar extends StatelessWidget {
  const _DormStudentAvatar({
    required this.rawHeadUrl,
    required this.name,
    required this.size,
  });

  final String rawHeadUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = ui(8);
    final raw = rawHeadUrl.trim();
    final url = raw.isNotEmpty ? MediaUrl.resolve(raw) : '';
    final initial = name.trim().isNotEmpty ? name.characters.first : '';

    Widget child;
    if (url.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(ui, radius, initial),
        ),
      );
    } else {
      child = _fallback(ui, radius, initial);
    }
    return SizedBox(width: size, height: size, child: child);
  }

  Widget _fallback(double Function(double) ui, double radius, String initial) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFA773FF),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: initial.isNotEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontSize: ui(size * 0.38),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            )
          : Icon(Icons.person_rounded, size: ui(size * 0.5), color: Colors.white),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.record, this.onTap});

  final _StudentRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(16)),
      child: Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DormStudentAvatar(
                rawHeadUrl: record.headUrl,
                name: record.studentName,
                size: ui(40),
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  record.studentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: ui(14),
                                    color: _kTextDark,
                                    fontFamily: 'PingFang SC',
                                    fontWeight: AppFont.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              SizedBox(width: ui(4)),
                              Text(
                                record.studentNo,
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
                        Text(
                          '查寝',
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        _StudentStatusBadge(status: record.status),
                      ],
                    ),
                    SizedBox(height: ui(6)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.dormName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1.2,
                            ),
                          ),
                        ),
                        Text(
                          record.date,
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
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          _TimeBlock(
            requiredTime: record.requiredTime,
            punchTime: record.punchTime,
          ),
          SizedBox(height: ui(10)),
          Text(
            '备注：${record.note}',
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
    );
  }
}

class _StudentStatusBadge extends StatelessWidget {
  const _StudentStatusBadge({required this.status});

  final _StudentStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
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
          height: 1.2,
        ),
      ),
    );
  }
}

// —— 灰底时间双列 ————————————————————————————————————————————

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.requiredTime, required this.punchTime});

  final String requiredTime;
  final String punchTime;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(11), horizontal: ui(8)),
      decoration: BoxDecoration(
        color: _kCardGreyBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeColumn(label: '规定时间', value: requiredTime),
          ),
          Expanded(
            child: _TimeColumn(label: '打卡时间', value: punchTime),
          ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
        SizedBox(height: ui(6)),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// —— 演示数据 ——————————————————————————————————————————————————

// ignore: unused_element
List<_DormRecord> _demoDormRecords() => const [
  // 晨查寝 · 正常（女生宿舍3号楼 612）
  _DormRecord(
    session: _Session.morning,
    status: _DormStatus.normal,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  // 晨查寝 · 未打卡
  _DormRecord(
    session: _Session.morning,
    status: _DormStatus.absent,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  // 晚查寝 · 迟到（备注：教师拖堂）
  _DormRecord(
    session: _Session.evening,
    status: _DormStatus.late_,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '21:20前',
    punchTime: '21:23',
    note: '教师拖堂',
  ),
];

// 学生口径示例：晚查寝 / 晨查寝 各 6 张（演示分布）。
// ignore: unused_element
List<_StudentRecord> _demoStudents() => const [
  _StudentRecord(
    id: '',
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    headUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    id: '',
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    headUrl: '',
    status: _StudentStatus.absent,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    id: '',
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    headUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    id: '',
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    headUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    id: '',
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    headUrl: '',
    status: _StudentStatus.absent,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    id: '',
    session: _Session.evening,
    studentName: '王晴',
    studentNo: 'G3030201',
    headUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  // 晨查寝
  _StudentRecord(
    id: '',
    session: _Session.morning,
    studentName: '王晴',
    studentNo: 'G3030201',
    headUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    id: '',
    session: _Session.morning,
    studentName: '王晴',
    studentNo: 'G3030201',
    headUrl: '',
    status: _StudentStatus.absent,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _StudentRecord(
    id: '',
    session: _Session.morning,
    studentName: '王晴',
    studentNo: 'G3030201',
    headUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
];
