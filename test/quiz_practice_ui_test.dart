import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/features/quiz_practice/state/quiz_practice_state.dart';
import 'package:the_road_of_art_flutter/features/quiz_practice/ui/quiz_practice_view.dart';

void main() {
  setUpAll(registerDemoFixtures);

  testWidgets('quiz practice mode counts align at the 1024 content width', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'token': DemoAccounts.student.token,
    });
    final prefs = await SharedPreferences.getInstance();
    await DemoStore.init();
    await DemoStore.reset();
    tester.view.physicalSize = const Size(814, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
        child: const MaterialApp(
          home: Scaffold(
            body: QuizPracticeView(schoolId: kPublicQuizSchoolId, subtitle: ''),
          ),
        ),
      ),
    );
    for (var tick = 0; tick < 10; tick++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final counts = find.textContaining(RegExp(r'^已(?:做|复习) \d+ / \d+$'));
    expect(counts, findsNWidgets(4));
    final baseline = tester.getTopLeft(counts.first).dy;
    for (var index = 1; index < 4; index++) {
      expect(tester.getTopLeft(counts.at(index)).dy, baseline);
    }
    expect(tester.takeException(), isNull);
  });
}
