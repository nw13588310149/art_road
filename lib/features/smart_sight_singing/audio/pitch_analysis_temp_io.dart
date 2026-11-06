import 'dart:io';
import 'dart:typed_data';

/// Native temp-file helper for MP3 decode via [readSamplesFromFile].
abstract final class PitchAnalysisTempFile {
  static Future<String> write(Uint8List bytes, String ext) async {
    final safeExt = ext.isEmpty ? 'mp3' : ext;
    final path =
        '${Directory.systemTemp.path}/sight_singing_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<Uint8List> read(String path) async {
    return File(path).readAsBytes();
  }
}
