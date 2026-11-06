import 'package:geolocator/geolocator.dart';

import 'geo_locator_types.dart';

/// iOS / Android：通过 [geolocator] 获取 WGS-84 坐标。
Future<GeoPosition> getCurrentLocation({Duration? timeout}) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw const GeoException(
      GeoErrorKind.positionUnavailable,
      '系统定位服务未开启',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const GeoException(GeoErrorKind.permissionDenied, '已拒绝定位权限');
  }
  if (permission == LocationPermission.deniedForever) {
    throw const GeoException(
      GeoErrorKind.permissionDenied,
      '定位权限被永久拒绝，请在系统设置中开启',
    );
  }

  try {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout ?? const Duration(seconds: 12),
      ),
    );
    return GeoPosition(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyMeters: pos.accuracy,
      timestamp: pos.timestamp,
    );
  } on LocationServiceDisabledException {
    throw const GeoException(
      GeoErrorKind.positionUnavailable,
      '系统定位服务未开启',
    );
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('timeout') || msg.contains('Timeout')) {
      throw const GeoException(GeoErrorKind.timeout, '获取定位超时');
    }
    if (msg.contains('permission') || msg.contains('Permission')) {
      throw const GeoException(
        GeoErrorKind.permissionDenied,
        '已拒绝定位权限，请在系统设置中开启',
      );
    }
    throw GeoException(GeoErrorKind.unknown, e.toString());
  }
}
