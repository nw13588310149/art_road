import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:web/web.dart' as web;

import '../../../../core/constants/baidu_map_config.dart';

/// Web 端百度地图嵌入。原理：
///
/// 1. 注册一个唯一的 `viewType`，在工厂里创建 `<iframe>` 指向
///    `baidu_map.html?ak=...&lat=XX&lng=YY&label=ZZ&zoom=NN`。
/// 2. iframe 内部由 `web/baidu_map.html` 处理 WGS-84 → BD-09 坐标转换、
///    地图渲染、Marker + 反编码地址。
/// 3. iframe 完成反编码后会 `window.parent.postMessage` 回传地址。
///    本 widget 监听 `window` 的 `message` 事件，回调 [onAddressResolved]。
///
/// 注意：必须使用 [BaiduMapConfig.webJsAk]（浏览器端 AK），不能使用 iOS SDK AK。
///
/// iframe 回传地址前一直盖着 Flutter 占位，iframe 里的加载 / 配置报错不会
/// 露给用户；iframe 回传 `type: 'error'` 或超过 [_loadTimeout] 仍未回传地址时
/// 显示「地图暂不可用」。占位文字贴底，避免与叠在地图中央的按钮重叠。
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
  static int _seq = 0;
  static const Duration _loadTimeout = Duration(seconds: 8);
  late String _viewType;
  JSFunction? _messageListener;
  Timer? _loadTimer;
  bool _ready = false;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _registerView();
    _installMessageListener();
  }

  @override
  void didUpdateWidget(covariant BaiduMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat ||
        oldWidget.lng != widget.lng ||
        oldWidget.label != widget.label ||
        oldWidget.zoom != widget.zoom) {
      setState(_registerView);
    }
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    final l = _messageListener;
    if (l != null) {
      web.window.removeEventListener('message', l);
      _messageListener = null;
    }
    super.dispose();
  }

  void _installMessageListener() {
    void onMessage(web.MessageEvent ev) {
      final data = ev.data?.dartify();
      if (data is! Map) return;
      if (data['source'] != 'baidu_map') return;
      if (!mounted) return;
      if (data['type'] == 'error') {
        _loadTimer?.cancel();
        if (!_ready && !_timedOut) setState(() => _timedOut = true);
        return;
      }
      if (data['type'] != 'address') return;
      _loadTimer?.cancel();
      if (!_ready || _timedOut) {
        setState(() {
          _ready = true;
          _timedOut = false;
        });
      }
      final address = data['address'];
      if (address is String && address.isNotEmpty) {
        widget.onAddressResolved?.call(address);
      }
    }

    final js = onMessage.toJS;
    _messageListener = js;
    web.window.addEventListener('message', js);
  }

  void _registerView() {
    _ready = false;
    _timedOut = false;
    _loadTimer?.cancel();
    _loadTimer = Timer(_loadTimeout, () {
      if (mounted && !_ready) setState(() => _timedOut = true);
    });
    _viewType = 'baidu-map-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    final src = _buildSrc();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..allowFullscreen = false
        ..allow = 'geolocation'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#EFF3FC';
      return iframe;
    });
  }

  String _buildSrc() {
    final lat = widget.lat;
    final lng = widget.lng;
    final params = <String, String>{
      'ak': BaiduMapConfig.webJsAk,
      'zoom': widget.zoom.toString(),
      if (lat != null && lat.isFinite) 'lat': lat.toString(),
      if (lng != null && lng.isFinite) 'lng': lng.toString(),
      if (widget.label != null && widget.label!.isNotEmpty)
        'label': widget.label!,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'baidu_map.html?$query';
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius;
    final hasPosition = widget.lat != null && widget.lng != null;
    final Widget view = Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        if (!_ready)
          _MapPlaceholder(
            label: !hasPosition
                ? '定位成功后显示地图'
                : _timedOut
                ? '地图暂不可用，打卡以定位结果为准'
                : '正在加载地图…',
          ),
      ],
    );
    if (radius == null) return view;
    return ClipRRect(borderRadius: radius, child: view);
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSubtle,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpace.s4),
              Text(
                label,
                style: AppText.caption12.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
