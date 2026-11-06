import 'package:flutter/painting.dart';

/// 美术联考三科。科目名称与阅卷系统一致（后端以中文名称传递）。
enum ArtSubject {
  sketch('素描', 'sketch', Color(0xFF4A74D6), Color(0xFFEAF0FB)),
  color('色彩', 'color', Color(0xFF3B9A6E), Color(0xFFE7F5EE)),
  speed('速写', 'speed', Color(0xFF1F8FA8), Color(0xFFE4F3F7));

  const ArtSubject(this.label, this.code, this.accent, this.accentSoft);

  final String label;
  final String code;
  final Color accent;
  final Color accentSoft;

  String get coverAsset => switch (this) {
    ArtSubject.sketch => 'assets/demo/art/sketch-bust-1.jpg',
    ArtSubject.color => 'assets/demo/art/color-still-2.jpg',
    ArtSubject.speed => 'assets/demo/art/speed-figure-1.jpg',
  };

  String get tagline => switch (this) {
    ArtSubject.sketch => '结构 · 明暗 · 空间',
    ArtSubject.color => '色调 · 冷暖 · 塑造',
    ArtSubject.speed => '动态 · 比例 · 线条',
  };

  /// 按中文名称或英文代码匹配；未知科目返回 null（作品允许自定义科目）。
  static ArtSubject? tryParse(String? value) {
    final text = value?.trim() ?? '';
    for (final subject in ArtSubject.values) {
      if (subject.label == text || subject.code == text) {
        return subject;
      }
    }
    return null;
  }
}

/// 科目色：未知 / 自定义科目统一用品牌紫。
Color artSubjectColor(String? name) =>
    ArtSubject.tryParse(name)?.accent ?? const Color(0xFF715EFE);

Color artSubjectSoftColor(String? name) =>
    ArtSubject.tryParse(name)?.accentSoft ?? const Color(0xFFF0EDFF);
