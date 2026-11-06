import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../../../core/audio/mpv_player_release.dart';
import '../../data/circle_video_cache.dart';
import '../../state/circle_state.dart';
import 'circle_video_play_button.dart';

/// 沉浸媒体 contain 尺寸：在可用区域内等比缩放至最大，与 [_ImmersiveDouyinVideoFrame] 一致。
Size _immersiveContainSize({
  required double maxWidth,
  required double maxHeight,
  required double aspectRatio,
}) {
  if (maxWidth <= 0 || maxHeight <= 0 || aspectRatio <= 0) {
    return Size.zero;
  }
  final byHeight = Size(maxHeight * aspectRatio, maxHeight);
  if (byHeight.width <= maxWidth) return byHeight;
  return Size(maxWidth, maxWidth / aspectRatio);
}

/// 从 [VideoParams] 读取显示宽高（含 90° / 270° 旋转）。
(double, double)? _displaySizeFromVideoParams(VideoParams params) {
  final dw = params.dw;
  final dh = params.dh;
  if (dw == null || dh == null || dw <= 0 || dh <= 0) return null;
  final rotate = params.rotate ?? 0;
  if (rotate == 90 || rotate == 270) {
    return (dh.toDouble(), dw.toDouble());
  }
  return (dw.toDouble(), dh.toDouble());
}

/// 沉浸模式下的统一媒体播放壳：
/// - **图片**：盖一张大图 + 加载/失败兜底
/// - **视频**：`media_kit` 播放；竖屏 cover、横屏 contain（抖音式）+ 全屏进度拖动
/// - **音频**：同款交互（AnimatedIcons.play_pause + 全屏/底部进度条）
class CircleMediaPlayer extends StatefulWidget {
  const CircleMediaPlayer({
    super.key,
    required this.post,
    this.autoPlay = true,
    this.isActive = true,
    this.mediaStopEpoch = 0,
  });

  final CirclePost post;
  final bool autoPlay;

  /// 仅当前可见帖创建/播放媒体，避免 PageView 邻页同时占用解码器。
  final bool isActive;

  /// 与 [CircleController.stopMediaPlayback] 联动，退出页面时立刻停止。
  final int mediaStopEpoch;

  @override
  State<CircleMediaPlayer> createState() => _CircleMediaPlayerState();
}

class _CircleMediaPlayerState extends State<CircleMediaPlayer> {
  Player? _player;
  VideoController? _videoController;
  bool _loadingMedia = false;
  int _setupGeneration = 0;
  double? _videoAspectRatio;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<int?>? _videoWidthSub;
  StreamSubscription<int?>? _videoHeightSub;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      unawaited(_setupForCurrentPost());
    }
  }

  @override
  void didUpdateWidget(covariant CircleMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaStopEpoch != widget.mediaStopEpoch) {
      _teardownPlayer();
      return;
    }
    final postChanged = oldWidget.post.id != widget.post.id ||
        oldWidget.post.primaryMediaUrl != widget.post.primaryMediaUrl ||
        oldWidget.post.mediaKind != widget.post.mediaKind;
    final activeChanged = oldWidget.isActive != widget.isActive;

    if (postChanged) {
      _teardownPlayer();
      if (widget.isActive) {
        unawaited(_setupForCurrentPost());
      }
      return;
    }

    if (activeChanged) {
      if (widget.isActive) {
        unawaited(_setupForCurrentPost());
      } else {
        _teardownPlayer();
      }
    }
  }

  Future<void> _setupForCurrentPost() async {
    if (!widget.isActive) return;

    final url = widget.post.primaryMediaUrl;
    if (url.isEmpty || widget.post.mediaKind == PostMediaKind.image) return;

    final generation = ++_setupGeneration;
    final needsCache = CircleVideoCache.needsLocalCache(url);
    if (needsCache && mounted) {
      setState(() => _loadingMedia = true);
    }

    var playbackSource = url;
    if (needsCache) {
      try {
        playbackSource = await CircleVideoCache.resolvePlaybackSource(url);
      } catch (_) {
        playbackSource = url;
      }
    }

    if (!mounted ||
        generation != _setupGeneration ||
        !widget.isActive ||
        widget.post.primaryMediaUrl != url) {
      return;
    }

    await MpvPlayerRelease.awaitPending();
    if (!mounted ||
        generation != _setupGeneration ||
        !widget.isActive ||
        widget.post.primaryMediaUrl != url) {
      return;
    }

    final player = Player();
    _player = player;
    if (widget.post.mediaKind == PostMediaKind.video) {
      _videoController = VideoController(player);
    }

    try {
      var opened = false;
      try {
        await _openAndLoop(player, playbackSource);
        opened = true;
      } catch (_) {
        if (playbackSource != url) {
          await _openAndLoop(player, url);
          opened = true;
        } else {
          rethrow;
        }
      }
      if (!mounted ||
          generation != _setupGeneration ||
          !widget.isActive ||
          _player != player) {
        unawaited(MpvPlayerRelease.release(player));
        return;
      }
      if (opened &&
          widget.post.mediaKind == PostMediaKind.video &&
          generation == _setupGeneration &&
          mounted) {
        _attachVideoLayoutListener(player);
      }
    } catch (_) {
      _teardownPlayer();
    } finally {
      if (mounted && generation == _setupGeneration) {
        setState(() => _loadingMedia = false);
      }
    }
  }

  Future<void> _openAndLoop(Player player, String url) async {
    await player.setPlaylistMode(PlaylistMode.single);
    await player.open(Media(url), play: widget.autoPlay);
  }

  void _attachVideoLayoutListener(Player player) {
    _detachVideoLayoutListener();
    void syncLayout() => _syncVideoLayout(player);

    syncLayout();
    _videoParamsSub = player.stream.videoParams.listen((_) => syncLayout());
    _videoWidthSub = player.stream.width.listen((_) => syncLayout());
    _videoHeightSub = player.stream.height.listen((_) => syncLayout());
  }

  void _syncVideoLayout(Player player) {
    final aspect = _resolvedVideoAspectRatio(player);
    if (!mounted) return;
    if (_videoAspectRatio != null &&
        (_videoAspectRatio! - aspect).abs() <= 0.001) {
      return;
    }
    setState(() => _videoAspectRatio = aspect);
  }

  double? _displayAspectFromPlayer(Player player) {
    final fromParams = _displaySizeFromVideoParams(player.state.videoParams);
    if (fromParams != null) {
      return fromParams.$1 / fromParams.$2;
    }
    final w = player.state.width;
    final h = player.state.height;
    if (w != null && h != null && w > 0 && h > 0) {
      return w / h;
    }
    return null;
  }

  double _resolvedVideoAspectRatio(Player player) {
    final fromDecoder = _displayAspectFromPlayer(player);
    final fromPost = widget.post.imageAspectRatio;

    if (fromDecoder != null) {
      // 接口没有视频宽高时，最终比例完全以播放器加载后的解码元数据为准。
      // 只有接口明确给出 videoWidth/videoHeight 时，才用它纠正解码器可能缺失 rotate 的情况。
      if (widget.post.hasExplicitAspectRatio &&
          fromDecoder > 1 &&
          fromPost <= 1) {
        return fromPost;
      }
      return fromDecoder;
    }
    return _fallbackVideoAspectRatio();
  }

  /// 解码完成前兜底：优先帖子比例；横图封面时退回 9:16。
  double _fallbackVideoAspectRatio() {
    final api = widget.post.imageAspectRatio;
    if (widget.post.mediaKind == PostMediaKind.video) {
      if (api <= 1) return api;
      return 9 / 16;
    }
    return api;
  }

  void _detachVideoLayoutListener() {
    _videoParamsSub?.cancel();
    _videoWidthSub?.cancel();
    _videoHeightSub?.cancel();
    _videoParamsSub = null;
    _videoWidthSub = null;
    _videoHeightSub = null;
    _videoAspectRatio = null;
  }

  double get _effectiveVideoAspectRatio =>
      _videoAspectRatio ?? _fallbackVideoAspectRatio();

  void _teardownPlayer() {
    _setupGeneration++;
    _detachVideoLayoutListener();
    final player = _player;
    _player = null;
    _videoController = null;
    _loadingMedia = false;
    if (player != null) {
      unawaited(MpvPlayerRelease.release(player));
    }
  }

  @override
  void deactivate() {
    _teardownPlayer();
    super.deactivate();
  }

  @override
  void dispose() {
    if (_player != null) {
      _teardownPlayer();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.post.mediaKind) {
      PostMediaKind.image => _ImageBackdrop(
          url: widget.post.imageUrl,
          aspectRatioHint: widget.post.hasExplicitAspectRatio
              ? widget.post.imageAspectRatio
              : null,
          adaptOrientation: true,
        ),
      PostMediaKind.video => _buildVideoBody(),
      PostMediaKind.audio => _buildAudioBody(),
    };
  }

  Widget _buildVideoBody() {
    final controller = _videoController;
    final url = widget.post.primaryMediaUrl;
    if (url.isEmpty || controller == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _ImageBackdrop(url: widget.post.imageUrl),
          if (_loadingMedia)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2,
              ),
            ),
        ],
      );
    }
    return _ImmersiveDouyinVideoFrame(
      controller: controller,
      player: _player!,
      aspectRatio: _effectiveVideoAspectRatio,
    );
  }

  Widget _buildAudioBody() {
    final player = _player;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.post.imageUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: const ColorFilter.mode(
              Color(0x55000000),
              BlendMode.darken,
            ),
            child: Image.network(
              widget.post.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _AudioBackdrop(),
            ),
          )
        else
          const _AudioBackdrop(),
        if (player != null)
          Positioned.fill(
            child: _DouyinMediaControls(player: player),
          ),
      ],
    );
  }
}

/// 沉浸视频渲染：竖屏 cover 铺满，横屏 contain 留黑边；控件叠在最上层。
class _ImmersiveDouyinVideoFrame extends StatelessWidget {
  const _ImmersiveDouyinVideoFrame({
    required this.controller,
    required this.player,
    required this.aspectRatio,
  });

  final VideoController controller;
  final Player player;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final isPortrait = aspectRatio <= 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final fittedSize = _immersiveContainSize(
          maxWidth: maxW,
          maxHeight: maxH,
          aspectRatio: aspectRatio,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF000000)),
            if (isPortrait)
              Center(
                child: SizedBox(
                  width: fittedSize.width,
                  height: fittedSize.height,
                  child: Video(
                    controller: controller,
                    width: fittedSize.width,
                    height: fittedSize.height,
                    fit: BoxFit.fill,
                    aspectRatio: aspectRatio,
                    fill: const Color(0xFF000000),
                    controls: (_) => const SizedBox.shrink(),
                  ),
                ),
              )
            else
              Center(
                child: SizedBox(
                  width: fittedSize.width,
                  height: fittedSize.height,
                  child: Video(
                    controller: controller,
                    width: fittedSize.width,
                    height: fittedSize.height,
                    fit: BoxFit.fill,
                    aspectRatio: aspectRatio,
                    fill: const Color(0xFF000000),
                    controls: (_) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Positioned.fill(
              child: _DouyinMediaControls(
                player: player,
                listStylePlayPause: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 抖音式全屏媒体控件：
/// - **单击**任意位置：播放 / 暂停
/// - **全屏横向滑动**：拖动进度（拖动时暂停，松手恢复）
/// - **纵向滑动**：不拦截，交给外层 PageView 翻页
/// - 底部细进度条随播放更新；拖动时变粗并显示时间
class _DouyinMediaControls extends StatefulWidget {
  const _DouyinMediaControls({
    required this.player,
    this.listStylePlayPause = false,
  });

  final Player player;
  final bool listStylePlayPause;

  @override
  State<_DouyinMediaControls> createState() => _DouyinMediaControlsState();
}

class _DouyinMediaControlsState extends State<_DouyinMediaControls>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _playingSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  bool _dragging = false;
  double _dragRatio = 0;
  bool _resumeAfterDrag = false;
  DateTime _lastPositionUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  AnimationController? _iconAnimation;

  @override
  void initState() {
    super.initState();
    if (!widget.listStylePlayPause) {
      _iconAnimation = AnimationController(
        vsync: this,
        value: widget.player.state.playing ? 1 : 0,
        duration: const Duration(milliseconds: 200),
      );
    }
    _playing = widget.player.state.playing;
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _posSub = widget.player.stream.position.listen((p) {
      if (!mounted || _dragging) return;
      final now = DateTime.now();
      if (now.difference(_lastPositionUiUpdate) <
          const Duration(milliseconds: 120)) {
        return;
      }
      _lastPositionUiUpdate = now;
      setState(() => _position = p);
    });
    _durSub = widget.player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _playingSub = widget.player.stream.playing.listen((p) {
      if (!mounted) return;
      setState(() => _playing = p);
      final iconAnimation = _iconAnimation;
      if (iconAnimation == null) return;
      if (p) {
        iconAnimation.forward();
      } else {
        iconAnimation.reverse();
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _iconAnimation?.dispose();
    super.dispose();
  }

  double get _displayRatio {
    if (_dragging) return _dragRatio;
    final totalMs = _duration.inMilliseconds;
    if (totalMs <= 0) return 0;
    return (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: <Type, GestureRecognizerFactory>{
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(),
              (TapGestureRecognizer instance) {
                instance.onTap = () {
                  if (!_dragging) widget.player.playOrPause();
                };
              },
            ),
            HorizontalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
              (HorizontalDragGestureRecognizer instance) {
                instance.onStart = (d) => _onDragStart(d.localPosition.dx, width);
                instance.onUpdate = (d) =>
                    _onDragUpdate(d.localPosition.dx, width);
                instance.onEnd = (_) => unawaited(_onDragEnd());
                instance.onCancel = _onDragCancel;
              },
            ),
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_dragging)
                ColoredBox(color: Colors.black.withValues(alpha: 0.12)),
              if (!_dragging && !_playing)
                Center(
                  child: widget.listStylePlayPause
                      ? const CircleVideoPlayButton()
                      : AnimatedIcon(
                          progress: _iconAnimation!,
                          icon: AnimatedIcons.play_pause,
                          size: ui(56),
                          color: Colors.white,
                        ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildProgressBar(ui, width),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(double Function(double) ui, double width) {
    final barHeight = _dragging ? ui(6) : ui(2);
    return Padding(
      padding: EdgeInsets.only(bottom: _dragging ? ui(4) : 0),
      child: SizedBox(
        height: ui(44),
        width: double.infinity,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: barHeight,
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(barHeight / 2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _displayRatio,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  ),
                ),
                if (_dragging)
                  Positioned(
                    left: (width * _displayRatio).clamp(0.0, width) - ui(6),
                    top: (barHeight - ui(12)) / 2,
                    child: Container(
                      width: ui(12),
                      height: ui(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onDragStart(double dx, double width) {
    if (width <= 0 || _duration.inMilliseconds <= 0) return;
    _resumeAfterDrag = widget.player.state.playing;
    if (_resumeAfterDrag) {
      unawaited(widget.player.pause());
    }
    final ratio = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _dragging = true;
      _dragRatio = ratio;
    });
    unawaited(_seekToRatio(ratio));
  }

  void _onDragUpdate(double dx, double width) {
    if (!_dragging || width <= 0 || _duration.inMilliseconds <= 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    if (ratio == _dragRatio) return;
    setState(() => _dragRatio = ratio);
    unawaited(_seekToRatio(ratio));
  }

  Future<void> _onDragEnd() async {
    if (!_dragging) return;
    final ratio = _dragRatio;
    final resume = _resumeAfterDrag;
    setState(() {
      _dragging = false;
      _resumeAfterDrag = false;
    });
    await _seekToRatio(ratio);
    if (resume && mounted) {
      await widget.player.play();
    }
  }

  void _onDragCancel() {
    if (!_dragging) return;
    final resume = _resumeAfterDrag;
    setState(() {
      _dragging = false;
      _resumeAfterDrag = false;
    });
    if (resume) {
      unawaited(widget.player.play());
    }
  }

  Future<void> _seekToRatio(double ratio) async {
    if (_duration.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * ratio).round(),
    );
    await widget.player.seek(target);
  }
}

/// 沉浸模式图片底图：
/// - `adaptOrientation == false`（视频/音频封面兜底）：始终 cover 铺满。
/// - `adaptOrientation == true`（图片帖）：与沉浸视频同一套 contain 布局——
///   纯黑底 + 等比居中，竖图 / 横图均完整展示并留黑边。
///   真实比例以解码后的图片尺寸为准，解码完成前用接口给出的比例兜底。
class _ImageBackdrop extends StatefulWidget {
  const _ImageBackdrop({
    required this.url,
    this.aspectRatioHint,
    this.adaptOrientation = false,
  });

  final String url;
  final double? aspectRatioHint;
  final bool adaptOrientation;

  @override
  State<_ImageBackdrop> createState() => _ImageBackdropState();
}

class _ImageBackdropState extends State<_ImageBackdrop> {
  ImageProvider? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _resolvedAspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _ImageBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolvedAspectRatio = null;
      _resolveImage();
    }
  }

  void _resolveImage() {
    _detach();
    if (widget.url.isEmpty || !widget.adaptOrientation) {
      _provider = widget.url.isEmpty ? null : NetworkImage(widget.url);
      return;
    }
    final provider = NetworkImage(widget.url);
    _provider = provider;
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        final w = info.image.width;
        final h = info.image.height;
        if (!mounted || w <= 0 || h <= 0) return;
        final aspect = w / h;
        if (_resolvedAspectRatio == null ||
            (_resolvedAspectRatio! - aspect).abs() > 0.001) {
          setState(() => _resolvedAspectRatio = aspect);
        }
      },
      onError: (_, _) {},
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _detach() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) {
      return const ColoredBox(color: Color(0xFF1B1530));
    }

    final imageProvider = _provider ?? NetworkImage(widget.url);
    final imageError = const ColoredBox(color: Color(0xFF1B1530));

    if (!widget.adaptOrientation) {
      return Image(
        image: imageProvider,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => imageError,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox.expand();
        },
      );
    }

    // 与沉浸视频 [_ImmersiveDouyinVideoFrame] 同一套 contain 居中布局。
    final aspect = _resolvedAspectRatio ?? widget.aspectRatioHint ?? 9 / 16;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fittedSize = _immersiveContainSize(
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          aspectRatio: aspect,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF000000)),
            Center(
              child: SizedBox(
                width: fittedSize.width,
                height: fittedSize.height,
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stack) => imageError,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AudioBackdrop extends StatelessWidget {
  const _AudioBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1E66), Color(0xFF0B081A)],
        ),
      ),
    );
  }
}
