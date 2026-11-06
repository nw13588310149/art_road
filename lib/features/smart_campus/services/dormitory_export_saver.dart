import 'dart:typed_data';

import 'dormitory_export_saver_io.dart'
    if (dart.library.html) 'dormitory_export_saver_web.dart';

class DormitoryExportSaveResult {
  const DormitoryExportSaveResult({
    required this.ok,
    this.cancelled = false,
    this.path,
    this.error,
  });

  final bool ok;
  final bool cancelled;
  final String? path;
  final String? error;

  static const cancelledByUser = DormitoryExportSaveResult(
    ok: false,
    cancelled: true,
  );
}

Future<DormitoryExportSaveResult> saveDormitoryExport({
  required Uint8List bytes,
  required String suggestedName,
}) {
  return saveDormitoryExportImpl(bytes: bytes, suggestedName: suggestedName);
}
