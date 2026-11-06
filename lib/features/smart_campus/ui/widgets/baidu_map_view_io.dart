import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../../core/constants/baidu_map_config.dart';
import '../../services/baidu_geo_service.dart';

const _hostChannel = 'BaiduMapHost';

/// iOS：WebView 内嵌百度 JS 地图（高清矢量、支持手势缩放）。
/// Android：缓存静态底图 + [InteractiveViewer] 缩放，避免父级 rebuild 闪烁。
class BaiduMapView extends StatefulWidget {
  const BaiduMapView({
    super.key,
    required this.lat,
    required this.lng,
    this.label,
    this.zoom = 17,
    this.onAddressResolved,
    this.borderRadius,
  });

  final double? lat;
  final double? lng;
  final String? label;
  final int zoom;
  final ValueChanged<String>? onAddressResolved;
  final BorderRadius? borderRadius;

  @override
  State<BaiduMapView> createState() => _BaiduMapViewState();
}

class _BaiduMapViewState extends State<BaiduMapView> {
  String? _lastGeocodeKey;

  @override
  void initState() {
    super.initState();
    _maybeGeocode();
  }

  @override
  void didUpdateWidget(covariant BaiduMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      _maybeGeocode();
    }
  }

  Future<void> _maybeGeocode() async {
    final lat = widget.lat;
    final lng = widget.lng;
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return;

    final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_lastGeocodeKey == key) return;
    _lastGeocodeKey = key;

    final address = await BaiduGeoService.reverseGeocode(lat: lat, lng: lng);
    if (!mounted || address == null || address.isEmpty) return;
    widget.onAddressResolved?.call(address);
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.lat;
    final lng = widget.lng;
    final hasPoint =
        lat != null && lng != null && lat.isFinite && lng.isFinite;
    final radius = widget.borderRadius;

    Widget child;
    if (!hasPoint) {
      child = const ColoredBox(
        color: Color(0xFFEFF3FC),
        child: Center(
          child: Text(
            '暂无定位',
            style: TextStyle(color: Color(0xFFB6B5BB), fontSize: 13),
          ),
        ),
      );
    } else if (!kIsWeb && Platform.isIOS) {
      child = _BaiduMapWebViewLayer(
        lat: lat,
        lng: lng,
        label: widget.label,
        zoom: widget.zoom,
        onAddressResolved: widget.onAddressResolved,
      );
    } else {
      child = _BaiduMapStaticLayer(
        lat: lat,
        lng: lng,
        zoom: widget.zoom,
      );
    }

    if (radius == null) return child;
    return ClipRRect(borderRadius: radius, child: child);
  }
}

// —— iOS WebView 交互地图 ————————————————————————————————————————————————

class _BaiduMapWebViewLayer extends StatefulWidget {
  const _BaiduMapWebViewLayer({
    required this.lat,
    required this.lng,
    this.label,
    required this.zoom,
    this.onAddressResolved,
  });

  final double lat;
  final double lng;
  final String? label;
  final int zoom;
  final ValueChanged<String>? onAddressResolved;

  @override
  State<_BaiduMapWebViewLayer> createState() => _BaiduMapWebViewLayerState();
}

class _BaiduMapWebViewLayerState extends State<_BaiduMapWebViewLayer> {
  static Future<Directory>? _hostDirFuture;
  static var _counter = 0;

  late final WebViewController _controller;
  late final String _containerId;
  late final Directory _hostDir;

  var _pageReady = false;
  String? _lastParamsKey;

  @override
  void initState() {
    super.initState();
    _containerId = 'baidu-map-${_counter++}';
    _controller = _createController();
    unawaited(_bootstrapHost());
  }

  @override
  void didUpdateWidget(covariant _BaiduMapWebViewLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pageReady) return;
    if (oldWidget.lat != widget.lat ||
        oldWidget.lng != widget.lng ||
        oldWidget.label != widget.label ||
        oldWidget.zoom != widget.zoom) {
      unawaited(_pushHostParams());
    }
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

    return WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEFF3FC))
      ..addJavaScriptChannel(
        _hostChannel,
        onMessageReceived: (JavaScriptMessage msg) {
          _handleHostMessage(msg.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _pageReady = true);
            unawaited(_pushHostParams());
          },
        ),
      );
  }

  void _handleHostMessage(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      if (data['source'] != 'baidu_map') return;
      if (data['type'] != 'address') return;
      final address = data['address'];
      if (address is String && address.isNotEmpty) {
        widget.onAddressResolved?.call(address);
      }
    } catch (_) {
      // 忽略非 JSON 回传。
    }
  }

  static Future<Directory> _ensureHostDir() {
    return _hostDirFuture ??= () async {
      final dir = Directory(
        '${Directory.systemTemp.path}/smart_campus_baidu_map_host',
      );
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }();
  }

  Future<void> _bootstrapHost() async {
    try {
      _hostDir = await _ensureHostDir();
      final raw = await rootBundle.loadString('assets/web/baidu_map.html');
      final html = raw.replaceFirst(
        '<head>',
        '<head>\n  <base href="${BaiduMapConfig.webReferer}">',
      );
      final htmlPath = '${_hostDir.path}/$_containerId.html';
      await File(htmlPath).writeAsString(html, flush: true);

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
    } catch (_) {
      // 页面加载失败时保持占位背景。
    }
  }

  Future<void> _pushHostParams() async {
    final key =
        '${widget.lat.toStringAsFixed(5)},${widget.lng.toStringAsFixed(5)},'
        '${widget.zoom},${widget.label ?? ''}';
    if (_lastParamsKey == key) return;
    _lastParamsKey = key;

    final detail = jsonEncode(<String, dynamic>{
      'ak': BaiduMapConfig.webJsAk,
      'lat': widget.lat,
      'lng': widget.lng,
      'label': widget.label ?? '当前位置',
      'zoom': widget.zoom,
    });
    try {
      await _controller.runJavaScript(
        'window.dispatchEvent(new CustomEvent("hostParams", {detail: $detail}));',
      );
    } catch (_) {
      // WebView 销毁时忽略。
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: WebViewWidget(
        controller: _controller,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
      ),
    );
  }
}

// —— Android / 回退：高清静态图 + 手势缩放 ——————————————————————————————————

class _BaiduMapStaticLayer extends StatefulWidget {
  const _BaiduMapStaticLayer({
    required this.lat,
    required this.lng,
    required this.zoom,
  });

  final double lat;
  final double lng;
  final int zoom;

  @override
  State<_BaiduMapStaticLayer> createState() => _BaiduMapStaticLayerState();
}

class _BaiduMapStaticLayerState extends State<_BaiduMapStaticLayer> {
  Uint8List? _mapBytes;
  bool _loading = false;
  String? _loadKey;

  void _scheduleLoad(int width, int height) {
    final key =
        '${widget.lat.toStringAsFixed(5)},${widget.lng.toStringAsFixed(5)},'
        '$width,$height,${widget.zoom}';
    if (_loadKey == key && (_mapBytes != null || _loading)) return;
    if (_loading && _loadKey == key) return;

    _loadKey = key;
    _loading = true;
    BaiduGeoService.fetchStaticMapImage(
      lat: widget.lat,
      lng: widget.lng,
      width: width,
      height: height,
      zoom: widget.zoom,
      scaler: 2,
    ).then((bytes) {
      if (!mounted || _loadKey != key) return;
      setState(() {
        _mapBytes = bytes;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final width = (constraints.maxWidth * dpr).ceil().clamp(100, 1024);
        final height = (constraints.maxHeight * dpr).ceil().clamp(100, 1024);
        _scheduleLoad(width, height);

        if (_loading && _mapBytes == null) {
          return const ColoredBox(
            color: Color(0xFFEFF3FC),
            child: Center(child: AppLoadingIndicator()),
          );
        }

        final bytes = _mapBytes;
        if (bytes == null) {
          return ColoredBox(
            color: const Color(0xFFEFF3FC),
            child: Center(
              child: Text(
                '地图加载失败\n${widget.lat.toStringAsFixed(5)}, ${widget.lng.toStringAsFixed(5)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB6B5BB),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          );
        }

        return RepaintBoundary(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            panEnabled: true,
            scaleEnabled: true,
            clipBehavior: Clip.hardEdge,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            ),
          ),
        );
      },
    );
  }
}
