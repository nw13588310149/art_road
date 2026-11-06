import 'dart:io';

import 'package:dio/dio.dart';

bool circleVideoCacheNeedsLocal(String url) {
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  final path = uri.path.toLowerCase();
  return path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      path.endsWith('.qt');
}

final Map<String, String> _resolvedPaths = <String, String>{};
final Map<String, Future<String>> _inFlight = <String, Future<String>>{};

Future<String> circleVideoCacheResolve(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty || !circleVideoCacheNeedsLocal(trimmed)) {
    return trimmed;
  }

  final cached = _resolvedPaths[trimmed];
  if (cached != null) {
    final file = File(Uri.parse(cached).path);
    if (await file.exists() && await file.length() > 0) {
      return cached;
    }
    _resolvedPaths.remove(trimmed);
  }

  return _inFlight.putIfAbsent(trimmed, () async {
    try {
      final localPath = await _downloadToTemp(trimmed);
      final playbackUri = Uri.file(localPath).toString();
      _resolvedPaths[trimmed] = playbackUri;
      return playbackUri;
    } finally {
      _inFlight.remove(trimmed);
    }
  });
}

Future<String> _downloadToTemp(String url) async {
  final uri = Uri.parse(url);
  final ext = _extensionFromPath(uri.path);
  final fileName = 'circle_video_${url.hashCode.abs()}.$ext';
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');

  if (await file.exists()) {
    final length = await file.length();
    if (length > 0) return file.path;
    await file.delete();
  }

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      responseType: ResponseType.bytes,
      followRedirects: true,
    ),
  );

  await dio.download(url, file.path);
  return file.path;
}

String _extensionFromPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot <= 0 || dot >= path.length - 1) return 'mov';
  return path.substring(dot + 1).toLowerCase();
}
