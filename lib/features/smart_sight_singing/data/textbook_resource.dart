import 'dart:convert';

import '../../../core/network/media_url.dart';

/// 从 `textbookDetail` 响应中提取首个可跟唱资源 URL（MIDI / MusicXML）。
String extractTextbookResourceUrl(Map<String, dynamic> raw) {
  for (final key in ['file1', 'file2', 'file3', 'musicUrl', 'url']) {
    final url = _extractUrl(raw[key]);
    if (url.isNotEmpty) return url;
  }
  return '';
}

String _extractUrl(dynamic entry) {
  if (entry == null) return '';

  if (entry is Map) {
    final url = (entry['url'] ?? entry['fileUrl'])?.toString().trim() ?? '';
    if (url.isNotEmpty) return MediaUrl.resolve(url);
    final path =
        (entry['path'] ?? entry['img'] ?? entry['filePath'])?.toString().trim() ??
        '';
    if (path.isNotEmpty) return MediaUrl.resolve(path);
    return '';
  }

  if (entry is List) {
    for (final item in entry) {
      final url = _extractUrl(item);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  final text = entry.toString().trim();
  if (text.isEmpty) return '';

  if ((text.startsWith('{') && text.endsWith('}')) ||
      (text.startsWith('[') && text.endsWith(']'))) {
    try {
      final decoded = jsonDecode(text);
      return _extractUrl(decoded);
    } catch (_) {
      // fall through
    }
  }

  return MediaUrl.resolve(text);
}

bool isSupportedSightSingingResource(String urlOrName) {
  final lower = urlOrName.toLowerCase();
  const exts = ['.mid', '.midi', '.musicxml', '.xml', '.mxl'];
  for (final ext in exts) {
    if (lower.contains(ext)) return true;
  }
  return false;
}

/// 优先从资源 URL 推断扩展名；教材标题（如「测试」）通常不含后缀。
String inferSightSingingResourceExtension(
  String url, {
  String? displayName,
}) {
  final fromUrl = _extensionFromName(url);
  if (fromUrl.isNotEmpty) return fromUrl;
  if (displayName != null) {
    final fromName = _extensionFromName(displayName);
    if (fromName.isNotEmpty) return fromName;
  }
  return '';
}

String _extensionFromName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';

  final uri = Uri.tryParse(trimmed);
  final path = uri != null && uri.hasAuthority ? uri.path : trimmed;
  final lower = path.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot < 0 || dot == lower.length - 1) return '';
  return lower.substring(dot + 1);
}

String resourceDisplayName({
  required String url,
  required String? title,
  required int id,
}) {
  final trimmedTitle = title?.trim() ?? '';
  if (trimmedTitle.isNotEmpty) return trimmedTitle;
  final uri = Uri.tryParse(url);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    final last = Uri.decodeComponent(uri.pathSegments.last).trim();
    if (last.isNotEmpty) return last;
  }
  return '教材 $id';
}
