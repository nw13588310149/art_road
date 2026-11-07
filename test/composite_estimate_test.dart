import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/app/router/route_paths.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/score_calculator.dart';
import 'package:the_road_of_art_flutter/features/study_center/data/composite_estimate.dart';
import 'package:the_road_of_art_flutter/features/study_center/data/study_models.dart';
import 'package:the_road_of_art_flutter/features/study_center/ui/widgets/study_composite_estimate_card.dart';

/// 林小雨 9 月月考：素描 92.5 + 色彩 85 + 速写 88 = 265.5 / 300。
const _exam = StudyExamRecord(
  examId: '26',
  examName: '2026 年 9 月月考',
  examTime: '2026-09-20 08:30:00',
  status: StudyExamStatus.published,
  totalScore: 265.5,
  maxScore: 300,
);

void main() {
  group('estimateComposite', () {
    test('uses the Gansu formula from the score calculator', () {
      final estimate = estimateComposite(
        province: ScoreProvince.gansu,
        professionalScore: 265.5,
        professionalFull: 300,
        culture: '500',
      );
      // 500 × 50% + 265.5 ÷ 300 × 750 × 50% = 250 + 331.875 = 581.875 → 581.88
      expect(estimate.result!.text, '581.88');
      expect(estimate.professional, 265.5);
      expect(estimate.rule.formula, contains('÷ 300 × 750 × 50%'));
      expect(estimate.result!.steps.last.expression, contains('581.875'));
      expect(estimate.gap, isNull);
      expect(estimate.cultureError, isNull);
    });

    test('gap to the target is positive when short and negative when reached', () {
      CompositeEstimate withTarget(String target) => estimateComposite(
        province: ScoreProvince.gansu,
        professionalScore: 265.5,
        professionalFull: 300,
        culture: '500',
        target: target,
      );
      expect(withTarget('600').gap, 18.12);
      expect(withTarget('560').gap, -21.88);
      expect(withTarget('581.88').gap, 0);
      expect(withTarget('800').targetError, isNotNull);
      expect(withTarget('560.123').targetError, isNotNull);
      expect(withTarget('').target, isNull);
    });

    test('province presets change the rounding and weights', () {
      final beijing = estimateComposite(
        province: ScoreProvince.beijing,
        professionalScore: 265.5,
        culture: '500',
      );
      expect(beijing.result!.text, '582');
      final heilongjiang = estimateComposite(
        province: ScoreProvince.heilongjiang,
        professionalScore: 265.5,
        culture: '500',
      );
      // 265.5 ÷ 300 × 750 × 40% + 500 × 60% = 265.5 + 300
      expect(heilongjiang.result!.text, '565.50');
    });

    test('a non-300 exam is scaled to 300 before the formula', () {
      expect(professionalOn300(132.75, 150), 265.5);
      expect(professionalOn300(265.5, null), 265.5);
      expect(professionalOn300(null, 300), isNull);
      final estimate = estimateComposite(
        province: ScoreProvince.gansu,
        professionalScore: 132.75,
        professionalFull: 150,
        culture: '500',
      );
      expect(estimate.result!.text, '581.88');
    });

    test('empty or invalid culture scores give no result', () {
      final empty = estimateComposite(
        province: ScoreProvince.gansu,
        professionalScore: 265.5,
        culture: '',
      );
      expect(empty.result, isNull);
      expect(empty.cultureError, isNull);
      final invalid = estimateComposite(
        province: ScoreProvince.gansu,
        professionalScore: 265.5,
        culture: '751',
      );
      expect(invalid.result, isNull);
      expect(invalid.cultureError, isNotNull);
      final noExam = estimateComposite(
        province: ScoreProvince.gansu,
        professionalScore: null,
        culture: '500',
      );
      expect(noExam.result, isNull);
    });
  });

  group('CompositeEstimateStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('keeps each account’s input separately', () async {
      const mine = CompositeEstimateStore(account: '13809310001');
      await mine.save(
        const CompositeEstimateForm(
          province: ScoreProvince.anhui,
          culture: '512.5',
          target: '580',
        ),
      );
      final loaded = await const CompositeEstimateStore(
        account: '13809310001',
      ).load();
      expect(loaded.province, ScoreProvince.anhui);
      expect(loaded.culture, '512.5');
      expect(loaded.target, '580');

      final other = await const CompositeEstimateStore(account: '13900000000').load();
      expect(other.province, ScoreProvince.gansu);
      expect(other.culture, isEmpty);
    });
  });

  group('StudyCompositeEstimateCard', () {
    Future<List<RouteSettings>> pumpCard(
      WidgetTester tester, {
      StudyExamRecord? exam = _exam,
      Map<String, Object> prefs = const <String, Object>{},
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final storage = AppStorage(await SharedPreferences.getInstance());
      tester.view.physicalSize = const Size(950, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pushed = <RouteSettings>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appStorageProvider.overrideWithValue(storage)],
          child: MaterialApp(
            onGenerateRoute: (settings) {
              if (settings.name != '/') {
                pushed.add(settings);
              }
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => Scaffold(
                  backgroundColor: AppColors.page,
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: StudyCompositeEstimateCard(exam: exam),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return pushed;
    }

    testWidgets('estimates from the latest exam, shows the gap and the disclaimer', (
      tester,
    ) async {
      final pushed = await pumpCard(tester);
      expect(find.text('综合分预估'), findsWidgets);
      expect(find.text(StudyCompositeEstimateCard.disclaimer), findsOneWidget);
      expect(find.textContaining('265.5'), findsOneWidget);
      expect(find.text('填写文化课预估分后显示'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).at(0), '500');
      await tester.pump();
      expect(find.textContaining('581.88'), findsWidgets);

      await tester.enterText(find.byType(EditableText).at(1), '600');
      await tester.pump();
      expect(find.textContaining('距目标还差'), findsOneWidget);
      expect(find.textContaining('18.12'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('完整计算器'));
      await tester.pumpAndSettle();
      expect(pushed.single.name, RoutePaths.artToolbox);
      expect(pushed.single.arguments, {'tool': 'score'});
    });

    testWidgets('restores the saved culture score', (tester) async {
      await pumpCard(
        tester,
        prefs: <String, Object>{
          'study_composite_estimate_v1':
              '{"province":"gansu","culture":"520","target":""}',
        },
      );
      expect(find.text('520'), findsOneWidget);
      expect(find.textContaining('591.88'), findsWidgets);
    });

    testWidgets('without a published exam it only explains and links the calculator', (
      tester,
    ) async {
      await pumpCard(tester, exam: null);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text(StudyCompositeEstimateCard.disclaimer), findsOneWidget);
      expect(find.text('完整计算器'), findsOneWidget);
    });
  });
}
