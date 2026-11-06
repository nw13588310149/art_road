import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/constants/baidu_map_config.dart';
import 'geo_address_platform_io.dart'
    if (dart.library.html) 'geo_address_platform_web.dart';

/// 百度地图 Web 服务：静态底图 + 逆地理编码（WGS-84 入参）。
///
/// iOS / Android 端用静态图规避 WKWebView Referer 白名单问题；
/// 逆地理编码优先走百度，失败时回退到系统 geocoding。
abstract final class BaiduGeoService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: <String, String>{
        'Referer': BaiduMapConfig.webReferer,
      },
    ),
  );

  /// 生成百度静态地图 URL（[coordtype]=wgs84ll）。
  static String staticMapUrl({
    required double lat,
    required double lng,
    required int width,
    required int height,
    int zoom = 16,
    int scaler = 2,
  }) {
    final w = width.clamp(100, 1024);
    final h = height.clamp(100, 1024);
    return Uri(
      scheme: 'https',
      host: 'api.map.baidu.com',
      path: '/staticimage/v2',
      queryParameters: <String, String>{
        'ak': BaiduMapConfig.webJsAk,
        'center': '$lng,$lat',
        'width': '$w',
        'height': '$h',
        'zoom': '$zoom',
        'scaler': '${scaler.clamp(1, 2)}',
        'markers': '$lng,$lat',
        'coordtype': 'wgs84ll',
        'markerStyles': 'l,,0x8741FF',
      },
    ).toString();
  }

  /// 下载静态地图 PNG（须带 Referer，不可直接用 [Image.network]）。
  static Future<Uint8List?> fetchStaticMapImage({
    required double lat,
    required double lng,
    required int width,
    required int height,
    int zoom = 16,
    int scaler = 2,
  }) async {
    try {
      final url = staticMapUrl(
        lat: lat,
        lng: lng,
        width: width,
        height: height,
        zoom: zoom,
        scaler: scaler,
      );
      final resp = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data;
      if (bytes == null || bytes.length < 8) return null;
      // PNG 魔数；否则可能是 JSON 错误体。
      if (bytes[0] == 0x89 && bytes[1] == 0x50) {
        return Uint8List.fromList(bytes);
      }
    } catch (_) {
      // 网络或 AK 权限问题：上层展示坐标占位。
    }
    return null;
  }

  /// 逆地理编码；百度失败时回退系统 geocoding。
  static Future<String?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    final baidu = await _baiduReverseGeocode(lat: lat, lng: lng);
    if (baidu != null && baidu.isNotEmpty) return baidu;
    return platformReverseGeocode(lat: lat, lng: lng);
  }

  static Future<String?> _baiduReverseGeocode({
    required double lat,
    required double lng,
  }) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        'https://api.map.baidu.com/reverse_geocoding/v3/',
        queryParameters: <String, dynamic>{
          'ak': BaiduMapConfig.webJsAk,
          'output': 'json',
          'coordtype': 'wgs84ll',
          'location': '$lat,$lng',
        },
      );
      final data = resp.data;
      if (data == null || data['status'] != 0) return null;
      final result = data['result'];
      if (result is! Map) return null;
      final map = Map<String, dynamic>.from(result);
      for (final key in ['formatted_address', 'sematic_description']) {
        final text = map[key]?.toString().trim();
        if (text != null && text.isNotEmpty) return text;
      }
    } catch (_) {
      // 百度 Web 服务未开通或网络异常。
    }
    return null;
  }
}
