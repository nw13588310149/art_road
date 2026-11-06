import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'school_website_html_utils.dart';

/// 原生（iOS / Android）：用 WebView 直接 [WebViewController.loadHtmlString]
/// 渲染后端返回的完整 HTML 文档，保留其自带的 CSS 与轮播脚本。
class SchoolWebsiteHtmlView extends StatefulWidget {
  const SchoolWebsiteHtmlView({super.key, required this.html});

  final String html;

  @override
  State<SchoolWebsiteHtmlView> createState() => _SchoolWebsiteHtmlViewState();
}

class _SchoolWebsiteHtmlViewState extends State<SchoolWebsiteHtmlView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
    unawaited(_loadHtml());
  }

  @override
  void didUpdateWidget(covariant SchoolWebsiteHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      unawaited(_loadHtml());
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
      ..setBackgroundColor(const Color(0xFFF7F7FB));
  }

  Future<void> _loadHtml() async {
    try {
      await _controller.loadHtmlString(
        schoolWebsiteHtmlForEmbeddedView(widget.html),
      );
    } catch (_) {
      // WebView 已销毁等场景忽略。
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: WebViewWidget(
        controller: _controller,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
      ),
    );
  }
}
