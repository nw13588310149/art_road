import 'realtime_pitch_capture_stub.dart'
    if (dart.library.io) 'realtime_pitch_capture_io.dart';

/// 实时麦克风采样 → YIN 音高检测结果的事件流。
abstract class RealtimePitchCapture {
  /// 麦克风权限是否已授予。
  Future<bool> hasPermission();

  /// 申请权限（必要时弹系统提示）。
  Future<bool> requestPermission();

  /// 启动采样 + 检测。事件的最小间隔约等于一帧（≈ 46ms）。
  Future<Stream<RealtimePitchEvent>> start();

  /// 停止采样、关闭录音、释放资源。
  ///
  /// [restorePlaybackSession] 为 false 时仅停麦，不立刻切回 playback 会话
  /// （跟唱停止时应先等伴奏淡出完毕再恢复会话，避免爆音）。
  Future<void> stop({bool restorePlaybackSession = true});

  bool get isRunning;
}

/// 实时音高事件（单帧）。
class RealtimePitchEvent {
  const RealtimePitchEvent({
    required this.frequencyHz,
    required this.midi,
    required this.confidence,
    required this.amplitude,
    required this.pitched,
  });
  final double frequencyHz;
  final double midi;
  final double confidence;
  final double amplitude;
  final bool pitched;

  static const empty = RealtimePitchEvent(
    frequencyHz: 0,
    midi: -1,
    confidence: 0,
    amplitude: 0,
    pitched: false,
  );
}

/// 通过条件导入选择 io / web 实现。
enum RealtimePitchCaptureProfile {
  /// 录音系统等通用场景。
  general,

  /// 智能视唱 + 扬声器伴奏：measurement 采音 + 软件串音过滤。
  sightSinging,

  /// 无声跟唱：与 [sightSinging] 相同采音策略，仅伴奏不外放。
  visualOnly,
}

RealtimePitchCapture createRealtimePitchCapture({
  RealtimePitchCaptureProfile profile = RealtimePitchCaptureProfile.general,
}) =>
    createPlatformRealtimePitchCapture(profile: profile);
