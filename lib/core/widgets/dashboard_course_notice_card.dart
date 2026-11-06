import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../../features/shell/ui/shell_layout.dart';
import 'course_class_kind_tag.dart';
import 'course_subject_tag.dart';

/// 首页右侧 / 智慧校园学生端课表共用的 104 高课程卡。
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

  /// 自定义右上角状态角标（如签到历史「正常 / 缺勤」）；未设置时沿用课程阶段文案。
  final String? statusBadgeLabel;
  final Color? statusBadgeBackground;
  final Color? statusBadgeTextColor;
  final VoidCallback? onTap;

  static const Color _kCardBg = Color(0xFFF5F6FA);
  static const Color _kStatusEndedBg = Color(0xFFE6E9F1);
  static const Color _kStatusActiveBg = Color(0xFFEAE5FF);
  static const Color _kTextDark = Color(0xFF0B081A);
  static const Color _kTextSection = Color(0xFF1A1A1A);
  static const Color _kTextHint = Color(0xFFB6B5BB);
  static const Color _kTimeDash = Color(0xFFB6B5BB);
  static const double _kStatusBadgeWidth = 60;
  static const double _kHeaderStatusGap = 4;

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

  bool get _isEnded => runState == DashboardCourseRunState.ended;

  bool get _isUpcoming => runState == DashboardCourseRunState.upcoming;

  String get _statusLabel => switch (runState) {
    DashboardCourseRunState.ended => '已结束',
    DashboardCourseRunState.inProgress => '进行中',
    DashboardCourseRunState.upcoming => '待开始',
  };

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.maybeOf(context);
    double ui(double value) => scale?.ui(value) ?? value;

    final statusColor =
        statusBadgeBackground ??
        (_isEnded ? _kStatusEndedBg : _kStatusActiveBg);
    final statusTextColor =
        statusBadgeTextColor ?? (_isEnded ? _kTextHint : _kTextDark);
    final badgeLabel = statusBadgeLabel ?? _statusLabel;
    final timeTextColor = _isUpcoming ? _kTextDark : _kTextSection;
    final muted = _isEnded;
    final resolvedDotColor = muted ? null : tagDotColor;

    final card = Container(
      width: double.infinity,
      height: ui(104),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: ui(6),
                  offset: Offset(0, ui(2)),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(16),
            top: ui(14),
            // 只保留状态角标自身宽度 + 4px 安全间距，尽量扩大右侧标签
            // 横向滑动区，同时确保内容不会进入角标覆盖范围。
            right: ui(_kStatusBadgeWidth + _kHeaderStatusGap),
            child: _ResponsiveCourseHeader(
              startTime: startTime,
              endTime: endTime,
              subjectName: subjectName,
              isSmallCourse: isSmallCourse,
              textColor: timeTextColor,
              muted: muted,
              tagDotColor: resolvedDotColor,
              ui: ui,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: ui(_kStatusBadgeWidth),
              height: ui(22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(ui(12)),
                  bottomLeft: Radius.circular(ui(12)),
                ),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: ui(12),
                  color: statusTextColor,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(left: ui(16), top: ui(48), child: avatar),
          Positioned(
            left: ui(64),
            top: ui(50),
            right: ui(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 22 / 14,
                    color: _kTextDark,
                    fontWeight: AppFont.w600,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

/// 首页、任课老师端和学生端共用课程卡首行。
///
/// 时间始终完整显示；科目与大/小课标签视为一个不可拆分的自然宽度整体，
/// 剩余空间不足时只在标签区域内横向滑动，不压缩或截断任一标签。
class _ResponsiveCourseHeader extends StatelessWidget {
  const _ResponsiveCourseHeader({
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.isSmallCourse,
    required this.textColor,
    required this.muted,
    required this.tagDotColor,
    required this.ui,
  });

  final String startTime;
  final String endTime;
  final String subjectName;
  final bool isSmallCourse;
  final Color textColor;
  final bool muted;
  final Color? tagDotColor;
  final double Function(double) ui;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _TimeLabel(
          startTime: startTime,
          endTime: endTime,
          textColor: textColor,
          ui: ui,
        ),
        SizedBox(width: ui(6)),
        Expanded(
          child: ClipRect(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CourseSubjectTag(name: subjectName, muted: muted),
                    SizedBox(width: ui(4)),
                    CourseClassKindTag(
                      isSmall: isSmallCourse,
                      muted: muted,
                      dotColor: tagDotColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({
    required this.startTime,
    required this.endTime,
    required this.textColor,
    required this.ui,
  });

  final String startTime;
  final String endTime;
  final Color textColor;
  final double Function(double) ui;

  @override
  Widget build(BuildContext context) {
    final hasEnd = endTime.isNotEmpty && endTime != '--:--';
    final baseStyle = TextStyle(
      fontSize: ui(18),
      color: textColor,
      fontFamily: 'Barlow',
      fontWeight: FontWeight.w600,
      height: 1,
    );
    if (!hasEnd) {
      return Text(startTime, maxLines: 1, softWrap: false, style: baseStyle);
    }
    return RichText(
      maxLines: 1,
      softWrap: false,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: '$startTime '),
          TextSpan(
            text: '- ',
            style: TextStyle(color: DashboardCourseNoticeCard._kTimeDash),
          ),
          TextSpan(text: endTime),
        ],
      ),
    );
  }
}
