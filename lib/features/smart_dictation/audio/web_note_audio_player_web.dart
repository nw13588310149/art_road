import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'web_note_audio_player_base.dart';

WebNoteAudioPlayer createWebNoteAudioPlayer() => _WebNoteAudioPlayer();

class _WebNoteAudioPlayer implements WebNoteAudioPlayer {
  static const _maxVoices = 18;
  static const _baseNoteGain = 0.42;
  static const _masterLevel = 0.9;

  bool _ready = false;
  web.AudioContext? _audioContext;
  web.GainNode? _masterGain;
  web.AnalyserNode? _analyser;
  final Map<String, web.AudioBuffer> _buffersByAsset =
      <String, web.AudioBuffer>{};
  final List<_ActivePlayback> _playbackOrder = <_ActivePlayback>[];
  final Set<_ActivePlayback> _activePlaybacks = <_ActivePlayback>{};
  final StreamController<List<double>> _frequencyController =
      StreamController<List<double>>.broadcast();
  Timer? _visualTicker;

  @override
  bool get isReady => _ready;

  @override
  Stream<List<double>> get frequencyBands => _frequencyController.stream;

  web.AudioContext _ensureContext() {
    final existing = _audioContext;
    if (existing != null) {
      return existing;
    }
    final context = web.AudioContext(
      web.AudioContextOptions(latencyHint: 'interactive'.toJS),
    );
    final master = context.createGain()..gain.value = _masterLevel;
    final analyser = context.createAnalyser()
      ..fftSize = 512
      ..smoothingTimeConstant = 0.76;
    master.connect(analyser);
    analyser.connect(context.destination);
    _audioContext = context;
    _masterGain = master;
    _analyser = analyser;
    return context;
  }

  @override
  Future<void> prepare(Iterable<String> assets) async {
    final uniqueAssets = assets.toSet().toList(growable: false);
    if (_ready && uniqueAssets.every(_buffersByAsset.containsKey)) {
      return;
    }

    final context = _ensureContext();
    await Future.wait(
      uniqueAssets.map((asset) async {
        if (_buffersByAsset.containsKey(asset)) {
          return;
        }
        final byteData = await rootBundle.load(asset);
        final bytes = Uint8List.fromList(Uint8List.sublistView(byteData));
        final buffer = await context.decodeAudioData(bytes.buffer.toJS).toDart;
        _buffersByAsset[asset] = buffer;
      }),
    );
    _ready = true;
  }

  @override
  Future<void> activateByUserGesture() async {
    final context = _ensureContext();
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
  }

  @override
  Future<void> playAsset(String asset, {double volume = 1}) async {
    final buffer = _buffersByAsset[asset];
    if (buffer == null) {
      return;
    }

    _purgeFinishedPlaybacks();
    if (_playbackOrder.length >= _maxVoices) {
      await _releasePlayback(_playbackOrder.first, fadeMs: 12);
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
      ..gain.value = _scaledVolume(volume.clamp(0.0, 1.0));

    source.connect(gain);
    gain.connect(master);

    final playback = _ActivePlayback(source: source, gain: gain);
    _activePlaybacks.add(playback);
    _playbackOrder.add(playback);
    _startVisualTicker();

    source.addEventListener(
      'ended',
      ((web.Event _) {
        _cleanupPlayback(playback);
      }).toJS,
    );

    source.start();
  }

  @override
  Future<void> stopAll() async {
    final targets = List<_ActivePlayback>.from(_playbackOrder);
    await Future.wait(
      targets.map((playback) => _releasePlayback(playback, fadeMs: 90)),
    );
    _stopVisualTicker();
  }

  @override
  Future<void> dispose() async {
    await stopAll();
    _buffersByAsset.clear();
    _ready = false;
    await _frequencyController.close();

    final context = _audioContext;
    _audioContext = null;
    _masterGain = null;
    _analyser = null;
    if (context != null && context.state != 'closed') {
      await context.close().toDart;
    }
  }

  double _scaledVolume(double requested) {
    final voices = math.max(1, _activePlaybacks.length);
    final headroom = 0.9 / math.sqrt(voices.clamp(1, 32).toDouble());
    return requested * _baseNoteGain * headroom;
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

    if (_activePlaybacks.isEmpty) {
      _stopVisualTicker();
    }
  }

  void _startVisualTicker() {
    _visualTicker ??= Timer.periodic(const Duration(milliseconds: 66), (_) {
      final analyser = _analyser;
      if (analyser == null || _activePlaybacks.isEmpty) {
        _frequencyController.add(const <double>[]);
        return;
      }
      final data = Uint8List(analyser.frequencyBinCount);
      analyser.getByteFrequencyData(data.toJS);
      _frequencyController.add(_compressFrequencyData(data));
    });
  }

  void _stopVisualTicker() {
    _visualTicker?.cancel();
    _visualTicker = null;
    if (!_frequencyController.isClosed) {
      _frequencyController.add(const <double>[]);
    }
  }

  List<double> _compressFrequencyData(List<int> data) {
    const bands = 46;
    if (data.isEmpty) {
      return const <double>[];
    }
    final result = List<double>.filled(bands, 0);
    for (var i = 0; i < bands; i++) {
      final start = math.pow(i / bands, 1.55) * (data.length - 1);
      final end = math.pow((i + 1) / bands, 1.55) * (data.length - 1);
      final from = start.floor().clamp(0, data.length - 1);
      final to = math.max(from + 1, end.ceil().clamp(0, data.length));
      var sum = 0.0;
      for (var j = from; j < to; j++) {
        sum += data[j] / 255.0;
      }
      final average = sum / (to - from);
      result[i] = math.pow((average * 2.8).clamp(0.0, 1.0), 0.58) as double;
    }
    return result;
  }
}

class _ActivePlayback {
  _ActivePlayback({required this.source, required this.gain});

  final web.AudioBufferSourceNode source;
  final web.GainNode gain;
  bool released = false;
}
