import 'dart:typed_data';

import 'music_xml_file_picker_io.dart'
    if (dart.library.html) 'music_xml_file_picker_web.dart';

class PickedMusicXmlFile {
  const PickedMusicXmlFile({
    required this.name,
    required this.bytes,
    this.path,
  });

  final String name;
  final String? path;
  final Uint8List bytes;
}

Future<PickedMusicXmlFile?> pickLocalMusicXmlFile() =>
    pickLocalMusicXmlFileImpl();
