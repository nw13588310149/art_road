import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'mpv_player_smooth.dart';

/// 全应用串行释放 media_kit [Player]。
///
/// 与交互用的 [MpvPlayerSmooth.pauseSmooth] 不同：释放路径硬静音、不再恢复音量，
/// 避免 iOS mpv ao 缓冲在 stop/dispose 前因音量回拉而漏出尾音。
abstract final class MpvPlayerRelease {
  static Future<void>? _teardownChain;

  static const Duration _stepTimeout = Duration(seconds: 4);
  static const Duration _iosDrainDelay = Duration(milliseconds: 48);

  /// 新实例创建前等待队列中尚未完成的释放。
  static Future<void> awaitPending() async {
    final pending = _teardownChain;
    if (pending == null) return;
    try {
      await pending;
    } catch (_) {}
  }

  /// 有序释放：mute → 淡出 → pause → drain → stop → dispose。
  static Future<void> release(Player player) async {
    final waitFor = _teardownChain;
    final task = _runRelease(player);
    _teardownChain = task;
    if (waitFor != null) {
      try {
        await waitFor;
      } catch (_) {}
    }
    try {
      await task;
    } finally {
      if (identical(_teardownChain, task)) {
        _teardownChain = null;
      }
    }
  }

  static Future<void> _runRelease(Player player) async {
    try {
      await _setMuted(player, true);
    } catch (_) {}
    if (MpvPlayerSmooth.isIosNative) {
      try {
        await MpvPlayerSmooth.fadeVolume(player, to: 0);
      } catch (_) {}
    } else {
      try {
        await MpvPlayerSmooth.setVolumeSafe(player, 0);
      } catch (_) {}
    }
    try {
      await player.pause().timeout(_stepTimeout, onTimeout: () {});
    } catch (_) {}
    if (MpvPlayerSmooth.isIosNative) {
      await Future<void>.delayed(_iosDrainDelay);
    }
    try {
      await player.stop().timeout(_stepTimeout, onTimeout: () {});
    } catch (_) {}
    try {
      await player.dispose().timeout(_stepTimeout, onTimeout: () {});
    } catch (_) {}
  }

  static Future<void> _setMuted(Player player, bool muted) async {
    final platform = player.platform;
    if (platform == null) return;
    await (platform as dynamic).setProperty('mute', muted ? 'yes' : 'no');
  }
}
