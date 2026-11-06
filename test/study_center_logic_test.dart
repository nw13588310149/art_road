import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/features/study_center/data/study_logic.dart';
import 'package:the_road_of_art_flutter/features/study_center/data/study_models.dart';
import 'package:the_road_of_art_flutter/features/study_center/state/study_center_args.dart';

const _bands = <GradeBandInfo>[
  GradeBandInfo(grade: 'A', min: 90, max: 100),
  GradeBandInfo(grade: 'B', min: 80, max: 89.5),
  GradeBandInfo(grade: 'C', min: 70, max: 79.5),
  GradeBandInfo(grade: 'D', min: 60, max: 69.5),
  GradeBandInfo(grade: 'E', min: 0, max: 59.5),
];

ScoreQueryRow _row(
  String name,
  double total,
  int rank,
  double color,
  int colorRank,
) {
  return ScoreQueryRow(
    studentId: name,
    archiveId: name,
    studentName: name,
    admissionNo: 'A26$rank',
    totalScore: total,
    totalRanking: rank,
    subjectScores: [
      ScoreQuerySubject(
        subjectId: '39',
        subjectName: '色彩',
        score: color,
        ranking: colorRank,
      ),
    ],
  );
}

void main() {
  group('explainScore', () {
    test('mean of two judges builds the formula', () {
      final result = explainScore(
        algorithm: ScoringAlgorithm.mean,
        judges: [92, 93],
        finalScore: 92.5,
        diffThreshold: 10,
      );
      expect(result.formula, '(92 + 93) ÷ 2 = 92.5');
      expect(result.maxDiff, 1.0);
      expect(result.exceedsThreshold, isFalse);
      expect(result.marks, [null, null]);
    });

    test('trimmed mean drops one highest and one lowest score', () {
      final result = explainScore(
        algorithm: ScoringAlgorithm.trimmed,
        judges: [84, 86, 85, 90, 82],
        finalScore: 85,
        diffThreshold: 10,
      );
      expect(result.algorithm, ScoringAlgorithm.trimmed);
      expect(result.marks, [
        null,
        null,
        null,
        JudgeMark.highest,
        JudgeMark.lowest,
      ]);
      expect(result.used, [84.0, 86.0, 85.0]);
      expect(result.dropped, [90.0, 82.0]);
      expect(result.formula, '(84 + 86 + 85) ÷ 3 = 85');
    });

    test('rounded average is shown as approximately equal', () {
      final result = explainScore(
        algorithm: ScoringAlgorithm.trimmed,
        judges: [84, 85, 87, 80, 90],
        finalScore: 85.3,
      );
      expect(result.formula, '(84 + 85 + 87) ÷ 3 ≈ 85.3');
    });

    test('arbitrated result has no formula and exceeds the threshold', () {
      final result = explainScore(
        algorithm: ScoringAlgorithm.mean,
        judges: [91, 76],
        finalScore: 85,
        diffThreshold: 10,
        arbitrated: true,
      );
      expect(result.formula, isEmpty);
      expect(result.maxDiff, 15.0);
      expect(result.exceedsThreshold, isTrue);
    });

    test('trimmed falls back to mean with fewer than three scores', () {
      final result = explainScore(
        algorithm: ScoringAlgorithm.trimmed,
        judges: [80, 82],
        finalScore: 81,
      );
      expect(result.algorithm, ScoringAlgorithm.mean);
      expect(result.dropped, isEmpty);
      expect(result.formula, '(80 + 82) ÷ 2 = 81');
    });

    test('no judges means nothing to explain', () {
      final result = explainScore(
        algorithm: ScoringAlgorithm.mean,
        judges: const [],
        finalScore: 70.5,
      );
      expect(result.formula, isEmpty);
      expect(result.maxDiff, isNull);
    });
  });

  test('surpassedPercentOf follows (N - rank) / (N - 1)', () {
    expect(surpassedPercentOf(7, 38), 84);
    expect(surpassedPercentOf(1, 38), 100);
    expect(surpassedPercentOf(38, 38), 0);
    expect(surpassedPercentOf(1, 1), isNull);
    expect(surpassedPercentOf(null, 38), isNull);
  });

  test('summarizeScores computes average, median and extremes', () {
    final summary = summarizeScores([231, 240.5, 248.5, 246, 256.5, 265.5]);
    expect(summary.count, 6);
    expect(summary.average, 248.0);
    expect(summary.median, 247.3);
    expect(summary.max, 265.5);
    expect(summary.min, 231.0);
    expect(summarizeScores(const []).average, isNull);
  });

  group('score buckets', () {
    test('bands use [min, previous min) so gaps between bands are covered', () {
      final buckets = bucketsByBands([92.5, 89.7, 85, 70, 59.9, 60], _bands);
      expect(buckets.map((b) => b.count), [1, 2, 1, 1, 1]);
      expect(buckets.first.label, 'A 档');
      expect(buckets.first.rangeLabel, '90–100');
      expect(buckets[1].percent, 33);
    });

    test('steps only span the occupied range', () {
      final buckets = bucketsByStep([202.5, 215, 230, 280.5, 279]);
      expect(buckets.first.label, '200');
      expect(buckets.last.label, '280');
      expect(buckets, hasLength(9));
      expect(buckets.fold<int>(0, (sum, b) => sum + b.count), 5);
    });

    test('steps double when the range is too wide', () {
      final buckets = bucketsByStep([10, 290]);
      expect(buckets.length, lessThanOrEqualTo(12));
      expect(buckets.first.rangeLabel, '0–40');
    });

    test('grades fall back to letters A–E plus extras', () {
      final buckets = bucketsByGrades(['A', 'B', 'B', 'F']);
      expect(buckets.map((b) => b.label), [
        'A 档',
        'B 档',
        'C 档',
        'D 档',
        'E 档',
        'F 档',
      ]);
      expect(buckets[1].count, 2);
    });
  });

  test('groupStats sorts campuses by average', () {
    final groups = groupStats<(String, double?)>(
      [('城东', 250), ('城西', 240), ('城东', 260), ('安宁', null)],
      (row) => row.$1,
      (row) => row.$2,
    );
    expect(groups.map((g) => g.name), ['城东', '城西']);
    expect(groups.first.average, 255.0);
    expect(groups.first.count, 2);
  });

  group('growth', () {
    const curve = StudentCurve(
      points: [
        StaffCurvePoint(examId: '21', score: 231, ranking: 8),
        StaffCurvePoint(
          examId: '22',
          score: 240.5,
          ranking: 9,
          scoreChange: 9.5,
        ),
        StaffCurvePoint(
          examId: '26',
          score: 265.5,
          ranking: 7,
          scoreChange: 25,
        ),
      ],
      subjects: ['素描', '色彩'],
    );

    test('ranking change is positive when the rank number drops', () {
      final result = growthFromCurve(curve, GrowthMetric.ranking);
      expect(result.points.map((p) => p.value), [8.0, 9.0, 7.0]);
      expect(result.points.map((p) => p.change), [null, -1.0, 2.0]);
      expect(result.statistics.bestValue, 7.0);
      expect(result.statistics.recentChange, 2.0);
      expect(result.tabs.map((t) => t.label), ['总分', '素描', '色彩']);
    });

    test('score metric uses the reported score change', () {
      final result = growthFromCurve(curve, GrowthMetric.score);
      expect(result.points.map((p) => p.change), [null, 9.5, 25.0]);
      expect(result.statistics.bestValue, 265.5);
      expect(result.statistics.averageValue, 245.7);
    });
  });

  group('niceAxis', () {
    test('score axis rounds to tidy steps', () {
      final axis = niceAxis(231, 265.5, floor: 0, ceiling: 300);
      expect(axis.min, 230);
      expect(axis.max, 270);
      expect(axis.ticks, [230, 240, 250, 260, 270]);
    });

    test('ranking axis is integer and never goes below 1', () {
      final axis = niceAxis(1, 9, integer: true, floor: 1);
      expect(axis.min, 1);
      expect(axis.step, 2);
      expect(axis.ticks.first, 1);
    });

    test('single value gets padding around it', () {
      final axis = niceAxis(7, 7, integer: true, floor: 1);
      expect(axis.min, lessThan(7));
      expect(axis.max, greaterThan(7));
    });
  });

  test('rankedScoreRows sorts by subject ranking and filters by keyword', () {
    final rows = [
      _row('甲', 250, 2, 80, 3),
      _row('乙', 260, 1, 85, 2),
      _row('丙', 240, 3, 90, 1),
    ];
    expect(rankedScoreRows(rows).map((r) => r.studentName), ['乙', '甲', '丙']);
    expect(rankedScoreRows(rows, subjectName: '色彩').map((r) => r.studentName), [
      '丙',
      '乙',
      '甲',
    ]);
    expect(rankedScoreRows(rows, keyword: 'a263').map((r) => r.studentName), [
      '丙',
    ]);
  });

  test('bandForScore picks the highest band whose minimum is reached', () {
    expect(bandForScore(_bands, 92.5)?.grade, 'A');
    expect(bandForScore(_bands, 89.7)?.grade, 'B');
    expect(bandForScore(_bands, null), isNull);
  });

  group('parsing', () {
    test('grade standard accepts both student and school shapes', () {
      final student = GradeStandard.fromJson({
        'subjectId': '38',
        'subjectName': '素描',
        'fullScore': 100,
        'algorithm': 'trimmed',
        'diffThreshold': 10,
        'bands': [
          {'grade': 'B', 'min': 80, 'max': 89.5, 'description': 'b'},
          {'grade': 'A', 'min': 90, 'max': 100, 'imageUrl': 'http://x/a.jpg'},
        ],
      });
      expect(student.algorithm, ScoringAlgorithm.trimmed);
      expect(student.bands.map((b) => b.grade), ['A', 'B']);
      expect(student.topBand?.imageUrl, 'http://x/a.jpg');

      final school = GradeStandard.fromJson({
        'score': 100,
        'algorithm': 0,
        'gradeList': [
          {
            'grade': 'a',
            'min': 90,
            'max': 100,
            'imgUrl': 'u',
            'imgUrlDesc': 'd',
          },
        ],
      }, subjectId: '39');
      expect(school.fullScore, 100);
      expect(school.subjectId, '39');
      expect(school.algorithm, ScoringAlgorithm.mean);
      expect(school.bands.single.description, 'd');
      expect(school.bands.single.grade, 'A');
    });

    test('marking review reads arbitration and judges', () {
      final review = MarkingReview.fromJson({
        'review': {
          'paperUrl': 'http://x/p.jpg',
          'finalScore': 85,
          'finalGrade': 'B',
          'algorithm': 1,
          'diffThreshold': 10,
          'arbitrationStatus': 'RESOLVED',
          'everArbitrated': true,
          'teachers': [
            {'teacherName': '周强', 'score': 91, 'grade': 'A', 'comment': '好'},
          ],
        },
        'maxScore': 100,
        'bands': [
          {'grade': 'A', 'minScore': 90, 'maxScore': 100},
        ],
      });
      expect(review.arbitrated, isTrue);
      expect(review.arbitrationPending, isFalse);
      expect(review.algorithm, ScoringAlgorithm.trimmed);
      expect(review.teachers.single.score, 91.0);
      expect(review.bands.single.max, 100.0);
    });

    test('exam report falls back to exam subjects and keeps changes', () {
      final report = StudyExamReport.fromJson({
        'exam': {
          'examId': '26',
          'status': 'PUBLISHED',
          'totalScore': 265.5,
          'maxScore': 300,
          'examTime': '2026-09-20 08:30:00',
          'subjects': [
            {
              'subjectId': '38',
              'subjectName': '素描',
              'score': 92.5,
              'maxScore': 100,
            },
          ],
        },
        'scoreChange': 9,
        'rankingChange': 5,
        'surpassedPercent': 84,
        'interpretations': [
          {'type': 'STRENGTH', 'subjectId': '38', 'text': '素描表现最好'},
          {'type': 'IMPROVEMENT', 'text': ''},
        ],
      });
      expect(report.exam.isPublished, isTrue);
      expect(report.exam.examDate, '2026-09-20');
      expect(report.subjects.single.rate, 0.925);
      expect(report.rankingChange, 5);
      expect(report.interpretations.single.isStrength, isTrue);
    });

    test('route args are parsed defensively', () {
      final args = StudyCenterArgs.parse({
        'examId': 26,
        'view': 'Paper',
        'subjectId': null,
      });
      expect(args.examId, '26');
      expect(args.view, StudyCenterInitialView.paper);
      expect(args.subjectId, isEmpty);
      expect(StudyCenterArgs.parse('bad').examId, isEmpty);
      expect(
        StudyCenterArgs.parse({'view': 'growth'}).view,
        StudyCenterInitialView.trend,
      );
    });
  });
}
