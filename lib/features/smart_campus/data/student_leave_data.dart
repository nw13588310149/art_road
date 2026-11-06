/// 班主任端「学生请假审批」API 数据模型与 JSON 解析。
library;

import '../../../core/network/media_url.dart';

/// 家长尚未审批时，班主任同意默认填写的审批意见。
const String kHeadTeacherLeaveApproveReasonWithoutParent =
    '已和家长沟通获得允许，故同意请假';

/// 家长已同意后，班主任同意默认填写的审批意见。
const String kHeadTeacherLeaveApproveReasonDefault = '同意请假';

/// 班主任拒绝默认填写的审批意见。
const String kHeadTeacherLeaveRejectReasonDefault = '不予批准请假';

/// API `status`：0-待家长审批 / 1-家长同意 / 2-家长拒绝 / 3-老师同意 / 4-老师拒绝
enum StudentLeaveStatus {
  waitingParent(0, '待家长审批'),
  waitingTeacher(1, '待我审批'),
  parentRejected(2, '家长已拒绝'),
  approved(3, '已通过'),
  teacherRejected(4, '已拒绝');

  const StudentLeaveStatus(this.code, this.label);

  final int code;
  final String label;

  bool get canTeacherAudit =>
      this == StudentLeaveStatus.waitingTeacher ||
      this == StudentLeaveStatus.waitingParent;

  static StudentLeaveStatus? fromApi(dynamic raw) {
    final code = int.tryParse(raw?.toString() ?? '');
    if (code == null) return null;
    for (final s in StudentLeaveStatus.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

enum StudentLeaveStepStatus {
  pending('待审批'),
  approved('已通过'),
  rejected('已拒绝');

  const StudentLeaveStepStatus(this.label);
  final String label;
}

class StudentLeaveRecord {
  const StudentLeaveRecord({
    required this.id,
    required this.studentName,
    required this.studentNo,
    this.headUrl,
    required this.leaveType,
    required this.duration,
    required this.timeRange,
    required this.reason,
    required this.appliedAt,
    required this.path,
    required this.status,
    required this.parentStep,
    required this.headTeacherStep,
    required this.note,
  });

  final String id;
  final String studentName;
  final String studentNo;
  final String? headUrl;
  final String leaveType;
  final String duration;
  final String timeRange;
  final String reason;
  final String appliedAt;
  final String path;
  final StudentLeaveStatus status;
  final StudentLeaveStepStatus parentStep;
  final StudentLeaveStepStatus headTeacherStep;
  final String note;

  String get durationLabel {
    if (duration.isEmpty || duration == '—') return '—';
    if (duration.startsWith('时长')) return duration;
    return '时长$duration';
  }

  factory StudentLeaveRecord.fromJson(Map<String, dynamic> json) {
    final studentRaw = json['student'];
    final student = studentRaw is Map
        ? Map<String, dynamic>.from(studentRaw)
        : const <String, dynamic>{};

    final name = _pickString(student, ['realname', 'nickname'], '');
    final studentNo = _pickString(
      json,
      ['studentId'],
      _pickString(student, ['studentNo', 'stuNo', 'no', 'id'], ''),
    );
    final headUrlRaw = _pickString(student, ['headUrl', 'avatar', 'headImg'], '');
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

    final statusCode = int.tryParse(json['status']?.toString() ?? '') ?? 0;
    final status = StudentLeaveStatus.fromApi(statusCode) ??
        StudentLeaveStatus.waitingParent;

    final parentReason = _pickString(json, ['parentAuditReason'], '');
    final teacherReason = _pickString(json, ['teacherAuditReason'], '');
    final note = teacherReason.isNotEmpty
        ? teacherReason
        : (parentReason.isNotEmpty ? parentReason : '—');

    return StudentLeaveRecord(
      id: _pickString(json, ['id'], ''),
      studentName: name.isNotEmpty ? name : '未命名学生',
      studentNo: studentNo.isNotEmpty ? studentNo : '—',
      headUrl: headUrl.isEmpty ? null : headUrl,
      leaveType: leaveType,
      duration: _formatDuration(_pickString(json, ['leaveDuration'], '—')),
      timeRange: timeRange.isNotEmpty ? timeRange : '—',
      reason: _pickString(json, ['leaveReason'], '—'),
      appliedAt: _formatDateTime(json['createTime']),
      path: '家长小程序 → 班主任',
      status: status,
      parentStep: _parentStepFromStatus(statusCode),
      headTeacherStep: _headTeacherStepFromStatus(statusCode),
      note: note,
    );
  }
}

StudentLeaveStepStatus _parentStepFromStatus(int status) {
  return switch (status) {
    0 => StudentLeaveStepStatus.pending,
    1 || 3 || 4 => StudentLeaveStepStatus.approved,
    2 => StudentLeaveStepStatus.rejected,
    _ => StudentLeaveStepStatus.pending,
  };
}

StudentLeaveStepStatus _headTeacherStepFromStatus(int status) {
  return switch (status) {
    1 => StudentLeaveStepStatus.pending,
    3 => StudentLeaveStepStatus.approved,
    4 => StudentLeaveStepStatus.rejected,
    _ => StudentLeaveStepStatus.pending,
  };
}

/// API 提交 / 展示用时间格式：`yyyy-MM-dd HH:mm:ss`
String formatStudentLeaveDateTime(DateTime d) {
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

List<StudentLeaveRecord> parseStudentLeaveList(dynamic raw) {
  final rows = _extractRecordMaps(raw);
  final parsed = <StudentLeaveRecord>[];
  for (final m in rows) {
    final id = m['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    parsed.add(StudentLeaveRecord.fromJson(m));
  }
  return parsed;
}

StudentLeaveRecord? parseStudentLeaveDetail(dynamic raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    if (map['data'] is Map) {
      return StudentLeaveRecord.fromJson(
        Map<String, dynamic>.from(map['data'] as Map),
      );
    }
    if (map.containsKey('id')) {
      return StudentLeaveRecord.fromJson(map);
    }
  }
  return null;
}

/// UI 请假类型 → API `type`：0 病假 / 1 事假
int studentLeaveTypeToApi(String typeLabel) {
  return switch (typeLabel) {
    '病假' => 0,
    '事假' => 1,
    _ => 1,
  };
}

int? parseStudentLeaveTotal(dynamic raw) {
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

List<Map<String, dynamic>> _extractRecordMaps(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  if (raw is Map) {
    final m = Map<dynamic, dynamic>.from(raw);
    for (final key in ['records', 'list', 'rows']) {
      final v = m[key];
      if (v is List) {
        return [
          for (final item in v)
            if (item is Map) Map<String, dynamic>.from(item),
        ];
      }
    }
    final nested = m['data'];
    if (nested != null) {
      return _extractRecordMaps(nested);
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
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

/// 学生端「我的请假」审批中数量（待家长 / 待班主任审批）。
int parseStudentLeavePendingCount(dynamic raw) {
  final rows = parseStudentLeaveList(raw);
  return rows
      .where(
        (r) =>
            r.status == StudentLeaveStatus.waitingParent ||
            r.status == StudentLeaveStatus.waitingTeacher,
      )
      .length;
}
