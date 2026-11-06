import 'dart:typed_data';

/// Web stub: decode stays in memory via [readSamplesFromMem].
abstract final class PitchAnalysisTempFile {
  static Future<String> write(Uint8List bytes, String ext) async {
    throw UnsupportedError('PitchAnalysisTempFile.write is not used on web.');
  }

  static Future<void> delete(String path) async {}

  static Future<Uint8List> read(String path) async {
    throw UnsupportedError('PitchAnalysisTempFile.read is not used on web.');
  }
}
