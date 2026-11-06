import 'ios_playback_volume.dart';

/// 虚拟钢琴 / 智能视唱短音播放参数（Web 与 iOS 原生对齐）。
///
/// 响度由系统音量键控制；软件层不对单音做衰减或和弦 headroom。
abstract final class PianoPlaybackMix {
  static const int maxVoices = 24;

  static const double masterLevel = 1.0;

  static const int voiceStealFadeMs = 28;

  static const int stopAllFadeMs = 120;

  static const int metronomeStopFadeMs = 35;

  /// 每音使用请求音量；iOS 恒为 1.0，与系统音量一致。
  static double noteGain({
    required double requested,
    int activeVoicesIncludingNew = 1,
  }) {
    return IosPlaybackVolume.apply(requested.clamp(0.0, 1.0));
  }
}
