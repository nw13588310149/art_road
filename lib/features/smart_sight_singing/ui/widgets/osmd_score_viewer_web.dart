import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'osmd_score_shell.dart';

const String _kBridgeKey = '__SightSingingOsmd';
const String _kBridgeReadyKey = '__SightSingingOsmdReady';
const String _kBridgeVersionKey = '__SightSingingOsmdBridgeVersion';
const int _kBridgeVersion = 2;
const String _kOsmdLibKey = 'opensheetmusicdisplay';

/// 全局只需注入一次：CDN OSMD 库 + 桥脚本。
Future<void>? _readyFuture;

Future<void> _ensureOsmdReady() {
  final existing = _readyFuture;
  if (existing != null) {
    return existing;
  }
  final completer = Completer<void>();
  _readyFuture = completer.future;

  () async {
    try {
      await _loadOsmdLibrary();
      _injectBridgeScript();
      web.window.setProperty(_kBridgeReadyKey.toJS, true.toJS);
      completer.complete();
    } catch (e, s) {
      _readyFuture = null;
      completer.completeError(e, s);
    }
  }();

  return completer.future;
}

Future<void> _loadOsmdLibrary() async {
  if (web.window.getProperty<JSAny?>(_kOsmdLibKey.toJS) != null) {
    return;
  }
  final completer = Completer<void>();
  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..src = OsmdScoreShell.osmdCdn
    ..async = true;

  void onLoadOk(web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }

  void onLoadErr(web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('OSMD 库加载失败，请检查网络。'));
    }
  }

  script.addEventListener('load', onLoadOk.toJS);
  script.addEventListener('error', onLoadErr.toJS);
  web.document.head!.appendChild(script);

  // 给个上限，避免没网时一直挂着。
  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw StateError('OSMD 库加载超时'),
  );
}

void _injectBridgeScript() {
  final existingVersion =
      web.window.getProperty<JSNumber?>(_kBridgeVersionKey.toJS)?.toDartInt;
  if (web.window.getProperty<JSAny?>(_kBridgeKey.toJS) != null &&
      existingVersion == _kBridgeVersion) {
    return;
  }
  web.window.delete(_kBridgeKey.toJS);
  final bridgeScript =
      web.document.createElement('script') as web.HTMLScriptElement
        ..text = OsmdScoreShell.bridgeJs;
  web.document.head!.appendChild(bridgeScript);
  web.window.setProperty(_kBridgeVersionKey.toJS, _kBridgeVersion.toJS);
}

JSObject? _bridge() {
  return web.window.getProperty<JSObject?>(_kBridgeKey.toJS);
}

/// Web 端通过 HtmlElementView + 主文档 DOM 渲染 OSMD 五线谱。
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
  State<OsmdScoreViewer> createState() => _OsmdScoreViewerWebState();
}

class _OsmdScoreViewerWebState extends State<OsmdScoreViewer> {
  static var _counter = 0;
  late final String _containerId;
  late final web.HTMLDivElement _scrollWrap;
  late final web.HTMLDivElement _scoreDiv;

  var _initialized = false;
  var _failed = false;
  String? _failureMessage;

  String _lastLoadedXml = '';
  List<int> _lastOnsets = const <int>[];
  int _lastSeekMs = -1;

  @override
  void initState() {
    super.initState();
    _containerId = 'sight-osmd-${_counter++}';

    _scoreDiv = (web.document.createElement('div') as web.HTMLDivElement)
      ..id = _containerId;
    _scoreDiv.style.setProperty('width', '100%');
    _scoreDiv.style.setProperty('min-height', '100%');

    _scrollWrap = (web.document.createElement('div') as web.HTMLDivElement);
    _scrollWrap.style
      ..setProperty('width', '100%')
      ..setProperty('height', '100%')
      ..setProperty('overflow', 'auto')
      ..setProperty('background', '#F5F6F8')
      ..setProperty('padding', '8px 12px 16px')
      ..setProperty('box-sizing', 'border-box');
    _scrollWrap.appendChild(_scoreDiv);

    ui_web.platformViewRegistry.registerViewFactory(
      _containerId,
      (int _) => _scrollWrap,
    );

    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _ensureOsmdReady();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _failureMessage = e is StateError ? e.message : '$e';
      });
      return;
    }

    // 等 platform view 真正挂到 DOM。
    var attempts = 0;
    while (mounted &&
        web.document.getElementById(_containerId) == null &&
        attempts < 40) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      attempts++;
    }
    if (!mounted) return;
    if (web.document.getElementById(_containerId) == null) {
      setState(() {
        _failed = true;
        _failureMessage = '乐谱容器初始化失败';
      });
      return;
    }

    final bridge = _bridge();
    final created = bridge?.callMethod<JSAny?>(
      'create'.toJS,
      _containerId.toJS,
    );
    if (created == null) {
      setState(() {
        _failed = true;
        _failureMessage = '乐谱渲染器未就绪';
      });
      return;
    }

    setState(() => _initialized = true);

    _applyXml(force: true);
    _applyOnsets(force: true);
    _applySeek(force: true);
  }

  @override
  void didUpdateWidget(covariant OsmdScoreViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized) return;
    if (oldWidget.musicXml != widget.musicXml) {
      _applyXml();
    }
    if (!listEquals(oldWidget.onsetMs, widget.onsetMs)) {
      _applyOnsets();
    }
    if (oldWidget.playbackMs != widget.playbackMs) {
      _applySeek();
    }
  }

  void _applyXml({bool force = false}) {
    final xml = widget.musicXml.trim();
    if (xml.isEmpty) return;
    if (!force && xml == _lastLoadedXml) return;
    _lastLoadedXml = xml;
    _lastSeekMs = -1;
    _bridge()?.callMethod<JSAny?>('load'.toJS, _containerId.toJS, xml.toJS);
  }

  void _applyOnsets({bool force = false}) {
    if (!force && listEquals(_lastOnsets, widget.onsetMs)) return;
    _lastOnsets = List<int>.unmodifiable(widget.onsetMs);
    final arr = <JSAny?>[for (final v in widget.onsetMs) v.toJS].toJS;
    _bridge()?.callMethod<JSAny?>('setOnsets'.toJS, _containerId.toJS, arr);
  }

  void _applySeek({bool force = false}) {
    final ms = widget.playbackMs;
    if (!force && ms == _lastSeekMs) return;
    _lastSeekMs = ms;
    _bridge()?.callMethod<JSAny?>('seek'.toJS, _containerId.toJS, ms.toJS);
  }

  @override
  void dispose() {
    try {
      _bridge()?.callMethod<JSAny?>('dispose'.toJS, _containerId.toJS);
    } catch (_) {
      // 忽略清理失败。
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed && widget.fallback != null) {
      return widget.fallback!;
    }

    final child = _failed
        ? _OsmdErrorPlaceholder(message: _failureMessage)
        : HtmlElementView(viewType: _containerId);
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
