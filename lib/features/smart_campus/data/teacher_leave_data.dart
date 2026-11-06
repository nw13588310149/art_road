/// 教师请假 API 数据模型与 JSON 解析。
///
/// 共用场景：
/// - 管理员端「教师请假审批」（`/manager/teacherLeaveList`）
/// - 任课老师 / 班主任「我的请假」（`/teacher/teacherLeaveList`）
///
/// 单条记录对应 `AppSchoolTeacherLeave`：`type`（0病假/1事假）、
/// `status`（0待审批/1已批准/2已拒绝）、`startTime` / `endTime` /
/// `leaveDuration` / `leaveReason` / `shiftHandover` / `auditReason` /
/// `auditTime` / `createTime` / 嵌套 `teacher`（`UserInfoRes`）。
library;

import '../../../core/network/media_url.dart';

enum TeacherLeaveStatus {
  pending(0, '待审批'),
  approved(1, '已通过'),
  rejected(2, '已拒绝');

  const TeacherLeaveStatus(this.code, this.label);

  final int code;
  final String label;

  static TeacherLeaveStatus? fromApi(dynamic raw) {
    final code = int.tryParse(raw?.toString() ?? '');
    if (code == null) return null;
    for (final s in TeacherLeaveStatus.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

class TeacherLeaveRecord {
  const TeacherLeaveRecord({
    required this.id,
    required this.teacherName,
    required this.teacherNo,
    this.headUrl,
    required this.contact,
    required this.leaveType,
    required this.duration,
    required this.timeRange,
    required this.reason,
    required this.appliedAt,
    required this.handoff,
    required this.status,
    this.auditReason,
    required this.auditTime,
  });

  final String id;
  final String teacherName;
  final String teacherNo;
  final String? headUrl;
  final String contact;
  final String leaveType;
  final String duration;
  final String timeRange;
  final String reason;
  final String appliedAt;
  final String handoff;
  final TeacherLeaveStatus status;
  final String? auditReason;
  final String auditTime;

  /// 卡片 header 展示：`时长2天`。
  String get durationLabel {
    if (duration.isEmpty || duration == '—') return '—';
    if (duration.startsWith('时长')) return duration;
    return '时长$duration';
  }

  factory TeacherLeaveRecord.fromJson(Map<String, dynamic> json) {
    final teacherRaw = json['teacher'];
    final teacher = teacherRaw is Map
        ? Map<String, dynamic>.from(teacherRaw)
        : const <String, dynamic>{};

    final name = _pickString(teacher, ['realname', 'nickname'], '');
    final teacherId = _pickString(
      json,
      ['teacherId'],
      _pickString(teacher, ['id'], ''),
    );
    final mobile = _pickString(teacher, ['mobile'], '');
    final headUrlRaw = _pickString(teacher, ['headUrl', 'avatar', 'headImg'], '');
    final headUrl = headUrlRaw.isNotEmpty ? MediaUrl.resolve(headUrlRaw) : '';

    final typeRaw = int.tryParse(json['type']?.toString() ?? '');
    final leaveType = switch (typeRaw) {
      1 => '事假',
      0 => '病假',
      _ => '请假',
    };

    final start = _formatDateTime(json['startTime']);
    final end = _formatDateTime(json['endTime']);
    final timeRange = start.isNotEmpty && end.isNotEmpty
        ? '$start - $end'
        : (start.isNotEmpty ? start : end);

    return TeacherLeaveRecord(
      id: _pickString(json, ['id'], ''),
      teacherName: name.isNotEmpty ? name : '未命名教师',
      teacherNo: teacherId.isNotEmpty ? teacherId : '—',
      headUrl: headUrl.isEmpty ? null : headUrl,
      contact: mobile.isNotEmpty ? mobile : '—',
      leaveType: leaveType,
      duration: _formatDuration(_pickString(json, ['leaveDuration'], '—')),
      timeRange: timeRange.isNotEmpty ? timeRange : '—',
      reason: _pickString(json, ['leaveReason'], '—'),
      appliedAt: _formatDateTime(json['createTime']),
      handoff: _pickString(json, ['shiftHandover'], '—'),
      status: TeacherLeaveStatus.fromApi(json['status']) ??
          TeacherLeaveStatus.pending,
      auditReason: () {
        final raw = _pickString(json, ['auditReason'], '');
        return raw.isEmpty ? null : raw;
      }(),
      auditTime: _formatDateTime(json['auditTime']),
    );
  }
}

List<TeacherLeaveRecord> parseTeacherLeaveList(dynamic raw) {
  final rows = _extractRecordMaps(raw);
  final parsed = <TeacherLeaveRecord>[];
  for (final m in rows) {
    final id = m['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    parsed.add(TeacherLeaveRecord.fromJson(m));
  }
  return parsed;
}

TeacherLeaveRecord? parseTeacherLeaveDetail(dynamic raw) {
  dynamic value = raw;
  if (value is Map && value['data'] is Map) value = value['data'];
  if (value is! Map) return null;
  final map = Map<String, dynamic>.from(value);
  if ((map['id']?.toString() ?? '').isEmpty) return null;
  return TeacherLeaveRecord.fromJson(map);
}

int? parseTeacherLeaveTotal(dynamic raw) {
  if (raw is! Map) return null;
  var m = raw.cast<String, dynamic>();
  if (m['data'] is Map) {
    m = Map<String, dynamic>.from(m['data'] as Map);
  }
  for (final key in ['total', 'totalCount', 'recordsTotal', 'count']) {
    final v = m[key];
    if (v == null) continue;
    if (v is int) return v;
    final n = int.tryParse(v.toString());
    if (n != null) return n;
  }
  return null;
}

/// 待审批本人请假条数（`status: 0` 列表的 `total` 或 `records` 长度）。
int parseTeacherLeavePendingCount(dynamic raw) {
  return parseTeacherLeaveTotal(raw) ??
      parseTeacherLeaveList(raw).length;
}

List<Map<String, dynamic>> _extractRecordMaps(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  if (raw is Map) {
    final m = raw.cast<String, dynamic>();
    if (m['records'] is List) {
      return [
        for (final item in m['records'] as List)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    if (m['data'] is Map) {
      return _extractRecordMaps(m['data']);
    }
    if (m['data'] is List) {
      return _extractRecordMaps(m['data']);
    }
  }
  return const [];
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return fallback;
}

String _formatDuration(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '—') return '—';
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(trimmed)) return '$trimmed天';
  if (trimmed.contains('天') ||
      trimmed.contains('小时') ||
      trimmed.contains('时') ||
      trimmed.contains('分钟')) {
    return trimmed;
  }
  return trimmed;
}

String _formatDateTime(dynamic raw) {
  if (raw == null) return '';
  final s = raw.toString().trim();
  if (s.isEmpty) return '';
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Tab → API `status`；`null` = 全部。
int? teacherLeaveStatusForTabIndex(int tabIndex) {
  return switch (tabIndex) {
    1 => 0,
    2 => 1,
    3 => 2,
    _ => null,
  };
}
