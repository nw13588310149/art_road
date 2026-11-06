import 'dart:typed_data';

import 'midi_file_picker_io.dart'
    if (dart.library.html) 'midi_file_picker_web.dart';

/// 用户从本地选择的 MIDI 文件。
class PickedMidiFile {
  const PickedMidiFile({
    required this.name,
    required this.bytes,
    this.path,
  });

  final String name;
  final String? path;
  final Uint8List bytes;
}

/// 打开系统文件选择器，选取 `.mid` / `.midi`。
Future<PickedMidiFile?> pickLocalMidiFile() => pickLocalMidiFileImpl();
