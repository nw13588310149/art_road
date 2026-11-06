import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/network/media_url.dart';
import '../logic/image_filters.dart';
import '../logic/image_ops.dart';

/// 工具箱当前处理的图片：显示用的 [image] 与像素运算用的 [data] 尺寸一致（长边 ≤ 1600）。
class ToolboxImage {
  ToolboxImage({
    required this.data,
    required this.image,
    required this.label,
    required this.version,
  });

  final ArtImageData data;
  final ui.Image image;
  final String label;

  /// 每次换图递增，工具据此丢弃上一张图的派生结果。
  final int version;

  int get width => data.width;
  int get height => data.height;
  double get aspectRatio => data.width / data.height;

  Future<ArtImageData>? _work;

  /// 滑块实时调整的工具使用的缩小副本（长边 ≤ [kToolboxWorkSide]），首次使用时在后台生成，换工具时复用。
  Future<ArtImageData> workData() => _work ??=
      math.max(data.width, data.height) <= kToolboxWorkSide
      ? Future<ArtImageData>.value(data)
      : compute(downscaleForWork, data);

  void dispose() => image.dispose();
}

class PickedImageBytes {
  const PickedImageBytes(this.bytes, this.name);

  final Uint8List bytes;
  final String name;
}

/// 图片来源：相册（file_picker，Web 与 iPad 均直接拿字节）、打包资源、网络地址。
class ToolboxImageLoader {
  ToolboxImageLoader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  /// 用户取消返回 null；打不开相册时抛出异常。
  Future<PickedImageBytes?> pickFromAlbum() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) {
      return null;
    }
    return PickedImageBytes(bytes, file.name);
  }

  Future<Uint8List> loadAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// 演示媒体地址直接读打包资源，其余地址走网络下载。
  Future<Uint8List> download(String url) async {
    final assetKey = demoAssetKeyOf(url);
    if (assetKey != null) {
      try {
        return await loadAsset(assetKey);
      } catch (_) {
        // 资源键解析不准时退回网络下载。
      }
    }
    final response = await _dio.get<List<int>>(
      MediaUrl.resolve(url),
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw StateError('图片内容为空');
    }
    return data is Uint8List ? data : Uint8List.fromList(data);
  }
}

/// 演示媒体地址对应的资源键：iOS / Android 为 `http://127.0.0.1:端口/a/assets/...`，
/// Web 为 `<站点>/assets/assets/...`。
String? demoAssetKeyOf(String url) {
  final path = Uri.tryParse(url)?.path ?? '';
  for (final marker in const ['/a/assets/', '/assets/assets/']) {
    final index = path.indexOf(marker);
    if (index >= 0) {
      final key = path.substring(index + marker.length - 'assets/'.length);
      return Uri.decodeFull(key);
    }
  }
  return null;
}

/// 解码并把长边限制在 [kToolboxMaxSide] 内：优先用引擎解码（异步、不占 UI 线程，
/// 支持 HEIC 等平台格式），失败时在 isolate 中用 image 包兜底。
Future<ToolboxImage?> decodeToolboxImage(
  Uint8List bytes, {
  required String label,
  required int version,
}) async {
  final engine = await _decodeWithEngine(bytes);
  if (engine != null) {
    return ToolboxImage(
      data: engine.data,
      image: engine.image,
      label: label,
      version: version,
    );
  }
  final data = await compute(decodeArtImage, bytes);
  if (data == null) {
    return null;
  }
  final image = await artImageToUiImage(data);
  return ToolboxImage(data: data, image: image, label: label, version: version);
}

Future<({ArtImageData data, ui.Image image})?> _decodeWithEngine(
  Uint8List bytes,
) async {
  ui.Image? image;
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (width, height) {
        if (width <= kToolboxMaxSide && height <= kToolboxMaxSide) {
          return const ui.TargetImageSize();
        }
        return width >= height
            ? const ui.TargetImageSize(width: kToolboxMaxSide)
            : const ui.TargetImageSize(height: kToolboxMaxSide);
      },
    );
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      image.dispose();
      return null;
    }
    final rgba = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final data = await compute(
      flattenPremultipliedImage,
      ArtImageData(width: image.width, height: image.height, rgba: rgba),
    );
    return (data: data, image: image);
  } catch (_) {
    image?.dispose();
    return null;
  }
}

/// 把处理后的像素转成可显示的图片。
Future<ui.Image> artImageToUiImage(ArtImageData data) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    data.rgba,
    data.width,
    data.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
