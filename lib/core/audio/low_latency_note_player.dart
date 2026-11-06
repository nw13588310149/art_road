import 'low_latency_note_player_stub.dart'
    if (dart.library.io) 'low_latency_note_player_io.dart';

/// 低延迟短音频播放器。
///
/// 用途：钢琴键、节拍器、智能听写题目音这类「短、小、频繁触发」的声音。
/// 不用于长音频播放，长音频仍走 media_kit / just_audio。
abstract interface class LowLatencyNotePlayer {
  bool get isReady;

  /// iOS 原生 AVAudioEngine 是否就绪（不含 just_audio 回退）。
  bool get nativeReady;

  bool get supportsImmediatePlay;

  /// 屏幕诊断面板用：返回播放器 + 原生引擎/会话的实时状态快照。
  Future<Map<String, Object?>> diagnostics();

  Future<void> prepare(Map<String, String> assetByKey);

  /// iOS：等待原生侧完成解码后再返回（节拍器初始化专用，避免增量 prepare 早退）。
  Future<void> prepareEnsuringDecoded(Map<String, String> assetByKey);

  bool hasPrepared(String key);

  bool tryPlay(String key, {double volume = 1, bool metronome = false});

  Future<void> play(
    String key, {
    double volume = 1,
    bool metronome = false,
    bool waitUntilFinished = false,
  });

  /// iOS：轻量确认引擎在运行态（不丢弃排队音符）。
  Future<void> pingEngine();

  /// 兼容旧调用；实现应委托 [pingEngine]。
  Future<void> reclaimEngine();

  /// 仅淡出节拍器发声，不截断钢琴延音（iOS 原生池）。
  Future<void> stopMetronomePlaybacks();

  Future<void> stopAll();

  Future<void> dispose();
}

LowLatencyNotePlayer createLowLatencyNotePlayer() {
  return createPlatformLowLatencyNotePlayer();
}
