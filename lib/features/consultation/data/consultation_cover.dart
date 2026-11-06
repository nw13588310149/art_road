import 'dart:convert';

import '../../../core/network/media_url.dart';

/// 从 textbook 资讯条目解析封面 URL：优先 [img1] 首图，回退 [shortText3]。
String parseConsultationCoverUrl(Map raw) {
  final fromImg1 = _firstImageUrl(raw['img1']);
  if (fromImg1.isNotEmpty) {
    return fromImg1;
  }
  final fallback = raw['shortText3']?.toString().trim() ?? '';
  return fallback.isEmpty ? '' : MediaUrl.resolve(fallback);
}

String _firstImageUrl(dynamic raw) {
  for (final entry in _normalizeToList(raw)) {
    final url = _extractUrl(entry);
    if (url.isNotEmpty) {
      return url;
    }
  }
  return '';
}

String _extractUrl(dynamic entry) {
  if (entry == null) {
    return '';
  }
  if (entry is Map) {
    final url = (entry['url'] ?? entry['fileUrl'])?.toString().trim() ?? '';
    if (url.isNotEmpty) {
      return MediaUrl.resolve(url);
    }
    final path =
        (entry['path'] ?? entry['img'] ?? entry['filePath'])
            ?.toString()
            .trim() ??
        '';
    if (path.isNotEmpty) {
      return MediaUrl.resolve(path);
    }
    return '';
  }

  final text = entry.toString().trim();
  if (text.isEmpty) {
    return '';
  }

  if ((text.startsWith('{') && text.endsWith('}')) ||
      (text.startsWith('[') && text.endsWith(']'))) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return _extractUrl(decoded);
      }
      if (decoded is List && decoded.isNotEmpty) {
        return _extractUrl(decoded.first);
      }
    } catch (_) {
      // 落到下面的 Dart 风格 / 纯字符串解析。
    }
  }

  if (text.startsWith('{') && text.endsWith('}')) {
    final urlMatch = RegExp(r'url:\s*([^,}\s][^,}]*)').firstMatch(text);
    if (urlMatch != null) {
      return MediaUrl.resolve(urlMatch.group(1)!.trim());
    }
    final pathMatch = RegExp(r'path:\s*([^,}\s][^,}]*)').firstMatch(text);
    if (pathMatch != null) {
      return MediaUrl.resolve(pathMatch.group(1)!.trim());
    }
    return '';
  }

  return MediaUrl.resolve(text);
}

List<dynamic> _normalizeToList(dynamic raw) {
  if (raw == null) {
    return const <dynamic>[];
  }
  final decoded = _decodeJsonLike(raw);
  if (decoded is List) {
    if (decoded.length == 1 && decoded.first is List) {
      return List<dynamic>.from(decoded.first as List);
    }
    return List<dynamic>.from(decoded);
  }
  if (decoded is Map) {
    return <dynamic>[decoded];
  }
  final text = raw.toString().trim();
  if (text.isEmpty) {
    return const <dynamic>[];
  }
  return <dynamic>[raw];
}

dynamic _decodeJsonLike(dynamic value) {
  if (value is List || value is Map) {
    return value;
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return value;
  }
  if (!(text.startsWith('{') || text.startsWith('['))) {
    return value;
  }
  try {
    return jsonDecode(text);
  } catch (_) {
    return value;
  }
}
