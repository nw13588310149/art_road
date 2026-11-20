import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/features/creative_hub/data/creative_repository.dart';
import 'package:the_road_of_art_flutter/features/creative_hub/state/creative_controllers.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/creative_hub/ui/learning_topics_page.dart';
import 'package:the_road_of_art_flutter/features/creative_hub/ui/marketplace_page.dart';

class _MarketSamplesApi extends Fake implements ApiClient {
  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    expect(path, '/app/market/samples');
    return const ApiResponse(
      code: 0,
      msg: 'ok',
      data: [
        {'id': 'sample-44', 'title': '平台素材', 'kind': 'images'},
      ],
    );
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUpAll(registerDemoFixtures);
  test('集市示例素材使用独立只读接口', () async {
    final container = ProviderContainer(
      overrides: [
        creativeRepositoryProvider.overrideWithValue(
          CreativeRepository(_MarketSamplesApi()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(marketSamplesProvider, (_, _) {});
    addTearDown(subscription.close);
    final items = await container.read(marketSamplesProvider.future);
    expect(items.single.id, 'sample-44');
    expect(items.single.title, '平台素材');
  });
  for (final width in [950.0, 814.0]) {
    testWidgets('topic and market forms fit $width with visible validation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'token': DemoAccounts.student.token,
      });
      final prefs = await SharedPreferences.getInstance();
      await DemoStore.init();
      await DemoStore.reset();
      tester.view.physicalSize = Size(width, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> mount(Widget page) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appStorageProvider.overrideWithValue(AppStorage(prefs)),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(body: page),
            ),
          ),
        );
        await settle(tester);
      }

      await mount(const LearningTopicsPage());
      expect(find.text('把明暗交界线画进体积里'), findsOneWidget);
      await tester.tap(find.text('新增课件'));
      await settle(tester);
      expect(find.text('课件内容'), findsOneWidget);
      expect(find.text('阅读资料'), findsOneWidget);
      await tester.tap(find.text('发布课件'));
      await settle(tester);
      expect(find.textContaining('课件名称须为'), findsOneWidget);
      final fields = find.byType(AppInputField);
      expect(tester.getSize(fields.first).width, greaterThan(220));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
      await mount(const MarketplacePage());
      expect(find.text('午后的静物'), findsOneWidget);
      await tester.tap(find.text('发布作品'));
      await settle(tester);
      expect(find.text('创作信息'), findsOneWidget);
      await tester.tap(find.text('提交审核').last);
      await settle(tester);
      expect(find.text('请先选择作品图片'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
    });
  }
}
