import 'dart:async';

import 'package:flutter/foundation.dart';

import 'low_latency_note_player.dart';
import 'native_piano_handoff.dart';
import 'native_playback_audio_session.dart';

/// 全应用 iOS 音频统一协调器。
abstract final class AppAudioService {
  static final LowLatencyNotePlayer _player = createLowLatencyNotePlayer();

  static LowLatencyNotePlayer get sharedNativePlayer => _player;

  // Feature/page wrappers may stop voices, but must never dispose this
  // App-lifetime shared player.

  static bool _pianoCoreWarmed = false;
  static Future<void>? _pianoWarmTask;
  static DateTime? _lastReconcileAt;
  static const Duration _reconcileMinInterval = Duration(milliseconds: 350);

  static bool get isNativePianoReady => _player.nativeReady;

  static Future<void> reconcilePlaybackSession() {
    if (kIsWeb) return Future<void>.value();
    _lastReconcileAt = DateTime.now();
    return NativePlaybackAudioSession.reconcilePlayback();
  }

  static Future<void> enterRecordSession() =>
      NativePlaybackAudioSession.ensureRecordActive();

  static Future<void> enterMeasurementSession() =>
      NativePlaybackAudioSession.ensurePlayAndRecordActive();

  static Future<void> enterSightSingingCapture({bool soft = false}) {
    if (soft) {
      return NativePlaybackAudioSession.ensureSightSingingCaptureActiveSoft();
    }
    return NativePlaybackAudioSession.ensureSightSingingCaptureActive();
  }

  /// 按键前准备。已预热时仅 ping（快）；否则完整 reconcile。
  static Future<void> prepareForPianoKeypress({bool force = false}) async {
    if (kIsWeb) return;

    // The keypress hot path must never cross a platform channel or reconfigure
    // AVAudioSession. Native route/interruption observers keep the persistent
    // engine alive; explicit reconciliation happens at feature transitions.
    if (!force && _pianoCoreWarmed && _player.nativeReady) return;

    await reconcilePlaybackSession();
    await _player.pingEngine();
    if (!_pianoCoreWarmed || !_player.nativeReady) {
      await warmupPianoCore();
    }
  }

  static Future<void> _reconcileIfDue() async {
    final last = _lastReconcileAt;
    if (last != null &&
        DateTime.now().difference(last) < _reconcileMinInterval) {
      return;
    }
    try {
      await reconcilePlaybackSession();
    } catch (_) {}
  }

  static bool playPianoFromGesture(
    String note, {
    double volume = 1,
    bool metronome = false,
  }) {
    if (kIsWeb || !_player.nativeReady) return false;
    return _player.tryPlay(note, volume: volume, metronome: metronome);
  }

  static Future<void> warmupPianoCore() {
    return _pianoWarmTask ??= _runWarmPianoCore();
  }

  static Future<void> _runWarmPianoCore() async {
    if (kIsWeb) return;
    try {
      await NativePianoHandoff.run(() async {
        await reconcilePlaybackSession();
        await _player.pingEngine();
      });
      _pianoCoreWarmed = _player.nativeReady;
    } catch (error, stack) {
      _pianoWarmTask = null;
      debugPrint('AppAudioService.warmupPianoCore failed: $error\n$stack');
    }
  }

  /// 页面进入：仅 reconcile + ping（采样已在 [IosPianoBootstrap] 预加载）。
  static Future<void> onPianoPageVisible() async {
    if (kIsWeb) return;
    await reconcilePlaybackSession();
    await _player.pingEngine();
  }

  static Future<void> enterPianoPage({
    required Future<void> Function() prepareAssets,
    bool invalidateSession = false,
  }) async {
    if (kIsWeb) {
      await prepareAssets();
      return;
    }
    // 采样已在启动预加载：页面进入只做 reconcile + ping，绝不重复 prepare。
    if (_player.nativeReady) {
      if (invalidateSession) {
        NativePlaybackAudioSession.invalidatePlaybackCache();
      }
      await onPianoPageVisible();
      _pianoCoreWarmed = true;
      return;
    }
    await NativePianoHandoff.run(() async {
      if (invalidateSession) {
        NativePlaybackAudioSession.invalidatePlaybackCache();
      }
      await reconcilePlaybackSession();
      await prepareAssets();
      await _player.pingEngine();
      _pianoCoreWarmed = _player.nativeReady;
    });
  }

  static Future<void> recoverPianoAfterMediaKit({
    required Future<void> Function() ensurePrepared,
  }) async {
    if (kIsWeb) {
      await ensurePrepared();
      return;
    }
    if (_player.nativeReady && _pianoCoreWarmed) {
      await onPianoPageVisible();
      return;
    }
    await NativePianoHandoff.run(() async {
      await reconcilePlaybackSession();
      await _player.pingEngine();
      if (!_player.nativeReady) {
        await ensurePrepared();
      }
      _pianoCoreWarmed = _player.nativeReady;
    });
  }

  /// 离开页面：停短音，保留原生缓冲与 warm 状态。
  static Future<void> onPageLeave() async {
    await _player.stopAll();
    if (!kIsWeb) {
      unawaited(_reconcileIfDue());
    }
  }

  static Future<void> restorePlaybackAfterCapture({
    required Future<void> Function() ensurePrepared,
  }) async {
    if (kIsWeb) {
      await ensurePrepared();
      return;
    }
    await NativePianoHandoff.run(() async {
      await reconcilePlaybackSession();
      await _player.pingEngine();
      await ensurePrepared();
      _pianoCoreWarmed = _player.nativeReady;
    });
  }

  /// 首次 prepare 成功后由引擎调用。
  static void markPianoCoreWarmed() {
    _pianoCoreWarmed = true;
  }
}
