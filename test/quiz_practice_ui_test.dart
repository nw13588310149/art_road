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

  testWidgets('quiz practice ring cards share one baseline at 1024 width', (
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
            body: QuizPracticeView(
              schoolId: kPublicQuizSchoolId,
              subtitle: '',
            ),
          ),
        ),
      ),
    );
    for (var tick = 0; tick < 10; tick++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.text('练习方式'), findsOneWidget);
    final labels = [
      find.text('顺序练习'),
      find.text('随机练习'),
      find.text('高频考点'),
      find.text('错题本'),
    ];
    for (final finder in labels) {
      expect(finder, findsOneWidget);
    }
    final baseline = tester.getTopLeft(labels.first).dy;
    for (var index = 1; index < labels.length; index++) {
      expect(tester.getTopLeft(labels[index]).dy, baseline);
    }
    expect(tester.takeException(), isNull);
  });
}
