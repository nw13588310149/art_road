import 'package:flutter/material.dart';

import '../../../core/network/media_url.dart';
import 'schedule_color_palette.dart';

/// 课表网格内课程卡片的四种视觉主题（与管理员排课页一致）。
enum ScheduleCourseCardKind {
  smallOrange,
  smallBlue,
  bigStandard,
  bigExtended,
}

/// 课表课程卡展示数据（管理员 / 教师 / 学生共用）。
class ScheduleCourseCardData {
  const ScheduleCourseCardData({
    required this.kind,
    required this.location,
    required this.name,
    required this.subline,
    this.logoUrl = '',
    this.capacity,
    this.bgColor,
  });

  final ScheduleCourseCardKind kind;
  final String location;
  final String name;
  final String subline;
  final String logoUrl;
  final String? capacity;
  final Color? bgColor;
}

ScheduleCardThemeKind scheduleCourseCardThemeKind(ScheduleCourseCardKind kind) {
  return switch (kind) {
    ScheduleCourseCardKind.smallOrange => ScheduleCardThemeKind.smallOrange,
    ScheduleCourseCardKind.smallBlue => ScheduleCardThemeKind.smallBlue,
    ScheduleCourseCardKind.bigStandard => ScheduleCardThemeKind.bigStandard,
    ScheduleCourseCardKind.bigExtended => ScheduleCardThemeKind.bigExtended,
  };
}

/// 从 API `courseList` 单条记录构建课表课程卡展示数据。
/// 字段映射与管理员排课页 `_parseCourseCard` 保持一致。
ScheduleCourseCardData buildScheduleCourseCard(
  Map<String, dynamic> json,
  int smallIdxInCell,
) {
  final typeRaw = json['type'];
  final type = typeRaw is int
      ? typeRaw
      : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
  final isSmall = type == 1;

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
  final colorOverride =
      parseScheduleHexColor(pickScheduleString(json, ['color']));

  if (isSmall) {
    final kind = smallIdxInCell.isEven
        ? ScheduleCourseCardKind.smallOrange
        : ScheduleCourseCardKind.smallBlue;
    return ScheduleCourseCardData(
      kind: kind,
      location: location,
      name: name,
      subline: className.isNotEmpty ? className : teacher,
      logoUrl: resolveScheduleLogoUrl(json),
      capacity: pickScheduleCapacityLabel(json),
      bgColor: colorOverride,
    );
  }
  return ScheduleCourseCardData(
    kind: ScheduleCourseCardKind.bigStandard,
    location: location,
    name: name,
    subline: teacher.isEmpty
        ? className
        : (className.isEmpty ? teacher : '$teacher-$className'),
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

String? pickScheduleCapacityLabel(Map<String, dynamic> json) {
  final attendCount = json['attendCount'] ?? json['signCount'];
  final totalCount =
      json['totalCount'] ?? json['capacity'] ?? json['classSize'];
  if (attendCount != null && totalCount != null) {
    return '$attendCount/$totalCount人';
  }
  return null;
}
