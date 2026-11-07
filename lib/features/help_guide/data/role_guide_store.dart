import 'package:shared_preferences/shared_preferences.dart';

import 'role_guides.dart';

/// 新手引导「已看过」标记：按身份分别保存在本机，同一台设备换身份登录会各看一次。
class RoleGuideStore {
  const RoleGuideStore();

  static const _prefix = 'role_guide_seen_v1:';

  static String keyOf(String role) => '$_prefix${role.trim()}';

  Future<bool> hasSeen(String role) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyOf(role)) ?? false;
  }

  Future<void> markSeen(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyOf(role), true);
  }

  /// 全部身份都记为已看过（演示时从帮助页跳过引导）。
  Future<void> markAllSeen() async {
    final prefs = await SharedPreferences.getInstance();
    for (final role in roleGuideRoles) {
      await prefs.setBool(keyOf(role), true);
    }
  }

  /// 清除全部身份的标记，下次进入首页重新显示引导。
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final role in roleGuideRoles) {
      await prefs.remove(keyOf(role));
    }
  }

  Future<bool> allSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return roleGuideRoles.every((role) => prefs.getBool(keyOf(role)) ?? false);
  }
}
