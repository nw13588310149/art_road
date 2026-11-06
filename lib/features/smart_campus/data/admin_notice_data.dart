/// 管理员端「通知管理」API 数据模型与 JSON 解析。
library;

import '../../../core/network/snowflake_id.dart';

enum AdminNoticeStatus {
  draft(0, '草稿'),
  published(1, '已通过'),
  scheduled(2, '定时中'),
  withdrawn(3, '已撤回');

  const AdminNoticeStatus(this.code, this.label);

  final int code;
  final String label;

  static AdminNoticeStatus? fromApi(dynamic raw) {
    final code = int.tryParse(raw?.toString() ?? '');
    if (code == null) return null;
    for (final s in AdminNoticeStatus.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

enum AdminNoticePriority {
  normal('普通'),
  important('重要'),
  urgent('紧急');

  const AdminNoticePriority(this.label);
  final String label;

  static AdminNoticePriority fromApi(String raw) {
    final v = raw.trim();
    for (final p in AdminNoticePriority.values) {
      if (p.label == v) return p;
    }
    return AdminNoticePriority.normal;
  }
}

/// 推送范围：UI 中文 ↔ API 英文 key。
const Map<String, String> kAdminNoticeScopeLabelToApi = <String, String>{
  '学生': 'student',
  '教师': 'course_teacher',
  '班主任': 'head_teacher',
  '宿管': 'dormitory',
  '家长': 'parent',
};

const Map<String, String> kAdminNoticeScopeApiToLabel = <String, String>{
  'student': '学生',
  'course_teacher': '教师',
  'head_teacher': '班主任',
  'dormitory': '宿管',
  'parent': '家长',
};

const List<String> kAdminNoticeAllScopeApiKeys = <String>[
  'student',
  'course_teacher',
  'head_teacher',
  'dormitory',
  'parent',
];

/// 右侧通知列表预览文案：有正文时「标题：正文」，否则仅标题。
String formatNoticePreviewText(String title, String content) {
  final body = content.trim();
  if (body.isEmpty) return title;
  return '$title：$body';
}

class AdminNoticeRecord {
  const AdminNoticeRecord({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.deptName,
    required this.type,
    required this.priority,
    required this.scopes,
    required this.status,
    required this.time,
    this.scheduledAt,
    this.publishMode,
  });

  final String id;
  final String title;
  final String content;
  final String author;
  final String deptName;
  final String type;
  final AdminNoticePriority priority;
  final List<String> scopes;
  final AdminNoticeStatus status;
  final String time;
  final DateTime? scheduledAt;
  final int? publishMode;

  String get scopeLabel => scopes.isEmpty ? '—' : scopes.join('、');

  factory AdminNoticeRecord.fromJson(Map<String, dynamic> json) {
    final status =
        AdminNoticeStatus.fromApi(json['status']) ?? AdminNoticeStatus.draft;
    final publishMode = int.tryParse(json['publishMode']?.toString() ?? '');

    final publishedAt = _formatDateTime(json['publishedAt']);
    final scheduledRaw = _formatDateTime(json['scheduledTime']);
    final updateTime = _formatDateTime(json['updateTime']);
    final createTime = _formatDateTime(json['createTime']);

    final time = switch (status) {
      AdminNoticeStatus.published =>
        publishedAt.isNotEmpty ? publishedAt : createTime,
      AdminNoticeStatus.scheduled =>
        scheduledRaw.isNotEmpty ? scheduledRaw : createTime,
      AdminNoticeStatus.withdrawn =>
        updateTime.isNotEmpty ? updateTime : createTime,
      AdminNoticeStatus.draft =>
        updateTime.isNotEmpty ? updateTime : createTime,
    };

    DateTime? scheduledAt;
    final scheduledSource = json['scheduledTime'];
    if (scheduledSource != null) {
      scheduledAt = DateTime.tryParse(scheduledSource.toString())?.toLocal();
    }

    final creator = _pickString(json, ['creator'], '');
    final modifier = _pickString(json, ['modifier'], '');
    final author = creator.isNotEmpty
        ? creator
        : (modifier.isNotEmpty ? modifier : '—');

    return AdminNoticeRecord(
      id: readSnowflakeId(json['id']) ?? _pickString(json, ['id'], ''),
      title: _pickString(json, ['title'], '未命名通知'),
      content: _pickString(json, ['content'], ''),
      author: author,
      deptName: _pickString(json, ['deptName'], ''),
      type: _pickString(json, ['type'], '通知'),
      priority: AdminNoticePriority.fromApi(
        _pickString(json, ['priority'], '普通'),
      ),
      scopes: decodeAdminNoticeScopes(json['pushScope']),
      status: status,
      time: time.isNotEmpty ? time : '—',
      scheduledAt: scheduledAt,
      publishMode: publishMode,
    );
  }
}

class AdminNoticeSaveRequest {
  const AdminNoticeSaveRequest({
    required this.title,
    required this.content,
    required this.type,
    required this.priority,
    required this.scopes,
    required this.publishMode,
    this.scheduledAt,
    this.creator,
    this.deptName,
  });

  final String title;
  final String content;
  final String type;
  final AdminNoticePriority priority;
  final Set<String> scopes;
  final int publishMode;
  final DateTime? scheduledAt;
  final String? creator;
  final String? deptName;

  Map<String, dynamic> toJson() {
    final pushScope = encodeAdminNoticeScopes(scopes);
    return <String, dynamic>{
      'title': title,
      'content': content,
      'type': type,
      'priority': priority.label,
      'publishMode': publishMode,
      'pushScope': pushScope,
      if (creator != null && creator!.isNotEmpty) 'creator': creator,
      if (deptName != null && deptName!.isNotEmpty) 'deptName': deptName,
      if (publishMode == 2 && scheduledAt != null)
        'scheduledTime': formatAdminNoticeApiDateTime(scheduledAt!),
    };
  }
}

List<AdminNoticeRecord> parseAdminNoticeList(dynamic raw) {
  final rows = _extractRecordMaps(raw);
  final parsed = <AdminNoticeRecord>[];
  for (final m in rows) {
    final id = readSnowflakeId(m['id']) ?? m['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    parsed.add(AdminNoticeRecord.fromJson(m));
  }
  return parsed;
}

AdminNoticeRecord? parseAdminNoticeDetail(dynamic raw) {
  if (raw is! Map) return null;
  var m = Map<String, dynamic>.from(raw);
  if (m['data'] is Map) {
    m = Map<String, dynamic>.from(m['data'] as Map);
  }
  final id = readSnowflakeId(m['id']) ?? m['id']?.toString() ?? '';
  if (id.isEmpty) return null;
  return AdminNoticeRecord.fromJson(m);
}

List<String> decodeAdminNoticeScopes(dynamic raw) {
  if (raw == null) return const [];
  final text = raw.toString().trim();
  if (text.isEmpty) return const [];
  final labels = <String>[];
  for (final part in text.split(',')) {
    final key = part.trim();
    if (key.isEmpty) continue;
    final label = kAdminNoticeScopeApiToLabel[key];
    if (label != null && !labels.contains(label)) {
      labels.add(label);
    }
  }
  return labels;
}

String encodeAdminNoticeScopes(Set<String> scopes) {
  if (scopes.contains('全校师生')) {
    return kAdminNoticeAllScopeApiKeys.join(',');
  }
  final keys = <String>[];
  for (final label in scopes) {
    if (label == '访客端') continue;
    final api = kAdminNoticeScopeLabelToApi[label];
    if (api != null && !keys.contains(api)) {
      keys.add(api);
    }
  }
  return keys.join(',');
}

String formatAdminNoticeApiDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
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
