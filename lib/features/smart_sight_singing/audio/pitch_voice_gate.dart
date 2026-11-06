import '../config/smart_sight_singing_tuning.dart';
import 'realtime_pitch_capture.dart';

/// 过滤扬声器伴奏被麦克风录入导致的「假跟唱」。
///
/// 阈值实时从 [SightSingingTuning] 读取，调试面板修改后立即生效。
abstract final class PitchVoiceGate {
  /// 无声跟唱：不外放伴奏，不做串音过滤，仅最低响度门限。
  static PitchVoiceGatePolicy visualOnly() {
    final t = SightSingingTuning.instance;
    return PitchVoiceGatePolicy(
      minAmplitude: t.visualOnlyMinAmplitude,
      bleedMatchMaxAmplitude: 0,
      bleedMatchMaxCents: 0,
      rejectPlaybackPitchMatch: false,
      rejectRefMidiMatch: false,
    );
  }

  /// 有伴奏跟唱：过滤「极低响度 + 与当前钢琴音完全一致」的扬声器串音。
  /// 唱准参考音的用户声音不会被过滤——用户本来就要对准旋律。
  static PitchVoiceGatePolicy withAccompaniment() {
    final t = SightSingingTuning.instance;
    return PitchVoiceGatePolicy(
      minAmplitude: t.accompanimentMinAmplitude,
      bleedMatchMaxAmplitude: t.bleedMatchMaxAmplitude,
      bleedMatchMaxCents: t.bleedMatchMaxCents,
      rejectPlaybackPitchMatch: true,
      rejectRefMidiMatch: false,
    );
  }

  static bool isLikelyUserVoice({
    required RealtimePitchEvent event,
    double? refMidi,
    double? playbackMidi,
    required PitchVoiceGatePolicy policy,
  }) {
    if (!event.pitched) return false;
    if (event.amplitude < policy.minAmplitude) return false;

    if (!policy.rejectRefMidiMatch && !policy.rejectPlaybackPitchMatch) {
      return true;
    }

    final t = SightSingingTuning.instance;

    if (policy.rejectPlaybackPitchMatch &&
        playbackMidi != null &&
        playbackMidi > 0) {
      final playbackDiff = (event.midi - playbackMidi).abs() * 100;
      // 响度明显高于串音水平时，视为用户发声（即使音高与伴奏一致）。
      if (event.amplitude >
          policy.bleedMatchMaxAmplitude + t.strongVoiceExtraAmplitude) {
        return true;
      }
      if (playbackDiff <= policy.bleedMatchMaxCents &&
          event.amplitude <= policy.bleedMatchMaxAmplitude) {
        return false;
      }
    }

    if (policy.rejectRefMidiMatch && refMidi != null && refMidi > 0) {
      final diffCents = (event.midi - refMidi).abs() * 100;
      if (diffCents <= policy.bleedMatchMaxCents &&
          event.amplitude <= policy.bleedMatchMaxAmplitude) {
        return false;
      }
    }
    return true;
  }

  static RealtimePitchEvent filterForScoring({
    required RealtimePitchEvent event,
    double? refMidi,
    double? playbackMidi,
    required PitchVoiceGatePolicy policy,
  }) {
    if (!isLikelyUserVoice(
      event: event,
      refMidi: refMidi,
      playbackMidi: playbackMidi,
      policy: policy,
    )) {
      return RealtimePitchEvent(
        frequencyHz: 0,
        midi: -1,
        confidence: event.confidence,
        amplitude: event.amplitude,
        pitched: false,
      );
    }
    return event;
  }
}

class PitchVoiceGatePolicy {
  const PitchVoiceGatePolicy({
    required this.minAmplitude,
    required this.bleedMatchMaxAmplitude,
    required this.bleedMatchMaxCents,
    required this.rejectPlaybackPitchMatch,
    required this.rejectRefMidiMatch,
  });

  final double minAmplitude;
  final double bleedMatchMaxAmplitude;
  final double bleedMatchMaxCents;
  final bool rejectPlaybackPitchMatch;
  final bool rejectRefMidiMatch;
}
