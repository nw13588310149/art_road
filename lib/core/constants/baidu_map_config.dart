/// 百度地图开放平台 AK 配置。
///
/// - [iosSdkAk]：iOS SDK 类型密钥，仅用于原生 BMap SDK（非 JS API）。
/// - [webJsAk]：浏览器端 JS API 密钥，Web / iOS WebView 内嵌地图必须使用此密钥。
abstract final class BaiduMapConfig {
  static const String iosSdkAk = 'nBiqhTUfrbmE4iwUcQjy8RrlS64M8CgQ';
  static const String webJsAk = 'Q4It3qA6pOS2uqrmL4KNxwNqVjz9PbJf';

  /// 浏览器端 AK 绑定的 Referer 根域；静态图等 Web 服务 API 请求须携带。
  static const String webReferer = 'https://yyzl0931.com/';
}
