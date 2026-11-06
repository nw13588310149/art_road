import 'dart:async';

import 'music_play_audio_visualizer.dart';
import 'music_play_frequency_utils.dart';

MusicPlayAudioVisualizer createMusicPlayAudioVisualizer() =>
    _NativeMusicPlayAudioVisualizer();

class _NativeMusicPlayAudioVisualizer implements MusicPlayAudioVisualizer {
  final StreamController<List<double>> _bandsController =
      StreamController<List<double>>.broadcast();

  StreamSubscription<dynamic>? _eventSub;
  String _attachedUrl = '';
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
    _attachedUrl = url;
    resetMusicPlayVisualizerEnvelope(_globalEnvelope);
    _eventSub ??= kMusicPlayVisualizerEventChannel.receiveBroadcastStream().listen(
      (event) {
        final bands = polishMusicPlayVisualizerBands(
          parseMusicPlayVisualizerBandEvent(event),
          globalEnvelopeHolder: _globalEnvelope,
          previous: _previousBands,
        );
        if (bands.isEmpty) {
          return;
        }
        _previousBands = bands;
        if (!_bandsController.isClosed) {
          _bandsController.add(bands);
        }
      },
      onError: (_) {},
    );
    await kMusicPlayVisualizerMethodChannel.invokeMethod<void>('attach', {
      'url': url,
      'androidAudioSessionId': ?androidAudioSessionId,
    });
  }

  @override
  Future<void> updateAndroidSession(int? sessionId) async {
    if (_attachedUrl.isEmpty) return;
    await kMusicPlayVisualizerMethodChannel.invokeMethod<void>(
      'updateAndroidSession',
      {'androidAudioSessionId': sessionId ?? 0},
    );
  }

  @override
  Future<void> syncTransport({
    required bool playing,
    required int positionMs,
  }) async {
    if (_attachedUrl.isEmpty) return;
    await kMusicPlayVisualizerMethodChannel.invokeMethod<void>('syncTransport', {
      'playing': playing,
      'positionMs': positionMs,
    });
  }

  @override
  Future<void> detach() async {
    _attachedUrl = '';
    _previousBands = const <double>[];
    resetMusicPlayVisualizerEnvelope(_globalEnvelope);
    try {
      await kMusicPlayVisualizerMethodChannel.invokeMethod<void>('detach');
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await detach();
    await _eventSub?.cancel();
    _eventSub = null;
    await _bandsController.close();
  }
}
