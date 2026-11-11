import 'package:shared_preferences/shared_preferences.dart';

class CompanionPreferences {
  static const motionKey = 'art_toolbox_companion_motion_v1';

  Future<bool> loadMotion() async =>
      (await SharedPreferences.getInstance()).getBool(motionKey) ?? true;

  Future<void> saveMotion(bool enabled) async {
    await (await SharedPreferences.getInstance()).setBool(motionKey, enabled);
  }
}
