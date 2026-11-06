import 'dart:math' as math;
import 'dart:typed_data';

import '../../music_companion/audio/music_companion_audio_catalog.dart';
import '../config/smart_sight_singing_config.dart';
import 'ktv_pitch_guide.dart';
import 'midi_file_parser.dart';
import 'pitch_track.dart';

/// MIDI 播放事件（钢琴短音）。
class MidiPlaybackEvent {
  const MidiPlaybackEvent({
    required this.timeMs,
    required this.pitch,
    required this.velocity,
    this.metronomeCue,
  });

  final int timeMs;
  final int pitch;
  final int velocity;
  final MusicCompanionMetronomeCue? metronomeCue;
}

/// 单轨摘要，供用户选择主旋律轨。
class MidiTrackSummary {
  const MidiTrackSummary({
    required this.trackIndex,
    required this.noteCount,
    required this.minPitch,
    required this.maxPitch,
    required this.durationMs,
    required this.recommended,
  });

  final int trackIndex;
  final int noteCount;
  final int minPitch;
  final int maxPitch;
  final int durationMs;
  final bool recommended;

  bool get hasNotes => noteCount > 0;

  String get pitchRangeLabel {
    if (!hasNotes) return '--';
    return '${PitchUtils.midiToNoteName(minPitch.toDouble())}'
        ' ~ ${PitchUtils.midiToNoteName(maxPitch.toDouble())}';
  }
}

/// MIDI 解析预览（尚未选定主旋律轨）。
class MidiParsePreview {
  const MidiParsePreview({
    required this.parsed,
    required this.summaries,
    required this.suggestedTrackIndex,
  });

  final ParsedMidiFile parsed;
  final List<MidiTrackSummary> summaries;
  final int suggestedTrackIndex;
}

/// 智能视唱 MIDI 解析结果。
class MidiSightSingingBundle {
  const MidiSightSingingBundle({
    required this.track,
    required this.playbackEvents,
    required this.melodyTrackIndex,
    required this.totalMs,
  });

  final PitchTrack track;
  final List<MidiPlaybackEvent> playbackEvents;
  final int melodyTrackIndex;
  final int totalMs;
}

class MidiSightSingingException implements Exception {
  MidiSightSingingException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class MidiSightSingingService {
  /// 解析 MIDI 并生成各轨摘要，不自动构建参考轨。
  static MidiParsePreview parsePreview(Uint8List bytes) {
    final parsed = MidiFileParser.parse(bytes);
    if (parsed.notes.isEmpty) {
      throw MidiSightSingingException('MIDI 中没有可播放的音符。');
    }

    final suggested = suggestMelodyTrackIndex(parsed);
    final summaries = <MidiTrackSummary>[];
    for (var track = 1; track <= parsed.tracks; track++) {
      summaries.add(_summaryForTrack(parsed, track, suggested));
    }

    return MidiParsePreview(
      parsed: parsed,
      summaries: summaries,
      suggestedTrackIndex: suggested,
    );
  }

  /// 根据用户选定轨构建参考轨与播放事件（播放与打分均只用该轨）。
  static MidiSightSingingBundle buildBundle(
    ParsedMidiFile parsed,
    int melodyTrackIndex,
  ) {
    if (melodyTrackIndex < 1 || melodyTrackIndex > parsed.tracks) {
      throw MidiSightSingingException('轨道编号无效：$melodyTrackIndex');
    }

    final melodyNotes = parsed.notesOnTrack(melodyTrackIndex);
    if (melodyNotes.isEmpty) {
      throw MidiSightSingingException('轨道 $melodyTrackIndex 没有音符，请换一条轨道。');
    }

    final notes = melodyNotes
        .where((n) => n.endMs > n.startMs && n.pitch > 0)
        .map(
          (n) => KtvNoteSegment(
            startMs: n.startMs.round(),
            endMs: math.max(
              n.endMs.round(),
              n.startMs.round() + SmartSightSingingMidiConfig.minMidiNoteMs,
            ),
            midi: n.pitch.toDouble(),
            startBeat: n.startTick / parsed.ticksPerQuarter,
            durationBeats: (n.endTick - n.startTick) / parsed.ticksPerQuarter,
          ),
        )
        .toList(growable: false);

    if (notes.isEmpty) {
      throw MidiSightSingingException('轨道 $melodyTrackIndex 没有有效音符。');
    }

    final range = KtvPitchGuideBuilder.rangeForNotes(notes);
    final totalMs =
        notes.map((n) => n.endMs).reduce(math.max) +
        SmartSightSingingMidiConfig.playbackTailMs;

    final track = PitchTrack(
      frames: const <PitchFrame>[],
      notes: notes,
      totalMs: totalMs,
      frameStepMs: SmartSightSingingMidiConfig.referenceFrameStepMs,
      minMidi: range.minMidi,
      maxMidi: range.maxMidi,
    );

    final playbackEvents =
        melodyNotes
            .where(
              (n) =>
                  n.channel != SmartSightSingingMidiConfig.percussionChannel &&
                  n.pitch > 0 &&
                  n.velocity > 0 &&
                  n.endMs > n.startMs,
            )
            .map(
              (n) => MidiPlaybackEvent(
                timeMs: n.startMs.round(),
                pitch: n.pitch,
                velocity: n.velocity,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.timeMs.compareTo(b.timeMs));

    return MidiSightSingingBundle(
      track: track,
      playbackEvents: playbackEvents,
      melodyTrackIndex: melodyTrackIndex,
      totalMs: totalMs,
    );
  }

  static MidiTrackSummary _summaryForTrack(
    ParsedMidiFile parsed,
    int trackIndex,
    int suggestedTrackIndex,
  ) {
    final notes = parsed.notesOnTrack(trackIndex);
    if (notes.isEmpty) {
      return MidiTrackSummary(
        trackIndex: trackIndex,
        noteCount: 0,
        minPitch: 0,
        maxPitch: 0,
        durationMs: parsed.totalMs.ceil(),
        recommended: trackIndex == suggestedTrackIndex,
      );
    }

    final pitches = notes.map((n) => n.pitch).toList(growable: false);
    final minPitch = pitches.reduce(math.min);
    final maxPitch = pitches.reduce(math.max);
    final lastEnd = notes.map((n) => n.endMs).reduce(math.max);

    return MidiTrackSummary(
      trackIndex: trackIndex,
      noteCount: notes.length,
      minPitch: minPitch,
      maxPitch: maxPitch,
      durationMs: lastEnd.ceil(),
      recommended: trackIndex == suggestedTrackIndex,
    );
  }

  /// 启发式推荐主旋律轨（用户仍可改选）。
  static int suggestMelodyTrackIndex(ParsedMidiFile parsed) {
    var bestTrack = 1;
    var bestScore = -1.0;

    for (var track = 1; track <= parsed.tracks; track++) {
      final notes = parsed.notesOnTrack(track);
      if (notes.isEmpty) continue;

      final pitches = notes.map((n) => n.pitch).toList();
      final vocalCount = pitches
          .where(
            (p) =>
                p >= SmartSightSingingMidiConfig.melodyMidiMin &&
                p <= SmartSightSingingMidiConfig.melodyMidiMax,
          )
          .length;
      final lowCount = pitches
          .where(
            (p) => p < SmartSightSingingMidiConfig.lowPitchPenaltyBelowMidi,
          )
          .length;
      final score =
          vocalCount * SmartSightSingingMidiConfig.vocalPitchWeight -
          lowCount * SmartSightSingingMidiConfig.lowPitchPenaltyWeight -
          (notes.length - SmartSightSingingMidiConfig.idealMelodyNoteCount)
                  .abs() *
              SmartSightSingingMidiConfig.noteCountDistancePenalty;

      if (score > bestScore) {
        bestScore = score;
        bestTrack = track;
      }
    }

    return bestTrack;
  }
}
