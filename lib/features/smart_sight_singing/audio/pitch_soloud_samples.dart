import 'dart:typed_data';

import 'pitch_soloud_samples_stub.dart'
    if (dart.library.io) 'pitch_soloud_samples_io.dart';

/// Read equally-spaced audio samples on the **main isolate**.
///
/// Public [SoLoud.readSamplesFromMem] uses [compute], which breaks native FFI
/// on iOS/iPadOS (`isInited` symbol not found in spawned isolates).
Float32List readPitchAnalysisSamplesFromMem(
  Uint8List buffer,
  int numSamplesNeeded, {
  double endTime = -1,
  bool average = true,
}) {
  return readPitchAnalysisSamplesFromMemImpl(
    buffer,
    numSamplesNeeded,
    endTime: endTime,
    average: average,
  );
}

Float32List readPitchAnalysisSamplesFromFile(
  String filePath,
  int numSamplesNeeded, {
  double endTime = -1,
  bool average = true,
}) {
  return readPitchAnalysisSamplesFromFileImpl(
    filePath,
    numSamplesNeeded,
    endTime: endTime,
    average: average,
  );
}
