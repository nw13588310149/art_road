import 'package:media_kit/media_kit.dart';

import '../../../core/audio/mpv_player_smooth.dart';

/// 视频中心播放器：封装 iOS mpv 去咔哒操作（详情 / 全屏 / 画中画共用）。
final class VideoPlayerSmoothSession {
  VideoPlayerSmoothSession(this.player);

  final Player player;
  bool scrubVolumeDucked = false;

  Future<void> duckForScrub() async {
    if (!MpvPlayerSmooth.isIosNative || scrubVolumeDucked) return;
    scrubVolumeDucked = true;
    await MpvPlayerSmooth.fadeVolume(
      player,
      to: 0,
      steps: MpvPlayerSmooth.scrubDuckSteps,
      stepDelay: MpvPlayerSmooth.scrubDuckStepDelay,
    );
  }

  Future<void> restoreAfterScrub({required bool isPlaying}) async {
    if (!scrubVolumeDucked) return;
    scrubVolumeDucked = false;
    if (isPlaying) {
      await MpvPlayerSmooth.fadeVolume(
        player,
        to: MpvPlayerSmooth.normalVolume,
        from: 0,
        steps: MpvPlayerSmooth.clickFadeSteps,
        stepDelay: MpvPlayerSmooth.clickFadeStepDelay,
      );
    } else {
      await MpvPlayerSmooth.setVolumeSafe(
        player,
        MpvPlayerSmooth.normalVolume,
      );
    }
  }

  Future<void> pause() => MpvPlayerSmooth.pauseSmooth(player);

  Future<void> play() => MpvPlayerSmooth.playSmooth(player);

  Future<void> seek(Duration position, {required bool isPlaying}) async {
    final muted = scrubVolumeDucked;
    await MpvPlayerSmooth.seekSmooth(
      player,
      position,
      restoreIfPlaying: isPlaying,
      alreadyMuted: muted,
    );
    scrubVolumeDucked = false;
  }

  Future<void> replayFromStart() async {
    scrubVolumeDucked = false;
    await MpvPlayerSmooth.seekSmooth(
      player,
      Duration.zero,
      restoreIfPlaying: false,
    );
    await MpvPlayerSmooth.playSmooth(player);
  }
}
