import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../../../core/audio/piano_playback_mix.dart';
import 'music_companion_web_audio_player_base.dart';

MusicCompanionWebAudioPlayer createMusicCompanionWebAudioPlayer() {
  return _MusicCompanionWebAudioPlayer();
}

class _MusicCompanionWebAudioPlayer implements MusicCompanionWebAudioPlayer {
  web.AudioContext? _audioContext;
  web.GainNode? _masterGain;
  final Map<String, web.AudioBuffer> _buffersByAsset =
      <String, web.AudioBuffer>{};
  final List<_ActivePlayback> _playbackOrder = <_ActivePlayback>[];
  final Set<_ActivePlayback> _activePlaybacks = <_ActivePlayback>{};
  final Set<String> _requestedAssets = <String>{};

  bool _ready = false;
  Future<void>? _prepareTask;

  @override
  bool get isReady => _ready;

  web.AudioContext _ensureContext() {
    final existing = _audioContext;
    if (existing != null) {
      return existing;
    }
    final context = web.AudioContext(
      web.AudioContextOptions(latencyHint: 'interactive'.toJS),
    );
    final master = context.createGain()
      ..gain.value = PianoPlaybackMix.masterLevel;
    master.connect(context.destination);
    _audioContext = context;
    _masterGain = master;
    return context;
  }

  @override
  Future<void> prepare(Iterable<String> assets) {
    _requestedAssets.addAll(assets);
    if (_requestedAssets.every(_buffersByAsset.containsKey)) {
      _ready = true;
      return Future<void>.value();
    }

    return _prepareTask ??= _prepareRequestedAssets().whenComplete(() {
      _prepareTask = null;
    });
  }

  Future<void> _prepareRequestedAssets() async {
    final context = _ensureContext();
    while (_requestedAssets.any((asset) => !_buffersByAsset.containsKey(asset))) {
      final pending = _requestedAssets
          .where((asset) => !_buffersByAsset.containsKey(asset))
          .toList(growable: false);
      await Future.wait(
        pending.map((asset) => _decodeAsset(context, asset)),
      );
    }
    _ready = true;
  }

  Future<void> _decodeAsset(web.AudioContext context, String asset) async {
    final byteData = await rootBundle.load(asset);
    final bytes = Uint8List.fromList(Uint8List.sublistView(byteData));
    final buffer = await context.decodeAudioData(bytes.buffer.toJS).toDart;
    _buffersByAsset[asset] = buffer;
  }

  @override
  Future<void> activateByUserGesture() async {
    final context = _ensureContext();
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
  }

  @override
  Future<void> playAsset(
    String asset, {
    double volume = 1,
    bool metronome = false,
  }) async {
    final buffer = _buffersByAsset[asset];
    if (buffer == null) {
      return;
    }

    _purgeFinishedPlaybacks();
    if (_activePlaybackCount >= PianoPlaybackMix.maxVoices) {
      await _releasePlayback(_playbackOrder.first, fadeMs: PianoPlaybackMix.voiceStealFadeMs);
    }

    final context = _ensureContext();
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }

    final master = _masterGain;
    if (master == null) {
      return;
    }

    final source = context.createBufferSource()..buffer = buffer;
    final gain = context.createGain()
      ..gain.value = PianoPlaybackMix.noteGain(
        requested: volume.clamp(0.0, 1.0),
      );

    source.connect(gain);
    gain.connect(master);

    final playback = _ActivePlayback(
      source: source,
      gain: gain,
      metronome: metronome,
    );
    _activePlaybacks.add(playback);
    _playbackOrder.add(playback);

    source.addEventListener(
      'ended',
      ((web.Event _) {
        _cleanupPlayback(playback);
      }).toJS,
    );

    source.start();
  }

  int get _activePlaybackCount =>
      _activePlaybacks.where((p) => !p.released).length;

  @override
  Future<void> stopMetronomePlaybacks() async {
    final targets = _playbackOrder
        .where((playback) => playback.metronome)
        .toList(growable: false);
    await Future.wait(
      targets.map(
        (playback) => _releasePlayback(
          playback,
          fadeMs: PianoPlaybackMix.metronomeStopFadeMs,
        ),
      ),
    );
  }

  @override
  Future<void> stopAll() async {
    final targets = List<_ActivePlayback>.from(_playbackOrder);
    await Future.wait(
      targets.map(
        (playback) => _releasePlayback(
          playback,
          fadeMs: PianoPlaybackMix.stopAllFadeMs,
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await stopAll();
    _buffersByAsset.clear();
    _requestedAssets.clear();
    _ready = false;

    final context = _audioContext;
    _audioContext = null;
    _masterGain = null;
    if (context != null && context.state != 'closed') {
      await context.close().toDart;
    }
  }

  void _purgeFinishedPlaybacks() {
    final stale = _playbackOrder
        .where((playback) => playback.released)
        .toList(growable: false);
    for (final playback in stale) {
      _detachPlayback(playback);
    }
  }

  Future<void> _releasePlayback(
    _ActivePlayback playback, {
    required int fadeMs,
  }) async {
    if (!_activePlaybacks.contains(playback) || playback.released) {
      return;
    }
    playback.released = true;

    if (fadeMs <= 0) {
      _detachPlayback(playback);
      return;
    }

    final context = _audioContext;
    if (context == null) {
      _detachPlayback(playback);
      return;
    }

    final fadeSec = fadeMs / 1000.0;
    final now = context.currentTime;
    final gainParam = playback.gain.gain;
    try {
      gainParam.cancelScheduledValues(now);
      gainParam.setValueAtTime(gainParam.value, now);
      gainParam.linearRampToValueAtTime(0.0001, now + fadeSec);
    } catch (_) {}

    await Future<void>.delayed(Duration(milliseconds: fadeMs + 20));
    _detachPlayback(playback);
  }

  void _cleanupPlayback(_ActivePlayback playback) {
    if (playback.released) {
      return;
    }
    playback.released = true;
    _detachPlayback(playback);
  }

  void _detachPlayback(_ActivePlayback playback) {
    if (!_activePlaybacks.remove(playback)) {
      return;
    }
    _playbackOrder.remove(playback);

    try {
      playback.source.disconnect();
    } catch (_) {}
    try {
      playback.gain.disconnect();
    } catch (_) {}
  }
}

class _ActivePlayback {
  _ActivePlayback({
    required this.source,
    required this.gain,
    required this.metronome,
  });

  final web.AudioBufferSourceNode source;
  final web.GainNode gain;
  final bool metronome;
  bool released = false;
}
