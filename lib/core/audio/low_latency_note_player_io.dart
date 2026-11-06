import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'ios_playback_volume.dart';
import 'low_latency_note_player.dart';

LowLatencyNotePlayer createPlatformLowLatencyNotePlayer() {
  return _IoLowLatencyNotePlayer();
}

class _IoLowLatencyNotePlayer implements LowLatencyNotePlayer {
  static const MethodChannel _channel = MethodChannel(
    'com.yyzl.music/low_latency_notes',
  );

  // Native iOS prepare now means "decoded and immediately playable", not just
  // "asset names registered". App-launch warmup is fire-and-forget, so allow
  // enough time for the full piano range to become genuinely ready.
  static const Duration _kPrepareTimeout = Duration(seconds: 45);
  static const Duration _kIncrementalPrepareTimeout = Duration(seconds: 5);
  static const Duration _kPlayChannelTimeout = Duration(milliseconds: 800);

  final Map<String, String> _assetByKey = <String, String>{};
  final Map<String, AudioPlayer> _fallbackPlayers = <String, AudioPlayer>{};
  final Map<String, Future<AudioPlayer?>> _fallbackLoads =
      <String, Future<AudioPlayer?>>{};
  final Set<AudioPlayer> _fallbackOneShots = <AudioPlayer>{};

  bool _nativeReady = false;
  bool _fallbackMode = false;
  bool _disposed = false;

  /// 诊断用：最近一次原生通道失败信息（屏幕诊断面板读取）。
  String? _lastNativeError;

  @override
  bool get isReady => !_disposed && (_nativeReady || _fallbackMode);

  @override
  bool get nativeReady => !_disposed && _nativeReady;

  @override
  bool get supportsImmediatePlay => _nativeReady;

  @override
  Future<Map<String, Object?>> diagnostics() async {
    final base = <String, Object?>{
      'platform': defaultTargetPlatform.name,
      'nativeReady': _nativeReady,
      'fallbackMode': _fallbackMode,
      'registeredKeys': _assetByKey.length,
      'fallbackPlayers': _fallbackPlayers.length,
      'lastNativeError': _lastNativeError,
    };
    if (defaultTargetPlatform == TargetPlatform.iOS && !_disposed) {
      try {
        final native = await _channel
            .invokeMapMethod<String, Object?>('diagnostics')
            .timeout(const Duration(seconds: 3));
        if (native != null) {
          native.forEach((key, value) => base['native_$key'] = value);
        }
      } on TimeoutException {
        base['native_error'] = 'diagnostics timed out';
      } on PlatformException catch (e) {
        base['native_error'] = 'diagnostics failed: ${e.message}';
      } on MissingPluginException {
        base['native_error'] = 'channel missing (handler not registered)';
      }
    }
    return base;
  }

  @override
  Future<void> prepare(Map<String, String> assetByKey) async {
    if (_disposed) return;
    _assetByKey.addAll(assetByKey);

    if (assetByKey.isEmpty && _assetByKey.isEmpty) {
      _nativeReady = true;
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final onlyIncremental = _nativeReady && assetByKey.isNotEmpty;
      try {
        await _channel
            .invokeMethod<void>('prepare', <String, Object>{
              'assets': assetByKey,
            })
            .timeout(
              onlyIncremental
                  ? _kIncrementalPrepareTimeout
                  : _kPrepareTimeout,
            );
        _nativeReady = true;
        _fallbackMode = false;
        _lastNativeError = null;
        return;
      } on TimeoutException catch (error, stack) {
        _lastNativeError = 'prepare timed out: $error';
        debugPrint(
          'LowLatencyNotePlayer native prepare timed out: $error\n$stack',
        );
        // 启动预加载后增量 prepare 超时不切回退：后台继续同步原生。
        if (_nativeReady) {
          unawaited(
            _channel.invokeMethod<void>('prepare', <String, Object>{
              'assets': assetByKey,
            }),
          );
          return;
        }
      } on MissingPluginException catch (error, stack) {
        _lastNativeError = 'channel missing: $error';
        debugPrint(
          'LowLatencyNotePlayer native channel missing: $error\n$stack',
        );
      } on PlatformException catch (error, stack) {
        _lastNativeError = 'prepare failed: $error';
        debugPrint(
          'LowLatencyNotePlayer native prepare failed: $error\n$stack',
        );
      }
      // iOS 永不走 just_audio 回退（专业钢琴 App 只用 AVAudioEngine）。
      return;
    }

    // Android / desktop：通道失败时回退 just_audio。
    _fallbackMode = true;
    _nativeReady = false;
  }

  @override
  Future<void> prepareEnsuringDecoded(Map<String, String> assetByKey) async {
    if (_disposed || assetByKey.isEmpty) return;
    _assetByKey.addAll(assetByKey);

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      await prepare(assetByKey);
      return;
    }

    try {
      await _channel
          .invokeMethod<void>('prepare', <String, Object>{
            'assets': assetByKey,
          })
          .timeout(_kPrepareTimeout);
      _nativeReady = true;
      _fallbackMode = false;
      _lastNativeError = null;
    } on TimeoutException catch (error, stack) {
      _lastNativeError = 'prepareEnsuringDecoded timed out: $error';
      debugPrint(
        'LowLatencyNotePlayer.prepareEnsuringDecoded timed out: '
        '$error\n$stack',
      );
      rethrow;
    } on MissingPluginException catch (error, stack) {
      _lastNativeError = 'channel missing: $error';
      debugPrint(
        'LowLatencyNotePlayer.prepareEnsuringDecoded channel missing: '
        '$error\n$stack',
      );
      rethrow;
    } on PlatformException catch (error, stack) {
      _lastNativeError = 'prepareEnsuringDecoded failed: $error';
      debugPrint(
        'LowLatencyNotePlayer.prepareEnsuringDecoded failed: $error\n$stack',
      );
      rethrow;
    }
  }

  @override
  bool hasPrepared(String key) {
    if (!_assetByKey.containsKey(key)) return false;
    if (_nativeReady) return true;
    return _fallbackPlayers.containsKey(key);
  }

  double _softwareVolume(double volume) =>
      IosPlaybackVolume.apply(volume.clamp(0.0, 1.0).toDouble());

  @override
  bool tryPlay(String key, {double volume = 1, bool metronome = false}) {
    if (_disposed || !_assetByKey.containsKey(key) || !_nativeReady) {
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final safeVolume = _softwareVolume(volume);
      // 热路径：fire-and-forget，不 await，避免排队在 handoff/prepare 之后迟播。
      _channel.invokeMethod<void>('play', <String, Object>{
        'key': key,
        'volume': safeVolume,
        'metronome': metronome,
        'waitUntilFinished': false,
      }).catchError((Object error, StackTrace stack) {
        _lastNativeError = 'tryPlay failed: $error';
        debugPrint('LowLatencyNotePlayer tryPlay failed: $error\n$stack');
      });
      return true;
    }
    unawaited(play(key, volume: volume, metronome: metronome));
    return true;
  }

  @override
  Future<void> reclaimEngine() => pingEngine();

  @override
  Future<void> pingEngine() async {
    if (_disposed || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await _channel
          .invokeMethod<void>('pingEngine')
          .timeout(const Duration(seconds: 2));
    } on TimeoutException catch (error, stack) {
      debugPrint('LowLatencyNotePlayer pingEngine timed out: $error\n$stack');
    } on PlatformException catch (error, stack) {
      debugPrint('LowLatencyNotePlayer pingEngine failed: $error\n$stack');
    } on MissingPluginException catch (error, stack) {
      debugPrint('LowLatencyNotePlayer pingEngine missing: $error\n$stack');
    }
  }

  @override
  Future<void> play(
    String key, {
    double volume = 1,
    bool metronome = false,
    bool waitUntilFinished = false,
  }) async {
    if (_disposed || !_assetByKey.containsKey(key)) return;
    final safeVolume = _softwareVolume(volume);

    if (_nativeReady) {
      try {
        await _channel
            .invokeMethod<void>('play', <String, Object>{
              'key': key,
              'volume': safeVolume,
              'metronome': metronome,
              'waitUntilFinished': waitUntilFinished,
            })
            .timeout(_kPlayChannelTimeout);
        return;
      } on PlatformException catch (error, stack) {
        debugPrint('LowLatencyNotePlayer native play failed: $error\n$stack');
      } on MissingPluginException catch (error, stack) {
        debugPrint('LowLatencyNotePlayer native play missing: $error\n$stack');
      }
    }

    final player = await _loadFallbackPlayer(key);
    if (player == null || _disposed) return;
    final asset = _assetByKey[key];
    if (asset == null) return;

    if (player.playing) {
      final oneShot = await _createFallbackPlayer(asset);
      _fallbackOneShots.add(oneShot);
      unawaited(
        _playFallback(oneShot, volume: safeVolume).whenComplete(() async {
          _fallbackOneShots.remove(oneShot);
          await oneShot.dispose();
        }),
      );
      return;
    }

    await _playFallback(player, volume: safeVolume);
  }

  Future<AudioPlayer?> _loadFallbackPlayer(String key) async {
    final cached = _fallbackPlayers[key];
    if (cached != null) return cached;
    final inflight = _fallbackLoads[key];
    if (inflight != null) return inflight;

    final asset = _assetByKey[key];
    if (asset == null) return null;
    final future = _createFallbackPlayer(asset)
        .then((player) {
          if (_disposed) {
            unawaited(player.dispose());
            return null;
          }
          _fallbackPlayers[key] = player;
          return player;
        })
        .whenComplete(() {
          _fallbackLoads.remove(key);
        });
    _fallbackLoads[key] = future;
    return future;
  }

  Future<AudioPlayer> _createFallbackPlayer(String asset) async {
    final player = AudioPlayer();
    await player.setAsset(asset);
    await player.setVolume(1);
    return player;
  }

  Future<void> _playFallback(
    AudioPlayer player, {
    required double volume,
  }) async {
    await player.setVolume(volume);
    await player.seek(Duration.zero);
    await player.play();
  }

  @override
  Future<void> stopMetronomePlaybacks() async {
    if (!_nativeReady) return;
    try {
      await _channel.invokeMethod<void>('stopMetronome');
    } catch (_) {}
  }

  @override
  Future<void> stopAll() async {
    if (_nativeReady) {
      try {
        await _channel.invokeMethod<void>('stopAll');
      } catch (_) {}
    }

    final players = <AudioPlayer>{
      ..._fallbackPlayers.values,
      ..._fallbackOneShots,
    };
    await Future.wait(
      players.map((player) => player.stop().catchError((_) {})),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_nativeReady) {
      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // iOS 的 AVAudioEngine + decoded sample buffers 是 App 级短音频资源。
          // 页面离开只停声，不销毁原生图；下一页 prepare 同一批 key 时原生层会复用
          // buffers，避免 musicPlay / 音乐伴侣反复冷解码整张钢琴。
          await _channel.invokeMethod<void>('stopAll');
        } else {
          await _channel.invokeMethod<void>('dispose');
        }
      } catch (_) {}
    }

    final players = <AudioPlayer>{
      ..._fallbackPlayers.values,
      ..._fallbackOneShots,
    };
    for (final player in players) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _fallbackPlayers.clear();
    _fallbackLoads.clear();
    _fallbackOneShots.clear();
    _assetByKey.clear();
    _nativeReady = false;
    _fallbackMode = false;
  }
}
