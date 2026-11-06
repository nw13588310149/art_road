import 'dart:io';
import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

import 'video_cover_frame_extractor_constants.dart';

Future<Uint8List?> extractVideoCoverFrameImpl({
  required String? filePath,
  required Uint8List? fileBytes,
  int frameIndex = 10,
}) async {
  if (frameIndex < 1) return null;

  String? videoPath = filePath?.trim();
  File? tempFile;

  try {
    if ((videoPath == null || videoPath.isEmpty) &&
        fileBytes != null &&
        fileBytes.isNotEmpty) {
      tempFile = File(
        '${Directory.systemTemp.path}/circle_video_cover_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await tempFile.writeAsBytes(fileBytes, flush: true);
      videoPath = tempFile.path;
    }
    if (videoPath == null || videoPath.isEmpty) return null;

    final timeMs = ((frameIndex - 1) * 1000 / kVideoCoverDefaultFps).round();

    return await VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 1280,
      quality: 85,
      timeMs: timeMs,
    );
  } catch (_) {
    return null;
  } finally {
    try {
      tempFile?.deleteSync();
    } catch (_) {}
  }
}
