abstract class MusicCompanionWebAudioPlayer {
  bool get isReady;

  Future<void> prepare(Iterable<String> assets);

  Future<void> activateByUserGesture();

  Future<void> playAsset(
    String asset, {
    double volume = 1,
    bool metronome = false,
  });

  /// 仅停止节拍器短音，不影响虚拟钢琴正在延音的音符。
  Future<void> stopMetronomePlaybacks();

  Future<void> stopAll();

  Future<void> dispose();
}
