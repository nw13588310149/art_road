import 'dart:typed_data';

Float32List readPitchAnalysisSamplesFromMemImpl(
  Uint8List buffer,
  int numSamplesNeeded, {
  double endTime = -1,
  bool average = true,
}) {
  throw UnsupportedError(
    'readPitchAnalysisSamplesFromMemImpl is only available on native IO.',
  );
}

Float32List readPitchAnalysisSamplesFromFileImpl(
  String filePath,
  int numSamplesNeeded, {
  double endTime = -1,
  bool average = true,
}) {
  throw UnsupportedError(
    'readPitchAnalysisSamplesFromFileImpl is only available on native IO.',
  );
}
