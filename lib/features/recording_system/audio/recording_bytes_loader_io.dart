import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readRecordedBytes(String source) {
  final uri = Uri.tryParse(source);
  if (uri != null && uri.scheme == 'file') {
    return File.fromUri(uri).readAsBytes();
  }
  return File(source).readAsBytes();
}

String createTemporaryRecordingPath() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${Directory.systemTemp.path}${Platform.pathSeparator}music_recording_$timestamp.m4a';
}

Future<String> createPublishedRecordingUrl(
  Uint8List bytes, {
  String mimeType = 'audio/mp4',
}) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final path =
      '${Directory.systemTemp.path}${Platform.pathSeparator}music_recording_merged_$timestamp.m4a';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

void disposePublishedRecordingUrl(String url) {
  if (url.isEmpty || _isUrlPlaybackSource(url)) return;
  try {
    final file = File(_localPath(url));
    if (file.existsSync()) {
      file.deleteSync();
    }
  } catch (_) {}
}

bool _isUrlPlaybackSource(String source) {
  final lower = source.trimLeft().toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('blob:') ||
      lower.startsWith('data:');
}

String _localPath(String source) {
  final uri = Uri.tryParse(source);
  if (uri != null && uri.scheme == 'file') {
    return uri.toFilePath();
  }
  return source;
}
