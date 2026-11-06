import 'package:flutter/material.dart';

/// 课表色板（产品 16 色）。
const List<Color> scheduleColorPalette = <Color>[
  Color(0xFF8C63FF),
  Color(0xFF808BFF),
  Color(0xFFA49AF4),
  Color(0xFFA8C3FE),
  Color(0xFF71D4D0),
  Color(0xFFCBEEF4),
  Color(0xFFFEEA98),
  Color(0xFFF99C5D),
  Color(0xFFC5E53E),
  Color(0xFFFDEE2F),
  Color(0xFFFE96EB),
  Color(0xFFFFD0F4),
  Color(0xFF00FF01),
  Color(0xFFA4E5DB),
  Color(0xFF79D1E8),
  Color(0xFFC5EBAA),
];

/// 颜色选择器默认色（色板首色 #8C63FF）。
const Color scheduleDefaultPickerColor = Color(0xFF8C63FF);

enum ScheduleCardThemeKind {
  smallOrange,
  smallBlue,
  bigStandard,
  bigExtended,
}

/// 无 API `color` 时，按课卡 kind 取默认背景色。
Color scheduleDefaultBg(ScheduleCardThemeKind kind) {
  switch (kind) {
    case ScheduleCardThemeKind.smallOrange:
      return scheduleColorPalette[7];
    case ScheduleCardThemeKind.smallBlue:
      return scheduleColorPalette[3];
    case ScheduleCardThemeKind.bigStandard:
      return scheduleColorPalette[0];
    case ScheduleCardThemeKind.bigExtended:
      return scheduleColorPalette[2];
  }
}

bool scheduleIsSmallKind(ScheduleCardThemeKind kind) {
  return kind == ScheduleCardThemeKind.smallOrange ||
      kind == ScheduleCardThemeKind.smallBlue;
}

/// 根据背景亮度选择标题文字色，保证对比度。
Color scheduleTitleColorForBackground(Color bg) {
  return bg.computeLuminance() > 0.55
      ? const Color(0xFF0B081A)
      : Colors.white;
}

/// 提交 API 用的 `#RRGGBB` 字符串。
String scheduleColorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// 解析 `#RRGGBB` / `#AARRGGBB`；非法则返回 null。
Color? parseScheduleHexColor(String? hex) {
  if (hex == null) return null;
  var s = hex.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(v);
}

bool scheduleColorsEqualRgb(Color a, Color b) {
  return (a.toARGB32() & 0xFFFFFF) == (b.toARGB32() & 0xFFFFFF);
}

/// 在色板中查找完全匹配的颜色。
Color? schedulePaletteMatch(Color color) {
  for (final c in scheduleColorPalette) {
    if (scheduleColorsEqualRgb(c, color)) return c;
  }
  return null;
}

/// 将任意颜色映射到色板中最接近的一色（用于颜色选择器预选）。
Color scheduleNearestPaletteColor(Color color) {
  final matched = schedulePaletteMatch(color);
  if (matched != null) return matched;

  final targetR = (color.r * 255.0).round();
  final targetG = (color.g * 255.0).round();
  final targetB = (color.b * 255.0).round();

  Color nearest = scheduleColorPalette.first;
  var minDist = double.infinity;
  for (final c in scheduleColorPalette) {
    final dr = (c.r * 255.0).round() - targetR;
    final dg = (c.g * 255.0).round() - targetG;
    final db = (c.b * 255.0).round() - targetB;
    final dist = dr * dr + dg * dg + db * db;
    if (dist < minDist) {
      minDist = dist.toDouble();
      nearest = c;
    }
  }
  return nearest;
}
