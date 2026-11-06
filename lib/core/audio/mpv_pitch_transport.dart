import 'package:media_kit/media_kit.dart';

/// iOS mpv + [PlayerConfiguration.pitch]（scaletempo）操作层。
///
/// scaletempo 在 pause/seek/音量斜坡时会重配滤波并冲刷 ao 缓冲，产生可闻咔哒。
/// 本层用 mpv 原生 `mute`（输出级硬静音）包裹 transport，并在拖动进度时由上层
/// 只做 UI 预览、松手单次 seek，避免连续 seek 触发滤波器重配。
abstract final class MpvPitchTransport {
  static Future<void> configure(Player player) async {
    try {
      final platform = player.platform;
      if (platform == null) {
        return;
      }
      final native = platform as dynamic;
      await native.setProperty('gapless-audio', 'yes');
      await native.setProperty('audio-stream-silence', 'yes');
    } catch (_) {}
  }

  static Future<void> setMuted(Player player, bool muted) async {
    try {
      final platform = player.platform;
      if (platform == null) {
        return;
      }
      await (platform as dynamic).setProperty('mute', muted ? 'yes' : 'no');
    } catch (_) {}
  }

  static Future<void> pauseSmooth(Player player) async {
    await setMuted(player, true);
    try {
      await player.pause();
    } catch (_) {}
  }

  static Future<void> playSmooth(Player player) async {
    try {
      await player.play();
    } catch (_) {}
    await setMuted(player, false);
  }

  static Future<void> seekSmooth(
    Player player,
    Duration position, {
    bool restoreAudible = true,
  }) async {
    await setMuted(player, true);
    try {
      await player.seek(position);
    } catch (_) {}
    if (restoreAudible) {
      await setMuted(player, false);
    }
  }
}
