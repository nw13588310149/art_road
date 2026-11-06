import 'dart:math' as math;
import 'dart:typed_data';

/// 网格均匀采样 RGBA 像素，返回 [r, g, b, r, g, b, ...]。
Uint8List sampleRgb(Uint8List rgba, int width, int height, int maxSamples) {
  final stride = math.max(
    1,
    math.sqrt(width * height / math.max(1, maxSamples)).ceil(),
  );
  final start = stride ~/ 2;
  int countFrom(int extent) =>
      start >= extent ? 0 : (extent - 1 - start) ~/ stride + 1;
  final out = Uint8List(countFrom(width) * countFrom(height) * 3);
  var o = 0;
  for (var y = start; y < height; y += stride) {
    for (var x = start; x < width; x += stride) {
      final i = (y * width + x) * 4;
      out[o++] = rgba[i];
      out[o++] = rgba[i + 1];
      out[o++] = rgba[i + 2];
    }
  }
  return out;
}

double sampleDistance2(Uint8List samples, int i, List<double> center) {
  final dr = samples[i * 3] - center[0];
  final dg = samples[i * 3 + 1] - center[1];
  final db = samples[i * 3 + 2] - center[2];
  return dr * dr + dg * dg + db * db;
}

/// k-means++ 选初始中心；样本全部重合时提前结束，返回的中心可能少于 [k] 个。
List<List<double>> seedCenters(Uint8List samples, int k, math.Random random) {
  final n = samples.length ~/ 3;
  List<double> centerOf(int i) => [
    samples[i * 3].toDouble(),
    samples[i * 3 + 1].toDouble(),
    samples[i * 3 + 2].toDouble(),
  ];
  final centers = <List<double>>[centerOf(random.nextInt(n))];
  final nearest = Float64List(n);
  for (var i = 0; i < n; i++) {
    nearest[i] = sampleDistance2(samples, i, centers.first);
  }
  while (centers.length < k) {
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      total += nearest[i];
    }
    if (total <= 0) {
      break;
    }
    var target = random.nextDouble() * total;
    var pick = n - 1;
    for (var i = 0; i < n; i++) {
      target -= nearest[i];
      if (target <= 0) {
        pick = i;
        break;
      }
    }
    final center = centerOf(pick);
    centers.add(center);
    for (var i = 0; i < n; i++) {
      final d = sampleDistance2(samples, i, center);
      if (d < nearest[i]) {
        nearest[i] = d;
      }
    }
  }
  return centers;
}

/// 把每个样本归到最近的中心，返回是否有样本换了归属。
bool assignNearest(
  Uint8List samples,
  List<List<double>> centers,
  Int32List assignment,
) {
  var changed = false;
  final n = samples.length ~/ 3;
  for (var i = 0; i < n; i++) {
    var best = 0;
    var bestD = double.infinity;
    for (var c = 0; c < centers.length; c++) {
      final d = sampleDistance2(samples, i, centers[c]);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    if (assignment[i] != best) {
      assignment[i] = best;
      changed = true;
    }
  }
  return changed;
}

/// 按当前归属重新计算中心；没有样本的中心保持原位。
({List<List<double>> centers, List<int> sizes}) recenter(
  Uint8List samples,
  List<List<double>> centers,
  Int32List assignment,
) {
  final k = centers.length;
  final sums = List.generate(k, (_) => [0.0, 0.0, 0.0]);
  final sizes = List<int>.filled(k, 0);
  final n = samples.length ~/ 3;
  for (var i = 0; i < n; i++) {
    final c = assignment[i];
    sums[c][0] += samples[i * 3];
    sums[c][1] += samples[i * 3 + 1];
    sums[c][2] += samples[i * 3 + 2];
    sizes[c]++;
  }
  return (
    centers: [
      for (var c = 0; c < k; c++)
        sizes[c] == 0
            ? centers[c]
            : [
                sums[c][0] / sizes[c],
                sums[c][1] / sizes[c],
                sums[c][2] / sizes[c],
              ],
    ],
    sizes: sizes,
  );
}

/// RGB 空间的 k-means：k-means++ 初始化、固定种子，结果可复现。
({List<List<double>> centers, List<int> sizes}) kMeansRgb(
  Uint8List samples,
  int k, {
  int seed = 7,
  int maxIterations = 16,
}) {
  final n = samples.length ~/ 3;
  var centers = seedCenters(samples, k, math.Random(seed));
  final assignment = Int32List(n);
  for (var iteration = 0; iteration < maxIterations; iteration++) {
    final changed = assignNearest(samples, centers, assignment);
    centers = recenter(samples, centers, assignment).centers;
    if (!changed && iteration > 0) {
      break;
    }
  }
  assignNearest(samples, centers, assignment);
  return recenter(samples, centers, assignment);
}
