import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 演示后端的可写状态：内存优先，写操作后以 JSON 持久化到本机，
/// 让上传的作品、点评、笔记、收藏等在重启后依然存在。
abstract final class DemoStore {
  static const _prefix = 'demo_store:';
  static SharedPreferences? _prefs;
  static final Map<String, Object?> _memory = <String, Object?>{};

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 读取一个 JSON 列表；首次读取时用 [seed] 生成并缓存（未持久化前不落盘）。
  static List<Map<String, dynamic>> list(
    String key,
    List<Map<String, dynamic>> Function() seed,
  ) {
    final cached = _memory[key];
    if (cached is List<Map<String, dynamic>>) {
      return cached;
    }
    final stored = _prefs?.getString('$_prefix$key');
    List<Map<String, dynamic>> value;
    if (stored != null) {
      try {
        value = (jsonDecode(stored) as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } catch (_) {
        value = seed();
      }
    } else {
      value = seed();
    }
    _memory[key] = value;
    return value;
  }

  /// 读取一个 JSON 对象；首次读取时用 [seed] 生成并缓存。
  static Map<String, dynamic> map(
    String key,
    Map<String, dynamic> Function() seed,
  ) {
    final cached = _memory[key];
    if (cached is Map<String, dynamic>) {
      return cached;
    }
    final stored = _prefs?.getString('$_prefix$key');
    Map<String, dynamic> value;
    if (stored != null) {
      try {
        value = Map<String, dynamic>.from(jsonDecode(stored) as Map);
      } catch (_) {
        value = seed();
      }
    } else {
      value = seed();
    }
    _memory[key] = value;
    return value;
  }

  /// 把 [key] 当前的内存值写入本机。
  static void save(String key) {
    final value = _memory[key];
    if (value == null) {
      return;
    }
    _prefs?.setString('$_prefix$key', jsonEncode(value));
  }

  /// 单调递增的本地 id（字符串承载，与后端雪花 id 一致）。
  static String nextId([String prefix = '']) {
    final current = _prefs?.getInt('${_prefix}seq') ?? 100000;
    final next = current + 1;
    _prefs?.setInt('${_prefix}seq', next);
    return '$prefix$next';
  }

  /// 清空全部演示写入，恢复到初始演示数据。
  static Future<void> reset() async {
    _memory.clear();
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }
}
