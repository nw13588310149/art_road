// 通用定位服务入口。
//
// Web 端调用浏览器 geolocation；iOS / Android 使用 geolocator。
// 地址解析见 [BaiduGeoService.reverseGeocode]（百度 + 系统 geocoding 兜底）。
export 'geo_locator_types.dart';
export 'geo_locator_io.dart' if (dart.library.html) 'geo_locator_web.dart';
