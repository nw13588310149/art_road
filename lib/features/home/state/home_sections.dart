import 'package:flutter/foundation.dart';

import '../../../core/demo/demo_accounts.dart';
import '../../../core/demo/demo_config.dart';
import 'home_dashboard_state.dart';

/// 首页按身份显示的区块：不适用的卡片不出现。
///
/// - 学生：今日练习 + 最近点评，学情速览；
/// - 任课老师：学情速览 + 待点评；
/// - 班主任：学情速览 + 今日待办（右栏仍是课程）；
/// - 管理员：没有个人课表，右栏换成今日待办，保留学情速览；
/// - 宿管：不看成绩、没有课表，右栏是今日待办，也不显示三科范画入口。
@immutable
class HomeSections {
  const HomeSections({
    this.subjects = true,
    this.courses = true,
    this.sideTodo = false,
    this.practice = false,
    this.studySnapshot = false,
    this.reviewQueue = false,
    this.todo = false,
  });

  /// 功能入口旁的三科范画入口。
  final bool subjects;

  /// 右栏为今日课程（有个人课表的身份）。
  final bool courses;

  /// 右栏为今日待办（宿管、管理员）。
  final bool sideTodo;

  /// 今日练习 + 最近点评（学生）。
  final bool practice;

  /// 学情速览（宿管不看成绩）。
  final bool studySnapshot;

  /// 学情速览右侧的待点评（任课老师）。
  final bool reviewQueue;

  /// 学情速览右侧的今日待办（班主任）。
  final bool todo;
}

/// 身份未知（`/myInfo` 未回包）时只保留各身份共有的区块，避免先闪出别的身份的卡片。
HomeSections homeSectionsFor(String role) => switch (homeRoleKind(role)) {
  'student' => const HomeSections(practice: true, studySnapshot: true),
  'teacher' => const HomeSections(studySnapshot: true, reviewQueue: true),
  'headTeacher' => const HomeSections(studySnapshot: true, todo: true),
  'admin' => const HomeSections(
    courses: false,
    sideTodo: true,
    studySnapshot: true,
  ),
  'dormManager' => const HomeSections(
    subjects: false,
    courses: false,
    sideTodo: true,
  ),
  _ => const HomeSections(),
};

/// 首页用的身份：优先 `/myInfo` 的 role；演示版回包前按登录 token 还原。
String resolveHomeRole(
  String role, {
  required String token,
  bool demoMode = kDemoMode,
}) {
  final value = role.trim();
  if (value.isNotEmpty) {
    return value;
  }
  if (!demoMode || token.trim().isEmpty) {
    return '';
  }
  return DemoAccounts.fromToken(token).roleKey;
}
