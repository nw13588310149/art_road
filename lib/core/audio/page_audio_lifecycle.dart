import 'package:flutter/foundation.dart';

import 'app_audio_service.dart';
import 'native_audio_bootstrap.dart';
import 'native_playback_audio_session.dart';
import '../../features/music_companion/audio/music_companion_audio_engine.dart';

/// 页面级音频生命周期（已迁至 core，全应用共用）。
abstract final class PageAudioLifecycle {
  static Future<void> enterPlaybackPiano(MusicCompanionAudioEngine engine) {
    if (AppAudioService.isNativePianoReady) {
      return AppAudioService.onPianoPageVisible();
    }
    return AppAudioService.enterPianoPage(
      prepareAssets: () => engine.ensurePianoInitialized(),
    );
  }

  static Future<void> enterPlaybackPianoNative({
    required Future<void> Function() prepareEngine,
  }) {
    return AppAudioService.enterPianoPage(prepareAssets: prepareEngine);
  }

  static Future<void> primeMediaKitPlaybackSession({
    bool releaseOthersFirst = true,
  }) async {
    if (kIsWeb) return;
    if (releaseOthersFirst) {
      NativePlaybackAudioSession.invalidatePlaybackCache();
    }
    await AppAudioService.reconcilePlaybackSession();
  }

  static Future<void> enterMediaKitPiano(
    MusicCompanionAudioEngine engine, {
    bool forceSessionRelease = true,
  }) {
    return AppAudioService.enterPianoPage(
      invalidateSession: forceSessionRelease,
      prepareAssets: () => engine.ensurePianoInitialized(),
    );
  }

  static Future<void> recoverPianoDuringMediaKit(
    MusicCompanionAudioEngine engine,
  ) {
    return AppAudioService.recoverPianoAfterMediaKit(
      ensurePrepared: () => engine.ensurePianoInitialized(),
    );
  }

  static Future<void> ensurePianoReady(MusicCompanionAudioEngine engine) async {
    if (kIsWeb) {
      if (!engine.isPianoReady) {
        await engine.ensurePianoInitialized();
      }
      return;
    }
    if (!engine.isPianoReady) {
      await enterPlaybackPiano(engine);
    }
  }

  static Future<void> leavePage({
    MusicCompanionAudioEngine? pianoEngine,
  }) async {
    await AppAudioService.onPageLeave();
  }

  static Future<void> leaveSightSinging() async {
    if (kIsWeb) return;
    await NativeAudioBootstrap.reactivatePlaybackSession();
    NativePlaybackAudioSession.invalidatePlaybackCache();
    await AppAudioService.reconcilePlaybackSession();
    await AppAudioService.sharedNativePlayer.pingEngine();
  }

  static Future<void> enterSightSingingCapture({bool soft = false}) {
    return AppAudioService.enterSightSingingCapture(soft: soft);
  }

  static Future<void> enterTuner() {
    return AppAudioService.enterMeasurementSession();
  }

  static Future<void> leaveTunerToPlaybackPiano(
    MusicCompanionAudioEngine engine,
  ) {
    return AppAudioService.restorePlaybackAfterCapture(
      ensurePrepared: () async {
        await engine.reclaimNativeGraphAfterSessionChange();
        if (!engine.isPianoReady) {
          await engine.ensurePianoInitialized();
        }
      },
    );
  }
}
