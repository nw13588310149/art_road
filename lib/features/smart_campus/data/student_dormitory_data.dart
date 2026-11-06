import '../../../core/network/snowflake_id.dart';

class DormitoryDetailField {
  const DormitoryDetailField(this.label, this.value);

  final String label;
  final String value;
}

/// 查寝 / 补卡详情弹窗顶部的学生摘要（头像 + 姓名 + 副标题）。
class DormitoryDetailStudentProfile {
  const DormitoryDetailStudentProfile({
    required this.name,
    this.avatarUrl = '',
    this.subtitle = '',
  });

  final String name;
  final String avatarUrl;
  final String subtitle;
}

class StudentDormitoryInfo {
  const StudentDormitoryInfo({
    this.buildingName = '',
    this.floorName = '',
    this.roomName = '',
    this.bedName = '',
  });

  final String buildingName;
  final String floorName;
  final String roomName;
  final String bedName;

  String get displayLabel {
    if (roomName.isEmpty && bedName.isEmpty) return '未分配宿舍';
    if (roomName.isEmpty) return bedName;
    if (bedName.isEmpty) return roomName;
    return '$roomName-$bedName';
  }

  factory StudentDormitoryInfo.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    return StudentDormitoryInfo(
      buildingName: _pickString(map, ['buildingName']),
      floorName: _pickString(map, ['floorName']),
      roomName: _pickString(map, ['roomName']),
      bedName: _pickString(map, ['bedName', 'bedInfo']),
    );
  }
}

class StudentDormitoryStat {
  const StudentDormitoryStat({
    this.normalCount = 0,
    this.lateCount = 0,
    this.absentCount = 0,
    this.pendingMakeupCount = 0,
  });

  final int normalCount;
  final int lateCount;
  final int absentCount;
  final int pendingMakeupCount;

  static const zero = StudentDormitoryStat();

  factory StudentDormitoryStat.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    return StudentDormitoryStat(
      normalCount: _pickInt(map, ['normalCount']),
      lateCount: _pickInt(map, ['lateCount']),
      absentCount: _pickInt(map, ['absentCount', 'notCheckedCount']),
      pendingMakeupCount: _pickInt(map, ['pendingMakeupCount']),
    );
  }
}

enum StudentDormitoryCheckStatus {
  normal,
  late,
  absent;

  static StudentDormitoryCheckStatus fromApi(dynamic raw) {
    return switch (raw?.toString().trim()) {
      '正常' || '已打卡' => StudentDormitoryCheckStatus.normal,
      '晚归' || '迟到' => StudentDormitoryCheckStatus.late,
      _ => StudentDormitoryCheckStatus.absent,
    };
  }

  String get apiValue => switch (this) {
    StudentDormitoryCheckStatus.normal => '正常',
    StudentDormitoryCheckStatus.late => '晚归',
    StudentDormitoryCheckStatus.absent => '未打卡',
  };
}

class StudentDormitoryCheckItem {
  const StudentDormitoryCheckItem({
    required this.id,
    required this.checkDate,
    required this.checkType,
    required this.dormName,
    required this.deadline,
    required this.checkTime,
    required this.remark,
    required this.status,
    required this.handleStatus,
  });

  final String id;
  final String checkDate;
  final String checkType;
  final String dormName;
  final String deadline;
  final String checkTime;
  final String remark;
  final StudentDormitoryCheckStatus status;
  final int handleStatus;

  bool get isAbnormal =>
      status == StudentDormitoryCheckStatus.late ||
      status == StudentDormitoryCheckStatus.absent;

  factory StudentDormitoryCheckItem.fromJson(Map<String, dynamic> map) {
    return StudentDormitoryCheckItem(
      id: pickFirstSnowflakeId(map, ['id']) ?? '',
      checkDate: _pickString(map, ['checkDate', 'date']),
      checkType: _pickString(map, ['checkType', 'scene'], '查寝'),
      dormName: _dormName(map),
      deadline: _pickString(map, ['checkDeadline', 'deadline', 'requiredTime']),
      checkTime: _clock(_pickString(map, ['checkTime', 'stampTime'])),
      remark: _pickString(map, ['remark', 'note'], '无'),
      status: StudentDormitoryCheckStatus.fromApi(map['status']),
      handleStatus: _pickInt(map, ['handleStatus']),
    );
  }
}

class StudentDormitoryMakeupItem {
  const StudentDormitoryMakeupItem({
    required this.id,
    required this.checkDate,
    required this.checkType,
    required this.reason,
    required this.status,
    required this.statusText,
  });

  final String id;
  final String checkDate;
  final String checkType;
  final String reason;
  final int status;
  final String statusText;

  bool get canCancel => status == 0;

  factory StudentDormitoryMakeupItem.fromJson(Map<String, dynamic> map) {
    return StudentDormitoryMakeupItem(
      id: pickFirstSnowflakeId(map, ['id']) ?? '',
      checkDate: _pickString(map, ['checkDate', 'date']),
      checkType: _pickString(map, ['checkType', 'scene'], '补卡'),
      reason: _pickString(map, ['reason'], '未填写原因'),
      status: _pickInt(map, ['status']),
      statusText: _pickString(map, ['statusText']),
    );
  }
}

List<StudentDormitoryCheckItem> parseStudentDormitoryCheckHistory(dynamic raw) {
  return _unwrapList(raw)
      .map(StudentDormitoryCheckItem.fromJson)
      .toList(growable: false);
}

List<StudentDormitoryMakeupItem> parseStudentDormitoryMakeupList(dynamic raw) {
  return _unwrapList(raw)
      .map(StudentDormitoryMakeupItem.fromJson)
      .toList(growable: false);
}

String studentDormitoryIsoDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String studentDormitoryMakeupSceneApi(String sceneLabel) {
  final value = sceneLabel.trim();
  if (value.contains('晨')) return '晨查寝';
  if (value.contains('晚')) return '晚查寝';
  return value.isEmpty ? '晚查寝' : value;
}

List<DormitoryDetailField> parseStudentDormitoryCheckDetailFields(dynamic raw) {
  final map = _unwrapMap(raw) ?? const <String, dynamic>{};
  final status = map['status']?.toString().trim() ?? '';
  final handleStatus = _pickInt(map, ['handleStatus']);
  return [
    DormitoryDetailField('查寝场次', _pickString(map, ['checkType', 'scene'], '查寝')),
    DormitoryDetailField('查寝日期', _pickString(map, ['checkDate', 'date'])),
    DormitoryDetailField('学生宿舍', _dormName(map)),
    DormitoryDetailField('规定时间', _pickString(map, ['checkDeadline', 'deadline'])),
    DormitoryDetailField('打卡时间', _clock(_pickString(map, ['checkTime', 'stampTime']))),
    DormitoryDetailField('查寝状态', status.isEmpty ? '—' : status),
    DormitoryDetailField('查寝备注', _pickString(map, ['remark', 'note'], '无')),
    if (handleStatus > 0)
      DormitoryDetailField('处理状态', _pickString(map, ['handleStatusText'], '$handleStatus')),
    DormitoryDetailField(
      '处理说明',
      _pickString(map, ['handleRemark', 'handleReason']),
    ),
  ];
}

List<DormitoryDetailField> parseStudentDormitoryMakeupDetailFields(dynamic raw) {
  final map = _unwrapMap(raw) ?? const <String, dynamic>{};
  return [
    DormitoryDetailField('补卡场次', _pickString(map, ['checkType', 'scene'], '补卡')),
    DormitoryDetailField('补卡日期', _pickString(map, ['checkDate', 'date'])),
    DormitoryDetailField('申请原因', _pickString(map, ['reason'], '未填写')),
    DormitoryDetailField(
      '审批状态',
      _pickString(map, ['statusText'], _makeupStatusLabel(_pickInt(map, ['status']))),
    ),
    DormitoryDetailField('审批意见', _pickString(map, ['auditReason', 'auditRemark'])),
    DormitoryDetailField('申请时间', _pickString(map, ['createTime', 'applyTime'])),
    DormitoryDetailField('审批时间', _pickString(map, ['auditTime', 'updateTime'])),
  ];
}

String _makeupStatusLabel(int status) {
  return switch (status) {
    0 => '待审批',
    1 => '已通过',
    2 => '已驳回',
    _ => '未知',
  };
}

String _dormName(Map<String, dynamic> map) {
  return [
    _pickString(map, ['buildingName']),
    _pickString(map, ['floorName']),
    _pickString(map, ['roomName']),
  ].where((value) => value.isNotEmpty).join(' ');
}

Map<String, dynamic>? _unwrapMap(dynamic raw) {
  final map = _asMap(raw);
  if (map == null) return null;
  for (final key in ['data', 'result', 'record']) {
    final nested = _asMap(map[key]);
    if (nested != null) return nested;
  }
  return map;
}

List<Map<String, dynamic>> _unwrapList(dynamic raw) {
  if (raw is List) {
    return raw.map(_asMap).whereType<Map<String, dynamic>>().toList();
  }
  final map = _asMap(raw);
  if (map == null) return const [];
  for (final key in ['records', 'list', 'rows', 'data']) {
    final value = map[key];
    if (value is List) {
      return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
    }
    final nested = _asMap(value);
    if (nested != null) {
      final list = _unwrapList(nested);
      if (list.isNotEmpty) return list;
    }
  }
  return const [];
}

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

int _pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = int.tryParse(map[key]?.toString() ?? '');
    if (value != null) return value;
  }
  return 0;
}

String _pickString(
  Map<String, dynamic> map,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

String _clock(String value) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return value.isEmpty ? '—' : value;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}
