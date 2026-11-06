class AdminClassSummary {
  const AdminClassSummary({
    this.bigClassCount = 0,
    this.smallClassCount = 0,
    this.studentCount = 0,
    this.teacherCount = 0,
    this.unassignedStudentCount = 0,
  });

  final int bigClassCount;
  final int smallClassCount;
  final int studentCount;
  final int teacherCount;
  final int unassignedStudentCount;

  int get classCount => bigClassCount + smallClassCount;

  factory AdminClassSummary.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    return AdminClassSummary(
      bigClassCount: _readInt(map['bigClassCount']),
      smallClassCount: _readInt(map['smallClassCount']),
      studentCount: _readInt(map['studentCount']),
      teacherCount: _readInt(map['teacherCount']),
      unassignedStudentCount: _readInt(map['unassignedStudentCount']),
    );
  }
}

Map<String, dynamic>? _unwrapMap(dynamic raw) {
  if (raw is! Map) return null;
  final map = raw.map((key, value) => MapEntry(key.toString(), value));
  final data = map['data'];
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  return map;
}

int _readInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}
