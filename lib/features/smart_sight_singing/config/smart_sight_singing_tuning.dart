import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'smart_sight_singing_config.dart';

/// 智能视唱「现场可调参数」运行时容器。
///
/// 设计目的：
/// - 真机调试时无需重新编译就能调节关键参数（音准容差、麦克风延迟、
///   串音阈值、稳定平滑、置信度…），所有调音/打分链路实时生效。
/// - 调到满意值后可一键导出为 Dart 源码片段，直接粘回
///   `smart_sight_singing_config.dart` 替换默认值。
/// - 在本地 `SharedPreferences` 持久化，App 重启后保留；可一键复位全部。
///
/// 该容器的所有 getter 在没有 override 时落回到 const 默认；只有当用户
/// 在调试面板里改过该字段时，对应字段才会读取本地 override。
class SightSingingTuning extends ChangeNotifier {
  SightSingingTuning._();
  static final SightSingingTuning instance = SightSingingTuning._();

  static const String _prefsPrefix = 'sight_singing_tuning::';

  bool _loaded = false;
  SharedPreferences? _prefs;
  final Map<String, num> _overrides = <String, num>{};

  bool get isLoaded => _loaded;
  bool get hasAnyOverride => _overrides.isNotEmpty;
  int get overrideCount => _overrides.length;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      for (final key in _prefs!.getKeys()) {
        if (!key.startsWith(_prefsPrefix)) continue;
        final value = _prefs!.get(key);
        if (value is num) {
          _overrides[key.substring(_prefsPrefix.length)] = value;
        }
      }
    } catch (_) {
      // 某些平台拿不到 SharedPreferences 时，保持默认值即可。
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  int _getInt(String key, int fallback) {
    final v = _overrides[key];
    return v == null ? fallback : v.toInt();
  }

  double _getDouble(String key, double fallback) {
    final v = _overrides[key];
    return v == null ? fallback : v.toDouble();
  }

  bool _getBool(String key, bool fallback) {
    final v = _overrides[key];
    if (v == null) return fallback;
    return v.toInt() != 0;
  }

  Future<void> _put(String key, num value) async {
    _overrides[key] = value;
    notifyListeners();
    try {
      await _prefs?.setDouble('$_prefsPrefix$key', value.toDouble());
    } catch (_) {}
  }

  Future<void> resetAll() async {
    final keys = _overrides.keys.toList(growable: false);
    _overrides.clear();
    notifyListeners();
    try {
      for (final key in keys) {
        await _prefs?.remove('$_prefsPrefix$key');
      }
    } catch (_) {}
  }

  // ---- Scoring（打分链路） ----
  int get micLatencyMs => _getInt(
    'micLatencyMs',
    SmartSightSingingScoringConfig.micLatencyMs,
  );
  Future<void> setMicLatencyMs(int v) => _put('micLatencyMs', v);

  int get earlySingMs => _getInt(
    'earlySingMs',
    SmartSightSingingScoringConfig.earlySingMs,
  );
  Future<void> setEarlySingMs(int v) => _put('earlySingMs', v);

  int get lateSingMs => _getInt(
    'lateSingMs',
    SmartSightSingingScoringConfig.lateSingMs,
  );
  Future<void> setLateSingMs(int v) => _put('lateSingMs', v);

  double get defaultStandardCents => _getDouble(
    'defaultStandardCents',
    SmartSightSingingScoringConfig.defaultStandardCents,
  );
  Future<void> setDefaultStandardCents(double v) =>
      _put('defaultStandardCents', v);

  double get perfectCentsAtDefault => _getDouble(
    'perfectCentsAtDefault',
    SmartSightSingingScoringConfig.perfectCentsAtDefault,
  );
  Future<void> setPerfectCentsAtDefault(double v) =>
      _put('perfectCentsAtDefault', v);

  double get okCentsAtDefault => _getDouble(
    'okCentsAtDefault',
    SmartSightSingingScoringConfig.okCentsAtDefault,
  );
  Future<void> setOkCentsAtDefault(double v) => _put('okCentsAtDefault', v);

  // ---- Realtime pitch（实时音高） ----
  double get realtimeMinRms => _getDouble(
    'realtimeMinRms',
    SmartSightSingingRealtimePitchConfig.minRms,
  );
  Future<void> setRealtimeMinRms(double v) => _put('realtimeMinRms', v);

  double get frameMinConfidence => _getDouble(
    'frameMinConfidence',
    SmartSightSingingRealtimePitchConfig.frameMinConfidence,
  );
  Future<void> setFrameMinConfidence(double v) =>
      _put('frameMinConfidence', v);

  double get autocorrelationMinCorrelation => _getDouble(
    'autocorrelationMinCorrelation',
    SmartSightSingingRealtimePitchConfig.autocorrelationMinCorrelation,
  );
  Future<void> setAutocorrelationMinCorrelation(double v) =>
      _put('autocorrelationMinCorrelation', v);

  int get stableFrameCount => _getInt(
    'stableFrameCount',
    SmartSightSingingRealtimePitchConfig.stableFrameCount,
  );
  Future<void> setStableFrameCount(int v) => _put('stableFrameCount', v);

  double get stableFrequencyDiffRatio => _getDouble(
    'stableFrequencyDiffRatio',
    SmartSightSingingRealtimePitchConfig.stableFrequencyDiffRatio,
  );
  Future<void> setStableFrequencyDiffRatio(double v) =>
      _put('stableFrequencyDiffRatio', v);

  double get smoothedConfidenceFloor => _getDouble(
    'smoothedConfidenceFloor',
    SmartSightSingingRealtimePitchConfig.smoothedConfidenceFloor,
  );
  Future<void> setSmoothedConfidenceFloor(double v) =>
      _put('smoothedConfidenceFloor', v);

  // ---- Voice gate（人声/串音过滤） ----
  double get visualOnlyMinAmplitude => _getDouble(
    'visualOnlyMinAmplitude',
    SmartSightSingingVoiceGateConfig.visualOnlyMinAmplitude,
  );
  Future<void> setVisualOnlyMinAmplitude(double v) =>
      _put('visualOnlyMinAmplitude', v);

  double get accompanimentMinAmplitude => _getDouble(
    'accompanimentMinAmplitude',
    SmartSightSingingVoiceGateConfig.accompanimentMinAmplitude,
  );
  Future<void> setAccompanimentMinAmplitude(double v) =>
      _put('accompanimentMinAmplitude', v);

  double get bleedMatchMaxAmplitude => _getDouble(
    'bleedMatchMaxAmplitude',
    SmartSightSingingVoiceGateConfig.bleedMatchMaxAmplitude,
  );
  Future<void> setBleedMatchMaxAmplitude(double v) =>
      _put('bleedMatchMaxAmplitude', v);

  double get bleedMatchMaxCents => _getDouble(
    'bleedMatchMaxCents',
    SmartSightSingingVoiceGateConfig.bleedMatchMaxCents,
  );
  Future<void> setBleedMatchMaxCents(double v) =>
      _put('bleedMatchMaxCents', v);

  double get strongVoiceExtraAmplitude => _getDouble(
    'strongVoiceExtraAmplitude',
    SmartSightSingingVoiceGateConfig.strongVoiceExtraAmplitude,
  );
  Future<void> setStrongVoiceExtraAmplitude(double v) =>
      _put('strongVoiceExtraAmplitude', v);

  // ---- Behavior（行为开关，未在 config 中预定义，仅 runtime） ----

  /// 是否对评分做八度归一（同名音跨八度仍能拿分）。
  /// 关闭后变成「严格音域评分」：唱错八度直接 miss。
  bool get octaveNormalizeScoring => _getBool('octaveNormalizeScoring', true);
  Future<void> setOctaveNormalizeScoring(bool v) =>
      _put('octaveNormalizeScoring', v ? 1 : 0);

  /// 实时检测在无音高超过该毫秒数后，清掉稳定平滑缓存，避免再次出声
  /// 时被旧的 `_lastHz` 吸附到错误频率。
  int get silenceResetSmoothingMs => _getInt('silenceResetSmoothingMs', 220);
  Future<void> setSilenceResetSmoothingMs(int v) =>
      _put('silenceResetSmoothingMs', v);

  /// 导出当前 override 为 Dart 源码片段，方便复制到 config 文件作为新默认。
  String exportDartSource() {
    final lines = <String>[
      '// === 智能视唱真机调试导出 ===',
      '// 把对应字段替换到:',
      '//   lib/features/smart_sight_singing/config/smart_sight_singing_config.dart',
      '',
    ];

    if (_overrides.isEmpty) {
      lines.add('// 当前没有任何参数修改，已恢复全部默认。');
      return lines.join('\n');
    }

    void emit(
      String section,
      List<({String name, String line})> items,
    ) {
      final touched = items
          .where((it) => _overrides.containsKey(it.name))
          .toList(growable: false);
      if (touched.isEmpty) return;
      lines.add('// --- $section ---');
      for (final it in touched) {
        lines.add(it.line);
      }
      lines.add('');
    }

    emit('SmartSightSingingScoringConfig', [
      (
        name: 'micLatencyMs',
        line: 'static const int micLatencyMs = $micLatencyMs;',
      ),
      (
        name: 'earlySingMs',
        line: 'static const int earlySingMs = $earlySingMs;',
      ),
      (
        name: 'lateSingMs',
        line: 'static const int lateSingMs = $lateSingMs;',
      ),
      (
        name: 'defaultStandardCents',
        line:
            'static const double defaultStandardCents = ${_fmt(defaultStandardCents)};',
      ),
      (
        name: 'perfectCentsAtDefault',
        line:
            'static const double perfectCentsAtDefault = ${_fmt(perfectCentsAtDefault)};',
      ),
      (
        name: 'okCentsAtDefault',
        line:
            'static const double okCentsAtDefault = ${_fmt(okCentsAtDefault)};',
      ),
    ]);

    emit('SmartSightSingingRealtimePitchConfig', [
      (
        name: 'realtimeMinRms',
        line: 'static const double minRms = ${_fmt(realtimeMinRms)};',
      ),
      (
        name: 'frameMinConfidence',
        line:
            'static const double frameMinConfidence = ${_fmt(frameMinConfidence)};',
      ),
      (
        name: 'autocorrelationMinCorrelation',
        line:
            'static const double autocorrelationMinCorrelation = ${_fmt(autocorrelationMinCorrelation)};',
      ),
      (
        name: 'stableFrameCount',
        line: 'static const int stableFrameCount = $stableFrameCount;',
      ),
      (
        name: 'stableFrequencyDiffRatio',
        line:
            'static const double stableFrequencyDiffRatio = ${_fmt(stableFrequencyDiffRatio)};',
      ),
      (
        name: 'smoothedConfidenceFloor',
        line:
            'static const double smoothedConfidenceFloor = ${_fmt(smoothedConfidenceFloor)};',
      ),
    ]);

    emit('SmartSightSingingVoiceGateConfig', [
      (
        name: 'visualOnlyMinAmplitude',
        line:
            'static const double visualOnlyMinAmplitude = ${_fmt(visualOnlyMinAmplitude)};',
      ),
      (
        name: 'accompanimentMinAmplitude',
        line:
            'static const double accompanimentMinAmplitude = ${_fmt(accompanimentMinAmplitude)};',
      ),
      (
        name: 'bleedMatchMaxAmplitude',
        line:
            'static const double bleedMatchMaxAmplitude = ${_fmt(bleedMatchMaxAmplitude)};',
      ),
      (
        name: 'bleedMatchMaxCents',
        line:
            'static const double bleedMatchMaxCents = ${_fmt(bleedMatchMaxCents)};',
      ),
      (
        name: 'strongVoiceExtraAmplitude',
        line:
            'static const double strongVoiceExtraAmplitude = ${_fmt(strongVoiceExtraAmplitude)};',
      ),
    ]);

    final behavior = <String>[];
    if (_overrides.containsKey('octaveNormalizeScoring')) {
      behavior.add(
        '// SmartSightSingingTuning.octaveNormalizeScoring 当前默认值建议改为: $octaveNormalizeScoring',
      );
    }
    if (_overrides.containsKey('silenceResetSmoothingMs')) {
      behavior.add(
        '// SmartSightSingingTuning.silenceResetSmoothingMs 当前默认值建议改为: $silenceResetSmoothingMs ms',
      );
    }
    if (behavior.isNotEmpty) {
      lines.add('// --- 行为开关（runtime，无对应 const） ---');
      lines.addAll(behavior);
    }

    return lines.join('\n');
  }

  static String _fmt(double v) {
    if (!v.isFinite) return '0';
    if (v == v.roundToDouble()) return v.toStringAsFixed(1);
    return v.toStringAsFixed(3);
  }
}
