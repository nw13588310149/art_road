import 'package:flutter/foundation.dart';

import 'app_audio_service.dart';
import 'native_playback_audio_session.dart';

/// 页面级音频生命周期（全应用共用）。
abstract final class PageAudioLifecycle {
  static Future<void> primeMediaKitPlaybackSession({
    bool releaseOthersFirst = true,
  }) async {
    if (kIsWeb) return;
    if (releaseOthersFirst) {
      NativePlaybackAudioSession.invalidatePlaybackCache();
    }
    await AppAudioService.reconcilePlaybackSession();
  }
}
