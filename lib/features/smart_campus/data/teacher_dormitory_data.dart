import '../../../core/network/snowflake_id.dart';
import 'head_teacher_index_data.dart';
import 'student_dormitory_data.dart' show DormitoryDetailField;

class TeacherDormitoryOverview {
  const TeacherDormitoryOverview({
    this.classId = '',
    this.className = '',
    this.enrolledDormCount = 0,
    this.pendingMakeupCount = 0,
    this.todayAbsentCount = 0,
    this.todayLateCount = 0,
    this.todayNormalCount = 0,
  });

  final String classId;
  final String className;
  final int enrolledDormCount;
  final int pendingMakeupCount;
  final int todayAbsentCount;
  final int todayLateCount;
  final int todayNormalCount;

  factory TeacherDormitoryOverview.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    return TeacherDormitoryOverview(
      classId: pickFirstSnowflakeId(map, ['classId', 'id']) ?? '',
      className: _pickString(map, ['className', 'name']),
      enrolledDormCount: _pickInt(map, ['enrolledDormCount', 'studentCount']),
      pendingMakeupCount: _pickInt(map, ['pendingMakeupCount']),
      todayAbsentCount: _pickInt(map, ['todayAbsentCount']),
      todayLateCount: _pickInt(map, ['todayLateCount']),
      todayNormalCount: _pickInt(map, ['todayNormalCount']),
    );
  }
}

class TeacherDormitoryStat {
  const TeacherDormitoryStat({
    this.studentCount = 0,
    this.normalCount = 0,
    this.lateCount = 0,
    this.absentCount = 0,
    this.makeupApprovedCount = 0,
  });

  final int studentCount;
  final int normalCount;
  final int lateCount;
  final int absentCount;
  final int makeupApprovedCount;

  factory TeacherDormitoryStat.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    return TeacherDormitoryStat(
      studentCount: _pickInt(map, ['studentCount']),
      normalCount: _pickInt(map, ['normalCount']),
      lateCount: _pickInt(map, ['lateCount']),
      absentCount: _pickInt(map, ['absentCount', 'notCheckedCount']),
      makeupApprovedCount: _pickInt(map, ['makeupApprovedCount']),
    );
  }
}

enum TeacherDormitoryStatus {
  normal,
  late,
  absent;

  static TeacherDormitoryStatus fromApi(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty || value == 'null') {
      return TeacherDormitoryStatus.absent;
    }
    return switch (value) {
      '正常' => TeacherDormitoryStatus.normal,
      '晚归' || '迟到' => TeacherDormitoryStatus.late,
      _ => TeacherDormitoryStatus.absent,
    };
  }
}

class TeacherDormitoryDynamicItem {
  const TeacherDormitoryDynamicItem({
    required this.studentId,
    required this.studentName,
    required this.studentNo,
    required this.avatarUrl,
    required this.dormName,
    required this.bedName,
    required this.checkDate,
    required this.checkTime,
    required this.status,
  });

  final String studentId;
  final String studentName;
  final String studentNo;
  final String avatarUrl;
  final String dormName;
  final String bedName;
  final String checkDate;
  final String checkTime;
  final TeacherDormitoryStatus status;

  factory TeacherDormitoryDynamicItem.fromJson(Map<String, dynamic> map) {
    return TeacherDormitoryDynamicItem(
      studentId: pickFirstSnowflakeId(map, ['studentId', 'userId']) ?? '',
      studentName: _pickStudentName(map),
      studentNo: _pickString(map, ['studentNo', 'no'], '--'),
      avatarUrl: _pickStudentHeadUrl(map),
      dormName: _dormName(map),
      bedName: _pickString(map, ['bedName', 'bedInfo']),
      checkDate: _pickString(map, ['checkDate']),
      checkTime: _clock(_pickString(map, ['checkTime'])),
      status: TeacherDormitoryStatus.fromApi(map['status']),
    );
  }
}

class TeacherDormitoryHistoryItem {
  const TeacherDormitoryHistoryItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentNo,
    required this.avatarUrl,
    required this.dormName,
    required this.checkDate,
    required this.checkTime,
    required this.status,
    required this.handleStatus,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String studentNo;
  final String avatarUrl;
  final String dormName;
  final String checkDate;
  final String checkTime;
  final TeacherDormitoryStatus status;
  final int handleStatus;

  bool get isMorning {
    final hour = int.tryParse(checkTime.split(':').first);
    return hour != null && hour < 12;
  }

  factory TeacherDormitoryHistoryItem.fromJson(Map<String, dynamic> map) {
    return TeacherDormitoryHistoryItem(
      id: pickFirstSnowflakeId(map, ['id']) ?? '',
      studentId: pickFirstSnowflakeId(map, ['userId', 'studentId']) ?? '',
      studentName: _pickStudentName(map),
      studentNo: _pickString(map, ['studentNo'], '--'),
      avatarUrl: _pickStudentHeadUrl(map),
      dormName: _dormName(map),
      checkDate: _pickString(map, ['checkDate']),
      checkTime: _clock(_pickString(map, ['checkTime'])),
      status: TeacherDormitoryStatus.fromApi(map['status']),
      handleStatus: _pickInt(map, ['handleStatus']),
    );
  }
}

class TeacherDormitoryMakeupItem {
  const TeacherDormitoryMakeupItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.avatarUrl,
    required this.checkDate,
    required this.checkType,
    required this.reason,
    required this.status,
    required this.statusText,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String avatarUrl;
  final String checkDate;
  final String checkType;
  final String reason;
  final int status;
  final String statusText;

  factory TeacherDormitoryMakeupItem.fromJson(Map<String, dynamic> map) {
    return TeacherDormitoryMakeupItem(
      id: pickFirstSnowflakeId(map, ['id']) ?? '',
      studentId: pickFirstSnowflakeId(map, ['userId', 'studentId']) ?? '',
      studentName: _pickStudentName(map),
      avatarUrl: _pickStudentHeadUrl(map),
      checkDate: _pickString(map, ['checkDate']),
      checkType: _pickString(map, ['checkType'], '补卡'),
      reason: _pickString(map, ['reason'], '未填写原因'),
      status: _pickInt(map, ['status']),
      statusText: _pickString(map, ['statusText']),
    );
  }
}

List<HeadTeacherClassItem> parseTeacherDormitoryClasses(dynamic raw) {
  return parseHeadTeacherIndexRes(raw).classList;
}

List<HeadTeacherClassItem> parseClassListItems(dynamic raw) {
  if (raw is Map && raw['data'] is List) {
    raw = raw['data'];
  } else if (raw is Map && raw['records'] is List) {
    raw = raw['records'];
  }
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => HeadTeacherClassItem.fromJson(Map<String, dynamic>.from(e)))
      .where((item) => item.classId.isNotEmpty)
      .toList(growable: false);
}

List<TeacherDormitoryDynamicItem> parseTeacherDormitoryDynamicList(
  dynamic raw,
) {
  return _unwrapList(
    raw,
  ).map(TeacherDormitoryDynamicItem.fromJson).toList(growable: false);
}

List<TeacherDormitoryHistoryItem> parseTeacherDormitoryHistoryList(
  dynamic raw,
) {
  return _unwrapList(
    raw,
  ).map(TeacherDormitoryHistoryItem.fromJson).toList(growable: false);
}

List<TeacherDormitoryMakeupItem> parseTeacherDormitoryMakeupList(dynamic raw) {
  return _unwrapList(
    raw,
  ).map(TeacherDormitoryMakeupItem.fromJson).toList(growable: false);
}

String teacherDormitoryIsoDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
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

/// 学生展示名：`studentName` / `realname` 优先，`studentNickname` 备用。
String _pickStudentName(
  Map<String, dynamic> map, [
  String fallback = '未命名学生',
]) {
  return _pickString(
    map,
    ['studentName', 'realname', 'studentNickname'],
    fallback,
  );
}

String _pickStudentHeadUrl(Map<String, dynamic> map) {
  final raw = _pickString(
    map,
    ['studentHeadUrl', 'headUrl', 'avatarUrl', 'avatar', 'headImg'],
  );
  if (raw.isNotEmpty) return raw;
  for (final key in ['user', 'student']) {
    final nested = _asMap(map[key]);
    if (nested == null) continue;
    final fromNested = _pickString(
      nested,
      ['headUrl', 'avatar', 'avatarUrl', 'headImg', 'studentHeadUrl'],
    );
    if (fromNested.isNotEmpty) return fromNested;
  }
  return '';
}

String _clock(String value) {
  if (value.isEmpty || value == '--') return '--';
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return value;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

List<DormitoryDetailField> parseTeacherDormitoryCheckDetailFields(dynamic raw) {
  final map = _unwrapMap(raw) ?? const <String, dynamic>{};
  final status = TeacherDormitoryStatus.fromApi(map['status']);
  final handleStatus = _pickInt(map, ['handleStatus']);
  return [
    DormitoryDetailField('学生姓名', _pickStudentName(map, '')),
    DormitoryDetailField('学生学号', _pickString(map, ['studentNo'], '--')),
    DormitoryDetailField('查寝日期', _pickString(map, ['checkDate'])),
    DormitoryDetailField('打卡时间', _clock(_pickString(map, ['checkTime']))),
    DormitoryDetailField('所在宿舍', _dormName(map)),
    DormitoryDetailField('查寝状态', _teacherStatusLabel(status)),
    if (handleStatus > 0)
      DormitoryDetailField('处理状态', '$handleStatus'),
    DormitoryDetailField('宿管备注', _pickString(map, ['remark', 'note'], '无')),
  ];
}

List<DormitoryDetailField> parseTeacherDormitoryMakeupDetailFields(dynamic raw) {
  final map = _unwrapMap(raw) ?? const <String, dynamic>{};
  final status = _pickInt(map, ['status']);
  return [
    DormitoryDetailField('学生姓名', _pickStudentName(map, '')),
    DormitoryDetailField('补卡场次', _pickString(map, ['checkType'], '补卡')),
    DormitoryDetailField('补卡日期', _pickString(map, ['checkDate'])),
    DormitoryDetailField('申请原因', _pickString(map, ['reason'], '未填写')),
    DormitoryDetailField(
      '审批状态',
      _pickString(map, ['statusText'], _teacherMakeupStatusLabel(status)),
    ),
    DormitoryDetailField('审批意见', _pickString(map, ['auditReason'])),
  ];
}

String _teacherStatusLabel(TeacherDormitoryStatus status) {
  return switch (status) {
    TeacherDormitoryStatus.normal => '正常',
    TeacherDormitoryStatus.late => '晚归',
    TeacherDormitoryStatus.absent => '未归',
  };
}

String _teacherMakeupStatusLabel(int status) {
  return switch (status) {
    0 => '待审批',
    1 => '已通过',
    2 => '已驳回',
    _ => '未知',
  };
}
