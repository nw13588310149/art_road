import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart WAV PCM decoder for sight-singing pitch analysis.
///
/// Avoids flutter_soloud [readSamplesFromMem], which runs in a [compute]
/// isolate and breaks native FFI symbol lookup (`isInited`) on iOS/iPadOS.
abstract final class PitchWavDecoder {
  static bool looksLikeWav(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
  }

  static PitchWavDecodeResult decode(
    Uint8List bytes, {
    int targetSampleRate = 22050,
  }) {
    if (!looksLikeWav(bytes)) {
      throw PitchWavDecodeException('不是有效的 WAV（缺少 RIFF 头）。');
    }

    final view = ByteData.sublistView(bytes);
    // RIFF chunk size 位于 offset 4（不含前 8 字节的 "RIFF"+size 头）。
    final riffSize = view.getUint32(4, Endian.little);
    if (bytes.length < 8 + riffSize) {
      throw PitchWavDecodeException('WAV 文件不完整。');
    }

    var offset = 12;
    var audioFormat = 0;
    var numChannels = 0;
    var sampleRate = 0;
    var bitsPerSample = 0;
    var dataOffset = -1;
    var dataSize = 0;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = view.getUint32(offset + 4, Endian.little);
      final chunkDataStart = offset + 8;
      if (chunkSize <= 0) {
        break;
      }

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        audioFormat = view.getUint16(chunkDataStart, Endian.little);
        numChannels = view.getUint16(chunkDataStart + 2, Endian.little);
        sampleRate = view.getUint32(chunkDataStart + 4, Endian.little);
        bitsPerSample = view.getUint16(chunkDataStart + 14, Endian.little);
      } else if (chunkId == 'data' && dataOffset < 0) {
        dataOffset = chunkDataStart;
        dataSize = math.min(chunkSize, bytes.length - chunkDataStart);
      }

      final nextOffset =
          chunkDataStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
      if (nextOffset <= offset) {
        break;
      }
      offset = nextOffset;
    }

    if (dataOffset < 0 || dataSize <= 0) {
      throw PitchWavDecodeException('WAV 缺少 data 块。');
    }
    if (audioFormat != 1) {
      throw PitchWavDecodeException('仅支持 PCM WAV（audioFormat=$audioFormat）。');
    }
    if (bitsPerSample != 16) {
      throw PitchWavDecodeException('仅支持 16-bit PCM WAV（bits=$bitsPerSample）。');
    }
    if (numChannels < 1 || numChannels > 2) {
      throw PitchWavDecodeException('不支持的声道数：$numChannels');
    }
    if (sampleRate <= 0) {
      throw PitchWavDecodeException('无效的采样率：$sampleRate');
    }

    final frameCount = dataSize ~/ (bitsPerSample ~/ 8 * numChannels);
    if (frameCount <= 0) {
      throw PitchWavDecodeException('WAV data 块为空。');
    }

    final mono = Float32List(frameCount);
    final dataView = ByteData.sublistView(bytes, dataOffset, dataOffset + dataSize);
    if (numChannels == 1) {
      for (var i = 0; i < frameCount; i++) {
        final sample = dataView.getInt16(i * 2, Endian.little);
        mono[i] = sample / 32768.0;
      }
    } else {
      for (var i = 0; i < frameCount; i++) {
        final left = dataView.getInt16(i * 4, Endian.little);
        final right = dataView.getInt16(i * 4 + 2, Endian.little);
        mono[i] = (left + right) / (2 * 32768.0);
      }
    }

    final resampled = sampleRate == targetSampleRate
        ? mono
        : _resampleLinear(mono, sampleRate, targetSampleRate);
    final durationMs = (resampled.length * 1000 / targetSampleRate).round();

    return PitchWavDecodeResult(
      samples: resampled,
      sampleRate: targetSampleRate,
      duration: Duration(milliseconds: durationMs.clamp(1, 1 << 31)),
    );
  }

  static Float32List _resampleLinear(
    Float32List input,
    int fromRate,
    int toRate,
  ) {
    if (input.isEmpty || fromRate == toRate) {
      return input;
    }
    final outLen = (input.length * toRate / fromRate).round().clamp(1, 1 << 28);
    final output = Float32List(outLen);
    final ratio = fromRate / toRate;
    for (var i = 0; i < outLen; i++) {
      final srcPos = i * ratio;
      final idx = srcPos.floor();
      final frac = srcPos - idx;
      if (idx >= input.length - 1) {
        output[i] = input[input.length - 1];
      } else {
        output[i] = input[idx] * (1 - frac) + input[idx + 1] * frac;
      }
    }
    return output;
  }
}

class PitchWavDecodeResult {
  const PitchWavDecodeResult({
    required this.samples,
    required this.sampleRate,
    required this.duration,
  });

  final Float32List samples;
  final int sampleRate;
  final Duration duration;
}

class PitchWavDecodeException implements Exception {
  PitchWavDecodeException(this.message);
  final String message;

  @override
  String toString() => message;
}
