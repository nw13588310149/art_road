import '../demo_backend.dart';
import 'campus/campus_a_registry.dart';
import 'campus/campus_b_registry.dart';
import 'campus/teaching_overview_fixtures.dart';
import 'content_registry.dart';
import 'creative_hub_fixtures.dart';
import 'interaction_registry.dart';
import 'marking_artwork_fixtures.dart';
import 'marking_gallery_fixtures.dart';
import 'marking_study_fixtures.dart';
import 'platform_core_fixtures.dart';

/// 登记全部演示接口；在 main() 中、runApp 之前调用一次。
void registerDemoFixtures() {
  if (DemoBackend.isRegistered) {
    return;
  }
  final platform = DemoBackend.platform;
  final marking = DemoBackend.marking;

  registerPlatformCoreFixtures(platform);
  registerContentFixtures(platform);
  registerCreativeHubFixtures(platform);
  registerInteractionFixtures(platform);
  registerCampusFixturesPartA(platform);
  registerCampusFixturesPartB(platform);

  registerMarkingStudyFixtures(marking);
  registerMarkingArtworkFixtures(marking);
  registerMarkingGalleryFixtures(marking);
  registerTeachingOverviewFixtures(marking);

  DemoBackend.markRegistered();
}
