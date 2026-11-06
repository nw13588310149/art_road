import 'dart:typed_data';

// ignore: implementation_imports
import 'package:flutter_soloud/src/bindings/soloud_controller.dart';

Float32List readPitchAnalysisSamplesFromMemImpl(
  Uint8List buffer,
  int numSamplesNeeded, {
  double endTime = -1,
  bool average = true,
}) {
  return SoLoudController().soLoudFFI.readSamplesFromMem(
    buffer,
    numSamplesNeeded,
    endTime: endTime,
    average: average,
  );
}

Float32List readPitchAnalysisSamplesFromFileImpl(
  String filePath,
  int numSamplesNeeded, {
  double endTime = -1,
  bool average = true,
}) {
  return SoLoudController().soLoudFFI.readSamplesFromFile(
    filePath,
    numSamplesNeeded,
    endTime: endTime,
    average: average,
  );
}
