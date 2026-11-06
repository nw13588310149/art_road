import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio/ktv_pitch_guide.dart';
import '../../audio/pitch_track.dart';
import '../../config/smart_sight_singing_config.dart';
import '../../state/smart_sight_singing_state.dart';

/// 谱例视唱视图：把 MIDI 主旋律轨绘制成五线谱滚动谱例。
class ScoreSightReadingTrack extends StatelessWidget {
  const ScoreSightReadingTrack({
    required this.track,
    required this.playbackMs,
    required this.currentUserMidi,
    this.userPoints = const <UserPitchPoint>[],
    this.currentUserAmplitude = 0,
    this.scoringStandardCents =
        SmartSightSingingScoringConfig.defaultStandardCents,
    this.windowMs = SmartSightSingingViewConfig.scoreWindowMs,
    super.key,
  });

  final PitchTrack track;
  final int playbackMs;
  final double currentUserMidi;
  final List<UserPitchPoint> userPoints;
  final double currentUserAmplitude;
  final double scoringStandardCents;
  final int windowMs;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ScoreSightReadingPainter(
              track: track,
              playbackMs: playbackMs,
              currentUserMidi: currentUserMidi,
              userPoints: userPoints,
              currentUserAmplitude: currentUserAmplitude,
              scoringStandardCents: scoringStandardCents,
              windowMs: windowMs,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _ScoreSightReadingPainter extends CustomPainter {
  _ScoreSightReadingPainter({
    required this.track,
    required this.playbackMs,
    required this.currentUserMidi,
    required this.userPoints,
    required this.currentUserAmplitude,
    required this.scoringStandardCents,
    required this.windowMs,
  });

  final PitchTrack track;
  final int playbackMs;
  final double currentUserMidi;
  final List<UserPitchPoint> userPoints;
  final double currentUserAmplitude;
  final double scoringStandardCents;
  final int windowMs;

  static const _bg = Color(0xFFF5F6F8);
  static const _staff = Color(0xFF6B7280);
  static const _note = Color(0xFF4A5568);
  static const _noteMuted = Color(0xFF9CA3AF);
  static const _notePast = Color(0xFFC4C9D1);
  static const _active = Color(0xFF1A1A1A);
  static const _user = Color(0xFF4A5568);
  static const _userGood = Color(0xFF2E7D5B);
  static const _userOk = Color(0xFFB7791F);
  static const _userMiss = Color(0xFFC05621);

  static const int _e4Step = SmartSightSingingViewConfig.trebleStaffBottomStep;
  static const int _f5Step = SmartSightSingingViewConfig.trebleStaffTopStep;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);

    final notes = track.notes;
    if (notes.isEmpty || size.isEmpty) return;

    final lineSpacing =
        (size.height *
                SmartSightSingingViewConfig.scoreLineSpacingHeightFraction)
            .clamp(12.0, 20.0)
            .toDouble();
    final halfStep = lineSpacing / 2;
    final staffTop = (size.height - lineSpacing * 4) / 2;
    final staffBottom = staffTop + lineSpacing * 4;
    final centerX =
        size.width * SmartSightSingingViewConfig.scoreNowLineFraction;
    final pxPerMs = size.width / windowMs;
    final visibleStartMs = playbackMs - windowMs ~/ 2;
    final visibleEndMs = playbackMs + windowMs ~/ 2;

    double xFromTime(int ms) => centerX + (ms - playbackMs) * pxPerMs;
    double yFromStep(int step) => staffBottom - (step - _e4Step) * halfStep;
    double yFromMidi(double midi) => yFromStep(_spell(midi).step);

    final staffPaint = Paint()
      ..color = _staff
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = staffTop + i * lineSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), staffPaint);
    }

    _drawClef(canvas, Offset(18, staffTop - lineSpacing * 0.35), lineSpacing);

    final restY = staffTop + lineSpacing * 2;
    for (final note in notes) {
      if (note.endMs < visibleStartMs || note.startMs > visibleEndMs) {
        continue;
      }
      final x0 = xFromTime(note.startMs);
      final x1 = xFromTime(note.endMs).clamp(x0 + 12, size.width + 48);
      final active = playbackMs >= note.startMs && playbackMs <= note.endMs;
      final past = note.endMs < playbackMs;
      final color = active
          ? _active
          : past
          ? _notePast
          : _note;

      if (note.isRest) {
        _drawDurationGuide(canvas, x0, x1, restY, color, active);
        _drawRest(canvas, note, Offset(x0, restY), color, active);
        continue;
      }

      final y = yFromMidi(note.midi);
      _drawDurationGuide(canvas, x0, x1, y, color, active);
      _drawLedgerLines(canvas, x0, yFromStep, _spell(note.midi).step, color);
      _drawNote(canvas, note, Offset(x0, y), color, active);
    }

    _drawUserTrace(canvas, visibleStartMs, visibleEndMs, xFromTime, yFromMidi);

    final nowPaint = Paint()
      ..color = _active
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(centerX, 8),
      Offset(centerX, size.height - 8),
      nowPaint,
    );

    if (currentUserMidi >= 0) {
      final ref = track.sampleAt(playbackMs);
      final displayMidi = _displayUserMidi(currentUserMidi, ref?.midi);
      final y = yFromMidi(displayMidi);
      if (ref != null && ref.pitched) {
        final refY = yFromMidi(ref.midi);
        canvas.drawLine(
          Offset(centerX, refY),
          Offset(centerX, y),
          Paint()
            ..color = _comparisonColor(
              PitchUtils.octaveNormalizedCents(displayMidi, ref.midi),
            ).withValues(alpha: 0.45)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawCircle(
        Offset(centerX, y),
        13,
        Paint()
          ..color = _user.withValues(
            alpha: (0.10 + currentUserAmplitude * 0.22).clamp(0.10, 0.30),
          ),
      );
      canvas.drawCircle(
        Offset(centerX, y),
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _user.withValues(alpha: 0.75),
      );
    } else if (currentUserAmplitude >
        SmartSightSingingViewConfig.micActivityIndicatorMinAmplitude) {
      final barW = (8 + currentUserAmplitude * 40).clamp(8.0, 36.0);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size.height - 18),
          width: barW,
          height: 6,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = _noteMuted.withValues(
            alpha: 0.35 + currentUserAmplitude * 0.4,
          ),
      );
    }
  }

  void _drawUserTrace(
    Canvas canvas,
    int visibleStartMs,
    int visibleEndMs,
    double Function(int ms) xFromTime,
    double Function(double midi) yFromMidi,
  ) {
    Offset? previous;
    int? previousMs;
    for (final point in userPoints) {
      if (!point.pitched ||
          point.timeMs < visibleStartMs ||
          point.timeMs > visibleEndMs) {
        previous = null;
        previousMs = null;
        continue;
      }

      final ref = track.sampleAt(point.timeMs);
      final displayMidi = _displayUserMidi(point.midi, ref?.midi);
      final current = Offset(xFromTime(point.timeMs), yFromMidi(displayMidi));
      final color = _comparisonColor(point.cents);
      final alpha = (0.32 + point.amplitude * 0.42).clamp(0.32, 0.78);

      if (previous != null &&
          previousMs != null &&
          point.timeMs - previousMs <= 180) {
        canvas.drawLine(
          previous,
          current,
          Paint()
            ..color = color.withValues(alpha: alpha * 0.72)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawCircle(
        current,
        (2.5 + point.amplitude * 4).clamp(2.5, 6.0),
        Paint()..color = color.withValues(alpha: alpha),
      );
      previous = current;
      previousMs = point.timeMs;
    }
  }

  void _drawClef(Canvas canvas, Offset offset, double lineSpacing) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          color: _staff.withValues(alpha: 0.78),
          fontSize: lineSpacing * 3.0,
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawDurationGuide(
    Canvas canvas,
    double x0,
    double x1,
    double y,
    Color color,
    bool active,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: active ? 0.28 : 0.16)
      ..strokeWidth = active ? 5 : 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), paint);
  }

  void _drawRest(
    Canvas canvas,
    KtvNoteSegment note,
    Offset anchor,
    Color color,
    bool active,
  ) {
    final value = _noteValue(note);
    final paint = Paint()
      ..color = active ? _active : color
      ..style = PaintingStyle.fill;

    switch (value) {
      case _ScoreNoteValue.whole:
        canvas.drawRect(
          Rect.fromCenter(
            center: anchor + const Offset(0, -2),
            width: 18,
            height: 5,
          ),
          paint,
        );
      case _ScoreNoteValue.half:
        canvas.drawRect(
          Rect.fromCenter(
            center: anchor + const Offset(0, -3),
            width: 16,
            height: 4.5,
          ),
          paint,
        );
      default:
        final path = Path()
          ..moveTo(anchor.dx - 2, anchor.dy + 2)
          ..cubicTo(
            anchor.dx + 6,
            anchor.dy - 10,
            anchor.dx + 14,
            anchor.dy + 4,
            anchor.dx + 4,
            anchor.dy + 10,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = active ? _active : color
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 2.2 : 1.8
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  void _drawNote(
    Canvas canvas,
    KtvNoteSegment note,
    Offset center,
    Color color,
    bool active,
  ) {
    final spelling = _spell(note.midi);
    if (spelling.accidental != null) {
      _drawAccidental(canvas, spelling.accidental!, center, color);
    }

    final value = _noteValue(note);
    final notePaint = Paint()
      ..color = _noteHeadFilled(note) ? (active ? _active : color) : _bg
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = active ? _active : color
      ..strokeWidth = active ? 1.8 : 1.3
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 10);
    final headWidth = value == _ScoreNoteValue.whole ? 19.0 : 16.0;
    final headHeight = value == _ScoreNoteValue.whole ? 10.5 : 11.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: headWidth,
        height: headHeight,
      ),
      notePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: headWidth,
        height: headHeight,
      ),
      outline,
    );
    canvas.restore();

    if (value == _ScoreNoteValue.whole) return;

    final stemUp = spelling.step < 34;
    final stemStart = stemUp
        ? Offset(center.dx + 7, center.dy)
        : Offset(center.dx - 7, center.dy);
    final stemEnd = stemUp
        ? Offset(center.dx + 7, center.dy - 34)
        : Offset(center.dx - 7, center.dy + 34);
    canvas.drawLine(
      stemStart,
      stemEnd,
      Paint()
        ..color = active ? _active : color
        ..strokeWidth = 1.5,
    );

    final flagCount = switch (value) {
      _ScoreNoteValue.eighth => 1,
      _ScoreNoteValue.sixteenth => 2,
      _ => 0,
    };
    if (flagCount > 0) {
      _drawFlags(canvas, stemEnd, stemUp, active ? _active : color, flagCount);
    }
  }

  void _drawFlags(
    Canvas canvas,
    Offset stemEnd,
    bool stemUp,
    Color color,
    int count,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final dy = i * (stemUp ? 7.0 : -7.0);
      final start = Offset(stemEnd.dx, stemEnd.dy + dy);
      final path = Path()..moveTo(start.dx, start.dy);
      if (stemUp) {
        path.cubicTo(
          start.dx + 13,
          start.dy + 4,
          start.dx + 15,
          start.dy + 13,
          start.dx + 4,
          start.dy + 18,
        );
      } else {
        path.cubicTo(
          start.dx + 13,
          start.dy - 4,
          start.dx + 15,
          start.dy - 13,
          start.dx + 4,
          start.dy - 18,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawAccidental(
    Canvas canvas,
    String accidental,
    Offset noteCenter,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: accidental,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(noteCenter.dx - 23, noteCenter.dy - painter.height / 2),
    );
  }

  void _drawLedgerLines(
    Canvas canvas,
    double x,
    double Function(int step) yFromStep,
    int step,
    Color color,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    if (step < _e4Step) {
      var ledger = _e4Step - 2;
      while (ledger >= step) {
        final y = yFromStep(ledger);
        canvas.drawLine(Offset(x - 13, y), Offset(x + 13, y), paint);
        ledger -= 2;
      }
      return;
    }
    if (step > _f5Step) {
      var ledger = _f5Step + 2;
      while (ledger <= step) {
        final y = yFromStep(ledger);
        canvas.drawLine(Offset(x - 13, y), Offset(x + 13, y), paint);
        ledger += 2;
      }
    }
  }

  double _displayUserMidi(double userMidi, double? refMidi) {
    if (refMidi == null || refMidi < 0) return userMidi;
    final cents = PitchUtils.octaveNormalizedCents(userMidi, refMidi);
    if (!cents.isFinite) return userMidi;
    return refMidi + cents / 100;
  }

  Color _comparisonColor(double cents) {
    final absCents = cents.abs();
    if (!absCents.isFinite) return _user;
    final goodCents = SmartSightSingingScoringConfig.normalizeStandardCents(
      scoringStandardCents,
    );
    final okCents =
        goodCents *
        SmartSightSingingScoringConfig.okCentsAtDefault /
        SmartSightSingingScoringConfig.defaultStandardCents;
    if (absCents <= goodCents) {
      return _userGood;
    }
    if (absCents <= okCents) {
      return _userOk;
    }
    return _userMiss;
  }

  bool _noteHeadFilled(KtvNoteSegment note) {
    return switch (_noteValue(note)) {
      _ScoreNoteValue.whole || _ScoreNoteValue.half => false,
      _ => true,
    };
  }

  _ScoreNoteValue _noteValue(KtvNoteSegment note) {
    final beats = note.durationBeats;
    if (beats == null || !beats.isFinite || beats <= 0) {
      return note.durationMs <= 300
          ? _ScoreNoteValue.eighth
          : _ScoreNoteValue.quarter;
    }
    if (beats >= 3.2) return _ScoreNoteValue.whole;
    if (beats >= 1.6) return _ScoreNoteValue.half;
    if (beats > 0.75) return _ScoreNoteValue.quarter;
    if (beats > 0.37) return _ScoreNoteValue.eighth;
    return _ScoreNoteValue.sixteenth;
  }

  _StaffSpelling _spell(double midi) {
    final rounded = midi.round();
    final octave = (rounded ~/ 12) - 1;
    final pc = ((rounded % 12) + 12) % 12;
    return switch (pc) {
      0 => _StaffSpelling(step: octave * 7, accidental: null),
      1 => _StaffSpelling(step: octave * 7, accidental: '#'),
      2 => _StaffSpelling(step: octave * 7 + 1, accidental: null),
      3 => _StaffSpelling(step: octave * 7 + 1, accidental: '#'),
      4 => _StaffSpelling(step: octave * 7 + 2, accidental: null),
      5 => _StaffSpelling(step: octave * 7 + 3, accidental: null),
      6 => _StaffSpelling(step: octave * 7 + 3, accidental: '#'),
      7 => _StaffSpelling(step: octave * 7 + 4, accidental: null),
      8 => _StaffSpelling(step: octave * 7 + 4, accidental: '#'),
      9 => _StaffSpelling(step: octave * 7 + 5, accidental: null),
      10 => _StaffSpelling(step: octave * 7 + 5, accidental: '#'),
      _ => _StaffSpelling(step: octave * 7 + 6, accidental: null),
    };
  }

  @override
  bool shouldRepaint(covariant _ScoreSightReadingPainter old) {
    return old.track != track ||
        old.playbackMs != playbackMs ||
        old.currentUserMidi != currentUserMidi ||
        old.userPoints != userPoints ||
        old.currentUserAmplitude != currentUserAmplitude ||
        old.scoringStandardCents != scoringStandardCents ||
        old.windowMs != windowMs;
  }
}

enum _ScoreNoteValue { whole, half, quarter, eighth, sixteenth }

class _StaffSpelling {
  const _StaffSpelling({required this.step, required this.accidental});

  final int step;
  final String? accidental;
}
