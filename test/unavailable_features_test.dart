import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/features/creative_hub/ui/marketplace_page.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/dorm_manager_check_in_view.dart';

class _NoRequests implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError(
    'Unavailable feature attempted a request: ${i.memberName}',
  );
}

void main() {
  testWidgets(
    'real account market remains unavailable without requests or transaction controls',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            demoSessionProvider.overrideWithValue(false),
            apiClientProvider.overrideWithValue(_NoRequests()),
          ],
          child: const MaterialApp(home: Scaffold(body: MarketplacePage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('作品集市暂未开通'), findsOneWidget);
      expect(find.text('购买'), findsNothing);
      expect(find.text('发布作品'), findsNothing);
    },
  );
  testWidgets(
    'real account punch has no mock records, location or success action',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            demoSessionProvider.overrideWithValue(false),
            apiClientProvider.overrideWithValue(_NoRequests()),
          ],
          child: MaterialApp(
            home: Scaffold(body: DormManagerCheckInView(onBack: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('当前不会记录打卡或定位'), findsOneWidget);
      expect(find.text('我的打卡记录'), findsNothing);
      expect(find.text('获取当前定位'), findsNothing);
      expect(find.text('正常'), findsNothing);
    },
  );
}
