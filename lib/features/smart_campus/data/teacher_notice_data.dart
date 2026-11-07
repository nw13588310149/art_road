/// 任课老师端校级通知 API 数据模型与 JSON 解析。
library;

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:flutter/material.dart';

import 'admin_notice_data.dart';

class TeacherNoticeListItem {
  const TeacherNoticeListItem({
    required this.id,
    required this.tag,
    required this.title,
    required this.time,
    required this.content,
    this.deptName = '',
    this.author = '',
    this.type = '',
    this.priority = '',
    this.scopeLabel = '',
    this.publishedAt = '',
  });

  final String id;
  final String tag;
  final String title;
  final String time;
  final String content;
  final String deptName;
  final String author;
  final String type;
  final String priority;
  final String scopeLabel;
  final String publishedAt;

  ({Color foreground, Color background}) get tagStyle =>
      teacherNoticeTagStyle(tag);

  /// 与管理员首页右侧通知列表一致的预览文案。
  String get previewText => formatNoticePreviewText(title, content);

  factory TeacherNoticeListItem.fromRecord(AdminNoticeRecord record) {
    final author = record.deptName.isNotEmpty
        ? '${record.deptName} · ${record.author}'
        : record.author;
    return TeacherNoticeListItem(
      id: record.id,
      // 「紧急」是优先级而不是类型：紧急通知在列表里显示「紧急」标签。
      tag: record.priority.label == '紧急'
          ? '紧急'
          : (record.type.isNotEmpty ? record.type : '通知'),
      title: record.title,
      time: record.time,
      content: record.content,
      deptName: record.deptName,
      author: author,
      type: record.type,
      priority: record.priority.label,
      scopeLabel: record.scopeLabel,
      publishedAt: record.time,
    );
  }
}

List<TeacherNoticeListItem> parseTeacherNoticeList(dynamic raw) {
  return parseAdminNoticeList(raw)
      .where((r) => r.status != AdminNoticeStatus.draft)
      .map(TeacherNoticeListItem.fromRecord)
      .toList(growable: false);
}

TeacherNoticeListItem? parseTeacherNoticeDetail(dynamic raw) {
  final record = parseAdminNoticeDetail(raw);
  return record == null ? null : TeacherNoticeListItem.fromRecord(record);
}

/// 通知类型标签：只有「紧急」用危险色，其余类型一律中性灰，不再按类型配彩色。
({Color foreground, Color background}) teacherNoticeTagStyle(String type) {
  final tone = type.trim() == '紧急' ? AppTone.danger : AppTone.neutral;
  return (foreground: tone.foreground, background: tone.background);
}
