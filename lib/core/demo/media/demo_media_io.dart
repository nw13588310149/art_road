import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

HttpServer? _server;
String _base = '';
Directory? _uploadDir;

Future<void> startDemoMediaHost() async {
  if (_server != null) {
    return;
  }
  final dir = Directory('${Directory.systemTemp.path}/art_road_demo_uploads');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  _uploadDir = dir;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  _server = server;
  _base = 'http://127.0.0.1:${server.port}/';
  server.listen((request) {
    _handle(request).catchError((Object error) {
      debugPrint('[demo-media] ${request.uri} 失败：$error');
    });
  });
}

String demoFileBaseUrl() => _base;

String demoAssetUrl(String assetKey) =>
    '${_base}a/${Uri.encodeFull(assetKey)}';

Future<String> hostDemoBytes(Uint8List bytes, String fileName) async {
  final dir = _uploadDir;
  if (dir == null) {
    throw StateError('Demo media host is not started');
  }
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final id = '${DateTime.now().microsecondsSinceEpoch}_$safeName';
  await File('${dir.path}/$id').writeAsBytes(bytes, flush: true);
  return 'f/$id';
}

Future<void> _handle(HttpRequest request) async {
  final response = request.response;
  response.headers.set('Access-Control-Allow-Origin', '*');
  final path = request.uri.path;
  Uint8List? bytes;
  var name = path;
  try {
    if (path.startsWith('/a/')) {
      name = Uri.decodeFull(path.substring(3));
      final data = await rootBundle.load(name);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } else if (path.startsWith('/f/') && _uploadDir != null) {
      name = path.substring(3);
      final file = File('${_uploadDir!.path}/$name');
      if (await file.exists()) {
        bytes = await file.readAsBytes();
      }
    }
  } catch (_) {
    bytes = null;
  }
  if (bytes == null) {
    response.statusCode = HttpStatus.notFound;
    await response.close();
    return;
  }

  response.headers.set(HttpHeaders.contentTypeHeader, _mimeOf(name));
  response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
  response.headers.set(HttpHeaders.cacheControlHeader, 'max-age=3600');

  final total = bytes.length;
  var start = 0;
  var end = total - 1;
  final range = request.headers.value(HttpHeaders.rangeHeader);
  if (range != null && range.startsWith('bytes=') && total > 0) {
    final parts = range.substring(6).split('-');
    final requestedStart = int.tryParse(parts.first);
    final requestedEnd = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (requestedStart == null && requestedEnd != null) {
      start = (total - requestedEnd).clamp(0, total - 1);
    } else {
      start = (requestedStart ?? 0).clamp(0, total - 1);
      end = (requestedEnd ?? total - 1).clamp(start, total - 1);
    }
    response.statusCode = HttpStatus.partialContent;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/$total',
    );
  } else {
    response.statusCode = HttpStatus.ok;
  }
  response.contentLength = total == 0 ? 0 : end - start + 1;
  if (request.method != 'HEAD' && total > 0) {
    response.add(Uint8List.sublistView(bytes, start, end + 1));
  }
  await response.close();
}

String _mimeOf(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}
