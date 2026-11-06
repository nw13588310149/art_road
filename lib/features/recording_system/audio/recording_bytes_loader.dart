import 'dart:typed_data';

import 'recording_bytes_loader_stub.dart'
    if (dart.library.html) 'recording_bytes_loader_web.dart'
    if (dart.library.io) 'recording_bytes_loader_io.dart';

Future<Uint8List> loadRecordedBytes(String source) => readRecordedBytes(source);

String buildTemporaryRecordingPath() => createTemporaryRecordingPath();

Future<String> publishRecordingBytes(
  Uint8List bytes, {
  String mimeType = 'audio/webm',
}) =>
    createPublishedRecordingUrl(bytes, mimeType: mimeType);

void revokePublishedRecordingUrl(String url) =>
    disposePublishedRecordingUrl(url);
