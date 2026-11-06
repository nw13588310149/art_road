import '../demo_backend.dart';
import 'platform_core_fixtures.dart';

/// 登记全部演示接口；在 main() 中、runApp 之前调用一次。
void registerDemoFixtures() {
  if (DemoBackend.isRegistered) {
    return;
  }
  registerPlatformCoreFixtures(DemoBackend.platform);
  DemoBackend.markRegistered();
}
