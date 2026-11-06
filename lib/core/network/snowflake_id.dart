import 'dart:convert';

/// 从 JSON 字段读取雪花 long id。
///
/// Web 端只允许 [String]（响应侧 [BigIntSafeTransformer] 会把 16+ 位整数
/// 解码为 String）；若已是精度受损的 [num]，直接丢弃，避免把错误 id 继续
/// 传给下游接口。原生端额外允许 [int]。
String? readSnowflakeId(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    final s = raw.trim();
    return s.isEmpty ? null : s;
  }
  if (raw is int) return raw.toString();
  if (raw is num) {
    // Web 端若已落为 double，toString 可能是近似值；仍优于直接丢弃导致列表空白。
    final s = raw.toStringAsFixed(0);
    return s.isEmpty ? null : s;
  }
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

/// 按 [keys] 顺序读取第一个合法的雪花 id 字符串。
String? pickFirstSnowflakeId(Map<dynamic, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final id = readSnowflakeId(json[key]);
    if (id != null) return id;
  }
  return null;
}

/// 构造 POST JSON 文本，强制 `classId` / `id` 等字段以 **带引号的字符串**
/// 写入请求体。Web 端直接 `jsonEncode(Map)` 仍可能把大整数变成 IEEE-754
/// number，因此 studentList 等接口改用手写 JSON 字符串 + `data: String` 发送。
String encodeSnowflakeSafeRequestBody(Map<String, dynamic> body) {
  final entries = <String>[];
  body.forEach((key, value) {
    if (value == null) return;
    final encodedKey = jsonEncode(key);
    if (isSnowflakeJsonKey(key)) {
      final id =
          readSnowflakeId(value) ?? (value is String ? value.trim() : null);
      if (id == null || id.isEmpty) return;
      entries.add('$encodedKey:${jsonEncode(id)}');
      return;
    }
    if (value is String) {
      entries.add('$encodedKey:${jsonEncode(value)}');
      return;
    }
    if (value is num || value is bool) {
      entries.add('$encodedKey:$value');
      return;
    }
    entries.add('$encodedKey:${jsonEncode(value)}');
  });
  return '{${entries.join(',')}}';
}

/// 班级新增/编辑（`classSave` / `classUpdate`）：`id`、`headTeacherId`、
/// `classroomId`、`campusId` 与 `studentIds[]` 一律写入 **带引号的 JSON 字符串**，
/// 避免 Web 端把 int64 当作 number 解析后末位被截断。
String? encodeClassMutationRequestBody(Map<String, dynamic> body) {
  final entries = <String>[];
  for (final entry in body.entries) {
    final value = entry.value;
    if (value == null) continue;
    final key = entry.key;
    final encodedKey = jsonEncode(key);

    if (key == 'studentIds') {
      if (value is! Iterable) return null;
      final encodedIds = <String>[];
      for (final item in value) {
        final id = readSnowflakeId(item);
        if (id == null || !RegExp(r'^\d+$').hasMatch(id)) return null;
        encodedIds.add(jsonEncode(id));
      }
      entries.add('$encodedKey:[${encodedIds.join(',')}]');
      continue;
    }

    if (isSnowflakeJsonKey(key)) {
      final id = readSnowflakeId(value);
      if (id == null || id.isEmpty) return null;
      entries.add('$encodedKey:${jsonEncode(id)}');
      continue;
    }

    entries.add('$encodedKey:${jsonEncode(value)}');
  }
  return '{${entries.join(',')}}';
}

const Set<String> snowflakeJsonKeys = {
  'id',
  'classId',
  'archiveId',
  'teacherId',
  'studentId',
  'userId',
  'headTeacherId',
  'courseId',
  'fromUserId',
  'toUserId',
  'bedId',
  'cId',
};

bool isSnowflakeJsonKey(String key) {
  if (snowflakeJsonKeys.contains(key)) return true;
  return key.endsWith('Id');
}

/// 请求体序列化前，把雪花 id 字段强制保持/转换为 JSON 字符串。
Object? coerceSnowflakeRequestValue(String key, Object? value) {
  if (!isSnowflakeJsonKey(key)) return value;
  // studentList 等接口用空串表示「全部班级」，不能转成 null 被省略。
  if (value is String && value.isEmpty) return value;
  return readSnowflakeId(value);
}

/// 递归处理 POST body，确保 `classId` / `id` 等字段以字符串形态进入
/// `jsonEncode`，避免 Web 端把 19 位雪花 id 变成 IEEE-754 双精度整数。
Object? coerceSnowflakeRequestData(Object? data, [String? key]) {
  if (data is Map) {
    return {
      for (final entry in data.entries)
        entry.key.toString(): coerceSnowflakeRequestData(
          coerceSnowflakeRequestValue(entry.key.toString(), entry.value),
          entry.key.toString(),
        ),
    };
  }
  if (data is List) {
    if (key == 'classIdList') {
      return [
        for (final item in data) coerceSnowflakeRequestValue('classId', item),
      ];
    }
    if (key == 'id') {
      return [for (final item in data) coerceSnowflakeRequestValue('id', item)];
    }
    return [for (final item in data) coerceSnowflakeRequestData(item)];
  }
  return data;
}

/// 构造 `{ "id": [123, 456] }` 请求 JSON 文本（id 为 number，非 string）。
///
/// 课表删除等接口要求 int64 数组；若走 [coerceSnowflakeRequestData] +
/// [BigIntSafeTransformer]，会把元素变成 `"2065…"` 字符串。这里直接把
/// 雪花 id 的十进制字面量写入 JSON，并以 [String] 交给 Dio，绕过 Transformer
/// 的字符串化，同时避免 Web 端 JS Number 精度丢失。
String? encodeNumericIdArrayRequestBody(List<String> ids) {
  final literals = <String>[];
  for (final raw in ids) {
    final id = readSnowflakeId(raw);
    if (id != null && RegExp(r'^\d+$').hasMatch(id)) {
      literals.add(id);
    }
  }
  if (literals.isEmpty) return null;
  return '{"id":[${literals.join(',')}]}';
}

/// 按 Swagger `int64` 约定构造 JSON 请求体，同时避免 Web 端大整数精度丢失。
///
/// [numericIdKeys] 中的标量和 [numericIdArrayKeys] 中的数组元素会以不带引号
/// 的十进制字面量写入；其它字段仍走标准 [jsonEncode]。
String? encodeNumericIdRequestBody(
  Map<String, dynamic> body, {
  Set<String> numericIdKeys = const {},
  Set<String> numericIdArrayKeys = const {},
}) {
  final entries = <String>[];
  for (final entry in body.entries) {
    final value = entry.value;
    if (value == null) continue;
    final key = jsonEncode(entry.key);
    if (numericIdKeys.contains(entry.key)) {
      final literal = _numericIdLiteral(value);
      if (literal == null) return null;
      entries.add('$key:$literal');
      continue;
    }
    if (numericIdArrayKeys.contains(entry.key)) {
      if (value is! Iterable) return null;
      final literals = <String>[];
      for (final item in value) {
        final literal = _numericIdLiteral(item);
        if (literal == null) return null;
        literals.add(literal);
      }
      entries.add('$key:[${literals.join(',')}]');
      continue;
    }
    entries.add('$key:${jsonEncode(value)}');
  }
  return '{${entries.join(',')}}';
}

String? _numericIdLiteral(dynamic raw) {
  final value = readSnowflakeId(raw);
  return value != null && RegExp(r'^\d+$').hasMatch(value) ? value : null;
}
