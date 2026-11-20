import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';

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
  test(
    'only exact packaged tokens are demo; existing real tokens stay real',
    () async {
      SharedPreferences.setMockInitialValues({'token': 'real-existing'});
      final storage = AppStorage(await SharedPreferences.getInstance());
      expect(storage.isDemoSession, isFalse);
      expect(storage.sessionToken.value, 'real-existing');
      expect(DemoAccounts.lookupMobile('13900000000'), isNull);
      expect(DemoAccounts.isDemoToken('demo.student.13900000000'), isFalse);
      expect(
        DemoAccounts.isDemoToken('${DemoAccounts.student.token}.extra'),
        isFalse,
      );
      for (final account in DemoAccounts.all) {
        await storage.saveToken(account.token);
        expect(storage.isDemoSession, isTrue);
        expect(DemoAccounts.lookupMobile(account.mobile), account);
      }
      await storage.saveToken('youke');
      expect(storage.isDemoSession, isFalse);
      expect(storage.isGuestSession, isTrue);
    },
  );
  test(
    'switch and logout notify only after identity caches are cleared',
    () async {
      SharedPreferences.setMockInitialValues({
        'token': 'old',
        'schoolId': '9',
        'mobile': 'old-mobile',
        'avatar_url': 'old-avatar',
        'nickname': 'old-name',
        'fileBaseUrl': 'old-files',
        'checkStatus': true,
      });
      final storage = AppStorage(await SharedPreferences.getInstance());
      final seen = <String>[];
      storage.sessionToken.addListener(() {
        seen.add(storage.sessionToken.value);
        expect(storage.schoolId, '0');
        expect(storage.mobile, isEmpty);
        expect(storage.avatarUrl, isEmpty);
        expect(storage.nickname, isEmpty);
        expect(storage.fileBaseUrl, isEmpty);
        expect(storage.checkStatusData, isNull);
      });
      await storage.saveToken('new');
      await storage.saveAvatarUrl('new-avatar');
      await storage.clearToken();
      expect(seen, ['new', '']);
    },
  );
  test('stale unauthorized cleanup cannot delete a newer login', () async {
    SharedPreferences.setMockInitialValues({'token': 'old'});
    final storage = AppStorage(await SharedPreferences.getInstance());
    final clearing = storage.clearTokenIfCurrent('old', () => true);
    await storage.saveToken('new');
    await storage.saveAvatarUrl('new-avatar');
    expect(await clearing, isFalse);
    expect(storage.token, 'new');
    expect(storage.avatarUrl, 'new-avatar');
    expect(storage.sessionToken.value, 'new');
    expect(await storage.clearTokenIfCurrent('old', () => true), isFalse);
    expect(storage.token, 'new');
  });
}
