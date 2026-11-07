import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:flutter/material.dart';

import '../state/smart_campus_state.dart';

/// 身份标签：全应用统一用品牌色调的 AppTag（浅紫底深紫字），不再按身份配彩色。
///
/// 用于各端首页右侧栏与管理员「教师管理」卡片的身份标签。
({Color bg, Color fg}) smartCampusRoleTagStyle(SmartCampusRole role) =>
    (bg: AppTone.brand.background, fg: AppTone.brand.foreground);

SmartCampusRole smartCampusRoleFromLabel(String label) {
  if (label.contains('班主任')) {
    return SmartCampusRole.headTeacher;
  }
  if (label.contains('校长')) {
    return SmartCampusRole.principal;
  }
  if (label.contains('教务老师') || label.contains('管理员') || label.contains('管理')) {
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
