import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:music_xml/music_xml.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/audio/app_audio_service.dart';
import '../audio/ktv_scoring.dart';
import '../audio/midi_file_parser.dart';
import '../audio/midi_playback_scheduler.dart';
import '../audio/midi_sight_singing_service.dart';
import '../audio/music_xml_sight_singing_service.dart';
import '../audio/pitch_voice_gate.dart';
import '../audio/realtime_pitch_capture.dart';
import '../config/smart_sight_singing_config.dart';
import '../config/smart_sight_singing_tuning.dart';
import '../../music_companion/audio/page_audio_lifecycle.dart';
import '../../music_play/data/music_play_repository.dart';
import '../data/midi_file_picker.dart';
import '../data/music_xml_file_picker.dart';
import '../data/textbook_resource.dart';
import 'sight_singing_platform.dart';
import 'smart_sight_singing_state.dart';

final smartSightSingingControllerProvider =
    StateNotifierProvider.autoDispose<
      SmartSightSingingController,
      SightSingingState
    >((ref) {
      final ctrl = SmartSightSingingController(
        musicPlayRepository: ref.watch(musicPlayRepositoryProvider),
      );
      ref.onDispose(ctrl.shutdown);
      return ctrl;
    });

class SmartSightSingingController extends StateNotifier<SightSingingState> {
  SmartSightSingingController({MusicPlayRepository? musicPlayRepository})
    : _musicPlayRepository = musicPlayRepository,
      super(
        SightSingingState(
          visualOnlyMode: SightSingingPlatform.defaultsToVisualOnlyMode,
        ),
      ) {
    _playback = MidiPlaybackScheduler();
    _playback.muteAudioOutput = SightSingingPlatform.defaultsToVisualOnlyMode;
    _positionSub = _playback.positionMs.listen(_onPlaybackPosition);
    _completedSub = _playback.completed.listen((_) {
      if (_isPreviewSession) {
        unawaited(_stopPreview());
        return;
      }
      unawaited(_handlePlaybackEnded());
    });
    SightSingingTuning.instance.addListener(_onTuningChanged);
    unawaited(SightSingingTuning.instance.ensureLoaded());
  }

  void _onTuningChanged() {
    // tuning 改变后，把当前评分会话的容差同步到最新默认值（仅当用户未设置过
    // session 级容差时才同步；判定方式：state.scoringStandardCents 与默认值
    // 完全相等，视为「未自定义」）。
    final tuning = SightSingingTuning.instance;
    if ((state.scoringStandardCents -
                SmartSightSingingScoringConfig.defaultStandardCents)
            .abs() <
        0.01) {
      _scoringSession?.updateStandardCents(tuning.defaultStandardCents);
    }
  }

  late final MidiPlaybackScheduler _playback;
  StreamSubscription<int>? _positionSub;
  StreamSubscription<void>? _completedSub;
  StreamSubscription<RealtimePitchEvent>? _pitchSub;
  RealtimePitchCapture? _capture;
  KtvScoringSession? _scoringSession;
  MidiSightSingingBundle? _midiBundle;
  ParsedMidiFile? _parsedMidi;
  MusicXmlDocument? _parsedMusicXml;
  String? _musicXmlRawContent;
  Timer? _countdownTimer;
  var _isPreviewSession = false;
  bool _shuttingDown = false;
  var _previewInFlight = false;
  var _previewGeneration = 0;
  var _startSingingGeneration = 0;
  final MusicPlayRepository? _musicPlayRepository;

  static String _formatDebugError(
    String headline,
    Object error, [
    StackTrace? stack,
  ]) {
    final buffer = StringBuffer(headline);
    buffer.writeln();
    buffer.writeln('错误: $error');
    if (stack != null) {
      buffer.writeln();
      buffer.writeln('Stack trace:');
      buffer.write(stack);
    }
    return buffer.toString();
  }

  void reportError(String message) {
    if (!mounted) return;
    state = state.copyWith(errorMessage: message);
  }

  /// 从本地文件系统选择 MusicXML 并解析。
  Future<void> importLocalMusicXml() async {
    if (_blocksImport()) return;

    try {
      final picked = await pickLocalMusicXmlFile();
      if (picked == null) return;
      await _prepareFromMusicXmlBytes(
        bytes: picked.bytes,
        displayName: picked.name,
        sourceLabel: picked.path ?? picked.name,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: e.message);
    } on MusicXmlSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('本地 MusicXML 解析失败', e.message, stack),
        analyzingProgress: 0,
      );
    } catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('本地 MusicXML 读取失败', e, stack),
        analyzingProgress: 0,
      );
    }
  }

  /// 从本地文件系统选择 MIDI 并解析。
  Future<void> importLocalMidi() async {
    if (_blocksImport()) return;

    try {
      final picked = await pickLocalMidiFile();
      if (picked == null) return;
      await _prepareFromMidiBytes(
        bytes: picked.bytes,
        displayName: picked.name,
        sourceLabel: picked.path ?? picked.name,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: e.message);
    } on MidiSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('本地 MIDI 解析失败', e.message, stack),
        analyzingProgress: 0,
      );
    } catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('本地 MIDI 读取失败', e, stack),
        analyzingProgress: 0,
      );
    }
  }

  /// 解析内置 demo.mid，进入选轨界面（曲目名 demo）。
  Future<void> importAudio() async {
    if (_blocksImport()) return;

    try {
      final bytes = await rootBundle.load(
        SmartSightSingingImportConfig.demoMidiAssetPath,
      );
      await _prepareFromMidiBytes(
        bytes: Uint8List.sublistView(bytes),
        displayName: SmartSightSingingImportConfig.demoDisplayName,
        sourceLabel: SmartSightSingingImportConfig.demoMidiAssetPath,
      );
    } on MidiSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('解析 demo MIDI 失败', e.message, stack),
        analyzingProgress: 0,
      );
    } catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.idle,
        errorMessage: _formatDebugError('解析 demo 失败', e, stack),
        analyzingProgress: 0,
      );
    }
  }

  /// 从教材详情加载 MIDI / MusicXML 资源（列表页点选后进入）。
  Future<void> loadFromTextbook(int id) async {
    if (_blocksImport()) return;
    final repo = _musicPlayRepository;
    if (repo == null) {
      state = state.copyWith(errorMessage: '教材服务未就绪，请稍后重试。');
      return;
    }

    state = state.copyWith(
      stage: SightSingingStage.analyzing,
      analyzingProgress: 0.02,
      errorMessage: null,
      textbookId: id,
      scoreSightReadingMode: true,
    );

    try {
      final resp = await repo.getDetail(id);
      if (!mounted) return;
      if (!resp.isSuccess || resp.data is! Map) {
        state = state.copyWith(
          stage: SightSingingStage.analyzing,
          analyzingProgress: 0,
          errorMessage: resp.displayMsg.isNotEmpty
              ? resp.displayMsg
              : '教材详情加载失败',
        );
        return;
      }

      final map = Map<String, dynamic>.from(resp.data as Map);
      final url = extractTextbookResourceUrl(map);
      if (url.isEmpty || !isSupportedSightSingingResource(url)) {
        state = state.copyWith(
          stage: SightSingingStage.analyzing,
          analyzingProgress: 0,
          errorMessage: '该教材未配置可跟唱的 MIDI / MusicXML 资源',
        );
        return;
      }

      final favorite =
          map['isFavorite'] == true ||
          map['isFavorite']?.toString() == '1' ||
          map['favorite'] == true ||
          map['favorite']?.toString() == '1';
      final shortText1 = map['shortText1']?.toString().trim() ?? '';
      state = state.copyWith(
        favorite: favorite,
        shortText1: shortText1.isEmpty ? null : shortText1,
      );

      final title = map['title']?.toString();
      await _loadOnlineResource(
        url: url,
        displayName: resourceDisplayName(url: url, title: title, id: id),
      );
    } catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.analyzing,
        analyzingProgress: 0,
        errorMessage: _formatDebugError('教材资源加载失败', e, stack),
      );
    }
  }

  /// 下载并解析在线 MIDI 地址。
  Future<void> analyzeOnlineAudio(String rawUrl) async {
    if (_blocksImport()) return;

    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      state = state.copyWith(errorMessage: '请输入有效的 http/https MIDI 地址。');
      return;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      state = state.copyWith(errorMessage: '在线地址仅支持 http/https。');
      return;
    }

    final displayName = _nameFromUri(uri);
    final ext = _inferExt(displayName);
    if (ext != 'mid' && ext != 'midi') {
      state = state.copyWith(errorMessage: '在线解析仅支持 .mid / .midi 文件。');
      return;
    }

    await _loadOnlineResource(url: url, displayName: displayName);
  }

  Future<void> _loadOnlineResource({
    required String url,
    required String displayName,
  }) async {
    state = state.copyWith(
      stage: SightSingingStage.analyzing,
      audioPath: url,
      audioName: displayName,
      analyzingProgress: 0.05,
      track: null,
      trackSummaries: const <MidiTrackSummary>[],
      selectedTrackIndex: null,
      melodyTrackIndex: null,
      userPoints: const <UserPitchPoint>[],
      playbackMs: 0,
      currentScore: 0,
      hitCount: 0,
      scoredCount: 0,
      combo: 0,
      currentUserMidi: -1,
      currentUserAmplitude: 0,
      errorMessage: null,
    );

    try {
      final response = await Dio(
        BaseOptions(
          connectTimeout: SmartSightSingingImportConfig.onlineConnectTimeout,
          receiveTimeout: SmartSightSingingImportConfig.onlineReceiveTimeout,
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      ).get<List<int>>(url);
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw MidiSightSingingException('在线资源为空，请换一个地址试试。');
      }
      if (data.length > SmartSightSingingImportConfig.maxOnlineMidiBytes) {
        throw MidiSightSingingException('在线文件过大，请使用 8MB 以内的文件。');
      }

      final ext = inferSightSingingResourceExtension(
        url,
        displayName: displayName,
      );
      final bytes = Uint8List.fromList(data);
      if (ext == 'musicxml' || ext == 'xml' || ext == 'mxl') {
        await _prepareFromMusicXmlBytes(
          bytes: bytes,
          displayName: displayName,
          sourceLabel: url,
        );
        return;
      }

      await _prepareFromMidiBytes(
        bytes: bytes,
        displayName: displayName,
        sourceLabel: url,
      );
    } on MidiSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.analyzing,
        errorMessage: _formatDebugError('在线资源解析失败', e.message, stack),
        analyzingProgress: 0,
      );
    } on MusicXmlSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.analyzing,
        errorMessage: _formatDebugError('在线 MusicXML 解析失败', e.message, stack),
        analyzingProgress: 0,
      );
    } catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.analyzing,
        errorMessage: _formatDebugError('在线资源解析失败', e, stack),
        analyzingProgress: 0,
      );
    }
  }

  Future<void> _prepareFromMusicXmlBytes({
    required Uint8List bytes,
    required String displayName,
    required String sourceLabel,
  }) async {
    _parsedMidi = null;
    _parsedMusicXml = null;
    _musicXmlRawContent = null;
    _midiBundle = null;
    await _playback.stop();

    state = state.copyWith(
      stage: SightSingingStage.analyzing,
      importFormat: SightSingingImportFormat.musicXml,
      musicXmlContent: null,
      musicXmlCursorOnsetMs: const <int>[],
      audioPath: sourceLabel,
      audioName: displayName,
      analyzingProgress: 0.2,
      track: null,
      trackSummaries: const <MidiTrackSummary>[],
      selectedTrackIndex: null,
      melodyTrackIndex: null,
      userPoints: const <UserPitchPoint>[],
      playbackMs: 0,
      currentScore: 0,
      hitCount: 0,
      scoredCount: 0,
      combo: 0,
      currentUserMidi: -1,
      currentUserAmplitude: 0,
      errorMessage: null,
      scoreSightReadingMode: true,
    );

    final preview = MusicXmlSightSingingService.parseBytes(
      bytes,
      fileName: displayName,
    );
    if (!mounted) return;

    _parsedMusicXml = preview.document;
    _musicXmlRawContent = preview.rawXml;
    state = state.copyWith(
      stage: SightSingingStage.selectTrack,
      analyzingProgress: 1,
      musicXmlContent: preview.rawXml,
      trackSummaries: preview.summaries,
      selectedTrackIndex: preview.suggestedPartIndex,
    );
    await confirmSelectedTrack();
  }

  Future<void> _prepareFromMidiBytes({
    required Uint8List bytes,
    required String displayName,
    required String sourceLabel,
  }) async {
    _parsedMidi = null;
    _parsedMusicXml = null;
    _musicXmlRawContent = null;
    _midiBundle = null;
    await _playback.stop();

    state = state.copyWith(
      stage: SightSingingStage.analyzing,
      importFormat: SightSingingImportFormat.midi,
      musicXmlContent: null,
      audioPath: sourceLabel,
      audioName: displayName,
      analyzingProgress: 0.2,
      track: null,
      trackSummaries: const <MidiTrackSummary>[],
      selectedTrackIndex: null,
      melodyTrackIndex: null,
      userPoints: const <UserPitchPoint>[],
      playbackMs: 0,
      currentScore: 0,
      hitCount: 0,
      scoredCount: 0,
      combo: 0,
      currentUserMidi: -1,
      currentUserAmplitude: 0,
      errorMessage: null,
    );

    final preview = MidiSightSingingService.parsePreview(bytes);
    if (!mounted) return;

    _parsedMidi = preview.parsed;
    state = state.copyWith(
      stage: SightSingingStage.selectTrack,
      analyzingProgress: 1,
      trackSummaries: preview.summaries,
      selectedTrackIndex: preview.suggestedTrackIndex,
    );
    await confirmSelectedTrack();
  }

  void setSelectedTrack(int trackIndex) {
    if (state.stage != SightSingingStage.selectTrack) return;
    if (trackIndex < 1 || trackIndex > state.trackSummaries.length) return;
    state = state.copyWith(selectedTrackIndex: trackIndex);
  }

  /// 用户确认主旋律轨，生成参考轨并进入就绪状态。
  Future<void> confirmSelectedTrack() async {
    if (state.stage != SightSingingStage.selectTrack) return;
    final trackIndex = state.selectedTrackIndex;
    if (trackIndex == null) return;

    if (state.importFormat == SightSingingImportFormat.musicXml) {
      await _confirmSelectedMusicXmlPart(trackIndex);
      return;
    }

    final parsed = _parsedMidi;
    if (parsed == null) return;

    MidiTrackSummary? summary;
    for (final s in state.trackSummaries) {
      if (s.trackIndex == trackIndex) {
        summary = s;
        break;
      }
    }
    if (summary == null || !summary.hasNotes) {
      state = state.copyWith(errorMessage: '请选择包含音符的轨道。');
      return;
    }

    try {
      final bundle = MidiSightSingingService.buildBundle(parsed, trackIndex);
      _midiBundle = bundle;
      await _playback.prepare(
        bundle.playbackEvents,
        totalMs: bundle.totalMs,
        leadInDurationMs: bundle.totalMs - bundle.track.totalMs,
      );

      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.ready,
        track: bundle.track,
        melodyTrackIndex: trackIndex,
        trackSummaries: const <MidiTrackSummary>[],
        selectedTrackIndex: null,
        playbackMs: 0,
        playbackLeadInMs: 0,
        userPoints: const <UserPitchPoint>[],
        currentScore: 0,
        hitCount: 0,
        scoredCount: 0,
        combo: 0,
        currentUserMidi: -1,
        currentUserAmplitude: 0,
        errorMessage: null,
      );
      _scheduleReadyStagePrime();
    } on MidiSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: _formatDebugError('构建参考轨失败', e.message, stack),
      );
    }
  }

  Future<void> _confirmSelectedMusicXmlPart(int partIndex) async {
    final parsed = _parsedMusicXml;
    if (parsed == null) return;

    MidiTrackSummary? summary;
    for (final s in state.trackSummaries) {
      if (s.trackIndex == partIndex) {
        summary = s;
        break;
      }
    }
    if (summary == null || !summary.hasNotes) {
      state = state.copyWith(errorMessage: '请选择包含音符的声部。');
      return;
    }

    try {
      final bundle = MusicXmlSightSingingService.buildBundle(
        parsed,
        partIndex,
        rawXml: _musicXmlRawContent,
      );
      _midiBundle = MidiSightSingingBundle(
        track: bundle.track,
        playbackEvents: bundle.playbackEvents,
        melodyTrackIndex: bundle.melodyPartIndex,
        totalMs: bundle.totalMs,
      );
      await _playback.prepare(
        bundle.playbackEvents,
        totalMs: bundle.totalMs,
        leadInDurationMs: bundle.totalMs - bundle.track.totalMs,
      );

      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.ready,
        track: bundle.track,
        melodyTrackIndex: partIndex,
        trackSummaries: const <MidiTrackSummary>[],
        selectedTrackIndex: null,
        playbackMs: 0,
        playbackLeadInMs: bundle.totalMs - bundle.track.totalMs,
        userPoints: const <UserPitchPoint>[],
        currentScore: 0,
        hitCount: 0,
        scoredCount: 0,
        combo: 0,
        currentUserMidi: -1,
        currentUserAmplitude: 0,
        errorMessage: null,
        scoreSightReadingMode: true,
        musicXmlContent: _musicXmlRawContent,
        musicXmlCursorOnsetMs: bundle.cursorOnsetMs,
      );
      _scheduleReadyStagePrime();
    } on MusicXmlSightSingingException catch (e, stack) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: _formatDebugError('构建 MusicXML 参考轨失败', e.message, stack),
      );
    }
  }

  void cancelTrackSelection() {
    if (state.stage != SightSingingStage.selectTrack) return;
    _parsedMidi = null;
    _parsedMusicXml = null;
    _musicXmlRawContent = null;
    state = state.copyWith(
      stage: SightSingingStage.idle,
      trackSummaries: const <MidiTrackSummary>[],
      selectedTrackIndex: null,
      analyzingProgress: 0,
      musicXmlContent: null,
      musicXmlCursorOnsetMs: const <int>[],
      importFormat: SightSingingImportFormat.midi,
    );
  }

  void setVisualOnlyMode(bool enabled) {
    if (state.visualOnlyMode == enabled) return;
    _playback.muteAudioOutput = enabled;
    state = state.copyWith(visualOnlyMode: enabled);
  }

  void setScoreSightReadingMode(bool enabled) {
    if (state.scoreSightReadingMode == enabled) return;
    state = state.copyWith(scoreSightReadingMode: enabled);
  }

  void setScoringStandardCents(double cents) {
    final normalized = SmartSightSingingScoringConfig.normalizeStandardCents(
      cents,
    );
    if ((state.scoringStandardCents - normalized).abs() < 0.01) return;
    state = state.copyWith(scoringStandardCents: normalized);
  }

  void _scheduleReadyStagePrime() {
    // Deliberately no-op on iOS: background session/engine warmup can occupy
    // the same native queue that preview, start, and back actions need.
  }

  /// 试听旋律（ready / finished 均可触发；iPad 无声模式会短暂开启扬声器伴奏）。
  Future<void> previewMelody() async {
    final stage = state.stage;
    if ((stage != SightSingingStage.ready &&
            stage != SightSingingStage.finished) ||
        _midiBundle == null) {
      return;
    }
    if (state.isPreviewPlaying || _isPreviewSession || _previewInFlight) {
      stopPreview();
      return;
    }
    final generation = ++_previewGeneration;
    _previewInFlight = true;
    state = state.copyWith(
      isPreviewPlaying: true,
      isPreviewLoading: false,
      playbackMs: 0,
      userPoints: const <UserPitchPoint>[],
      currentUserMidi: -1,
      currentUserAmplitude: 0,
      errorMessage: null,
    );
    unawaited(_runPreviewStart(generation));
  }

  Future<void> _runPreviewStart(int generation) async {
    final bundle = _midiBundle!;
    final leadInMs = state.playbackLeadInMs;
    try {
      await _playback.stop();
      if (!_isCurrentPreviewGeneration(generation)) return;
      _isPreviewSession = true;
      _playback.muteAudioOutput = false;

      // 仅当原生图被切到录音会话（例如刚跟唱过）时才重建，
      // 普通连续试听不再每次重切会话，响应更快。
      if (!kIsWeb) {
        await AppAudioService.reconcilePlaybackSession();
        if (!_isCurrentPreviewGeneration(generation)) return;
        await _playback.reclaimNativeEngine();
        if (!_isCurrentPreviewGeneration(generation)) return;
      }

      await _playback.prepare(
        bundle.playbackEvents,
        totalMs: bundle.totalMs,
        leadInDurationMs: leadInMs,
      );
      if (!_isCurrentPreviewGeneration(generation)) return;
      await _playback.warmupAudioEngine();
      if (!_isCurrentPreviewGeneration(generation)) return;
      await _playback.start(muteAudio: false);
    } catch (e) {
      _isPreviewSession = false;
      _playback.muteAudioOutput = state.visualOnlyMode;
      if (!mounted) return;
      state = state.copyWith(
        isPreviewPlaying: false,
        isPreviewLoading: false,
        errorMessage: '旋律试听失败：$e',
      );
      return;
    } finally {
      _previewInFlight = false;
    }

    if (!mounted) return;
    if (!_isCurrentPreviewGeneration(generation)) return;
    state = state.copyWith(isPreviewLoading: false);
  }

  bool _isCurrentPreviewGeneration(int generation) {
    if (generation == _previewGeneration && !_shuttingDown) return true;
    _isPreviewSession = false;
    _playback.muteAudioOutput = state.visualOnlyMode;
    unawaited(_playback.stop());
    return false;
  }

  void stopPreview() {
    if (!state.isPreviewPlaying &&
        !state.isPreviewLoading &&
        !_isPreviewSession) {
      return;
    }
    _previewGeneration++;
    state = state.copyWith(
      isPreviewPlaying: false,
      isPreviewLoading: false,
      playbackMs: 0,
      userPoints: const <UserPitchPoint>[],
      currentUserMidi: -1,
      currentUserAmplitude: 0,
    );
    unawaited(_stopPreview());
  }

  Future<void> _stopPreview() async {
    _isPreviewSession = false;
    await _playback.stop();
    _playback.muteAudioOutput = state.visualOnlyMode;
    if (!mounted) return;
    state = state.copyWith(
      isPreviewPlaying: false,
      isPreviewLoading: false,
      playbackMs: 0,
      userPoints: const <UserPitchPoint>[],
      currentUserMidi: -1,
      currentUserAmplitude: 0,
    );
  }

  PitchVoiceGatePolicy get _voiceGatePolicy => state.visualOnlyMode
      ? PitchVoiceGate.visualOnly()
      : PitchVoiceGate.withAccompaniment();

  RealtimePitchCaptureProfile get _captureProfile => state.visualOnlyMode
      ? RealtimePitchCaptureProfile.visualOnly
      : RealtimePitchCaptureProfile.sightSinging;

  Future<void> startSinging() async {
    if (state.stage != SightSingingStage.ready &&
        state.stage != SightSingingStage.finished) {
      return;
    }
    if (state.track == null || _midiBundle == null) return;

    final generation = ++_startSingingGeneration;
    state = state.copyWith(
      stage: SightSingingStage.preparing,
      errorMessage: null,
      isPreviewPlaying: false,
      isPreviewLoading: false,
      playbackMs: 0,
    );
    unawaited(_runStartSinging(generation));
  }

  Future<void> _runStartSinging(int generation) async {
    if (state.isPreviewPlaying || _isPreviewSession) {
      _previewGeneration++;
      await _stopPreview();
    }
    if (!mounted || generation != _startSingingGeneration) return;
    if (state.stage != SightSingingStage.preparing) return;

    final capture = createRealtimePitchCapture(profile: _captureProfile);
    _capture = capture;
    try {
      if (!kIsWeb) {
        var hasPermission = await capture.hasPermission();
        if (!hasPermission) {
          hasPermission = await capture.requestPermission();
        }
        if (!hasPermission) {
          _capture = null;
          if (!mounted || generation != _startSingingGeneration) return;
          final status = await Permission.microphone.status;
          state = state.copyWith(
            stage: SightSingingStage.ready,
            errorMessage: status.isPermanentlyDenied
                ? '麦克风权限被拒绝，请在系统「设置 → 音乐之路 → 麦克风」中开启。'
                : '请允许麦克风权限后再开始跟唱。',
          );
          return;
        }
      }

      final pitchStream = await capture.start();
      if (!mounted || generation != _startSingingGeneration) {
        await capture.stop();
        return;
      }

      _pitchSub = pitchStream.listen(
        _onUserPitch,
        onError: (Object e, _) {
          if (!mounted) return;
          state = state.copyWith(errorMessage: '录音异常：$e');
        },
      );
    } catch (e) {
      _capture = null;
      if (!mounted || generation != _startSingingGeneration) return;
      state = state.copyWith(
        stage: SightSingingStage.ready,
        errorMessage: kIsWeb ? '麦克风启动失败，请在浏览器中允许麦克风权限后再试。' : '麦克风启动失败：$e',
      );
      return;
    }

    if (!mounted || generation != _startSingingGeneration) {
      await capture.stop();
      return;
    }

    _scoringSession = KtvScoringSession(
      track: state.track!,
      standardCents: state.scoringStandardCents,
    );
    _heldUserMidi = -1;
    _heldUserMidiUntilMs = 0;
    _latestPlaybackMs = 0;

    state = state.copyWith(
      stage: SightSingingStage.countdown,
      countdownSeconds: SmartSightSingingSessionConfig.countdownStartSeconds,
      userPoints: const <UserPitchPoint>[],
      playbackMs: 0,
      currentScore: 0,
      hitCount: 0,
      scoredCount: 0,
      combo: 0,
      currentUserMidi: -1,
      currentUserAmplitude: 0,
      errorMessage: null,
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _shuttingDown) {
        timer.cancel();
        return;
      }
      if (state.stage != SightSingingStage.countdown) {
        timer.cancel();
        return;
      }
      if (state.countdownSeconds <= 1) {
        timer.cancel();
        unawaited(_beginSingingPlayback());
        return;
      }
      state = state.copyWith(countdownSeconds: state.countdownSeconds - 1);
    });
  }

  /// 取消「准备中」或倒计时：先恢复 UI，再后台释放采集。
  Future<void> cancelPreparingOrCountdown() async {
    if (state.stage == SightSingingStage.preparing) {
      _startSingingGeneration++;
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _scoringSession = null;
      state = state.copyWith(
        stage: SightSingingStage.ready,
        countdownSeconds: 0,
        userPoints: const <UserPitchPoint>[],
        currentUserMidi: -1,
        currentUserAmplitude: 0,
      );
      unawaited(_stopCaptureSilently());
      return;
    }
    await cancelCountdown();
  }

  Future<void> _beginSingingPlayback() async {
    if (!mounted || _shuttingDown) return;
    if (_midiBundle == null) return;

    state = state.copyWith(
      stage: SightSingingStage.singing,
      countdownSeconds: 0,
    );

    _playback.muteAudioOutput = state.visualOnlyMode;
    await _playback.prepare(
      _midiBundle!.playbackEvents,
      totalMs: _midiBundle!.totalMs,
      leadInDurationMs: state.playbackLeadInMs,
    );
    try {
      if (!kIsWeb) {
        if (!state.visualOnlyMode || state.playbackLeadInMs > 0) {
          await PageAudioLifecycle.enterSightSingingCapture(soft: true);
        }
        // 开麦后仍在 playAndRecord：只 ping + 预热节拍器，不切回 playback。
        await _playback.reclaimNativeEngine(restorePlaybackSession: false);
        await _playback.warmupAudioEngine();
      }
      await _playback.start(muteAudio: state.visualOnlyMode);
    } catch (e) {
      await _stopCaptureSilently();
      _scoringSession = null;
      if (!mounted) return;
      state = state.copyWith(
        stage: SightSingingStage.ready,
        errorMessage: 'MIDI 播放失败：$e',
      );
    }
  }

  Future<void> cancelCountdown() async {
    if (state.stage != SightSingingStage.countdown) return;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _scoringSession = null;
    state = state.copyWith(
      stage: SightSingingStage.ready,
      countdownSeconds: 0,
      userPoints: const <UserPitchPoint>[],
      currentUserMidi: -1,
      currentUserAmplitude: 0,
    );
    unawaited(_stopCaptureSilently());
  }

  Future<void> stopSinging({bool reset = false}) async {
    if (state.stage != SightSingingStage.singing) return;
    if (state.isStoppingSinging) return;
    final session = _scoringSession;
    final tick = session?.finalize();
    final completedScores = session == null
        ? const <KtvNoteScore>[]
        : session.completedScores;
    _scoringSession = null;
    state = state.copyWith(
      isStoppingSinging: true,
      stage: reset ? SightSingingStage.ready : SightSingingStage.finished,
      currentScore: tick?.totalScore ?? state.currentScore,
      hitCount: tick?.hitCount ?? state.hitCount,
      scoredCount: tick?.scoredCount ?? state.scoredCount,
      combo: tick?.combo ?? state.combo,
      completedNoteScores: reset ? const <KtvNoteScore>[] : completedScores,
      userPoints: reset ? const <UserPitchPoint>[] : state.userPoints,
      currentUserMidi: reset ? -1 : state.currentUserMidi,
      currentUserAmplitude: reset ? 0 : state.currentUserAmplitude,
    );
    try {
      // 必须先淡出伴奏，再停麦/切会话；否则 playAndRecord→playback 时
      // 钢琴尾音仍在 ao 里，会产生一次可闻咔哒。
      await _playback.pauseSmooth();
      await _stopCaptureSilently(restorePlaybackSession: false);
      if (!kIsWeb) {
        await _restorePlaybackSessionForHandoff();
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isStoppingSinging: false);
      }
    }
  }

  Future<void> returnToHome() async {
    if (state.stage == SightSingingStage.analyzing) {
      return;
    }
    if (state.stage == SightSingingStage.preparing ||
        state.stage == SightSingingStage.countdown) {
      await cancelPreparingOrCountdown();
    } else if (state.stage == SightSingingStage.singing) {
      await stopSinging(reset: true);
    } else if (state.stage == SightSingingStage.selectTrack) {
      cancelTrackSelection();
    } else {
      if (state.isPreviewPlaying) {
        stopPreview();
      }
      await _playback.stop();
      if (!mounted) return;
      if (state.stage == SightSingingStage.finished) {
        state = state.copyWith(
          stage: SightSingingStage.ready,
          playbackMs: 0,
          userPoints: const <UserPitchPoint>[],
          currentScore: 0,
          hitCount: 0,
          scoredCount: 0,
          combo: 0,
          currentUserMidi: -1,
          currentUserAmplitude: 0,
          completedNoteScores: const <KtvNoteScore>[],
        );
      }
    }
    unawaited(_restorePlaybackSessionForHandoff());
  }

  /// 收藏 / 取消收藏当前教材（智能视唱 type=11）。乐观更新 + 失败回滚。
  Future<void> toggleFavorite() async {
    final repo = _musicPlayRepository;
    final id = state.textbookId;
    if (repo == null || id == null) return;

    final next = !state.favorite;
    state = state.copyWith(favorite: next);
    try {
      final resp = await repo.setFavorite(
        targetId: id,
        type: 11,
        favorite: next,
      );
      if (!mounted) return;
      if (!resp.isSuccess) {
        state = state.copyWith(favorite: !next);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(favorite: !next);
    }
  }

  /// 切换调试面板可见性（页面右上角调试按钮）。
  void toggleDebugPanel() {
    state = state.copyWith(debugPanelVisible: !state.debugPanelVisible);
  }

  void setDebugPanelVisible(bool visible) {
    if (state.debugPanelVisible == visible) return;
    state = state.copyWith(debugPanelVisible: visible);
  }

  /// 调试面板触发的 tuning 变更后，立刻刷新 UI 一次（即便没有麦克风事件）。
  void onTuningExternallyChanged() {
    if (!mounted) return;
    state = state.copyWith();
  }

  void dismissError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(errorMessage: null);
  }

  Future<void> shutdown() async {
    _shuttingDown = true;
    SightSingingTuning.instance.removeListener(_onTuningChanged);
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isPreviewSession = false;
    await _stopCaptureSilently();
    await _positionSub?.cancel();
    await _completedSub?.cancel();
    _positionSub = null;
    _completedSub = null;
    await _playback.dispose();
    await _restorePlaybackSessionForHandoff();
  }

  /// 视唱/试听会把 AVAudioSession 切到 playAndRecord；离开页面前必须切回
  /// playback，否则智能听写等模块的钢琴声会明显变小，直到重启 App。
  Future<void> _restorePlaybackSessionForHandoff() async {
    await PageAudioLifecycle.leaveSightSinging();
  }

  bool _blocksImport() {
    return state.stage == SightSingingStage.analyzing ||
        state.stage == SightSingingStage.preparing ||
        state.stage == SightSingingStage.singing ||
        state.stage == SightSingingStage.countdown;
  }

  static String _nameFromUri(Uri uri) {
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final decoded = Uri.decodeComponent(last).trim();
    return decoded.isEmpty ? '在线 MIDI' : decoded;
  }

  static String _inferExt(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  void _onPlaybackPosition(int positionMs) {
    if (_shuttingDown || !mounted) return;
    _latestPlaybackMs = positionMs;
    if (_isPreviewSession) {
      state = state.copyWith(playbackMs: positionMs);
      return;
    }
    if (state.stage != SightSingingStage.singing) return;
    state = state.copyWith(playbackMs: positionMs);
  }

  Future<void> _handlePlaybackEnded() async {
    if (_shuttingDown || !mounted) return;
    if (state.stage != SightSingingStage.singing) return;
    final session = _scoringSession;
    final tick = session?.finalize();
    final completedScores = session == null
        ? const <KtvNoteScore>[]
        : session.completedScores;
    _scoringSession = null;
    await _playback.stop(awaitNativeFade: true);
    await _stopCaptureSilently(restorePlaybackSession: false);
    if (!kIsWeb) {
      await _restorePlaybackSessionForHandoff();
    }
    if (!mounted) return;
    state = state.copyWith(
      stage: SightSingingStage.finished,
      currentScore: tick?.totalScore ?? state.currentScore,
      hitCount: tick?.hitCount ?? state.hitCount,
      scoredCount: tick?.scoredCount ?? state.scoredCount,
      combo: tick?.combo ?? state.combo,
      completedNoteScores: completedScores,
    );
  }

  double _heldUserMidi = -1;
  int _heldUserMidiUntilMs = 0;
  int _latestPlaybackMs = 0;

  void _onUserPitch(RealtimePitchEvent event) {
    if (_shuttingDown || !mounted) return;
    if (state.stage != SightSingingStage.singing &&
        state.stage != SightSingingStage.preparing &&
        state.stage != SightSingingStage.countdown) {
      return;
    }

    final playbackMs = _latestPlaybackMs;
    final session = _scoringSession;

    if (state.stage == SightSingingStage.preparing) {
      var displayMidi = event.pitched && event.midi >= 0 ? event.midi : -1.0;
      state = state.copyWith(
        currentUserMidi: displayMidi >= 0 ? displayMidi : -1,
        currentUserAmplitude: event.amplitude,
        lastFrequencyHz: event.frequencyHz,
        lastFrameConfidence: event.confidence,
        lastSourceLabel: event.pitched ? 'live' : '--',
      );
      return;
    }

    if (session == null) return;

    final tuning = SightSingingTuning.instance;
    final refFrame = state.track?.sampleAt(playbackMs - tuning.micLatencyMs);
    final refMidi = refFrame?.pitched == true ? refFrame!.midi : null;
    final playbackMidi = _playback.activePlaybackPitch?.toDouble();
    final filtered = PitchVoiceGate.filterForScoring(
      event: event,
      refMidi: refMidi,
      playbackMidi: playbackMidi,
      policy: _voiceGatePolicy,
    );

    // UI / 绘制始终用原始检测结果；串音过滤仅作用于打分。
    var displayMidi = event.pitched && event.midi >= 0 ? event.midi : -1.0;
    if (displayMidi >= 0) {
      _heldUserMidi = displayMidi;
      _heldUserMidiUntilMs = playbackMs + 220;
    } else if (_heldUserMidi >= 0 && playbackMs <= _heldUserMidiUntilMs) {
      displayMidi = _heldUserMidi;
    }

    // 倒计时阶段只预热麦克风，不计分。
    if (state.stage == SightSingingStage.countdown) {
      state = state.copyWith(
        currentUserMidi: displayMidi >= 0 ? displayMidi : -1,
        currentUserAmplitude: event.amplitude,
        lastFrequencyHz: event.frequencyHz,
        lastFrameConfidence: event.confidence,
        lastSourceLabel: event.pitched ? 'live' : '--',
        lastRefMidi: refMidi ?? -1,
        lastPlaybackMidi: playbackMidi ?? -1,
        lastCents: double.nan,
      );
      return;
    }

    // 无谱视唱预备段：标准音/节拍器外放可能被麦克风录入，不写入 KTV 音高轨。
    if (!state.scoreSightReadingMode &&
        state.playbackLeadInMs > 0 &&
        playbackMs < state.playbackLeadInMs) {
      _heldUserMidi = -1;
      _heldUserMidiUntilMs = 0;
      if (state.currentUserMidi >= 0 || state.currentUserAmplitude > 0) {
        state = state.copyWith(currentUserMidi: -1, currentUserAmplitude: 0);
      }
      return;
    }

    final tick = session.onPitch(playbackMs: playbackMs, event: filtered);
    final cents = tick.cents;

    final newPoint = UserPitchPoint(
      timeMs: playbackMs,
      midi: displayMidi >= 0 ? displayMidi : -1,
      amplitude: event.amplitude,
      cents: cents,
    );

    final next = List<UserPitchPoint>.from(state.userPoints)..add(newPoint);
    if (next.length > SmartSightSingingSessionConfig.userPitchPointCap) {
      next.removeRange(
        0,
        next.length - SmartSightSingingSessionConfig.userPitchPointCap,
      );
    }

    state = state.copyWith(
      userPoints: next,
      currentUserMidi: displayMidi >= 0 ? displayMidi : -1,
      currentUserAmplitude: event.amplitude,
      currentScore: tick.totalScore,
      hitCount: tick.hitCount,
      scoredCount: tick.scoredCount,
      combo: tick.combo,
      lastFrequencyHz: event.frequencyHz,
      lastFrameConfidence: event.confidence,
      lastSourceLabel: event.pitched
          ? (filtered.pitched ? 'voice' : 'bleed?')
          : '--',
      lastRefMidi: refMidi ?? -1,
      lastPlaybackMidi: playbackMidi ?? -1,
      lastCents: cents,
    );
  }

  Future<void> _stopCaptureSilently({
    bool restorePlaybackSession = true,
  }) async {
    await _pitchSub?.cancel();
    _pitchSub = null;
    try {
      await _capture?.stop(restorePlaybackSession: restorePlaybackSession);
    } catch (_) {}
    _capture = null;
  }
}
