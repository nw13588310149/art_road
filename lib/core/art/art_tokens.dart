import 'package:flutter/material.dart';

import '../theme/app_font.dart';

/// 美术之路设计令牌（与艺考网阅卷系统 / 学情小程序色板一致）。
abstract final class ArtColors {
  static const brand = Color(0xFF715EFE);
  static const brandDeep = Color(0xFF5D45ED);
  static const brandSoft = Color(0xFF9585FF);
  static const brandLight = Color(0xFFD7D5FF);
  static const brandTint = Color(0xFFE3DFFF);
  static const brandWash = Color(0xFFF5F3FF);

  static const ink = Color(0xFF0B081A);
  static const ink2 = Color(0xFF6D6B75);
  static const ink3 = Color(0xFF8B8993);
  static const ink4 = Color(0xFFB6B5BB);
  static const line = Color(0xFFF0F0F4);
  static const page = Color(0xFFEFF3FC);
  static const card = Colors.white;
  static const subtle = Color(0xFFF7F8FB);

  static const up = Color(0xFF47BA5F);
  static const down = Color(0xFFEB6681);
  static const warn = Color(0xFFE09A2D);
  static const success = Color(0xFF16A37A);
  static const danger = Color(0xFFC3313B);

  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brand, Color(0xFF8E7FFF)],
  );

  /// 档位色：A 档品牌紫，B–E 依次蓝 / 青 / 金 / 红，F 及以后沿用 E。
  static Color grade(String grade) {
    switch (grade.trim().toUpperCase()) {
      case 'A':
        return brandDeep;
      case 'B':
        return const Color(0xFF5479D1);
      case 'C':
        return const Color(0xFF479982);
      case 'D':
        return const Color(0xFFAF7B30);
      case '':
        return ink3;
      default:
        return const Color(0xFFC45867);
    }
  }

  /// 点评标签 8 色（与小程序一致，后端以 #HEX 传递）。
  static const tagPalette = <String, Color>{
    '#715EFE': Color(0xFF715EFE),
    '#4A74D6': Color(0xFF4A74D6),
    '#1F8FA8': Color(0xFF1F8FA8),
    '#3B9A6E': Color(0xFF3B9A6E),
    '#B9770F': Color(0xFFB9770F),
    '#DE7A34': Color(0xFFDE7A34),
    '#D64A62': Color(0xFFD64A62),
    '#6D6B75': Color(0xFF6D6B75),
  };

  static Color fromHex(String? hex, {Color fallback = brand}) {
    final value = (hex ?? '').replaceAll('#', '').trim();
    if (value.length != 6) {
      return fallback;
    }
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }
}

/// 常用文字样式（PingFang SC + 字重补偿；数字用 Manrope）。
abstract final class ArtText {
  static TextStyle title({double size = 20, Color color = ArtColors.ink}) =>
      TextStyle(
        fontSize: size,
        height: 1.25,
        color: color,
        fontWeight: AppFont.w600,
        fontFamily: 'PingFang SC',
      );

  static TextStyle body({
    double size = 14,
    Color color = ArtColors.ink,
    FontWeight? weight,
    double height = 1.45,
  }) => TextStyle(
    fontSize: size,
    height: height,
    color: color,
    fontWeight: weight ?? AppFont.w400,
    fontFamily: 'PingFang SC',
  );

  static TextStyle caption({double size = 12, Color color = ArtColors.ink3}) =>
      TextStyle(
        fontSize: size,
        height: 1.35,
        color: color,
        fontWeight: AppFont.w400,
        fontFamily: 'PingFang SC',
      );

  static TextStyle number({
    double size = 24,
    Color color = ArtColors.ink,
    FontWeight weight = FontWeight.w500,
  }) => TextStyle(
    fontSize: size,
    height: 1.1,
    color: color,
    fontWeight: weight,
    fontFamily: 'Manrope',
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// 分数显示：整数不带小数，非整数保留 1 位。
String formatScore(num? value) {
  if (value == null) {
    return '—';
  }
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}
