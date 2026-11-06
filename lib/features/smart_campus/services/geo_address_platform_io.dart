import 'package:geocoding/geocoding.dart';

/// iOS / Android：系统逆地理编码（Apple / Google），作为百度 Web 服务不可用时的兜底。
Future<String?> platformReverseGeocode({
  required double lat,
  required double lng,
}) async {
  try {
    final marks = await placemarkFromCoordinates(lat, lng);
    if (marks.isEmpty) return null;
    final p = marks.first;
    final parts = <String>[
      if (p.administrativeArea?.trim().isNotEmpty == true) p.administrativeArea!.trim(),
      if (p.locality?.trim().isNotEmpty == true) p.locality!.trim(),
      if (p.subLocality?.trim().isNotEmpty == true) p.subLocality!.trim(),
      if (p.thoroughfare?.trim().isNotEmpty == true) p.thoroughfare!.trim(),
      if (p.subThoroughfare?.trim().isNotEmpty == true) p.subThoroughfare!.trim(),
    ];
    final text = parts.join('');
    return text.isNotEmpty ? text : p.name?.trim();
  } catch (_) {
    return null;
  }
}
