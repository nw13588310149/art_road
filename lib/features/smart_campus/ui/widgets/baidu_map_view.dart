// 百度地图嵌入 widget 入口。
//
// - Web：iframe 加载 `web/baidu_map.html`，传入 [BaiduMapConfig.webJsAk]。
// - iOS：WebView 内嵌百度 JS 地图（高清矢量、手势缩放/拖拽）。
// - Android：高清静态底图 + [InteractiveViewer] 缩放，并缓存图片避免闪烁。
// - iOS SDK AK（[BaiduMapConfig.iosSdkAk]）仅用于原生 BMap SDK，不可用于 JS / Web 服务。
//
// AK 白名单：浏览器端密钥需配置 Referer（Web iframe）；Web 服务 API 需在控制台开通
// 静态图 / 逆地理编码权限（开发时可加 `localhost`、`127.0.0.1`）。
export 'baidu_map_view_io.dart'
    if (dart.library.html) 'baidu_map_view_web.dart';
