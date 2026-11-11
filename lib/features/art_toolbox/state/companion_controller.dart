import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/companion_preferences.dart';

final companionMotionProvider =
    StateNotifierProvider<CompanionMotionController, bool>(
      (ref) => CompanionMotionController(CompanionPreferences()),
    );

class CompanionMotionController extends StateNotifier<bool> {
  CompanionMotionController(this._preferences) : super(true) {
    unawaited(_load());
  }

  final CompanionPreferences _preferences;
  bool _changed = false;
  Future<void> _save = Future<void>.value();

  Future<void> _load() async {
    try {
      final enabled = await _preferences.loadMotion();
      if (mounted && !_changed) state = enabled;
    } catch (_) {
      // 本地偏好不可读时沿用默认形态。
    }
  }

  void setMotion(bool enabled) {
    _changed = true;
    state = enabled;
    _save = _save.then((_) async {
      try {
        await _preferences.saveMotion(enabled);
      } catch (_) {
        // 动态开关立即生效，存储失败不影响画具操作。
      }
    });
  }
}
