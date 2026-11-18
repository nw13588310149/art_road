import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/recording/recording_playback.dart';
import '../../../core/network/media_url.dart';

typedef ArtworkPlaybackFactory = RecordingPlayback Function();

/// 播放器的来源；测试里换成不出声的替身。
final artworkPlaybackFactoryProvider = Provider<ArtworkPlaybackFactory>(
  (ref) => createRecordingPlayback,
);

/// 作品页上正在播的那一段语音。[key] 为空表示没有在播。
@immutable
class ArtworkVoicePlayback {
  const ArtworkVoicePlayback({
    this.key = '',
    this.loading = false,
    this.playing = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.failed = false,
  });

  final String key;
  final bool loading;
  final bool playing;
  final int positionMs;
  final int durationMs;
  final bool failed;

  bool isActive(String other) => key.isNotEmpty && key == other;

  ArtworkVoicePlayback copyWith({
    bool? loading,
    bool? playing,
    int? positionMs,
    int? durationMs,
    bool? failed,
  }) {
    return ArtworkVoicePlayback(
      key: key,
      loading: loading ?? this.loading,
      playing: playing ?? this.playing,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      failed: failed ?? this.failed,
    );
  }
}

/// 一页共用一个播放器：点评语音和各处定点点评的语音同一时间只播一段，
/// 开始播新的一段时先停掉上一段。离开页面时停止。
final artworkVoicePlayerProvider =
    StateNotifierProvider.autoDispose<ArtworkVoicePlayer, ArtworkVoicePlayback>(
      (ref) => ArtworkVoicePlayer(ref.watch(artworkPlaybackFactoryProvider)),
    );

class ArtworkVoicePlayer extends StateNotifier<ArtworkVoicePlayback> {
  ArtworkVoicePlayer(this._create) : super(const ArtworkVoicePlayback());

  final ArtworkPlaybackFactory _create;
  RecordingPlayback? _player;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// 每次换一段语音加一，旧的回调回来时据此丢弃。
  int _generation = 0;

  /// 点同一段：播放中暂停、暂停中接着播、播完从头播；点另一段：换成那一段。
  Future<void> toggle(String key, String source, {int seconds = 0}) async {
    final player = _player;
    if (player != null && state.isActive(key) && !state.failed) {
      if (state.loading) {
        return;
      }
      if (state.playing) {
        await player.pause();
        return;
      }
      if (state.durationMs > 0 && state.positionMs >= state.durationMs - 200) {
        await player.seek(0);
      }
      unawaited(player.play().catchError((Object _) {}));
      return;
    }
    await play(key, source, seconds: seconds);
  }

  /// 从头播放 [key] 这一段（[source] 是上传返回的路径或完整地址）。
  Future<void> play(String key, String source, {int seconds = 0}) async {
    final url = MediaUrl.resolve(source);
    if (url.isEmpty) {
      return;
    }
    final generation = ++_generation;
    await _release();
    if (!mounted || generation != _generation) {
      return;
    }
    final player = _create();
    _player = player;
    state = ArtworkVoicePlayback(
      key: key,
      loading: true,
      durationMs: seconds * 1000,
    );
    bool current() => mounted && generation == _generation;
    _subscriptions
      ..add(
        player.positionMs.listen((ms) {
          if (current()) state = state.copyWith(positionMs: ms);
        }),
      )
      ..add(
        player.durationMs.listen((ms) {
          if (current() && ms > 0) state = state.copyWith(durationMs: ms);
        }),
      )
      ..add(
        player.status.listen((status) {
          if (!current()) return;
          state = status.completed
              ? state.copyWith(playing: false, positionMs: state.durationMs)
              : state.copyWith(playing: status.playing);
        }),
      );
    try {
      final ms = await player.setSource(url, isUrl: true);
      if (!current()) {
        return;
      }
      state = state.copyWith(
        loading: false,
        durationMs: ms != null && ms > 0 ? ms : null,
      );
      // 有的平台要等整段播完 play 才返回，不在这里等。
      unawaited(
        player.play().catchError((Object _) {
          if (current()) state = state.copyWith(playing: false, failed: true);
        }),
      );
    } catch (_) {
      if (current()) {
        state = state.copyWith(loading: false, playing: false, failed: true);
      }
    }
  }

  Future<void> stop() async {
    _generation++;
    await _release();
    if (mounted) {
      state = const ArtworkVoicePlayback();
    }
  }

  /// 只在正在播 [key] 这一段时停下。
  Future<void> stopIfActive(String key) async {
    if (state.isActive(key)) {
      await stop();
    }
  }

  Future<void> _release() async {
    final subscriptions = List<StreamSubscription<Object?>>.of(_subscriptions);
    _subscriptions.clear();
    final player = _player;
    _player = null;
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await player?.dispose();
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_release());
    super.dispose();
  }
}
