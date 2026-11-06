import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_loading_indicator.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/audio/mpv_player_smooth.dart';

/// 原生平台（iOS / Android / 桌面）通用文件内嵌预览。
///
/// Web 端有 iframe + Office Online 等"浏览器内置"渲染能力，
/// 原生平台则需要逐类型自己实现：
/// - PDF：用 [PdfViewer.uri] 跑 pdfrx，与 theory 页面同款渲染、加载/错误
///   样式（参见 `lib/core/widgets/pdf/app_pdf_view_native.dart`）。
/// - 图片：直接交给 [CachedNetworkImage]，居中、按比例缩放。
/// - 视频：media_kit 播放器 + 系统风格控制条（示范视频、写生实录等）。
/// - 其它（音频 / Office / 文本 / 未知后缀）：返回 [placeholder]
///   或一个友好的占位提示，让上层走"在浏览器中查看 / 下载"路径。
class CoursewareInlinePreview extends StatelessWidget {
  const CoursewareInlinePreview({
    super.key,
    required this.url,
    this.placeholder,
    this.authToken = '',
  });

  final String url;
  final Widget? placeholder;

  /// 后端鉴权 token，会作为 `app-token` 请求头附加到 PDF 下载请求上，
  /// 与 theory 页面的 PDF 一致。courseware 的资源链 URL 大多本身就
  /// 是公开静态资源，没有 token 也能正常加载，这里仅保险起见。
  final String authToken;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return placeholder ?? const _UnsupportedPreview();
    }
    switch (_kindForUrl(url)) {
      case _PreviewKind.pdf:
        return _CoursewarePdfPreview(url: url, authToken: authToken);
      case _PreviewKind.image:
        return _CoursewareImagePreview(url: url);
      case _PreviewKind.video:
        return _CoursewareVideoPreview(url: url);
      case _PreviewKind.audio:
      case _PreviewKind.office:
      case _PreviewKind.text:
      case _PreviewKind.unknown:
        return placeholder ?? const _UnsupportedPreview();
    }
  }
}

/// 原生 PDF 预览：与 theory 页面 PDF 阅读器使用相同的 pdfrx 调用约定，
/// 包括自定义加载条、错误占位、去掉每页四周的黑色阴影等。
class _CoursewarePdfPreview extends StatelessWidget {
  const _CoursewarePdfPreview({required this.url, required this.authToken});

  final String url;
  final String authToken;

  @override
  Widget build(BuildContext context) {
    final headers = <String, String>{
      if (authToken.isNotEmpty) 'app-token': authToken,
    };
    return PdfViewer.uri(
      Uri.parse(url),
      headers: headers.isEmpty ? null : headers,
      withCredentials: true,
      params: PdfViewerParams(
        backgroundColor: const Color(0xFFFAFAFB),
        margin: 12,
        // 去掉 pdfrx 默认每页四周的黑色 drop shadow，让 PDF 干净地贴在
        // courseware 卡片背景上。
        pageDropShadow: null,
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
          final progress = (totalBytes != null && totalBytes > 0)
              ? bytesDownloaded / totalBytes
              : null;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppLoadingIndicator(value: progress),
                const SizedBox(height: 12),
                Text(
                  progress == null
                      ? 'PDF 加载中…'
                      : 'PDF 加载中…${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF6D6B75),
                    fontSize: 12,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          );
        },
        errorBannerBuilder: (context, error, stackTrace, documentRef) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: Color(0xFFC9C6D8),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PDF 加载失败，请稍后重试',
                    style: TextStyle(
                      color: Color(0xFF6D6B75),
                      fontSize: 13,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    url,
                    style: const TextStyle(
                      color: Color(0xFF715EFE),
                      fontSize: 11,
                      fontFamily: 'Manrope',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    error.toString(),
                    style: const TextStyle(
                      color: Color(0xFFB6B5BB),
                      fontSize: 11,
                      fontFamily: 'Manrope',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 原生图片预览：居中、按比例缩放，使用 [CachedNetworkImage] 共享缓存。
class _CoursewareImagePreview extends StatelessWidget {
  const _CoursewareImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAFAFD),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            placeholder: (context, _) => const Center(
              child: AppLoadingIndicator(),
            ),
            errorWidget: (context, _, _) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: Color(0xFFC9C6D8),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 原生视频预览：进入页面加载但不自动播放，离开页面释放播放器。
class _CoursewareVideoPreview extends StatefulWidget {
  const _CoursewareVideoPreview({required this.url});

  final String url;

  @override
  State<_CoursewareVideoPreview> createState() =>
      _CoursewareVideoPreviewState();
}

class _CoursewareVideoPreviewState extends State<_CoursewareVideoPreview> {
  Player? _player;
  VideoController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant _CoursewareVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _release();
      _failed = false;
      _open();
    }
  }

  void _open() {
    try {
      MediaKit.ensureInitialized();
      final player = Player();
      _player = player;
      _controller = VideoController(player);
      unawaited(
        MpvPlayerSmooth.openSmooth(
          player,
          Media(widget.url),
          play: false,
        ).catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        }),
      );
    } catch (_) {
      _release();
      _failed = true;
    }
  }

  void _release() {
    final player = _player;
    _player = null;
    _controller = null;
    if (player != null) {
      unawaited(player.dispose());
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null) {
      return const _UnsupportedPreview(message: '视频加载失败，请稍后重试。');
    }
    return Video(controller: controller, fill: Colors.black);
  }
}

class _UnsupportedPreview extends StatelessWidget {
  const _UnsupportedPreview({
    this.message = '当前平台暂不支持预览此文件类型，请在浏览器中查看或下载。',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF8F86A8)),
        ),
      ),
    );
  }
}

enum _PreviewKind { image, pdf, audio, video, office, text, unknown }

/// 与 `courseware_inline_preview_web.dart` 中的判定逻辑保持一致。
/// 两边都用文件后缀（去掉 query / fragment 后）来分流，避免出现
/// "web 端用 iframe 渲染、原生端却没有任何对应分支"的不一致行为。
_PreviewKind _kindForUrl(String url) {
  final lower = url.toLowerCase();
  final pathOnly = lower.split('?').first.split('#').first;
  bool hasExt(List<String> exts) {
    for (final e in exts) {
      if (pathOnly.endsWith('.$e')) return true;
    }
    return false;
  }

  if (hasExt(const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'])) {
    return _PreviewKind.image;
  }
  if (hasExt(const ['pdf'])) return _PreviewKind.pdf;
  if (hasExt(const ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'])) {
    return _PreviewKind.audio;
  }
  if (hasExt(const ['mp4', 'webm', 'mov', 'm4v', 'ogv'])) {
    return _PreviewKind.video;
  }
  if (hasExt(const ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'])) {
    return _PreviewKind.office;
  }
  if (hasExt(const ['txt', 'md', 'log', 'json', 'xml', 'csv', 'rtf'])) {
    return _PreviewKind.text;
  }
  return _PreviewKind.unknown;
}
