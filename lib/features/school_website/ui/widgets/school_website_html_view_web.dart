import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'school_website_html_utils.dart';

/// Web：用 `<iframe srcdoc>` 渲染完整 HTML。
///
/// Flutter Web 的 [HtmlElementView] 容易按整页视口宽度布局平台视图，
/// 在 Shell 侧栏 + 内容 padding 场景下会向右溢出（左侧留白、右侧贴边）。
/// 本实现：
/// 1. 宿主 div 按 Flutter 布局像素同步 width/height；
/// 2. 同步修正 `flt-platform-view` 父链宽度；
/// 3. iframe 文档内注入 fit 脚本锁定 clientWidth。
class SchoolWebsiteHtmlView extends StatefulWidget {
  const SchoolWebsiteHtmlView({super.key, required this.html});

  final String html;

  @override
  State<SchoolWebsiteHtmlView> createState() => _SchoolWebsiteHtmlViewState();
}

class _SchoolWebsiteHtmlViewState extends State<SchoolWebsiteHtmlView> {
  static int _seq = 0;

  late String _viewType;
  web.HTMLDivElement? _host;
  web.HTMLIFrameElement? _iframe;
  Size? _lastSyncedSize;

  @override
  void initState() {
    super.initState();
    _viewType = 'school-website-host-$_seq';
    _seq++;
    _registerFactory();
  }

  @override
  void didUpdateWidget(covariant SchoolWebsiteHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _loadHtmlIntoIframe();
    }
  }

  void _registerFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final host = web.HTMLDivElement();
      host.className = 'school-website-flutter-host';
      _applyHostBox(host, null);

      final iframe = web.HTMLIFrameElement();
      _applyIframeBox(iframe);
      iframe.setAttribute(
        'srcdoc',
        schoolWebsiteHtmlForEmbeddedView(widget.html),
      );

      host.appendChild(iframe);
      _host = host;
      _iframe = iframe;
      return host;
    });
  }

  void _loadHtmlIntoIframe() {
    final iframe = _iframe;
    if (iframe == null) return;
    iframe.setAttribute(
      'srcdoc',
      schoolWebsiteHtmlForEmbeddedView(widget.html),
    );
  }

  void _applyHostBox(web.HTMLDivElement host, Size? size) {
    host.style.position = 'relative';
    host.style.overflow = 'hidden';
    host.style.boxSizing = 'border-box';
    host.style.display = 'block';
    host.style.margin = '0';
    host.style.padding = '0';
    if (size != null && size.width.isFinite && size.height.isFinite) {
      final w = size.width.floor();
      final h = size.height.floor();
      host.style.width = '${w}px';
      host.style.maxWidth = '${w}px';
      host.style.minWidth = '0';
      host.style.height = '${h}px';
      host.style.maxHeight = '${h}px';
    } else {
      host.style.width = '100%';
      host.style.height = '100%';
    }
  }

  void _applyIframeBox(web.HTMLIFrameElement iframe) {
    iframe.style.border = 'none';
    iframe.style.display = 'block';
    iframe.style.margin = '0';
    iframe.style.padding = '0';
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    iframe.style.overflow = 'hidden';
    iframe.style.backgroundColor = '#F7F7FB';
    iframe.allowFullscreen = true;
  }

  void _syncPlatformViewChain(web.HTMLDivElement host, Size size) {
    final w = '${size.width.floor()}px';
    void patchElementBox(web.Element? el) {
      if (el == null || !el.isA<web.HTMLElement>()) return;
      final htmlElement = el as web.HTMLElement;
      htmlElement.style.width = w;
      htmlElement.style.maxWidth = w;
      htmlElement.style.minWidth = '0';
      htmlElement.style.overflow = 'hidden';
    }
    patchElementBox(host.parentElement);
    patchElementBox(host.parentElement?.parentElement);
  }

  void _syncSize(Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }
    if (_lastSyncedSize == size) return;
    _lastSyncedSize = size;

    final host = _host;
    if (host == null) return;
    _applyHostBox(host, size);
    _syncPlatformViewChain(host, size);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width.isFinite && height.isFinite) {
          final size = Size(width, height);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _syncSize(size);
          });
        }

        final view = HtmlElementView(
          key: ValueKey(_viewType),
          viewType: _viewType,
        );

        if (!width.isFinite || !height.isFinite) {
          return ClipRect(child: SizedBox.expand(child: view));
        }

        return ClipRect(
          child: SizedBox(
            width: width,
            height: height,
            child: view,
          ),
        );
      },
    );
  }
}
