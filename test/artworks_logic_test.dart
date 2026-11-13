import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_data.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_seed.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_marking_data.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_models.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_rules.dart';

void main() {
  final now = DateTime(2026, 11, 13, 21, 30);

  setUp(() {
    DemoArtworkStore.setNow(now);
  });

  tearDown(DemoArtworkStore.clearCache);

  group('DemoArtworkData.leadReasons', () {
    test('collects every matched reason', () {
      final reasons = DemoArtworkData.leadReasons(
        id: 'aw-spot-0',
        requested: true,
        score: 50,
        maxScore: 100,
        recentFinals: const [0.8, 0.82, 0.79],
        content: '短评',
        hasAnnotations: false,
        spotCheckPercent: 100,
      );
      expect(
        reasons,
        containsAll(<String>[
          DemoArtworkData.reasonRequested,
          DemoArtworkData.reasonScoreAnomaly,
          DemoArtworkData.reasonBrief,
          DemoArtworkData.reasonSpotCheck,
        ]),
      );
    });

    test('skips score anomaly when history is shorter than 2', () {
      final reasons = DemoArtworkData.leadReasons(
        id: 'aw-ok',
        requested: false,
        score: 40,
        maxScore: 100,
        recentFinals: const [0.9],
        content: '这是一条足够长的评语，用来避免被判定为点评过简。',
        hasAnnotations: false,
        spotCheckPercent: 0,
      );
      expect(reasons, isEmpty);
    });

    test('brief needs both short content and no annotations', () {
      final withAnno = DemoArtworkData.leadReasons(
        id: 'aw-ok',
        requested: false,
        score: 80,
        maxScore: 100,
        recentFinals: const [],
        content: '短',
        hasAnnotations: true,
        spotCheckPercent: 0,
      );
      expect(withAnno, isEmpty);
    });
  });

  group('status and final score', () {
    test('pending until responsible teacher reviews', () {
      final work = <String, dynamic>{
        'id': 'aw-1',
        'teacherId': 't-1',
        'review': null,
      };
      expect(DemoArtworkData.statusOf(work), DemoArtworkData.statusPending);
      expect(DemoArtworkData.finalScoreOf(work), isNull);
    });

    test('lead adjust replaces final score', () {
      final work = <String, dynamic>{
        'id': 'aw-1',
        'teacherId': 't-1',
        'review': <String, dynamic>{
          'teacherId': 't-1',
          'score': 80,
          'maxScore': 100,
        },
        'leadReview': <String, dynamic>{
          'action': DemoArtworkData.actionAdjust,
          'score': 88,
        },
      };
      expect(DemoArtworkData.statusOf(work), DemoArtworkData.statusReviewed);
      expect(DemoArtworkData.leadStatusOf(work), DemoArtworkData.leadDone);
      expect(DemoArtworkData.finalScoreOf(work), 88);
    });
  });

  group('visibility', () {
    test('student cannot see lead reasons or quality', () {
      final work = <String, dynamic>{
        'id': DemoArtworkSeed.storyInReviewId,
        'personIndex': 1,
        'teacherId': 't-1',
        'subject': '素描',
        'review': <String, dynamic>{'teacherId': 't-1', 'score': 88},
        'leadReview': <String, dynamic>{
          'reasons': <String>[DemoArtworkData.reasonRequested],
          'action': null,
          'leaderId': 't-2',
          'qualityStars': 4,
        },
      };
      final access = DemoArtworkData.accessOf(DemoAccounts.student, work);
      expect(access.seesReview, isTrue);
      expect(access.seesLeadReasons, isFalse);
      expect(access.seesQuality, isFalse);
      expect(access.seesLeadResult, isTrue);
    });

    test('leader and principal see reasons and quality', () {
      final work = <String, dynamic>{
        'id': 'aw-x',
        'personIndex': 2,
        'teacherId': 't-1',
        'subject': '素描',
        'review': <String, dynamic>{'teacherId': 't-1'},
        'leadReview': <String, dynamic>{'leaderId': 't-2', 'action': null},
      };
      final leader = DemoArtworkData.accessOf(DemoAccounts.groupLeader, work);
      final principal = DemoArtworkData.accessOf(DemoAccounts.principal, work);
      expect(leader.seesLeadReasons, isTrue);
      expect(leader.seesQuality, isTrue);
      expect(principal.seesLeadReasons, isTrue);
      expect(principal.canFeature, isTrue);
      expect(principal.canReview, isFalse);
    });
  });

  group('seed data (injectable now)', () {
    late DemoArtworkSeedResult seed;

    setUp(() {
      seed = DemoArtworkSeed.build(now);
    });

    test('tasks are about 70 across 8 weeks and never on Sunday', () {
      expect(seed.tasks.length, inInclusiveRange(60, 80));
      for (final task in seed.tasks) {
        final created = DemoArtworkData.parseTime(task['createTime'])!;
        expect(created.weekday, isNot(DateTime.sunday));
      }
    });

    test('no submissions after now or on Sunday', () {
      for (final work in seed.works) {
        final created = DemoArtworkData.parseTime(work['createTime'])!;
        expect(created.isAfter(now), isFalse);
        expect(created.weekday, isNot(DateTime.sunday));
      }
    });

    test('林小雨 story line is complete', () {
      final mine = seed.works.where((w) => w['personIndex'] == 1).toList();
      final pending = mine.where((w) => !DemoArtworkData.isReviewed(w)).toList();
      expect(pending, hasLength(2));
      expect(
        pending.any((w) => DemoArtworkData.text(w['id']) == DemoArtworkSeed.storyPendingId),
        isTrue,
      );
      final today = DemoArtworkData.ymd(now);
      expect(
        pending.any(
          (w) => DemoArtworkData.text(w['createTime']).startsWith(today),
        ),
        isTrue,
      );

      final gypsum = seed.works
          .where((w) => w['id'] == DemoArtworkSeed.storyInReviewId)
          .single;
      expect(DemoArtworkData.leadStatusOf(gypsum), DemoArtworkData.leadInReview);
      expect(
        DemoArtworkData.text(DemoArtworkData.reviewOf(gypsum)?['content']),
        startsWith('结构交代清楚，暗部再整体一些'),
      );

      final chain = seed.works
          .where((w) => w['id'] == DemoArtworkSeed.storyChainId)
          .single;
      expect(DemoArtworkData.leadStatusOf(chain), DemoArtworkData.leadDone);
      expect(chain['featured'], isTrue);
      expect(DemoArtworkData.principalCommentsOf(chain), isNotEmpty);

      final v2 = seed.works
          .where((w) => w['id'] == DemoArtworkSeed.storyRevisionV2Id)
          .single;
      expect(DemoArtworkData.versionOf(v2), 2);
      expect(DemoArtworkData.text(v2['parentId']), DemoArtworkSeed.storyRevisionV1Id);
    });

    test('teacher queues and differences match the brief', () {
      const settings = DemoReviewSettings();
      Map<String, List<Map<String, dynamic>>> byTeacher() {
        final map = <String, List<Map<String, dynamic>>>{};
        for (final work in seed.works) {
          final id = DemoArtworkData.text(work['teacherId']);
          map.putIfAbsent(id, () => <Map<String, dynamic>>[]).add(work);
        }
        return map;
      }

      final grouped = byTeacher();
      final lijing = grouped['t-1']!;
      final pendingLijing = lijing.where((w) => !DemoArtworkData.isReviewed(w));
      expect(pendingLijing.length, inInclusiveRange(8, 12));
      expect(
        pendingLijing
            .where((w) => DemoArtworkData.isOverdue(w, now, settings))
            .length,
        2,
      );

      final zhaoxue = grouped['t-4']!;
      expect(
        zhaoxue.where((w) => !DemoArtworkData.isReviewed(w)).length,
        inInclusiveRange(3, 5),
      );

      final wang = grouped['t-5']!;
      final wangPending = wang.where((w) => !DemoArtworkData.isReviewed(w));
      expect(wangPending.length, inInclusiveRange(5, 8));
      expect(
        wangPending.every((w) => DemoArtworkData.isOverdue(w, now, settings)),
        isTrue,
      );

      final leadQueue = seed.works.where(
        (w) =>
            DemoArtworkData.leadStatusOf(w) == DemoArtworkData.leadInReview &&
            DemoArtworkData.text(DemoArtworkData.leadOf(w)?['leaderId']) ==
                't-2',
      );
      expect(leadQueue.length, inInclusiveRange(6, 10));
      expect(
        leadQueue
            .where((w) => DemoArtworkData.isLeadOverdue(w, now, settings))
            .length,
        inInclusiveRange(1, 2),
      );
    });

    test('featured and principal comments cover three subjects', () {
      final featured = seed.works.where((w) => w['featured'] == true).toList();
      expect(featured, hasLength(12));
      expect(
        featured.map((w) => DemoArtworkData.text(w['subject'])).toSet(),
        containsAll(DemoArtworkData.subjects),
      );
      final comments = seed.works.expand(DemoArtworkData.principalCommentsOf);
      expect(comments.length, 15);
    });

    test('reviewTeachers are the six roster teachers', () {
      expect(DemoMarkingData.reviewTeachers, hasLength(6));
      expect(
        DemoMarkingData.reviewTeachers.where((t) => t.leader).map((t) => t.id),
        containsAll(<String>['t-2', 't-3', 't-6']),
      );
    });
  });

  group('ArtworkRules', () {
    test('validateLeadReview requires stars and adjust reason', () {
      expect(
        ArtworkRules.validateLeadReview(action: 'KEEP', qualityStars: 0),
        isNotNull,
      );
      expect(
        ArtworkRules.validateLeadReview(
          action: 'ADJUST',
          qualityStars: 4,
          reason: '太短',
          score: 90,
        ),
        isNotNull,
      );
      expect(
        ArtworkRules.validateLeadReview(
          action: 'ADJUST',
          qualityStars: 4,
          reason: '对照联考评分标准，造型完成度已到九十分档。',
          score: 90,
        ),
        isNull,
      );
    });

    test('draft validation still rejects empty images', () {
      expect(
        ArtworkRules.validateDraft(
          imageCount: 0,
          title: '石膏',
          subject: '素描',
          drawingDate: DateTime(2026, 11, 1),
          description: '',
          now: now,
        ),
        '请至少选择 1 张作品照片',
      );
    });

    test('image header check accepts jpeg', () {
      final bytes = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0x00]);
      expect(ArtworkRules.isSupportedImage(bytes), isTrue);
    });
  });

  group('client models', () {
    test('ArtworkDetail reads timeline and lead status', () {
      final detail = ArtworkDetail.fromJson(<String, dynamic>{
        'work': <String, dynamic>{
          'id': 'aw-1',
          'title': '素描练习',
          'status': 'REVIEWED',
          'leadStatus': 'IN_REVIEW',
          'version': 1,
          'versionCount': 1,
        },
        'images': const <Map<String, dynamic>>[],
        'review': <String, dynamic>{
          'teacherId': 't-1',
          'teacherName': '李静',
          'reviewed': true,
          'content': '结构交代清楚，暗部再整体一些。',
          'score': 88,
        },
        'timeline': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'STUDENT',
            'type': 'SUBMIT',
            'name': '林小雨',
            'time': '2026-11-10 12:00:00',
          },
        ],
        'dimensions': <Map<String, dynamic>>[
          <String, dynamic>{'key': 'form', 'name': '造型'},
        ],
      });
      expect(detail.work.leadStatus, ArtworkLeadStatus.inReview);
      expect(detail.review?.score, 88);
      expect(detail.timeline, hasLength(1));
      expect(detail.dimensions.first.name, '造型');
    });
  });
}
