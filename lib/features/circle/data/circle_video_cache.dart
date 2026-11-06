import 'circle_video_cache_stub.dart'
    if (dart.library.io) 'circle_video_cache_io.dart';

/// Circle 沉浸视频播放源解析（MOV 等格式在 native 端会先缓存到本地）。
abstract final class CircleVideoCache {
  static bool needsLocalCache(String url) =>
      circleVideoCacheNeedsLocal(url);

  static Future<String> resolvePlaybackSource(String url) =>
      circleVideoCacheResolve(url);
}
