import 'dart:math' as math;

/// 难度：灰阶覆盖的感知明度（CIE L*）范围，范围越窄相邻色块越接近。
enum ValueOrderLevel {
  standard('标准', '从深灰到浅灰，跨度大', 14, 92),
  fine('细腻', '集中在中间调，相邻色块更接近', 32, 76);

  const ValueOrderLevel(this.label, this.description, this.minLightness, this.maxLightness);

  final String label;
  final String description;
  final double minLightness;
  final double maxLightness;
}

const valueOrderCounts = <int>[7, 8, 9];

/// CIE L*（0–100）对应的 sRGB 灰度值，让色阶按人眼感受均匀分布。
int greyForLightness(double lightness) {
  final l = lightness.clamp(0.0, 100.0);
  final fy = (l + 16) / 116;
  final y = l > 8 ? fy * fy * fy : l / 903.3;
  final srgb = y <= 0.0031308
      ? 12.92 * y
      : 1.055 * math.pow(y, 1 / 2.4) - 0.055;
  return (srgb * 255).round().clamp(0, 255);
}

/// 明度排序：把打乱的灰色块从暗到亮排好。[levels] 为当前从左到右的灰度值（各不相同）。
class ValueOrderGame {
  ValueOrderGame(List<int> levels) : levels = List<int>.of(levels);

  /// 发一局：[count] 个灰阶在难度范围内均匀分布并带少量随机偏移，打乱到大部分不在原位。
  factory ValueOrderGame.deal({
    int count = 7,
    ValueOrderLevel level = ValueOrderLevel.standard,
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    final n = count.clamp(3, 12);
    final step = (level.maxLightness - level.minLightness) / (n - 1);
    final greys = <int>[];
    for (var i = 0; i < n; i++) {
      final jitter = (rng.nextDouble() - 0.5) * step * 0.3;
      final lightness = i == 0 || i == n - 1
          ? level.minLightness + step * i
          : level.minLightness + step * i + jitter;
      var grey = greyForLightness(lightness);
      if (greys.isNotEmpty && grey <= greys.last) {
        grey = greys.last + 1;
      }
      greys.add(grey);
    }
    final shuffled = List<int>.of(greys);
    for (var attempt = 0; attempt < 60; attempt++) {
      shuffled.shuffle(rng);
      var inPlace = 0;
      for (var i = 0; i < n; i++) {
        if (shuffled[i] == greys[i]) {
          inPlace++;
        }
      }
      if (inPlace <= n ~/ 3) {
        break;
      }
    }
    return ValueOrderGame(shuffled);
  }

  final List<int> levels;

  int get length => levels.length;

  /// 正确顺序：从暗到亮。
  List<int> get answer => List<int>.of(levels)..sort();

  void swap(int a, int b) {
    if (a == b) {
      return;
    }
    final t = levels[a];
    levels[a] = levels[b];
    levels[b] = t;
  }

  /// 把 [from] 位置的色块插到 [to] 位置，其余依次挪动。
  void move(int from, int to) {
    if (from == to) {
      return;
    }
    final item = levels.removeAt(from);
    levels.insert(to.clamp(0, levels.length), item);
  }

  /// 放错位置的下标（升序）。
  List<int> mistakes() {
    final sorted = answer;
    return [
      for (var i = 0; i < levels.length; i++)
        if (levels[i] != sorted[i]) i,
    ];
  }

  bool get solved => mistakes().isEmpty;

  /// 位置 [index] 上的色块在正确顺序里应该排第几（从 0 开始）。
  int rankOf(int index) => answer.indexOf(levels[index]);
}

/// 用时文本：`1:05.3`。
String formatValueOrderTime(int millis) {
  final tenths = (millis / 100).round();
  final minutes = tenths ~/ 600;
  final seconds = (tenths % 600) ~/ 10;
  final fraction = tenths % 10;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.$fraction';
}
