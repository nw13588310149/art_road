abstract final class AppConstants {
  /// 平台接口（账号、首页、课件、视频、智慧校园等，沿用音乐之路平台协议）。
  static const apiBaseUrl = String.fromEnvironment(
    'ART_ROAD_API_BASE_URL',
    defaultValue: 'https://api-v2.yyzl0931.com/',
  );

  /// 艺考网阅卷系统接口（学情、原卷、作品点评、资料库）。
  static const markingApiBaseUrl = String.fromEnvironment(
    'ART_ROAD_API_BASE_URL',
    defaultValue: 'https://exam-api.yyzl0931.com/',
  );

  static const fallbackDeviceId = '17186897471475123686';
}
