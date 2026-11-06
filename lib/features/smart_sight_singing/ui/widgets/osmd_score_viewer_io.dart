import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'osmd_score_shell.dart';

const _readyChannel = 'OsmdHostReady';
const _loadedChannel = 'OsmdScoreLoaded';
const _base64ChunkLength = 48 * 1024;

/// iPad / 原生 WebView：本地 OSMD + 分片注入 MusicXML，规避 WKWebView
/// 对 file:// fetch 和大字符串执行的限制。
class OsmdScoreViewer extends StatefulWidget {
  const OsmdScoreViewer({
    required this.musicXml,
    required this.playbackMs,
    this.onsetMs = const <int>[],
    this.fallback,
    super.key,
  });

  final String musicXml;
  final int playbackMs;
  final List<int> onsetMs;
  final Widget? fallback;

  @override
  State<OsmdScoreViewer> createState() => _OsmdScoreViewerState();
}

class _OsmdScoreViewerState extends State<OsmdScoreViewer> {
  static Future<Directory>? _hostDirFuture;

  static var _counter = 0;

  late final WebViewController _controller;
  late final String _containerId;
  late final Directory _hostDir;

  var _hostReady = false;
  var _scoreLoaded = false;
  var _failed = false;
  String? _failureMessage;

  String _lastLoadedXml = '';
  List<int> _lastOnsets = const <int>[];
  int _lastSeekIndex = -1;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _containerId = 'sight-osmd-${_counter++}';
    _controller = _createController();
    unawaited(_bootstrapHost());
  }

  WebViewController _createController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F6F8))
      ..addJavaScriptChannel(
        _readyChannel,
        onMessageReceived: (JavaScriptMessage msg) {
          if (!mounted) return;
          if (msg.message == 'ready') {
            setState(() => _hostReady = true);
            unawaited(_applyXml(force: true));
            _applyOnsets(force: true);
          } else {
            setState(() {
              _failed = true;
              _failureMessage = '乐谱渲染器初始化失败';
            });
          }
        },
      )
      ..addJavaScriptChannel(
        _loadedChannel,
        onMessageReceived: (JavaScriptMessage msg) {
          if (!mounted) return;
          if (msg.message == 'loaded:$_containerId') {
            setState(() => _scoreLoaded = true);
            _applySeek(force: true);
          } else if (msg.message.startsWith('error:')) {
            final message = _decodeLoadError(msg.message);
            setState(() {
              _failed = true;
              _failureMessage = message == null || message.isEmpty
                  ? 'MusicXML 渲染失败'
                  : 'MusicXML 渲染失败：$message';
            });
          }
        },
      );

    return controller;
  }

  static Future<Directory> _ensureHostDir() {
    return _hostDirFuture ??= () async {
      final dir = Directory(
        '${Directory.systemTemp.path}/sight_singing_osmd_host',
      );
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final osmdAsset = await rootBundle.load(
        'assets/smart_sight_singing/${OsmdScoreShell.osmdScriptFileName}',
      );
      await File(
        '${dir.path}/${OsmdScoreShell.osmdScriptFileName}',
      ).writeAsBytes(
        osmdAsset.buffer.asUint8List(
          osmdAsset.offsetInBytes,
          osmdAsset.lengthInBytes,
        ),
        flush: true,
      );

      return dir;
    }();
  }

  Future<void> _bootstrapHost() async {
    try {
      _hostDir = await _ensureHostDir();
      final htmlPath =
          '${_hostDir.path}/${_containerId}_${OsmdScoreShell.hostHtmlFileName}';
      await File(htmlPath).writeAsString(
        OsmdScoreShell.hostHtml(containerId: _containerId),
        flush: true,
      );

      final platform = _controller.platform;
      if (platform is WebKitWebViewController) {
        await platform.loadFileWithParams(
          WebKitLoadFileParams(
            absoluteFilePath: htmlPath,
            readAccessPath: _hostDir.path,
          ),
        );
      } else {
        await _controller.loadFile(htmlPath);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _failureMessage = e is StateError ? e.message : '$e';
      });
    }
  }

  @override
  void didUpdateWidget(covariant OsmdScoreViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hostReady) return;
    if (oldWidget.musicXml != widget.musicXml) {
      unawaited(_applyXml());
    }
    if (!listEquals(oldWidget.onsetMs, widget.onsetMs)) {
      _applyOnsets();
    }
    if (oldWidget.playbackMs != widget.playbackMs) {
      _applySeek();
    }
  }

  Future<void> _applyXml({bool force = false}) async {
    final xml = widget.musicXml.trim();
    if (xml.isEmpty || !_hostReady) return;
    if (!force && xml == _lastLoadedXml) return;

    final generation = ++_loadGeneration;
    _lastLoadedXml = xml;
    _lastSeekIndex = -1;
    _scoreLoaded = false;
    if (_failed && mounted) {
      setState(() {
        _failed = false;
        _failureMessage = null;
      });
    }

    try {
      final divId = jsonEncode(_containerId);
      await _runJsRequired(
        'window.__SightSingingOsmd && window.__SightSingingOsmd.beginBase64Load($divId);',
      );

      final encoded = base64Encode(utf8.encode(xml));
      for (
        var offset = 0;
        offset < encoded.length;
        offset += _base64ChunkLength
      ) {
        if (!mounted || generation != _loadGeneration) return;
        final next = offset + _base64ChunkLength;
        final end = next < encoded.length ? next : encoded.length;
        final chunk = jsonEncode(encoded.substring(offset, end));
        await _runJsRequired(
          'window.__SightSingingOsmd && window.__SightSingingOsmd.appendBase64Chunk($divId, $chunk);',
        );
      }

      if (!mounted || generation != _loadGeneration) return;
      await _runJsRequired(
        'window.__SightSingingOsmd && window.__SightSingingOsmd.finishBase64Load($divId);',
      );
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _failed = true;
        _failureMessage = 'MusicXML 送入渲染器失败';
      });
    }
  }

  void _applyOnsets({bool force = false}) {
    if (!_hostReady) return;
    if (!force && listEquals(_lastOnsets, widget.onsetMs)) return;
    _lastOnsets = List<int>.unmodifiable(widget.onsetMs);
    _lastSeekIndex = -1;

    final divId = jsonEncode(_containerId);
    final encoded = jsonEncode(widget.onsetMs);
    unawaited(
      _runJs(
        'window.__SightSingingOsmd && window.__SightSingingOsmd.setOnsets($divId, $encoded);',
      ),
    );
  }

  void _applySeek({bool force = false}) {
    if (!_hostReady || !_scoreLoaded) return;

    final index = _noteIndexAt(widget.playbackMs);
    if (!force && index == _lastSeekIndex) return;
    _lastSeekIndex = index;

    final divId = jsonEncode(_containerId);
    unawaited(
      _runJs(
        'window.__SightSingingOsmd && window.__SightSingingOsmd.seek($divId, ${widget.playbackMs});',
      ),
    );
  }

  int _noteIndexAt(int ms) {
    final onsets = widget.onsetMs;
    if (onsets.isEmpty || ms < onsets.first) return -1;

    var lo = 0;
    var hi = onsets.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (onsets[mid] <= ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return (lo - 1).clamp(0, onsets.length - 1);
  }

  Future<void> _runJs(String js) async {
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // WebView 销毁时忽略。
    }
  }

  Future<void> _runJsRequired(String js) => _controller.runJavaScript(js);

  String? _decodeLoadError(String message) {
    final prefix = 'error:$_containerId';
    if (!message.startsWith(prefix)) return null;
    if (message.length <= prefix.length + 1) return null;
    final encoded = message.substring(prefix.length + 1);
    try {
      return Uri.decodeComponent(encoded);
    } catch (_) {
      return encoded;
    }
  }

  @override
  void dispose() {
    final divId = jsonEncode(_containerId);
    unawaited(
      _runJs(
        'window.__SightSingingOsmd && window.__SightSingingOsmd.dispose($divId);',
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed && widget.fallback != null) {
      return widget.fallback!;
    }

    final child = _failed
        ? _OsmdErrorPlaceholder(message: _failureMessage)
        : WebViewWidget(
            controller: _controller,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
            },
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

class _OsmdErrorPlaceholder extends StatelessWidget {
  const _OsmdErrorPlaceholder({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message?.isNotEmpty == true ? '乐谱加载失败：$message' : '乐谱加载失败',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}
