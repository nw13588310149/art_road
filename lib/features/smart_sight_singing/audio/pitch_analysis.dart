import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

import '../../../core/audio/native_audio_bootstrap.dart';
import '../config/smart_sight_singing_config.dart';
import 'pitch_analysis_temp_io.dart'
    if (dart.library.html) 'pitch_analysis_temp_web.dart';
import 'pitch_soloud_samples.dart';
import 'pitch_track.dart';
import 'pitch_wav_decoder.dart';
import 'ktv_pitch_guide.dart';
import 'pcm_pitch_utils.dart';

/// Smart sight-singing offline pitch analysis (flutter_soloud + YIN).
abstract final class SightSingingPitchAnalyzer {
  static const int analysisSampleRate =
      SmartSightSingingOfflineAnalysisConfig.analysisSampleRate;
  static const int yinBufferSize =
      SmartSightSingingOfflineAnalysisConfig.yinBufferSize;
  static const int yinHopSize =
      SmartSightSingingOfflineAnalysisConfig.yinHopSize;

  static const String _msgWebNoPath =
      'Web \u7aef\u6682\u4e0d\u652f\u6301\u4ece\u672c\u5730\u8def\u5f84\u5206\u6790\u97f3\u9891\uff0c'
      '\u8bf7\u4f7f\u7528 iPad \u6216\u91cd\u65b0\u9009\u62e9\u6586\u4ef6\u3002';
  static const String _msgReadFailed =
      '\u65e0\u6cd5\u8bfb\u53d6\u97f3\u9891\u6570\u636e\uff0c\u8bf7\u6362\u4e00\u9996\u6b4c\u8bd5\u8bd5\u3002';
  static const String _msgDecodeFailed =
      '\u97f3\u9891\u89e3\u7801\u5931\u8d25\uff0c\u8bf7\u786e\u8ba4\u6586\u4ef6\u683c\u5f0f\u4e3a mp3 / m4a / wav / aac\u3002';

  static Future<PitchTrack> analyzeFile(
    String path, {
    Duration? durationHint,
  }) async {
    if (kIsWeb) {
      throw PitchAnalysisException(_msgWebNoPath);
    }
    try {
      final bytes = await PitchAnalysisTempFile.read(path);
      return analyzeBytes(
        bytes,
        formatHint: _normalizeExt(
          path.contains('.') ? path.split('.').last : 'mp3',
        ),
        durationHint: durationHint,
      );
    } on PitchAnalysisException {
      rethrow;
    } on SoLoudException catch (error) {
      throw PitchAnalysisException(_mapSoLoudError(error));
    } catch (error) {
      throw PitchAnalysisException('$_msgDecodeFailed ($error)');
    }
  }

  static Future<PitchTrack> analyzeBytes(
    Uint8List bytes, {
    required String formatHint,
    Duration? durationHint,
  }) async {
    if (bytes.isEmpty) {
      throw PitchAnalysisException(_msgReadFailed);
    }

    try {
      final decoded = await _decodeBytes(
        bytes,
        formatHint: formatHint,
        durationHint: durationHint,
      );
      return _analyzeFloatSamples(
        decoded.samples,
        analysisDuration: decoded.duration,
        playbackDuration: decoded.playbackDuration,
      );
    } on PitchAnalysisException {
      rethrow;
    } on SoLoudException catch (error) {
      throw PitchAnalysisException(_mapSoLoudError(error));
    } catch (error) {
      throw PitchAnalysisException('$_msgDecodeFailed ($error)');
    }
  }

  static Future<_DecodedAudioSamples> _decodeBytes(
    Uint8List bytes, {
    required String formatHint,
    Duration? durationHint,
  }) async {
    final ext = _normalizeExt(formatHint);

    // WAV：纯 Dart 解码，绕开 flutter_soloud 在 compute isolate 里的 FFI 崩溃。
    if (ext == 'wav' || PitchWavDecoder.looksLikeWav(bytes)) {
      try {
        final wav = PitchWavDecoder.decode(
          bytes,
          targetSampleRate: analysisSampleRate,
        );
        if (wav.samples.isEmpty) {
          throw PitchAnalysisException(_msgReadFailed);
        }
        return _DecodedAudioSamples(
          samples: wav.samples,
          // 分析用解码时长；若 media_kit 探测到播放时长，在 YIN 阶段再对齐时间轴。
          duration: wav.duration,
          playbackDuration: durationHint,
        );
      } on PitchWavDecodeException catch (error) {
        throw PitchAnalysisException('WAV 解码失败：$error');
      }
    }

    final request = _sampleRequestForDuration(
      durationHint ?? _estimateDuration(bytes),
    );

    if (kIsWeb) {
      await _ensureSoLoudReadyForWebDecode();
      final samples = await SoLoud.instance.readSamplesFromMem(
        bytes,
        request.sampleCount,
        endTime: -1,
        average: true,
      );
      final trimmed = _trimTail(samples);
      return _DecodedAudioSamples(
        samples: trimmed,
        duration: durationHint ?? _durationFromSampleCount(trimmed.length),
        playbackDuration: durationHint,
      );
    }

    await NativeAudioBootstrap.ensureReady();

    final tempPath = await PitchAnalysisTempFile.write(bytes, ext);
    try {
      final samples = _readSamplesWithFallback(
        filePath: tempPath,
        bytes: bytes,
        request: request,
      );
      return _DecodedAudioSamples(
        samples: samples,
        duration: durationHint ?? _durationFromSampleCount(samples.length),
        playbackDuration: durationHint,
      );
    } finally {
      await PitchAnalysisTempFile.delete(tempPath);
    }
  }

  static Float32List _readSamplesWithFallback({
    required String filePath,
    required Uint8List bytes,
    required _SampleRequest request,
  }) {
    Object? lastError;
    try {
      final samples = readPitchAnalysisSamplesFromFile(
        filePath,
        request.sampleCount,
        endTime: -1,
        average: true,
      );
      final trimmed = _trimTail(samples);
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    } catch (error) {
      lastError = error;
    }

    try {
      final samples = readPitchAnalysisSamplesFromMem(
        bytes,
        request.sampleCount,
        endTime: -1,
        average: true,
      );
      final trimmed = _trimTail(samples);
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    } catch (error) {
      lastError = error;
    }

    if (lastError is SoLoudException) {
      throw PitchAnalysisException(_mapSoLoudError(lastError));
    }
    throw PitchAnalysisException(
      lastError == null ? _msgDecodeFailed : '$_msgDecodeFailed ($lastError)',
    );
  }

  static Future<void> _ensureSoLoudReadyForWebDecode() async {
    if (kIsWeb) {
      final soLoud = SoLoud.instance;
      if (!soLoud.isInitialized) {
        await soLoud.init();
      }
      return;
    }
    await NativeAudioBootstrap.ensureReady();
  }

  static Duration _estimateDuration(Uint8List bytes) {
    final estimatedSec =
        (bytes.length /
                SmartSightSingingOfflineAnalysisConfig.estimatedBytesPerSecond)
            .ceil()
            .clamp(
              10,
              SmartSightSingingOfflineAnalysisConfig.maxAnalysisSeconds,
            );
    final cappedSec = kIsWeb
        ? math.min(
            estimatedSec,
            SmartSightSingingOfflineAnalysisConfig.webMaxAnalysisSeconds,
          )
        : estimatedSec;
    return Duration(seconds: cappedSec);
  }

  static Duration _durationFromSampleCount(int sampleCount) {
    if (sampleCount <= 0) {
      return Duration.zero;
    }
    final ms = (sampleCount / analysisSampleRate * 1000).round();
    return Duration(milliseconds: math.max(1, ms));
  }

  static _SampleRequest _sampleRequestForDuration(Duration? duration) {
    final maxSeconds = kIsWeb
        ? SmartSightSingingOfflineAnalysisConfig.webMaxAnalysisSeconds
        : SmartSightSingingOfflineAnalysisConfig.maxAnalysisSeconds;
    final durationMs = duration?.inMilliseconds ?? 0;
    final cappedMs = durationMs > 0
        ? math.min(durationMs, maxSeconds * 1000)
        : maxSeconds * 1000;
    final seconds = cappedMs / 1000.0;
    final sampleCount = math.max(1, (seconds * analysisSampleRate).round());
    return _SampleRequest(
      sampleCount: sampleCount,
      effectiveDuration: durationMs > 0
          ? Duration(milliseconds: cappedMs.round())
          : null,
    );
  }

  static Float32List _trimTail(Float32List samples) {
    if (samples.isEmpty) {
      return samples;
    }
    var end = samples.length;
    while (end > 0 && samples[end - 1].abs() < 1e-6) {
      end--;
    }
    if (end == samples.length) {
      return samples;
    }
    return Float32List.sublistView(samples, 0, end);
  }

  static Future<PitchTrack> _analyzeFloatSamples(
    Float32List floats, {
    Duration? analysisDuration,
    Duration? playbackDuration,
  }) async {
    if (floats.isEmpty) {
      throw PitchAnalysisException(_msgReadFailed);
    }
    final pcm = _floatToInt16Bytes(floats);
    final sampleRate = _sampleRateForAnalysis(floats, analysisDuration);
    final track = kIsWeb
        ? await _yinPipeline(pcm, sampleRate: sampleRate)
        : await compute(
            _yinPipelineIsolate,
            _YinPipelineMessage(pcm: pcm, sampleRate: sampleRate),
          );
    return _alignTrackToPlaybackDuration(track, playbackDuration);
  }

  static PitchTrack _alignTrackToPlaybackDuration(
    PitchTrack track,
    Duration? playbackDuration,
  ) {
    final playbackMs = playbackDuration?.inMilliseconds ?? 0;
    if (playbackMs <= 0 || track.totalMs >= playbackMs) {
      return track;
    }
    return PitchTrack(
      frames: track.frames,
      notes: track.notes,
      totalMs: playbackMs,
      frameStepMs: track.frameStepMs,
      minMidi: track.minMidi,
      maxMidi: track.maxMidi,
    );
  }

  static String _mapSoLoudError(SoLoudException error) {
    return '$_msgDecodeFailed (${error.runtimeType}: ${error.description})';
  }

  static String _normalizeExt(String formatHint) {
    final ext = formatHint.trim().toLowerCase();
    if (ext.isEmpty || ext == 'audio') return 'mp3';
    return ext.replaceAll('.', '');
  }

  static double _sampleRateForAnalysis(
    Float32List samples,
    Duration? durationHint,
  ) {
    final durationMs = durationHint?.inMilliseconds ?? 0;
    if (durationMs <= 0 || samples.isEmpty) {
      return analysisSampleRate.toDouble();
    }
    final sampleRate = samples.length * 1000 / durationMs;
    if (!sampleRate.isFinite || sampleRate <= 0) {
      return analysisSampleRate.toDouble();
    }
    return sampleRate.clamp(
      SmartSightSingingOfflineAnalysisConfig.minDerivedSampleRate,
      SmartSightSingingOfflineAnalysisConfig.maxDerivedSampleRate,
    );
  }
}

class _DecodedAudioSamples {
  const _DecodedAudioSamples({
    required this.samples,
    required this.duration,
    this.playbackDuration,
  });

  final Float32List samples;
  final Duration? duration;
  final Duration? playbackDuration;
}

class _SampleRequest {
  const _SampleRequest({
    required this.sampleCount,
    required this.effectiveDuration,
  });

  final int sampleCount;
  final Duration? effectiveDuration;
}

class PitchAnalysisException implements Exception {
  PitchAnalysisException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _YinPipelineMessage {
  const _YinPipelineMessage({required this.pcm, required this.sampleRate});

  final Uint8List pcm;
  final double sampleRate;
}

Future<PitchTrack> _yinPipelineIsolate(_YinPipelineMessage message) {
  return _yinPipeline(message.pcm, sampleRate: message.sampleRate);
}

Future<PitchTrack> _yinPipeline(
  Uint8List pcm, {
  required double sampleRate,
}) async {
  const bufSize = SightSingingPitchAnalyzer.yinBufferSize;
  const hop = SightSingingPitchAnalyzer.yinHopSize;

  final detector = PitchDetector(
    audioSampleRate: sampleRate.toDouble(),
    bufferSize: bufSize,
  );

  final totalSamples = pcm.length ~/ 2;
  if (totalSamples < bufSize) {
    return const PitchTrack(
      frames: <PitchFrame>[],
      totalMs: 0,
      frameStepMs: 0,
      minMidi: SmartSightSingingPitchRangeConfig.defaultMinMidi,
      maxMidi: SmartSightSingingPitchRangeConfig.defaultMaxMidi,
    );
  }

  final totalMs = (totalSamples * 1000 / sampleRate).round();
  final stepMs = (hop * 1000 / sampleRate).round();

  final frames = <PitchFrame>[];
  final frameBuf = Uint8List(bufSize * 2);
  final view = ByteData.sublistView(pcm);

  double minMidi = double.infinity;
  double maxMidi = -double.infinity;

  for (var start = 0; start + bufSize <= totalSamples; start += hop) {
    final byteStart = start * 2;
    frameBuf.setRange(0, bufSize * 2, pcm, byteStart);

    var sumSq = 0.0;
    for (var i = 0; i < bufSize; i++) {
      final s = view.getInt16(byteStart + i * 2, Endian.little).toDouble();
      sumSq += s * s;
    }
    final rms = math.sqrt(sumSq / bufSize);
    final timeMs = ((start + bufSize ~/ 2) * 1000 / sampleRate).round();

    if (rms < SmartSightSingingOfflineAnalysisConfig.minRms) {
      frames.add(
        PitchFrame(timeMs: timeMs, frequencyHz: 0, midi: -1, confidence: 0),
      );
      continue;
    }

    final result = await detector.getPitchFromFloatBuffer(
      pcm16LeToFloatSamples(frameBuf),
    );
    final hz = result.pitch;
    final midi = (result.pitched && hz > 0 && hz.isFinite)
        ? PitchUtils.hzToMidi(hz)
        : double.nan;
    final ok =
        result.pitched &&
        hz > 0 &&
        midi.isFinite &&
        hz > SmartSightSingingOfflineAnalysisConfig.minFrequencyHz &&
        hz < SmartSightSingingOfflineAnalysisConfig.maxFrequencyHz;

    if (ok) {
      if (midi < minMidi) minMidi = midi;
      if (midi > maxMidi) maxMidi = midi;
    }

    frames.add(
      PitchFrame(
        timeMs: timeMs,
        frequencyHz: ok ? hz : 0,
        midi: ok ? midi : -1,
        confidence: result.probability,
      ),
    );
  }

  if (!minMidi.isFinite || !maxMidi.isFinite) {
    minMidi = SmartSightSingingPitchRangeConfig.defaultMinMidi;
    maxMidi = SmartSightSingingPitchRangeConfig.defaultMaxMidi;
  } else {
    minMidi =
        (minMidi - SmartSightSingingPitchRangeConfig.rangePaddingSemitones)
            .clamp(
              SmartSightSingingPitchRangeConfig.hardMinMidi,
              SmartSightSingingPitchRangeConfig.hardMaxMidi -
                  SmartSightSingingPitchRangeConfig.minDisplayedRangeSemitones,
            )
            .toDouble();
    maxMidi =
        (maxMidi + SmartSightSingingPitchRangeConfig.rangePaddingSemitones)
            .clamp(
              minMidi +
                  SmartSightSingingPitchRangeConfig.minDisplayedRangeSemitones,
              SmartSightSingingPitchRangeConfig.hardMaxMidi,
            )
            .toDouble();
  }

  final smoothed = _medianSmooth(frames);
  final notes = KtvPitchGuideBuilder.fromFrames(smoothed, frameStepMs: stepMs);
  final noteRange = KtvPitchGuideBuilder.rangeForNotes(notes);
  if (notes.isNotEmpty) {
    minMidi = noteRange.minMidi;
    maxMidi = noteRange.maxMidi;
  }

  return PitchTrack(
    frames: smoothed,
    notes: notes,
    totalMs: totalMs,
    frameStepMs: stepMs > 0 ? stepMs : 1,
    minMidi: minMidi,
    maxMidi: maxMidi,
  );
}

Uint8List _floatToInt16Bytes(Float32List floats) {
  final out = ByteData(floats.length * 2);
  for (var i = 0; i < floats.length; i++) {
    final clamped = floats[i].clamp(-1.0, 1.0);
    out.setInt16(i * 2, (clamped * 32767).round(), Endian.little);
  }
  return out.buffer.asUint8List();
}

List<PitchFrame> _medianSmooth(List<PitchFrame> frames) {
  final radius = SmartSightSingingOfflineAnalysisConfig.medianSmoothRadius;
  if (frames.length < radius * 2 + 1) return frames;
  final result = List<PitchFrame>.from(frames, growable: false);
  final window = <double>[];
  for (var i = 0; i < frames.length; i++) {
    if (!frames[i].pitched) continue;
    window.clear();
    for (var k = -radius; k <= radius; k++) {
      final j = i + k;
      if (j < 0 || j >= frames.length) continue;
      if (frames[j].pitched) window.add(frames[j].midi);
    }
    if (window.length <
        SmartSightSingingOfflineAnalysisConfig.medianSmoothMinPitched) {
      continue;
    }
    window.sort();
    final med = window[window.length ~/ 2];
    if ((med - frames[i].midi).abs() >
        SmartSightSingingOfflineAnalysisConfig.medianSmoothJumpSemitones) {
      result[i] = PitchFrame(
        timeMs: frames[i].timeMs,
        frequencyHz: PitchUtils.midiToHz(med),
        midi: med,
        confidence: frames[i].confidence,
      );
    }
  }
  return result;
}
