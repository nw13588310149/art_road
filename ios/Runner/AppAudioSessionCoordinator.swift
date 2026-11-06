import AVFoundation
import Flutter

/// Single AVAudioSession owner for Flutter-facing iOS audio features.
final class AppAudioSessionCoordinator {
  static let shared = AppAudioSessionCoordinator()

  private let queue = DispatchQueue(
    label: "com.yyzl.music.audioSession",
    qos: .userInitiated
  )
  private var channel: FlutterMethodChannel?
  private var currentProfile = "none"
  private var lastError: String?

  private init() {}

  func register(messenger: FlutterBinaryMessenger) {
    guard channel == nil else { return }
    let channel = FlutterMethodChannel(
      name: "com.yyzl.music/audio_session",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    self.channel = channel
  }

  func applyPlayback() throws {
    try apply(profile: "playback")
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "apply":
      guard
        let args = call.arguments as? [String: Any],
        let profile = args["profile"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing profile", details: nil))
        return
      }
      queue.async { [weak self] in
        guard let self else { return }
        do {
          try self.apply(profile: profile)
          DispatchQueue.main.async { result(nil) }
        } catch {
          self.lastError = "\(error)"
          DispatchQueue.main.async {
            result(FlutterError(code: "session_apply_failed", message: "\(error)", details: nil))
          }
        }
      }
    case "diagnostics":
      let session = AVAudioSession.sharedInstance()
      result([
        "profile": currentProfile,
        "category": session.category.rawValue,
        "mode": session.mode.rawValue,
        "sampleRate": session.sampleRate,
        "ioBufferDuration": session.ioBufferDuration,
        "route": session.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ","),
        "lastError": lastError ?? "",
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func apply(profile: String) throws {
    let session = AVAudioSession.sharedInstance()
    switch profile {
    case "record":
      try session.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
      )
    case "measurement":
      try session.setCategory(
        .playAndRecord,
        mode: .measurement,
        options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
      )
    default:
      // 与 Dart NativePlaybackAudioSession 一致：允许 just_audio 与可视化探针引擎并行。
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }
    try session.setPreferredSampleRate(44_100)
    try session.setPreferredIOBufferDuration(0.005)
    try session.setActive(true)
    currentProfile = profile
    lastError = nil
  }
}
