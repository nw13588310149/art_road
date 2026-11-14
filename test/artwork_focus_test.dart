import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_data.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_models.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/widgets/artwork_focus_panel.dart';

Map<String, dynamic> review(int level, String time, {bool? resolved}) => {
  'teacherId': 'teacher-$level',
  'score': 80,
  'maxScore': 100,
  'reviewedTime': time,
  'content': '观察并调整体积的明暗关系',
  'dimensions': {
    'composition': level,
    'shape': level,
    'value': level,
    'detail': level,
  },
  'tags': [
    {'name': '明暗层次弱', 'color': '#FAAD14', 'explanation': '暗部整体关系还需要拉开'},
  ],
  'tagResolutions': [
    if (resolved != null) {'tag': '明暗层次弱', 'resolved': resolved},
  ],
};

Map<String, dynamic> work(
  String id,
  String subject,
  List<Map<String, dynamic>> reviews,
) => {
  'id': id,
  'title': '静物练习 $id',
  'subject': subject,
  'createTime': '2026-11-14 10:00:00',
  'review': reviews.first,
  'teacherReviews': reviews.skip(1).toList(),
};

ArtworkInsights fixture() => ArtworkInsights.fromJson(
  DemoArtworkData.insightsOf([
    work('a', '素描', [
      review(1, '2026-11-12 10:00:00'),
      review(5, '2026-11-12 11:00:00', resolved: true),
    ]),
    work('b', '素描', [review(1, '2026-11-14 10:00:00')]),
    work('c', '色彩', [review(4, '2026-11-13 10:00:00', resolved: true)]),
  ], DateTime(2026, 11, 15, 10)),
);

void main() {
  test(
    'multiple teacher dimensions are averaged per work; issue evidence stays in its subject',
    () {
      final insights = fixture();
      final sketch = insights.dimensions.firstWhere((d) => d.subject == '素描');
      expect(sketch.sampleCount, 2);
      expect(sketch.reviewCount, 3);
      expect(sketch.items.firstWhere((d) => d.key == 'composition').level, 2);
      expect(sketch.issues.single.count, 2);
      expect(sketch.issues.single.evidence.length, 3);
      expect(sketch.issues.single.latestResolved, false);
      expect(sketch.issues.single.resolvedCount, 1);
      expect(
        sketch.issues.single.evidence.map((e) => e.artworkId),
        isNot(contains('c')),
      );
      expect(sketch.sourceWorks.map((w) => w.id), ['a', 'b']);
      expect(
        insights.dimensions
            .firstWhere((d) => d.subject == '色彩')
            .issues
            .single
            .latestResolved,
        true,
      );
    },
  );
  test('ten-work limit and response remains JSON serializable', () {
    final data = DemoArtworkData.insightsOf([
      for (var i = 1; i <= 12; i++)
        work('$i', '素描', [
          review(3, '2026-11-${i.toString().padLeft(2, '0')} 10:00:00'),
        ]),
    ], DateTime(2026, 11, 15, 10));
    final parsed = ArtworkInsights.fromJson(jsonDecode(jsonEncode(data)));
    expect(parsed.dimensions.single.sampleCount, 10);
    expect(parsed.dimensions.single.sourceWorks.first.id, '3');
  });
  for (final width in [950.0, 814.0, 560.0]) {
    testWidgets('focus panel explains and opens evidence at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final levels = fixture().dimensions.firstWhere((d) => d.subject == '素描');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ArtworkFocusPanel(levels: levels),
            ),
          ),
        ),
      );
      expect(find.text('近期关注'), findsOneWidget);
      expect(find.text('继续练习'), findsOneWidget);
      await tester.ensureVisible(find.text('查看依据'));
      await tester.tap(find.text('查看依据'));
      await tester.pumpAndSettle();
      expect(find.text('静物练习 b'), findsOneWidget);
      expect(find.text('查看原作品'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
