import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../config/smart_sight_singing_config.dart';
import 'midi_file_picker.dart';

Future<PickedMidiFile?> pickLocalMidiFileImpl() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['mid', 'midi'],
    allowMultiple: false,
    withData: false,
  );
  final files = result?.files ?? const <PlatformFile>[];
  if (files.isEmpty) return null;

  final file = files.first;
  final path = file.path;
  if (path == null || path.isEmpty) return null;

  final ioFile = File(path);
  final size = await ioFile.length();
  if (size <= 0) {
    throw StateError('所选 MIDI 文件为空。');
  }
  if (size > SmartSightSingingImportConfig.maxLocalMidiBytes) {
    throw StateError('本地 MIDI 过大，请使用 8MB 以内的文件。');
  }

  final bytes = Uint8List.fromList(await ioFile.readAsBytes());
  final name = file.name.trim().isEmpty
      ? _nameFromPath(path)
      : file.name.trim();
  return PickedMidiFile(name: name, path: path, bytes: bytes);
}

String _nameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash < 0 ? normalized : normalized.substring(slash + 1);
}
