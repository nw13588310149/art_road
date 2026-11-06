import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  AppStorage(this._prefs);

  static const _tokenKey = 'token';
  static const _pushIdKey = 'pushId';
  static const _checkStatusKey = 'checkStatus';
  static const _schoolIdKey = 'schoolId';
  // 登录成功后保存的当前账号（手机号）。供 ShellController 在 refreshUserAndSchool
  // 时判定演示用「白名单管理员」(例如 13588310149) 是否需要覆盖 user.role
  // 为 admin。logout 时会清空。
  static const _mobileKey = 'mobile';

  /// 登录后本地缓存的头像 URL 与昵称，供下次启动 / 重新登录时在 myInfo
  /// 回包前立刻渲染正确头像与用户名，消除首帧「空头像 + 用户」闪烁。
  static const _avatarUrlKey = 'avatar_url';
  static const _nicknameKey = 'nickname';

  /// 通过 `/app/common/v2/configList` 拉取的「文件服务器域名」。所有
  /// 后端返回的相对路径（如 `app/upload/.../foo.png`）需要拼接到这个域名
  /// 上才能加载到。为空时回退到 `AppConstants.apiBaseUrl`。
  static const _fileBaseUrlKey = 'fileBaseUrl';

  /// 是否已完成首次原生权限引导（麦克风 / 相机 / 相册 / 通知等）。
  static const _nativePermissionsPrimedKey = 'native_permissions_primed_v1';

  final SharedPreferences _prefs;

  static Future<AppStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStorage(prefs);
  }

  String get token => _prefs.getString(_tokenKey) ?? '';

  String get pushId => _prefs.getString(_pushIdKey) ?? '';

  String get schoolId => _prefs.getString(_schoolIdKey) ?? '0';

  /// 与 [schoolId] 相同；Web 端对应 localStorage 键 `flutter.schoolId`。
  String get cachedSchoolId => schoolId;

  String get mobile => _prefs.getString(_mobileKey) ?? '';

  String get avatarUrl => _prefs.getString(_avatarUrlKey) ?? '';

  String get nickname => _prefs.getString(_nicknameKey) ?? '';

  String get fileBaseUrl => _prefs.getString(_fileBaseUrlKey) ?? '';

  bool get nativePermissionsPrimed =>
      _prefs.getBool(_nativePermissionsPrimedKey) ?? false;

  /// `/app/common/dict/check` 返回的 `data` 原值；未拉取过时为 `null`。
  bool? get checkStatusData {
    if (!_prefs.containsKey(_checkStatusKey)) {
      return null;
    }
    final value = _prefs.get(_checkStatusKey);
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      if (value.isEmpty || value == 'false' || value == '0') {
        return false;
      }
      return true;
    }
    return null;
  }

  /// `data: true` 表示 App 正在审核中（需隐藏会员 / 兑换等商业化入口）。
  bool get isAppUnderReview => checkStatusData ?? false;

  /// 非审核中时可展示会员相关内容。
  bool get showMemberContent => !isAppUnderReview;

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
  }

  Future<void> saveSchoolId(dynamic schoolId) async {
    final value = schoolId?.toString().trim() ?? '';
    await _prefs.setString(_schoolIdKey, value.isEmpty ? '0' : value);
  }

  Future<void> clearSchoolId() async {
    await _prefs.remove(_schoolIdKey);
  }

  Future<void> saveMobile(String mobile) async {
    await _prefs.setString(_mobileKey, mobile);
  }

  Future<void> clearMobile() async {
    await _prefs.remove(_mobileKey);
  }

  Future<void> saveAvatarUrl(String url) async {
    if (url.isEmpty) {
      await _prefs.remove(_avatarUrlKey);
    } else {
      await _prefs.setString(_avatarUrlKey, url);
    }
  }

  Future<void> clearAvatarUrl() async {
    await _prefs.remove(_avatarUrlKey);
  }

  Future<void> saveNickname(String name) async {
    if (name.isEmpty) {
      await _prefs.remove(_nicknameKey);
    } else {
      await _prefs.setString(_nicknameKey, name);
    }
  }

  Future<void> clearNickname() async {
    await _prefs.remove(_nicknameKey);
  }

  Future<void> savePushId(String pushId) async {
    await _prefs.setString(_pushIdKey, pushId);
  }

  Future<void> saveFileBaseUrl(String url) async {
    final value = url.trim();
    if (value.isEmpty) {
      await _prefs.remove(_fileBaseUrlKey);
      return;
    }
    await _prefs.setString(_fileBaseUrlKey, value);
  }

  Future<void> setNativePermissionsPrimed(bool value) async {
    await _prefs.setBool(_nativePermissionsPrimedKey, value);
  }

  Future<void> saveCheckStatus(dynamic value) async {
    if (value == null) {
      await _prefs.remove(_checkStatusKey);
      return;
    }
    if (value is bool) {
      await _prefs.setBool(_checkStatusKey, value);
      return;
    }
    if (value is int) {
      await _prefs.setInt(_checkStatusKey, value);
      return;
    }
    if (value is double) {
      await _prefs.setDouble(_checkStatusKey, value);
      return;
    }
    await _prefs.setString(_checkStatusKey, value.toString());
  }
}
