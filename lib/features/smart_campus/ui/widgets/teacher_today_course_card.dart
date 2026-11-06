import 'package:flutter/material.dart';

import '../../../../core/widgets/dashboard_course_notice_card.dart';

/// 签课管理「今日课程」使用的首页课程卡适配层。
///
/// 基础视觉完全交给 [DashboardCourseNoticeCard]，这里只保留签课页的选中态
/// 与教师端课程状态枚举转换，避免两套课程卡样式再次产生偏差。
enum TeacherTodayCourseRunState { ended, inProgress, upcoming }

class TeacherTodayCourseCard extends StatelessWidget {
  const TeacherTodayCourseCard({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.runState,
    required this.displayName,
    required this.courseName,
    required this.isSmallCourse,
    required this.subtitle,
    required this.avatar,
    this.isActive = false,
    this.onTap,
    this.tagDotColor,
  });

  final String startTime;
  final String endTime;
  final TeacherTodayCourseRunState runState;
  final String displayName;
  final String courseName;
  final bool isSmallCourse;
  final String subtitle;
  final Widget avatar;
  final bool isActive;
  final VoidCallback? onTap;
  final Color? tagDotColor;

  DashboardCourseRunState get _dashboardRunState => switch (runState) {
    TeacherTodayCourseRunState.ended => DashboardCourseRunState.ended,
    TeacherTodayCourseRunState.inProgress => DashboardCourseRunState.inProgress,
    TeacherTodayCourseRunState.upcoming => DashboardCourseRunState.upcoming,
  };

  @override
  Widget build(BuildContext context) {
    return DashboardCourseNoticeCard(
      startTime: startTime,
      endTime: endTime,
      subjectName: courseName,
      isSmallCourse: isSmallCourse,
      displayName: displayName,
      subtitle: subtitle,
      avatar: avatar,
      runState: _dashboardRunState,
      isSelected: isActive,
      tagDotColor: tagDotColor,
      onTap: onTap,
    );
  }
}
