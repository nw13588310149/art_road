import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_sight_singing/audio/ktv_pitch_guide.dart';
import 'package:the_road_of_music_flutter/features/smart_sight_singing/audio/ktv_scoring.dart';
import 'package:the_road_of_music_flutter/features/smart_sight_singing/audio/live_pitch_detector.dart';
import 'package:the_road_of_music_flutter/features/smart_sight_singing/audio/midi_file_parser.dart';
import 'package:the_road_of_music_flutter/features/smart_sight_singing/audio/midi_sight_singing_service.dart';
import 'package:the_road_of_music_flutter/features/smart_sight_singing/audio/pitch_track.dart';
import 'package:the_road_of_music_flutter/features/smart_sight_singing/audio/realtime_pitch_capture.dart';
import 'package:the_road_of_music_flutter/features/smart_sight_singing/ui/widgets/score_sight_reading_track.dart';

void main() {
  test('MIDI tempo events apply across tracks', () {
    final parsed = MidiFileParser.parse(_typeOneMidiWithTempoTrack());

    expect(parsed.notes, hasLength(1));
    final note = parsed.notes.single;
    expect(note.trackIndex, 2);
    expect(note.startTick, 0);
    expect(note.endTick, 120);
    expect(note.startMs, closeTo(0, 0.001));
    expect(note.endMs, closeTo(1000, 0.001));
  });

  test('MIDI bundle preserves eighth-note rhythm metadata', () {
    final parsed = MidiFileParser.parse(_midiWithQuarterAndEighthNotes());
    final bundle = MidiSightSingingService.buildBundle(parsed, 1);

    expect(bundle.track.notes, hasLength(2));
    expect(bundle.track.notes[0].durationBeats, closeTo(1, 0.0001));
    expect(bundle.track.notes[1].durationBeats, closeTo(0.5, 0.0001));
  });

  test('live pitch detector recognizes a sung A4-like sine frame', () async {
    final detector = LivePitchDetector(sampleRate: 44100, bufferSize: 2048);
    final frame = _sinePcm16Frame(
      frequencyHz: 440,
      sampleRate: 44100,
      sampleCount: 2048,
    );

    final result = await detector.analyzePcm16Frame(frame);

    expect(result.pitched, isTrue);
    expect(result.frequencyHz, closeTo(440, 8));
  });

  test('KTV scoring accepts the same pitch class in another octave', () {
    final track = PitchTrack(
      frames: const <PitchFrame>[],
      notes: const <KtvNoteSegment>[
        KtvNoteSegment(startMs: 0, endMs: 1000, midi: 72),
      ],
      totalMs: 1000,
      frameStepMs: 23,
      minMidi: 60,
      maxMidi: 74,
    );
    final session = KtvScoringSession(track: track);

    session.onPitch(
      playbackMs: 240,
      event: const RealtimePitchEvent(
        frequencyHz: 261.6256,
        midi: 60,
        confidence: 0.9,
        amplitude: 0.3,
        pitched: true,
      ),
    );
    final result = session.finalize();

    expect(result.totalScore, 100);
    expect(result.hitCount, 1);
    expect(result.scoredCount, 1);
  });

  test('KTV scoring reports a provisional score before note end', () {
    final track = PitchTrack(
      frames: const <PitchFrame>[],
      notes: const <KtvNoteSegment>[
        KtvNoteSegment(startMs: 0, endMs: 2000, midi: 60),
      ],
      totalMs: 2000,
      frameStepMs: 23,
      minMidi: 58,
      maxMidi: 62,
    );
    final session = KtvScoringSession(track: track);

    final tick = session.onPitch(
      playbackMs: 400,
      event: const RealtimePitchEvent(
        frequencyHz: 261.6256,
        midi: 60,
        confidence: 0.9,
        amplitude: 0.3,
        pitched: true,
      ),
    );

    expect(tick.totalScore, 100);
    expect(tick.scoredCount, 1);
  });

  test('KTV scoring standard cents controls the hit interval', () {
    final track = PitchTrack(
      frames: const <PitchFrame>[],
      notes: const <KtvNoteSegment>[
        KtvNoteSegment(startMs: 0, endMs: 1000, midi: 60),
      ],
      totalMs: 1000,
      frameStepMs: 23,
      minMidi: 58,
      maxMidi: 62,
    );

    KtvScoringTick scoreWith(double standardCents) {
      final session = KtvScoringSession(
        track: track,
        standardCents: standardCents,
      );
      session.onPitch(
        playbackMs: 240,
        event: const RealtimePitchEvent(
          frequencyHz: 0,
          midi: 60.85,
          confidence: 0.9,
          amplitude: 0.3,
          pitched: true,
        ),
      );
      return session.finalize();
    }

    expect(scoreWith(80).hitCount, 0);
    expect(scoreWith(100).hitCount, 1);
  });

  testWidgets('score sight-reading view renders the melody staff', (
    tester,
  ) async {
    final track = PitchTrack(
      frames: const <PitchFrame>[],
      notes: const <KtvNoteSegment>[
        KtvNoteSegment(startMs: 0, endMs: 500, midi: 60),
        KtvNoteSegment(startMs: 500, endMs: 1000, midi: 64),
        KtvNoteSegment(startMs: 1000, endMs: 1500, midi: 67),
      ],
      totalMs: 1500,
      frameStepMs: 23,
      minMidi: 58,
      maxMidi: 69,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 640,
          height: 240,
          child: ScoreSightReadingTrack(
            track: track,
            playbackMs: 500,
            currentUserMidi: 64,
            currentUserAmplitude: 0.3,
          ),
        ),
      ),
    );

    expect(find.byType(ScoreSightReadingTrack), findsOneWidget);
  });
}

Uint8List _typeOneMidiWithTempoTrack() {
  return Uint8List.fromList(<int>[
    0x4D, 0x54, 0x68, 0x64, // MThd
    0x00, 0x00, 0x00, 0x06,
    0x00, 0x01, // format 1
    0x00, 0x02, // two tracks
    0x00, 0x78, // 120 ticks per quarter
    0x4D, 0x54, 0x72, 0x6B, // MTrk
    0x00, 0x00, 0x00, 0x0B,
    0x00, 0xFF, 0x51, 0x03, 0x0F, 0x42, 0x40, // 60 BPM
    0x00, 0xFF, 0x2F, 0x00,
    0x4D, 0x54, 0x72, 0x6B, // MTrk
    0x00, 0x00, 0x00, 0x0C,
    0x00, 0x90, 0x3C, 0x40, // note on C4
    0x78, 0x80, 0x3C, 0x00, // one quarter later
    0x00, 0xFF, 0x2F, 0x00,
  ]);
}

Uint8List _midiWithQuarterAndEighthNotes() {
  return Uint8List.fromList(<int>[
    0x4D, 0x54, 0x68, 0x64, // MThd
    0x00, 0x00, 0x00, 0x06,
    0x00, 0x00, // format 0
    0x00, 0x01, // one track
    0x00, 0x78, // 120 ticks per quarter
    0x4D, 0x54, 0x72, 0x6B, // MTrk
    0x00, 0x00, 0x00, 0x1B,
    0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, // 120 BPM
    0x00, 0x90, 0x3C, 0x40, // C4 on
    0x78, 0x80, 0x3C, 0x00, // quarter off
    0x00, 0x90, 0x3E, 0x40, // D4 on
    0x3C, 0x80, 0x3E, 0x00, // eighth off
    0x00, 0xFF, 0x2F, 0x00,
  ]);
}

Uint8List _sinePcm16Frame({
  required double frequencyHz,
  required int sampleRate,
  required int sampleCount,
}) {
  final bytes = Uint8List(sampleCount * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    final sample = (math.sin(2 * math.pi * frequencyHz * t) * 22000).round();
    data.setInt16(i * 2, sample, Endian.little);
  }
  return bytes;
}
