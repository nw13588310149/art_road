import '../demo_backend.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';

/// 资讯、视频、云盘、笔记、收藏等内容类演示数据的公共工具。
///
/// 媒体统一以 `asset:` / 上传引用保存，响应前用 [url] 转成本次启动可加载的
/// 绝对地址；客户端回传的绝对地址在落盘前用 [refOf] 还原成引用。
abstract final class ContentDemo {
  static String art(String name) => 'asset:assets/demo/art/$name.jpg';
  static String paper(String name) => 'asset:assets/demo/papers/$name.jpg';
  static String scene(String name) => 'asset:assets/demo/scene/$name.jpg';
  static String clip(String name) => 'asset:assets/demo/video/$name.mp4';
  static const schoolLogo = 'asset:assets/demo/brand/school_logo.png';

  static String url(String ref) => isPlaceholder(ref) ? '' : DemoMedia.url(ref);

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String dateTime(DateTime d) =>
      '${date(d)} ${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  static String now() => dateTime(DateTime.now());

  /// 客户端约定的空值占位（`string` / `null` / 空串）。
  static bool isPlaceholder(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return value.isEmpty ||
        value == 'string' ||
        value == 'null' ||
        value == 'undefined';
  }

  static final RegExp _loopback = RegExp(r'^https?://127\.0\.0\.1:\d+/(.*)$');

  /// 把演示媒体的绝对地址还原成可持久化的引用；其它值原样返回。
  ///
  /// 本机媒体服务每次启动端口都会变化，绝对地址不能直接写进 [DemoStore]。
  static String refOf(String raw) {
    final value = raw.trim();
    if (isPlaceholder(value) || value.startsWith('asset:')) {
      return value;
    }
    String? rest;
    final base = DemoMedia.fileBaseUrl;
    if (base.isNotEmpty && value.startsWith(base)) {
      rest = value.substring(base.length);
    } else {
      rest = _loopback.firstMatch(value)?.group(1);
    }
    if (rest == null) {
      return value;
    }
    if (rest.startsWith('a/')) {
      return 'asset:${Uri.decodeFull(rest.substring(2))}';
    }
    if (rest.startsWith('assets/')) {
      return 'asset:${Uri.decodeFull(rest.substring('assets/'.length))}';
    }
    return rest;
  }

  /// 按请求的 current / size 截取一页（接口直接返回数组的场景）。
  static List<T> slice<T>(List<T> all, DemoRequest req) {
    final start = (req.page - 1) * req.size;
    if (start >= all.length) {
      return <T>[];
    }
    return all.sublist(start, (start + req.size).clamp(0, all.length));
  }

  static int toInt(Object? raw, [int fallback = 0]) {
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString().trim() ?? '') ?? fallback;
  }

  /// 本地自增 id（数字形态，云盘 / 笔记客户端按 int 解析）。
  static int newId() => int.parse(DemoStore.nextId());

  static const _assetBytes = <String, int>{
    'art/color-flower-1.jpg': 304874,
    'art/color-landscape-1.jpg': 295801,
    'art/color-still-1.jpg': 301071,
    'art/color-still-2.jpg': 308012,
    'art/color-still-3.jpg': 248128,
    'art/color-still-4.jpg': 297006,
    'art/color-still-5.jpg': 248669,
    'art/detail-color.jpg': 383769,
    'art/detail-sketch.jpg': 372144,
    'art/sketch-bust-1.jpg': 166190,
    'art/sketch-bust-2.jpg': 365757,
    'art/sketch-bust-3.jpg': 243544,
    'art/sketch-geometry-1.jpg': 227389,
    'art/sketch-portrait-1.jpg': 252976,
    'art/sketch-still-1.jpg': 254511,
    'art/sketch-still-2.jpg': 351724,
    'art/sketch-still-3.jpg': 212730,
    'art/speed-figure-1.jpg': 211438,
    'art/speed-figure-2.jpg': 232466,
    'art/speed-figure-3.jpg': 273576,
    'art/speed-figure-4.jpg': 326667,
    'art/speed-figure-5.jpg': 319907,
    'art/speed-group-1.jpg': 255930,
    'art/speed-scene-1.jpg': 325891,
    'papers/color.jpg': 39451,
    'papers/sketch.jpg': 97580,
    'papers/speed.jpg': 32218,
    'scene/exam-hall.jpg': 149962,
    'scene/studio-wall.jpg': 179204,
    'video/hatching.mp4': 2121374,
    'video/place-paper.mp4': 571500,
    'video/studio.mp4': 4144070,
  };

  /// 演示资源的真实字节数；上传文件没有记录大小时按类型估算。
  static int bytesOf(String ref) {
    const prefix = 'asset:assets/demo/';
    if (ref.startsWith(prefix)) {
      final known = _assetBytes[ref.substring(prefix.length)];
      if (known != null) {
        return known;
      }
    }
    final lower = ref.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) {
      return 3 * 1024 * 1024;
    }
    if (lower.endsWith('.pdf') || lower.endsWith('.docx')) {
      return 1536 * 1024;
    }
    return 860 * 1024;
  }
}
