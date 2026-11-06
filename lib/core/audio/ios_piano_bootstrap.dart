import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/music_companion/audio/music_companion_audio_catalog.dart';
import 'app_audio_service.dart';
import 'native_playback_audio_session.dart';

/// iOS 启动时一次性预加载钢琴 + 节拍器（GarageBand / 钢琴 App 同款策略）。
///
/// 采样在 App 生命周期内常驻内存；页面切换只做 reconcile + ping，不再 prepare。
abstract final class IosPianoBootstrap {
  static Future<void>? _task;

  static Future<void> warmAtAppLaunch() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return Future<void>.value();
    }
    return _task ??= _run();
  }

  static Future<void> _run() async {
    try {
      await NativePlaybackAudioSession.reconcilePlayback();
      final player = AppAudioService.sharedNativePlayer;
      await player.prepare(_allShortAudioAssets);
      await player.pingEngine();
      if (player.nativeReady) {
        AppAudioService.markPianoCoreWarmed();
      }
    } catch (error, stack) {
      _task = null;
      debugPrint('IosPianoBootstrap failed: $error\n$stack');
    }
  }

  static Map<String, String> get _allShortAudioAssets {
    final assets = <String, String>{
      ...kMusicCompanionPianoAssetByNote,
    };
    for (final entry in kMusicCompanionMetronomeAssetByCue.entries) {
      assets['metronome.${entry.key.name}'] = entry.value;
    }
    return assets;
  }
}
