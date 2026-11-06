import 'dart:convert';

import 'package:flutter/material.dart';

import 'my_notes_state.dart';

/// 矢量笔迹在 `param2` 中的编码约定。
///
/// - `pk:<base64>`：iOS PencilKit 内联数据
/// - `strokes:<json>`：Android / Flutter 笔迹 JSON
/// - 其它非空、非占位字符串：视为已上传文件的相对 path（下载后按内容识别）
abstract final class NoteDrawingCodec {
  static const String pkPrefix = 'pk:';
  static const String strokesPrefix = 'strokes:';
  static const int inlineMaxChars = 80 * 1024;

  static bool isPlaceholder(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return true;
    }
    final lower = value.toLowerCase();
    return lower == 'string' || lower == 'null' || lower == 'undefined';
  }

  static bool hasInlineOrPath(String? raw) => !isPlaceholder(raw);

  static String encodePkInline(String base64) => '$pkPrefix$base64';

  static String encodeStrokesInline(List<NoteStroke> strokes) {
    return '$strokesPrefix${encodeStrokesJson(strokes)}';
  }

  static String encodeStrokesJson(List<NoteStroke> strokes) {
    final payload = <Map<String, dynamic>>[
      for (final stroke in strokes)
        <String, dynamic>{
          'color': stroke.color.toARGB32(),
          'width': stroke.width,
          'points': <List<double>>[
            for (final point in stroke.points) <double>[point.dx, point.dy],
          ],
        },
    ];
    return jsonEncode(payload);
  }

  static List<NoteStroke> decodeStrokesJson(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! List) {
      return const <NoteStroke>[];
    }
    final result = <NoteStroke>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final map = item.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final pointsRaw = map['points'];
      if (pointsRaw is! List || pointsRaw.length < 2) {
        continue;
      }
      final points = <Offset>[];
      for (final point in pointsRaw) {
        if (point is List && point.length >= 2) {
          final dx = (point[0] as num?)?.toDouble();
          final dy = (point[1] as num?)?.toDouble();
          if (dx != null && dy != null) {
            points.add(Offset(dx, dy));
          }
        } else if (point is Map) {
          final dx = (point['x'] as num?)?.toDouble() ??
              (point['dx'] as num?)?.toDouble();
          final dy = (point['y'] as num?)?.toDouble() ??
              (point['dy'] as num?)?.toDouble();
          if (dx != null && dy != null) {
            points.add(Offset(dx, dy));
          }
        }
      }
      if (points.length < 2) {
        continue;
      }
      final colorValue = map['color'];
      final color = colorValue is int
          ? Color(colorValue)
          : Color(int.tryParse(colorValue?.toString() ?? '') ?? 0xFF2A2A2A);
      final width = (map['width'] as num?)?.toDouble() ?? 12;
      result.add(NoteStroke(color: color, width: width, points: points));
    }
    return result;
  }

  /// 解析 param2 / 下载正文，得到可加载的矢量载荷。
  static NoteDrawingPayload? parsePayload(String raw) {
    final value = raw.trim();
    if (isPlaceholder(value)) {
      return null;
    }
    if (value.startsWith(pkPrefix)) {
      final data = value.substring(pkPrefix.length).trim();
      if (data.isEmpty) {
        return null;
      }
      return NoteDrawingPayload.pencilKit(data);
    }
    if (value.startsWith(strokesPrefix)) {
      final jsonText = value.substring(strokesPrefix.length);
      return NoteDrawingPayload.strokes(decodeStrokesJson(jsonText));
    }
    // 纯 JSON 数组（旧/文件正文）
    if (value.startsWith('[')) {
      return NoteDrawingPayload.strokes(decodeStrokesJson(value));
    }
    // 看起来像相对 path / URL → 由调用方下载后再 parseFileBody
    if (_looksLikePath(value)) {
      return NoteDrawingPayload.remotePath(value);
    }
    // 无前缀的长 base64：当作 PencilKit
    if (value.length > 64 && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(value)) {
      return NoteDrawingPayload.pencilKit(value);
    }
    return null;
  }

  static NoteDrawingPayload? parseFileBody(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.startsWith(pkPrefix) ||
        text.startsWith(strokesPrefix) ||
        text.startsWith('[')) {
      return parsePayload(text);
    }
    // 文件正文为裸 PencilKit base64
    return NoteDrawingPayload.pencilKit(text);
  }

  static bool _looksLikePath(String value) {
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('//') ||
        value.startsWith('app/') ||
        value.startsWith('/app/')) {
      return true;
    }
    return value.contains('/') && !value.contains(' ');
  }
}

enum NoteDrawingKind { pencilKit, strokes, remotePath }

class NoteDrawingPayload {
  const NoteDrawingPayload._({
    required this.kind,
    this.pencilKitBase64,
    this.strokes = const <NoteStroke>[],
    this.remotePath,
  });

  factory NoteDrawingPayload.pencilKit(String base64) => NoteDrawingPayload._(
        kind: NoteDrawingKind.pencilKit,
        pencilKitBase64: base64,
      );

  factory NoteDrawingPayload.strokes(List<NoteStroke> strokes) =>
      NoteDrawingPayload._(
        kind: NoteDrawingKind.strokes,
        strokes: strokes,
      );

  factory NoteDrawingPayload.remotePath(String path) => NoteDrawingPayload._(
        kind: NoteDrawingKind.remotePath,
        remotePath: path,
      );

  final NoteDrawingKind kind;
  final String? pencilKitBase64;
  final List<NoteStroke> strokes;
  final String? remotePath;
}
