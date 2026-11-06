import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'dormitory_export_saver.dart';

Future<DormitoryExportSaveResult> saveDormitoryExportImpl({
  required Uint8List bytes,
  required String suggestedName,
}) async {
  final isMobile = Platform.isIOS || Platform.isAndroid;
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '保存查寝记录',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      // iOS / Android 必须传入 bytes，由原生层写入并通过系统导出面板保存。
      bytes: isMobile ? bytes : null,
    );
    if (path == null || path.isEmpty) {
      return DormitoryExportSaveResult.cancelledByUser;
    }
    if (!isMobile) {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
    return DormitoryExportSaveResult(ok: true, path: path);
  } on UnimplementedError {
    return const DormitoryExportSaveResult(
      ok: false,
      error: '当前平台暂不支持保存 Excel 文件',
    );
  } catch (error) {
    return DormitoryExportSaveResult(ok: false, error: '保存失败：$error');
  }
}
