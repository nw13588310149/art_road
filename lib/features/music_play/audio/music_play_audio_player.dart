import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:media_kit/media_kit.dart' as mk;

import '../../../core/audio/app_audio_service.dart';
import '../../../core/audio/mpv_pitch_transport.dart';

class MusicPlayAudioPlayerState {
  const MusicPlayAudioPlayerState({
    required this.playing,
    required this.volume,
  });

  final bool playing;
  final double volume;
}

class MusicPlayAudioPlayerStreams {
  const MusicPlayAudioPlayerStreams({
    required this.position,
    required this.duration,
    required this.playing,
    required this.completed,
  });

  final Stream<Duration> position;
  final Stream<Duration> duration;
  final Stream<bool> playing;
  final Stream<bool> completed;
}

/// MusicPlay backend adapter.
///
/// iOS uses AVPlayer/just_audio for normal playback. When independent pitch
/// shifting is enabled, iOS switches to the app-owned native AVAudioEngine
/// player instead of mpv, so build-time mpv frameworks are not required and
/// pause/seek/pitch changes can be muted inside one serialized native queue.
class MusicPlayAudioPlayer {
  MusicPlayAudioPlayer({required bool enablePitch})
    : _usesNativeIosPlayback = !kIsWeb && Platform.isIOS && !enablePitch,
      _usesNativeIosPitchPlayback = !kIsWeb && Platform.isIOS && enablePitch,
      _usesMpvPitchTransport = !kIsWeb && !Platform.isIOS && enablePitch {
    if (_usesNativeIosPlayback) {
      final player = ja.AudioPlayer();
      _justAudio = player;
      _position = player.positionStream;
      _duration = player.durationStream
          .where((value) => value != null)
          .cast<Duration>();
      _playing = player.playerStateStream.map(
        (value) =>
            value.playing &&
            value.processingState != ja.ProcessingState.completed,
      );
      _completed = player.playerStateStream.map(
        (value) => value.processingState == ja.ProcessingState.completed,
      );
      return;
    }

    if (_usesNativeIosPitchPlayback) {
      final player = NativeIosPitchAudioPlayer();
      _nativeIosPitch = player;
      _position = player.positionStream;
      _duration = player.durationStream;
      _playing = player.playingStream;
      _completed = player.completedStream;
      return;
    }

    mk.Player? configuredPlayer;
    final player = mk.Player(
      configuration: mk.PlayerConfiguration(
        pitch: enablePitch,
        ready: _usesMpvPitchTransport
            ? () => unawaited(MpvPitchTransport.configure(configuredPlayer!))
            : null,
      ),
    );
    configuredPlayer = player;
    _mediaKit = player;
    _position = player.stream.position;
    _duration = player.stream.duration;
    _playing = player.stream.playing;
    _completed = player.stream.completed;
  }

  final bool _usesNativeIosPlayback;
  final bool _usesNativeIosPitchPlayback;
  final bool _usesMpvPitchTransport;
  ja.AudioPlayer? _justAudio;
  NativeIosPitchAudioPlayer? _nativeIosPitch;
  mk.Player? _mediaKit;
  bool _outputMuted = false;
  late final Stream<Duration> _position;
  late final Stream<Duration> _duration;
  late final Stream<bool> _playing;
  late final Stream<bool> _completed;
  double _volume = 100;

  bool get usesNativeIosPlayback => _usesNativeIosPlayback;

  bool get usesNativeIosPitchPlayback => _usesNativeIosPitchPlayback;

  bool get usesPitchTransport =>
      _usesMpvPitchTransport || _usesNativeIosPitchPlayback;

  /// Android `just_audio` 路径下可用于绑定 [Visualizer]；其它后端返回 null。
  Stream<int?>? get androidAudioSessionIdStream {
    if (_usesNativeIosPlayback) {
      return _justAudio!.androidAudioSessionIdStream;
    }
    return null;
  }

  int? get androidAudioSessionId {
    if (_usesNativeIosPlayback) {
      return _justAudio!.androidAudioSessionId;
    }
    return null;
  }

  MusicPlayAudioPlayerState get state => MusicPlayAudioPlayerState(
    playing: _usesNativeIosPlayback
        ? (_justAudio?.playing ?? false)
        : _usesNativeIosPitchPlayback
        ? (_nativeIosPitch?.playing ?? false)
        : (_mediaKit?.state.playing ?? false),
    volume: _volume,
  );

  MusicPlayAudioPlayerStreams get stream => MusicPlayAudioPlayerStreams(
    position: _position,
    duration: _duration,
    playing: _playing,
    completed: _completed,
  );

  Future<void> open(String url, {required bool play}) async {
    if (_usesNativeIosPlayback) {
      await AppAudioService.reconcilePlaybackSession();
      final player = _justAudio!;
      await player.setUrl(url);
      if (play) unawaited(player.play());
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await AppAudioService.reconcilePlaybackSession();
      await _nativeIosPitch!.open(url, play: play);
      return;
    }
    await _mediaKit!.open(mk.Media(url), play: play);
  }

  Future<void> ensureOutputMuted() async {
    if (!usesPitchTransport || _outputMuted) {
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await _nativeIosPitch!.setMuted(true);
    } else {
      await MpvPitchTransport.setMuted(_mediaKit!, true);
    }
    _outputMuted = true;
  }

  Future<void> restoreOutputAudible() async {
    if (!usesPitchTransport || !_outputMuted) {
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await _nativeIosPitch!.setMuted(false);
    } else {
      await MpvPitchTransport.setMuted(_mediaKit!, false);
    }
    _outputMuted = false;
  }

  Future<void> play() async {
    if (_usesNativeIosPlayback) {
      await AppAudioService.reconcilePlaybackSession();
      unawaited(_justAudio!.play());
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await AppAudioService.reconcilePlaybackSession();
      await _nativeIosPitch!.play();
      _outputMuted = false;
      return;
    }
    if (_usesMpvPitchTransport) {
      await MpvPitchTransport.playSmooth(_mediaKit!);
      _outputMuted = false;
      return;
    }
    await _mediaKit!.play();
  }

  Future<void> pause() async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.pause();
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await _nativeIosPitch!.pause();
      _outputMuted = true;
      return;
    }
    if (_usesMpvPitchTransport) {
      await MpvPitchTransport.pauseSmooth(_mediaKit!);
      _outputMuted = true;
      return;
    }
    await _mediaKit!.pause();
  }

  Future<void> stop() async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.stop();
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await _nativeIosPitch!.stop();
      _outputMuted = false;
      return;
    }
    await _mediaKit!.stop();
  }

  Future<void> seek(Duration position, {bool restoreAudible = true}) async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.seek(position);
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await _nativeIosPitch!.seek(position, restoreAudible: restoreAudible);
      _outputMuted = !restoreAudible;
      return;
    }
    if (_usesMpvPitchTransport) {
      await MpvPitchTransport.seekSmooth(
        _mediaKit!,
        position,
        restoreAudible: restoreAudible,
      );
      _outputMuted = !restoreAudible;
      return;
    }
    await _mediaKit!.seek(position);
  }

  Future<void> runPitchFilterChange(
    Future<void> Function() action, {
    bool restoreAudible = true,
  }) async {
    if (!usesPitchTransport) {
      await action();
      return;
    }
    final shouldRestore = restoreAudible && !_outputMuted;
    if (shouldRestore) {
      await ensureOutputMuted();
    }
    await action();
    if (shouldRestore) {
      await restoreOutputAudible();
    }
  }

  Future<void> setRate(double rate) async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.setSpeed(rate);
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await _nativeIosPitch!.setRate(rate);
      return;
    }
    await _mediaKit!.setRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    if (_usesNativeIosPlayback) return;
    if (_usesNativeIosPitchPlayback) {
      await _nativeIosPitch!.setPitch(pitch);
      return;
    }
    await _mediaKit!.setPitch(pitch);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, 100);
    if (_usesNativeIosPlayback) {
      await _justAudio!.setVolume(_volume / 100);
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await _nativeIosPitch!.setVolume(_volume);
      return;
    }
    await _mediaKit!.setVolume(_volume);
  }

  Future<void> dispose() async {
    if (_usesNativeIosPlayback) {
      await _justAudio!.dispose();
      _justAudio = null;
      return;
    }
    if (_usesNativeIosPitchPlayback) {
      await _nativeIosPitch!.dispose();
      _nativeIosPitch = null;
      return;
    }
    await _mediaKit!.dispose();
    _mediaKit = null;
  }
}

class NativeIosPitchAudioPlayer {
  NativeIosPitchAudioPlayer() {
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_pollState()),
    );
  }

  static const MethodChannel _channel = MethodChannel(
    'com.yyzl.music/music_play_pitch',
  );

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();

  Timer? _pollTimer;
  bool _disposed = false;
  int _pollGeneration = 0;
  bool playing = false;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  bool _lastCompleted = false;

  Stream<Duration> get positionStream => _position.stream;
  Stream<Duration> get durationStream => _duration.stream;
  Stream<bool> get playingStream => _playing.stream;
  Stream<bool> get completedStream => _completed.stream;

  Future<void> open(String url, {required bool play}) async {
    await _invoke('open', <String, Object>{'url': url, 'play': play});
    await _pollState();
  }

  Future<void> play() => _invoke('play');

  Future<void> pause() => _invoke('pause');

  Future<void> stop() => _invoke('stop');

  Future<void> seek(Duration position, {required bool restoreAudible}) =>
      _invoke('seek', <String, Object>{
        'positionMs': position.inMilliseconds,
        'restoreAudible': restoreAudible,
      });

  Future<void> setPitch(double pitch) =>
      _invoke('setPitch', <String, Object>{'pitch': pitch});

  Future<void> setRate(double rate) =>
      _invoke('setRate', <String, Object>{'rate': rate});

  Future<void> setVolume(double volume) =>
      _invoke('setVolume', <String, Object>{'volume': volume});

  Future<void> setMuted(bool muted) =>
      _invoke('setMuted', <String, Object>{'muted': muted});

  Future<void> dispose() async {
    _disposed = true;
    _pollGeneration += 1;
    _pollTimer?.cancel();
    _pollTimer = null;
    try {
      await _channel.invokeMethod<void>('dispose');
    } finally {
      await _position.close();
      await _duration.close();
      await _playing.close();
      await _completed.close();
    }
  }

  Future<void> _invoke(String method, [Map<String, Object>? args]) async {
    if (_disposed) return;
    await _channel.invokeMethod<void>(method, args);
    await _pollState();
  }

  Future<void> _pollState() async {
    if (_disposed) return;
    final generation = _pollGeneration;
    try {
      final state = await _channel.invokeMapMethod<String, Object?>('state');
      if (_disposed || generation != _pollGeneration || state == null) return;
      final position = Duration(
        milliseconds: (state['positionMs'] as num? ?? 0).round(),
      );
      final duration = Duration(
        milliseconds: (state['durationMs'] as num? ?? 0).round(),
      );
      final nextPlaying = state['playing'] == true;
      final completed = state['completed'] == true;

      playing = nextPlaying;
      if (position != _lastPosition) {
        _lastPosition = position;
        _position.add(position);
      }
      if (duration != _lastDuration) {
        _lastDuration = duration;
        _duration.add(duration);
      }
      _playing.add(nextPlaying);
      if (completed != _lastCompleted) {
        _lastCompleted = completed;
        _completed.add(completed);
      }
    } catch (_) {}
  }
}
