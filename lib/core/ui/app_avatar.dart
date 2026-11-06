import 'package:flutter/material.dart';

import '../theme/app_font.dart';
import 'app_colors.dart';
import 'app_image.dart';

/// 圆形头像：有图显示图片（网络 / 相对路径 / `asset:` 引用），没有图或加载失败时
/// 显示姓氏（名字第一个字），底色按名字在 6 个浅色中固定取一个。
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.url = '',
    this.size = 40,
    super.key,
  });

  final String name;
  final String url;
  final double size;

  static const _palette = <Color>[
    Color(0xFF715EFE),
    Color(0xFF4A74D6),
    Color(0xFF3B9A6E),
    Color(0xFF1F8FA8),
    Color(0xFFDE7A34),
    Color(0xFFD64A62),
  ];

  /// 头像文字：中文取第一个字（姓），英文取首字母大写，空名字为「?」。
  static String initialOf(String name) {
    final text = name.trim();
    if (text.isEmpty) {
      return '?';
    }
    return text.characters.first.toUpperCase();
  }

  static Color colorOf(String name) {
    final text = name.trim();
    if (text.isEmpty) {
      return _palette.first;
    }
    final seed = text.runes.fold<int>(0, (sum, rune) => sum + rune);
    return _palette[seed % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(name);
    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        initialOf(name),
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: size * 0.42,
          height: 1,
          fontWeight: AppFont.w500,
        ),
      ),
    );
    if (url.trim().isEmpty) {
      return initials;
    }
    return ClipOval(
      child: AppImage(
        src: url,
        width: size,
        height: size,
        placeholder: initials,
        error: initials,
      ),
    );
  }
}
