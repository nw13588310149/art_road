import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 裁切页展示用图（已校正方向并压缩为 JPEG）。
class FaceIdPreparedImage {
  const FaceIdPreparedImage({required this.bytes, required this.size});

  final Uint8List bytes;
  final Size size;
}

/// 在 isolate 中解码大图，避免打开裁切页时主线程卡顿 2–4 秒。
Future<FaceIdPreparedImage?> prepareFaceIdDisplayImage(Uint8List raw) {
  return compute(_prepareFaceIdDisplayImage, raw);
}

FaceIdPreparedImage? _prepareFaceIdDisplayImage(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    return null;
  }
  final oriented = img.bakeOrientation(decoded);
  return FaceIdPreparedImage(
    bytes: Uint8List.fromList(img.encodeJpg(oriented, quality: 92)),
    size: Size(oriented.width.toDouble(), oriented.height.toDouble()),
  );
}
