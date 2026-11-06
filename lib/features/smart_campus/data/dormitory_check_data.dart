/// 宿管端「按宿舍查寝」API 数据模型与 JSON 解析。
library;

import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';
import '../../school/data/school_config_data.dart';
import 'student_dormitory_data.dart' show DormitoryDetailField;

class DormitoryCheckStat {
  const DormitoryCheckStat({
    required this.bedCount,
    required this.normalCount,
    required this.lateCount,
    required this.notCheckedCount,
  });

  final int bedCount;
  final int normalCount;
  final int lateCount;
  final int notCheckedCount;

  static const zero = DormitoryCheckStat(
    bedCount: 0,
    normalCount: 0,
    lateCount: 0,
    notCheckedCount: 0,
  );
}

class DormitoryBuildingOption {
  const DormitoryBuildingOption({
    required this.id,
    required this.label,
    this.roomCount = 0,
    this.assignedBedCount = 0,
  });

  final String id;
  final String label;
  final int roomCount;
  final int assignedBedCount;

  static const all = DormitoryBuildingOption(id: '', label: '全部宿舍楼');
}

class DormitoryFloorOption {
  const DormitoryFloorOption({
    required this.id,
    required this.label,
    this.roomCount = 0,
    this.assignedBedCount = 0,
  });

  final String id;
  final String label;
  final int roomCount;
  final int assignedBedCount;

  static const all = DormitoryFloorOption(id: '', label: '全部楼层');
}

enum DormitoryStudentCheckStatus {
  unchecked('未打卡'),
  normal('正常'),
  lateReturn('晚归'),
  absent('缺勤');

  const DormitoryStudentCheckStatus(this.apiValue);
  final String apiValue;

  static DormitoryStudentCheckStatus fromApi(String raw) {
    final v = raw.trim();
    if (v == '正常' || v == '已打卡') {
      return DormitoryStudentCheckStatus.normal;
    }
    if (v == '晚归') return DormitoryStudentCheckStatus.lateReturn;
    if (v == '缺勤') return DormitoryStudentCheckStatus.absent;
    return DormitoryStudentCheckStatus.unchecked;
  }
}

class DormitoryRoomStudent {
  const DormitoryRoomStudent({
    required this.userId,
    required this.name,
    required this.studentNo,
    required this.bedName,
    required this.avatarUrl,
    required this.status,
  });

  final String userId;
  final String name;
  final String studentNo;
  final String bedName;
  final String avatarUrl;
  final DormitoryStudentCheckStatus status;
}

class DormitoryRoomCheck {
  const DormitoryRoomCheck({
    required this.roomId,
    required this.roomName,
    required this.buildingDesc,
    required this.session,
    required this.deadline,
    required this.allChecked,
    required this.students,
  });

  final String roomId;
  final String roomName;
  final String buildingDesc;
  final String session;
  final String deadline;
  final bool allChecked;
  final List<DormitoryRoomStudent> students;
}

DormitoryCheckStat parseDormitoryCheckStat(dynamic raw) {
  if (raw is! Map) return DormitoryCheckStat.zero;
  var m = Map<String, dynamic>.from(raw);
  if (m['data'] is Map) {
    m = Map<String, dynamic>.from(m['data'] as Map);
  }
  return DormitoryCheckStat(
    bedCount: _asInt(m['bedCount']) ?? 0,
    normalCount: _asInt(m['normalCount']) ?? 0,
    lateCount: _asInt(m['lateCount']) ?? 0,
    notCheckedCount: _asInt(m['notCheckedCount']) ?? 0,
  );
}

List<DormitoryBuildingOption> parseDormitoryManagedBuildingList(dynamic raw) {
  final rows = _coerceList(raw);
  final parsed = <DormitoryBuildingOption>[DormitoryBuildingOption.all];
  for (final m in rows) {
    final id =
        readSnowflakeId(m['buildingId']) ?? m['buildingId']?.toString() ?? '';
    if (id.isEmpty) continue;
    parsed.add(
      DormitoryBuildingOption(
        id: id,
        label: _pickString(m, ['buildingName'], '未命名宿舍楼'),
        roomCount: _asInt(m['roomCount']) ?? 0,
        assignedBedCount: _asInt(m['assignedBedCount']) ?? 0,
      ),
    );
  }
  return parsed;
}

List<DormitoryFloorOption> parseDormitoryFloorList(dynamic raw) {
  final rows = _coerceList(raw);
  final parsed = <DormitoryFloorOption>[DormitoryFloorOption.all];
  for (final m in rows) {
    final id = readSnowflakeId(m['floorId']) ?? m['floorId']?.toString() ?? '';
    if (id.isEmpty) continue;
    parsed.add(
      DormitoryFloorOption(
        id: id,
        label: _pickString(m, ['floorName'], '未命名楼层'),
        roomCount: _asInt(m['roomCount']) ?? 0,
        assignedBedCount: _asInt(m['assignedBedCount']) ?? 0,
      ),
    );
  }
  return parsed;
}

List<DormitoryRoomCheck> parseDormitoryCheckRoomList(dynamic raw) {
  final rows = _coerceList(raw);
  final parsed = <DormitoryRoomCheck>[];
  for (final m in rows) {
    final roomId =
        readSnowflakeId(m['roomId']) ?? m['roomId']?.toString() ?? '';
    if (roomId.isEmpty) continue;
    final buildingName = _pickString(m, ['buildingName'], '');
    final floorName = _pickString(m, ['floorName'], '');
    final buildingDesc = [
      if (buildingName.isNotEmpty) buildingName,
      if (floorName.isNotEmpty) floorName,
    ].join('·');
    final students = _parseUserList(m['userList']);
    parsed.add(
      DormitoryRoomCheck(
        roomId: roomId,
        roomName: _pickString(m, ['roomName'], '宿舍'),
        buildingDesc: buildingDesc.isEmpty ? '—' : buildingDesc,
        session: _pickString(m, ['checkType'], '查寝'),
        deadline: _pickString(m, ['checkDeadline'], '—'),
        allChecked:
            m['allChecked'] == true ||
            m['allChecked']?.toString() == 'true' ||
            m['allChecked'] == 1,
        students: students,
      ),
    );
  }
  return parsed;
}

List<DormitoryRoomStudent> _parseUserList(dynamic raw) {
  if (raw is! List) return const [];
  final parsed = <DormitoryRoomStudent>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final userId =
        readSnowflakeId(m['userId']) ??
        readSnowflakeId(m['studentId']) ??
        m['userId']?.toString() ??
        m['studentId']?.toString() ??
        '';
    if (userId.isEmpty) continue;
    final rawAvatar = _pickString(
      m,
      ['studentHeadUrl', 'headUrl', 'avatar'],
      '',
    );
    parsed.add(
      DormitoryRoomStudent(
        userId: userId,
        name: _pickString(m, [
          'realname',
          'nickname',
          'studentName',
          'name',
          'userName',
        ], '未命名'),
        studentNo: _pickString(m, ['studentNo', 'userNo'], '—'),
        bedName: _pickString(m, ['bedName', 'bedInfo'], '—'),
        avatarUrl: rawAvatar.isNotEmpty ? MediaUrl.resolve(rawAvatar) : '',
        status: DormitoryStudentCheckStatus.fromApi(
          _pickString(m, ['status', 'checkStatus'], '未打卡'),
        ),
      ),
    );
  }
  return parsed;
}

List<Map<String, dynamic>> _coerceList(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  if (raw is Map) {
    final m = raw.cast<String, dynamic>();
    if (m['records'] is List) return _coerceList(m['records']);
    if (m['data'] is List) return _coerceList(m['data']);
    if (m['data'] is Map) return _coerceList(m['data']);
  }
  return const [];
}

int parseDormitoryHistoryTotal(dynamic raw) {
  if (raw is! Map) return 0;
  var map = raw.cast<String, dynamic>();
  if (map['data'] is Map) {
    map = Map<String, dynamic>.from(map['data'] as Map);
  }
  return _asInt(map['total']) ?? _coerceList(raw).length;
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

int? _asInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

String dormitoryCheckDateParam([DateTime? date]) {
  final d = date ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

class DormitoryIndexOverview {
  const DormitoryIndexOverview({
    this.managedBuildingCount = 0,
    this.bedCount = 0,
    this.todayNormalCount = 0,
    this.todayLateCount = 0,
    this.todayAbsentCount = 0,
    this.pendingMakeupCount = 0,
    this.unclosedExceptionCount = 0,
    this.managedAreas = const [],
    this.currentTask,
    this.todayDutyTasks = const [],
  });

  final int managedBuildingCount;
  final int bedCount;
  final int todayNormalCount;
  final int todayLateCount;
  final int todayAbsentCount;
  final int pendingMakeupCount;
  final int unclosedExceptionCount;
  final List<String> managedAreas;
  final DormitoryDutyTask? currentTask;
  final List<DormitoryDutyTask> todayDutyTasks;

  static const zero = DormitoryIndexOverview();

  DormitoryIndexOverview copyWith({
    int? managedBuildingCount,
    int? bedCount,
    int? todayNormalCount,
    int? todayLateCount,
    int? todayAbsentCount,
    int? pendingMakeupCount,
    int? unclosedExceptionCount,
    List<String>? managedAreas,
    DormitoryDutyTask? currentTask,
    List<DormitoryDutyTask>? todayDutyTasks,
  }) {
    return DormitoryIndexOverview(
      managedBuildingCount: managedBuildingCount ?? this.managedBuildingCount,
      bedCount: bedCount ?? this.bedCount,
      todayNormalCount: todayNormalCount ?? this.todayNormalCount,
      todayLateCount: todayLateCount ?? this.todayLateCount,
      todayAbsentCount: todayAbsentCount ?? this.todayAbsentCount,
      pendingMakeupCount: pendingMakeupCount ?? this.pendingMakeupCount,
      unclosedExceptionCount:
          unclosedExceptionCount ?? this.unclosedExceptionCount,
      managedAreas: managedAreas ?? this.managedAreas,
      currentTask: currentTask ?? this.currentTask,
      todayDutyTasks: todayDutyTasks ?? this.todayDutyTasks,
    );
  }
}

class DormitoryDutyTask {
  const DormitoryDutyTask({
    required this.tag,
    required this.title,
    required this.timeFrom,
    required this.timeTo,
  });

  final String tag;
  final String title;
  final String timeFrom;
  final String timeTo;

  factory DormitoryDutyTask.fromJson(Map<String, dynamic> map) {
    return DormitoryDutyTask(
      tag: _pickString(map, ['checkType', 'tag', 'type'], '查寝'),
      title: _pickString(map, ['title', 'taskName', 'name'], '查寝任务'),
      timeFrom: _clock(
        _pickString(map, ['timeFrom', 'beginTime', 'startTime']),
      ),
      timeTo: _clock(_pickString(map, ['timeTo', 'endTime', 'finishTime'])),
    );
  }
}

class DormitoryCheckHistoryItem {
  const DormitoryCheckHistoryItem({
    required this.id,
    required this.userId,
    required this.studentName,
    required this.studentNo,
    required this.dormName,
    required this.bedName,
    required this.checkDate,
    required this.checkType,
    required this.deadline,
    required this.checkTime,
    required this.status,
    required this.statusLabel,
    required this.remark,
    required this.handleStatus,
    this.avatarUrl = '',
    this.mobile = '',
    this.gender = '',
  });

  final String id;
  final String userId;
  final String studentName;
  final String studentNo;
  final String dormName;
  final String bedName;
  final String checkDate;
  final String checkType;
  final String deadline;
  final String checkTime;
  final DormitoryStudentCheckStatus status;
  final String statusLabel;
  final String remark;
  final int handleStatus;
  final String avatarUrl;
  final String mobile;
  final String gender;

  String get bedLabel => _formatBedLabel(bedName);

  String get studentSubtitle {
    if (studentNo.isNotEmpty && studentNo != '—') return studentNo;
    if (mobile.isNotEmpty) return mobile;
    if (gender.isNotEmpty) return gender;
    return '';
  }

  String get locationLabel {
    final parts = <String>[
      if (dormName.isNotEmpty) dormName,
      if (bedName.isNotEmpty) bedLabel,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  bool get needsExceptionHandle =>
      status != DormitoryStudentCheckStatus.normal && handleStatus == 0;

  factory DormitoryCheckHistoryItem.fromJson(Map<String, dynamic> map) {
    final user = _pickNestedUserMap(map);
    final bedName = _pickString(map, ['bedName', 'bedInfo']);
    final statusLabel = _pickString(map, ['status', 'checkStatus'], '未打卡');
    return DormitoryCheckHistoryItem(
      id: readSnowflakeId(map['id']) ?? map['id']?.toString() ?? '',
      userId:
          readSnowflakeId(map['userId']) ??
          readSnowflakeId(map['studentId']) ??
          readSnowflakeId(user['id']) ??
          map['userId']?.toString() ??
          '',
      studentName: _historyStudentName(map, bedName: bedName),
      studentNo: _historyStudentNo(map, user),
      dormName: _historyDormName(map),
      bedName: bedName,
      checkDate: _pickString(map, ['checkDate', 'date']),
      checkType: _pickString(map, ['checkType', 'scene']),
      deadline: _pickString(map, [
        'checkDeadline',
        'deadline',
        'requiredTime',
      ]),
      checkTime: _historyClock(_pickString(map, ['checkTime', 'stampTime'])),
      status: DormitoryStudentCheckStatus.fromApi(statusLabel),
      statusLabel: statusLabel,
      remark: _pickString(map, ['anomalyReason', 'remark', 'note']),
      handleStatus: _asInt(map['handleStatus']) ?? 0,
      avatarUrl: _historyAvatarUrl(map, user),
      mobile: _pickString(user, ['mobile', 'phone']),
      gender: _pickString(user, ['gender', 'sex']),
    );
  }
}

class DormitoryMakeupItem {
  const DormitoryMakeupItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.checkDate,
    required this.checkType,
    required this.reason,
    required this.status,
    required this.statusText,
    required this.dormName,
    required this.createTime,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String checkDate;
  final String checkType;
  final String reason;
  final int status;
  final String statusText;
  final String dormName;
  final String createTime;

  factory DormitoryMakeupItem.fromJson(Map<String, dynamic> map) {
    return DormitoryMakeupItem(
      id: readSnowflakeId(map['id']) ?? map['id']?.toString() ?? '',
      studentId:
          readSnowflakeId(map['userId']) ??
          readSnowflakeId(map['studentId']) ??
          '',
      studentName: _pickString(map, ['studentName', 'realname'], '未命名学生'),
      checkDate: _pickString(map, ['checkDate', 'date']),
      checkType: _pickString(map, ['checkType', 'scene'], '补卡'),
      reason: _pickString(map, ['reason'], '未填写原因'),
      status: _asInt(map['status']) ?? 0,
      statusText: _pickString(map, ['statusText']),
      dormName: _historyDormName(map),
      createTime: _pickString(map, ['createTime', 'applyTime']),
    );
  }
}

DormitoryIndexOverview parseDormitoryIndexOverview(dynamic raw) {
  if (raw is! Map) return DormitoryIndexOverview.zero;
  var map = Map<String, dynamic>.from(raw);
  if (map['data'] is Map) {
    map = Map<String, dynamic>.from(map['data'] as Map);
  }
  final areas = <String>[];
  final areaRaw = map['managedAreaList'] ?? map['buildingList'] ?? map['areas'];
  if (areaRaw is List) {
    for (final item in areaRaw) {
      if (item is Map) {
        final name = _pickString(Map<String, dynamic>.from(item), [
          'buildingName',
          'name',
          'areaName',
        ]);
        if (name.isNotEmpty) areas.add(name);
      } else {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) areas.add(text);
      }
    }
  } else {
    final areaText = _pickString(map, ['managedArea', 'areaDesc']);
    if (areaText.isNotEmpty) {
      areas.addAll(areaText.split(RegExp(r'[、,，;；\n]')));
    }
  }
  DormitoryDutyTask? currentTask;
  final currentRaw = map['currentTask'] ?? map['currentItem'];
  if (currentRaw is Map) {
    currentTask = DormitoryDutyTask.fromJson(
      Map<String, dynamic>.from(currentRaw),
    );
  }
  final dutyTasks = <DormitoryDutyTask>[];
  for (final item in _coerceList(map['todayDutyList'] ?? map['dutyList'])) {
    dutyTasks.add(DormitoryDutyTask.fromJson(item));
  }
  return DormitoryIndexOverview(
    managedBuildingCount:
        _asInt(map['managedBuildingCount']) ??
        _asInt(map['buildingCount']) ??
        0,
    bedCount: _asInt(map['totalBedCount']) ?? _asInt(map['bedCount']) ?? 0,
    todayNormalCount:
        _asInt(map['todayNormalCount']) ?? _asInt(map['normalCount']) ?? 0,
    todayLateCount:
        _asInt(map['todayLateCount']) ?? _asInt(map['lateCount']) ?? 0,
    todayAbsentCount:
        _asInt(map['todayAbsentCount']) ??
        _asInt(map['notCheckedCount']) ??
        _asInt(map['absentCount']) ??
        0,
    pendingMakeupCount: _asInt(map['pendingMakeupCount']) ?? 0,
    unclosedExceptionCount:
        _asInt(map['unhandledExceptionCount']) ??
        _asInt(map['unclosedExceptionCount']) ??
        _asInt(map['exceptionCount']) ??
        0,
    managedAreas: areas.where((v) => v.trim().isNotEmpty).toList(),
    currentTask: currentTask,
    todayDutyTasks: dutyTasks,
  );
}

List<DormitoryCheckHistoryItem> parseDormitoryCheckHistoryList(dynamic raw) {
  return _coerceList(
    raw,
  ).map(DormitoryCheckHistoryItem.fromJson).toList(growable: false);
}

DormitoryCheckStat calculateDormitoryHistoryStat(
  List<DormitoryCheckHistoryItem> items,
) {
  var normalCount = 0;
  var lateCount = 0;
  var notCheckedCount = 0;
  for (final item in items) {
    switch (item.status) {
      case DormitoryStudentCheckStatus.normal:
        normalCount++;
      case DormitoryStudentCheckStatus.lateReturn:
        lateCount++;
      case DormitoryStudentCheckStatus.unchecked:
      case DormitoryStudentCheckStatus.absent:
        notCheckedCount++;
    }
  }
  return DormitoryCheckStat(
    bedCount: items.length,
    normalCount: normalCount,
    lateCount: lateCount,
    notCheckedCount: notCheckedCount,
  );
}

DormitoryCheckStat calculateDormitoryRoomStat(List<DormitoryRoomCheck> rooms) {
  var normalCount = 0;
  var lateCount = 0;
  var notCheckedCount = 0;
  for (final room in rooms) {
    for (final student in room.students) {
      switch (student.status) {
        case DormitoryStudentCheckStatus.normal:
          normalCount++;
        case DormitoryStudentCheckStatus.lateReturn:
          lateCount++;
        case DormitoryStudentCheckStatus.unchecked:
        case DormitoryStudentCheckStatus.absent:
          notCheckedCount++;
      }
    }
  }
  return DormitoryCheckStat(
    bedCount: normalCount + lateCount + notCheckedCount,
    normalCount: normalCount,
    lateCount: lateCount,
    notCheckedCount: notCheckedCount,
  );
}

List<DormitoryMakeupItem> parseDormitoryMakeupList(dynamic raw) {
  return _coerceList(
    raw,
  ).map(DormitoryMakeupItem.fromJson).toList(growable: false);
}

String _historyDormName(Map<String, dynamic> map) {
  return [
    _pickString(map, ['buildingName']),
    _pickString(map, ['floorName']),
    _pickString(map, ['roomName']),
  ].where((value) => value.isNotEmpty).join(' · ');
}

Map<String, dynamic> _pickNestedUserMap(Map<String, dynamic> map) {
  final user = map['user'];
  if (user is Map) return Map<String, dynamic>.from(user);
  return const {};
}

String _historyStudentName(Map<String, dynamic> map, {String bedName = ''}) {
  final user = _pickNestedUserMap(map);
  final topLevel = _pickString(map, ['studentName', 'realname', 'userName']);
  if (topLevel.isNotEmpty) return topLevel;
  final realname = _pickString(user, ['realname', 'realName']);
  if (realname.isNotEmpty) return realname;
  final nickname = _pickString(user, ['nickname', 'nickName']);
  if (nickname.isNotEmpty) return nickname;
  if (bedName.isNotEmpty) return '$bedName（未登记）';
  return '未登记学生';
}

String _historyStudentNo(
  Map<String, dynamic> map,
  Map<String, dynamic> user,
) {
  final no = _pickString(map, ['studentNo', 'userNo']);
  if (no.isNotEmpty) return no;
  final fromUser = _pickString(user, ['studentNo', 'no', 'userNo']);
  return fromUser.isNotEmpty ? fromUser : '—';
}

String _historyAvatarUrl(
  Map<String, dynamic> map,
  Map<String, dynamic> user,
) {
  final raw = _pickString(map, ['studentHeadUrl', 'headUrl', 'avatar']);
  if (raw.isEmpty) {
    final fromUser = _pickString(user, ['headUrl', 'avatar', 'avatarUrl']);
    if (fromUser.isEmpty) return '';
    return MediaUrl.resolve(fromUser);
  }
  return MediaUrl.resolve(raw);
}

String _formatBedLabel(String bedName) {
  final trimmed = bedName.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.endsWith('床')) return trimmed;
  return '$trimmed床';
}

String _historyClock(String value) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return value.isEmpty ? '—' : value;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

String _clock(String value) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return value.isEmpty ? '--' : value;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

bool _isEmptyDetailValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ||
      trimmed == '—' ||
      trimmed == '--' ||
      trimmed == '未登记学生';
}

/// 详情弹窗补全「规定时间」：记录 / 接口缺失时回退 [SchoolDormitoryCheckConfig]。
List<DormitoryDetailField> enrichDormitoryDetailRequiredTime({
  required List<DormitoryDetailField> fields,
  required String checkType,
  required String recordDeadline,
  required SchoolDormitoryCheckConfig config,
}) {
  final deadline = resolveDormitoryRequiredDeadline(
    recordDeadline: recordDeadline,
    checkType: checkType,
    config: config,
  );
  if (deadline == '—') return fields;

  var replaced = false;
  final updated = <DormitoryDetailField>[];
  for (final field in fields) {
    if (field.label == '规定时间') {
      replaced = true;
      updated.add(
        DormitoryDetailField(
          field.label,
          _isEmptyDetailValue(field.value) ? deadline : field.value,
        ),
      );
    } else {
      updated.add(field);
    }
  }
  if (replaced) return updated;

  final insertIndex = updated.indexWhere((field) => field.label == '打卡时间');
  final requiredField = DormitoryDetailField('规定时间', deadline);
  if (insertIndex >= 0) {
    updated.insert(insertIndex, requiredField);
    return updated;
  }
  return [...updated, requiredField];
}

/// 详情接口字段缺失时，用查寝历史列表行补全展示值。
List<DormitoryDetailField> mergeDormitoryCheckDetailFields({
  required List<DormitoryDetailField> fields,
  required DormitoryCheckHistoryItem item,
}) {
  final fallback = <String, String>{
    '学生姓名': item.studentName,
    '学生学号': item.studentNo != '—' ? item.studentNo : '',
    '手机号': item.mobile,
    '查寝日期': item.checkDate,
    '我的宿舍': item.dormName,
    '我的床位': item.bedName.isEmpty ? '' : item.bedLabel,
    '打卡时间': item.checkTime,
    '查寝状态': item.statusLabel,
    '查寝备注': item.remark,
  };
  return [
    for (final field in fields)
      DormitoryDetailField(
        field.label,
        _isEmptyDetailValue(field.value)
            ? (fallback[field.label]?.trim().isNotEmpty == true
                  ? fallback[field.label]!.trim()
                  : field.value)
            : field.value,
      ),
  ];
}

/// 详情接口无数据时，完全由列表行构造字段。
List<DormitoryDetailField> buildDormitoryCheckDetailFieldsFromHistoryItem(
  DormitoryCheckHistoryItem item,
) {
  return [
    DormitoryDetailField(
      '学生姓名',
      item.studentName.isEmpty ? '—' : item.studentName,
    ),
    if (item.studentNo.isNotEmpty && item.studentNo != '—')
      DormitoryDetailField('学生学号', item.studentNo),
    if (item.mobile.isNotEmpty) DormitoryDetailField('手机号', item.mobile),
    DormitoryDetailField(
      '查寝日期',
      item.checkDate.isEmpty ? '—' : item.checkDate,
    ),
    DormitoryDetailField(
      '我的宿舍',
      item.dormName.isEmpty ? '—' : item.dormName,
    ),
    DormitoryDetailField(
      '我的床位',
      item.bedName.isEmpty ? '—' : item.bedLabel,
    ),
    DormitoryDetailField(
      '打卡时间',
      item.checkTime.isEmpty ? '—' : item.checkTime,
    ),
    DormitoryDetailField(
      '查寝状态',
      item.statusLabel.isEmpty ? '—' : item.statusLabel,
    ),
    if (item.remark.isNotEmpty) DormitoryDetailField('查寝备注', item.remark),
    if (item.handleStatus > 0)
      DormitoryDetailField(
        '处理状态',
        item.handleStatus == 1 ? '已处理' : '待处理',
      ),
  ];
}

List<DormitoryDetailField> parseDormitoryCheckDetailFields(dynamic raw) {
  if (raw is! Map) return const [];
  var map = Map<String, dynamic>.from(raw);
  if (map['data'] is Map) {
    map = Map<String, dynamic>.from(map['data'] as Map);
  }
  final status = DormitoryStudentCheckStatus.fromApi(
    _pickString(map, ['status', 'checkStatus'], '未打卡'),
  );
  final handleStatus = _asInt(map['handleStatus']) ?? 0;
  final user = _pickNestedUserMap(map);
  final bedName = _pickString(map, ['bedName', 'bedInfo']);
  final studentDisplay = _historyStudentName(map, bedName: bedName);
  final studentNo = _historyStudentNo(map, user);
  final mobile = _pickString(user, ['mobile', 'phone']);
  return [
    DormitoryDetailField('学生姓名', studentDisplay),
    DormitoryDetailField(
      '学生学号',
      studentNo != '—' ? studentNo : '—',
    ),
    if (studentNo == '—' && mobile.isNotEmpty)
      DormitoryDetailField('手机号', mobile),
    DormitoryDetailField('查寝日期', _pickString(map, ['checkDate', 'date'])),
    DormitoryDetailField('我的宿舍', _historyDormName(map)),
    DormitoryDetailField(
      '我的床位',
      bedName.isEmpty ? '—' : _formatBedLabel(bedName),
    ),
    DormitoryDetailField(
      '打卡时间',
      _pickString(map, ['checkTime', 'stampTime'], '—'),
    ),
    DormitoryDetailField(
      '查寝状态',
      _pickString(map, ['status', 'checkStatus'], status.apiValue),
    ),
    if (_pickString(map, ['anomalyReason', 'remark', 'note']).isNotEmpty)
      DormitoryDetailField(
        '查寝备注',
        _pickString(map, ['anomalyReason', 'remark', 'note']),
      ),
    if (handleStatus > 0)
      DormitoryDetailField('处理状态', handleStatus == 1 ? '已处理' : '待处理'),
    if (_pickString(map, ['handleRemark', 'handleReason']).isNotEmpty)
      DormitoryDetailField(
        '处理说明',
        _pickString(map, ['handleRemark', 'handleReason']),
      ),
  ];
}

List<DormitoryDetailField> parseDormitoryMakeupDetailFields(dynamic raw) {
  if (raw is! Map) return const [];
  var map = Map<String, dynamic>.from(raw);
  if (map['data'] is Map) {
    map = Map<String, dynamic>.from(map['data'] as Map);
  }
  final status = _asInt(map['status']) ?? 0;
  return [
    DormitoryDetailField('学生', _pickString(map, ['studentName', 'realname'])),
    DormitoryDetailField(
      '补卡场次',
      _pickString(map, ['checkType', 'scene'], '补卡'),
    ),
    DormitoryDetailField('补卡日期', _pickString(map, ['checkDate', 'date'])),
    DormitoryDetailField('申请原因', _pickString(map, ['reason'], '未填写')),
    DormitoryDetailField('附件', _pickString(map, ['attachment'], '无')),
    DormitoryDetailField(
      '审批状态',
      _pickString(map, ['statusText'], _makeupStatusLabel(status)),
    ),
    DormitoryDetailField('审批人', _pickString(map, ['approverName'], '—')),
    DormitoryDetailField(
      '审批意见',
      _pickString(map, ['approveRemark', 'auditReason', 'auditRemark'], '无'),
    ),
    DormitoryDetailField('申请时间', _pickString(map, ['createTime', 'applyTime'])),
    DormitoryDetailField(
      '审批时间',
      _pickString(map, ['approveTime', 'auditTime', 'updateTime'], '—'),
    ),
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
