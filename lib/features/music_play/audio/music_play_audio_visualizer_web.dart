import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'music_play_audio_visualizer.dart';
import 'music_play_frequency_utils.dart';

MusicPlayAudioVisualizer createMusicPlayAudioVisualizer() =>
    _WebMusicPlayAudioVisualizer();

class _WebMusicPlayAudioVisualizer implements MusicPlayAudioVisualizer {
  final StreamController<List<double>> _bandsController =
      StreamController<List<double>>.broadcast();

  web.AudioContext? _context;
  web.AnalyserNode? _analyser;
  web.HTMLAudioElement? _probe;
  Timer? _ticker;
  bool _playing = false;
  List<double> _previousBands = const <double>[];
  final List<double> _globalEnvelope = <double>[0.015];

  @override
  Stream<List<double>> get bands => _bandsController.stream;

  @override
  Future<void> attach({
    required String url,
    int? androidAudioSessionId,
  }) async {
    await detach();
    resetMusicPlayVisualizerEnvelope(_globalEnvelope);
    _probe = web.HTMLAudioElement()
      ..src = url
      ..crossOrigin = 'anonymous'
      ..preload = 'auto';
    _context = web.AudioContext(
      web.AudioContextOptions(latencyHint: 'interactive'.toJS),
    );
    final analyser = _context!.createAnalyser()
      ..fftSize = 512
      ..smoothingTimeConstant = 0.22;
    final source = _context!.createMediaElementSource(_probe!);
    final silentGain = _context!.createGain()..gain.value = 0;
    source.connect(analyser);
    analyser.connect(silentGain);
    silentGain.connect(_context!.destination);
    _analyser = analyser;
  }

  @override
  Future<void> updateAndroidSession(int? sessionId) async {}

  @override
  Future<void> syncTransport({
    required bool playing,
    required int positionMs,
  }) async {
    _playing = playing;
    final probe = _probe;
    final context = _context;
    if (probe == null || context == null) return;

    if (context.state == 'suspended') {
      await context.resume().toDart;
    }

    final targetSec = positionMs / 1000.0;
    if ((probe.currentTime - targetSec).abs() > 0.35) {
      probe.currentTime = math.max(0, targetSec);
    }

    if (playing) {
      if (probe.paused) {
        await probe.play().toDart;
      }
      _startTicker();
    } else {
      probe.pause();
      _stopTicker();
    }
  }

  @override
  Future<void> detach() async {
    _stopTicker();
    _playing = false;
    _previousBands = const <double>[];
    resetMusicPlayVisualizerEnvelope(_globalEnvelope);
    _probe?.pause();
    _probe = null;
    _analyser = null;
    final context = _context;
    _context = null;
    if (context != null && context.state != 'closed') {
      await context.close().toDart;
    }
  }

  @override
  Future<void> dispose() async {
    await detach();
    await _bandsController.close();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 66), (_) {
      final analyser = _analyser;
      if (!_playing || analyser == null) {
        return;
      }
      final data = Uint8List(analyser.frequencyBinCount);
      analyser.getByteFrequencyData(data.toJS);
      final bands = compressMusicPlayFrequencyData(
        data,
        globalEnvelopeHolder: _globalEnvelope,
        previous: _previousBands,
        fftSize: analyser.fftSize,
      );
      if (bands.isEmpty) {
        return;
      }
      _previousBands = bands;
      _bandsController.add(bands);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}
