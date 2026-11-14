import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/features/teaching_overview/ui/principal_overview.dart';

void main() {
  for (final size in [const Size(970, 748), const Size(814, 696)]) {
    testWidgets(
      'approved principal layout fits $size and keeps management reachable',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'token': DemoAccounts.principal.token,
        });
        final prefs = await SharedPreferences.getInstance();
        await DemoStore.init();
        await DemoStore.reset();
        registerDemoFixtures();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appStorageProvider.overrideWithValue(AppStorage(prefs)),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: PrincipalOverview(name: '陈建华')),
            ),
          ),
        );
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(find.text('校长驾驶舱'), findsNothing);
        expect(find.text('近期作品'), findsOneWidget);
        expect(
          tester.getBottomRight(find.text('更多管理')).dy,
          lessThan(size.height),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('更多管理'));
        await tester.pumpAndSettle();
        expect(find.text('教师请假审批'), findsOneWidget);
        expect(find.text('刷新教学数据'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
