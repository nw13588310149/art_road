import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ExamCountdown {
  const ExamCountdown({
    required this.id,
    required this.name,
    required this.date,
  });

  final String id;
  final String name;

  /// 只取年月日。
  final DateTime date;

  /// 距今天还有几天：今天为 0，已过为负数（按自然日计算，不受时区夏令时影响）。
  int daysLeftFrom(DateTime now) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;

  String get dateText => '${date.year}-${_two(date.month)}-${_two(date.day)}';

  String get weekdayText =>
      const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1];

  ExamCountdown copyWith({String? name, DateTime? date}) =>
      ExamCountdown(id: id, name: name ?? this.name, date: date ?? this.date);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'date': dateText,
  };

  static ExamCountdown? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final date = DateTime.tryParse(json['date']?.toString() ?? '');
    final name = json['name']?.toString().trim() ?? '';
    if (date == null || name.isEmpty) {
      return null;
    }
    return ExamCountdown(
      id: json['id']?.toString() ?? '${date.millisecondsSinceEpoch}',
      name: name,
      date: DateTime(date.year, date.month, date.day),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

/// 考试倒计时本地存储（SharedPreferences JSON 列表）。
class CountdownRepository {
  static const storageKey = 'art_toolbox_countdowns_v1';

  /// 仅首次使用（尚无存储）时写入的示例日期。
  static List<ExamCountdown> defaults() => [
    ExamCountdown(
      id: 'default-liankao',
      name: '2027 届甘肃省美术统考（示例日期）',
      date: DateTime(2026, 12, 6),
    ),
    ExamCountdown(
      id: 'default-xiaokao',
      name: '院校校考（示例日期）',
      date: DateTime(2027, 2, 20),
    ),
  ];

  Future<List<ExamCountdown>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      final seeded = defaults();
      await save(seeded);
      return seeded;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ExamCountdown>[];
      }
      return [for (final item in decoded) ?ExamCountdown.fromJson(item)];
    } catch (_) {
      return const <ExamCountdown>[];
    }
  }

  Future<void> save(List<ExamCountdown> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode([for (final item in items) item.toJson()]),
    );
  }
}
