import AVFoundation
import Flutter

/// 与主播放器并行运行的静音探针引擎：从 PCM tap 提取 46 段 RMS 能量，
/// 经 EventChannel 推送给 Flutter 可视化条（不接管主输出）。
final class MusicPlayAudioVisualizer: NSObject {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let queue = DispatchQueue(label: "com.yyzl.music.musicPlayVisualizer")

  private var audioFile: AVAudioFile?
  private var attachedUrl: String?
  private var currentFrame: AVAudioFramePosition = 0
  private var isPlaying = false
  private var tapInstalled = false
  private var lastSyncedPositionMs: Int64 = -1
  private var lastSyncedPlaying = false

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "com.yyzl.music/music_play_visualizer",
      binaryMessenger: messenger
    )
    eventChannel = FlutterEventChannel(
      name: "com.yyzl.music/music_play_visualizer/bands",
      binaryMessenger: messenger
    )
    super.init()
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    eventChannel.setStreamHandler(self)
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "attach":
      guard let args = call.arguments as? [String: Any],
            let url = args["url"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing url", details: nil))
        return
      }
      queue.async { [weak self] in
        self?.attach(urlString: url) {
          DispatchQueue.main.async { result(nil) }
        }
      }
    case "updateAndroidSession":
      result(nil)
    case "syncTransport":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "Missing args", details: nil))
        return
      }
      let playing = (args["playing"] as? NSNumber)?.boolValue ?? false
      let positionMs = (args["positionMs"] as? NSNumber)?.int64Value ?? 0
      queue.async { [weak self] in
        self?.syncTransport(playing: playing, positionMs: positionMs)
        DispatchQueue.main.async { result(nil) }
      }
    case "detach":
      queue.async { [weak self] in
        self?.detach()
        DispatchQueue.main.async { result(nil) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func attach(urlString: String, completion: @escaping () -> Void) {
    detachInternal()
    attachedUrl = urlString
    resolveURL(urlString) { [weak self] resolved in
      guard let self else {
        completion()
        return
      }
      self.queue.async {
        switch resolved {
        case .failure:
          self.emitIdle()
        case .success(let localUrl):
          do {
            try AppAudioSessionCoordinator.shared.applyPlayback()
            self.audioFile = try AVAudioFile(forReading: localUrl)
            try self.configureGraph()
          } catch {
            self.emitIdle()
          }
        }
        completion()
      }
    }
  }

  private func configureGraph() throws {
    removeTapIfNeeded()
    player.stop()
    if engine.isRunning {
      engine.stop()
    }
    engine.reset()
    if engine.attachedNodes.contains(player) {
      engine.detach(player)
    }
    engine.attach(player)
    let mixer = engine.mainMixerNode
    mixer.outputVolume = 0
    guard let format = audioFile?.processingFormat else {
      throw MusicPlayAudioVisualizerError.missingFormat
    }
    engine.connect(player, to: mixer, format: format)
    try ensureEngineRunning()
    installTapIfNeeded()
  }

  private func ensureEngineRunning() throws {
    if !engine.isRunning {
      engine.prepare()
      try engine.start()
    }
  }

  private func installTapIfNeeded() {
    guard !tapInstalled, let format = audioFile?.processingFormat else { return }
    player.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      guard let self, self.isPlaying else { return }
      let bands = self.process(buffer: buffer)
      guard !bands.isEmpty else { return }
      DispatchQueue.main.async {
        self.eventSink?(bands)
      }
    }
    tapInstalled = true
  }

  private func removeTapIfNeeded() {
    guard tapInstalled else { return }
    player.removeTap(onBus: 0)
    tapInstalled = false
  }

  private func syncTransport(playing: Bool, positionMs: Int64) {
    guard audioFile != nil else { return }
    let wasPlaying = isPlaying
    isPlaying = playing
    let sampleRate = audioFile?.processingFormat.sampleRate ?? 44100

    if playing {
      do {
        try AppAudioSessionCoordinator.shared.applyPlayback()
        let driftMs = abs(positionMs - lastSyncedPositionMs)
        let needsReschedule = !wasPlaying || !lastSyncedPlaying || driftMs > 400
        if needsReschedule {
          currentFrame = AVAudioFramePosition(Double(positionMs) / 1000.0 * sampleRate)
          scheduleFromCurrentFrame()
          lastSyncedPositionMs = positionMs
        }
        try ensureEngineRunning()
        if !player.isPlaying {
          player.play()
        }
      } catch {
        isPlaying = false
      }
    } else {
      player.pause()
      lastSyncedPositionMs = positionMs
    }
    lastSyncedPlaying = playing
  }

  private func scheduleFromCurrentFrame() {
    guard let file = audioFile else { return }
    player.stop()
    let clamped = max(0, min(currentFrame, file.length))
    currentFrame = clamped
    let frameCount = AVAudioFrameCount(max(0, file.length - clamped))
    if frameCount <= 0 {
      emitIdle()
      return
    }
    player.schedule(
      segment: AVAudioSegment(
        file: file,
        startingFrame: clamped,
        frameCount: frameCount,
        loopCount: 0
      ),
      at: nil
    )
  }

  private func process(buffer: AVAudioPCMBuffer) -> [Double] {
    guard isPlaying else { return [] }
    let frames = Int(buffer.frameLength)
    guard frames >= 128 else { return [] }

    let n = min(frames, 1024)
    let bands = 46
    let sampleRate = buffer.format.sampleRate
    let floatChannel = buffer.floatChannelData?[0]
    let int16Channel = buffer.int16ChannelData?[0]
    guard floatChannel != nil || int16Channel != nil else { return [] }

    var result = [Double](repeating: 0, count: bands)
    for b in 0..<bands {
      let k = melBinIndex(b: b, bands: bands, n: n, sampleRate: sampleRate)
      let omega = 2.0 * Double.pi * Double(k) / Double(n)
      let coeff = 2.0 * cos(omega)
      var s0 = 0.0
      var s1 = 0.0
      var s2 = 0.0
      for i in 0..<n {
        let sample: Double
        if let floatChannel {
          sample = Double(floatChannel[i])
        } else if let int16Channel {
          sample = Double(int16Channel[i]) / 32768.0
        } else {
          sample = 0
        }
        s0 = sample + coeff * s1 - s2
        s2 = s1
        s1 = s0
      }
      let power = s1 * s1 + s2 * s2 - coeff * s1 * s2
      let magnitude = sqrt(max(0, power)) / Double(n)
      // 对齐 Android Visualizer / Web Analyser 的展示量级。
      result[b] = min(1.0, magnitude * 96.0)
    }
    return result
  }

  private func melBinIndex(b: Int, bands: Int, n: Int, sampleRate: Double) -> Int {
    let minHz = 50.0
    let maxHz = 14000.0
    let minMel = hzToMel(minHz)
    let maxMel = hzToMel(maxHz)
    let mel = minMel + (maxMel - minMel) * Double(b) / Double(bands)
    let hz = melToHz(mel)
    let k = Int(hz / sampleRate * Double(n))
    return max(1, min(n / 2 - 1, k))
  }

  private func hzToMel(_ hz: Double) -> Double {
    2595.0 * log10(1.0 + hz / 700.0)
  }

  private func melToHz(_ mel: Double) -> Double {
    700.0 * (pow(10.0, mel / 2595.0) - 1.0)
  }

  private func detach() {
    detachInternal()
    emitIdle()
  }

  private func detachInternal() {
    isPlaying = false
    lastSyncedPlaying = false
    lastSyncedPositionMs = -1
    attachedUrl = nil
    player.stop()
    removeTapIfNeeded()
    if engine.isRunning {
      engine.stop()
    }
    audioFile = nil
    currentFrame = 0
  }

  private func emitIdle() {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?([])
    }
  }

  private func resolveURL(
    _ urlString: String,
    completion: @escaping (Result<URL, Error>) -> Void
  ) {
    if let url = URL(string: urlString), url.isFileURL {
      completion(.success(url))
      return
    }
    if let url = URL(string: urlString),
       url.scheme == "http" || url.scheme == "https" {
      let cached = cachedURL(for: url)
      if FileManager.default.fileExists(atPath: cached.path) {
        completion(.success(cached))
        return
      }
      URLSession.shared.downloadTask(with: url) { temp, _, error in
        if let error {
          completion(.failure(error))
          return
        }
        guard let temp else {
          completion(.failure(MusicPlayAudioVisualizerError.downloadFailed))
          return
        }
        do {
          try? FileManager.default.removeItem(at: cached)
          try FileManager.default.moveItem(at: temp, to: cached)
          completion(.success(cached))
        } catch {
          completion(.failure(error))
        }
      }.resume()
      return
    }
    completion(.success(URL(fileURLWithPath: urlString)))
  }

  private func cachedURL(for url: URL) -> URL {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let ext = url.pathExtension.isEmpty ? "audio" : url.pathExtension
    let hash = UInt(bitPattern: url.absoluteString.hashValue)
    let name = "music_play_visualizer_\(hash).\(ext)"
    return caches.appendingPathComponent(name)
  }
}

extension MusicPlayAudioVisualizer: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

private enum MusicPlayAudioVisualizerError: Error {
  case downloadFailed
  case missingFormat
}

private struct AVAudioSegment {
  let file: AVAudioFile
  let startingFrame: AVAudioFramePosition
  let frameCount: AVAudioFrameCount
  let loopCount: Int
}

private extension AVAudioPlayerNode {
  func schedule(segment: AVAudioSegment, at when: AVAudioTime?) {
    scheduleSegment(
      segment.file,
      startingFrame: segment.startingFrame,
      frameCount: segment.frameCount,
      at: when,
      completionHandler: nil
    )
  }
}
