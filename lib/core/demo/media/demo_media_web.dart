import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> startDemoMediaHost() async {}

String demoFileBaseUrl() => Uri.base.resolve('./').toString();

/// Flutter Web 把资源 `assets/x.png` 发布在 `<base>/assets/assets/x.png`。
String demoAssetUrl(String assetKey) =>
    Uri.base.resolve('assets/${Uri.encodeFull(assetKey)}').toString();

Future<String> hostDemoBytes(Uint8List bytes, String fileName) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: _mimeOf(fileName)),
  );
  return web.URL.createObjectURL(blob);
}

String _mimeOf(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}
