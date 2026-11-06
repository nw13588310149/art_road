import 'dart:convert';
import 'dart:typed_data';

/// 生成单工作表的最小 `.xlsx`（ZIP 存储模式 + inlineStr 单元格），
/// 供演示导出接口返回可被 Excel / Numbers / WPS 直接打开的文件。
abstract final class CampusAXlsx {
  static Uint8List build({
    required String sheetName,
    required List<List<String>> rows,
  }) {
    final sheet = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      )
      ..write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      sheet.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        sheet
          ..write('<c r="${_column(c)}${r + 1}" t="inlineStr"><is><t>')
          ..write(_escape(rows[r][c]))
          ..write('</t></is></c>');
      }
      sheet.write('</row>');
    }
    sheet.write('</sheetData></worksheet>');

    final files = <String, String>{
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
          '</Types>',
      '_rels/.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
          '</Relationships>',
      'xl/workbook.xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheets><sheet name="${_escape(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
          '</workbook>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
          '</Relationships>',
      'xl/worksheets/sheet1.xml': sheet.toString(),
    };
    return _zip({
      for (final entry in files.entries) entry.key: utf8.encode(entry.value),
    });
  }

  static String _column(int index) {
    var n = index + 1;
    var name = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      name = String.fromCharCode(65 + rem) + name;
      n = (n - 1) ~/ 26;
    }
    return name;
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static final List<int> _crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) == 1 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    return c;
  });

  static int _crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) >>> 0;
  }

  static Uint8List _zip(Map<String, List<int>> files) {
    final out = BytesBuilder();
    final central = BytesBuilder();
    var offset = 0;
    for (final entry in files.entries) {
      final name = utf8.encode(entry.key);
      final data = entry.value;
      final crc = _crc32(data);
      final local = ByteData(30)
        ..setUint32(0, 0x04034b50, Endian.little)
        ..setUint16(4, 20, Endian.little)
        ..setUint16(6, 0x0800, Endian.little)
        ..setUint16(8, 0, Endian.little)
        ..setUint16(10, 0, Endian.little)
        ..setUint16(12, 0x5A21, Endian.little)
        ..setUint32(14, crc, Endian.little)
        ..setUint32(18, data.length, Endian.little)
        ..setUint32(22, data.length, Endian.little)
        ..setUint16(26, name.length, Endian.little)
        ..setUint16(28, 0, Endian.little);
      out
        ..add(local.buffer.asUint8List())
        ..add(name)
        ..add(data);
      final header = ByteData(46)
        ..setUint32(0, 0x02014b50, Endian.little)
        ..setUint16(4, 20, Endian.little)
        ..setUint16(6, 20, Endian.little)
        ..setUint16(8, 0x0800, Endian.little)
        ..setUint16(10, 0, Endian.little)
        ..setUint16(12, 0, Endian.little)
        ..setUint16(14, 0x5A21, Endian.little)
        ..setUint32(16, crc, Endian.little)
        ..setUint32(20, data.length, Endian.little)
        ..setUint32(24, data.length, Endian.little)
        ..setUint16(28, name.length, Endian.little)
        ..setUint16(30, 0, Endian.little)
        ..setUint16(32, 0, Endian.little)
        ..setUint16(34, 0, Endian.little)
        ..setUint16(36, 0, Endian.little)
        ..setUint32(38, 0, Endian.little)
        ..setUint32(42, offset, Endian.little);
      central
        ..add(header.buffer.asUint8List())
        ..add(name);
      offset += 30 + name.length + data.length;
    }
    final directory = central.takeBytes();
    final end = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint16(4, 0, Endian.little)
      ..setUint16(6, 0, Endian.little)
      ..setUint16(8, files.length, Endian.little)
      ..setUint16(10, files.length, Endian.little)
      ..setUint32(12, directory.length, Endian.little)
      ..setUint32(16, offset, Endian.little)
      ..setUint16(20, 0, Endian.little);
    out
      ..add(directory)
      ..add(end.buffer.asUint8List());
    return out.takeBytes();
  }
}
