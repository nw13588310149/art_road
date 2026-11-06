import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/audio/app_audio_service.dart';
import '../../../core/audio/ios_piano_bootstrap.dart';
import '../../../core/audio/low_latency_note_player.dart';
import 'music_companion_audio_catalog.dart';
import 'music_companion_web_audio_player_base.dart';
import 'music_companion_web_audio_player_stub.dart'
    if (dart.library.html) 'music_companion_web_audio_player_web.dart';

/// 启动时预加载钢琴 + 节拍器（iOS 常驻 AVAudioEngine 采样）。
Future<void> warmupMusicCompanionPianoAudio() =>
    IosPianoBootstrap.warmAtAppLaunch();

/// 音乐伴侣 / musicPlay 钢琴引擎（薄封装，共享 [AppAudioService.sharedNativePlayer]）。
class MusicCompanionAudioEngine {
  final MusicCompanionWebAudioPlayer _webPlayer =
      createMusicCompanionWebAudioPlayer();

  LowLatencyNotePlayer get _nativePlayer =>
      AppAudioService.sharedNativePlayer;

  Future<void>? _pianoInitTask;
  Future<void>? _metronomeInitTask;
  bool _disposed = false;

  bool get isReady => kIsWeb ? _webPlayer.isReady : !_disposed;

  bool get isPianoReady => kIsWeb ? _webPlayer.isReady : _nativePlayer.isReady;

  static Future<void> primeAfterForeignAudioSession(
    MusicCompanionAudioEngine engine,
  ) {
    return AppAudioService.enterPianoPage(
      prepareAssets: () => engine.ensurePianoInitialized(),
    );
  }

  static Future<void> recoverNativePianoAfterMediaKit(
    MusicCompanionAudioEngine engine, {
    bool softMediaKitSession = false,
  }) {
    return AppAudioService.recoverPianoAfterMediaKit(
      ensurePrepared: () => engine.ensurePianoInitialized(),
    );
  }

  Future<void> ensureInitialized() => ensurePianoInitialized();

  Future<void> ensurePianoInitialized() {
    return _pianoInitTask ??= _runEnsurePianoInitialized();
  }

  Future<void> reclaimNativeEngineAfterSessionChange() =>
      reclaimNativeGraphAfterSessionChange();

  Future<void> reclaimNativeGraphAfterSessionChange({
    bool restorePlaybackSession = true,
  }) async {
    if (_disposed || kIsWeb) return;
    if (restorePlaybackSession) {
      await AppAudioService.reconcilePlaybackSession();
    }
    await _nativePlayer.pingEngine();
    // 会话切换后强制下次播放前重新 ensure 节拍器采样。
    _metronomeInitTask = null;
  }

  Future<void> _runEnsurePianoInitialized() async {
    try {
      if (kIsWeb) {
        await _webPlayer.prepare(kMusicCompanionPianoAssetByNote.values);
        return;
      }
      if (AppAudioService.isNativePianoReady) {
        return;
      }
      await _nativePlayer.prepare(_initialPianoAssetByNote);
      AppAudioService.markPianoCoreWarmed();
      unawaited(_warmUpRemainingPianoRange());
    } catch (error, stack) {
      _pianoInitTask = null;
      debugPrint(
        'MusicCompanionAudioEngine.ensurePianoInitialized failed: '
        '$error\n$stack',
      );
      rethrow;
    }
  }

  Future<void> _warmUpRemainingPianoRange() async {
    if (_disposed || kIsWeb) return;
    final remaining = <String, String>{
      for (final entry in kMusicCompanionPianoAssetByNote.entries)
        if (!_nativePlayer.hasPrepared(entry.key)) entry.key: entry.value,
    };
    if (remaining.isEmpty) return;
    try {
      await _nativePlayer.prepare(remaining);
    } catch (error, stack) {
      debugPrint(
        'MusicCompanionAudioEngine._warmUpRemainingPianoRange failed: '
        '$error\n$stack',
      );
    }
  }

  Future<void> ensureMetronomeInitialized() {
    return _metronomeInitTask ??= _runEnsureMetronomeInitialized();
  }

  Future<void> _runEnsureMetronomeInitialized() async {
    try {
      if (kIsWeb) {
        await _webPlayer.prepare(kMusicCompanionMetronomeAssetByCue.values);
        return;
      }
      await _nativePlayer.prepareEnsuringDecoded(_metronomeAssetByKey);
    } catch (error, stack) {
      _metronomeInitTask = null;
      debugPrint(
        'MusicCompanionAudioEngine.ensureMetronomeInitialized failed: '
        '$error\n$stack',
      );
      rethrow;
    }
  }

  bool tryPlayNoteFromUserGesture(String rawNote, {double volume = 1}) {
    if (_disposed || kIsWeb) return false;
    return AppAudioService.playPianoFromGesture(
      _normalizeNote(rawNote),
      volume: volume,
    );
  }

  bool tryPlayMetronomeCueFromUserGesture(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) {
    if (_disposed || kIsWeb) return false;
    return AppAudioService.playPianoFromGesture(
      _metronomeKey(cue),
      volume: volume,
      metronome: true,
    );
  }

  Future<void> activateByUserGesture() async {
    if (kIsWeb) {
      await _webPlayer.activateByUserGesture();
      return;
    }
    try {
      await ensurePianoInitialized();
    } catch (_) {
      return;
    }
  }

  Future<void> playNote(String rawNote, {double volume = 1}) async {
    if (_disposed) return;
    final note = _normalizeNote(rawNote);
    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null) return;

    if (kIsWeb) {
      try {
        await ensurePianoInitialized();
      } catch (_) {
        return;
      }
      if (_disposed) return;
      try {
        await _webPlayer.playAsset(asset, volume: volume, metronome: false);
      } catch (error, stack) {
        debugPrint(
          'MusicCompanionAudioEngine.playNote web $note failed: $error\n$stack',
        );
      }
      return;
    }

    try {
      await AppAudioService.prepareForPianoKeypress();
      await ensurePianoInitialized();
      if (_disposed) return;
      await _ensureNativePianoNotePrepared(note);
      if (_disposed) return;
      if (_nativePlayer.tryPlay(note, volume: volume, metronome: false)) {
        return;
      }
      await _nativePlayer.play(note, volume: volume, metronome: false);
    } catch (error, stack) {
      debugPrint(
        'MusicCompanionAudioEngine.playNote $note failed: $error\n$stack',
      );
    }
  }

  Future<void> playNotes(Iterable<String> notes, {double volume = 1}) async {
    if (_disposed) return;
    if (!kIsWeb) {
      final normalized = notes.map(_normalizeNote).toList(growable: false);
      await ensurePianoInitialized();
      await _ensureNativePianoNotesPrepared(normalized);
      if (_disposed) return;
      await Future.wait(
        normalized.map((note) => playNote(note, volume: volume)),
      );
      return;
    }
    await Future.wait(notes.map((note) => playNote(note, volume: volume)));
  }

  Future<void> playMetronomeCue(
    MusicCompanionMetronomeCue cue, {
    double volume = 1,
  }) async {
    if (_disposed) return;
    final asset = kMusicCompanionMetronomeAssetByCue[cue];
    if (asset == null) return;

    if (kIsWeb) {
      try {
        await ensureMetronomeInitialized();
      } catch (_) {
        return;
      }
      if (_disposed) return;
      try {
        await _webPlayer.playAsset(asset, volume: volume, metronome: true);
      } catch (error, stack) {
        debugPrint(
          'MusicCompanionAudioEngine.playMetronomeCue web $cue failed: '
          '$error\n$stack',
        );
      }
      return;
    }

    try {
      await ensureMetronomeInitialized();
      if (_disposed) return;
      final key = _metronomeKey(cue);
      await _nativePlayer.play(key, volume: volume, metronome: true);
    } catch (error, stack) {
      debugPrint(
        'MusicCompanionAudioEngine.playMetronomeCue $cue failed: $error\n$stack',
      );
    }
  }

  Future<void> stopMetronomePlaybacks() async {
    if (_disposed) return;
    if (kIsWeb) {
      await _webPlayer.stopMetronomePlaybacks();
      return;
    }
    await _nativePlayer.stopMetronomePlaybacks();
  }

  Future<void> stopAll() async {
    if (kIsWeb) {
      await _webPlayer.stopAll();
      return;
    }
    await _nativePlayer.stopAll();
  }

  void stopAllImmediately() {
    unawaited(stopAll());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopAll();

    if (kIsWeb) {
      await _webPlayer.dispose();
      _pianoInitTask = null;
      _metronomeInitTask = null;
      return;
    }
    // iOS：共享原生图，页面 dispose 只停声，不销毁 buffers。
    _pianoInitTask = null;
    _metronomeInitTask = null;
  }

  String _normalizeNote(String rawNote) {
    return rawNote.trim().replaceAll('♯', '#').toUpperCase();
  }

  Future<void> _ensureNativePianoNotePrepared(String note) async {
    if (kIsWeb || _nativePlayer.hasPrepared(note)) return;
    final asset = kMusicCompanionPianoAssetByNote[note];
    if (asset == null) return;
    await _nativePlayer.prepare(<String, String>{note: asset});
  }

  Future<void> _ensureNativePianoNotesPrepared(Iterable<String> notes) async {
    if (kIsWeb) return;
    final assets = <String, String>{};
    for (final note in notes) {
      if (_nativePlayer.hasPrepared(note)) continue;
      final asset = kMusicCompanionPianoAssetByNote[note];
      if (asset != null) {
        assets[note] = asset;
      }
    }
    if (assets.isEmpty) return;
    await _nativePlayer.prepare(assets);
  }

  static Map<String, String> get _metronomeAssetByKey {
    return <String, String>{
      for (final entry in kMusicCompanionMetronomeAssetByCue.entries)
        _metronomeKey(entry.key): entry.value,
    };
  }

  static String _metronomeKey(MusicCompanionMetronomeCue cue) {
    return 'metronome.${cue.name}';
  }

  static Map<String, String> get _initialPianoAssetByNote {
    return <String, String>{
      for (final entry in kMusicCompanionPianoAssetByNote.entries)
        if (_isInitialPianoNote(entry.key)) entry.key: entry.value,
    };
  }

  static bool _isInitialPianoNote(String note) {
    final midi = _noteMidi(note);
    return midi >= 60 && midi <= 72;
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
}
