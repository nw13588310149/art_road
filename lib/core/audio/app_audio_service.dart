import 'package:flutter/foundation.dart';

import 'native_playback_audio_session.dart';

/// 全应用音频会话协调入口：录音、语音消息与长音频/视频播放之间的会话切换。
abstract final class AppAudioService {
  static Future<void> reconcilePlaybackSession() {
    if (kIsWeb) return Future<void>.value();
    return NativePlaybackAudioSession.reconcilePlayback();
  }

  static Future<void> enterRecordSession() =>
      NativePlaybackAudioSession.ensureRecordActive();
}
