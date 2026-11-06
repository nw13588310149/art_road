import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/features/design_system/design_system_page.dart';

void main() {
  testWidgets('design system gallery lays out at the shell content width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(980, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: DesignSystemPage()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('组件库'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(
      find.textContaining('加载、空与错误', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('还没有作品'), findsOneWidget);
  });
}
