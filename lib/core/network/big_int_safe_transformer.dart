import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'snowflake_id.dart';

/// Dio Transformer，在 JSON 解码前把 16+ 位整数替换成 JSON 字符串。
///
/// ### 背景
/// Web 端 Dart 使用 JavaScript `Number`（IEEE-754 双精度浮点），能精确表示的
/// 最大整数为 2^53 ≈ 9 × 10¹⁵（15~16 位）。后端雪花 ID（Snowflake）为
/// 19 位，直接交给 `jsonDecode` 解析后末几位会被截断：
///   `1801911384317390848` → `1801911384317390850`（丢 2）
///
/// ### 修复方案
/// - **响应**：在 `jsonDecode` 之前，把 JSON 文本中作为 **值** 出现的 16+ 位整数
///   用双引号包裹，使其在解码后保持为 `String` 而非精度受损的 `double`。
/// - **请求**：序列化前递归把 `classId` / `id` 等雪花字段强制保持为 String，
///   并对 `jsonEncode` 输出再做一次大整数引号兜底。
///
/// 替换时 **跳过 JSON 字符串内部**，避免误改 `teacherIds` 等逗号分隔 id 字段。
class BigIntSafeTransformer implements Transformer {
  const BigIntSafeTransformer();

  /// 匹配 JSON 值位置的 16+ 位纯十进制整数：
  ///   - `([:\[,]\s*)` — 值上下文：对象的值（`:`）或数组元素（`[` / `,`）
  ///   - `(-?\d{16,})` — 可选负号 + 至少 16 位数字
  ///   - `(?=\s*[,\}\]])` — 后面紧跟值终止符（确认是独立值，非字段名）
  static final _bigIntRe = RegExp(
    r'([:\[,]\s*)(-?\d{16,})(?=\s*[,\}\]])',
  );

  /// 响应体解码：大整数引号兜底后再 `jsonDecode`。
  static dynamic decodeBigIntSafeJson(String raw) => _safeDecode(raw);

  /// 轻量解码：仅修补已知 id 字段上的大整数，适合 HTML 体量大的刷题列表。
  static dynamic decodeLightweightJson(String raw) {
    if (raw.isEmpty) return null;
    if (!_knownIdFieldRe.hasMatch(raw)) {
      return jsonDecode(raw);
    }
    final patched = raw.replaceAllMapped(
      _knownIdFieldRe,
      (m) => '"${m.group(1)}":"${m.group(2)}"',
    );
    try {
      return jsonDecode(patched);
    } catch (_) {
      return jsonDecode(raw);
    }
  }

  /// 请求体序列化：雪花 id 字段保持 String + 大整数引号兜底。
  static String encodeBigIntSafeJson(Object? data) => _safeEncode(data);

  /// 刷题等接口常见 id 字段；只匹配 JSON 键值，不会误改 HTML 字符串内容。
  static final RegExp _knownIdFieldRe = RegExp(
    r'"((?:id|practiceId|questionPracticeItemId|schoolId))"\s*:\s*(-?\d{16,})',
  );

  /// 仅在 JSON 字符串 **外部** 把裸大整数包上引号。
  static String _patchBigIntLiteralsOutsideStrings(String raw) {
    final out = StringBuffer();
    var i = 0;
    var inString = false;
    var escape = false;

    while (i < raw.length) {
      final ch = raw[i];

      if (inString) {
        out.write(ch);
        if (escape) {
          escape = false;
        } else if (ch == r'\') {
          escape = true;
        } else if (ch == '"') {
          inString = false;
        }
        i++;
        continue;
      }

      if (ch == '"') {
        inString = true;
        out.write(ch);
        i++;
        continue;
      }

      final match = _bigIntRe.matchAsPrefix(raw, i);
      if (match != null) {
        out.write('${match.group(1)}"${match.group(2)}"');
        i = match.end;
        continue;
      }

      out.write(ch);
      i++;
    }

    return out.toString();
  }

  /// 快速探测：JSON 字符串外部是否存在需要修补的大整数。
  static bool _containsBigIntLiteralOutsideStrings(String raw) {
    var inString = false;
    var escape = false;

    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];

      if (inString) {
        if (escape) {
          escape = false;
        } else if (ch == r'\') {
          escape = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
        continue;
      }

      if (_bigIntRe.matchAsPrefix(raw, i) != null) {
        return true;
      }
    }

    return false;
  }

  /// 请求体序列化：雪花 id 字段保持 String + 大整数引号兜底。
  static String _safeEncode(Object? data) {
    final coerced = coerceSnowflakeRequestData(data);
    final encoded = jsonEncode(coerced);
    return _patchBigIntLiteralsOutsideStrings(encoded);
  }

  /// 将 JSON 文本中的大整数包裹为字符串，再走标准 `jsonDecode`。
  static dynamic _safeDecode(String raw) {
    if (raw.isEmpty) return null;
    if (!_containsBigIntLiteralOutsideStrings(raw)) {
      return jsonDecode(raw);
    }
    final patched = _patchBigIntLiteralsOutsideStrings(raw);
    try {
      return jsonDecode(patched);
    } catch (_) {
      // 补丁失败时退回原始 JSON，至少保证页面能渲染。
      return jsonDecode(raw);
    }
  }

  // ── Transformer interface ──────────────────────────────────────────────────

  @override
  Future<String> transformRequest(RequestOptions options) async {
    final data = options.data;
    if (data == null) return '';
    if (data is String) return data;
    if (data is FormData) return data.toString();
    return _safeEncode(data);
  }

  @override
  Future<dynamic> transformResponse(
    RequestOptions options,
    ResponseBody responseBody,
  ) async {
    final responseType = options.responseType;

    // 流式响应：原样返回。
    if (responseType == ResponseType.stream) {
      return responseBody;
    }

    // 收集所有字节。
    final bytes = <int>[];
    await for (final chunk in responseBody.stream) {
      bytes.addAll(chunk);
    }

    // 二进制响应：返回 Uint8List。
    if (responseType == ResponseType.bytes) {
      return bytes;
    }

    // 文本 / JSON 响应：先解码为 String。
    final rawStr = utf8.decode(bytes, allowMalformed: true);

    if (responseType == ResponseType.plain) {
      return rawStr;
    }

    // JSON（默认）：刷题大 payload 走轻量解码，其余走通用安全解码。
    if (rawStr.trim().isEmpty) return null;
    try {
      if (options.extra['lightweightJson'] == true) {
        return decodeLightweightJson(rawStr);
      }
      return _safeDecode(rawStr);
    } catch (_) {
      // 解析失败时原样返回字符串，让上层 _toApiResponse 兜底。
      return rawStr;
    }
  }
}

/// 响应 JSON 文本安全解码（16+ 位整数 → String）。
dynamic decodeBigIntSafeJson(String raw) =>
    BigIntSafeTransformer.decodeBigIntSafeJson(raw);

/// 请求 JSON 安全编码（雪花 id 字段 → 带引号字符串）。
String encodeBigIntSafeJson(Object? data) =>
    BigIntSafeTransformer.encodeBigIntSafeJson(data);

/// 轻量 JSON 解码（仅修补已知 id 字段大整数）。
dynamic decodeLightweightJson(String raw) =>
    BigIntSafeTransformer.decodeLightweightJson(raw);
