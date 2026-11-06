import 'package:flutter/foundation.dart';

import '../config/smart_sight_singing_config.dart';
import '../audio/ktv_scoring.dart';
import '../audio/midi_sight_singing_service.dart';
import '../audio/pitch_track.dart';

enum SightSingingImportFormat { midi, musicXml }

enum SightSingingStage {
  /// 初始：尚未导入音频。
  idle,

  /// 正在解码 + 离线分析音高。
  analyzing,

  /// 解析完成，等待用户选择主旋律轨。
  selectTrack,

  /// 分析完成，等待开始跟唱。
  ready,

  /// 用户已点「开始跟唱」，正在申请权限 / 开麦 / 预热（UI 即时反馈）。
  preparing,

  /// 跟唱前倒计时（3→2→1）。
  countdown,

  /// 正在跟唱（播放 + 录音）。
  singing,

  /// 演唱结束，等待用户重听 / 重唱。
  finished,
}

/// 演唱过程中沿时间轴累积的实测音高点（用于绘制 KTV 拖尾）。
class UserPitchPoint {
  const UserPitchPoint({
    required this.timeMs,
    required this.midi,
    required this.amplitude,
    required this.cents,
  });

  /// 相对曲目开始的时间（毫秒）。
  final int timeMs;

  /// 用户实测 MIDI。-1 表示无音高（静音/未达阈值）。
  final double midi;

  /// 该帧响度（0~1），UI 可作圆点大小映射。
  final double amplitude;

  /// 与参考音的偏离 cents；无参考音时为 `double.nan`。
  final double cents;

  bool get pitched => midi >= 0;
}

@immutable
class SightSingingState {
  const SightSingingState({
    this.importFormat = SightSingingImportFormat.midi,
    this.musicXmlContent,
    this.musicXmlCursorOnsetMs = const <int>[],
    this.stage = SightSingingStage.idle,
    this.audioPath,
    this.audioName,
    this.analyzingProgress = 0,
    this.errorMessage,
    this.track,
    this.trackSummaries = const <MidiTrackSummary>[],
    this.selectedTrackIndex,
    this.melodyTrackIndex,
    this.countdownSeconds = 0,
    this.playbackMs = 0,
    this.playbackLeadInMs = 0,
    this.userPoints = const <UserPitchPoint>[],
    this.currentUserMidi = -1,
    this.currentUserAmplitude = 0,
    this.currentScore = 0,
    this.hitCount = 0,
    this.scoredCount = 0,
    this.combo = 0,
    this.visualOnlyMode = false,
    this.scoreSightReadingMode = true,
    this.scoringStandardCents =
        SmartSightSingingScoringConfig.defaultStandardCents,
    this.isPreviewPlaying = false,
    this.isPreviewLoading = false,
    this.isStoppingSinging = false,
    this.debugPanelVisible = false,
    this.lastFrequencyHz = 0,
    this.lastFrameConfidence = 0,
    this.lastSourceLabel = '',
    this.lastRefMidi = -1,
    this.lastPlaybackMidi = -1,
    this.lastCents = double.nan,
    this.completedNoteScores = const <KtvNoteScore>[],
    this.textbookId,
    this.favorite = false,
    this.shortText1,
  });

  final SightSingingStage stage;

  /// 当前导入格式：MIDI 或 MusicXML。
  final SightSingingImportFormat importFormat;

  /// MusicXML 原文（仅 [importFormat] 为 musicXml 时有值，供 OSMD 渲染）。
  final String? musicXmlContent;

  /// OSMD 光标逐步对齐用 onset（含延音线后续音头）；KTV 参考轨仍用 [track]。
  final List<int> musicXmlCursorOnsetMs;

  /// 当前导入的音频路径（本地/缓存）。
  final String? audioPath;

  /// 用户友好的曲目名（取文件名）。
  final String? audioName;

  /// 0~1，离线分析进度（暂用粗略阶段，UI 可绑动画）。
  final double analyzingProgress;

  /// 可视化的错误消息（同时驱动 toast）。
  final String? errorMessage;

  /// 离线分析结果。
  final PitchTrack? track;

  /// 解析后各轨摘要（`selectTrack` 阶段使用）。
  final List<MidiTrackSummary> trackSummaries;

  /// 用户在选轨界面高亮的轨道（1-based）。
  final int? selectedTrackIndex;

  /// 已确认的主旋律轨（1-based）。
  final int? melodyTrackIndex;

  /// 跟唱前倒计时剩余秒数（`countdown` 阶段）。
  final int countdownSeconds;

  /// 当前播放进度（毫秒）。
  final int playbackMs;

  /// MusicXML 预备段占用时长（标准音 + 节拍器，毫秒）；进度条展示时需从
  /// [playbackMs] 中扣除。
  final int playbackLeadInMs;

  /// 已记录的用户音高点（按时间升序，最多保留最近 600 个 ≈ 14s）。
  final List<UserPitchPoint> userPoints;

  /// 当前用户最新一帧 MIDI。
  final double currentUserMidi;

  /// 当前用户最新一帧响度（0~1）。
  final double currentUserAmplitude;

  /// 实时累计得分（0~100）。
  final int currentScore;

  /// 已结算音符中 Good 及以上次数。
  final int hitCount;

  /// 已结算音符总数。
  final int scoredCount;

  /// 当前连击（连续 Good 及以上）。
  final int combo;

  /// iPad 等设备：跟唱时不播放扬声器伴奏，仅看音符条（可选开关）。
  final bool visualOnlyMode;

  /// 谱例视唱：用五线谱视图替代 KTV 音高轨展示参考旋律。
  final bool scoreSightReadingMode;

  /// 音准命中容差，单位 cents。默认 90 cents 内算 Good/命中。
  final double scoringStandardCents;

  /// 就绪态试听旋律中（含乐观态：点击后先为 true，音频就绪后再真正播放）。
  final bool isPreviewPlaying;

  /// 试听按钮 loading：会话切换 / 钢琴 reclaim / 起播尚未完成。
  final bool isPreviewLoading;

  /// 停止跟唱后的收尾（采集停止、播放暂停）；界面已切到 finished/ready。
  final bool isStoppingSinging;

  /// 调试面板可见性（覆盖在主页右侧）。
  final bool debugPanelVisible;

  /// 实时麦克风最近一帧元信息（仅 debug 面板使用）。
  final double lastFrequencyHz;
  final double lastFrameConfidence;
  final String lastSourceLabel;
  final double lastRefMidi;
  final double lastPlaybackMidi;
  final double lastCents;

  /// 演唱结束后的逐音详情（finished 阶段展示在底部）。
  final List<KtvNoteScore> completedNoteScores;

  /// 当前教材 id（用于收藏接口）。
  final int? textbookId;

  /// 是否已收藏。
  final bool favorite;

  /// 教材详情 `shortText1`，播放条副标题。
  final String? shortText1;

  bool get hasTrack => track != null && !(track!.isEmpty);

  bool get isBusy =>
      stage == SightSingingStage.analyzing ||
      stage == SightSingingStage.preparing ||
      stage == SightSingingStage.countdown;

  bool get isSinging => stage == SightSingingStage.singing;

  /// 底部主操作是否应禁用（准备中、倒计时与跟唱中互斥）。
  bool get controlsLocked =>
      stage == SightSingingStage.preparing ||
      stage == SightSingingStage.countdown ||
      stage == SightSingingStage.singing ||
      isStoppingSinging;

  bool get isSelectingTrack => stage == SightSingingStage.selectTrack;

  bool get usesOsmdScore =>
      importFormat == SightSingingImportFormat.musicXml &&
      (musicXmlContent?.trim().isNotEmpty ?? false);

  SightSingingState copyWith({
    SightSingingStage? stage,
    SightSingingImportFormat? importFormat,
    Object? musicXmlContent = _sentinel,
    List<int>? musicXmlCursorOnsetMs,
    Object? audioPath = _sentinel,
    Object? audioName = _sentinel,
    double? analyzingProgress,
    Object? errorMessage = _sentinel,
    Object? track = _sentinel,
    List<MidiTrackSummary>? trackSummaries,
    Object? selectedTrackIndex = _sentinel,
    Object? melodyTrackIndex = _sentinel,
    int? countdownSeconds,
    int? playbackMs,
    int? playbackLeadInMs,
    List<UserPitchPoint>? userPoints,
    double? currentUserMidi,
    double? currentUserAmplitude,
    int? currentScore,
    int? hitCount,
    int? scoredCount,
    int? combo,
    bool? visualOnlyMode,
    bool? scoreSightReadingMode,
    double? scoringStandardCents,
    bool? isPreviewPlaying,
    bool? isPreviewLoading,
    bool? isStoppingSinging,
    bool? debugPanelVisible,
    double? lastFrequencyHz,
    double? lastFrameConfidence,
    String? lastSourceLabel,
    double? lastRefMidi,
    double? lastPlaybackMidi,
    double? lastCents,
    List<KtvNoteScore>? completedNoteScores,
    Object? textbookId = _sentinel,
    bool? favorite,
    Object? shortText1 = _sentinel,
  }) {
    return SightSingingState(
      stage: stage ?? this.stage,
      importFormat: importFormat ?? this.importFormat,
      musicXmlContent: identical(musicXmlContent, _sentinel)
          ? this.musicXmlContent
          : musicXmlContent as String?,
      musicXmlCursorOnsetMs:
          musicXmlCursorOnsetMs ?? this.musicXmlCursorOnsetMs,
      audioPath: identical(audioPath, _sentinel)
          ? this.audioPath
          : audioPath as String?,
      audioName: identical(audioName, _sentinel)
          ? this.audioName
          : audioName as String?,
      analyzingProgress: analyzingProgress ?? this.analyzingProgress,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      track: identical(track, _sentinel) ? this.track : track as PitchTrack?,
      trackSummaries: trackSummaries ?? this.trackSummaries,
      selectedTrackIndex: identical(selectedTrackIndex, _sentinel)
          ? this.selectedTrackIndex
          : selectedTrackIndex as int?,
      melodyTrackIndex: identical(melodyTrackIndex, _sentinel)
          ? this.melodyTrackIndex
          : melodyTrackIndex as int?,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      playbackMs: playbackMs ?? this.playbackMs,
      playbackLeadInMs: playbackLeadInMs ?? this.playbackLeadInMs,
      userPoints: userPoints ?? this.userPoints,
      currentUserMidi: currentUserMidi ?? this.currentUserMidi,
      currentUserAmplitude: currentUserAmplitude ?? this.currentUserAmplitude,
      currentScore: currentScore ?? this.currentScore,
      hitCount: hitCount ?? this.hitCount,
      scoredCount: scoredCount ?? this.scoredCount,
      combo: combo ?? this.combo,
      visualOnlyMode: visualOnlyMode ?? this.visualOnlyMode,
      scoreSightReadingMode:
          scoreSightReadingMode ?? this.scoreSightReadingMode,
      scoringStandardCents: scoringStandardCents ?? this.scoringStandardCents,
      isPreviewPlaying: isPreviewPlaying ?? this.isPreviewPlaying,
      isPreviewLoading: isPreviewLoading ?? this.isPreviewLoading,
      isStoppingSinging: isStoppingSinging ?? this.isStoppingSinging,
      debugPanelVisible: debugPanelVisible ?? this.debugPanelVisible,
      lastFrequencyHz: lastFrequencyHz ?? this.lastFrequencyHz,
      lastFrameConfidence: lastFrameConfidence ?? this.lastFrameConfidence,
      lastSourceLabel: lastSourceLabel ?? this.lastSourceLabel,
      lastRefMidi: lastRefMidi ?? this.lastRefMidi,
      lastPlaybackMidi: lastPlaybackMidi ?? this.lastPlaybackMidi,
      lastCents: lastCents ?? this.lastCents,
      completedNoteScores: completedNoteScores ?? this.completedNoteScores,
      textbookId: identical(textbookId, _sentinel)
          ? this.textbookId
          : textbookId as int?,
      favorite: favorite ?? this.favorite,
      shortText1: identical(shortText1, _sentinel)
          ? this.shortText1
          : shortText1 as String?,
    );
  }
}

const Object _sentinel = Object();
