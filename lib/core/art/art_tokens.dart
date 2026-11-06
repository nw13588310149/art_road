import 'package:flutter/material.dart';

import '../ui/app_colors.dart';
import '../ui/app_text.dart';

/// 美术模块色板：与 [AppColors] 同一套颜色，保留旧名供未迁移页面使用。
///
/// 新代码直接用 [AppColors]。
abstract final class ArtColors {
  static const brand = AppColors.brand;
  static const brandDeep = AppColors.brandDeep;
  static const brandSoft = AppColors.brandSoft;
  static const brandLight = AppColors.brandTint;
  static const brandTint = AppColors.brandTint;
  static const brandWash = AppColors.brandWash;

  static const ink = AppColors.ink;
  static const ink2 = AppColors.textSecondary;
  static const ink3 = AppColors.textTertiary;
  static const ink4 = AppColors.textPlaceholder;
  static const line = AppColors.lineSoft;
  static const page = AppColors.page;
  static const card = AppColors.surface;
  static const subtle = AppColors.surfaceSubtle;

  static const up = AppColors.success;
  static const down = AppColors.danger;
  static const warn = AppColors.warning;
  static const success = AppColors.success;
  static const danger = AppColors.danger;

  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.brand, AppColors.brandSoft],
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

/// 美术模块文字样式：基于 [AppText]，保留可传字号的旧接口供未迁移页面使用。
///
/// 新代码直接用 [AppText] 的固定字阶。
abstract final class ArtText {
  static TextStyle title({double size = 20, Color color = ArtColors.ink}) =>
      AppText.title20.copyWith(fontSize: size, height: 1.25, color: color);

  static TextStyle body({
    double size = 14,
    Color color = ArtColors.ink,
    FontWeight? weight,
    double height = 1.45,
  }) => AppText.body14.copyWith(
    fontSize: size,
    height: height,
    color: color,
    fontWeight: weight,
  );

  static TextStyle caption({double size = 12, Color color = ArtColors.ink3}) =>
      AppText.caption12.copyWith(fontSize: size, height: 1.35, color: color);

  static TextStyle number({
    double size = 24,
    Color color = ArtColors.ink,
    FontWeight weight = FontWeight.w500,
  }) => AppText.number(
    size: size,
    color: color,
  ).copyWith(height: 1.1, fontWeight: weight);
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
