import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/value_order_game.dart';

/// 明度排序训练的最佳用时（毫秒），按色块数和难度分别记录。
class ValueOrderRecordRepository {
  static const storageKey = 'art_toolbox_value_order_best_v1';

  static String keyOf(int count, ValueOrderLevel level) => '$count-${level.name}';

  Future<Map<String, int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      return <String, int>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, int>{};
      }
      return <String, int>{
        for (final entry in decoded.entries)
          if (entry.value is num && (entry.value as num) > 0)
            entry.key.toString(): (entry.value as num).toInt(),
      };
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> save(Map<String, int> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(records));
  }
}

/// 用时比原纪录短（或还没有纪录）时返回更新后的纪录表，否则返回 null。
Map<String, int>? recordIfBest(Map<String, int> records, String key, int millis) {
  final previous = records[key];
  if (millis <= 0 || (previous != null && previous <= millis)) {
    return null;
  }
  return <String, int>{...records, key: millis};
}
