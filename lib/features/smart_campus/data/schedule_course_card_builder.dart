import 'package:flutter/material.dart';

import '../../../core/network/media_url.dart';
import 'schedule_color_palette.dart';

/// 课表课程卡展示数据（管理员 / 教师 / 学生共用）。课程只有一种，卡片也只有
/// 一种样式，底色取课程色。
class ScheduleCourseCardData {
  const ScheduleCourseCardData({
    required this.location,
    required this.name,
    required this.subline,
    this.logoUrl = '',
    this.bgColor,
  });

  final String location;
  final String name;
  final String subline;
  final String logoUrl;
  final Color? bgColor;
}

/// 课程卡第二行写什么：学生看老师，老师看班级，管理端看老师。
enum ScheduleCardSubline { teacher, className, teacherAndClass }

/// 教室名去掉校区前缀（「城东校区 · 素描教室 A」→「素描教室 A」），校区写在页头。
String scheduleRoomName(String location) {
  final parts = location.split(' · ');
  return parts.length > 1 ? parts.last.trim() : location.trim();
}

/// 从 API `courseList` 单条记录构建课表课程卡展示数据。
/// 字段映射与管理员排课页 `_parseCourseCard` 保持一致。
ScheduleCourseCardData buildScheduleCourseCard(
  Map<String, dynamic> json, {
  ScheduleCardSubline subline = ScheduleCardSubline.teacherAndClass,
}) {
  final location = pickScheduleString(json, [
    'classroomName',
    'roomName',
    'classroom',
  ]);
  final name = pickScheduleString(json, [
    'subjectName',
    'courseName',
    'subject',
    'name',
  ]);
  final teacher = pickScheduleString(json, [
    'teacherRealname',
    'teacherName',
    'realname',
    'realName',
    'teacherNickname',
    'teacher',
  ]);
  final className = pickScheduleString(json, ['className', 'class']);
  final colorOverride = parseScheduleHexColor(
    pickScheduleString(json, ['color']),
  );
  final line = switch (subline) {
    ScheduleCardSubline.teacher => teacher.isEmpty ? className : teacher,
    ScheduleCardSubline.className => className.isEmpty ? teacher : className,
    ScheduleCardSubline.teacherAndClass => [
      teacher,
      className,
    ].where((s) => s.isNotEmpty).join(' · '),
  };

  return ScheduleCourseCardData(
    location: scheduleRoomName(location),
    name: name,
    subline: line,
    logoUrl: resolveScheduleLogoUrl(json),
    bgColor: colorOverride,
  );
}

/// 课表条目中的任课老师头像。`student/courseList` 等新接口在顶层下发
/// `teacherHeadUrl`；嵌套 `teacher` 对象内可能为 `headUrl`。
String resolveScheduleTeacherHeadUrl(Map<String, dynamic> json) {
  var raw = pickScheduleString(json, [
    'teacherHeadUrl',
    'teacherHead',
    'headUrl',
    'avatar',
    'avatarUrl',
    'headImg',
  ]);
  if (raw.isEmpty) {
    final nested = json['teacher'];
    if (nested is Map) {
      final map = nested.map((key, value) => MapEntry(key.toString(), value));
      raw = pickScheduleString(map, [
        'headUrl',
        'avatar',
        'avatarUrl',
        'headImg',
      ]);
    }
  }
  return raw.isEmpty ? '' : MediaUrl.resolve(raw);
}

/// 课程与班级相关接口统一下发的 `logo`。课程列表为顶层字段，下一节课等
/// 组合响应可能把它放在 `schoolClass` / `classInfo` 内。
String resolveScheduleLogoUrl(Map<String, dynamic> json) {
  var raw = pickScheduleString(json, ['logo', 'logoUrl', 'classLogo']);
  if (raw.isEmpty) {
    for (final key in ['schoolClass', 'classInfo', 'class']) {
      final nested = json[key];
      if (nested is! Map) continue;
      final map = nested.map((key, value) => MapEntry(key.toString(), value));
      raw = pickScheduleString(map, ['logo', 'logoUrl', 'classLogo']);
      if (raw.isNotEmpty) break;
    }
  }
  return raw.isEmpty ? '' : MediaUrl.resolve(raw);
}

String pickScheduleString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}
