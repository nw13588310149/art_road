import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// iOS mpv 长视频 / 长音频操作去咔哒：极短音量淡出再 pause/seek/open，恢复时淡入。
abstract final class MpvPlayerSmooth {
  static const double normalVolume = 100;

  static const int clickFadeSteps = 3;
  static const Duration clickFadeStepDelay = Duration(milliseconds: 6);

  static const int scrubDuckSteps = 2;
  static const Duration scrubDuckStepDelay = Duration(milliseconds: 4);

  static bool get isIosNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> setVolumeSafe(Player player, double volume) async {
    try {
      await player.setVolume(volume.clamp(0, 100));
    } catch (_) {}
  }

  static Future<void> fadeVolume(
    Player player, {
    required double to,
    double? from,
    int? steps,
    Duration? stepDelay,
  }) async {
    final fadeSteps = steps ?? clickFadeSteps;
    final fadeDelay = stepDelay ?? clickFadeStepDelay;
    final fromVol = from ?? player.state.volume;
    if ((fromVol - to).abs() < 1) {
      await setVolumeSafe(player, to);
      return;
    }
    for (var step = 1; step <= fadeSteps; step++) {
      final t = step / fadeSteps;
      await setVolumeSafe(player, fromVol + (to - fromVol) * t);
      if (step < fadeSteps) {
        await Future.delayed(fadeDelay);
      }
    }
  }

  static Future<void> pauseSmooth(Player player) async {
    if (!isIosNative) {
      try {
        await player.pause();
      } catch (_) {}
      return;
    }
    try {
      await fadeVolume(player, to: 0);
      await player.pause();
    } catch (_) {}
    await setVolumeSafe(player, normalVolume);
  }

  static Future<void> playSmooth(Player player) async {
    if (!isIosNative) {
      try {
        await player.play();
      } catch (_) {}
      return;
    }
    try {
      await setVolumeSafe(player, 0);
      await player.play();
      await fadeVolume(player, to: normalVolume, from: 0);
    } catch (_) {}
  }

  static Future<void> seekSmooth(
    Player player,
    Duration position, {
    bool restoreIfPlaying = true,
    bool alreadyMuted = false,
  }) async {
    try {
      final playing = player.state.playing;
      if (isIosNative && restoreIfPlaying && playing && !alreadyMuted) {
        await setVolumeSafe(player, 0);
      }
      await player.seek(position);
      if (isIosNative && restoreIfPlaying && playing) {
        await fadeVolume(
          player,
          to: normalVolume,
          from: 0,
          steps: scrubDuckSteps,
          stepDelay: scrubDuckStepDelay,
        );
      }
    } catch (_) {}
  }

  static Future<void> openSmooth(
    Player player,
    Media media, {
    required bool play,
  }) async {
    if (isIosNative) {
      await setVolumeSafe(player, 0);
    }
    await player.open(media, play: play);
    if (isIosNative && play) {
      await fadeVolume(player, to: normalVolume, from: 0);
    }
  }
}
