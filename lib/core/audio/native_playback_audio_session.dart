import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 全应用唯一的 AVAudioSession 协调器。
///
/// 设计原则：
/// 1. 单一会话，导航期间绝不 `setActive(false)`。
/// 2. 默认 `playback` + `mixWithOthers` + `defaultMode`。
/// 3. 录音 / 调音器 / 视唱临时升到 `playAndRecord`。
/// 4. [reconcilePlayback] **永不缓存短路**——media_kit(mpv) 会偷偷把 mode 改成
///    `moviePlayback`，缓存会导致 Dart 跳过 configure、钢琴长期无声。
abstract final class NativePlaybackAudioSession {
  static const MethodChannel _iosChannel = MethodChannel(
    'com.yyzl.music/audio_session',
  );
  static const Duration _kChannelTimeout = Duration(seconds: 4);

  static _SessionProfile _current = _SessionProfile.none;
  static bool _activated = false;
  static String? _lastError;
  static Future<void>? _inflight;

  static String get currentProfileLabel => _current.name;
  static bool get isActivated => _activated;
  static String? get lastError => _lastError;

  static Future<void> ensurePlaybackActive() => _ensure(_SessionProfile.playback);

  static Future<void> ensureMediaKitPlaybackActive({
    bool releaseOthersFirst = true,
  }) => reconcilePlayback();

  static Future<void> ensureRecordActive() =>
      _ensure(_SessionProfile.record);

  static Future<void> ensurePlayAndRecordActive() =>
      _ensure(_SessionProfile.measurement);

  static Future<void> ensureSightSingingCaptureActive() =>
      _ensure(_SessionProfile.measurement);

  static Future<void> ensureSightSingingCaptureActiveSoft() =>
      _ensure(_SessionProfile.measurement);

  static void invalidatePlaybackCache() {
    _current = _SessionProfile.none;
    _activated = false;
  }

  /// 强制重配 playback 会话（无缓存短路）。钢琴按键 / media_kit 混播前调用。
  static Future<void> reconcilePlayback() {
    if (kIsWeb) return Future<void>.value();
    return _applyForced(_SessionProfile.playback);
  }

  /// @deprecated 使用 [reconcilePlayback]。
  static Future<void> refreshPlaybackForPiano() => reconcilePlayback();

  static Future<void> _ensure(_SessionProfile profile) {
    if (kIsWeb) return Future<void>.value();
    if (_current == profile && _activated) {
      return Future<void>.value();
    }
    return _enqueue(() => _applyBestEffort(profile));
  }

  static Future<void> _applyForced(_SessionProfile profile) {
    if (kIsWeb) return Future<void>.value();
    return _enqueue(() => _apply(profile));
  }

  static Future<void> _enqueue(Future<void> Function() action) {
    final previous = _inflight;
    final task = previous != null
        ? previous.then((_) => action()).catchError((_) => action())
        : action();
    _inflight = task.whenComplete(() {
      if (identical(_inflight, task)) {
        _inflight = null;
      }
    });
    return task;
  }

  static Future<void> _applyBestEffort(_SessionProfile profile) async {
    if (_current == profile && _activated) return;
    try {
      await _apply(profile);
      _lastError = null;
    } catch (error, stack) {
      _lastError = '$profile: $error';
      debugPrint(
        'NativePlaybackAudioSession apply($profile) failed: $error\n$stack',
      );
    }
  }

  static Future<void> _apply(_SessionProfile profile) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _iosChannel
          .invokeMethod<void>('apply', <String, Object>{
            'profile': switch (profile) {
              _SessionProfile.record => 'record',
              _SessionProfile.measurement => 'measurement',
              _ => 'playback',
            },
          })
          .timeout(
            _kChannelTimeout,
            onTimeout: () => throw TimeoutException(
              'Native iOS audio-session apply($profile) hung > '
              '${_kChannelTimeout.inSeconds}s',
            ),
          );
      _activated = true;
      _current = profile;
      return;
    }
    final session = await AudioSession.instance.timeout(
      _kChannelTimeout,
      onTimeout: () => throw TimeoutException(
        'AudioSession.instance hung > ${_kChannelTimeout.inSeconds}s',
      ),
    );

    await session
        .configure(_configFor(profile))
        .timeout(
          _kChannelTimeout,
          onTimeout: () => throw TimeoutException(
            'AudioSession.configure($profile) hung > '
            '${_kChannelTimeout.inSeconds}s',
          ),
        );

    await session
        .setActive(true)
        .timeout(
          _kChannelTimeout,
          onTimeout: () => throw TimeoutException(
            'AudioSession.setActive(true) hung > '
            '${_kChannelTimeout.inSeconds}s',
          ),
        );
    _activated = true;
    _current = profile;
  }

  static AudioSessionConfiguration _configFor(_SessionProfile profile) {
    switch (profile) {
      case _SessionProfile.playback:
      case _SessionProfile.none:
        return AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        );
      case _SessionProfile.record:
        return AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        );
      case _SessionProfile.measurement:
        return AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.measurement,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        );
    }
  }
}

enum _SessionProfile {
  none,
  playback,
  record,
  measurement,
}
