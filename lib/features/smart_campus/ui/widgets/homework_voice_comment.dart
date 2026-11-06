// =============================================================================
// 作业「语音点评」可播放气泡（教师录制预览 / 学生回放共用）
//
// 设计：
//   - 紫色圆形 播放/暂停 按钮 + 进度条 + 时长（mm:ss）。
//   - 传入 `relativePath`（teacherParam1，fileUpload 返回的相对路径）与
//     `durationSec`（teacherParam2）；内部用 [MediaUrl.resolve] 拼成可加载 URL。
//   - 用录音系统的 [RecordingPlayback]（io: just_audio / web: HTMLAudio）播放，
//     与群聊语音、录音回放保持同一套音频会话协调。
//   - 同一时间允许多个气泡，但每个气泡自己管理自己的播放实例；点击播放时
//     不主动停止其它气泡（点评场景一般只有一条，简单优先）。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/media_url.dart';
import '../../../recording_system/audio/recording_playback.dart';

class HomeworkVoiceCommentBubble extends StatefulWidget {
  const HomeworkVoiceCommentBubble({
    super.key,
    required this.relativePath,
    required this.durationSec,
    this.scale = 1.0,
    this.accent = const Color(0xFF8741FF),
    this.background = const Color(0xFFF4F4FF),
  });

  /// 语音文件相对路径（teacherParam1）或完整 URL。
  final String relativePath;

  /// 语音时长（秒），用于初始展示与进度条插值。
  final int durationSec;

  /// UI 缩放系数（仪表盘 `ui()`）。
  final double scale;

  final Color accent;
  final Color background;

  @override
  State<HomeworkVoiceCommentBubble> createState() =>
      _HomeworkVoiceCommentBubbleState();
}

class _HomeworkVoiceCommentBubbleState
    extends State<HomeworkVoiceCommentBubble> {
  RecordingPlayback? _player;
  StreamSubscription<int>? _posSub;
  StreamSubscription<int>? _durSub;
  StreamSubscription<RecordingPlaybackStatus>? _statusSub;

  bool _loading = false;
  bool _playing = false;
  int _positionMs = 0;
  int _durationMs = 0;

  @override
  void initState() {
    super.initState();
    _durationMs = widget.durationSec * 1000;
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _statusSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  String get _resolvedUrl => MediaUrl.resolve(widget.relativePath);

  Future<void> _toggle() async {
    if (_resolvedUrl.isEmpty) return;
    final player = _player;
    if (player != null && _playing) {
      await player.pause();
      return;
    }
    if (player != null && !_playing) {
      // 播放结束后重新点击：从头播放。
      if (_durationMs > 0 && _positionMs >= _durationMs - 200) {
        await player.seek(0);
      }
      await player.play();
      return;
    }
    await _prepareAndPlay();
  }

  Future<void> _prepareAndPlay() async {
    setState(() => _loading = true);
    final player = createRecordingPlayback();
    _player = player;
    _posSub = player.positionMs.listen((ms) {
      if (!mounted) return;
      setState(() => _positionMs = ms);
    });
    _durSub = player.durationMs.listen((ms) {
      if (!mounted || ms <= 0) return;
      setState(() => _durationMs = ms);
    });
    _statusSub = player.status.listen((s) {
      if (!mounted) return;
      setState(() {
        _playing = s.playing;
        if (s.completed) {
          _playing = false;
          _positionMs = _durationMs;
        }
      });
    });
    try {
      final ms = await player.setSource(_resolvedUrl, isUrl: true);
      if (!mounted) return;
      if (ms != null && ms > 0) setState(() => _durationMs = ms);
      await player.play();
    } catch (_) {
      // 静默失败：保留时长展示，按钮回到可重试状态。
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(int ms) {
    final total = (ms / 1000).round();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    double u(double v) => v * widget.scale;
    final progress = _durationMs > 0
        ? (_positionMs / _durationMs).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: u(12), vertical: u(10)),
      decoration: BoxDecoration(
        color: widget.background,
        borderRadius: BorderRadius.circular(u(10)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _loading ? null : _toggle,
            child: Container(
              width: u(36),
              height: u(36),
              decoration: BoxDecoration(
                color: widget.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: _loading
                  ? SizedBox(
                      width: u(18),
                      height: u(18),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: u(22),
                    ),
            ),
          ),
          SizedBox(width: u(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(u(3)),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: u(4),
                    backgroundColor: widget.accent.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
                  ),
                ),
                SizedBox(height: u(6)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: u(14),
                      color: widget.accent,
                    ),
                    Text(
                      _playing || _positionMs > 0
                          ? '${_fmt(_positionMs)} / ${_fmt(_durationMs)}'
                          : _fmt(_durationMs),
                      style: TextStyle(
                        fontSize: u(12),
                        color: const Color(0xFF71717A),
                        fontFamily: 'Barlow',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
