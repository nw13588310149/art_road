// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'dormitory_export_saver.dart';

Future<DormitoryExportSaveResult> saveDormitoryExportImpl({
  required Uint8List bytes,
  required String suggestedName,
}) async {
  try {
    final blob = html.Blob(<dynamic>[
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = suggestedName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    Timer(const Duration(seconds: 5), () {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    });
    return DormitoryExportSaveResult(ok: true, path: suggestedName);
  } catch (error) {
    return DormitoryExportSaveResult(ok: false, error: '下载失败：$error');
  }
}
