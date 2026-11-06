import 'dart:typed_data';

Future<Uint8List> readRecordedBytes(String source) async {
  throw UnsupportedError(
    'Recording bytes loader is not supported on this platform.',
  );
}

String createTemporaryRecordingPath() => 'recording.m4a';

Future<String> createPublishedRecordingUrl(
  Uint8List bytes, {
  String mimeType = 'audio/webm',
}) async {
  throw UnsupportedError(
    'Recording publish is not supported on this platform.',
  );
}

void disposePublishedRecordingUrl(String url) {}
