import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_music_flutter/core/storage/app_storage.dart';

void main() {
  test('preserves App schoolId header as an exact string', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = AppStorage(await SharedPreferences.getInstance());

    await storage.saveSchoolId('2065123456789012345');

    expect(storage.schoolId, '2065123456789012345');
  });

  test('uses zero when schoolId is absent', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = AppStorage(await SharedPreferences.getInstance());

    await storage.saveSchoolId(null);

    expect(storage.schoolId, '0');
  });
}
