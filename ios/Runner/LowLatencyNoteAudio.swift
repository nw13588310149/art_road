import AVFoundation
import Flutter
import UIKit

/// 低延迟短音播放（iPad 虚拟钢琴 / 听写 / 智能视唱伴奏）—— 业界专业方案重构版。
///
/// 架构：**单个常驻 AVAudioEngine + 固定声部池 + 静态音频图**，活整个 App 生命周期。
/// - `prepare`：一次性建好 N 个常驻 `AVAudioPlayerNode`，全部 attach + connect 到主
///   混音器并进入 playing-idle；采样在后台串行解码进内存常驻。
/// - 播放一个音 = 在空闲节点 `scheduleBuffer`，**不** attach/detach/connect，
///   **不** start/stop 引擎，**不**碰 AVAudioSession。
/// - 引擎只在系统事件后重启（**不重建图**）：
///   * `AVAudioEngineConfigurationChange`（路由 / 采样率 / 类别切换）→ 重启 + 续接节点；
///   * 中断结束（`shouldResume`）→ 重启；
///   * `mediaServicesWereReset`（CoreAudio 整体重启，节点全废）→ 唯一一种整图重建。
///
/// **会话所有权完全归 Dart 侧 `NativePlaybackAudioSession`**：它全程只 `setActive(true)`、
/// 永不 `setActive(false)`，导航期间只在活动会话上切类别 / 模式。本类绝不 `setCategory`
/// / `setActive(false)`，仅做幂等的 `setActive(true)` 兜底，从根上杜绝
/// 「`setActive(false)` 掐断 IO → 引擎 isRunning 陈旧为 true → 假运行无声」的僵尸态。
final class LowLatencyNoteAudio {
  private let channel: FlutterMethodChannel
  private let engine = AVAudioEngine()
  /// Every AVAudioEngine/node operation is serialized here. Decoding may run
  /// off-queue, but decoded buffers are published back onto this queue.
  private let audioQueue = DispatchQueue(
    label: "com.yyzl.music.lowLatencyNotes.audio",
    qos: .userInteractive
  )
  private let decodeQueue = DispatchQueue(
    label: "com.yyzl.music.lowLatencyNotes.decode",
    qos: .utility
  )

  private var assetByKey: [String: String] = [:]
  private var buffersByKey: [String: AVAudioPCMBuffer] = [:]
  /// 解码时预加包络的播放缓冲，发声热路径零拷贝。
  private var playbackBuffersByKey: [String: AVAudioPCMBuffer] = [:]
  private var voices: [Voice] = []
  private var prepared = false
  private var graphBuilt = false
  /// 仅 `mediaServicesWereReset` 时置位：节点 / 引擎彻底失效，须整图重建。
  private var engineNeedsReset = false
  /// 是否处于音频中断中：中断期间绝不尝试启动引擎（系统不允许）。
  private var interrupted = false
  private var sessionObservers: [NSObjectProtocol] = []
  private var playSequence: UInt64 = 0
  private var fadeGeneration = 0
  /// 会话切换 / stopAll 时递增；早于此次序号的 `play` 任务直接丢弃，避免排队迟播。
  private var operationGeneration: UInt64 = 0

  /// 声部池大小：钢琴十指 + 延音绰绰有余，超出才会触发偷取。
  private let poolSize = 24

  /// 主混音输出电平；响度交由系统音量键，软件层不做衰减。
  private let masterOutputLevel: Float = 1.0

  /// 采样尾部淡出时长，确保 buffer 末尾归零，消除「播完瞬间」的爆音/电流声。
  private let tailFadeMs: Double = 5.0

  /// 起音淡入时长，消除采样起点非零造成的咔哒（极短，不影响触感）。
  private let attackFadeMs: Double = 1.0

  /// 所有采样统一为该格式，保证整条图 connect 格式恒定，运行期不改格式。
  private let standardFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 44100,
    channels: 2,
    interleaved: false
  )!

  /// 常驻发声节点。
  private final class Voice {
    let player = AVAudioPlayerNode()
    var busy = false
    var isMetronome = false
    var sequence: UInt64 = 0
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.yyzl.music/low_latency_notes",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    registerSessionObservers()
  }

  deinit {
    unregisterSessionObservers()
  }

  // MARK: - Flutter channel

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "prepare":
      guard
        let args = call.arguments as? [String: Any],
        let assets = args["assets"] as? [String: String]
      else {
        result(FlutterError(code: "bad_args", message: "Missing assets", details: nil))
        return
      }
      prepare(assets: assets, result: result)
    case "play":
      guard
        let args = call.arguments as? [String: Any],
        let key = args["key"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "Missing key", details: nil))
        return
      }
      let volume = (args["volume"] as? NSNumber)?.floatValue ?? 1.0
      let metronome = (args["metronome"] as? NSNumber)?.boolValue ?? false
      let waitUntilFinished = (args["waitUntilFinished"] as? NSNumber)?.boolValue ?? false
      play(
        key: key,
        volume: volume,
        metronome: metronome,
        waitUntilFinished: waitUntilFinished,
        result: result
      )
    case "reclaimEngine", "pingEngine":
      pingEngine(result: result)
    case "stopMetronome":
      audioQueue.async { [weak self] in self?.stopVoices(metronomeOnly: true, fadeMs: 35) }
      result(nil)
    case "stopAll":
      audioQueue.async { [weak self] in
        guard let self = self else { return }
        self.operationGeneration &+= 1
        self.stopVoices(metronomeOnly: false, fadeMs: 90)
      }
      result(nil)
    case "dispose":
      // App 级短音频资源：页面离开只停声，不销毁图（见 Dart dispose 注释）。
      audioQueue.async { [weak self] in self?.stopVoices(metronomeOnly: false, fadeMs: 90) }
      result(nil)
    case "diagnostics":
      diagnostics(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 屏幕诊断快照

  /// 返回原生引擎 / 会话的实时状态，供 Dart 侧屏幕诊断面板显示。
  private func diagnostics(result: @escaping FlutterResult) {
    // 同步快照：不排队 controlQueue，避免 prepare 占队时诊断也 6s 超时。
    let session = AVAudioSession.sharedInstance()
    let categoryOptions = session.categoryOptions
    let snapshot: [String: Any] = [
      "prepared": prepared,
      "graphBuilt": graphBuilt,
      "engineRunning": engine.isRunning,
      "engineNeedsReset": engineNeedsReset,
      "interrupted": interrupted,
      "voiceCount": voices.count,
      "busyVoices": activeVoiceCount(),
      "decodedBuffers": buffersByKey.count,
      "registeredAssets": assetByKey.count,
      "outputVolume": engine.mainMixerNode.outputVolume,
      "sessionCategory": session.category.rawValue,
      "sessionMode": session.mode.rawValue,
      "sessionOptions": Int(categoryOptions.rawValue),
      "outputVolumeSystem": session.outputVolume,
      "otherAudioPlaying": session.isOtherAudioPlaying,
      "outputRoute": session.currentRoute.outputs.map { $0.portType.rawValue }
        .joined(separator: ","),
    ]
    result(snapshot)
  }

  // MARK: - 系统事件观察者（重启而非重建）

  private func registerSessionObservers() {
    let center = NotificationCenter.default
    sessionObservers = [
      center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: nil,
        using: { [weak self] notification in
          self?.handleInterruption(notification)
        }
      ),
      center.addObserver(
        forName: AVAudioSession.mediaServicesWereResetNotification,
        object: nil,
        queue: nil,
        using: { [weak self] _ in
          // CoreAudio 整体重启：节点 / 引擎全废，标记整图重建。
          self?.audioQueue.async {
            self?.engineNeedsReset = true
          }
        }
      ),
      center.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: nil,
        using: { [weak self] _ in
          // 插拔耳机 / 蓝牙：引擎可能被系统停掉，重启即可（连接格式恒定，无需重连）。
          self?.restartEngineAfterSystemChange()
        }
      ),
      center.addObserver(
        forName: .AVAudioEngineConfigurationChange,
        object: engine,
        queue: nil,
        using: { [weak self] _ in
          // 设备 / 采样率 / 会话类别切换后引擎会停止；仅重启 + 续接节点。
          self?.restartEngineAfterSystemChange()
        }
      ),
    ]
  }

  private func unregisterSessionObservers() {
    let center = NotificationCenter.default
    for token in sessionObservers { center.removeObserver(token) }
    sessionObservers.removeAll()
  }

  private func handleInterruption(_ notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType)
    else { return }

    switch type {
    case .began:
      audioQueue.async { [weak self] in self?.interrupted = true }
    case .ended:
      let shouldResume: Bool
      if let rawOptions = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
        shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
          .contains(.shouldResume)
      } else {
        shouldResume = true
      }
      audioQueue.async { [weak self] in
        guard let self = self else { return }
        self.interrupted = false
        guard shouldResume else { return }
        self.restartEngineLocked()
      }
    @unknown default:
      break
    }
  }

  /// 系统侧（路由 / 配置变化）触发的重启：派发到串行队列后重启常驻引擎。
  private func restartEngineAfterSystemChange() {
    audioQueue.async { [weak self] in self?.restartEngineLocked() }
  }

  /// 在串行队列内：确保常驻引擎处于运行态并续接所有节点（不重建图）。
  private func restartEngineLocked() {
    guard !interrupted, prepared, graphBuilt else { return }
    do {
      try startEngineAndResumeNodes()
    } catch {
      debugPrint("LowLatencyNoteAudio restart after system change failed: \(error)")
    }
  }

  /// Dart [reconcilePlayback] 后调用：仅确认引擎在运行态。
  /// **不**递增 operationGeneration，避免丢弃已排队的 play 任务（旧 reclaim 根因）。
  private func pingEngine(result: @escaping FlutterResult) {
    result(nil)
    audioQueue.async { [weak self] in
      guard let self = self else { return }
      do {
        if self.prepared {
          try self.ensureEngineRunning()
        }
      } catch {
        debugPrint("LowLatencyNoteAudio ping/ensureRunning failed: \(error)")
      }
    }
  }

  // MARK: - Prepare / decode

  private func prepare(assets: [String: String], result: @escaping FlutterResult) {
    audioQueue.async { [weak self] in
      self?.prepareOnAudioQueue(assets: assets, result: result)
    }
  }

  private func prepareOnAudioQueue(
    assets: [String: String],
    result: @escaping FlutterResult
  ) {
    // 立即回 Dart：避免 ensureEngineRunning / 解码占满串行队列导致 6s prepare 超时。
    var decodeBatch: [(String, String)] = []
    var prepareError: Error?
    for (key, asset) in assets {
      guard resolveFlutterAsset(asset) != nil else {
        prepareError = LowLatencyNoteAudioError.assetNotFound(asset)
        break
      }
      assetByKey[key] = asset
      if playbackBuffersByKey[key] == nil {
        decodeBatch.append((key, asset))
      }
    }
    if let prepareError {
      result(FlutterError(code: "prepare_failed", message: "\(prepareError)", details: nil))
      return
    }
    prepared = true

    audioQueue.async { [weak self] in
      guard let self = self else { return }
      do {
        try self.ensureEngineRunning()
        self.scheduleBackgroundDecode(decodeBatch) {
          DispatchQueue.main.async { result(["loaded": assets.count]) }
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "prepare_failed", message: "\(error)", details: nil))
        }
      }
    }
  }

  private func scheduleBackgroundDecode(
    _ batch: [(String, String)],
    completion: @escaping () -> Void
  ) {
    guard !batch.isEmpty else {
      completion()
      return
    }
    let group = DispatchGroup()
    for (key, asset) in batch {
      group.enter()
      decodeQueue.async { [weak self] in
        guard let self = self else {
          group.leave()
          return
        }
        do {
          guard let url = self.resolveFlutterAsset(asset) else {
            group.leave()
            return
          }
          let buffer = try self.decodeAsset(url: url)
          self.audioQueue.async { [weak self] in
            guard let self = self else {
              group.leave()
              return
            }
            guard self.assetByKey[key] == asset else {
              group.leave()
              return
            }
            if self.buffersByKey[key] == nil {
              self.buffersByKey[key] = buffer
              if let playback = self.copyBufferWithEnvelope(buffer) {
                self.playbackBuffersByKey[key] = playback
              }
            }
            group.leave()
          }
        } catch {
          debugPrint("LowLatencyNoteAudio background decode failed for \(key): \(error)")
          group.leave()
        }
      }
    }
    group.notify(queue: audioQueue, execute: completion)
  }

  // MARK: - Play

  private func play(
    key: String,
    volume: Float,
    metronome: Bool,
    waitUntilFinished: Bool,
    result: @escaping FlutterResult
  ) {
    if !waitUntilFinished {
      result(nil)
    }
    audioQueue.async { [weak self] in
      guard let self = self else { return }
      let generation = self.operationGeneration
      do {
        let buffer = try self.playbackBufferForKey(key)

        if !self.graphBuilt || !self.engine.isRunning || self.engineNeedsReset {
          try self.ensureEngineRunning()
        }
        guard generation == self.operationGeneration else {
          if waitUntilFinished {
            DispatchQueue.main.async { result(nil) }
          }
          return
        }

        let voice = self.acquireVoice()
        voice.busy = true
        voice.isMetronome = metronome
        self.playSequence &+= 1
        let seq = self.playSequence
        voice.sequence = seq
        voice.player.volume = max(0, min(1, volume))

        // 听写 waitUntilFinished 须在播完后才回 Dart，但不能 semaphore.wait 占住串行队列，
        // 否则 musicPlay 钢琴 tryPlay 会排队数秒才响。
        var waitReplySent = false
        let sendWaitReply: () -> Void = {
          if waitReplySent { return }
          waitReplySent = true
          DispatchQueue.main.async { result(nil) }
        }

        try self.scheduleBufferOnVoice(
          voice,
          buffer: buffer,
          seq: seq,
          waitUntilFinished: waitUntilFinished,
          sendWaitReply: sendWaitReply
        )

        // 兜底：若 playedBack 回调未触发（极少数情况），按采样时长 + 余量释放 busy，
        // 避免 busy 卡死导致 activeVoiceCount 永不归零、引擎无法在会话切换后重建。
        let durationMs = max(
          400,
          Int(Double(buffer.frameLength) / buffer.format.sampleRate * 1000) + 200
        )
        self.audioQueue.asyncAfter(deadline: .now() + .milliseconds(durationMs)) {
          [weak voice] in
          guard let voice = voice, voice.sequence == seq, voice.busy else { return }
          voice.busy = false
          if waitUntilFinished {
            sendWaitReply()
          }
        }

      } catch {
        self.engineNeedsReset = true
        guard generation == self.operationGeneration else {
          if waitUntilFinished {
            DispatchQueue.main.async { result(nil) }
          }
          return
        }
        if waitUntilFinished {
          DispatchQueue.main.async {
            result(FlutterError(code: "play_failed", message: "\(error)", details: nil))
          }
        } else {
          debugPrint("LowLatencyNoteAudio play failed (fire-and-forget): \(error)")
        }
      }
    }
  }

  /// 在节点上排程缓冲。须先 `play()` 再 `scheduleBuffer`；mpv 切会话后
  /// `isPlaying` 可能陈旧，遇 IO cycle 错误时强制重启引擎并重试一次。
  private func scheduleBufferOnVoice(
    _ voice: Voice,
    buffer: AVAudioPCMBuffer,
    seq: UInt64,
    waitUntilFinished: Bool,
    sendWaitReply: @escaping () -> Void
  ) throws {
    do {
      try self.playAndSchedule(voice: voice, buffer: buffer, seq: seq,
                               waitUntilFinished: waitUntilFinished,
                               sendWaitReply: sendWaitReply)
    } catch {
      let msg = (error as NSError).localizedDescription
      if msg.contains("IO cycle") {
        try self.startEngineAndResumeNodes()
        try self.playAndSchedule(voice: voice, buffer: buffer, seq: seq,
                                 waitUntilFinished: waitUntilFinished,
                                 sendWaitReply: sendWaitReply)
        return
      }
      throw error
    }
  }

  private func playAndSchedule(
    voice: Voice,
    buffer: AVAudioPCMBuffer,
    seq: UInt64,
    waitUntilFinished: Bool,
    sendWaitReply: @escaping () -> Void
  ) throws {
    // AVAudioPlayerNode 要求引擎已跑且节点已 play，否则抛 IO cycle 异常。
    if !voice.player.isPlaying {
      try LowLatencyNoteAudioSafePlay.play(voice.player)
    }
    try LowLatencyNoteAudioSafePlay.scheduleBuffer(
      buffer,
      on: voice.player,
      playedBackHandler: { [weak self, weak voice] in
        self?.audioQueue.async {
          guard let voice = voice, voice.sequence == seq else { return }
          voice.busy = false
          if waitUntilFinished {
            sendWaitReply()
          }
        }
      }
    )
  }

  private func playbackBufferForKey(_ key: String) throws -> AVAudioPCMBuffer {
    if let cached = playbackBuffersByKey[key] {
      return cached
    }
    let source = try rawBufferForKey(key)
    guard let playback = copyBufferWithEnvelope(source) else {
      throw LowLatencyNoteAudioError.decodeFailed(key)
    }
    playbackBuffersByKey[key] = playback
    return playback
  }

  private func rawBufferForKey(_ key: String) throws -> AVAudioPCMBuffer {
    if let cached = buffersByKey[key] {
      return cached
    }
    guard let asset = assetByKey[key] else {
      throw LowLatencyNoteAudioError.bufferNotPrepared(key)
    }
    guard let url = resolveFlutterAsset(asset) else {
      throw LowLatencyNoteAudioError.assetNotFound(asset)
    }
    let buffer = try decodeAsset(url: url)
    buffersByKey[key] = buffer
    if let playback = copyBufferWithEnvelope(buffer) {
      playbackBuffersByKey[key] = playback
    }
    return buffer
  }

  /// 取一个发声节点：优先空闲；全忙时偷取序号最旧的非节拍器声部（极罕见）。
  private func acquireVoice() -> Voice {
    if let free = voices.first(where: { !$0.busy }) {
      return free
    }
    let victim =
      voices.min(by: { $0.sequence < $1.sequence }) ?? voices[0]
    // 偷取前先 stop 旧缓冲（仅在 >poolSize 个音同时发声时发生）。
    victim.player.stop()
    victim.busy = false
    return victim
  }

  // MARK: - Stop（淡出，绝不硬停）

  private func stopVoices(metronomeOnly: Bool, fadeMs: Int) {
    // 只淡出真正在播 buffer 的 busy 节点；其余 playing-idle 节点不动。
    let targets = voices.filter {
      $0.busy && (!metronomeOnly || $0.isMetronome)
    }
    guard !targets.isEmpty else { return }

    fadeGeneration += 1
    let generation = fadeGeneration
    let steps = 12
    let stepMs = max(1, fadeMs / steps)
    let baseVolumes = targets.map { max(0, min($0.player.volume, 1)) }

    // 淡出走主队列，不占 controlQueue / playQueue，避免页面切换时堵住发声。
    for step in 1...steps {
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(step * stepMs)) {
        [weak self] in
        guard let self = self, generation == self.fadeGeneration else { return }
        let scale = max(0, Float(steps - step) / Float(steps))
        for (index, voice) in targets.enumerated() {
          voice.player.volume = baseVolumes[index] * scale
        }
        guard step == steps else { return }
        self.audioQueue.async {
          for voice in targets {
            voice.player.stop()
            voice.player.volume = 1
            voice.busy = false
            voice.isMetronome = false
            if self.graphBuilt, self.engine.isRunning {
              try? LowLatencyNoteAudioSafePlay.play(voice.player)
            }
          }
          self.applyPendingResetIfIdle()
        }
      }
    }
  }

  // MARK: - 静态音频图：构建 / 重启 / 重建

  /// 确保常驻引擎处于运行态：
  /// - 仅 `mediaServicesWereReset` 且当前无发声时整图重建；
  /// - 未建图则建一次；
  /// - 已建图但引擎停了（中断 / 路由 / 类别切换后）则重启 + 续接节点。
  private func ensureEngineRunning() throws {
    guard !interrupted else { return }
    if engineNeedsReset && activeVoiceCount() == 0 {
      rebuildGraph()
    }
    if !graphBuilt {
      try buildGraph()
      return
    }
    if !engine.isRunning {
      try startEngineAndResumeNodes()
    }
  }

  private func buildGraph() throws {
    detachAllVoices()
    voices.removeAll()

    let mixer = engine.mainMixerNode
    for _ in 0..<poolSize {
      let voice = Voice()
      try LowLatencyNoteAudioSafePlay.attachNode(voice.player, toEngine: engine)
      try LowLatencyNoteAudioSafePlay.connectNode(
        voice.player,
        toNode: mixer,
        format: standardFormat,
        inEngine: engine
      )
      voices.append(voice)
    }

    try LowLatencyNoteAudioSafePlay.prepareAndStartEngine(engine)
    engine.mainMixerNode.outputVolume = masterOutputLevel

    for voice in voices {
      try? LowLatencyNoteAudioSafePlay.play(voice.player)
    }

    graphBuilt = true
    engineNeedsReset = false
  }

  private func startEngineAndResumeNodes() throws {
    try LowLatencyNoteAudioSafePlay.prepareAndStartEngine(engine)
    engine.mainMixerNode.outputVolume = masterOutputLevel
    // mpv / 会话切换后节点 isPlaying 常陈旧；stop + play 强制对齐 IO 周期。
    for voice in voices {
      if voice.player.isPlaying {
        voice.player.stop()
      }
      try? LowLatencyNoteAudioSafePlay.play(voice.player)
    }
    engineNeedsReset = false
  }

  private func rebuildGraph() {
    fadeGeneration += 1
    detachAllVoices()
    voices.removeAll()
    if engine.isRunning { engine.stop() }
    engine.reset()
    graphBuilt = false
    engineNeedsReset = false
  }

  private func detachAllVoices() {
    for voice in voices {
      if voice.player.isPlaying { voice.player.stop() }
      if engine.attachedNodes.contains(voice.player) {
        engine.disconnectNodeOutput(voice.player)
        engine.detach(voice.player)
      }
    }
  }

  private func applyPendingResetIfIdle() {
    guard engineNeedsReset else { return }
    guard activeVoiceCount() == 0 else { return }
    rebuildGraph()
    try? buildGraph()
  }

  /// 真正在发声的音数量：固定池中所有节点常驻 playing-idle，
  /// 故 `player.isPlaying` 恒为 true 不可用于判断；只数显式 busy。
  private func activeVoiceCount() -> Int {
    voices.filter { $0.busy }.count
  }

  // MARK: - Buffer 处理

  /// 拷贝采样并加首尾极短淡入/淡出（保证归零，消除播放起止咔哒）。
  /// AVAudioPCMBuffer 在 completion 前不可复用，故每次播放独立拷贝。
  private func copyBufferWithEnvelope(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard
      let copy = AVAudioPCMBuffer(
        pcmFormat: source.format,
        frameCapacity: source.frameLength
      ),
      let src = source.floatChannelData,
      let dst = copy.floatChannelData
    else {
      return nil
    }
    copy.frameLength = source.frameLength

    let channels = Int(source.format.channelCount)
    let frames = Int(source.frameLength)
    let byteCount = frames * MemoryLayout<Float>.size
    for channel in 0..<channels {
      memcpy(dst[channel], src[channel], byteCount)
    }

    let sampleRate = source.format.sampleRate
    let attackFrames = min(frames / 4, max(1, Int(attackFadeMs * 0.001 * sampleRate)))
    let releaseFrames = min(frames / 4, max(1, Int(tailFadeMs * 0.001 * sampleRate)))

    for channel in 0..<channels {
      let samples = dst[channel]
      if attackFrames > 1 {
        for i in 0..<attackFrames {
          samples[i] *= Float(i) / Float(attackFrames)
        }
      }
      if releaseFrames > 1 {
        for i in 0..<releaseFrames {
          let frame = frames - releaseFrames + i
          samples[frame] *= Float(releaseFrames - 1 - i) / Float(releaseFrames)
        }
      }
    }

    return copy
  }

  private func resolveFlutterAsset(_ asset: String) -> URL? {
    let lookupKey = FlutterDartProject.lookupKey(forAsset: asset)
    if let url = Bundle.main.url(forResource: lookupKey, withExtension: nil) {
      return url
    }
    if let path = Bundle.main.path(forResource: lookupKey, ofType: nil) {
      return URL(fileURLWithPath: path)
    }
    if let url = Bundle.main.url(forResource: "flutter_assets/\(asset)", withExtension: nil) {
      return url
    }
    if let url = Bundle.main.url(forResource: asset, withExtension: nil) {
      return url
    }
    return nil
  }

  private func decodeAsset(url: URL) throws -> AVAudioPCMBuffer {
    let file = try AVAudioFile(forReading: url)
    let frameCount = AVAudioFrameCount(file.length)
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat,
        frameCapacity: frameCount
      )
    else {
      throw LowLatencyNoteAudioError.decodeFailed(url.lastPathComponent)
    }
    try file.read(into: buffer)
    return try convertToStandardFormat(buffer)
  }

  /// 统一解码结果到 standardFormat（float32/44100/stereo），保证连接格式恒定。
  private func convertToStandardFormat(_ source: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
    if source.format.isEqual(standardFormat) {
      return source
    }
    guard let converter = AVAudioConverter(from: source.format, to: standardFormat) else {
      throw LowLatencyNoteAudioError.decodeFailed("converter")
    }
    let ratio = standardFormat.sampleRate / source.format.sampleRate
    let outFrames = AVAudioFrameCount(Double(source.frameLength) * ratio + 64)
    guard
      let output = AVAudioPCMBuffer(pcmFormat: standardFormat, frameCapacity: outFrames)
    else {
      throw LowLatencyNoteAudioError.decodeFailed("output")
    }

    var consumed = false
    var error: NSError?
    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
      if consumed {
        outStatus.pointee = .noDataNow
        return nil
      }
      consumed = true
      outStatus.pointee = .haveData
      return source
    }
    converter.convert(to: output, error: &error, withInputFrom: inputBlock)
    if let error { throw error }
    return output
  }
}

private enum LowLatencyNoteAudioError: Error, CustomStringConvertible {
  case assetNotFound(String)
  case decodeFailed(String)
  case bufferNotPrepared(String)

  var description: String {
    switch self {
    case .assetNotFound(let asset):
      return "Asset not found: \(asset)"
    case .decodeFailed(let asset):
      return "Failed to decode asset: \(asset)"
    case .bufferNotPrepared(let key):
      return "Buffer not prepared for key: \(key)"
    }
  }
}
