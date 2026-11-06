import 'package:flutter/material.dart';

import '../state/smart_campus_state.dart';

/// 智慧校园身份标签色（产品稿）。
///
/// 仅用于：① 各端首页右侧栏头像下方身份徽章；
/// ② 管理员「教师管理」卡片左下身份标签。
const Color kSmartCampusRoleTagFg = Color(0xFF0B081A);

const Color kSmartCampusPrincipalTagBg = Color(0xFFE2D1FF);
const Color kSmartCampusAdminTagBg = Color(0xFFCBF5F3);
const Color kSmartCampusHeadTeacherTagBg = Color(0xFFFFE7CC);
const Color kSmartCampusTeacherTagBg = Color(0xFFFFD9F6);
const Color kSmartCampusDormManagerTagBg = Color(0xFFD1EA65);

/// 学生端未出现在五身份色板中，沿用科目标签紫系。
const Color kSmartCampusStudentTagBg = Color(0xFFEAE5FF);
const Color kSmartCampusStudentTagFg = Color(0xFF8741FF);

/// 身份标签统一配色（设计稿：实色浅底 + 深色字）。
({Color bg, Color fg}) smartCampusRoleTagStyle(SmartCampusRole role) {
  switch (role) {
    case SmartCampusRole.principal:
      return (bg: kSmartCampusPrincipalTagBg, fg: kSmartCampusRoleTagFg);
    case SmartCampusRole.admin:
      return (bg: kSmartCampusAdminTagBg, fg: kSmartCampusRoleTagFg);
    case SmartCampusRole.headTeacher:
      return (bg: kSmartCampusHeadTeacherTagBg, fg: kSmartCampusRoleTagFg);
    case SmartCampusRole.teacher:
      return (bg: kSmartCampusTeacherTagBg, fg: kSmartCampusRoleTagFg);
    case SmartCampusRole.dormManager:
      return (bg: kSmartCampusDormManagerTagBg, fg: kSmartCampusRoleTagFg);
    case SmartCampusRole.student:
      return (bg: kSmartCampusStudentTagBg, fg: kSmartCampusStudentTagFg);
  }
}

SmartCampusRole smartCampusRoleFromLabel(String label) {
  if (label.contains('班主任')) {
    return SmartCampusRole.headTeacher;
  }
  if (label.contains('校长')) {
    return SmartCampusRole.principal;
  }
  if (label.contains('教务老师') ||
      label.contains('管理员') ||
      label.contains('管理')) {
    return SmartCampusRole.admin;
  }
  if (label.contains('宿管')) {
    return SmartCampusRole.dormManager;
  }
  if (label.contains('任课') || label.contains('教师') || label.contains('老师')) {
    return SmartCampusRole.teacher;
  }
  if (label.contains('学生')) {
    return SmartCampusRole.student;
  }
  return SmartCampusRole.teacher;
}

/// 教师管理页等中文身份标签 → 主题色。
({Color bg, Color fg}) smartCampusRoleTagColors(String label) =>
    smartCampusRoleTagStyle(smartCampusRoleFromLabel(label));
