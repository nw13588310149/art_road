import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';

import '../config/smart_sight_singing_config.dart';
import '../config/smart_sight_singing_tuning.dart';
import 'pitch_track.dart';

/// 实时单帧音高分析（YIN + 自相关互补，兼容 iPad 麦克风）。
///
/// 平滑相关阈值实时从 [SightSingingTuning] 读取；buffer/sampleRate
/// 一旦构造完成不会再变（再变需要重启录音流并重建 FFT）。
class LivePitchDetector {
  LivePitchDetector({double? sampleRate, int? bufferSize})
    : sampleRate =
          sampleRate ??
          SmartSightSingingRealtimePitchConfig.sampleRate.toDouble(),
      bufferSize =
          bufferSize ?? SmartSightSingingRealtimePitchConfig.bufferSize,
      _yin = PitchDetector(
        audioSampleRate:
            sampleRate ??
            SmartSightSingingRealtimePitchConfig.sampleRate.toDouble(),
        bufferSize:
            bufferSize ?? SmartSightSingingRealtimePitchConfig.bufferSize,
      ),
      _hann = _buildHannWindow(
        bufferSize ?? SmartSightSingingRealtimePitchConfig.bufferSize,
      ) {
    // 单帧时长（ms）：buffer / sampleRate，用于把「静音帧数」换算成 ms。
    _frameDurationMs =
        (this.bufferSize * 1000.0) /
        (this.sampleRate <= 0 ? 1.0 : this.sampleRate);
  }

  final double sampleRate;
  final int bufferSize;
  final PitchDetector _yin;
  final List<double> _hann;
  late final double _frameDurationMs;

  double? _lastHz;
  int _stableCount = 0;

  /// 连续无音高帧累计时长（ms）。超过 tuning.silenceResetSmoothingMs
  /// 后清掉 `_lastHz`，避免再次出声时被旧的稳定值吸附到错误音。
  double _silenceMs = 0;

  /// 上一帧检测元信息（供调试面板读取）。
  LivePitchResult get lastResult => _lastResult;
  LivePitchResult _lastResult = LivePitchResult.empty;

  static List<double> _buildHannWindow(int size) {
    if (size <= 1) return List<double>.filled(size, 1);
    return List<double>.generate(
      size,
      (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1)),
    );
  }

  Future<LivePitchResult> analyzePcm16Frame(Uint8List frameBytes) async {
    final le = _prepareSamples(frameBytes, Endian.little);
    final be = _prepareSamples(frameBytes, Endian.big);

    final yinLe = await _analyzeYin(le);
    final yinBe = await _analyzeYin(be);
    var best = _pickBetter(yinLe, yinBe);

    if (!best.pitched) {
      final acLe = _analyzeAutocorrelation(le);
      final acBe = _analyzeAutocorrelation(be);
      best = _pickBetter(best, _pickBetter(acLe, acBe));
    }

    final tuning = SightSingingTuning.instance;

    if (best.pitched && best.frequencyHz > 0) {
      _silenceMs = 0;
      if (_lastHz != null &&
          (best.frequencyHz - _lastHz!).abs() / _lastHz! <
              tuning.stableFrequencyDiffRatio) {
        _stableCount++;
      } else {
        _stableCount = 1;
      }
      _lastHz = best.frequencyHz;
      // 单帧 YIN 偶发跳音时，用上一稳定值平滑。
      if (_stableCount >= tuning.stableFrameCount && _lastHz != null) {
        best = LivePitchResult(
          pitched: true,
          frequencyHz: _lastHz!,
          confidence: math.max(best.confidence, tuning.smoothedConfidenceFloor),
          source: best.source,
        );
      }
    } else {
      _stableCount = 0;
      _silenceMs += _frameDurationMs;
      // 静音持续超过阈值，丢掉旧的 `_lastHz`，避免再次出声时被错误吸附。
      if (_silenceMs >= tuning.silenceResetSmoothingMs) {
        _lastHz = null;
      }
    }

    _lastResult = best;
    return best;
  }

  List<double> _prepareSamples(Uint8List frameBytes, Endian endian) {
    final view = ByteData.sublistView(frameBytes);
    final count = frameBytes.length ~/ 2;
    final out = List<double>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      out[i] = view.getInt16(i * 2, endian) / 32768.0;
    }
    return _windowAndHighPass(out);
  }

  List<double> _windowAndHighPass(List<double> samples) {
    final n = math.min(samples.length, _hann.length);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      out[i] = samples[i] * _hann[i];
    }
    // 一阶高通，削弱 DC / 低频隆隆声。
    const rc = 0.996;
    var prevIn = out[0];
    var prevOut = out[0];
    for (var i = 1; i < n; i++) {
      final currIn = out[i];
      final currOut = rc * (prevOut + currIn - prevIn);
      out[i] = currOut;
      prevIn = currIn;
      prevOut = currOut;
    }
    return out;
  }

  Future<LivePitchResult> _analyzeYin(List<double> samples) async {
    if (samples.length < bufferSize) {
      return LivePitchResult.empty;
    }
    try {
      final slice = samples.sublist(0, bufferSize);
      final result = await _yin.getPitchFromFloatBuffer(slice);
      final hz = result.pitch;
      if (!result.pitched || hz <= 0 || !hz.isFinite) {
        return LivePitchResult.empty;
      }
      if (hz < SmartSightSingingRealtimePitchConfig.minFrequencyHz ||
          hz > SmartSightSingingRealtimePitchConfig.maxFrequencyHz) {
        return LivePitchResult.empty;
      }
      return LivePitchResult(
        pitched: true,
        frequencyHz: hz,
        confidence: result.probability.clamp(0, 1),
        source: LivePitchSource.yin,
      );
    } catch (_) {
      return LivePitchResult.empty;
    }
  }

  LivePitchResult _analyzeAutocorrelation(List<double> samples) {
    if (samples.length < bufferSize) return LivePitchResult.empty;

    final x = samples.sublist(0, bufferSize);
    var mean = 0.0;
    for (final v in x) {
      mean += v;
    }
    mean /= x.length;
    for (var i = 0; i < x.length; i++) {
      x[i] -= mean;
    }

    final minLag =
        (sampleRate /
                SmartSightSingingRealtimePitchConfig
                    .autocorrelationMaxFrequencyHz)
            .round()
            .clamp(2, bufferSize ~/ 2);
    final maxLag =
        (sampleRate / SmartSightSingingRealtimePitchConfig.minFrequencyHz)
            .round()
            .clamp(minLag + 1, bufferSize ~/ 2);

    var bestLag = -1;
    var bestCorr = 0.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var corr = 0.0;
      var e0 = 0.0;
      var e1 = 0.0;
      final limit = x.length - lag;
      for (var i = 0; i < limit; i++) {
        final a = x[i];
        final b = x[i + lag];
        corr += a * b;
        e0 += a * a;
        e1 += b * b;
      }
      final norm = math.sqrt(e0 * e1);
      if (norm <= 1e-9) continue;
      corr /= norm;
      if (corr > bestCorr) {
        bestCorr = corr;
        bestLag = lag;
      }
    }

    if (bestLag <= 0 ||
        bestCorr < SightSingingTuning.instance.autocorrelationMinCorrelation) {
      return LivePitchResult.empty;
    }

    final hz = sampleRate / bestLag;
    if (hz < SmartSightSingingRealtimePitchConfig.minFrequencyHz ||
        hz > SmartSightSingingRealtimePitchConfig.maxFrequencyHz) {
      return LivePitchResult.empty;
    }

    return LivePitchResult(
      pitched: true,
      frequencyHz: hz,
      confidence: bestCorr.clamp(0, 1),
      source: LivePitchSource.autocorrelation,
    );
  }

  LivePitchResult _pickBetter(LivePitchResult a, LivePitchResult b) {
    if (!a.pitched) return b;
    if (!b.pitched) return a;
    if (b.confidence >
        a.confidence +
            SmartSightSingingRealtimePitchConfig.sourceSwitchConfidenceMargin) {
      return b;
    }
    return a;
  }
}

enum LivePitchSource { yin, autocorrelation }

class LivePitchResult {
  const LivePitchResult({
    required this.pitched,
    required this.frequencyHz,
    required this.confidence,
    required this.source,
  });

  final bool pitched;
  final double frequencyHz;
  final double confidence;
  final LivePitchSource source;

  static const empty = LivePitchResult(
    pitched: false,
    frequencyHz: 0,
    confidence: 0,
    source: LivePitchSource.yin,
  );

  double get midi => pitched ? PitchUtils.hzToMidi(frequencyHz) : double.nan;
}
