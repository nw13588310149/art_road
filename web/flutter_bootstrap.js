{{flutter_js}}
{{flutter_build_config}}

// 使用本地 CanvasKit，避免从 gstatic.com CDN 加载失败（国内网络/离线环境常见）。
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: '/canvaskit/',
  },
});
