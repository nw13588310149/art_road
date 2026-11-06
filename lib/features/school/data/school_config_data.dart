/// 学校全局配置（`schoolConfigList`）解析，重点提供查寝规定打卡时间。
library;

class SchoolDormitoryCheckConfig {
  const SchoolDormitoryCheckConfig({
    this.eveningDeadline = '',
    this.morningDeadline = '',
  });

  static const empty = SchoolDormitoryCheckConfig();

  /// 晚查寝 / 晚打卡规定时间，展示形如 `22:30前`。
  final String eveningDeadline;

  /// 晨查寝 / 晨打卡规定时间，展示形如 `07:20前`。
  final String morningDeadline;

  String deadlineForCheckType(String checkType) {
    return isMorningDormitoryCheckType(checkType)
        ? morningDeadline
        : eveningDeadline;
  }
}

/// 晨 / 晚查寝场次识别（兼容接口 `checkType` / 补卡 scene 文案）。
bool isMorningDormitoryCheckType(String checkType) {
  final value = checkType.trim();
  if (value.isEmpty) return false;
  if (value.contains('晨')) return true;
  if (value.contains('晚')) return false;
  final lower = value.toLowerCase();
  if (lower.contains('morning')) return true;
  if (lower.contains('evening') || lower.contains('night')) return false;
  return false;
}

/// 记录自带 deadline 优先；缺失时回退到学校配置。
String resolveDormitoryRequiredDeadline({
  required String recordDeadline,
  required String checkType,
  required SchoolDormitoryCheckConfig config,
  bool defaultMorning = false,
}) {
  final trimmed = recordDeadline.trim();
  if (trimmed.isNotEmpty && trimmed != '—' && trimmed != '--') {
    return trimmed;
  }
  final resolved = checkType.trim().isEmpty
      ? (defaultMorning ? config.morningDeadline : config.eveningDeadline)
      : config.deadlineForCheckType(checkType);
  return resolved.isEmpty ? '—' : resolved;
}

SchoolDormitoryCheckConfig parseSchoolDormitoryCheckConfig(dynamic raw) {
  final entries = _flattenConfigEntries(raw);
  if (entries.isEmpty) return SchoolDormitoryCheckConfig.empty;

  var evening = '';
  var morning = '';

  for (final entry in entries) {
    final key = _normalizeConfigKey(entry.key);
    final value = _normalizeDeadlineValue(entry.value);
    if (value.isEmpty) continue;

    if (_isEveningConfigKey(key, entry.type)) {
      evening = evening.isEmpty ? value : evening;
      continue;
    }
    if (_isMorningConfigKey(key, entry.type)) {
      morning = morning.isEmpty ? value : morning;
    }
  }

  return SchoolDormitoryCheckConfig(
    eveningDeadline: evening,
    morningDeadline: morning,
  );
}

class _ConfigEntry {
  const _ConfigEntry({required this.key, required this.value, this.type = ''});

  final String key;
  final String value;
  final String type;
}

List<_ConfigEntry> _flattenConfigEntries(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        ..._flattenConfigEntries(item),
    ];
  }
  if (raw is! Map) return const [];

  final map = raw.map((key, value) => MapEntry(key.toString(), value));
  for (final wrapperKey in ['data', 'result', 'records', 'list']) {
    final nested = map[wrapperKey];
    if (nested != null && nested != raw) {
      final parsed = _flattenConfigEntries(nested);
      if (parsed.isNotEmpty) return parsed;
    }
  }

  final keyField = _pickString(map, ['configKey', 'key', 'code', 'name']);
  final valueField = _pickString(map, [
    'configValue',
    'value',
    'content',
    'val',
  ]);
  final typeField = _pickString(map, ['type', 'configType', 'scene']);

  if (keyField.isNotEmpty && valueField.isNotEmpty) {
    return [
      _ConfigEntry(key: keyField, value: valueField, type: typeField),
    ];
  }

  final entries = <_ConfigEntry>[];
  for (final entry in map.entries) {
    final value = entry.value;
    if (value == null) continue;
    if (value is Map || value is List) {
      entries.addAll(_flattenConfigEntries(value));
      continue;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') continue;
    entries.add(_ConfigEntry(key: entry.key, value: text, type: typeField));
  }
  return entries;
}

bool _isEveningConfigKey(String key, String type) {
  if (_containsAny(key, ['evening', 'night', 'pm'])) return true;
  if (_containsAny(key, ['晚', '夜'])) return true;
  if (_containsAny(type, ['evening', 'night', 'pm', '晚', '夜'])) return true;
  if (key.contains('deadline') && key.contains('night')) return true;
  if (key.contains('check') && key.contains('night')) return true;
  return false;
}

bool _isMorningConfigKey(String key, String type) {
  if (_containsAny(key, ['morning', 'am'])) return true;
  if (key.contains('晨')) return true;
  if (_containsAny(type, ['morning', 'am', '晨'])) return true;
  if (key.contains('deadline') && key.contains('morning')) return true;
  if (key.contains('check') && key.contains('morning')) return true;
  return false;
}

bool _containsAny(String source, List<String> needles) {
  final lower = source.toLowerCase();
  for (final needle in needles) {
    if (lower.contains(needle.toLowerCase())) return true;
  }
  return false;
}

String _normalizeConfigKey(String raw) {
  return raw.trim().replaceAll(' ', '').replaceAll('_', '').toLowerCase();
}

String _normalizeDeadlineValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == 'null') return '';
  if (trimmed.contains('前') || trimmed.contains('后')) return trimmed;

  final clock = _extractClock(trimmed);
  if (clock.isEmpty) return trimmed;
  return '$clock前';
}

String _extractClock(String raw) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return '';
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') return value;
  }
  return '';
}
