import 'dart:typed_data';

/// 将 PCM16 小端字节转为 [-1, 1] 浮点样本。
///
/// `pitch_detector_dart` 自带的 [Uint8List.convertPCM16ToFloat] 只取低 8 位，
/// 会导致 YIN 几乎永远检测不到音高；视唱必须自行转换。
List<double> pcm16LeToFloatSamples(Uint8List pcm16Bytes) {
  final view = ByteData.sublistView(pcm16Bytes);
  final sampleCount = pcm16Bytes.length ~/ 2;
  final samples = List<double>.filled(sampleCount, 0);
  for (var i = 0; i < sampleCount; i++) {
    samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return samples;
}
