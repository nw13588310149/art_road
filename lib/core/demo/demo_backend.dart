import 'dart:async';

import 'package:flutter/foundation.dart';

import 'demo_accounts.dart';

/// 演示接口处理函数：返回值作为 `{code: 0, msg: 'ok', data: <返回值>}` 的 data。
/// 业务失败抛 [DemoApiException]；需要返回原始字节（下载）时返回 [DemoBytes]。
typedef DemoHandler = FutureOr<Object?> Function(DemoRequest request);

class DemoApiException implements Exception {
  const DemoApiException(this.message, {this.code = 500});

  final int code;
  final String message;

  @override
  String toString() => 'DemoApiException($code, $message)';
}

/// 下载类接口的原始字节响应。
class DemoBytes {
  const DemoBytes(this.bytes);

  final Uint8List bytes;
}

class DemoUploadedFile {
  const DemoUploadedFile({
    required this.field,
    required this.fileName,
    required this.bytes,
  });

  final String field;
  final String fileName;
  final Uint8List bytes;
}

class DemoRequest {
  DemoRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
    required this.headers,
    this.pathParams = const <String, String>{},
    this.files = const <DemoUploadedFile>[],
  });

  final String method;
  final String path;
  final Map<String, dynamic> query;

  /// JSON 请求体（Map / List），或 multipart 请求的普通字段（Map）。
  final Object? body;
  final Map<String, dynamic> headers;
  final Map<String, String> pathParams;
  final List<DemoUploadedFile> files;

  String get token {
    for (final key in const ['app-token', 'school-token', 'token']) {
      final value = headers[key]?.toString() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  DemoAccount get account => DemoAccounts.fromToken(token);

  Map<String, dynamic> get bodyMap {
    final value = body;
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    return const <String, dynamic>{};
  }

  String param(String name) => pathParams[name] ?? '';

  /// 依次从路径参数、query、body 中取值。
  Object? value(String key) {
    if (pathParams.containsKey(key)) {
      return pathParams[key];
    }
    if (query.containsKey(key)) {
      return query[key];
    }
    return bodyMap[key];
  }

  String str(String key, [String fallback = '']) {
    final raw = value(key);
    if (raw == null) {
      return fallback;
    }
    final text = raw.toString().trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  int intOf(String key, [int fallback = 0]) {
    final raw = value(key);
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  bool boolOf(String key, [bool fallback = false]) {
    final raw = value(key);
    if (raw is bool) {
      return raw;
    }
    final text = raw?.toString().toLowerCase();
    if (text == 'true' || text == '1') {
      return true;
    }
    if (text == 'false' || text == '0') {
      return false;
    }
    return fallback;
  }

  List<dynamic> listOf(String key) {
    final raw = value(key);
    return raw is List ? raw : const <dynamic>[];
  }

  int get page {
    final current = intOf('current', intOf('pageNum', intOf('page', 1)));
    return current < 1 ? 1 : current;
  }

  int get size {
    final value = intOf('size', intOf('pageSize', intOf('limit', 20)));
    return value < 1 ? 20 : value;
  }
}

/// 标准分页结构：`{records, total, size, current, pages}`。
Map<String, dynamic> demoPage(
  List<Object?> all,
  DemoRequest request, {
  int? page,
  int? size,
}) {
  final current = page ?? request.page;
  final pageSize = size ?? request.size;
  final start = (current - 1) * pageSize;
  final records = start >= all.length
      ? const <Object?>[]
      : all.sublist(start, (start + pageSize).clamp(0, all.length));
  return <String, dynamic>{
    'records': records,
    'total': all.length,
    'size': pageSize,
    'current': current,
    'pages': all.isEmpty ? 0 : (all.length + pageSize - 1) ~/ pageSize,
  };
}

/// 关键字过滤：任一字段包含关键字即命中；关键字为空时返回原列表。
List<T> demoSearch<T>(
  List<T> items,
  String keyword,
  Iterable<String> Function(T item) fields,
) {
  final key = keyword.trim();
  if (key.isEmpty) {
    return items;
  }
  return items.where((item) => fields(item).any((f) => f.contains(key))).toList();
}

class _DemoRoute {
  _DemoRoute(this.method, this.pattern, this.handler)
    : segments = pattern.split('/').where((s) => s.isNotEmpty).toList();

  final String method;
  final String pattern;
  final List<String> segments;
  final DemoHandler handler;

  Map<String, String>? match(List<String> pathSegments) {
    if (pathSegments.length != segments.length) {
      return null;
    }
    final params = <String, String>{};
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.startsWith('{') && seg.endsWith('}')) {
        params[seg.substring(1, seg.length - 1)] = Uri.decodeComponent(
          pathSegments[i],
        );
      } else if (seg != pathSegments[i]) {
        return null;
      }
    }
    return params;
  }
}

class DemoRouteMatch {
  const DemoRouteMatch(this.handler, this.params);

  final DemoHandler handler;
  final Map<String, String> params;
}

/// 按「方法 + 路径模板」登记演示接口，模板中 `{name}` 为路径参数。
class DemoRouter {
  DemoRouter(this.name);

  final String name;
  final List<_DemoRoute> _routes = <_DemoRoute>[];

  void get(String pattern, DemoHandler handler) =>
      _add('GET', pattern, handler);
  void post(String pattern, DemoHandler handler) =>
      _add('POST', pattern, handler);
  void put(String pattern, DemoHandler handler) =>
      _add('PUT', pattern, handler);
  void delete(String pattern, DemoHandler handler) =>
      _add('DELETE', pattern, handler);

  /// 同一路径同时登记 GET 与 POST（老接口两种方法都在用）。
  void any(String pattern, DemoHandler handler) {
    _add('GET', pattern, handler);
    _add('POST', pattern, handler);
  }

  void _add(String method, String pattern, DemoHandler handler) {
    _routes.add(_DemoRoute(method, pattern, handler));
  }

  DemoRouteMatch? match(String method, String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final upper = method.toUpperCase();
    // 字面量模板优先于带参数模板，避免 `/x/{id}` 抢走 `/x/statistics`。
    _DemoRoute? best;
    Map<String, String>? bestParams;
    for (final route in _routes) {
      if (route.method != upper) {
        continue;
      }
      final params = route.match(segments);
      if (params == null) {
        continue;
      }
      if (best == null || params.length < bestParams!.length) {
        best = route;
        bestParams = params;
      }
    }
    return best == null ? null : DemoRouteMatch(best.handler, bestParams!);
  }

  int get routeCount => _routes.length;
}

/// 演示后端：平台接口（原音乐之路 `/app/*`）与阅卷接口（exam-api）两套路由。
abstract final class DemoBackend {
  static final DemoRouter platform = DemoRouter('platform');
  static final DemoRouter marking = DemoRouter('marking');

  /// 被调用但未登记的接口（`方法 路径`），用于补齐演示数据。
  static final Set<String> missing = <String>{};

  static bool _registered = false;

  /// 由 `registerDemoFixtures` 在启动时调用一次。
  static void markRegistered() => _registered = true;

  static bool get isRegistered => _registered;

  static void reportMissing(String router, String method, String path) {
    final key = '[$router] $method $path';
    if (missing.add(key)) {
      debugPrint('[demo] 未登记的演示接口：$key');
    }
  }
}
