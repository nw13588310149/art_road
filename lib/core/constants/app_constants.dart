import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class AppConstants {
  static const _configuredApi = String.fromEnvironment('ART_ROAD_API_BASE_URL');

  /// Web 随当前站点的反向代理接入，原生构建由负责人指定服务根地址。
  static String get apiBaseUrl {
    if (_configuredApi.isNotEmpty) return secureApiBase(_configuredApi);
    return kIsWeb ? secureApiBase('${Uri.base.origin}/') : '';
  }

  static String secureApiBase(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return '';
    }
    final loopback = const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) return '';
    return uri.toString();
  }

  static String get markingApiBaseUrl => apiBaseUrl;

  static const fallbackDeviceId = '17186897471475123686';
}
