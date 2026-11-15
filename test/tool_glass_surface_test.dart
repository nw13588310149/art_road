import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/widgets/tool_glass_surface.dart';

void main() {
  testWidgets(
    'high contrast disables backdrop blur and keeps foreground interactive',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: Center(
              child: SizedBox(
                width: 52,
                height: 80,
                child: ToolGlassSurface(
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('工具'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isFalse,
      );
      await tester.tap(find.text('工具'));
      expect(taps, 1);
    },
  );

  testWidgets(
    'iOS material bridge forwards press and cancel without stealing tool input',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const platform = MethodChannel('flutter/platform_views');
      final configurations = <Map<Object?, Object?>>[];
      MethodChannel? material;
      messenger.setMockMethodCallHandler(platform, (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['id'];
          material = MethodChannel('com.meiyuji.art/tool_glass/$id');
          messenger.setMockMethodCallHandler(material!, (call) async {
            configurations.add(call.arguments as Map<Object?, Object?>);
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(platform, null);
        if (material != null) {
          messenger.setMockMethodCallHandler(material!, null);
        }
      });
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: SizedBox(
                width: 52,
                height: 80,
                child: ToolGlassSurface(
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('工具'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tool-glass-fallback')), findsNothing);
      expect(configurations.last['reduceMotion'], isTrue);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('工具')),
      );
      await tester.pump();
      expect(configurations.last['engaged'], isTrue);
      await gesture.cancel();
      await tester.pump();
      expect(configurations.last['engaged'], isFalse);
      expect(taps, 0);
      await tester.tap(find.text('工具'));
      await tester.pump();
      expect(taps, 1);
      expect(configurations.last['engaged'], isFalse);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
