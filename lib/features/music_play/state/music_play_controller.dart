import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/app_audio_service.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../music_companion/audio/music_companion_audio_engine.dart';
import '../../music_companion/audio/page_audio_lifecycle.dart';
import '../../smart_campus/data/chat_share_payload.dart';
import '../audio/music_play_audio_player.dart';
import '../audio/music_play_audio_visualizer.dart';
import '../audio/music_play_frequency_utils.dart';
import '../data/music_play_repository.dart';
import 'music_play_state.dart';

final musicPlayControllerProvider = StateNotifierProvider.autoDispose
    .family<MusicPlayController, MusicPlayState, MusicPlayPageArgs>((
      ref,
      args,
    ) {
      final repository = ref.watch(musicPlayRepositoryProvider);
      final controller = MusicPlayController(
        repository: repository,
        args: args,
      );
      return controller;
    });

class MusicPlayController extends StateNotifier<MusicPlayState> {
  MusicPlayController({
    required this.repository,
    required MusicPlayPageArgs args,
  }) : _pianoEngine = MusicCompanionAudioEngine(),
       super(MusicPlayState.initial(args)) {
    unawaited(_initialize());
  }

  /// 当前前台 MusicPlay 实例。叠层打开新播放页时，旧页仍在 Navigator
  /// 栈里且 provider 未 dispose，需要通过 handoff 立刻停掉旧长音频。
  static MusicPlayController? _foregroundController;

  /// 路由切到新的 MusicPlay 之前调用，避免旧页与新页叠音。
  static Future<void> stopForegroundPlayback() async {
    final current = _foregroundController;
    if (current == null) {
      return;
    }
    await current._stopLongAudioForHandoff();
  }

  final MusicPlayRepository repository;
  final MusicCompanionAudioEngine _pianoEngine;

  /// 主音频播放器：使用 `media_kit` 在 native（iOS/Android/Desktop）
  /// 与 Web 上提供"倍速 + 升降调"双独立旋钮：
  /// - [Player.setRate] —— 变速保音高（mpv 默认开启 audio-pitch-correction）；
  /// - [Player.setPitch] —— 独立的半音变调（speed 不动）。
  /// 钢琴弹奏仍然走 [MusicCompanionAudioEngine]（基于 SoLoud），与此处互不影响。
  MusicPlayAudioPlayer? _player;
  MusicPlayAudioVisualizer? _visualizer;
  StreamSubscription<List<double>>? _bandsSub;
  StreamSubscription<int?>? _androidSessionSub;
  DateTime? _lastVisualizerSync;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  bool _recordSaved = false;
  Future<void>? _iosPianoRecoverTask;
  Future<void>? _iosSessionPrimeTask;
  bool _iosMusicPlaySessionPrimed = false;

  /// 已经 dispose 的标志位。
  ///
  /// `dispose()` 中第一时间置位，让任何还在 await 的异步链（[togglePlay]、
  /// [pressPianoKey]、[_openActiveTrack] 等）都能在拿到 `player.open(...)`
  /// 之前 short-circuit 退出，避免页面消失之后还冒出一声 "ding"。
  bool _disposed = false;

  /// `_openActiveTrack` 并发自增票据。
  ///
  /// iPad 上动作较快时，用户连点 1 次播放或快速翻页，会让两次
  /// `_openActiveTrack` 并发：两次都各自调 `player.open(...)`，
  /// 出现"两个音频同时在响"。这里用最经典的 ticket 方案：每次进入
  /// 自增 1，await 之后比对，落后的那次直接放弃。
  int _openTicket = 0;

  /// 串行化 open，便于 [dispose] 在释放 mpv 前等待最后一次 open 结束。
  Future<void>? _openTrackChain;

  /// 全应用串行释放 media_kit Player，避免页间快速切换时并发 dispose 触发
  /// libmpv 在 `mp_client_send_property_changes` 里 abort。
  static Future<void>? _mediaKitTeardownChain;

  static const Duration _kMpvTeardownStepTimeout = Duration(seconds: 4);
  static const Duration _kMpvOpenDrainTimeout = Duration(seconds: 8);

  // ── 进度条 seek 合并 ────────────────────────────────────────────────
  // iPad 上拖进度条时，60–120Hz 的 onHorizontalDragUpdate 会让每个手势
  // 帧都触发一次 native `player.seek()`。mpv 的 seek 是 platform 往返
  // 调用（50–150ms / 次），不做合并就会出现"队列堆积 → 松手后还在追
  // 历史目标"的体验。下面三个字段实现：
  //   1. 同时只允许一次 native seek 在飞 (`_seekInFlight`)；
  //   2. 中间帧的目标只记到 `_pendingSeek`，最新的会覆盖旧的 —— 松手
  //      时一定收敛到最新手指位置；
  //   3. seek 发起后 ~350ms 内，`player.stream.position` 还可能吐 mpv
  //      "尚未跳到"前的旧位置，用 `_seekFilterUntil` + `_lastSeekTarget`
  //      把这些远离目标 (>500ms) 的事件丢弃，避免 thumb 看到"先回弹
  //      再前进"的鬼影。
  bool _seekInFlight = false;
  Duration? _pendingSeek;
  Duration? _lastSeekTarget;
  DateTime? _seekFilterUntil;
  static const Duration _kSeekStaleWindow = Duration(milliseconds: 350);
  static const int _kSeekStaleDiffMs = 500;

  /// 原调 ↔ 升降调切换时会重建播放器；open 初期 position/duration 会先回到 0。
  /// 在 seek 收敛前锁住 UI，避免进度条「先到 0 再回到当前」。
  Duration? _heldPositionDuringPitchTransition;
  Duration? _heldDurationDuringPitchTransition;

  /// 用户点击播放/暂停后，在淡出/恢复完成前忽略 [Player.stream.playing]，
  /// 避免按钮要等音频实际停播才切换图标。
  int _playbackToggleInFlight = 0;

  /// 拖动进度条期间保持 UI「播放中」状态；底层 seek 可能短暂上报 paused。
  bool _scrubbing = false;
  Timer? _scrubUiHoldTimer;
  int _scrubUiHoldGen = 0;
  static const Duration _kScrubUiHoldClear = Duration(milliseconds: 200);

  /// 主音频正常播放音量（media_kit 为 0–100）。
  static const double _kPlayerNormalVolume = 100;

  /// 暂停前淡出步数/间隔：减轻 mpv / Web 硬切 pause 时的滋滋底噪。
  static const int _kPauseFadeSteps = 4;
  static const Duration _kPauseFadeStepDelay = Duration(milliseconds: 18);

  /// iOS 暂停/恢复去爆音用的超短斜坡（约 3×6ms ≈ 18ms），尽量不影响响应手感。
  static const int _kIosClickFadeSteps = 3;
  static const Duration _kIosClickFadeStepDelay = Duration(milliseconds: 6);

  /// iOS mpv teardown 后给 CoreAudio 一个很短排空窗口，避免跨页释放时残留尾音。
  static const Duration _kIosPauseDrainDelay = Duration(milliseconds: 48);

  bool get _isIosNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool _usesMpvOnIos(MusicPlayAudioPlayer player) =>
      _isIosNative && !player.usesNativeIosPlayback;

  /// iOS 升降调：拖动只更新 UI，松手单次 native seek（避免 scaletempo 连续重配）。
  bool get _deferPitchScrubSeeks => _playerPitchEnabled && _isIosNative;

  bool get _shouldEnablePitchForCurrentState =>
      state.detail?.hidePitchShift != true && state.pitchSemitones != 0;

  int _appliedPitchSemitones = 0;
  bool _playerPitchEnabled = false;

  /// 把半音数转为 [Player.setPitch] 接受的频率倍率（2^(n/12)）。
  static double _pitchRatio(int semitones) =>
      math.pow(2, semitones / 12.0).toDouble();

  /// "随机循环" 用的随机源。整个 controller 生命周期共用一个实例，避免每次
  /// 抽下一首都重新 seed → 在系统时钟低分辨率的设备（部分 Android）上连出
  /// 同一个数字的尴尬。
  final math.Random _shuffleRandom = math.Random();

  /// 在 [total] 个 track 中给"随机循环"挑一个**不等于** [currentIdx] 的下标。
  ///
  /// 经典 "skip-current" 写法：从 `total - 1` 个候选里 [Random.nextInt]，
  /// 拿到的下标若 `>= currentIdx` 再 +1，等价于把当前 track 从候选集里抽掉。
  /// 这样保证：
  ///   - 不会立即重复同一首（用户对 "随机" 的最低期待）；
  ///   - 仍然每首都有 `1/(N-1)` 的概率被抽到，分布均匀。
  int _shuffleNextIndex(int currentIdx, int total) {
    if (total <= 1) {
      return 0;
    }
    final n = _shuffleRandom.nextInt(total - 1);
    return n >= currentIdx ? n + 1 : n;
  }

  void _claimForegroundHandoff() {
    final previous = _foregroundController;
    if (previous != null && !identical(previous, this)) {
      unawaited(previous._stopLongAudioForHandoff());
    }
    _foregroundController = this;
  }

  void _releaseForegroundHandoff() {
    if (identical(_foregroundController, this)) {
      _foregroundController = null;
    }
  }

  /// 立刻停止长音频与钢琴，供页间切换 / 同页换教材 handoff 使用。
  Future<void> _stopLongAudioForHandoff() async {
    if (_disposed) {
      return;
    }
    _openTicket++;
    _endScrubUiHold(immediate: true);
    if (mounted) {
      state = state.copyWith(isPlaying: false);
    }
    _setVisualizerPausedState();
    _pianoEngine.stopAllImmediately();
    final player = _player;
    if (player == null) {
      return;
    }
    try {
      if (player.usesPitchTransport) {
        await player.ensureOutputMuted();
      }
      await player.pause();
      await player.stop();
    } catch (_) {}
  }

  Future<void> _initialize() async {
    _claimForegroundHandoff();
    // 钢琴/会话预热与详情加载并行：预热先发起以尽量先占好会话，但**绝不阻塞**
    // 详情加载与 loading spinner——否则一旦 iOS 音频会话卡住，整页会一直转圈。
    final warmUp = _warmUpPiano();
    try {
      await loadDetail(state.args.id, preserveShowAnswer: false);
    } catch (_) {
      if (mounted) {
        state = state.copyWith(loading: false, errorMessage: '');
      }
    }
    // _warmUpPiano 自身已 try/catch 不抛出；这里仅消化其完成，不影响内容展示。
    await warmUp;
  }

  /// iOS：为 media_kit 长音频准备会话（不阻塞在钢琴 reclaim 上）。
  Future<void> _ensureIosMediaKitSessionForLongAudio({
    bool forceRelease = false,
  }) async {
    if (!_isIosNative || _disposed) {
      return;
    }
    if (_iosMusicPlaySessionPrimed && !forceRelease) {
      await PageAudioLifecycle.primeMediaKitPlaybackSession(
        releaseOthersFirst: false,
      );
      return;
    }
    if (_iosSessionPrimeTask != null) {
      await _iosSessionPrimeTask;
      return;
    }
    final task = PageAudioLifecycle.primeMediaKitPlaybackSession(
      releaseOthersFirst: forceRelease || !_iosMusicPlaySessionPrimed,
    );
    _iosSessionPrimeTask = task;
    try {
      await task;
      _iosMusicPlaySessionPrimed = true;
    } finally {
      if (identical(_iosSessionPrimeTask, task)) {
        _iosSessionPrimeTask = null;
      }
    }
  }

  Future<void> _recoverIosPianoGraph({bool awaitCompletion = true}) async {
    if (!_isIosNative || _disposed) {
      return;
    }
    final pending = _iosPianoRecoverTask;
    if (pending != null) {
      if (awaitCompletion) {
        await pending;
      } else {
        return;
      }
      if (!_disposed && _pianoEngine.isPianoReady) {
        return;
      }
    }
    final task = PageAudioLifecycle.recoverPianoDuringMediaKit(_pianoEngine);
    _iosPianoRecoverTask = task;
    if (!awaitCompletion) {
      unawaited(
        task.whenComplete(() {
          if (identical(_iosPianoRecoverTask, task)) {
            _iosPianoRecoverTask = null;
          }
          if (mounted &&
              !_disposed &&
              !state.ready &&
              _pianoEngine.isPianoReady) {
            state = state.copyWith(ready: true);
          }
        }),
      );
      return;
    }
    try {
      await task;
    } finally {
      if (identical(_iosPianoRecoverTask, task)) {
        _iosPianoRecoverTask = null;
      }
    }
  }

  /// 按键前确保 iOS 钢琴图已就绪（合并进行中的 recover，避免重复 handoff）。
  Future<void> _awaitIosPianoReadyForKeypress() async {
    if (!_isIosNative || _disposed) {
      return;
    }
    if (_shouldEnablePitchForCurrentState && !_iosMusicPlaySessionPrimed) {
      await _ensureIosMediaKitSessionForLongAudio();
    }
    if (_pianoEngine.isPianoReady) {
      return;
    }
    await _recoverIosPianoGraph();
  }

  Future<void> _warmUpPiano() async {
    try {
      if (_isIosNative) {
        // 先准备 media_kit 长音频会话（前台、强释放旧 owner）。
        // 然后在**后台**预热原生钢琴图（持久 AVAudioEngine 轻量 reclaim + 采样
        // 解码）。不 await，避免阻塞 loading 或干扰长音频；预热完成后首次按键
        // 直接命中 tryPlay，告别「钢琴等很久才响」。
        unawaited(_recoverIosPianoGraph(awaitCompletion: false));
      } else {
        await _pianoEngine.ensurePianoInitialized();
      }
      if (!mounted) {
        return;
      }
      state = state.copyWith(ready: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      state = state.copyWith(ready: false);
    }
  }

  Future<void> loadDetail(int id, {required bool preserveShowAnswer}) async {
    if (id <= 0) {
      state = state.copyWith(loading: false, errorMessage: '教材参数无效，无法打开播放页');
      return;
    }

    await _stopLongAudioForHandoff();

    state = state.copyWith(
      loading: true,
      errorMessage: '',
      position: Duration.zero,
      duration: Duration.zero,
      isPlaying: false,
      frequencyBands: const <double>[],
    );

    final responses = await Future.wait<ApiResponse>(<Future<ApiResponse>>[
      repository.getDetail(id),
      repository.getMyInfo(),
    ]);
    if (!mounted) {
      return;
    }

    final detailResponse = responses[0];
    final infoResponse = responses[1];
    if (!detailResponse.isSuccess ||
        detailResponse.data is! Map<String, dynamic>) {
      state = state.copyWith(
        loading: false,
        errorMessage: detailResponse.displayMsg,
      );
      return;
    }

    final detailMap = detailResponse.data as Map<String, dynamic>;
    final detail = _parseDetail(detailMap);
    if (detail.vipOnly && !_hasVipAccess(infoResponse.data)) {
      state = state.copyWith(
        loading: false,
        errorMessage: '当前内容需要会员权限，请先开通或续费会员',
      );
      return;
    }

    final nextShowAnswer = preserveShowAnswer
        ? state.showAnswer
        : _defaultShowAnswer(state.args.type, detail);

    final nextPitch = detail.hidePitchShift ? 0 : state.pitchSemitones;

    state = state.copyWith(
      loading: false,
      detail: detail,
      showAnswer: nextShowAnswer,
      activeImageIndex: 0,
      activeTrackIndex: 0,
      pitchSemitones: nextPitch,
      clearErrorMessage: true,
    );

    _recordSaved = false;
    await _openActiveTrack(play: false);
    if (!state.isPlaying) {
      _setVisualizerPausedState();
    }
  }

  Future<void> togglePlay() async {
    if (_disposed) return;
    final track = state.activeTrack;
    if (track == null) {
      return;
    }

    final player = _player;
    if (player == null || state.duration == Duration.zero) {
      if (mounted) {
        state = state.copyWith(isPlaying: true);
      }
      await _openActiveTrack(play: true);
      return;
    }
    _endScrubUiHold(immediate: true);

    final wantPlaying = !state.isPlaying;
    _playbackToggleInFlight++;
    if (mounted) {
      state = state.copyWith(isPlaying: wantPlaying);
    }
    try {
      if (wantPlaying) {
        await _resumePlayer(player);
      } else {
        await _pausePlayerSmooth(player);
      }
    } catch (_) {}
    _playbackToggleInFlight--;
    unawaited(_syncVisualizerTransport());
    if (!wantPlaying) {
      _setVisualizerPausedState();
    }
    if (_disposed || !mounted || _playbackToggleInFlight > 0) {
      return;
    }
    state = state.copyWith(isPlaying: player.state.playing);
  }

  Future<void> _setPlayerVolumeSafe(
    MusicPlayAudioPlayer player,
    double volume,
  ) async {
    try {
      await player.setVolume(volume.clamp(0, 100));
    } catch (_) {}
  }

  Future<void> _fadePlayerVolume(
    MusicPlayAudioPlayer player, {
    required double to,
    int? steps,
    Duration? stepDelay,
    double? from,
  }) async {
    final fadeSteps = steps ?? _kPauseFadeSteps;
    final fadeDelay = stepDelay ?? _kPauseFadeStepDelay;
    // 允许显式传入起点：刚 setVolume 后 player.state.volume 可能仍是旧值，
    // 不显式给 from 会导致 (from-to)<1 而跳过斜坡（恢复播放淡入失效）。
    final fromVol = from ?? player.state.volume;
    if ((fromVol - to).abs() < 1) {
      await _setPlayerVolumeSafe(player, to);
      return;
    }
    for (var step = 1; step <= fadeSteps; step++) {
      if (_disposed) {
        return;
      }
      final t = step / fadeSteps;
      await _setPlayerVolumeSafe(player, fromVol + (to - fromVol) * t);
      if (step < fadeSteps) {
        await Future.delayed(fadeDelay);
      }
    }
  }

  Future<void> _applyPitchToPlayer(
    MusicPlayAudioPlayer player, {
    bool muteGuard = true,
  }) async {
    if (state.detail?.hidePitchShift == true) {
      return;
    }
    if (!_playerPitchEnabled && state.pitchSemitones != 0) {
      return;
    }
    if (!_playerPitchEnabled && state.pitchSemitones == 0) {
      _appliedPitchSemitones = 0;
      return;
    }
    if (state.pitchSemitones == _appliedPitchSemitones) {
      return;
    }
    final ratio = _pitchRatio(state.pitchSemitones);
    Future<void> apply() async {
      await player.setPitch(ratio);
      _appliedPitchSemitones = state.pitchSemitones;
    }

    try {
      if (muteGuard && player.usesPitchTransport) {
        await player.runPitchFilterChange(
          apply,
          restoreAudible: state.isPlaying,
        );
      } else {
        await apply();
      }
    } catch (_) {}
  }

  /// 淡出后 pause，避免解码器硬切产生的短促底噪。
  Future<void> _pausePlayerSmooth(MusicPlayAudioPlayer player) async {
    if (_disposed) {
      return;
    }
    if (_isIosNative) {
      await _pausePlayerSmoothIos(player);
      return;
    }
    try {
      await _fadePlayerVolume(player, to: 0);
      await player.pause();
    } catch (_) {}
    await _setPlayerVolumeSafe(player, _kPlayerNormalVolume);
  }

  /// iOS：无升降调用 AVPlayer；有升降调用 mpv mute 包裹 pause（scaletempo 不吃音量斜坡）。
  Future<void> _pausePlayerSmoothIos(MusicPlayAudioPlayer player) async {
    if (_disposed) {
      return;
    }
    if (player.usesNativeIosPlayback || player.usesPitchTransport) {
      try {
        await player.pause();
      } catch (_) {}
      return;
    }
    try {
      await _fadePlayerVolume(
        player,
        to: 0,
        steps: _kIosClickFadeSteps,
        stepDelay: _kIosClickFadeStepDelay,
      );
      await player.pause();
    } catch (_) {}
    await _setPlayerVolumeSafe(player, _kPlayerNormalVolume);
  }

  Future<void> _resumePlayer(MusicPlayAudioPlayer player) async {
    if (_disposed) {
      return;
    }
    if (_isIosNative && !player.usesNativeIosPlayback) {
      await _ensureIosMediaKitSessionForLongAudio();
    }
    try {
      await _applyPitchToPlayer(player, muteGuard: false);
      if (player.usesPitchTransport) {
        await player.play();
      } else if (_isIosNative && !player.usesNativeIosPlayback) {
        await _setPlayerVolumeSafe(player, 0);
        await player.play();
        await _fadePlayerVolume(
          player,
          to: _kPlayerNormalVolume,
          steps: _kIosClickFadeSteps,
          stepDelay: _kIosClickFadeStepDelay,
          from: 0,
        );
      } else {
        await _setPlayerVolumeSafe(player, _kPlayerNormalVolume);
        await player.play();
      }
    } catch (_) {}
  }

  Future<void> previous() async {
    if (_disposed) return;
    if (state.args.allLessonIds.isNotEmpty) {
      await _switchLesson(-1);
      return;
    }
    final detail = state.detail;
    if (detail == null || detail.tracks.length <= 1) {
      await seek(Duration.zero);
      return;
    }
    // "随机循环"模式下，"上一首"也走随机抽取：用户既然选了随机，下一/上一
    // 都按随机来更符合直觉（避免出现"上一首明明刚听过"的体验割裂）。
    final previousIndex = state.playMode == MusicPlayMode.shuffle
        ? _shuffleNextIndex(state.activeTrackIndex, detail.tracks.length)
        : (state.activeTrackIndex <= 0
              ? detail.tracks.length - 1
              : state.activeTrackIndex - 1);
    state = state.copyWith(
      activeTrackIndex: previousIndex,
      activeImageIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      frequencyBands: const <double>[],
    );
    await _openActiveTrack(play: true);
  }

  Future<void> next() async {
    if (_disposed) return;
    if (state.args.allLessonIds.isNotEmpty) {
      await _switchLesson(1);
      return;
    }
    final detail = state.detail;
    if (detail == null || detail.tracks.length <= 1) {
      await seek(Duration.zero);
      return;
    }
    // 随机循环：next 等价于"再随机抽一首"；其它模式按顺序推进 + 末尾回环。
    final nextIndex = state.playMode == MusicPlayMode.shuffle
        ? _shuffleNextIndex(state.activeTrackIndex, detail.tracks.length)
        : (state.activeTrackIndex >= detail.tracks.length - 1
              ? 0
              : state.activeTrackIndex + 1);
    state = state.copyWith(
      activeTrackIndex: nextIndex,
      activeImageIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      frequencyBands: const <double>[],
    );
    await _openActiveTrack(play: true);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final nextSpeed = speed.clamp(0.5, 2.0);
    final player = _player;
    if (player != null) {
      try {
        if (player.usesPitchTransport) {
          await player.runPitchFilterChange(
            () => player.setRate(nextSpeed),
            restoreAudible: state.isPlaying,
          );
        } else {
          // mpv 默认 audio-pitch-correction=yes：变速不变调。
          // Web 端 HTML5 audio 的浏览器默认也保留音高。
          await player.setRate(nextSpeed);
        }
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    state = state.copyWith(speed: nextSpeed);
  }

  /// 独立的"升降调"控制（半音）。与 [setPlaybackSpeed] 完全解耦：
  /// 内部走 [Player.setPitch]，半音 N → 频率倍率 2^(N/12)。
  Future<void> setPitchSemitones(int semitones) async {
    if (state.detail?.hidePitchShift == true) {
      return;
    }
    final next = semitones.clamp(-12, 12);
    final pitchModeChanged =
        (state.detail?.hidePitchShift != true && next != 0) !=
        _playerPitchEnabled;
    if (mounted) {
      state = state.copyWith(pitchSemitones: next);
    }
    final player = _player;
    if (player != null && pitchModeChanged) {
      await _reopenActiveTrackPreservingPlayback();
      return;
    }
    if (player != null && _playerPitchEnabled) {
      try {
        await player.runPitchFilterChange(() async {
          await player.setPitch(_pitchRatio(next));
          _appliedPitchSemitones = next;
        }, restoreAudible: state.isPlaying);
      } catch (_) {
        // Web/部分平台对 setPitch 不一定支持，静默吞掉，
        // UI 层依旧按照所选半音数显示。
      }
    }
    if (player != null && _playerPitchEnabled) {
      return;
    }
    _appliedPitchSemitones = 0;
  }

  /// 切换"循环模式"：顺序 → 单曲循环 → 随机循环 → 顺序。
  /// 仅在多曲目场景下有意义，单曲目时也允许调用但不会影响实际行为。
  void togglePlayMode() {
    final next = switch (state.playMode) {
      MusicPlayMode.sequence => MusicPlayMode.single,
      MusicPlayMode.single => MusicPlayMode.shuffle,
      MusicPlayMode.shuffle => MusicPlayMode.sequence,
    };
    state = state.copyWith(playMode: next);
  }

  /// 直接跳到曲目列表中的指定索引并播放。
  /// 用户在"播放列表"菜单中点击某一项时调用；与 [previous] / [next] 共享
  /// 同一套 ticket 化的 `_openActiveTrack`，避免连点产生双声。
  Future<void> selectTrack(int index) async {
    if (_disposed) return;
    final detail = state.detail;
    if (detail == null || detail.tracks.isEmpty) {
      return;
    }
    final safe = index.clamp(0, detail.tracks.length - 1);
    if (safe == state.activeTrackIndex) {
      // 同一首：从头重播（同时承担"单曲循环"自动续播的语义）。
      await seek(Duration.zero);
      final player = _player;
      if (player != null) {
        await _resumePlayer(player);
      }
      return;
    }
    state = state.copyWith(
      activeTrackIndex: safe,
      activeImageIndex: 0,
      position: Duration.zero,
      duration: Duration.zero,
      frequencyBands: const <double>[],
    );
    await _openActiveTrack(play: true);
  }

  void _beginScrubUiHold() {
    if (!state.isPlaying) {
      return;
    }
    _scrubbing = true;
    _scrubUiHoldTimer?.cancel();
    _scrubUiHoldTimer = null;
  }

  /// 升降调拖动期间只刷新 thumb / 时间标签，不触发 native seek。
  void previewSeekPosition(Duration position) {
    final max = state.duration;
    final safe = max == Duration.zero
        ? position
        : Duration(
            milliseconds: position.inMilliseconds.clamp(0, max.inMilliseconds),
          );
    if (mounted) {
      state = state.copyWith(position: safe);
    }
  }

  Future<void> _commitPitchModeSeek(Duration target) async {
    if (_disposed) {
      return;
    }
    _lastSeekTarget = target;
    _seekFilterUntil = DateTime.now().add(_kSeekStaleWindow);
    if (mounted) {
      state = state.copyWith(position: target);
    }
    final player = _player;
    if (player == null) {
      return;
    }
    _beginScrubUiHold();
    try {
      await player.seek(
        target,
        restoreAudible: state.isPlaying,
      );
    } catch (_) {}
    _scrubUiHoldTimer?.cancel();
    _scrubUiHoldTimer = null;
    _scrubbing = false;
    if (mounted) {
      state = state.copyWith(isPlaying: player.state.playing);
    }
  }

  Future<void> _seekPlayerSmooth(
    MusicPlayAudioPlayer player,
    Duration target,
  ) async {
    if (player.usesPitchTransport) {
      await player.seek(target, restoreAudible: state.isPlaying);
      return;
    }
    if (!_usesMpvOnIos(player)) {
      await player.seek(target);
      return;
    }
    final restoreAudible = player.state.playing || state.isPlaying;
    if (restoreAudible) {
      await _setPlayerVolumeSafe(player, 0);
    }
    await player.seek(target);
    if (restoreAudible) {
      await _fadePlayerVolume(
        player,
        to: _kPlayerNormalVolume,
        from: 0,
        steps: _kIosClickFadeSteps,
        stepDelay: _kIosClickFadeStepDelay,
      );
    }
  }

  void _endScrubUiHold({bool immediate = false}) {
    _scrubUiHoldTimer?.cancel();
    _scrubUiHoldTimer = null;
    if (immediate || _disposed) {
      _scrubbing = false;
      return;
    }
    final gen = ++_scrubUiHoldGen;
    _scrubUiHoldTimer = Timer(_kScrubUiHoldClear, () {
      _scrubUiHoldTimer = null;
      if (_disposed || gen != _scrubUiHoldGen) {
        return;
      }
      if (_seekInFlight || _pendingSeek != null) {
        return;
      }
      _scrubbing = false;
      final player = _player;
      if (player != null && mounted) {
        state = state.copyWith(isPlaying: player.state.playing);
      }
    });
  }

  Future<void> seek(Duration position) async {
    final max = state.duration;
    final safe = max == Duration.zero
        ? position
        : Duration(
            milliseconds: position.inMilliseconds.clamp(0, max.inMilliseconds),
          );

    if (_deferPitchScrubSeeks) {
      await _commitPitchModeSeek(safe);
      return;
    }

    // 1) 已有 seek 在飞 → 只更新 pending 目标 + 乐观刷 UI 后立刻返回，
    //    让正在跑的 seek 循环跑完当前帧后接到最新目标。这样无论拖多快，
    //    native 端始终只有一条 seek 在排队。
    if (_seekInFlight) {
      _pendingSeek = safe;
      _lastSeekTarget = safe;
      _seekFilterUntil = DateTime.now().add(_kSeekStaleWindow);
      if (mounted) {
        state = state.copyWith(position: safe);
      }
      return;
    }

    // 2) 空闲：拿到飞行权 → 进入 seek 循环。每轮跑完后看 `_pendingSeek`，
    //    若有更新过的目标就继续跑下一轮；否则退出。
    _seekInFlight = true;
    Duration target = safe;
    _lastSeekTarget = target;
    _seekFilterUntil = DateTime.now().add(_kSeekStaleWindow);
    if (mounted) {
      state = state.copyWith(position: target);
    }

    _beginScrubUiHold();

    try {
      while (true) {
        if (_disposed) {
          break;
        }
        final activePlayer = _player;
        if (activePlayer == null) {
          break;
        }
        try {
          await _seekPlayerSmooth(activePlayer, target);
        } catch (_) {}

        final pending = _pendingSeek;
        if (pending != null && pending != target) {
          target = pending;
          _pendingSeek = null;
          _lastSeekTarget = target;
          _seekFilterUntil = DateTime.now().add(_kSeekStaleWindow);
          if (mounted) {
            state = state.copyWith(position: target);
          }
          continue;
        }
        _pendingSeek = null;
        break;
      }
    } finally {
      _seekInFlight = false;
      _scrubUiHoldTimer?.cancel();
      _scrubUiHoldTimer = null;
      _scrubbing = false;
      final player = _player;
      if (player != null && mounted) {
        state = state.copyWith(isPlaying: player.state.playing);
      }
      unawaited(_syncVisualizerTransport());
    }
  }

  Future<void> toggleFavorite() async {
    final detail = state.detail;
    if (detail == null) {
      return;
    }
    final nextFavorite = !detail.favorite;
    final response = await repository.setFavorite(
      targetId: detail.id,
      type: detail.type,
      favorite: nextFavorite,
    );
    if (!mounted) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(errorMessage: response.displayMsg);
      return;
    }
    state = state.copyWith(
      detail: MusicPlayDetail(
        id: detail.id,
        type: detail.type,
        title: detail.title,
        subtitle: detail.subtitle,
        shortText1: detail.shortText1,
        shortText2: detail.shortText2,
        coverUrl: detail.coverUrl,
        favorite: nextFavorite,
        vipOnly: detail.vipOnly,
        questionImages: detail.questionImages,
        answerImages: detail.answerImages,
        tracks: detail.tracks,
        longTextHtml: detail.longTextHtml,
        firstMenu: detail.firstMenu,
      ),
    );
  }

  void setShowAnswer(bool value) {
    if (value == state.showAnswer) {
      return;
    }
    state = state.copyWith(showAnswer: value, activeImageIndex: 0);
  }

  void setImageIndex(int index) {
    final images = state.visibleImages;
    if (images.isEmpty) {
      return;
    }
    final safe = index.clamp(0, images.length - 1);
    state = state.copyWith(activeImageIndex: safe);
  }

  Future<void> pressPianoKey(String note) async {
    if (_disposed) return;
    final active = Set<String>.from(state.activePianoNotes)..add(note);
    state = state.copyWith(activePianoNotes: active);

    if (_isIosNative) {
      if (_pianoEngine.isPianoReady &&
          _pianoEngine.tryPlayNoteFromUserGesture(note)) {
        if (!state.ready && mounted && !_disposed) {
          state = state.copyWith(ready: true);
        }
        return;
      }
      await AppAudioService.prepareForPianoKeypress();
      if (_disposed || !mounted) return;
      if (!_pianoEngine.isPianoReady) {
        await _awaitIosPianoReadyForKeypress();
        if (!mounted || _disposed) return;
      }
    } else if (!_pianoEngine.isPianoReady) {
      await _pianoEngine.ensurePianoInitialized();
      if (!mounted || _disposed) return;
    }

    if (_pianoEngine.tryPlayNoteFromUserGesture(note)) {
      if (!state.ready && mounted && !_disposed) {
        state = state.copyWith(ready: true);
      }
      return;
    }

    if (!mounted || _disposed) return;
    if (!state.ready) {
      state = state.copyWith(ready: true);
    }
    await _pianoEngine.playNote(note);
  }

  void releasePianoKey(String note) {
    final active = Set<String>.from(state.activePianoNotes)..remove(note);
    state = state.copyWith(activePianoNotes: active);
  }

  void clearError() {
    if (state.errorMessage.isEmpty) {
      return;
    }
    state = state.copyWith(clearErrorMessage: true);
  }

  Future<void> openShareDialog() async {
    state = state.copyWith(
      shareDialogVisible: true,
      classLoading: state.classList.isEmpty,
      clearErrorMessage: true,
    );
    final response = await repository.getClassList();
    if (!mounted) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        classLoading: false,
        errorMessage: response.displayMsg,
      );
      return;
    }
    final raw = response.data;
    final list = <MusicPlayShareClass>[];
    if (raw is List) {
      for (final node in raw) {
        if (node is Map) {
          list.add(MusicPlayShareClass.fromJson(node));
        }
      }
    }
    state = state.copyWith(classList: list, classLoading: false);
  }

  void closeShareDialog() {
    state = state.copyWith(shareDialogVisible: false);
  }

  void toggleClass(String classId) {
    state = state.copyWith(
      classList: <MusicPlayShareClass>[
        for (final cls in state.classList)
          if (cls.id == classId) cls.copyWith(checked: !cls.checked) else cls,
      ],
    );
  }

  Future<bool> sendShare() async {
    final detail = state.detail;
    if (detail == null) {
      return false;
    }
    final selected = state.classList
        .where((cls) => cls.checked && cls.id.isNotEmpty)
        .toList();
    if (selected.isEmpty) {
      final hasChecked = state.classList.any((cls) => cls.checked);
      state = state.copyWith(
        errorMessage: hasChecked ? '所选班级数据异常，请刷新后重试' : '请先选择要分享的班级群',
      );
      return false;
    }

    state = state.copyWith(sending: true, clearErrorMessage: true);
    final content = jsonEncode(
      buildBookShareContent(
        id: detail.id,
        title: detail.title,
        type: resolveMusicPlayShareBookType(
          detailType: detail.type,
          routeType: state.args.type,
        ),
        coverUrl: detail.coverUrl,
        subtitle: detail.shortText2.isNotEmpty
            ? detail.shortText2
            : detail.shortText1,
      ),
    );

    for (final cls in selected) {
      final response = await repository.sendMsg(
        classId: cls.id,
        content: content,
      );
      if (!mounted) {
        return false;
      }
      if (!response.isSuccess) {
        state = state.copyWith(
          sending: false,
          errorMessage: response.displayMsg,
        );
        return false;
      }
    }

    state = state.copyWith(
      sending: false,
      shareDialogVisible: false,
      errorMessage: '消息已成功发送',
    );
    return true;
  }

  Future<void> _reopenActiveTrackPreservingPlayback() async {
    final oldPlayer = _player;
    final track = state.activeTrack;
    if (oldPlayer == null || track == null || track.url.isEmpty || _disposed) {
      return;
    }

    final resumePosition = state.position;
    final resumeDuration = state.duration;
    final resumePlaying = oldPlayer.state.playing || state.isPlaying;
    _heldPositionDuringPitchTransition = resumePosition;
    _heldDurationDuringPitchTransition = resumeDuration;
    if (mounted) {
      state = state.copyWith(
        position: resumePosition,
        duration: resumeDuration,
      );
    }
    _openTicket++;
    _endScrubUiHold(immediate: true);
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _player = null;

    try {
      if (_usesMpvOnIos(oldPlayer)) {
        await _pausePlayerSmoothIos(oldPlayer);
      } else {
        try {
          await oldPlayer.pause();
        } catch (_) {}
      }
      await _releaseMediaKitPlayer(oldPlayer);
      if (_disposed || !mounted) {
        return;
      }

      await _openActiveTrack(play: false);
      if (_disposed || !mounted) {
        return;
      }
      final nextPlayer = _player;
      if (nextPlayer == null) {
        return;
      }
      try {
        if (nextPlayer.usesPitchTransport) {
          await nextPlayer.ensureOutputMuted();
          await nextPlayer.seek(resumePosition, restoreAudible: false);
          await _applyPitchToPlayer(nextPlayer, muteGuard: false);
        } else if (_usesMpvOnIos(nextPlayer)) {
          await _setPlayerVolumeSafe(nextPlayer, 0);
          await nextPlayer.seek(resumePosition);
          await _applyPitchToPlayer(nextPlayer, muteGuard: false);
        } else {
          await nextPlayer.seek(resumePosition);
          await _applyPitchToPlayer(nextPlayer, muteGuard: false);
        }
      } catch (_) {}
      if (resumePlaying) {
        await _resumePlayer(nextPlayer);
      }
    } finally {
      _heldPositionDuringPitchTransition = null;
      _heldDurationDuringPitchTransition = null;
      _lastSeekTarget = resumePosition;
      _seekFilterUntil = DateTime.now().add(_kSeekStaleWindow);
      if (mounted) {
        state = state.copyWith(
          position: resumePosition,
          duration: resumeDuration != Duration.zero
              ? resumeDuration
              : state.duration,
        );
      }
    }
  }

  Future<void> _dropPlayerIfPitchConfigurationChanged() async {
    final player = _player;
    if (player == null ||
        _playerPitchEnabled == _shouldEnablePitchForCurrentState) {
      return;
    }
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _player = null;
    _playerPitchEnabled = false;
    _appliedPitchSemitones = 0;
    await _releaseMediaKitPlayer(player);
  }

  Future<void> _switchLesson(int delta) async {
    final ids = state.args.allLessonIds;
    if (ids.isEmpty) {
      return;
    }
    final currentIndex = ids.indexOf(state.args.id);
    if (currentIndex == -1) {
      return;
    }
    final nextIndex = (currentIndex + delta) % ids.length;
    final safeIndex = nextIndex < 0 ? ids.length - 1 : nextIndex;
    final nextId = ids[safeIndex];
    final nextArgs = MusicPlayPageArgs(
      id: nextId,
      type: state.args.type,
      allLessonIds: ids,
      // 切到下一节时保留入口侧的 autoPlayNext / closedByDefault 语义，否则
      // 节奏 / 旋律 自动跳到下一节后会因为 args 重置而失去自动续播能力。
      autoPlayNext: state.args.autoPlayNext,
      closedByDefault: state.args.closedByDefault,
    );
    state = state.copyWith(args: nextArgs);
    await loadDetail(nextId, preserveShowAnswer: false);
  }

  Future<void> _openActiveTrack({required bool play}) {
    final previous = _openTrackChain;
    Future<void> run() => _openActiveTrackImpl(play: play);
    final task = previous != null
        ? previous.then((_) => run()).catchError((_) => run())
        : run();
    _openTrackChain = task.whenComplete(() {
      if (identical(_openTrackChain, task)) {
        _openTrackChain = null;
      }
    });
    return task;
  }

  Future<void> _openActiveTrackImpl({required bool play}) async {
    if (_disposed) {
      return;
    }
    final track = state.activeTrack;
    if (track == null || track.url.isEmpty) {
      return;
    }

    // 每次进入即抢占 ticket；之后任何一个 await 之后都比一下当前 ticket，
    // 不一致就当成"自己已被新一次 open 取代"处理。
    final ticket = ++_openTicket;
    bool isStale() => _disposed || ticket != _openTicket;

    try {
      if (isStale()) return;
      if (_isIosNative && _shouldEnablePitchForCurrentState) {
        await _ensureIosMediaKitSessionForLongAudio();
        unawaited(
          AppAudioService.recoverPianoAfterMediaKit(
            ensurePrepared: () => _pianoEngine.ensurePianoInitialized(),
          ),
        );
      }
      if (isStale()) return;
      await _dropPlayerIfPitchConfigurationChanged();
      if (isStale()) return;
      final player = _ensurePlayer();
      debugPrint('MusicPlay audio open: ${track.url}');
      _endScrubUiHold(immediate: true);
      if (player.usesPitchTransport) {
        await player.ensureOutputMuted();
      } else if (_isIosNative && !player.usesNativeIosPlayback) {
        await _setPlayerVolumeSafe(player, 0);
      }
      await player.open(track.url, play: play);
      if (isStale()) {
        // 页面已销毁或已被新 open 取代：勿再 setRate/setPitch，避免 mpv abort。
        return;
      }
      try {
        await player.setRate(state.speed);
      } catch (_) {}
      await _applyPitchToPlayer(player, muteGuard: false);
      if (player.usesPitchTransport && play) {
        await player.restoreOutputAudible();
      } else if (_usesMpvOnIos(player) && play) {
        await _fadePlayerVolume(
          player,
          to: _kPlayerNormalVolume,
          from: 0,
          steps: _kIosClickFadeSteps,
          stepDelay: _kIosClickFadeStepDelay,
        );
      }
      if (!isStale()) {
        await _attachVisualizerForTrack(track.url, playing: play);
      }
    } catch (error) {
      if (isStale()) return;
      debugPrint('MusicPlay audio load failed: $error');
      if (mounted) {
        state = state.copyWith(errorMessage: '音频加载失败，请稍后重试');
      }
    }
  }

  /// 有序释放 mpv：pause → stop → dispose，并与其它页面的释放串行排队。
  Future<void> _releaseMediaKitPlayer(MusicPlayAudioPlayer player) async {
    final waitFor = _mediaKitTeardownChain;
    final task = _runMediaKitPlayerRelease(player);
    _mediaKitTeardownChain = task;
    if (waitFor != null) {
      try {
        await waitFor;
      } catch (_) {}
    }
    try {
      await task;
    } finally {
      if (identical(_mediaKitTeardownChain, task)) {
        _mediaKitTeardownChain = null;
      }
    }
  }

  Future<void> _runMediaKitPlayerRelease(MusicPlayAudioPlayer player) async {
    if (player.usesPitchTransport) {
      try {
        await player.ensureOutputMuted();
      } catch (_) {}
    } else if (_usesMpvOnIos(player)) {
      try {
        await _fadePlayerVolume(
          player,
          to: 0,
          steps: _kIosClickFadeSteps,
          stepDelay: _kIosClickFadeStepDelay,
        );
      } catch (_) {}
    }
    try {
      await player.pause().timeout(_kMpvTeardownStepTimeout, onTimeout: () {});
    } catch (_) {}
    if (_isIosNative && !player.usesNativeIosPlayback) {
      await Future<void>.delayed(_kIosPauseDrainDelay);
    }
    try {
      await player.stop().timeout(_kMpvTeardownStepTimeout, onTimeout: () {});
    } catch (_) {}
    try {
      await player.dispose().timeout(
        _kMpvTeardownStepTimeout,
        onTimeout: () {},
      );
    } catch (_) {}
  }

  MusicPlayAudioPlayer _ensurePlayer() {
    if (_disposed) {
      throw StateError('MusicPlayController disposed');
    }
    final current = _player;
    if (current != null) {
      return current;
    }
    // 页内支持升降调时必须打开 pitch，否则 [Player.setPitch] 无效。
    // 无升降调能力的教材页关闭 pitch，保留 mpv 默认音高校正，听感更稳。
    final enablePitch = _shouldEnablePitchForCurrentState;
    final player = MusicPlayAudioPlayer(enablePitch: enablePitch);
    _playerPitchEnabled = enablePitch;
    _appliedPitchSemitones = 0;
    _player = player;
    _bindPlayerStreams(player);
    return player;
  }

  void _bindPlayerStreams(MusicPlayAudioPlayer player) {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();

    _positionSub = player.stream.position.listen((position) {
      if (!mounted) {
        return;
      }
      if (_heldPositionDuringPitchTransition != null) {
        return;
      }
      // seek 触发后短暂窗口（350ms）内，mpv 仍可能把"还没跳到目标"前的
      // 旧位置流回来。如果直接 copy 进 state，UI thumb 会看到"先回弹
      // 再前进"。这里把距离目标超过 500ms 的事件丢弃；一旦看到接近
      // 目标的位置就立刻解除过滤，避免误伤后续真实的播放进度。
      final filterUntil = _seekFilterUntil;
      final target = _lastSeekTarget;
      if (filterUntil != null && target != null) {
        if (DateTime.now().isBefore(filterUntil)) {
          final diffMs = (position.inMilliseconds - target.inMilliseconds)
              .abs();
          if (diffMs > _kSeekStaleDiffMs) {
            return;
          }
          _seekFilterUntil = null;
        } else {
          _seekFilterUntil = null;
        }
      }
      state = state.copyWith(position: position);
      _maybeSyncVisualizerPosition(position);
    });
    _durationSub = player.stream.duration.listen((duration) {
      if (!mounted) {
        return;
      }
      if (_heldDurationDuringPitchTransition != null) {
        return;
      }
      state = state.copyWith(duration: duration);
    });
    _playingSub = player.stream.playing.listen((playing) {
      if (!mounted) {
        return;
      }
      if (_playbackToggleInFlight > 0) {
        return;
      }
      // seek 过程中 mpv / Web 可能短暂上报 paused，不抢 UI 的播放态。
      if (_scrubbing && !playing && state.isPlaying) {
        return;
      }
      state = state.copyWith(isPlaying: playing);
      unawaited(_syncVisualizerTransport());
      if (_isIosNative && playing) {
        // iOS 主播放器就绪后补一次同步，避免探针引擎先于 just_audio 启动。
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (!_disposed && mounted && state.isPlaying) {
            unawaited(_syncVisualizerTransport());
          }
        });
      }
    });
    _completedSub = player.stream.completed.listen((completed) async {
      if (completed && mounted) {
        await _handleTrackCompleted();
      }
    });
  }

  /// 1.0 `musicPlay`：视唱 / 听写 在当前音频**完整播完**时上报一次
  /// `/app/user/textbookRecordSave`。
  ///
  /// - 视唱：教材 `type == 1`，或视唱多题入口透传的 `args.type == 3`
  /// - 听写：教材 `type == 3`（听写列表 / 搜索入口通常不带路由 type）
  /// - 乐理走 [TheoryController.markAnswerOpened]（查看答案时上报），不在此页处理
  bool _shouldSaveStudyRecord(MusicPlayDetail detail) {
    if (state.args.type == 3) {
      return true;
    }
    return detail.type == 1 || detail.type == 3;
  }

  void _maybeSaveStudyRecord(MusicPlayDetail detail) {
    if (_recordSaved || !_shouldSaveStudyRecord(detail)) {
      return;
    }
    _recordSaved = true;
    unawaited(repository.saveStudyRecord(detail.id));
  }

  Future<void> _handleTrackCompleted() async {
    if (_disposed) return;
    final detail = state.detail;
    if (detail == null) {
      return;
    }

    _maybeSaveStudyRecord(detail);

    final tracks = detail.tracks;
    final mode = state.playMode;

    // 单曲循环：始终回到当前曲——优先级最高，UI 显式选择，与入口无关。
    if (mode == MusicPlayMode.single) {
      await selectTrack(state.activeTrackIndex);
      return;
    }

    // 多 track 才有"列表/随机循环"的语义；_LoopModeChip 也只在 tracks > 1
    // 时显示，所以这里能进来必然是用户主动选的循环模式，应该一直循环下去，
    // 不受 autoPlayNext 影响（autoPlayNext 只决定"是否跨课跳到下一节"）。
    if (tracks.length > 1) {
      if (mode == MusicPlayMode.shuffle) {
        // 随机循环：永远在课内 N 条 track 中随机抽一条不同的继续播。
        final nextIdx = _shuffleNextIndex(
          state.activeTrackIndex,
          tracks.length,
        );
        state = state.copyWith(
          activeTrackIndex: nextIdx,
          activeImageIndex: 0,
          position: Duration.zero,
          duration: Duration.zero,
          frequencyBands: const <double>[],
        );
        await _openActiveTrack(play: true);
        return;
      }

      if (mode == MusicPlayMode.sequence) {
        final nextIndex = state.activeTrackIndex + 1;
        if (nextIndex < tracks.length) {
          // 课内还有下一条，照常推进。
          state = state.copyWith(
            activeTrackIndex: nextIndex,
            activeImageIndex: 0,
            position: Duration.zero,
            duration: Duration.zero,
            frequencyBands: const <double>[],
          );
          await _openActiveTrack(play: true);
          return;
        }
        // 已经播到本节最后一条 track。两种走向：
        //  - autoPlayNext + 有 allLessonIds + 不是最后一节  → 跳到下一节自动播；
        //  - 否则                                          → 回到本节第一条
        //    track 继续循环（这就是 "列表循环" 的字面语义，跟 enum doc 保持一致）。
        if (state.args.autoPlayNext && state.args.allLessonIds.isNotEmpty) {
          final ids = state.args.allLessonIds;
          final currentIdx = ids.indexOf(state.args.id);
          if (currentIdx >= 0 && currentIdx < ids.length - 1) {
            await _switchLesson(1);
            final player = _player;
            if (player != null) {
              await _resumePlayer(player);
            }
            return;
          }
        }
        state = state.copyWith(
          activeTrackIndex: 0,
          activeImageIndex: 0,
          position: Duration.zero,
          duration: Duration.zero,
          frequencyBands: const <double>[],
        );
        await _openActiveTrack(play: true);
        return;
      }
    }

    // 单 track 课程 + autoPlayNext：跨课接力（节奏 / 旋律典型用法）。
    if (state.args.autoPlayNext && state.args.allLessonIds.isNotEmpty) {
      final ids = state.args.allLessonIds;
      final currentIdx = ids.indexOf(state.args.id);
      if (currentIdx >= 0 && currentIdx < ids.length - 1) {
        await _switchLesson(1);
        final player = _player;
        if (player != null) {
          await _resumePlayer(player);
        }
        return;
      }
    }

    // 默认收尾：seek 回 0 + pause。涵盖单 track 单课、试题等"播完即停"的入口。
    final player = _player;
    if (player != null) {
      try {
        await _pausePlayerSmooth(player);
        await player.seek(
          Duration.zero,
          restoreAudible: false,
        );
        if (!player.usesPitchTransport) {
          await _setPlayerVolumeSafe(player, _kPlayerNormalVolume);
        }
      } catch (_) {}
    }
    if (mounted) {
      state = state.copyWith(isPlaying: false, position: Duration.zero);
    }
  }

  bool _hasVipAccess(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return false;
    }
    // myInfo 接口返回结构：{ user: { vipExpireDate, ... }, ... }
    final user = data['user'];
    final source = user is Map<String, dynamic> ? user : data;
    final raw = source['vipExpireDate']?.toString() ?? '';
    if (raw.trim().isEmpty) {
      return false;
    }
    final expire = DateTime.tryParse(raw.replaceAll('/', '-'));
    if (expire == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vipDate = DateTime(expire.year, expire.month, expire.day);
    return !vipDate.isBefore(today);
  }

  MusicPlayDetail _parseDetail(Map<String, dynamic> raw) {
    final id = int.tryParse(raw['id']?.toString() ?? '') ?? 0;
    final type = int.tryParse(raw['type']?.toString() ?? '') ?? 0;
    final title = raw['title']?.toString().trim().isNotEmpty == true
        ? raw['title'].toString().trim()
        : '未命名教材';
    final coverUrl = _resolveMediaUrl(
      raw['img']?.toString() ??
          raw['cover']?.toString() ??
          raw['icon']?.toString() ??
          '',
    );

    int? firstMenu;
    final fm = raw['firstMenu'];
    if (fm != null) {
      if (fm is int) {
        firstMenu = fm;
      } else {
        firstMenu = int.tryParse(fm.toString());
      }
    }

    final shortText1 = raw['shortText1']?.toString().trim() ?? '';
    final shortText2 = raw['shortText2']?.toString().trim() ?? '';
    // 旧字段 [subtitle] 优先用 shortText2（列表的"主副标题"），落空时再
    // 兜底 shortText1。各处分享 / 列表场景沿用这一兼容值；播放器条副标题
    // 走 _resolveSecondaryTitle 的更细粒度逻辑（多曲目/单曲目分别处理）。
    final compatSubtitle = shortText2.isNotEmpty ? shortText2 : shortText1;

    return MusicPlayDetail(
      id: id,
      type: type,
      title: title,
      subtitle: compatSubtitle,
      shortText1: shortText1,
      shortText2: shortText2,
      coverUrl: coverUrl,
      favorite:
          raw['isFavorite'] == true ||
          raw['isFavorite']?.toString() == '1' ||
          raw['favorite']?.toString() == '1',
      vipOnly: raw['vip']?.toString() == '1',
      questionImages: _parseImageList(raw['img2']),
      answerImages: _parseImageList(raw['img1']),
      tracks: _parseTracks(raw['file1']),
      longTextHtml: raw['longText1']?.toString() ?? '',
      firstMenu: firstMenu,
    );
  }

  List<MusicPlayTrack> _parseTracks(dynamic raw) {
    final values = _normalizeToList(raw);
    if (values.isEmpty) {
      final fallbackUrl = _extractUrl(raw);
      return fallbackUrl.isEmpty
          ? const <MusicPlayTrack>[]
          : <MusicPlayTrack>[MusicPlayTrack(url: fallbackUrl, title: '主音频')];
    }

    final tracks = <MusicPlayTrack>[];
    for (var i = 0; i < values.length; i++) {
      final entry = values[i];
      final url = _extractUrl(entry);
      if (url.isEmpty) continue;
      final title = _extractTitle(entry);
      tracks.add(
        MusicPlayTrack(
          url: url,
          title: (title == null || title.isEmpty) ? '音频 ${i + 1}' : title,
        ),
      );
    }
    return tracks;
  }

  List<String> _parseImageList(dynamic raw) {
    final values = _normalizeToList(raw);
    final result = <String>[];
    for (final entry in values) {
      final url = _extractUrl(entry);
      if (url.isNotEmpty) {
        result.add(url);
      }
    }
    return result;
  }

  /// 将 `file1` 单项规整为 Map（兼容 JSON 字符串：`{"url":"…","filename":"…"}`）。
  Map<String, dynamic>? _entryAsMap(dynamic entry) {
    if (entry is Map) {
      return entry.map((key, value) => MapEntry(key.toString(), value));
    }
    final text = entry?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        // 落到 Dart 风格字段解析。
      }
      if (text.startsWith('{') && text.endsWith('}')) {
        final filename = RegExp(
          r'filename:\s*([^,}]+)',
        ).firstMatch(text)?.group(1)?.trim();
        final url = RegExp(
          r'url:\s*([^,}\s][^,}]*)',
        ).firstMatch(text)?.group(1)?.trim();
        if (filename != null || url != null) {
          return <String, dynamic>{'filename': ?filename, 'url': ?url};
        }
      }
    }
    return null;
  }

  /// 解析 `filename`（抽屉列表 / 当前曲目副标题），与 [_extractUrl] 对应。
  String? _extractTitle(dynamic entry) {
    final map = _entryAsMap(entry);
    if (map == null) {
      return null;
    }
    final raw = map['filename']?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  /// 从一项资源中提取一个完整的可访问 URL。
  ///
  /// 兼容三类后端返回：
  ///  - 标准 JSON：`{"url":"https://...","path":"app/upload/..."}`
  ///  - 后端 `Map.toString()` 序列化（key/value 都没有引号）：
  ///    `{path: app/upload/..., url: https://...}`
  ///  - 纯字符串（绝对 URL 或相对 path）。
  ///
  /// 优先取已经带域名的 `url`，否则把 `path` 等字段交给 [MediaUrl.resolve]
  /// 拼接 fileServerUrl，避免在域名后再拼一段 Map 调试字符串。
  String _extractUrl(dynamic entry) {
    if (entry == null) return '';

    final map = _entryAsMap(entry);
    if (map != null) {
      final url = (map['url'] ?? map['fileUrl'])?.toString().trim() ?? '';
      if (url.isNotEmpty) return _resolveMediaUrl(url);
      final path =
          (map['path'] ?? map['img'] ?? map['filePath'])?.toString().trim() ??
          '';
      if (path.isNotEmpty) return _resolveMediaUrl(path);
      return '';
    }

    final text = entry.toString().trim();
    if (text.isEmpty) return '';

    return _resolveMediaUrl(text);
  }

  List<dynamic> _normalizeToList(dynamic raw) {
    if (raw == null) {
      return const <dynamic>[];
    }
    final decoded = _decodeJsonLike(raw);
    if (decoded is List) {
      if (decoded.length == 1 && decoded.first is List) {
        return List<dynamic>.from(decoded.first as List);
      }
      return List<dynamic>.from(decoded);
    }
    if (decoded is Map) {
      return <dynamic>[decoded];
    }
    final text = raw.toString().trim();
    if (text.isEmpty) {
      return const <dynamic>[];
    }
    return <dynamic>[raw];
  }

  dynamic _decodeJsonLike(dynamic value) {
    if (value is List || value is Map) {
      return value;
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return value;
    }
    if (!(text.startsWith('{') || text.startsWith('['))) {
      return value;
    }
    try {
      return jsonDecode(text);
    } catch (_) {
      return value;
    }
  }

  String _resolveMediaUrl(String raw) => MediaUrl.resolve(raw);

  bool _defaultShowAnswer(int? pageType, MusicPlayDetail detail) {
    // 试题（answerEnd2）听写 / 乐理：路由参数 `closedByDefault: true` 时默认
    // 先展示题面；「视唱」分类不传该参数，走下方 pageType / 资源逻辑。
    if (state.args.closedByDefault) {
      return false;
    }
    if (pageType == 3) {
      return true;
    }
    if (pageType == 2) {
      return detail.type == 4 || detail.answerImages.isNotEmpty;
    }
    return detail.answerImages.isNotEmpty;
  }

  void _ensureVisualizerListener() {
    _visualizer ??= MusicPlayAudioVisualizer();
    _bandsSub ??= _visualizer!.bands.listen((bands) {
      if (!mounted || _disposed || !state.isPlaying) {
        return;
      }
      if (bands.isEmpty) {
        return;
      }
      state = state.copyWith(frequencyBands: bands);
    });
  }

  void _setVisualizerPausedState() {
    if (!mounted || _disposed) {
      return;
    }
    state = state.copyWith(
      frequencyBands: buildMusicPlayVisualizerRestBands(),
    );
  }

  Future<void> _attachVisualizerForTrack(
    String url, {
    required bool playing,
  }) async {
    if (_disposed || url.isEmpty) {
      return;
    }
    _ensureVisualizerListener();
    final player = _player;
    try {
      await _visualizer!.attach(
        url: url,
        androidAudioSessionId: player?.androidAudioSessionId,
      );
      _bindAndroidSessionStream(player);
      await _visualizer!.syncTransport(
        playing: playing,
        positionMs: state.position.inMilliseconds,
      );
      if (!playing) {
        _setVisualizerPausedState();
      }
    } catch (error) {
      debugPrint('MusicPlay visualizer attach failed: $error');
    }
  }

  void _bindAndroidSessionStream(MusicPlayAudioPlayer? player) {
    _androidSessionSub?.cancel();
    _androidSessionSub = null;
    final stream = player?.androidAudioSessionIdStream;
    if (stream == null) {
      return;
    }
    _androidSessionSub = stream.listen((sessionId) {
      if (sessionId == null) {
        return;
      }
      unawaited(_visualizer?.updateAndroidSession(sessionId));
    });
  }

  Future<void> _syncVisualizerTransport() async {
    final visualizer = _visualizer;
    if (visualizer == null || _disposed) {
      return;
    }
    try {
      await visualizer.syncTransport(
        playing: state.isPlaying,
        positionMs: state.position.inMilliseconds,
      );
    } catch (_) {}
  }

  void _maybeSyncVisualizerPosition(Duration position) {
    if (!state.isPlaying) {
      return;
    }
    final now = DateTime.now();
    if (_lastVisualizerSync != null &&
        now.difference(_lastVisualizerSync!) <
            const Duration(milliseconds: 900)) {
      return;
    }
    _lastVisualizerSync = now;
    unawaited(_syncVisualizerTransport());
  }

  @override
  void dispose() {
    // 关键：_disposed + _openTicket 让 in-flight 的 open 在 await 后不再碰 mpv；
    // 异步链在后台先等 open 结束，再 pause→stop→dispose，避免 libmpv abort。
    _releaseForegroundHandoff();
    _disposed = true;
    _openTicket++;
    _endScrubUiHold(immediate: true);

    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _bandsSub?.cancel();
    _bandsSub = null;
    _androidSessionSub?.cancel();
    _androidSessionSub = null;
    final visualizer = _visualizer;
    _visualizer = null;
    unawaited(visualizer?.dispose());

    final openChain = _openTrackChain;
    final player = _player;
    _player = null;
    _playerPitchEnabled = false;
    _appliedPitchSemitones = 0;

    _pianoEngine.stopAllImmediately();
    unawaited(() async {
      if (openChain != null) {
        try {
          await openChain.timeout(_kMpvOpenDrainTimeout);
        } catch (_) {}
      }
      if (player != null) {
        await _releaseMediaKitPlayer(player);
      }
      try {
        await PageAudioLifecycle.leavePage(pianoEngine: _pianoEngine);
        await _pianoEngine.dispose();
      } catch (_) {}
    }());
    super.dispose();
  }
}
