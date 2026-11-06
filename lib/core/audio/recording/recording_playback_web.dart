import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'recording_playback.dart';

RecordingPlayback createPlatformRecordingPlayback() => _HtmlAudioPlayback();

class _HtmlAudioPlayback implements RecordingPlayback {
  _HtmlAudioPlayback() {
    _audio.preload = 'metadata';

    _audio.addEventListener(
      'timeupdate',
      ((web.Event _) => _emitPosition()).toJS,
    );
    _audio.addEventListener(
      'durationchange',
      ((web.Event _) => _emitDuration()).toJS,
    );
    _audio.addEventListener(
      'loadedmetadata',
      ((web.Event _) {
        _emitDuration();
        _completePendingLoad(null);
      }).toJS,
    );
    _audio.addEventListener(
      'canplay',
      ((web.Event _) {
        _emitDuration();
        _completePendingLoad(null);
      }).toJS,
    );
    _audio.addEventListener('play', ((web.Event _) => _emitStatus()).toJS);
    _audio.addEventListener('pause', ((web.Event _) => _emitStatus()).toJS);
    _audio.addEventListener(
      'ended',
      ((web.Event _) {
        if (_multiMode && _currentIndex < _playlist.length - 1) {
          unawaited(_advanceToNextSegment());
          return;
        }
        _completed = true;
        _emitStatus();
      }).toJS,
    );
    _audio.addEventListener(
      'error',
      ((web.Event _) {
        final code = _audio.error?.code;
        _completePendingLoad(StateError('HTMLAudioElement load error: $code'));
      }).toJS,
    );
  }

  final web.HTMLAudioElement _audio = web.HTMLAudioElement();
  final StreamController<int> _positionController =
      StreamController<int>.broadcast();
  final StreamController<int> _durationController =
      StreamController<int>.broadcast();
  final StreamController<RecordingPlaybackStatus> _statusController =
      StreamController<RecordingPlaybackStatus>.broadcast();

  Completer<int?>? _loadCompleter;
  String? _pendingLoadSrc;
  Timer? _positionTimer;
  bool _completed = false;

  bool _multiMode = false;
  List<String> _playlist = const <String>[];
  List<int> _segmentDurationsMs = const <int>[];
  int _totalDurationMs = 0;
  int _currentIndex = 0;
  int _segmentStartOffsetMs = 0;

  @override
  Stream<int> get positionMs => _positionController.stream;

  @override
  Stream<int> get durationMs => _durationController.stream;

  @override
  Stream<RecordingPlaybackStatus> get status => _statusController.stream;

  @override
  bool get isPlaying => !_audio.paused;

  @override
  bool get isCompleted => _completed;

  @override
  int? get currentDurationMs =>
      _multiMode ? _totalDurationMs : _durationToMs(_audio.duration);

  @override
  Future<int?> setSource(String source, {required bool isUrl}) async {
    _multiMode = false;
    _playlist = const <String>[];
    _segmentDurationsMs = const <int>[];
    _totalDurationMs = 0;
    _currentIndex = 0;
    _segmentStartOffsetMs = 0;

    await stop();
    _completed = false;
    _pendingLoadSrc = source;
    _loadCompleter = Completer<int?>();
    _audio.src = source;
    _audio.load();

    return _loadCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _loadCompleter = null;
        return null;
      },
    );
  }

  @override
  Future<int?> setSources(
    List<String> sources, {
    required bool isUrl,
    List<int>? segmentDurationsMs,
    int? totalDurationMs,
  }) async {
    if (sources.isEmpty) return null;
    if (sources.length == 1) {
      return setSource(sources.first, isUrl: isUrl);
    }

    // Reset the element first; [stop] clears playlist state and must run
    // before we configure multi-segment mode.
    await stop();
    _completed = false;
    _multiMode = true;
    _playlist = List<String>.from(sources);
    _segmentDurationsMs =
        segmentDurationsMs != null &&
            segmentDurationsMs.length == sources.length
        ? List<int>.from(segmentDurationsMs)
        : List<int>.filled(sources.length, 0);
    _totalDurationMs =
        totalDurationMs ?? _segmentDurationsMs.fold(0, (sum, ms) => sum + ms);
    _currentIndex = 0;
    _segmentStartOffsetMs = 0;

    await _loadSegment(0);

    if (_totalDurationMs > 0 && !_durationController.isClosed) {
      _durationController.add(_totalDurationMs);
    }
    return _totalDurationMs;
  }

  Future<void> _loadSegment(int index) async {
    _currentIndex = index;
    _segmentStartOffsetMs = 0;
    for (var i = 0; i < index; i++) {
      _segmentStartOffsetMs += _segmentDurationsMs[i];
    }

    final src = _playlist[index];
    _pendingLoadSrc = src;
    _loadCompleter = Completer<int?>();
    _audio.src = src;
    _audio.load();

    try {
      await _loadCompleter!.future.timeout(const Duration(seconds: 10));
    } catch (error) {
      _loadCompleter = null;
      rethrow;
    }
  }

  Future<void> _advanceToNextSegment() async {
    try {
      _currentIndex++;
      await _loadSegment(_currentIndex);
      _completed = false;
      await _audio.play().toDart;
      _startPositionTimer();
      _emitPosition();
      _emitStatus();
    } catch (_) {
      _completed = true;
      _emitStatus();
    }
  }

  @override
  Future<void> play() async {
    _completed = false;
    await _audio.play().toDart;
    _startPositionTimer();
    _emitStatus();
  }

  @override
  Future<void> pause() async {
    _audio.pause();
    _stopPositionTimer();
    _emitStatus();
  }

  @override
  Future<void> stop() async {
    _loadCompleter = null;
    _pendingLoadSrc = null;
    _audio.pause();
    _stopPositionTimer();
    try {
      _audio.currentTime = 0;
    } catch (_) {}
    _audio.removeAttribute('src');
    _audio.load();
    // Drain stale error/canplay events from the empty-src load before callers
    // attach a new source.
    await Future<void>.delayed(Duration.zero);
    _completed = false;
    _multiMode = false;
    _playlist = const <String>[];
    _segmentDurationsMs = const <int>[];
    _totalDurationMs = 0;
    _currentIndex = 0;
    _segmentStartOffsetMs = 0;
    _emitPosition();
    _emitStatus();
  }

  @override
  Future<void> seek(int positionMs) async {
    _completed = false;
    if (!_multiMode) {
      _audio.currentTime = math.max(positionMs, 0) / 1000.0;
      _emitPosition();
      return;
    }

    final clamped = positionMs.clamp(0, math.max(_totalDurationMs, 0));
    var offsetMs = 0;
    for (var i = 0; i < _playlist.length; i++) {
      final segmentDurationMs = _segmentDurationsMs[i];
      final segmentEndMs = offsetMs + segmentDurationMs;
      final isLast = i == _playlist.length - 1;
      if (clamped < segmentEndMs || isLast) {
        if (_currentIndex != i) {
          await _loadSegment(i);
        }
        final localMs = math.max(clamped - offsetMs, 0);
        _audio.currentTime = localMs / 1000.0;
        _emitPosition();
        return;
      }
      offsetMs = segmentEndMs;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    _loadCompleter = null;
    _pendingLoadSrc = null;
    await _positionController.close();
    await _durationController.close();
    await _statusController.close();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _emitPosition(),
    );
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _emitPosition() {
    if (_positionController.isClosed) return;
    final localMs = (_audio.currentTime * 1000).round();
    final globalMs = _multiMode ? _segmentStartOffsetMs + localMs : localMs;
    _positionController.add(globalMs);
  }

  void _emitDuration() {
    if (_durationController.isClosed) return;
    if (_multiMode) {
      if (_totalDurationMs > 0) {
        _durationController.add(_totalDurationMs);
      }
      return;
    }
    final ms = _durationToMs(_audio.duration);
    if (ms != null) {
      _durationController.add(ms);
    }
  }

  void _emitStatus() {
    if (_statusController.isClosed) return;
    _statusController.add(
      RecordingPlaybackStatus(
        playing: !_audio.paused && !_completed,
        completed: _completed,
      ),
    );
  }

  int? _durationToMs(double value) {
    if (!value.isFinite || value <= 0) return null;
    return (value * 1000).round();
  }

  void _completePendingLoad(Object? error) {
    final completer = _loadCompleter;
    if (completer == null || completer.isCompleted) return;
    final expected = _pendingLoadSrc;
    if (expected != null && _audio.currentSrc != expected) return;
    _loadCompleter = null;
    if (error != null) {
      completer.completeError(error);
      return;
    }
    if (_multiMode) {
      completer.complete(_totalDurationMs > 0 ? _totalDurationMs : null);
      return;
    }
    completer.complete(_durationToMs(_audio.duration));
  }
}
