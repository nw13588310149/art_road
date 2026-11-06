import '../config/smart_sight_singing_config.dart';
import '../config/smart_sight_singing_tuning.dart';
import 'pitch_track.dart';
import 'realtime_pitch_capture.dart';
import 'ktv_pitch_guide.dart';

/// 评分音准容差。standardCents 是 Good/命中的标准区间。
///
/// 其它两档（Perfect / OK）按 [SightSingingTuning] 中的比例换算，
/// 调试面板修改 perfect/ok 比例后实时生效。
class KtvScoringTolerance {
  const KtvScoringTolerance({
    required this.perfectCents,
    required this.goodCents,
    required this.okCents,
  });

  factory KtvScoringTolerance.fromStandardCents(double standardCents) {
    final good = SmartSightSingingScoringConfig.normalizeStandardCents(
      standardCents,
    );
    final tuning = SightSingingTuning.instance;
    final perfectRatio =
        tuning.perfectCentsAtDefault /
        SmartSightSingingScoringConfig.defaultStandardCents;
    final okRatio =
        tuning.okCentsAtDefault /
        SmartSightSingingScoringConfig.defaultStandardCents;
    return KtvScoringTolerance(
      perfectCents: good * perfectRatio,
      goodCents: good,
      okCents: good * okRatio,
    );
  }

  final double perfectCents;
  final double goodCents;
  final double okCents;
}

/// 单个音符的评分结果。
class KtvNoteScore {
  const KtvNoteScore({
    required this.noteIndex,
    required this.startMs,
    required this.endMs,
    required this.refMidi,
    required this.userMidi,
    required this.cents,
    required this.points,
    required this.hitLevel,
  });

  final int noteIndex;
  final int startMs;
  final int endMs;
  final double refMidi;
  final double userMidi;
  final double cents;
  final int points;

  /// perfect / good / ok / miss
  final String hitLevel;

  bool get isHit => points >= SmartSightSingingScoringConfig.goodPoints;

  int get durationMs {
    final d = endMs - startMs;
    return d < 0 ? 0 : d;
  }
}

/// KTV 打分会话：在用户跟唱过程中按音符结算。
///
/// 所有可调参数（mic 延迟、早晚窗、音准容差、是否八度归一）都实时
/// 从 [SightSingingTuning] 读取，调试面板拖动后下一帧立即生效。
class KtvScoringSession {
  KtvScoringSession({
    required PitchTrack track,
    double standardCents = SmartSightSingingScoringConfig.defaultStandardCents,
  }) : _track = track,
       _standardCents = standardCents;

  final PitchTrack _track;
  double _standardCents;

  KtvScoringTolerance get _tolerance =>
      KtvScoringTolerance.fromStandardCents(_standardCents);

  int? _activeNoteIndex;
  final List<double> _userMidis = <double>[];
  final List<KtvNoteScore> _completed = <KtvNoteScore>[];
  int _combo = 0;
  int _maxCombo = 0;

  List<KtvNoteScore> get completedScores =>
      List<KtvNoteScore>.unmodifiable(_completed);

  int get combo => _combo;
  int get maxCombo => _maxCombo;

  /// 实时调整音准容差（不影响已结算音符）。
  void updateStandardCents(double cents) {
    _standardCents = cents;
  }

  /// 当前累计得分 0~100（按时长加权的已完成音符平均分）。
  /// 改成时长加权后，短装饰音失误不会等同于长音失误，更符合教学。
  int get totalScore => _weightedAverage(_completed);

  int get hitCount => _completed.where((s) => s.isHit).length;
  int get scoredCount => _completed.length;

  int get _liveTotalScore {
    final preview = _previewActiveNoteScore();
    if (preview == null) return totalScore;
    return _weightedAverage([..._completed, preview]);
  }

  int get _liveHitCount {
    final preview = _previewActiveNoteScore();
    return hitCount + ((preview?.isHit ?? false) ? 1 : 0);
  }

  int get _liveScoredCount {
    final preview = _previewActiveNoteScore();
    return scoredCount + (preview == null ? 0 : 1);
  }

  static int _weightedAverage(List<KtvNoteScore> scores) {
    if (scores.isEmpty) return 0;
    var totalWeight = 0;
    var totalScoreWeighted = 0;
    for (final s in scores) {
      // 至少给 80ms 的权重，避免极短装饰音权重为 0。
      final w = s.durationMs < 80 ? 80 : s.durationMs;
      totalWeight += w;
      totalScoreWeighted += s.points * w;
    }
    if (totalWeight == 0) return 0;
    return (totalScoreWeighted / totalWeight).round().clamp(0, 100);
  }

  /// 处理一帧实时音高；返回当前应展示给用户的信息。
  KtvScoringTick onPitch({
    required int playbackMs,
    required RealtimePitchEvent event,
  }) {
    final tuning = SightSingingTuning.instance;
    final evalMs = playbackMs - tuning.micLatencyMs;
    final noteIndex = _track.noteIndexAt(
      evalMs,
      earlyMs: tuning.earlySingMs,
      lateMs: tuning.lateSingMs,
    );
    final note = noteIndex == null ? null : _track.notes[noteIndex];

    if (_activeNoteIndex != noteIndex) {
      _finalizeActiveNote();
      _activeNoteIndex = noteIndex;
      _userMidis.clear();
    }

    if (event.pitched && note != null) {
      _userMidis.add(event.midi);
    }

    final refFrame = _track.sampleAt(evalMs);
    final refMidi = refFrame?.midi ?? -1;
    double cents = double.nan;
    if (event.pitched && refFrame != null && refFrame.pitched) {
      cents = _centsForScoring(event.midi, refFrame.midi);
    }

    return KtvScoringTick(
      totalScore: _liveTotalScore,
      hitCount: _liveHitCount,
      scoredCount: _liveScoredCount,
      combo: _combo,
      cents: cents,
      refMidi: refMidi,
      userMidi: event.pitched ? event.midi : -1,
    );
  }

  /// 演唱结束或切歌时，结算最后一个音符。
  KtvScoringTick finalize() {
    _finalizeActiveNote();
    return KtvScoringTick(
      totalScore: totalScore,
      hitCount: hitCount,
      scoredCount: scoredCount,
      combo: _combo,
      cents: double.nan,
      refMidi: -1,
      userMidi: -1,
    );
  }

  void _finalizeActiveNote() {
    final index = _activeNoteIndex;
    if (index == null || index < 0 || index >= _track.notes.length) {
      return;
    }
    final note = _track.notes[index];
    final score = _gradeNote(
      note: note,
      noteIndex: index,
      userMidis: _userMidis,
      tolerance: _tolerance,
    );
    _completed.add(score);
    if (score.isHit) {
      _combo += 1;
      if (_combo > _maxCombo) _maxCombo = _combo;
    } else {
      _combo = 0;
    }
    _userMidis.clear();
  }

  KtvNoteScore? _previewActiveNoteScore() {
    final index = _activeNoteIndex;
    if (index == null ||
        index < 0 ||
        index >= _track.notes.length ||
        _userMidis.isEmpty) {
      return null;
    }
    return _gradeNote(
      note: _track.notes[index],
      noteIndex: index,
      userMidis: _userMidis,
      tolerance: _tolerance,
    );
  }

  /// 评分时计算偏差：默认八度归一，可在 tuning 中关闭后变为严格音域。
  static double _centsForScoring(double userMidi, double refMidi) {
    if (!userMidi.isFinite || !refMidi.isFinite) return double.nan;
    if (SightSingingTuning.instance.octaveNormalizeScoring) {
      return PitchUtils.octaveNormalizedCents(userMidi, refMidi);
    }
    return (userMidi - refMidi) * 100;
  }

  static KtvNoteScore _gradeNote({
    required KtvNoteSegment note,
    required int noteIndex,
    required List<double> userMidis,
    required KtvScoringTolerance tolerance,
  }) {
    if (userMidis.isEmpty) {
      return KtvNoteScore(
        noteIndex: noteIndex,
        startMs: note.startMs,
        endMs: note.endMs,
        refMidi: note.midi,
        userMidi: -1,
        cents: double.nan,
        points: 0,
        hitLevel: 'miss',
      );
    }

    final sorted = List<double>.from(userMidis)..sort();
    final userMidi = sorted[sorted.length ~/ 2];
    final cents = _centsForScoring(userMidi, note.midi);
    final absCents = cents.abs();

    late int points;
    late String level;
    if (absCents <= tolerance.perfectCents) {
      points = SmartSightSingingScoringConfig.perfectPoints;
      level = 'perfect';
    } else if (absCents <= tolerance.goodCents) {
      points = SmartSightSingingScoringConfig.goodPoints;
      level = 'good';
    } else if (absCents <= tolerance.okCents) {
      points = SmartSightSingingScoringConfig.okPoints;
      level = 'ok';
    } else {
      points = 0;
      level = 'miss';
    }

    return KtvNoteScore(
      noteIndex: noteIndex,
      startMs: note.startMs,
      endMs: note.endMs,
      refMidi: note.midi,
      userMidi: userMidi,
      cents: cents,
      points: points,
      hitLevel: level,
    );
  }
}

class KtvScoringTick {
  const KtvScoringTick({
    required this.totalScore,
    required this.hitCount,
    required this.scoredCount,
    required this.combo,
    required this.cents,
    required this.refMidi,
    required this.userMidi,
  });

  final int totalScore;
  final int hitCount;
  final int scoredCount;
  final int combo;
  final double cents;
  final double refMidi;
  final double userMidi;
}
