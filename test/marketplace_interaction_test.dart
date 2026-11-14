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
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/creative_hub/ui/marketplace_page.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(registerDemoFixtures);
  for (final width in [950.0, 814.0]) {
    testWidgets(
      'checkout requires agreement and delivers only after payment at $width',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'token': DemoAccounts.student.token,
        });
        final prefs = await SharedPreferences.getInstance();
        await DemoStore.init();
        await DemoStore.reset();
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appStorageProvider.overrideWithValue(AppStorage(prefs)),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: MarketplacePage()),
            ),
          ),
        );
        await settle(tester);
        Future<void> tap(String label, {bool contains = false}) async {
          final target = contains
              ? find.textContaining(label).last
              : find.text(label).last;
          await Scrollable.ensureVisible(
            tester.element(target),
            alignment: 0.5,
          );
          await tester.pump();
          await tester.tap(target);
          await settle(tester);
        }

        await tap('午后的静物');
        await tap('购买使用许可');
        await tap('创建订单 ·', contains: true);
        expect(find.text('请阅读并确认交易说明'), findsOneWidget);
        expect(DemoStore.list('creative:orders:v1', () => []), isEmpty);
        await tap('我已阅读并同意以上交易说明');
        await tap('创建订单 ·', contains: true);
        expect(find.text('待付款'), findsOneWidget);
        expect(find.text('查看交付文件'), findsNothing);
        await tap('模拟支付 ¥', contains: true);
        await tap('确认模拟支付');
        expect(find.text('已完成'), findsOneWidget);
        await tap('查看交付文件');
        expect(find.text('保存许可凭证'), findsOneWidget);
        expect(find.text('保存文件 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
      },
    );
  }
  testWidgets(
    'physical checkout validates and preserves address form on server error',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'token': DemoAccounts.student.token,
      });
      final prefs = await SharedPreferences.getInstance();
      await DemoStore.init();
      await DemoStore.reset();
      tester.view.physicalSize = const Size(950, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: MarketplacePage()),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('石膏像的光'));
      await settle(tester);
      await Scrollable.ensureVisible(
        tester.element(find.text('购买实物作品')),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(find.text('购买实物作品'));
      await settle(tester);
      await tester.ensureVisible(find.text('我已阅读并同意以上交易说明'));
      await tester.tap(find.text('我已阅读并同意以上交易说明'));
      await settle(tester);
      await tester.tap(find.textContaining('创建订单 ·'));
      await settle(tester);
      expect(find.text('请先添加并选择收货地址'), findsOneWidget);
      await tester.ensureVisible(find.text('新增收货地址'));
      await tester.tap(find.text('新增收货地址'));
      await settle(tester);
      final inputs = find.byType(AppInputField);
      await tester.enterText(
        find.descendant(of: inputs.at(0), matching: find.byType(EditableText)),
        '林小雨',
      );
      await tester.enterText(
        find.descendant(of: inputs.at(1), matching: find.byType(EditableText)),
        '123',
      );
      await tester.enterText(
        find.descendant(of: inputs.at(2), matching: find.byType(EditableText)),
        '示范画室城东校区一号楼前台',
      );
      await tester.tap(find.text('保存地址'));
      await settle(tester);
      expect(find.text('请填写 11 位手机号码'), findsOneWidget);
      expect(find.text('示范画室城东校区一号楼前台'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
    },
  );
}
