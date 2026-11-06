import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/audio/native_playback_audio_session.dart';
import '../../../core/audio/app_audio_service.dart';
import '../config/smart_sight_singing_config.dart';
import '../config/smart_sight_singing_tuning.dart';
import 'live_pitch_detector.dart';
import 'realtime_pitch_capture.dart';

class _IORealtimePitchCapture implements RealtimePitchCapture {
  _IORealtimePitchCapture({required this.profile})
    : _frameBuffer = Uint8List(
        SmartSightSingingRealtimePitchConfig.bufferSize * 2,
      ),
      _detector = LivePitchDetector(
        sampleRate: SmartSightSingingRealtimePitchConfig.sampleRate.toDouble(),
        bufferSize: SmartSightSingingRealtimePitchConfig.bufferSize,
      );

  final RealtimePitchCaptureProfile profile;

  final AudioRecorder _recorder = AudioRecorder();
  final LivePitchDetector _detector;
  final Uint8List _frameBuffer;

  StreamSubscription<Uint8List>? _streamSub;
  StreamController<RealtimePitchEvent>? _controller;
  int _filledBytes = 0;
  bool _running = false;
  bool _detectInFlight = false;
  Uint8List? _pendingFrame;

  @override
  bool get isRunning => _running;

  @override
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted || status.isLimited) return true;
    return _recorder.hasPermission();
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted || status.isLimited) return true;
    return _recorder.hasPermission();
  }

  RecordConfig get _recordConfig {
    return const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: SmartSightSingingRealtimePitchConfig.sampleRate,
      numChannels: 1,
      echoCancel: false,
      noiseSuppress: false,
    );
  }

  @override
  Future<Stream<RealtimePitchEvent>> start() async {
    if (_running) {
      throw StateError('RealtimePitchCapture already running');
    }
    var allowed = await hasPermission();
    if (!allowed) {
      allowed = await requestPermission();
    }
    if (!allowed) {
      throw StateError('录音权限被拒绝');
    }

    // 与音乐伴侣调音器相同：measurement + 外放；跟唱时加 mixWithOthers。
    try {
      await NativePlaybackAudioSession.ensureSightSingingCaptureActive();
    } catch (_) {}

    final pcmStream = await _recorder.startStream(_recordConfig);

    final controller = StreamController<RealtimePitchEvent>(
      onCancel: () async {
        await stop();
      },
    );
    _controller = controller;
    _filledBytes = 0;
    _detectInFlight = false;
    _pendingFrame = null;
    _running = true;

    _streamSub = pcmStream.listen(
      (chunk) => _consumeChunk(chunk, controller),
      onError: (Object error, StackTrace stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      },
      onDone: () async {
        await stop();
      },
      cancelOnError: false,
    );

    return controller.stream;
  }

  void _consumeChunk(
    Uint8List chunk,
    StreamController<RealtimePitchEvent> out,
  ) {
    var offset = 0;
    while (offset < chunk.length) {
      final need = _frameBuffer.length - _filledBytes;
      final available = chunk.length - offset;
      final take = available < need ? available : need;
      _frameBuffer.setRange(_filledBytes, _filledBytes + take, chunk, offset);
      _filledBytes += take;
      offset += take;
      if (_filledBytes == _frameBuffer.length) {
        final frame = Uint8List.fromList(_frameBuffer);
        _filledBytes = 0;
        _enqueueFrame(frame, out);
      }
    }
  }

  void _enqueueFrame(
    Uint8List frame,
    StreamController<RealtimePitchEvent> out,
  ) {
    if (_detectInFlight) {
      _pendingFrame = frame;
      return;
    }
    _runDetect(frame, out);
  }

  void _runDetect(
    Uint8List frame,
    StreamController<RealtimePitchEvent> out,
  ) {
    _detectInFlight = true;
    unawaited(
      _emitFrame(frame, out).whenComplete(() {
        if (!_running) {
          _detectInFlight = false;
          _pendingFrame = null;
          return;
        }
        final pending = _pendingFrame;
        _pendingFrame = null;
        if (pending != null) {
          _runDetect(pending, out);
        } else {
          _detectInFlight = false;
        }
      }),
    );
  }

  Future<void> _emitFrame(
    Uint8List frame,
    StreamController<RealtimePitchEvent> out,
  ) async {
    if (!_running || out.isClosed) return;

    final amplitude = _measureAmplitude(frame);
    if (amplitude.rms < SightSingingTuning.instance.realtimeMinRms) {
      out.add(
        RealtimePitchEvent(
          frequencyHz: 0,
          midi: -1,
          confidence: 0,
          amplitude: amplitude.normalized,
          pitched: false,
        ),
      );
      return;
    }

    final result = await _detector.analyzePcm16Frame(frame);
    if (!_running || out.isClosed) return;

    final minConf = SightSingingTuning.instance.frameMinConfidence;
    if (result.pitched &&
        result.midi.isFinite &&
        result.confidence >= minConf) {
      out.add(
        RealtimePitchEvent(
          frequencyHz: result.frequencyHz,
          midi: result.midi,
          confidence: result.confidence,
          amplitude: amplitude.normalized,
          pitched: true,
        ),
      );
      return;
    }

    out.add(
      RealtimePitchEvent(
        frequencyHz: 0,
        midi: -1,
        confidence: 0,
        amplitude: amplitude.normalized,
        pitched: false,
      ),
    );
  }

  _AmplitudeSnapshot _measureAmplitude(Uint8List frame) {
    final view = ByteData.sublistView(frame);
    var sumSq = 0.0;
    var peak = 0.0;
    final n = frame.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final s = view.getInt16(i * 2, Endian.little).toDouble();
      sumSq += s * s;
      final abs = s.abs();
      if (abs > peak) peak = abs;
    }
    final rms = math.sqrt(sumSq / n);
    final peakNorm = (peak / 32767.0).clamp(0.0, 1.0);
    final rmsNorm =
        (rms / SmartSightSingingRealtimePitchConfig.amplitudeRmsDivisor).clamp(
          0.0,
          1.0,
        );
    return _AmplitudeSnapshot(
      rms: rms,
      normalized: math.max(
        peakNorm * SmartSightSingingRealtimePitchConfig.amplitudePeakWeight,
        rmsNorm,
      ),
    );
  }

  @override
  Future<void> stop({bool restorePlaybackSession = true}) async {
    if (!_running) return;
    _running = false;
    await _streamSub?.cancel();
    _streamSub = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    _filledBytes = 0;
    _detectInFlight = false;
    _pendingFrame = null;
    if (restorePlaybackSession) {
      await AppAudioService.reconcilePlaybackSession();
    }
  }
}

class _AmplitudeSnapshot {
  const _AmplitudeSnapshot({required this.rms, required this.normalized});
  final double rms;
  final double normalized;
}

RealtimePitchCapture createPlatformRealtimePitchCapture({
  RealtimePitchCaptureProfile profile = RealtimePitchCaptureProfile.general,
}) => _IORealtimePitchCapture(profile: profile);
