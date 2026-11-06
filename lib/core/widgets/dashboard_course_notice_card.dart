import 'package:flutter/material.dart';

import '../ui/app_course_card.dart';
import '../ui/app_tag.dart';

/// 课程阶段（首页 / 智慧校园课表共用）。
enum DashboardCourseRunState { ended, inProgress, upcoming }

DateTime? dateTimeAtCourseHm(DateTime day, String hm) {
  var clock = hm.trim();
  if (clock.length >= 5 && clock.contains(':')) {
    clock = clock.substring(0, 5);
  }
  if (clock.isEmpty) return null;
  final parts = clock.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// 按当日 `HH:mm` 起止判断课程阶段（首页 / 智慧校园课表共用）。
DashboardCourseRunState resolveDashboardCourseRunState(
  DateTime now,
  String startHm,
  String endHm, {
  DateTime? day,
}) {
  final base = day ?? now;
  final start = dateTimeAtCourseHm(base, startHm);
  final end = dateTimeAtCourseHm(base, endHm);
  if (start == null || end == null) return DashboardCourseRunState.upcoming;
  if (now.isBefore(start)) return DashboardCourseRunState.upcoming;
  if (now.isAfter(end)) return DashboardCourseRunState.ended;
  return DashboardCourseRunState.inProgress;
}

DashboardCourseRunState resolveDashboardCourseRunStateFromIsoDate(
  DateTime now,
  String isoDate,
  String startHm,
  String endHm,
) {
  final day = DateTime.tryParse(isoDate);
  if (day == null) {
    return resolveDashboardCourseRunState(now, startHm, endHm);
  }
  return resolveDashboardCourseRunState(now, startHm, endHm, day: day);
}

/// 首页右侧课程、课堂签到、任课老师今日课表共用的课程卡，渲染 [AppCourseCard]，
/// 高度随内容。
class DashboardCourseNoticeCard extends StatelessWidget {
  const DashboardCourseNoticeCard({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.isSmallCourse,
    required this.displayName,
    required this.subtitle,
    required this.avatar,
    required this.runState,
    this.isSelected = false,
    this.tagDotColor,
    this.statusBadgeLabel,
    this.statusBadgeBackground,
    this.statusBadgeTextColor,
    this.onTap,
  });

  final String startTime;
  final String endTime;
  final String subjectName;
  final bool isSmallCourse;
  final String displayName;
  final String subtitle;
  final Widget avatar;
  final DashboardCourseRunState runState;
  final bool isSelected;
  final Color? tagDotColor;

  /// 自定义右上角状态（如签到历史「正常 / 缺勤」）；未设置时显示课程阶段。
  final String? statusBadgeLabel;
  final Color? statusBadgeBackground;
  final Color? statusBadgeTextColor;
  final VoidCallback? onTap;

  static Color? dotColorFromHex(String? hex, {required bool ended}) {
    if (ended) return null;
    final raw = hex?.trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.startsWith('#') ? raw.substring(1) : raw;
    if (normalized.length != 6 && normalized.length != 8) return null;
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) return null;
    if (normalized.length == 8) {
      return Color(value);
    }
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final badge = statusBadgeLabel;
    return AppCourseCard(
      startTime: startTime,
      endTime: endTime,
      subject: subjectName,
      teacherName: displayName,
      subtitle: subtitle,
      isSmallCourse: isSmallCourse,
      status: switch (runState) {
        DashboardCourseRunState.ended => AppCourseStatus.ended,
        DashboardCourseRunState.inProgress => AppCourseStatus.inProgress,
        DashboardCourseRunState.upcoming => AppCourseStatus.upcoming,
      },
      statusTag: badge == null
          ? null
          : AppTag(
              label: badge,
              color: statusBadgeTextColor,
              background: statusBadgeBackground,
            ),
      avatar: avatar,
      classKindDotColor: tagDotColor,
      selected: isSelected,
      onTap: onTap,
    );
  }
}
