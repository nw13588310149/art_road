/// 任课老师端校级通知 API 数据模型与 JSON 解析。
library;

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
      tag: record.type.isNotEmpty ? record.type : '通知',
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

({Color foreground, Color background}) teacherNoticeTagStyle(String type) {
  return switch (type.trim()) {
    '督导' => (
        foreground: const Color(0xFF325BFF),
        background: const Color(0xFFE8EDFF),
      ),
    '活动' => (
        foreground: const Color(0xFFFF6A00),
        background: const Color(0xFFFFEDD3),
      ),
    '会议' => (
        foreground: const Color(0xFF0CAC40),
        background: const Color(0xFFE4FFED),
      ),
    '紧急' => (
        foreground: const Color(0xFFFF323C),
        background: const Color(0xFFFFE5E5),
      ),
    _ => (
        foreground: const Color(0xFF0B081A),
        background: const Color(0xFFEAE5FF),
      ),
  };
}

