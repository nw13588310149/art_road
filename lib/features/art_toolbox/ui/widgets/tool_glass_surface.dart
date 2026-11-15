import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 材质是表现层：原生视图只绘制背景，命中、焦点和工具状态仍由 Flutter 管理。
class ToolGlassSurface extends StatefulWidget {
  const ToolGlassSurface({required this.child, super.key});
  final Widget child;

  @override
  State<ToolGlassSurface> createState() => _ToolGlassSurfaceState();
}

class _ToolGlassSurfaceState extends State<ToolGlassSurface> {
  MethodChannel? _channel;
  final _pointers = <int>{};
  bool _nativeReady = false;

  Map<String, Object> get _configuration => {
    'radius': 16.0,
    'engaged': _pointers.isNotEmpty,
    'reduceMotion': MediaQuery.disableAnimationsOf(context),
    'opaque': MediaQuery.highContrastOf(context),
  };

  Future<void> _configure() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('configure', _configuration);
      if (mounted && channel == _channel && !_nativeReady) {
        setState(() => _nativeReady = true);
      }
    } on PlatformException {
      // 较早的宿主或平台桥不可用时保留可操作的 Flutter 材质。
    } on MissingPluginException {
      // Web、测试和未注册平台视图的宿主不依赖原生效果。
    }
  }

  void _touch(int pointer, bool down) {
    down ? _pointers.add(pointer) : _pointers.remove(pointer);
    unawaited(_configure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_configure());
  }

  @override
  Widget build(BuildContext context) {
    final opaque = MediaQuery.highContrastOf(context);
    final native = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    const radius = BorderRadius.all(Radius.circular(16));
    return Listener(
      onPointerDown: (event) => _touch(event.pointer, true),
      onPointerUp: (event) => _touch(event.pointer, false),
      onPointerCancel: (event) => _touch(event.pointer, false),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Color(0x160F172A),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (!_nativeReady)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: BackdropFilter(
                      enabled: !opaque,
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: DecoratedBox(
                        key: const ValueKey('tool-glass-fallback'),
                        decoration: BoxDecoration(
                          color: opaque
                              ? Colors.white
                              : const Color(0xE8FFFFFF),
                          borderRadius: radius,
                          border: Border.all(color: const Color(0xF2FFFFFF)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (native)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: UiKitView(
                      viewType: 'com.meiyuji.art/tool_glass',
                      creationParams: _configuration,
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: (id) {
                        if (!mounted) return;
                        _channel = MethodChannel(
                          'com.meiyuji.art/tool_glass/$id',
                        );
                        unawaited(_configure());
                      },
                    ),
                  ),
                ),
              ),
            // 不在原生材质的父级使用透明度/裁剪，避免破坏 UIKit 背景采样。
            ClipRRect(borderRadius: radius, child: widget.child),
          ],
        ),
      ),
    );
  }
}
