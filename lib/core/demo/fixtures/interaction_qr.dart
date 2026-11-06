import 'dart:convert';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// 「我的二维码」演示图：本地生成可扫描的二维码 PNG（字节模式、纠错等级 M、
/// 版本 1–10），以 `data:image/png;base64,...` 返回，与线上接口格式一致。
String demoQrPngDataUri(String text, {int moduleSize = 8, int quietZone = 4}) {
  final matrix = encodeDemoQr(text);
  final size = matrix.length;
  final pixels = (size + quietZone * 2) * moduleSize;
  final image = img.Image(width: pixels, height: pixels);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  final ink = img.ColorRgb8(0x1B, 0x16, 0x33);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (!matrix[y][x]) {
        continue;
      }
      final left = (x + quietZone) * moduleSize;
      final top = (y + quietZone) * moduleSize;
      img.fillRect(
        image,
        x1: left,
        y1: top,
        x2: left + moduleSize - 1,
        y2: top + moduleSize - 1,
        color: ink,
      );
    }
  }
  return 'data:image/png;base64,${base64Encode(img.encodePng(image))}';
}

/// 二维码模块矩阵，`true` 为深色模块。
List<List<bool>> encodeDemoQr(String text) {
  final bytes = utf8.encode(text);
  var version = 1;
  while (version <= 10 &&
      4 + _countBits(version) + bytes.length * 8 >
          _dataCodewords(version) * 8) {
    version++;
  }
  if (version > 10) {
    throw ArgumentError.value(text, 'text', 'QR payload too long');
  }

  final bits = <int>[];
  void append(int value, int length) {
    for (var i = length - 1; i >= 0; i--) {
      bits.add((value >> i) & 1);
    }
  }

  append(0x4, 4);
  append(bytes.length, _countBits(version));
  for (final b in bytes) {
    append(b, 8);
  }
  final capacity = _dataCodewords(version) * 8;
  append(0, math.min(4, capacity - bits.length));
  append(0, (8 - bits.length % 8) % 8);
  for (var pad = 0xEC; bits.length < capacity; pad ^= 0xEC ^ 0x11) {
    append(pad, 8);
  }
  final data = <int>[
    for (var i = 0; i < bits.length; i += 8)
      bits.sublist(i, i + 8).fold<int>(0, (acc, bit) => (acc << 1) | bit),
  ];

  final grid = _QrGrid(version)
    ..drawFunctionPatterns()
    ..drawCodewords(_addEccAndInterleave(data, version));
  var bestMask = 0;
  var bestPenalty = 1 << 30;
  for (var mask = 0; mask < 8; mask++) {
    grid
      ..applyMask(mask)
      ..drawFormatBits(mask);
    final penalty = grid.penalty();
    if (penalty < bestPenalty) {
      bestMask = mask;
      bestPenalty = penalty;
    }
    grid.applyMask(mask);
  }
  grid
    ..applyMask(bestMask)
    ..drawFormatBits(bestMask);
  return grid.modules;
}

const _eccPerBlock = <int>[-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26];
const _blockCount = <int>[-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5];

int _countBits(int version) => version < 10 ? 8 : 16;

int _rawDataModules(int version) {
  var result = (16 * version + 128) * version + 64;
  if (version >= 2) {
    final numAlign = version ~/ 7 + 2;
    result -= (25 * numAlign - 10) * numAlign - 55;
    if (version >= 7) {
      result -= 36;
    }
  }
  return result;
}

int _dataCodewords(int version) =>
    _rawDataModules(version) ~/ 8 -
    _eccPerBlock[version] * _blockCount[version];

List<int> _addEccAndInterleave(List<int> data, int version) {
  final numBlocks = _blockCount[version];
  final eccLen = _eccPerBlock[version];
  final rawCodewords = _rawDataModules(version) ~/ 8;
  final numShortBlocks = numBlocks - rawCodewords % numBlocks;
  final shortBlockLen = rawCodewords ~/ numBlocks;
  final divisor = _reedSolomonDivisor(eccLen);
  final blocks = <List<int>>[];
  var k = 0;
  for (var i = 0; i < numBlocks; i++) {
    final dataLen = shortBlockLen - eccLen + (i < numShortBlocks ? 0 : 1);
    final block = data.sublist(k, k + dataLen);
    k += dataLen;
    final ecc = _reedSolomonRemainder(block, divisor);
    if (i < numShortBlocks) {
      block.add(0);
    }
    blocks.add(block..addAll(ecc));
  }
  final result = <int>[];
  for (var i = 0; i < blocks.first.length; i++) {
    for (var j = 0; j < blocks.length; j++) {
      if (i != shortBlockLen - eccLen || j >= numShortBlocks) {
        result.add(blocks[j][i]);
      }
    }
  }
  return result;
}

List<int> _reedSolomonDivisor(int degree) {
  final result = List<int>.filled(degree, 0)..[degree - 1] = 1;
  var root = 1;
  for (var i = 0; i < degree; i++) {
    for (var j = 0; j < result.length; j++) {
      result[j] = _gfMultiply(result[j], root);
      if (j + 1 < result.length) {
        result[j] ^= result[j + 1];
      }
    }
    root = _gfMultiply(root, 0x02);
  }
  return result;
}

List<int> _reedSolomonRemainder(List<int> data, List<int> divisor) {
  final result = List<int>.filled(divisor.length, 0, growable: true);
  for (final b in data) {
    final factor = b ^ result.removeAt(0);
    result.add(0);
    for (var i = 0; i < divisor.length; i++) {
      result[i] ^= _gfMultiply(divisor[i], factor);
    }
  }
  return result;
}

int _gfMultiply(int x, int y) {
  var z = 0;
  for (var i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >> 7) * 0x11D);
    z ^= ((y >> i) & 1) * x;
  }
  return z;
}

class _QrGrid {
  _QrGrid(this.version)
    : size = version * 4 + 17,
      modules = List.generate(
        version * 4 + 17,
        (_) => List<bool>.filled(version * 4 + 17, false),
      ),
      isFunction = List.generate(
        version * 4 + 17,
        (_) => List<bool>.filled(version * 4 + 17, false),
      );

  final int version;
  final int size;
  final List<List<bool>> modules;
  final List<List<bool>> isFunction;

  void _setFunction(int x, int y, bool dark) {
    modules[y][x] = dark;
    isFunction[y][x] = true;
  }

  void drawFunctionPatterns() {
    for (var i = 0; i < size; i++) {
      _setFunction(6, i, i.isEven);
      _setFunction(i, 6, i.isEven);
    }
    _drawFinder(3, 3);
    _drawFinder(size - 4, 3);
    _drawFinder(3, size - 4);
    final positions = _alignmentPositions();
    final n = positions.length;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final overlapsFinder =
            (i == 0 && j == 0) ||
            (i == 0 && j == n - 1) ||
            (i == n - 1 && j == 0);
        if (!overlapsFinder) {
          _drawAlignment(positions[i], positions[j]);
        }
      }
    }
    drawFormatBits(0);
    _drawVersion();
  }

  void _drawFinder(int cx, int cy) {
    for (var dy = -4; dy <= 4; dy++) {
      for (var dx = -4; dx <= 4; dx++) {
        final dist = math.max(dx.abs(), dy.abs());
        final x = cx + dx;
        final y = cy + dy;
        if (x >= 0 && x < size && y >= 0 && y < size) {
          _setFunction(x, y, dist != 2 && dist != 4);
        }
      }
    }
  }

  void _drawAlignment(int cx, int cy) {
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        _setFunction(cx + dx, cy + dy, math.max(dx.abs(), dy.abs()) != 1);
      }
    }
  }

  List<int> _alignmentPositions() {
    if (version == 1) {
      return const <int>[];
    }
    final numAlign = version ~/ 7 + 2;
    final step = (version * 8 + numAlign * 3 + 5) ~/ (numAlign * 4 - 4) * 2;
    final result = List<int>.filled(numAlign, 6);
    var pos = size - 7;
    for (var i = numAlign - 1; i >= 1; i--) {
      result[i] = pos;
      pos -= step;
    }
    return result;
  }

  /// 纠错等级 M 的格式位为 00，与掩码号拼成 5 位后做 BCH(15,5) 编码。
  void drawFormatBits(int mask) {
    final data = mask;
    var rem = data;
    for (var i = 0; i < 10; i++) {
      rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    }
    final bits = (data << 10 | rem) ^ 0x5412;
    bool bit(int i) => ((bits >> i) & 1) != 0;
    for (var i = 0; i <= 5; i++) {
      _setFunction(8, i, bit(i));
    }
    _setFunction(8, 7, bit(6));
    _setFunction(8, 8, bit(7));
    _setFunction(7, 8, bit(8));
    for (var i = 9; i < 15; i++) {
      _setFunction(14 - i, 8, bit(i));
    }
    for (var i = 0; i < 8; i++) {
      _setFunction(size - 1 - i, 8, bit(i));
    }
    for (var i = 8; i < 15; i++) {
      _setFunction(8, size - 15 + i, bit(i));
    }
    _setFunction(8, size - 8, true);
  }

  void _drawVersion() {
    if (version < 7) {
      return;
    }
    var rem = version;
    for (var i = 0; i < 12; i++) {
      rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
    }
    final bits = version << 12 | rem;
    for (var i = 0; i < 18; i++) {
      final dark = ((bits >> i) & 1) != 0;
      final a = size - 11 + i % 3;
      final b = i ~/ 3;
      _setFunction(a, b, dark);
      _setFunction(b, a, dark);
    }
  }

  void drawCodewords(List<int> data) {
    var i = 0;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) {
        right = 5;
      }
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final x = right - j;
          final upward = ((right + 1) & 2) == 0;
          final y = upward ? size - 1 - vert : vert;
          if (!isFunction[y][x] && i < data.length * 8) {
            modules[y][x] = ((data[i >> 3] >> (7 - (i & 7))) & 1) != 0;
            i++;
          }
        }
      }
    }
  }

  void applyMask(int mask) {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (isFunction[y][x]) {
          continue;
        }
        final invert = switch (mask) {
          0 => (x + y) % 2 == 0,
          1 => y % 2 == 0,
          2 => x % 3 == 0,
          3 => (x + y) % 3 == 0,
          4 => (x ~/ 3 + y ~/ 2) % 2 == 0,
          5 => x * y % 2 + x * y % 3 == 0,
          6 => (x * y % 2 + x * y % 3) % 2 == 0,
          _ => ((x + y) % 2 + x * y % 3) % 2 == 0,
        };
        if (invert) {
          modules[y][x] = !modules[y][x];
        }
      }
    }
  }

  int penalty() {
    var result = 0;
    for (var y = 0; y < size; y++) {
      result += _linePenalty((x) => modules[y][x]);
    }
    for (var x = 0; x < size; x++) {
      result += _linePenalty((y) => modules[y][x]);
    }
    for (var y = 0; y < size - 1; y++) {
      for (var x = 0; x < size - 1; x++) {
        final color = modules[y][x];
        if (color == modules[y][x + 1] &&
            color == modules[y + 1][x] &&
            color == modules[y + 1][x + 1]) {
          result += 3;
        }
      }
    }
    var dark = 0;
    for (final row in modules) {
      dark += row.where((m) => m).length;
    }
    final total = size * size;
    final k = ((dark * 20 - total * 10).abs() + total - 1) ~/ total - 1;
    return result + k * 10;
  }

  int _linePenalty(bool Function(int index) moduleAt) {
    var result = 0;
    var runColor = false;
    var runLength = 0;
    final history = List<int>.filled(7, 0);
    for (var i = 0; i < size; i++) {
      if (moduleAt(i) == runColor) {
        runLength++;
        if (runLength == 5) {
          result += 3;
        } else if (runLength > 5) {
          result++;
        }
      } else {
        _addHistory(runLength, history);
        if (!runColor) {
          result += _finderPatterns(history) * 40;
        }
        runColor = moduleAt(i);
        runLength = 1;
      }
    }
    if (runColor) {
      _addHistory(runLength, history);
      runLength = 0;
    }
    _addHistory(runLength + size, history);
    return result + _finderPatterns(history) * 40;
  }

  void _addHistory(int runLength, List<int> history) {
    final length = history[0] == 0 ? runLength + size : runLength;
    for (var i = history.length - 1; i > 0; i--) {
      history[i] = history[i - 1];
    }
    history[0] = length;
  }

  int _finderPatterns(List<int> h) {
    final n = h[1];
    final core = n > 0 && h[2] == n && h[3] == n * 3 && h[4] == n && h[5] == n;
    return (core && h[0] >= n * 4 && h[6] >= n ? 1 : 0) +
        (core && h[6] >= n * 4 && h[0] >= n ? 1 : 0);
  }
}
