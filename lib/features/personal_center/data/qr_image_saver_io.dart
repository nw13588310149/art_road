import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'qr_image_saver.dart';

/// 桌面写入所选路径；iPad / 手机将字节交给系统文件选择器保存。
Future<QrSaveResult> saveQrImageBytesImpl({
  required Uint8List bytes,
  required String suggestedName,
}) async {
  try {
    final isMobile = Platform.isIOS || Platform.isAndroid;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '保存二维码',
      fileName: suggestedName,
      type: FileType.image,
      bytes: isMobile ? bytes : null,
    );
    if (path == null || path.isEmpty) {
      return QrSaveResult.cancelledByUser;
    }
    if (!isMobile) {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
    return QrSaveResult(ok: true, path: path);
  } on UnimplementedError {
    return const QrSaveResult(ok: false, error: '当前设备未提供文件保存，请截屏保存');
  } catch (e) {
    return QrSaveResult(ok: false, error: '保存失败：$e');
  }
}
