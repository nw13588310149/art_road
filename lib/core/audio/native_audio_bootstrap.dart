import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'native_playback_audio_session.dart';

/// 全应用唯一的 SoLoud 初始化器。
///
/// 之前每个模块（音乐伴侣 / 智能听写 / musicPlay 钢琴）都各自 `SoLoud.init()`，
/// 在 iPad 上会被 media_kit / 录音器抢走 AVAudioSession，最终表现为：
///   - 钢琴卡在「加载中」
///   - 节拍器 / 听写 init 直接报错
///
/// 这里把 SoLoud.init + AVAudioSession 配置收敛到一个全局单例，
/// 任何模块要用 SoLoud 之前都先 `await NativeAudioBootstrap.ensureReady()`，
/// 后续 loadAsset 才会拿到一个稳定可用的 SoLoud 实例。
abstract final class NativeAudioBootstrap {
  static SoLoud get soLoud => SoLoud.instance;

  /// 当前进行中的 init Future；nullable 让任何一次失败都能在下次调用时重试。
  static Future<void>? _initTask;

  /// 上次 init 是否已经成功——成功后短路返回，避免反复进 platform channel。
  static bool _ready = false;

  /// 最近一次失败原因；UI 可以读出来给用户提示「请重试」。
  static Object? _lastError;

  /// 单次 `SoLoud.init()` 的最长等待。iOS 上偶尔会因为 AVAudioSession 抢占
  /// 失败而永远不返回，必须有个硬上限把它打断，让用户能看到错误而不是卡死。
  static const Duration _kInitTimeout = Duration(seconds: 12);

  /// 失败时的最大重试次数（含首次）。每次重试前会先重新尝试 session 配置。
  static const int _kMaxAttempts = 2;

  /// 重试之间的退避间隔。
  static const Duration _kRetryBackoff = Duration(milliseconds: 400);

  static bool get isReady => kIsWeb || _ready;

  static Object? get lastError => _lastError;

  /// 确保 SoLoud 已经 init 完成。
  ///
  /// - Web：no-op，直接返回。
  /// - 原生：
  ///   1. 配置 AVAudioSession 为 playback；
  ///   2. 如果 SoLoud 还没初始化，调 `SoLoud.init()`；
  ///   3. setMaxActiveVoiceCount 给共享 SoLoud 上一个合理值；
  ///   4. 任意一步失败都重试一次，仍失败则 rethrow。
  static Future<void> ensureReady() {
    if (kIsWeb || _ready) return Future<void>.value();
    return _initTask ??= _runInit().whenComplete(() {
      // 成功后保留 _ready；失败时清空 _initTask 让下次能重试。
      if (!_ready) {
        _initTask = null;
      }
    });
  }

  static Future<void> _runInit() async {
    Object? lastError;
    for (var attempt = 1; attempt <= _kMaxAttempts; attempt++) {
      try {
        await _runInitAttempt();
        _ready = true;
        _lastError = null;
        return;
      } catch (error, stack) {
        lastError = error;
        _lastError = error;
        debugPrint(
          'NativeAudioBootstrap init attempt $attempt/$_kMaxAttempts '
          'failed: $error\n$stack',
        );
        if (attempt < _kMaxAttempts) {
          await Future<void>.delayed(_kRetryBackoff);
          NativePlaybackAudioSession.invalidatePlaybackCache();
        }
      }
    }
    // 全部失败，把最后一次错误抛出去给调用方。
    throw lastError ?? StateError('NativeAudioBootstrap init failed');
  }

  static Future<void> _runInitAttempt() async {
    // Step 1：先把 AVAudioSession 切到 playback。这里内部已经带超时和兜底，
    // 即便 session 配置失败也只是 best-effort，会继续往下走。
    await NativePlaybackAudioSession.ensurePlaybackActive();

    // Step 2：SoLoud.init —— 加 timeout，避免被卡到无限等待。
    if (!soLoud.isInitialized) {
      await soLoud.init().timeout(
        _kInitTimeout,
        onTimeout: () => throw TimeoutException(
          'SoLoud.init() did not complete in ${_kInitTimeout.inSeconds}s',
        ),
      );
    }

    // Step 3：调一些常用的全局开关；这里是 in-process 调用，不会阻塞。
    soLoud.setMaxActiveVoiceCount(256);
  }

  /// 把当前缓存的「已就绪」状态清掉，让下一次 [ensureReady] 重新走完整初始化。
  /// 用于：
  /// - 用户在错误提示里点击「重试」；
  /// - 调音器 / 录音器结束后，外面想强制重做一次 session + SoLoud 状态自检。
  static void resetForRetry() {
    _ready = false;
    _initTask = null;
    _lastError = null;
    NativePlaybackAudioSession.invalidatePlaybackCache();
  }

  /// 应用 / 页面恢复 playback 之前调一次，确保 AVAudioSession 重新落到 playback。
  /// 不会重新 init SoLoud，只刷 session。
  static Future<void> reactivatePlaybackSession() async {
    if (kIsWeb) return;
    await NativePlaybackAudioSession.reconcilePlayback();
  }
}
