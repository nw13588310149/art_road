// Web-only implementation (dart:html).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'video_cover_frame_extractor_constants.dart';

Future<Uint8List?> extractVideoCoverFrameImpl({
  required String? filePath,
  required Uint8List? fileBytes,
  int frameIndex = 10,
}) async {
  if (frameIndex < 1 || fileBytes == null || fileBytes.isEmpty) {
    return null;
  }

  final blob = html.Blob(<Object>[fileBytes]);
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final video = html.VideoElement()
    ..src = objectUrl
    ..muted = true
    ..preload = 'auto'
    ..crossOrigin = 'anonymous';

  try {
    await video.onLoadedMetadata.first.timeout(const Duration(seconds: 15));

    final duration = video.duration;
    final targetSec = (frameIndex - 1) / kVideoCoverDefaultFps;
    video.currentTime = duration.isFinite && duration > 0
        ? targetSec.clamp(0, duration)
        : targetSec;

    await video.onSeeked.first.timeout(const Duration(seconds: 15));

    final width = video.videoWidth;
    final height = video.videoHeight;
    if (width <= 0 || height <= 0) return null;

    final canvas = html.CanvasElement(width: width, height: height);
    canvas.context2D.drawImage(video, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  } finally {
    html.Url.revokeObjectUrl(objectUrl);
  }
}
