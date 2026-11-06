import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<({Uint8List bytes, String filename, int size})?>
pickAiChatAttachmentFileImpl() async {
  // iOS / Android 上 FileType.image 会直接进入系统相册；桌面端保留任意文件。
  final fileType = !kIsWeb && (Platform.isIOS || Platform.isAndroid)
      ? FileType.image
      : FileType.any;

  final result = await FilePicker.platform.pickFiles(
    type: fileType,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }

  final file = result.files.first;
  var bytes = file.bytes;
  if ((bytes == null || bytes.isEmpty) &&
      file.path != null &&
      file.path!.isNotEmpty) {
    try {
      bytes = await File(file.path!).readAsBytes();
    } catch (_) {
      return null;
    }
  }
  if (bytes == null || bytes.isEmpty) {
    return null;
  }

  final filename = file.name.trim().isNotEmpty ? file.name.trim() : 'attachment';
  return (bytes: bytes, filename: filename, size: bytes.length);
}
