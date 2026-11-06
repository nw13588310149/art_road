import 'dart:async';

import 'package:flutter/services.dart';

import 'music_play_audio_visualizer_io.dart'
    if (dart.library.html) 'music_play_audio_visualizer_web.dart';

/// 从正在播放的长音频提取真实频谱，供 MusicPlay 转盘下方可视化条使用。
abstract class MusicPlayAudioVisualizer {
  factory MusicPlayAudioVisualizer() => createMusicPlayAudioVisualizer();

  Stream<List<double>> get bands;

  /// [androidAudioSessionId]：Android `just_audio` 的 ExoPlayer session；
  /// 为空时 native 端回退到 output mix（`0`）。
  Future<void> attach({
    required String url,
    int? androidAudioSessionId,
  });

  Future<void> updateAndroidSession(int? sessionId);

  Future<void> syncTransport({
    required bool playing,
    required int positionMs,
  });

  Future<void> detach();

  Future<void> dispose();
}

/// Native EventChannel 推送的 bands 解析。
List<double> parseMusicPlayVisualizerBandEvent(dynamic raw) {
  if (raw is! List) return const <double>[];
  return raw
      .map((e) => (e is num ? e.toDouble() : double.tryParse('$e') ?? 0))
      .map((v) => v.clamp(0.0, 1.0))
      .toList(growable: false);
}

const MethodChannel kMusicPlayVisualizerMethodChannel = MethodChannel(
  'com.yyzl.music/music_play_visualizer',
);

const EventChannel kMusicPlayVisualizerEventChannel = EventChannel(
  'com.yyzl.music/music_play_visualizer/bands',
);
