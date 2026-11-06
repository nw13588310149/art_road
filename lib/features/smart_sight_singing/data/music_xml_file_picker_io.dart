import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../config/smart_sight_singing_config.dart';
import 'music_xml_file_picker.dart';

Future<PickedMusicXmlFile?> pickLocalMusicXmlFileImpl() async {
  // iOS / iPad 的 UIDocumentPicker 对 FileType.custom 只接受「扩展名 → 单一 UTI」
  // 映射；MusicXML 的 .musicxml / .mxl 在高版本 iOS 上常对不上 UTI，文件会
  // 显示为灰色不可选。改走 FileType.any（public.item），选完再在 Dart 侧校验
  // 扩展名。Android / 桌面仍用 custom 过滤，减少无关文件干扰。
  final useBroadPicker = Platform.isIOS;
  final result = await FilePicker.platform.pickFiles(
    type: useBroadPicker ? FileType.any : FileType.custom,
    allowedExtensions: useBroadPicker
        ? null
        : SmartSightSingingImportConfig.musicXmlExtensions,
    allowMultiple: false,
    withData: false,
  );
  final files = result?.files ?? const <PlatformFile>[];
  if (files.isEmpty) {
    return null;
  }

  final file = files.first;
  final path = file.path;
  if (path == null || path.isEmpty) {
    return null;
  }

  final name = file.name.trim().isEmpty ? _nameFromPath(path) : file.name.trim();
  if (!SmartSightSingingImportConfig.isMusicXmlFileName(name)) {
    throw StateError(
      '请选择 MusicXML 文件（.xml / .musicxml / .mxl）。'
      '高版本 iPad 若列表里文件呈灰色，请先在「文件」App 中确认扩展名正确。',
    );
  }

  final ioFile = File(path);
  final size = await ioFile.length();
  if (size <= 0) {
    throw StateError('所选 MusicXML 文件为空。');
  }
  if (size > SmartSightSingingImportConfig.maxLocalMusicXmlBytes) {
    throw StateError('本地 MusicXML 过大，请使用 8MB 以内的文件。');
  }

  final bytes = Uint8List.fromList(await ioFile.readAsBytes());
  return PickedMusicXmlFile(name: name, path: path, bytes: bytes);
}

String _nameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash < 0 ? normalized : normalized.substring(slash + 1);
}
