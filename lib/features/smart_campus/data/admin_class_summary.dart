class AdminClassSummary {
  const AdminClassSummary({
    this.classCount = 0,
    this.studentCount = 0,
    this.teacherCount = 0,
    this.unassignedStudentCount = 0,
  });

  final int classCount;
  final int studentCount;
  final int teacherCount;
  final int unassignedStudentCount;

  factory AdminClassSummary.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    return AdminClassSummary(
      classCount: _readInt(map['classCount']),
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
