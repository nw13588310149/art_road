import 'dart:math' as math;

/// MusicPlay 频谱可视化统一频段数（与 UI `_FrequencyVisualizerPainter` 对齐）。
const int kMusicPlayVisualizerBandCount = 46;

/// 默认采样率（Web Analyser / 常见输出）。
const double kMusicPlayVisualizerSampleRate = 44100;

/// 将 Web `AnalyserNode` 字节频域采样映射为 46 段展示能量。
List<double> compressMusicPlayFrequencyData(
  List<int> data, {
  required List<double> globalEnvelopeHolder,
  List<double>? previous,
  double smooth = 0.36,
  int fftSize = 512,
}) {
  if (data.isEmpty) {
    return const <double>[];
  }
  return polishMusicPlayVisualizerBands(
    _melBinAverage(
      data.map((v) => v / 255.0).toList(growable: false),
      fftSize: fftSize,
    ),
    globalEnvelopeHolder: globalEnvelopeHolder,
    previous: previous,
    smooth: smooth,
  );
}

/// 将 native 端上报的原始能量做展示后处理（Android / iOS）。
List<double> polishMusicPlayVisualizerBands(
  List<double> raw, {
  required List<double> globalEnvelopeHolder,
  List<double>? previous,
  double smooth = 0.36,
}) {
  if (raw.isEmpty) {
    return const <double>[];
  }
  return _mapMusicPlayVisualizerDisplay(
    raw,
    globalEnvelopeHolder: globalEnvelopeHolder,
    previous: previous,
    smooth: smooth,
  );
}

/// 停止 / 暂停驻留：静态低幅山形，无动画。
List<double> buildMusicPlayVisualizerRestBands() {
  const bands = kMusicPlayVisualizerBandCount;
  const center = (bands - 1) / 2.0;
  return List<double>.generate(bands, (i) {
    final dist = ((i - center).abs() / center).clamp(0.0, 1.0);
    final envelope = math.exp(-dist * dist * 2.0);
    return (0.032 + envelope * 0.052).clamp(0.03, 0.085);
  }, growable: false);
}

void resetMusicPlayVisualizerEnvelope(List<double> envelope) {
  if (envelope.isEmpty) {
    return;
  }
  envelope[0] = 0.015;
}

/// Mel 刻度提取真实频域能量（分析用，非最终展示顺序）。
List<double> _melBinAverage(
  List<double> bins, {
  double sampleRate = kMusicPlayVisualizerSampleRate,
  int fftSize = 512,
}) {
  const bands = kMusicPlayVisualizerBandCount;
  if (bins.isEmpty) {
    return List<double>.filled(bands, 0);
  }

  final nyquist = sampleRate / 2;
  const minHz = 80.0;
  const maxHz = 12000.0;
  final minMel = _hzToMel(minHz);
  final maxMel = _hzToMel(maxHz);
  final result = List<double>.filled(bands, 0);

  for (var i = 0; i < bands; i++) {
    final melLow = minMel + (maxMel - minMel) * i / bands;
    final melHigh = minMel + (maxMel - minMel) * (i + 1) / bands;
    final hzLow = _melToHz(melLow);
    final hzHigh = _melToHz(melHigh);
    final from = (hzLow / nyquist * bins.length).floor().clamp(0, bins.length - 1);
    final to = (hzHigh / nyquist * bins.length)
        .ceil()
        .clamp(from + 1, bins.length);
    var sum = 0.0;
    for (var j = from; j < to; j++) {
      final v = bins[j];
      sum += v * v;
    }
    result[i] = math.sqrt(sum / (to - from));
  }
  return result;
}

double _hzToMel(double hz) => 2595 * math.log(1 + hz / 700) / math.ln10;

double _melToHz(double mel) => 700 * (math.pow(10, mel / 2595) - 1);

/// 业内标准（Web Audio / 网易云）：低频在视觉中心，向两侧对称展开到高频。
///
/// `mel[0]`（低）→ 中间柱最高；`mel[last]`（高）→ 两侧柱更低，自然形成山形。
List<double> _centerMirrorDisplay(List<double> melBands) {
  const n = kMusicPlayVisualizerBandCount;
  const half = n ~/ 2;
  final out = List<double>.filled(n, 0);
  if (melBands.isEmpty) {
    return out;
  }

  for (var d = 0; d < half; d++) {
    final srcFrom = (d * melBands.length / half).floor().clamp(0, melBands.length - 1);
    final srcTo = ((d + 1) * melBands.length / half)
        .ceil()
        .clamp(srcFrom + 1, melBands.length);
    var energy = 0.0;
    for (var j = srcFrom; j < srcTo; j++) {
      energy = math.max(energy, melBands[j]);
    }
    out[half - 1 - d] = energy;
    out[half + d] = energy;
  }

  // 轻量 Hann：保留频谱起伏，同时维持中间高、两边低。
  final center = (n - 1) / 2.0;
  for (var i = 0; i < n; i++) {
    final dist = ((i - center).abs() / center).clamp(0.0, 1.0);
    final hann = 0.62 + 0.38 * math.cos(dist * math.pi);
    out[i] *= hann;
  }
  return out;
}

List<double> _mapMusicPlayVisualizerDisplay(
  List<double> raw, {
  required List<double> globalEnvelopeHolder,
  List<double>? previous,
  double smooth = 0.36,
}) {
  const bands = kMusicPlayVisualizerBandCount;
  final mel = List<double>.filled(bands, 0);
  for (var i = 0; i < bands; i++) {
    if (i < raw.length) {
      mel[i] = raw[i].clamp(0.0, 1.0);
    }
  }

  final symmetric = _centerMirrorDisplay(mel);

  var frameMin = double.infinity;
  var framePeak = 0.0;
  for (final v in symmetric) {
    if (v < frameMin) {
      frameMin = v;
    }
    if (v > framePeak) {
      framePeak = v;
    }
  }
  if (frameMin.isInfinite) {
    frameMin = 0;
  }

  // 全局慢速包络仅用于整体响度参考，不再作为除数（避免整帧顶满）。
  final prevEnvelope = globalEnvelopeHolder.isEmpty
      ? 0.015
      : globalEnvelopeHolder[0];
  final nextEnvelope = math.max(framePeak, prevEnvelope * 0.955);
  if (globalEnvelopeHolder.isEmpty) {
    globalEnvelopeHolder.add(nextEnvelope);
  } else {
    globalEnvelopeHolder[0] = nextEnvelope;
  }

  final spread = framePeak - frameMin;
  final loudnessGain = (0.48 / (nextEnvelope + 0.07)).clamp(0.38, 1.05);

  const minPercent = 0.10;
  const maxPercent = 0.78;

  final input = List<double>.filled(bands, 0);
  for (var i = 0; i < bands; i++) {
    double relative;
    if (spread > 0.003) {
      relative = ((symmetric[i] - frameMin) / spread).clamp(0.0, 1.0);
    } else {
      relative = (symmetric[i] * loudnessGain).clamp(0.0, 1.0);
    }
    final absolute = (symmetric[i] * loudnessGain).clamp(0.0, 1.0);
    final blended = math.pow(relative * 0.80 + absolute * 0.20, 0.88).toDouble();
    input[i] = minPercent + blended * (maxPercent - minPercent);
  }

  if (previous != null && previous.length == bands) {
    for (var i = 0; i < bands; i++) {
      final delta = input[i] - previous[i];
      final factor = delta >= 0 ? 0.48 : 0.32;
      input[i] = previous[i] + delta * factor;
    }
  }

  return input;
}
