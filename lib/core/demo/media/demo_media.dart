import 'dart:typed_data';

import 'demo_media_io.dart' if (dart.library.html) 'demo_media_web.dart'
    as platform_host;

/// 演示媒体：把打包进 App 的演示图片 / 视频以及用户上传的文件变成可直接
/// 加载的 URL，供图片、视频、PDF 等组件按普通网络地址使用。
///
/// - iOS / Android：App 内起一个 127.0.0.1 本地 HTTP 服务；
/// - Web：资源走站点自身的 `assets/` 路径，上传文件走 blob 地址。
///
/// 演示数据里的媒体引用统一写成 `asset:<资源路径>` 或上传返回的引用，
/// 响应前用 [url] 转成绝对地址，避免持久化端口号等易变信息。
abstract final class DemoMedia {
  static Future<void> start() => platform_host.startDemoMediaHost();

  /// 文件服务器根地址（`configList.fileServerUrl`）。
  static String get fileBaseUrl => platform_host.demoFileBaseUrl();

  static String asset(String assetKey) => platform_host.demoAssetUrl(assetKey);

  /// 托管一段上传字节，返回可持久化的引用（iOS / Android 为相对路径，
  /// Web 为 blob 地址）。
  static Future<String> host(Uint8List bytes, String fileName) =>
      platform_host.hostDemoBytes(bytes, fileName);

  /// 把演示数据里的媒体引用转成可加载的绝对地址。
  static String url(String ref) {
    final value = ref.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('asset:')) {
      return asset(value.substring('asset:'.length));
    }
    if (value.contains('://') ||
        value.startsWith('blob:') ||
        value.startsWith('data:')) {
      return value;
    }
    final base = fileBaseUrl.endsWith('/') ? fileBaseUrl : '$fileBaseUrl/';
    return '$base${value.startsWith('/') ? value.substring(1) : value}';
  }
}
