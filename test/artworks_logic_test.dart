import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_data.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_marking_data.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_models.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_rules.dart';

Map<String, dynamic> _work({
  required List<String> teachers,
  required List<Map<String, dynamic>> reviews,
}) => <String, dynamic>{
  'id': 'aw-test',
  'personIndex': 1,
  'subject': '素描',
  'teacherIds': teachers,
  'reviews': reviews,
};

Map<String, dynamic> _review(String teacherId, double? score) =>
    <String, dynamic>{
      'teacherId': teacherId,
      'score': score,
      'maxScore': 100.0,
      'content': '',
      'reviewedTime': '2026-10-20 21:30:00',
      'tags': const <Map<String, dynamic>>[],
    };

void main() {
  group('DemoArtworkData.aggregate', () {
    test('stays pending until every assigned teacher has reviewed', () {
      final result = DemoArtworkData.aggregate(
        _work(teachers: ['t-1', 't-3'], reviews: [_review('t-3', 86)]),
      );
      expect(result.status, DemoArtworkData.statusPending);
      expect(result.finalScore, isNull);
      expect(result.reviewedCount, 1);
      expect(result.teacherCount, 2);
    });

    test('final score is the mean of scored reviews with two decimals', () {
      final result = DemoArtworkData.aggregate(
        _work(
          teachers: ['t-1', 't-2', 't-3'],
          reviews: [_review('t-1', 85), _review('t-2', 86), _review('t-3', 88)],
        ),
      );
      expect(result.status, DemoArtworkData.statusReviewed);
      expect(result.finalScore, 86.33);
    });

    test('reviews without a score do not count toward the mean', () {
      final result = DemoArtworkData.aggregate(
        _work(
          teachers: ['t-1', 't-2'],
          reviews: [_review('t-1', null), _review('t-2', 80)],
        ),
      );
      expect(result.status, DemoArtworkData.statusReviewed);
      expect(result.finalScore, 80);
    });
  });

  group('demo seed data', () {
    final works = DemoArtworkData.seedWorks();

    test('student 林小雨 has eight works, two of them pending', () {
      final mine = works.where((w) => w['personIndex'] == 1).toList();
      final pending = mine.where(
        (w) =>
            DemoArtworkData.aggregate(w).status ==
            DemoArtworkData.statusPending,
      );
      expect(mine, hasLength(8));
      expect(pending, hasLength(2));
    });

    test('teacher 李静 has seven works waiting for her review', () {
      final queue = works.where(
        (w) =>
            DemoArtworkData.teacherIdsOf(w).contains('t-1') &&
            DemoArtworkData.reviewOf(w, 't-1') == null,
      );
      expect(queue, hasLength(7));
    });

    test('insights rank 结构错误 first and skip praise tags in suggestions', () {
      final insights = DemoArtworkData.insightsOf(
        works.where((w) => w['personIndex'] == 1).toList(),
      );
      final topTags = insights['topTags'] as List;
      final suggestions = insights['suggestions'] as List;
      expect((topTags.first as Map)['name'], '结构错误');
      expect((topTags.first as Map)['count'], 3);
      expect((suggestions.first as Map)['gallerySubject'], '素描');
      expect((suggestions.first as Map)['galleryKeyword'], '结构');
      expect(suggestions.any((s) => (s as Map)['tag'] == '细节出彩'), isFalse);
      expect(insights['averageScore'], 84.67);
      final praise = topTags.cast<Map>().firstWhere((t) => t['name'] == '细节出彩');
      expect(praise['positive'], isTrue);
    });

    test('林小雨 daily works rank subjects the same way as her 9 月月考', () {
      final insights = DemoArtworkData.insightsOf(
        works.where((w) => w['personIndex'] == 1).toList(),
      );
      final exam = DemoMarkingData.instance.entryOf(1, '26')!;
      final bySubject = [...exam.subjects!]
        ..sort((a, b) => b.score.compareTo(a.score));
      expect(insights['bestSubject'], bySubject.first.def.subjectName);
      expect(insights['weakestSubject'], bySubject.last.def.subjectName);
    });

    test('submissions spread over the evening and reviews come later', () {
      final times = <String>{};
      for (final work in works) {
        final created = work['createTime'] as String;
        final clock = created.substring(11, 16);
        times.add(clock);
        expect(clock.compareTo('18:30') >= 0, isTrue, reason: created);
        expect(clock.compareTo('21:30') <= 0, isTrue, reason: created);
        for (final review in DemoArtworkData.reviewsOf(work)) {
          final reviewed = review['reviewedTime'] as String;
          expect(reviewed.compareTo(created) > 0, isTrue, reason: reviewed);
          final hour = int.parse(reviewed.substring(11, 13));
          expect(hour >= 8 && hour <= 21, isTrue, reason: reviewed);
        }
      }
      expect(times.length, greaterThan(8));
    });

    test('only 细节出彩 is a highlight tag', () {
      final tags = DemoArtworkData.seedTags('t-1');
      final highlights = tags
          .where((t) => ArtworkRules.isHighlightTag(t['color'] as String))
          .map((t) => t['name'])
          .toList();
      expect(highlights, ['细节出彩']);
    });
  });

  group('ArtworkRules', () {
    test('formats scores with at most two decimals', () {
      expect(ArtworkRules.formatScore(88), '88');
      expect(ArtworkRules.formatScore(87.5), '87.5');
      expect(ArtworkRules.formatScore(86.333), '86.33');
      expect(ArtworkRules.formatScore(100), '100');
      expect(ArtworkRules.formatScore(null), '—');
    });

    test('parses review scores against the full score', () {
      expect(ArtworkRules.parseScore('', '100').score, isNull);
      expect(ArtworkRules.parseScore('', '100').error, isNull);
      expect(ArtworkRules.parseScore('92.5', '100').score, 92.5);
      expect(ArtworkRules.parseScore('101', '100').error, isNotNull);
      expect(ArtworkRules.parseScore('88.123', '100').error, isNotNull);
      expect(ArtworkRules.parseScore('40', '0').error, isNotNull);
      final locked = ArtworkRules.parseScore(
        '120',
        '100',
        requiredFullScore: 150,
      );
      expect(locked.maxScore, 150);
      expect(locked.score, 120);
    });

    test('a review needs a score, a tag or a comment', () {
      expect(
        ArtworkRules.validateReview(score: null, tagCount: 0, comment: ' '),
        isNotNull,
      );
      expect(
        ArtworkRules.validateReview(score: null, tagCount: 1, comment: ''),
        isNull,
      );
      expect(
        ArtworkRules.validateReview(score: 80, tagCount: 9, comment: ''),
        isNotNull,
      );
    });

    test('validates the upload draft', () {
      final today = DateTime(2026, 11, 7);
      String? validate({int images = 1, String title = '静物', DateTime? date}) =>
          ArtworkRules.validateDraft(
            imageCount: images,
            title: title,
            subject: '素描',
            drawingDate: date ?? today,
            description: '',
            now: today,
          );
      expect(validate(), isNull);
      expect(validate(images: 0), isNotNull);
      expect(validate(images: 10), isNotNull);
      expect(validate(title: '  '), isNotNull);
      expect(validate(date: DateTime(2026, 11, 8)), isNotNull);
    });

    test('rejects duplicate tag names regardless of case', () {
      expect(
        ArtworkRules.validateTag(
          name: 'Line',
          explanation: '',
          color: '#4A74D6',
          otherNames: const ['line'],
        ),
        isNotNull,
      );
      expect(
        ArtworkRules.validateTag(name: '构图失衡', explanation: '', color: 'blue'),
        isNotNull,
      );
    });

    test('groups works by drawing month and labels the month', () {
      final groups = ArtworkRules.groupByMonth(const [
        '2026-11-03',
        '2026-11-01',
        '2026-10-25',
        '2026-08-30',
      ], (date) => date);
      expect(groups.map((g) => g.$1), ['2026-11', '2026-10', '2026-08']);
      expect(groups.first.$2, hasLength(2));
      expect(ArtworkRules.monthLabel('2026-10'), '2026 年 10 月');
      expect(ArtworkRules.dateText('2026-11-04 19:20:00'), '2026-11-04');
    });

    test('display scores keep at most one decimal', () {
      expect(ArtworkRules.displayScore(84.67), '84.7');
      expect(ArtworkRules.displayScore(86), '86');
      expect(ArtworkRules.displayScore(null), '—');
    });

    test('tags are either problems or highlights', () {
      expect(ArtworkRules.isHighlightTag('#3b9a6e'), isTrue);
      expect(ArtworkRules.isHighlightTag(ArtworkRules.problemTagColor), isFalse);
      expect(ArtworkRules.isHighlightTag('#4A74D6'), isFalse);
      expect(ArtworkRules.isHighlightTag('#4A74D6', positive: true), isTrue);
    });

    test('recognizes image signatures', () {
      expect(
        ArtworkRules.isSupportedImage(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        ),
        isTrue,
      );
      expect(
        ArtworkRules.isSupportedImage(
          Uint8List.fromList([0x00, 0x00, 0x00, 0x18]),
        ),
        isFalse,
      );
    });
  });

  group('models', () {
    test('annotation strokes survive a JSON round trip', () {
      final stroke = AnnotationStroke.fromJson(<String, dynamic>{
        'color': '#D64A62',
        'width': 4,
        'imageIndex': 1,
        'points': [
          [0.1, 0.2],
          [0.3, 0.4],
        ],
      });
      final copy = AnnotationStroke.fromJson(stroke.toJson());
      expect(copy.points, hasLength(2));
      expect(copy.points.last.dx, closeTo(0.3, 1e-9));
      expect(copy.imageIndex, 1);
      expect(copy.width, 4);
    });

    test('student detail hides reviews until the work is reviewed', () {
      final detail = ArtworkDetail.fromJson(<String, dynamic>{
        'work': <String, dynamic>{
          'id': 'aw-1',
          'title': '花卉色彩写生',
          'status': 'PENDING',
          'finalScore': null,
          'maxScore': 100,
        },
        'images': [
          <String, dynamic>{'id': 'i-1', 'url': 'https://example.com/a.jpg'},
        ],
        'reviews': [
          <String, dynamic>{
            'teacherId': 't-3',
            'teacherName': '刘芳',
            'reviewed': true,
            'score': null,
            'content': '',
            'tags': const <dynamic>[],
          },
        ],
      });
      expect(detail.work.reviewed, isFalse);
      expect(detail.teachers.single.reviewed, isTrue);
      expect(detail.reviews.single.visible, isFalse);
      expect(detail.images.single.url, 'https://example.com/a.jpg');
    });
  });
}
