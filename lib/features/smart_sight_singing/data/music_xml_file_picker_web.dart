import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../config/smart_sight_singing_config.dart';
import 'music_xml_file_picker.dart';

Future<PickedMusicXmlFile?> pickLocalMusicXmlFileImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: SmartSightSingingImportConfig.musicXmlExtensions,
    allowMultiple: false,
    withData: true,
  );
  final files = result?.files ?? const <PlatformFile>[];
  if (files.isEmpty) {
    return null;
  }

  final file = files.first;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  if (bytes.length > SmartSightSingingImportConfig.maxLocalMusicXmlBytes) {
    throw StateError('本地 MusicXML 过大，请使用 8MB 以内的文件。');
  }

  final name = file.name.trim().isEmpty ? 'score.musicxml' : file.name.trim();
  return PickedMusicXmlFile(
    name: name,
    bytes: Uint8List.fromList(bytes),
  );
}
