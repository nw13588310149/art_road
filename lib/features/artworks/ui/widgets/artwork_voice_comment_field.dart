import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/audio/recording/recording_bytes_loader.dart';
import '../../../../core/audio/recording/recording_capture.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';
import '../../../smart_campus/ui/widgets/homework_asset_icon.dart';
import '../../../smart_campus/ui/widgets/homework_voice_comment.dart';

/// 上传一段语音，返回可保存的路径；失败返回 null。
typedef ArtworkVoiceUpload =
    Future<String?> Function(Uint8List bytes, String filename);

enum _VoicePhase { idle, recording, uploading, ready }

/// 语音评语：按住右侧话筒说话，松开后上传；已有语音显示为可播放的气泡，可以重录
/// 或删除。交互、尺寸和图标照原版作品点评抽屉里的语音点评
/// （R `teacher_homework_review_view.dart` 3425–3800），播放气泡直接复用
/// [HomeworkVoiceCommentBubble]。
class ArtworkVoiceCommentField extends StatefulWidget {
  const ArtworkVoiceCommentField({
    required this.path,
    required this.seconds,
    required this.onUpload,
    required this.onChanged,
    super.key,
  });

  /// 已上传语音的路径；没有时为空。
  final String path;
  final int seconds;
  final ArtworkVoiceUpload onUpload;
  final void Function(String path, int seconds) onChanged;

  @override
  State<ArtworkVoiceCommentField> createState() =>
      _ArtworkVoiceCommentFieldState();
}

class _ArtworkVoiceCommentFieldState extends State<ArtworkVoiceCommentField> {
  static const _maxSeconds = 120;
  static const _liveWaveLength = 56;
  static const _cancelThresholdY = -56.0;

  RecordingCapture? _capture;
  StreamSubscription<double>? _amplitudes;
  Timer? _timer;

  _VoicePhase _phase = _VoicePhase.idle;
  bool _willCancel = false;
  int _seconds = 0;
  List<double> _wave = List<double>.filled(_liveWaveLength, 0.18);

  bool get _hasVoice => widget.path.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasVoice) {
      _phase = _VoicePhase.ready;
    }
  }

  @override
  void didUpdateWidget(covariant ArtworkVoiceCommentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path &&
        _phase != _VoicePhase.recording &&
        _phase != _VoicePhase.uploading) {
      _phase = _hasVoice ? _VoicePhase.ready : _VoicePhase.idle;
    }
  }

  @override
  void dispose() {
    _amplitudes?.cancel();
    _timer?.cancel();
    _capture?.dispose();
    super.dispose();
  }

  double _normalize(double amplitude) {
    if (amplitude >= 0.0 && amplitude <= 1.0) {
      return amplitude.clamp(0.1, 1.0);
    }
    return ((amplitude + 50.0) / 50.0).clamp(0.1, 1.0);
  }

  _VoicePhase get _restPhase =>
      _hasVoice ? _VoicePhase.ready : _VoicePhase.idle;

  Future<void> _onPressStart() async {
    if (_phase == _VoicePhase.recording || _phase == _VoicePhase.uploading) {
      return;
    }
    final capture = _capture ?? (_capture = createRecordingCapture());
    final allowed = await capture.hasPermission();
    if (!mounted) {
      return;
    }
    if (!allowed) {
      AppToast.showError(context, '请允许使用麦克风后重试');
      return;
    }
    await _amplitudes?.cancel();
    _timer?.cancel();
    try {
      await capture.start(path: buildTemporaryRecordingPath());
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, '无法开始录制，请检查麦克风权限');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _VoicePhase.recording;
      _willCancel = false;
      _seconds = 0;
      _wave = List<double>.filled(_liveWaveLength, 0.18);
    });
    _amplitudes = capture.amplitudes.listen((amplitude) {
      if (!mounted || _phase != _VoicePhase.recording) {
        return;
      }
      setState(() => _wave = [..._wave.skip(1), _normalize(amplitude)]);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _phase != _VoicePhase.recording) {
        return;
      }
      if (_seconds < _maxSeconds) {
        setState(() => _seconds++);
      } else {
        unawaited(_stopAndUpload());
      }
    });
  }

  void _onPressMove(double offsetDy) {
    if (_phase != _VoicePhase.recording) {
      return;
    }
    final cancel = offsetDy < _cancelThresholdY;
    if (cancel != _willCancel) {
      setState(() => _willCancel = cancel);
    }
  }

  Future<void> _onPressEnd() async {
    if (_phase != _VoicePhase.recording) {
      return;
    }
    if (_willCancel) {
      _abort();
      return;
    }
    if (_seconds < 1) {
      _abort();
      if (mounted) {
        AppToast.showInfo(context, '说话时间太短');
      }
      return;
    }
    await _stopAndUpload();
  }

  void _abort() {
    _amplitudes?.cancel();
    _amplitudes = null;
    _timer?.cancel();
    _timer = null;
    unawaited(_capture?.cancel());
    if (!mounted || _phase != _VoicePhase.recording) {
      return;
    }
    setState(() {
      _phase = _restPhase;
      _willCancel = false;
      _seconds = 0;
    });
  }

  Future<void> _stopAndUpload() async {
    if (_phase != _VoicePhase.recording) {
      return;
    }
    final seconds = _seconds;
    await _amplitudes?.cancel();
    _amplitudes = null;
    _timer?.cancel();
    _timer = null;
    String? recorded;
    try {
      recorded = await _capture?.stop();
    } catch (_) {
      recorded = null;
    }
    if (!mounted) {
      return;
    }
    if (seconds < 1 || recorded == null || recorded.isEmpty) {
      setState(() => _phase = _restPhase);
      AppToast.showInfo(context, '说话时间太短');
      return;
    }
    setState(() {
      _phase = _VoicePhase.uploading;
      _willCancel = false;
    });
    String? saved;
    try {
      final bytes = await loadRecordedBytes(recorded);
      final webm = recorded.contains('.webm') || recorded.startsWith('blob:');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      saved = await widget.onUpload(
        bytes,
        'artwork_voice_$stamp.${webm ? 'webm' : 'm4a'}',
      );
    } catch (_) {
      saved = null;
    }
    if (!mounted) {
      return;
    }
    if (saved == null || saved.isEmpty) {
      setState(() => _phase = _restPhase);
      AppToast.showError(context, '语音上传失败，请重试');
      return;
    }
    setState(() => _phase = _VoicePhase.ready);
    widget.onChanged(saved, seconds);
  }

  void _delete() {
    setState(() => _phase = _VoicePhase.idle);
    widget.onChanged('', 0);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _VoicePhase.uploading:
        return _buildBar(
          left: const _HintBar(text: '语音上传中…', loading: true),
          enabled: false,
        );
      case _VoicePhase.ready:
        return Row(
          children: [
            Expanded(
              child: HomeworkVoiceCommentBubble(
                key: ValueKey('${widget.path}-${widget.seconds}'),
                relativePath: widget.path,
                durationSec: widget.seconds,
                accent: AppColors.brand,
                background: AppColors.brandWash,
              ),
            ),
            const SizedBox(width: 8),
            _MiniAction(
              asset: AppAssets.homeworkReviewVoiceIcon,
              semanticLabel: '重新录制语音评语',
              onTap: () => setState(() => _phase = _VoicePhase.idle),
            ),
            const SizedBox(width: 6),
            _MiniAction(
              asset: AppAssets.homeworkReviewDeleteIcon,
              semanticLabel: '删除语音评语',
              onTap: _delete,
            ),
          ],
        );
      case _VoicePhase.recording:
        return _buildBar(
          left: _RecordingCard(waveform: _wave, willCancel: _willCancel),
          enabled: true,
        );
      case _VoicePhase.idle:
        return _buildBar(
          left: const _HintBar(text: '按住右侧话筒说话，松开后上传'),
          enabled: true,
        );
    }
  }

  Widget _buildBar({required Widget left, required bool enabled}) {
    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 8),
          _HoldButton(
            recording: _phase == _VoicePhase.recording,
            willCancel: _willCancel,
            enabled: enabled,
            onPressStart: _onPressStart,
            onPressMove: _onPressMove,
            onPressEnd: _onPressEnd,
          ),
        ],
      ),
    );
  }
}

/// 话筒按钮左侧的灰底说明条，与按钮等高。
class _HintBar extends StatelessWidget {
  const _HintBar({required this.text, this.loading = false});

  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          if (loading) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                color: loading
                    ? AppColors.textSecondary
                    : AppColors.textPlaceholder,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 48×48 的按住说话按钮。
class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.recording,
    required this.willCancel,
    required this.enabled,
    required this.onPressStart,
    required this.onPressMove,
    required this.onPressEnd,
  });

  final bool recording;
  final bool willCancel;
  final bool enabled;
  final VoidCallback onPressStart;
  final ValueChanged<double> onPressMove;
  final VoidCallback onPressEnd;

  static const _size = 48.0;

  @override
  Widget build(BuildContext context) {
    final cancelling = recording && willCancel;
    final Widget icon;
    BoxDecoration? decoration;
    if (cancelling) {
      icon = const HomeworkAssetIcon(
        AppAssets.homeworkReviewVoiceIcon,
        size: _size,
        colorFilter: ColorFilter.mode(AppColors.surface, BlendMode.srcIn),
      );
      decoration = const BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      );
    } else {
      icon = HomeworkAssetIcon(
        recording
            ? AppAssets.homeworkReviewVoiceActiveIcon
            : AppAssets.homeworkReviewVoiceIcon,
        size: _size,
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: '按住说话，录制语音评语',
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: enabled ? (_) => onPressStart() : null,
          onLongPressMoveUpdate: enabled
              ? (details) => onPressMove(details.localOffsetFromOrigin.dy)
              : null,
          onLongPressEnd: enabled ? (_) => onPressEnd() : null,
          onLongPressCancel: enabled ? onPressEnd : null,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: Container(
              width: _size,
              height: _size,
              alignment: Alignment.center,
              decoration: decoration,
              child: ExcludeSemantics(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

/// 录制中左侧的条：实时波形 + 提示文案。
class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.waveform, required this.willCancel});

  final List<double> waveform;
  final bool willCancel;

  @override
  Widget build(BuildContext context) {
    final color = willCancel ? AppColors.danger : AppColors.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRect(
              child: _LiveWaveform(heights: waveform, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            willCancel ? '松开取消' : '松开发送 上滑取消',
            style: TextStyle(
              fontSize: 12,
              height: 1,
              color: AppColors.ink,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveWaveform extends StatelessWidget {
  const _LiveWaveform({required this.heights, required this.color});

  final List<double> heights;
  final Color color;

  static const _barCount = 28;
  static const _maxHeight = 28.0;
  static const _base = 3.0;
  static const _barWidth = 2.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 表单较窄时少画几根，避免波形撑出说明条。
        final fit = ((constraints.maxWidth + _gap) / (_barWidth + _gap))
            .floor()
            .clamp(4, _barCount);
        final bars = _sample(heights, fit);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < bars.length; i++) ...[
              Container(
                width: _barWidth,
                height: _base + bars[i] * (_maxHeight - _base),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(_barWidth),
                ),
              ),
              if (i < bars.length - 1) const SizedBox(width: _gap),
            ],
          ],
        );
      },
    );
  }

  static List<double> _sample(List<double> source, int count) {
    if (source.isEmpty) {
      return List<double>.filled(count, 0.2);
    }
    if (count <= 1) {
      return <double>[source.last.clamp(0.08, 1).toDouble()];
    }
    return List<double>.generate(count, (i) {
      final index = (i * (source.length - 1) / (count - 1)).round();
      return source[index].clamp(0.08, 1).toDouble();
    });
  }
}

/// 36×36 的图标按钮（重录、删除），用原版作品点评的图标。
class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.asset,
    required this.semanticLabel,
    required this.onTap,
  });

  final String asset;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: 36,
        height: 36,
        child: ExcludeSemantics(child: HomeworkAssetIcon(asset, size: 36)),
      ),
    );
  }
}
