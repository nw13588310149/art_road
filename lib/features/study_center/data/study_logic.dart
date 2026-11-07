import 'dart:math' as math;

import 'study_models.dart';

double roundTo(double value, int digits) {
  final factor = math.pow(10, digits).toDouble();
  return (value * factor).round() / factor;
}

/// 与 UI 层 formatScore 规则一致：整数不带小数，其余保留 1 位。
String _fmt(num value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

/// 超过百分之多少的考生：(参考人数 - 名次) / 参考人数，与「第 7 名 / 38 人」可以互相核对。
int? surpassedPercentOf(int? ranking, int? participants) {
  if (ranking == null ||
      participants == null ||
      participants <= 1 ||
      ranking < 1 ||
      ranking > participants) {
    return null;
  }
  return ((participants - ranking) / participants * 100).round();
}

/// 分数变化量：固定一位小数（`5.0`、`1.7`），同一列表里位数一致。
String formatScoreDelta(num value) =>
    ((value.abs() * 10).round() / 10).toStringAsFixed(1);

final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

/// `2026-09-20 08:30:00` → `2026-09-20`。
String studyDateText(String time) {
  final match = _datePattern.firstMatch(time.trim());
  return match == null ? time : '${match[1]}-${match[2]}-${match[3]}';
}

/// `2026-09-20 08:30:00` → `09-20`（坐标轴等窄位置）。
String studyShortDate(String time) {
  final match = _datePattern.firstMatch(time.trim());
  return match == null ? time : '${match[2]}-${match[3]}';
}

/// `2026-09-20` → (9, 20)。
(int, int)? studyMonthDay(String time) {
  final match = _datePattern.firstMatch(time.trim());
  if (match == null) return null;
  return (int.parse(match[2]!), int.parse(match[3]!));
}

/// 「2026 年 9 月月考」→「9月月考」，超长名称截断。
String shortExamName(String name) {
  final text = name
      .replaceAll(RegExp(r'\s+'), '')
      .replaceFirst(RegExp(r'^\d{4}年'), '');
  return text.length > 6 ? '${text.substring(0, 4)}…' : text;
}

/// 分数落在哪一档：取下限不高于分数的最高档。
GradeBandInfo? bandForScore(List<GradeBandInfo> bands, double? score) {
  if (score == null || bands.isEmpty) return null;
  final sorted = [...bands]..sort((a, b) => b.min.compareTo(a.min));
  for (final band in sorted) {
    if (score >= band.min) return band;
  }
  return sorted.last;
}

class ScoreSummary {
  const ScoreSummary({
    this.count = 0,
    this.average,
    this.median,
    this.max,
    this.min,
  });

  final int count;
  final double? average;
  final double? median;
  final double? max;
  final double? min;
}

ScoreSummary summarizeScores(Iterable<double> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return const ScoreSummary();
  final mid = sorted.length ~/ 2;
  final median = sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
  final sum = sorted.fold<double>(0, (total, value) => total + value);
  return ScoreSummary(
    count: sorted.length,
    average: roundTo(sum / sorted.length, 1),
    median: roundTo(median, 1),
    max: sorted.last,
    min: sorted.first,
  );
}

class ScoreBucket {
  const ScoreBucket({
    required this.label,
    required this.count,
    required this.percent,
    this.rangeLabel = '',
    this.grade = '',
  });

  final String label;
  final String rangeLabel;
  final int count;

  /// 占比 0–100。
  final int percent;

  /// 按档位统计时的档位字母。
  final String grade;
}

int _percentOf(int count, int total) =>
    total == 0 ? 0 : (count / total * 100).round();

/// 按档位统计人数（A 档在前），区间为 [本档下限, 上一档下限)。
List<ScoreBucket> bucketsByBands(
  List<double> values,
  List<GradeBandInfo> bands,
) {
  final sorted = [...bands]..sort((a, b) => b.min.compareTo(a.min));
  final buckets = <ScoreBucket>[];
  for (var i = 0; i < sorted.length; i++) {
    final band = sorted[i];
    final upper = i == 0 ? null : sorted[i - 1].min;
    final count = values
        .where((v) => v >= band.min && (upper == null || v < upper))
        .length;
    buckets.add(
      ScoreBucket(
        label: '${band.grade} 档',
        rangeLabel: '${_fmt(band.min)}–${_fmt(band.max)}',
        count: count,
        percent: _percentOf(count, values.length),
        grade: band.grade,
      ),
    );
  }
  return buckets;
}

/// 按档位字母直接统计（没有打分规则时的兜底）。
List<ScoreBucket> bucketsByGrades(
  List<String> grades, {
  List<String> order = const ['A', 'B', 'C', 'D', 'E'],
}) {
  final total = grades.length;
  final letters = [
    ...order,
    for (final grade in grades.toSet())
      if (grade.isNotEmpty && !order.contains(grade)) grade,
  ];
  final buckets = <ScoreBucket>[];
  for (final letter in letters) {
    final count = grades.where((g) => g == letter).length;
    buckets.add(
      ScoreBucket(
        label: '$letter 档',
        count: count,
        percent: _percentOf(count, total),
        grade: letter,
      ),
    );
  }
  return buckets;
}

/// 等宽分数段（默认每 10 分一段），只覆盖实际分数所在区间；段数过多时步长翻倍。
List<ScoreBucket> bucketsByStep(
  List<double> values, {
  double step = 10,
  int maxBuckets = 12,
}) {
  if (values.isEmpty || step <= 0) return const <ScoreBucket>[];
  final low = values.reduce((a, b) => a < b ? a : b);
  final high = values.reduce((a, b) => a > b ? a : b);
  var size = step;
  while ((high / size).floor() - (low / size).floor() + 1 > maxBuckets) {
    size *= 2;
  }
  final start = (low / size).floor() * size;
  final count = ((high - start) / size).floor() + 1;
  final buckets = <ScoreBucket>[];
  for (var i = 0; i < count; i++) {
    final from = start + i * size;
    final to = from + size;
    final hits = values.where((v) => v >= from && v < to).length;
    buckets.add(
      ScoreBucket(
        label: _fmt(from),
        rangeLabel: '${_fmt(from)}–${_fmt(to)}',
        count: hits,
        percent: _percentOf(hits, values.length),
      ),
    );
  }
  return buckets;
}

class GroupStat {
  const GroupStat({
    required this.name,
    required this.count,
    this.average,
    this.max,
  });

  final String name;
  final int count;
  final double? average;
  final double? max;
}

/// 按名称分组求人数 / 平均分 / 最高分，平均分从高到低。
List<GroupStat> groupStats<T>(
  Iterable<T> rows,
  String Function(T row) nameOf,
  double? Function(T row) valueOf,
) {
  final groups = <String, List<double>>{};
  for (final row in rows) {
    final value = valueOf(row);
    if (value == null) continue;
    final name = nameOf(row).trim();
    groups
        .putIfAbsent(name.isEmpty ? '未填写' : name, () => <double>[])
        .add(value);
  }
  final stats = <GroupStat>[];
  groups.forEach((name, values) {
    final summary = summarizeScores(values);
    stats.add(
      GroupStat(
        name: name,
        count: summary.count,
        average: summary.average,
        max: summary.max,
      ),
    );
  });
  stats.sort((a, b) {
    final byAverage = (b.average ?? -1).compareTo(a.average ?? -1);
    if (byAverage != 0) return byAverage;
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.name.compareTo(b.name);
  });
  return stats;
}

enum JudgeMark { highest, lowest }

class ScoreExplanation {
  const ScoreExplanation({
    required this.algorithm,
    required this.marks,
    required this.used,
    this.dropped = const <double>[],
    this.computed,
    this.maxDiff,
    this.exceedsThreshold = false,
    this.consistent = false,
    this.formula = '',
  });

  /// 截尾平均在有效评分少于 3 份时退化为算术平均。
  final ScoringAlgorithm algorithm;

  /// 与评委一一对应：被截尾去掉的分数标记最高 / 最低。
  final List<JudgeMark?> marks;
  final List<double> used;

  /// 被去掉的分数（最高分在前）。
  final List<double> dropped;
  final double? computed;
  final double? maxDiff;
  final bool exceedsThreshold;

  /// 按规则还原的结果与最终得分一致。
  final bool consistent;

  /// 如 `(92 + 93) ÷ 2 = 92.5`；经仲裁、人工调整或无法还原时为空串。
  final String formula;
}

ScoreExplanation explainScore({
  required ScoringAlgorithm algorithm,
  required List<double?> judges,
  double? finalScore,
  double? diffThreshold,
  bool arbitrated = false,
  bool overridden = false,
}) {
  final scoredIndexes = <int>[
    for (var i = 0; i < judges.length; i++)
      if (judges[i] != null) i,
  ];
  final scores = [for (final i in scoredIndexes) judges[i]!];
  final effective = algorithm == ScoringAlgorithm.trimmed && scores.length >= 3
      ? ScoringAlgorithm.trimmed
      : ScoringAlgorithm.mean;
  final marks = List<JudgeMark?>.filled(judges.length, null);
  final dropped = <double>[];
  if (effective == ScoringAlgorithm.trimmed) {
    var highest = scoredIndexes.first;
    var lowest = scoredIndexes.first;
    for (final i in scoredIndexes) {
      if (judges[i]! > judges[highest]!) highest = i;
      if (judges[i]! < judges[lowest]!) lowest = i;
    }
    if (highest == lowest) {
      lowest = scoredIndexes.firstWhere((i) => i != highest);
    }
    marks[highest] = JudgeMark.highest;
    marks[lowest] = JudgeMark.lowest;
    dropped
      ..add(judges[highest]!)
      ..add(judges[lowest]!);
  }
  final used = [
    for (final i in scoredIndexes)
      if (marks[i] == null) judges[i]!,
  ];
  final computed = used.isEmpty
      ? null
      : used.fold<double>(0, (sum, value) => sum + value) / used.length;
  final maxDiff = scores.length >= 2
      ? scores.reduce((a, b) => a > b ? a : b) -
            scores.reduce((a, b) => a < b ? a : b)
      : null;
  final exceeds =
      maxDiff != null && diffThreshold != null && maxDiff > diffThreshold;

  var consistent = false;
  var exact = false;
  if (computed != null && finalScore != null) {
    exact = (computed - finalScore).abs() < 1e-6;
    consistent =
        exact ||
        (roundTo(computed, 1) - finalScore).abs() < 1e-6 ||
        (roundTo(computed, 2) - finalScore).abs() < 1e-6;
  }

  var formula = '';
  if (consistent && !arbitrated && !overridden && finalScore != null) {
    formula = used.length == 1
        ? '${_fmt(used.first)} = ${_fmt(finalScore)}'
        : '(${used.map(_fmt).join(' + ')}) ÷ ${used.length} '
              '${exact ? '=' : '≈'} ${_fmt(finalScore)}';
  }

  return ScoreExplanation(
    algorithm: effective,
    marks: marks,
    used: used,
    dropped: dropped,
    computed: computed,
    maxDiff: maxDiff,
    exceedsThreshold: exceeds,
    consistent: consistent,
    formula: formula,
  );
}

GrowthStatistics growthStatisticsOf(
  List<GrowthPoint> points,
  GrowthMetric metric,
) {
  final valued = [
    for (final point in points)
      if (point.value != null) point,
  ];
  if (valued.isEmpty) return const GrowthStatistics();
  final values = [for (final point in valued) point.value!];
  final ranking = metric == GrowthMetric.ranking;
  final best = values.reduce(
    (a, b) => ranking ? (a < b ? a : b) : (a > b ? a : b),
  );
  final sum = values.fold<double>(0, (total, value) => total + value);
  return GrowthStatistics(
    valueCount: values.length,
    bestValue: best,
    averageValue: roundTo(sum / values.length, 1),
    latestValue: valued.last.value,
    recentChange: valued.last.change,
  );
}

/// 教职端成绩曲线转成长曲线数据：排名变化取「上次名次 - 本次名次」。
GrowthResult growthFromCurve(StudentCurve curve, GrowthMetric metric) {
  final points = <GrowthPoint>[];
  StaffCurvePoint? previous;
  for (final point in curve.points) {
    final double? value;
    final double? change;
    if (metric == GrowthMetric.ranking) {
      final ranking = point.ranking;
      final previousRanking = previous?.ranking;
      value = ranking?.toDouble();
      change = ranking != null && previousRanking != null
          ? (previousRanking - ranking).toDouble()
          : null;
    } else {
      final score = point.score;
      final previousScore = previous?.score;
      value = score;
      change =
          point.scoreChange ??
          (score != null && previousScore != null
              ? roundTo(score - previousScore, 2)
              : null);
    }
    points.add(
      GrowthPoint(
        examId: point.examId,
        examName: point.examName,
        examTime: point.examTime,
        score: point.score,
        maxScore: point.maxScore,
        ranking: point.ranking,
        value: value,
        change: previous == null ? null : change,
      ),
    );
    previous = point;
  }
  return GrowthResult(
    tabs: [
      const GrowthTab(label: '总分'),
      for (final name in curve.subjects)
        GrowthTab(subjectName: name, label: name),
    ],
    points: points,
    statistics: growthStatisticsOf(points, metric),
  );
}

class ChartAxis {
  const ChartAxis({required this.min, required this.max, required this.step});

  final double min;
  final double max;
  final double step;

  List<double> get ticks {
    final result = <double>[];
    if (step <= 0) return result;
    for (var value = min; value <= max + step * 1e-6; value += step) {
      result.add(roundTo(value, 4));
    }
    return result;
  }

  /// 0（min）– 1（max）。
  double fraction(double value) {
    if (max <= min) return 0.5;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }
}

double _niceStep(double raw) {
  if (!raw.isFinite || raw <= 0) return 1;
  final exponent = (math.log(raw) / math.ln10).floor();
  final base = math.pow(10, exponent).toDouble();
  final fraction = raw / base;
  final nice = fraction <= 1
      ? 1.0
      : fraction <= 2
      ? 2.0
      : fraction <= 2.5
      ? 2.5
      : fraction <= 5
      ? 5.0
      : 10.0;
  return nice * base;
}

/// 坐标轴刻度：按「1 / 2 / 2.5 / 5 × 10ⁿ」取整步长，可限定上下界。
ChartAxis niceAxis(
  double low,
  double high, {
  int tickCount = 4,
  bool integer = false,
  double? floor,
  double? ceiling,
}) {
  var lo = math.min(low, high);
  var hi = math.max(low, high);
  if (hi - lo < 1e-9) {
    final pad = integer ? 1.0 : math.max(1.0, lo.abs() * 0.05);
    lo -= pad;
    hi += pad;
  }
  var step = _niceStep((hi - lo) / math.max(1, tickCount));
  if (integer) step = math.max(1, step.ceilToDouble());
  var min = (lo / step).floor() * step;
  var max = (hi / step).ceil() * step;
  if (floor != null && min < floor) min = floor;
  if (ceiling != null && max > ceiling && ceiling > min) max = ceiling;
  if (max <= min) max = min + step;
  final spans = ((max - min) / step - 1e-9).ceil();
  if (ceiling == null || min + spans * step <= ceiling + 1e-9) {
    max = min + spans * step;
  }
  return ChartAxis(min: roundTo(min, 4), max: roundTo(max, 4), step: step);
}

/// 科目名为空时取总分。
double? rowScore(ScoreQueryRow row, String subjectName) =>
    subjectName.isEmpty ? row.totalScore : row.subjectNamed(subjectName)?.score;

int? rowRanking(ScoreQueryRow row, String subjectName) => subjectName.isEmpty
    ? row.totalRanking
    : row.subjectNamed(subjectName)?.ranking;

/// 按总分 / 科目名次排序（无名次的排在最后），再按姓名或准考证号过滤。
List<ScoreQueryRow> rankedScoreRows(
  List<ScoreQueryRow> rows, {
  String subjectName = '',
  String keyword = '',
}) {
  final key = keyword.trim().toUpperCase();
  final filtered = key.isEmpty
      ? [...rows]
      : rows
            .where(
              (row) =>
                  row.studentName.toUpperCase().contains(key) ||
                  row.admissionNo.toUpperCase().contains(key),
            )
            .toList();
  const unranked = 1 << 30;
  filtered.sort((a, b) {
    final byRank = (rowRanking(a, subjectName) ?? unranked).compareTo(
      rowRanking(b, subjectName) ?? unranked,
    );
    if (byRank != 0) return byRank;
    return (rowScore(b, subjectName) ?? -1).compareTo(
      rowScore(a, subjectName) ?? -1,
    );
  });
  return filtered;
}
