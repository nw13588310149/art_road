import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// 缓存 [availableCameras] 并解析「标准前置 / 后置」索引（跳过超广角、长焦等多摄位）。
abstract final class FaceCameraRegistry {
  static List<CameraDescription>? _cached;
  static Future<List<CameraDescription>>? _loading;

  static void warmUp() {
    unawaited(getCameras());
  }

  static Future<List<CameraDescription>> getCameras() {
    if (_cached != null) {
      return Future<List<CameraDescription>>.value(_cached!);
    }
    return _loading ??= _load();
  }

  static Future<List<CameraDescription>> _load() async {
    try {
      final list = await availableCameras();
      _cached = list;
      return list;
    } catch (e, stack) {
      debugPrint('FaceCameraRegistry.getCameras: $e\n$stack');
      rethrow;
    } finally {
      _loading = null;
    }
  }

  static FaceCameraPair resolvePair(List<CameraDescription> cameras) {
    int? front;
    int? backWide;
    int? backFallback;

    for (var i = 0; i < cameras.length; i++) {
      final camera = cameras[i];
      switch (camera.lensDirection) {
        case CameraLensDirection.front:
          front ??= i;
        case CameraLensDirection.back:
          if (_isUltraWide(camera)) {
            continue;
          }
          backFallback ??= i;
          if (camera.lensType == CameraLensType.wide ||
              camera.lensType == CameraLensType.unknown) {
            backWide ??= i;
          }
        case CameraLensDirection.external:
          break;
      }
    }

    return FaceCameraPair(
      frontIndex: front,
      backIndex: backWide ?? backFallback,
    );
  }

  static bool _isUltraWide(CameraDescription camera) {
    if (camera.lensType == CameraLensType.ultraWide) {
      return true;
    }
    final name = camera.name.toLowerCase();
    return name.contains('ultra') ||
        name.contains('0.5x') ||
        name.contains('0.5×');
  }
}

class FaceCameraPair {
  const FaceCameraPair({this.frontIndex, this.backIndex});

  final int? frontIndex;
  final int? backIndex;

  bool get canSwitch => frontIndex != null && backIndex != null;

  int indexFor({required bool useFront}) {
    if (useFront) {
      return frontIndex ?? backIndex ?? 0;
    }
    return backIndex ?? frontIndex ?? 0;
  }
}
