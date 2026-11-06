import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/audio/app_audio_service.dart';
import '../../../core/audio/low_latency_note_player.dart';
import '../../../core/audio/piano_note_assets.dart';
import 'web_note_audio_player_base.dart';
import 'web_note_audio_player_stub.dart'
    if (dart.library.html) 'web_note_audio_player_web.dart';

/// 智能听写音频引擎。
///
/// 重构后的核心策略（iPad 修复版）：
/// - SoLoud 的 init / AVAudioSession 全部委托给 [NativeAudioBootstrap]，
///   引擎自己只关心音源（AudioSource）的加载和播放；
/// - 不再启动时一次性加载 30 个 wav，改为「懒加载 + 后台预热」：
///   * `ensureInitialized()` 只保证 SoLoud 可用，然后立刻返回 `audioReady`；
///   * 首次 `playToken(...)` 时按需加载真正用到的那一个 wav；
///   * 同时在后台串行预热剩余 wav，让后续点击零延迟。
/// - 任何一步失败都会清空当次缓存的 Future，下一次调用即可重试。
class SmartDictationAudioEngine {
  SmartDictationAudioEngine();

  final WebNoteAudioPlayer _webPlayer = createWebNoteAudioPlayer();
  LowLatencyNotePlayer get _nativePlayer =>
      AppAudioService.sharedNativePlayer;
  final StreamController<List<double>> _frequencyController =
      StreamController<List<double>>.broadcast();
  Future<void>? _initTask;
  bool _disposed = false;

  bool get isReady => kIsWeb ? _webPlayer.isReady : !_disposed;

  Stream<List<double>> get frequencyBands =>
      kIsWeb ? _webPlayer.frequencyBands : _frequencyController.stream;

  /// Web 端准备 WebAudio；native/iOS 准备 AVAudioEngine buffer pool。
  Future<void> ensureInitialized() {
    return _initTask ??= _runEnsureInitialized();
  }

  Future<void> _runEnsureInitialized() async {
    try {
      if (kIsWeb) {
        await _webPlayer.prepare(_assetByCanonical.values);
        return;
      }
      await _nativePlayer.prepare(_initialAssetByCanonical);
      AppAudioService.markPianoCoreWarmed();
      // 后台补全剩余听写音域，避免首个题音落在非中央音区时同步解码迟播。
      unawaited(_warmUpRemainingRange());
    } catch (error, stack) {
      _initTask = null;
      debugPrint(
        'SmartDictationAudioEngine.ensureInitialized failed: $error\n$stack',
      );
      rethrow;
    }
  }

  /// 后台补全整套听写采样（除已 prepare 的中央音区外）。失败静默——
  /// 真正播到未预热的音时 [playToken] 仍会按需 prepare 兜底。
  Future<void> _warmUpRemainingRange() async {
    if (_disposed || kIsWeb) return;
    final remaining = <String, String>{
      for (final entry in _assetByCanonical.entries)
        if (!_nativePlayer.hasPrepared(entry.key)) entry.key: entry.value,
    };
    if (remaining.isEmpty) return;
    try {
      await _nativePlayer.prepare(remaining);
    } catch (error, stack) {
      debugPrint(
        'SmartDictationAudioEngine._warmUpRemainingRange failed: $error\n$stack',
      );
    }
  }

  Future<void> playToken(String token, {double volume = 1}) async {
    if (_disposed) return;
    final canonical = canonicalFromToken(token);
    if (canonical.isEmpty) return;

    if (kIsWeb) {
      final asset = _assetByCanonical[canonical];
      if (asset == null) return;
      try {
        await _webPlayer.playAsset(asset, volume: volume);
      } catch (error, stack) {
        debugPrint(
          'SmartDictationAudioEngine.playToken web $canonical failed: '
          '$error\n$stack',
        );
      }
      return;
    }

    try {
      await ensureInitialized();
      if (_disposed) return;
      await _ensureNativeTokenPrepared(canonical);
      if (_disposed) return;
      final waitForPlayback =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      await _nativePlayer.play(
        canonical,
        volume: volume,
        waitUntilFinished: waitForPlayback,
      );
    } catch (error, stack) {
      debugPrint(
        'SmartDictationAudioEngine.playToken $canonical failed: $error\n$stack',
      );
    }
  }

  Future<void> activateByUserGesture() async {
    if (kIsWeb) {
      await _webPlayer.activateByUserGesture();
      return;
    }
    try {
      await ensureInitialized();
    } catch (_) {
      // 这里允许失败：UI 层的「重试」会再次走一次。
      return;
    }
    // Native low-latency player is prepared above. Do not play a probe sound:
    // entering a lesson / challenge must stay silent.
  }

  /// iOS：其它模块（如智能视唱）切走 AVAudioSession 后，重建原生引擎。
  Future<void> reclaimNativeEngineAfterSessionChange() async {
    if (kIsWeb || _disposed) return;
    await AppAudioService.reconcilePlaybackSession();
    await _nativePlayer.pingEngine();
  }

  Future<void> playTokensHarmonic(
    List<String> tokens, {
    double volume = 1,
  }) async {
    if (_disposed) return;
    if (kIsWeb) {
      for (final token in tokens) {
        await playToken(token, volume: volume);
      }
      return;
    }
    try {
      await ensureInitialized();
    } catch (_) {
      return;
    }
    await _ensureNativeTokensPrepared(tokens);
    if (_disposed) return;
    for (final token in tokens) {
      if (_disposed) return;
      final canonical = canonicalFromToken(token);
      if (canonical.isEmpty) continue;
      if (!_assetByCanonical.containsKey(canonical)) continue;
      try {
        unawaited(_nativePlayer.play(canonical, volume: volume));
      } catch (error, stack) {
        debugPrint(
          'SmartDictationAudioEngine harmonic $canonical failed: '
          '$error\n$stack',
        );
      }
    }
  }

  Future<void> playTokensMelodic(
    List<String> tokens, {
    Duration gap = const Duration(milliseconds: 320),
    double volume = 1,
  }) async {
    if (_disposed) return;
    for (var i = 0; i < tokens.length; i++) {
      if (_disposed) return;
      await playToken(tokens[i], volume: volume);
      if (i < tokens.length - 1) {
        await Future<void>.delayed(gap);
      }
    }
  }

  Future<void> stopAll() async {
    if (kIsWeb) {
      await _webPlayer.stopAll();
      return;
    }
    await _nativePlayer.stopAll();
    _frequencyController.add(const <double>[]);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (kIsWeb) {
      await _webPlayer.dispose();
      _initTask = null;
      return;
    }
    // AppAudioService owns this player for the entire app process. Disposing
    // it here would permanently silence every later short-audio page.
    await _nativePlayer.stopAll();
    if (!_frequencyController.isClosed) {
      await _frequencyController.close();
    }
    _initTask = null;
  }

  Future<void> _ensureNativeTokenPrepared(String canonical) async {
    if (kIsWeb || canonical.isEmpty || _nativePlayer.hasPrepared(canonical)) {
      return;
    }
    final asset = _assetByCanonical[canonical];
    if (asset == null) return;
    await _nativePlayer.prepare(<String, String>{canonical: asset});
  }

  Future<void> _ensureNativeTokensPrepared(Iterable<String> tokens) async {
    if (kIsWeb) return;
    final assets = <String, String>{};
    for (final token in tokens) {
      final canonical = canonicalFromToken(token);
      if (canonical.isEmpty || _nativePlayer.hasPrepared(canonical)) {
        continue;
      }
      final asset = _assetByCanonical[canonical];
      if (asset != null) {
        assets[canonical] = asset;
      }
    }
    if (assets.isEmpty) return;
    await _nativePlayer.prepare(assets);
  }

  static List<String> splitTokenGroup(String raw) {
    final cleaned = raw.replaceAll('，', ',').replaceAll('、', ',').trim();
    if (cleaned.isEmpty) {
      return const <String>[];
    }
    return cleaned
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static String canonicalFromToken(String rawToken) {
    if (rawToken.isEmpty) {
      return '';
    }
    final normalized = _normalizeToken(rawToken);
    if (normalized.isEmpty) {
      return '';
    }

    final direct = _tokenToCanonical[normalized];
    if (direct != null) {
      return direct;
    }

    final upper = normalized.toUpperCase();
    if (_assetByCanonical.containsKey(upper)) {
      return upper;
    }
    return '';
  }

  static String _normalizeToken(String raw) {
    return raw
        .trim()
        .replaceAll('<sup>#</sup>', '#')
        .replaceAll('<sup>b</sup>', 'b')
        .replaceAll('<sup>', '')
        .replaceAll('</sup>', '')
        .replaceAll('♯', '#')
        .replaceAll('＃', '#')
        .replaceAll('♭', 'b')
        .replaceAll('Ｂ', 'b')
        .replaceAll('，', ',')
        .replaceAll('。', '')
        .replaceAll('鹿', '1')
        .replaceAll('虏', '2')
        .replaceAll(' ', '')
        .replaceAll(RegExp('[^a-zA-Z0-9#,]'), '')
        .toLowerCase();
  }

  static const List<String> _dictationNotes = <String>[
    'F3',
    'F#3',
    'G3',
    'G#3',
    'A3',
    'A#3',
    'B3',
    'C4',
    'C#4',
    'D4',
    'D#4',
    'E4',
    'F4',
    'F#4',
    'G4',
    'G#4',
    'A4',
    'A#4',
    'B4',
    'C5',
    'C#5',
    'D5',
    'D#5',
    'E5',
    'F5',
    'F#5',
    'G5',
    'G#5',
    'A5',
    'A#5',
  ];

  static final Map<String, String> _assetByCanonical = <String, String>{
    for (final note in _dictationNotes) note: kPianoNoteAssetByNote[note]!,
  };

  static Map<String, String> get _initialAssetByCanonical {
    return <String, String>{
      for (final entry in _assetByCanonical.entries)
        if (_isInitialNote(entry.key)) entry.key: entry.value,
    };
  }

  static bool _isInitialNote(String note) {
    final midi = _noteMidi(note);
    return midi >= 60 && midi <= 72; // C4..C5, includes standard tone A4.
  }

  static int _noteMidi(String note) {
    final match = RegExp(r'^([A-G]#?)(-?\d+)$').firstMatch(note);
    if (match == null) return -1;
    final name = match.group(1);
    final octave = int.tryParse(match.group(2) ?? '');
    if (name == null || octave == null) return -1;
    const pitchClass = <String, int>{
      'C': 0,
      'C#': 1,
      'D': 2,
      'D#': 3,
      'E': 4,
      'F': 5,
      'F#': 6,
      'G': 7,
      'G#': 8,
      'A': 9,
      'A#': 10,
      'B': 11,
    };
    final pc = pitchClass[name];
    if (pc == null) return -1;
    return (octave + 1) * 12 + pc;
  }

  static const Map<String, String> _tokenToCanonical = <String, String>{
    'f': 'F3',
    '#f': 'F#3',
    'g': 'G3',
    '#g': 'G#3',
    'a': 'A3',
    'bb': 'A#3',
    'a#': 'A#3',
    'b': 'B3',
    'c': 'C4',
    'c1': 'C4',
    '#c1': 'C#4',
    'd1': 'D4',
    'be1': 'D#4',
    'd#1': 'D#4',
    'e1': 'E4',
    'f1': 'F4',
    '#f1': 'F#4',
    'g1': 'G4',
    '#g1': 'G#4',
    'a1': 'A4',
    'bb1': 'A#4',
    'a#1': 'A#4',
    'b1': 'B4',
    'c2': 'C5',
    '#c2': 'C#5',
    'd2': 'D5',
    'be2': 'D#5',
    'd#2': 'D#5',
    'e2': 'E5',
    'f2': 'F5',
    '#f2': 'F#5',
    'g2': 'G5',
    '#g2': 'G#5',
    'a2': 'A5',
    'bb2': 'A#5',
    'a#2': 'A#5',
    'f3': 'F3',
    'f#3': 'F#3',
    'g3': 'G3',
    'g#3': 'G#3',
    'a3': 'A3',
    'a#3': 'A#3',
    'b3': 'B3',
    'c4': 'C4',
    'c#4': 'C#4',
    'd4': 'D4',
    'd#4': 'D#4',
    'e4': 'E4',
    'f4': 'F4',
    'f#4': 'F#4',
    'g4': 'G4',
    'g#4': 'G#4',
    'a4': 'A4',
    'a#4': 'A#4',
    'b4': 'B4',
    'c5': 'C5',
    'c#5': 'C#5',
    'd5': 'D5',
    'd#5': 'D#5',
    'e5': 'E5',
    'f5': 'F5',
    'f#5': 'F#5',
    'g5': 'G5',
    'g#5': 'G#5',
    'a5': 'A5',
    'a#5': 'A#5',
  };
}
