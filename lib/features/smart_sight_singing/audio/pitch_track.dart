import 'dart:math' as math;

import '../config/smart_sight_singing_config.dart';
import 'ktv_pitch_guide.dart';

/// 单帧音高分析结果。
class PitchFrame {
  const PitchFrame({
    required this.timeMs,
    required this.frequencyHz,
    required this.midi,
    required this.confidence,
  });

  /// 帧中点对应的时间（毫秒）。
  final int timeMs;

  /// 检测到的基频（Hz）。0 表示该帧无音高（静音/噪声）。
  final double frequencyHz;

  /// 对应的 MIDI 音高（69 + 12·log2(f/440)），无音高时为 -1。
  final double midi;

  /// YIN 概率（0~1），越高越可信。
  final double confidence;

  bool get pitched =>
      frequencyHz > 0 &&
      confidence > SmartSightSingingRealtimePitchConfig.frameMinConfidence &&
      midi.isFinite;
}

/// 参考音高曲线 + 元数据。
class PitchTrack {
  const PitchTrack({
    required this.frames,
    required this.totalMs,
    required this.frameStepMs,
    required this.minMidi,
    required this.maxMidi,
    this.notes = const <KtvNoteSegment>[],
  });

  /// 按时间升序排列的全部帧（含无音高帧）。
  final List<PitchFrame> frames;

  /// KTV 音符条（由帧合并量化得到，UI 绘制与打分优先使用）。
  final List<KtvNoteSegment> notes;

  /// 曲目总长度（毫秒）。
  final int totalMs;

  /// 帧步长（毫秒，与 isolate 分析一致）。
  final int frameStepMs;

  /// 有效音高范围（用于 UI 纵轴居中），无有效帧时为合理默认。
  final double minMidi;
  final double maxMidi;

  bool get isEmpty => notes.isEmpty && frames.isEmpty;

  /// 当前时间所在的音符条下标；无则 `null`。
  int? noteIndexAt(int ms, {int earlyMs = 0, int lateMs = 0}) {
    if (notes.isEmpty) return null;
    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (n.isRest) continue;
      if (ms >= n.startMs - earlyMs && ms <= n.endMs + lateMs) {
        return i;
      }
    }
    return null;
  }

  KtvNoteSegment? noteAt(int ms, {int earlyMs = 0, int lateMs = 0}) {
    final idx = noteIndexAt(ms, earlyMs: earlyMs, lateMs: lateMs);
    if (idx == null) return null;
    return notes[idx];
  }

  /// 在时间 [ms] 附近返回参考音高帧（优先音符条，其次原始帧）。
  PitchFrame? sampleAt(
    int ms, {
    int searchHalfWindowMs =
        SmartSightSingingScoringConfig.referenceFrameSearchHalfWindowMs,
  }) {
    final note = noteAt(
      ms,
      earlyMs: SmartSightSingingScoringConfig.referenceSampleEarlyMs,
      lateMs: SmartSightSingingScoringConfig.referenceSampleLateMs,
    );
    if (note != null) {
      return PitchFrame(
        timeMs: ms,
        frequencyHz: PitchUtils.midiToHz(note.midi),
        midi: note.midi,
        confidence: 1,
      );
    }
    if (frames.isEmpty) return null;
    if (frameStepMs <= 0) return null;
    var idx = (ms / frameStepMs).round();
    idx = idx.clamp(0, frames.length - 1);
    final center = frames[idx];
    if (center.pitched) return center;
    final maxOffset = (searchHalfWindowMs / frameStepMs).ceil();
    for (var off = 1; off <= maxOffset; off++) {
      final left = idx - off;
      final right = idx + off;
      if (left >= 0 && frames[left].pitched) return frames[left];
      if (right < frames.length && frames[right].pitched) return frames[right];
    }
    return null;
  }
}

/// MIDI ↔ Hz 互转 + 中文唱名。
class PitchUtils {
  PitchUtils._();

  static double hzToMidi(double hz) {
    if (hz <= 0) return double.nan;
    return 69 + 12 * (math.log(hz / 440.0) / math.ln2);
  }

  static double midiToHz(double midi) {
    return 440.0 * math.pow(2, (midi - 69) / 12.0).toDouble();
  }

  /// 计算两个频率之间的偏差（音分），ref<=0 时返回 NaN。
  static double centsBetween(double real, double ref) {
    if (ref <= 0 || real <= 0) return double.nan;
    return 1200 * (math.log(real / ref) / math.ln2);
  }

  /// 计算 MIDI 音高相对参考音的最近八度偏差。
  ///
  /// 上传 MIDI 常常不在人声舒适音区，实时人声检测也可能偶发八度跳变；
  /// 智能视唱按旋律音级评分时，应避免同名音跨八度被直接判为 0 分。
  static double octaveNormalizedCents(double midi, double refMidi) {
    if (!midi.isFinite || !refMidi.isFinite || midi < 0 || refMidi < 0) {
      return double.nan;
    }
    final cents = (midi - refMidi) * 100;
    return cents - (cents / 1200).roundToDouble() * 1200;
  }

  /// 例如 midi=60 -> "C4"。
  static String midiToNoteName(double midi) {
    if (midi.isNaN || midi.isInfinite) return '--';
    const names = <String>[
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final rounded = midi.round();
    final octave = (rounded ~/ 12) - 1;
    final n = ((rounded % 12) + 12) % 12;
    return '${names[n]}$octave';
  }
}
