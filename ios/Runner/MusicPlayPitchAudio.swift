import AVFoundation
import Flutter

final class MusicPlayPitchAudio {
  private let channel: FlutterMethodChannel
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let pitch = AVAudioUnitTimePitch()
  private let queue = DispatchQueue(
    label: "com.yyzl.music.musicPlayPitch.audio",
    qos: .userInitiated
  )

  private var graphBuilt = false
  private var audioFile: AVAudioFile?
  private var sourceURL: URL?
  private var currentFrame: AVAudioFramePosition = 0
  private var scheduledFromFrame: AVAudioFramePosition = 0
  private var generation: UInt64 = 0
  private var completed = false
  private var outputMuted = false
  private var volume: Float = 1.0

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.yyzl.music/music_play_pitch",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "open":
      guard
        let args = call.arguments as? [String: Any],
        let url = args["url"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing url", details: nil))
        return
      }
      let play = (args["play"] as? NSNumber)?.boolValue ?? false
      open(urlString: url, play: play, result: result)
    case "play":
      queue.async { [weak self] in self?.play(result: result) }
    case "pause":
      queue.async { [weak self] in self?.pause(result: result) }
    case "stop":
      queue.async { [weak self] in self?.stop(result: result) }
    case "seek":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "Missing seek args", details: nil))
        return
      }
      let positionMs = (args["positionMs"] as? NSNumber)?.int64Value ?? 0
      let restore = (args["restoreAudible"] as? NSNumber)?.boolValue ?? true
      queue.async { [weak self] in
        self?.seek(positionMs: positionMs, restoreAudible: restore, result: result)
      }
    case "setPitch":
      guard
        let args = call.arguments as? [String: Any],
        let value = args["pitch"] as? NSNumber
      else {
        result(FlutterError(code: "bad_args", message: "Missing pitch", details: nil))
        return
      }
      queue.async { [weak self] in
        self?.setPitch(value.doubleValue, result: result)
      }
    case "setRate":
      guard
        let args = call.arguments as? [String: Any],
        let value = args["rate"] as? NSNumber
      else {
        result(FlutterError(code: "bad_args", message: "Missing rate", details: nil))
        return
      }
      queue.async { [weak self] in
        self?.pitch.rate = max(0.25, min(4.0, value.floatValue))
        self?.reply(result, nil)
      }
    case "setVolume":
      guard
        let args = call.arguments as? [String: Any],
        let value = args["volume"] as? NSNumber
      else {
        result(FlutterError(code: "bad_args", message: "Missing volume", details: nil))
        return
      }
      queue.async { [weak self] in
        guard let self else { return }
        self.volume = max(0, min(1, value.floatValue / 100.0))
        if !self.outputMuted {
          self.engine.mainMixerNode.outputVolume = self.volume
        }
        self.reply(result, nil)
      }
    case "setMuted":
      guard
        let args = call.arguments as? [String: Any],
        let muted = args["muted"] as? NSNumber
      else {
        result(FlutterError(code: "bad_args", message: "Missing muted", details: nil))
        return
      }
      queue.async { [weak self] in
        guard let self else { return }
        self.setMutedLocked(muted.boolValue)
        self.reply(result, nil)
      }
    case "state":
      queue.async { [weak self] in self?.state(result: result) }
    case "dispose":
      queue.async { [weak self] in self?.dispose(result: result) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func open(urlString: String, play: Bool, result: @escaping FlutterResult) {
    resolveURL(urlString) { [weak self] resolved in
      guard let self else { return }
      switch resolved {
      case .failure(let error):
        self.reply(
          result,
          FlutterError(code: "open_failed", message: "\(error)", details: nil)
        )
      case .success(let url):
        self.queue.async {
          do {
            try AppAudioSessionCoordinator.shared.applyPlayback()
            try self.ensureGraph()
            self.audioFile = try AVAudioFile(forReading: url)
            self.sourceURL = url
            self.currentFrame = 0
            self.scheduledFromFrame = 0
            self.completed = false
            self.generation &+= 1
            self.player.stop()
            try self.scheduleFromCurrentFrame()
            if play {
              self.player.play()
              self.fadeMutedLocked(false)
            }
            self.reply(result, nil)
          } catch {
            self.reply(
              result,
              FlutterError(code: "open_failed", message: "\(error)", details: nil)
            )
          }
        }
      }
    }
  }

  private func play(result: @escaping FlutterResult) {
    do {
      try AppAudioSessionCoordinator.shared.applyPlayback()
      try ensureGraph()
      if completed {
        currentFrame = 0
        completed = false
        player.stop()
        try scheduleFromCurrentFrame()
      }
      if !player.isPlaying {
        player.play()
      }
      fadeMutedLocked(false)
      reply(result, nil)
    } catch {
      reply(result, FlutterError(code: "play_failed", message: "\(error)", details: nil))
    }
  }

  private func pause(result: @escaping FlutterResult) {
    captureCurrentFrame()
    fadeMutedLocked(true)
    player.pause()
    reply(result, nil)
  }

  private func stop(result: @escaping FlutterResult) {
    fadeMutedLocked(true)
    player.stop()
    currentFrame = 0
    scheduledFromFrame = 0
    completed = false
    generation &+= 1
    reply(result, nil)
  }

  private func seek(
    positionMs: Int64,
    restoreAudible: Bool,
    result: @escaping FlutterResult
  ) {
    do {
      guard let file = audioFile else {
        reply(result, nil)
        return
      }
      let wasPlaying = player.isPlaying
      fadeMutedLocked(true)
      let sampleRate = file.processingFormat.sampleRate
      let frame = AVAudioFramePosition(
        max(0, min(Double(file.length), Double(positionMs) * sampleRate / 1000.0))
      )
      currentFrame = frame
      completed = false
      generation &+= 1
      player.stop()
      try scheduleFromCurrentFrame()
      if wasPlaying {
        player.play()
      }
      if restoreAudible {
        fadeMutedLocked(false)
      }
      reply(result, nil)
    } catch {
      reply(result, FlutterError(code: "seek_failed", message: "\(error)", details: nil))
    }
  }

  private func setPitch(_ ratio: Double, result: @escaping FlutterResult) {
    let cents = 1200.0 * log2(max(0.25, min(4.0, ratio)))
    pitch.pitch = Float(max(-2400, min(2400, cents)))
    reply(result, nil)
  }

  private func state(result: @escaping FlutterResult) {
    captureCurrentFrame()
    let durationMs: Int64
    if let file = audioFile {
      durationMs = Int64(Double(file.length) / file.processingFormat.sampleRate * 1000.0)
    } else {
      durationMs = 0
    }
    let positionMs: Int64
    if let file = audioFile {
      positionMs = Int64(Double(currentFrame) / file.processingFormat.sampleRate * 1000.0)
    } else {
      positionMs = 0
    }
    reply(result, [
      "positionMs": max(0, min(positionMs, durationMs)),
      "durationMs": durationMs,
      "playing": player.isPlaying && !completed,
      "completed": completed,
    ])
  }

  private func dispose(result: @escaping FlutterResult) {
    generation &+= 1
    player.stop()
    if engine.isRunning {
      engine.stop()
    }
    engine.reset()
    if engine.attachedNodes.contains(player) {
      engine.disconnectNodeOutput(player)
      engine.detach(player)
    }
    if engine.attachedNodes.contains(pitch) {
      engine.disconnectNodeOutput(pitch)
      engine.detach(pitch)
    }
    graphBuilt = false
    audioFile = nil
    sourceURL = nil
    currentFrame = 0
    scheduledFromFrame = 0
    completed = false
    reply(result, nil)
  }

  private func ensureGraph() throws {
    if !graphBuilt {
      if !engine.attachedNodes.contains(player) {
        engine.attach(player)
      }
      if !engine.attachedNodes.contains(pitch) {
        engine.attach(pitch)
      }
      engine.connect(player, to: pitch, format: nil)
      engine.connect(pitch, to: engine.mainMixerNode, format: nil)
      graphBuilt = true
    }
    if !engine.isRunning {
      engine.prepare()
      try engine.start()
    }
    engine.mainMixerNode.outputVolume = outputMuted ? 0 : volume
  }

  private func scheduleFromCurrentFrame() throws {
    guard let file = audioFile else { return }
    let clamped = max(0, min(currentFrame, file.length))
    currentFrame = clamped
    scheduledFromFrame = clamped
    let remaining = file.length - clamped
    if remaining <= 0 {
      completed = true
      return
    }
    let seq = generation
    player.scheduleSegment(
      file,
      startingFrame: clamped,
      frameCount: AVAudioFrameCount(remaining),
      at: nil
    ) { [weak self] in
      guard let self else { return }
      self.queue.async {
        guard seq == self.generation else { return }
        self.currentFrame = self.audioFile?.length ?? self.currentFrame
        self.completed = true
      }
    }
  }

  private func canQueryPlayerTiming() -> Bool {
    engine.isRunning && player.engine != nil
  }

  private func captureCurrentFrame() {
    guard canQueryPlayerTiming(),
          let nodeTime = player.lastRenderTime,
          let playerTime = player.playerTime(forNodeTime: nodeTime)
    else { return }
    let next = scheduledFromFrame + AVAudioFramePosition(playerTime.sampleTime)
    if let file = audioFile {
      currentFrame = max(0, min(next, file.length))
    } else {
      currentFrame = max(0, next)
    }
  }

  private func setMutedLocked(_ muted: Bool) {
    outputMuted = muted
    guard engine.isRunning else { return }
    engine.mainMixerNode.outputVolume = muted ? 0 : volume
  }

  private func fadeMutedLocked(_ muted: Bool) {
    outputMuted = muted
    guard engine.isRunning else { return }
    let from = engine.mainMixerNode.outputVolume
    let to: Float = muted ? 0 : volume
    let steps = 3
    if abs(from - to) < 0.001 {
      engine.mainMixerNode.outputVolume = to
      return
    }
    for step in 1...steps {
      let t = Float(step) / Float(steps)
      engine.mainMixerNode.outputVolume = from + (to - from) * t
      if step < steps {
        Thread.sleep(forTimeInterval: 0.006)
      }
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
          completion(.failure(MusicPlayPitchAudioError.downloadFailed))
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
    let url = URL(fileURLWithPath: urlString)
    completion(.success(url))
  }

  private func cachedURL(for url: URL) -> URL {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let ext = url.pathExtension.isEmpty ? "audio" : url.pathExtension
    let hash = UInt(bitPattern: url.absoluteString.hashValue)
    let name = "music_play_pitch_\(hash).\(ext)"
    return caches.appendingPathComponent(name)
  }

  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async {
      result(value)
    }
  }
}

private enum MusicPlayPitchAudioError: Error {
  case downloadFailed
}
