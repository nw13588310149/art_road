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
  // 校长「全校学情」的内容区：1180 × 820 与 1024 × 768 两种横屏。
  for (final size in [const Size(970, 748), const Size(814, 696)]) {
    testWidgets(
      'principal study overview fits $size with reports and management in view',
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
        expect(tester.takeException(), isNull);
        expect(find.text('校长驾驶舱'), findsNothing);
        expect(find.text('今日新交作品'), findsOneWidget);
        expect(find.text('教学趋势'), findsOneWidget);
        expect(find.text('近期作品'), findsOneWidget);

        // 报表入口：每行一份报表。
        expect(find.text('教学报表'), findsOneWidget);
        for (final report in [
          '班级学情',
          '老师履职',
          '作品点评链',
          '需要关注的学生',
          '学生到校',
          '老师在岗',
        ]) {
          expect(find.text(report), findsOneWidget, reason: report);
        }

        // 当天要处理的事在「今日工作」里，这里不再重复。
        for (final moved in ['今日待办', '校长信箱', '教学跟进', '更多管理', '集市']) {
          expect(find.text(moved), findsNothing, reason: moved);
        }

        // 两行卡片正好一屏，最下面的管理入口不用滚动。
        expect(find.text('常用管理'), findsOneWidget);
        expect(
          tester.getBottomRight(find.text('教师管理')).dy,
          lessThan(size.height),
        );
        expect(find.byTooltip('刷新教学数据'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
