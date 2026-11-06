import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 画室工具箱的六个工具；[key] 即路由参数 `tool` 的取值。
enum ArtTool {
  value(
    'value',
    '明度检查',
    '灰度与色阶，检查黑白灰关系',
    Icons.contrast_rounded,
    Color(0xFF5D45ED),
  ),
  mirror(
    'mirror',
    '镜像翻转',
    '左右 / 上下翻转，发现比例与透视问题',
    Icons.flip_rounded,
    Color(0xFF4A74D6),
  ),
  grid(
    'grid',
    '构图网格',
    '九宫格与自定义网格，辅助构图和临摹',
    Icons.grid_4x4_rounded,
    Color(0xFF1F8FA8),
  ),
  color(
    'color',
    '取色与色卡',
    '点击取色，自动提取画面主色',
    Icons.colorize_rounded,
    Color(0xFFDE7A34),
  ),
  quickSketch(
    'quickSketch',
    '速写计时练习',
    '限时看图默写，训练动态捕捉',
    Icons.timer_outlined,
    Color(0xFF3B9A6E),
  ),
  countdown(
    'countdown',
    '考试倒计时',
    '联考、校考日程一目了然',
    Icons.event_available_rounded,
    Color(0xFFD64A62),
  );

  const ArtTool(this.key, this.label, this.description, this.icon, this.accent);

  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color accent;

  /// 需要先选择一张图片的工具。
  bool get usesImage =>
      this == value || this == mirror || this == grid || this == color;

  /// 接受英文 key、枚举名、中文名称以及作品点评建议里使用的简称。
  static ArtTool? tryParse(String? key) {
    final value = key?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    for (final tool in ArtTool.values) {
      if (tool.key == value || tool.name == value || tool.label == value) {
        return tool;
      }
    }
    return _aliases[value];
  }

  static const _aliases = <String, ArtTool>{
    '明度': ArtTool.value,
    '镜像': ArtTool.mirror,
    '网格': ArtTool.grid,
    '取色': ArtTool.color,
    '取色色卡': ArtTool.color,
    '速写计时': ArtTool.quickSketch,
    '倒计时': ArtTool.countdown,
  };
}

class ToolboxSample {
  const ToolboxSample(this.asset, this.label);

  final String asset;
  final String label;
}

/// 「使用示例画作」可选的演示图片。
const toolboxSamples = <ToolboxSample>[
  ToolboxSample('assets/demo/art/color-still-1.jpg', '暖调静物'),
  ToolboxSample('assets/demo/art/color-still-4.jpg', '冷调静物'),
  ToolboxSample('assets/demo/art/color-flower-1.jpg', '花卉静物'),
  ToolboxSample('assets/demo/art/color-landscape-1.jpg', '秋日风景'),
  ToolboxSample('assets/demo/art/sketch-still-2.jpg', '素描静物'),
  ToolboxSample('assets/demo/art/sketch-bust-1.jpg', '大卫石膏像'),
  ToolboxSample('assets/demo/art/sketch-geometry-1.jpg', '石膏几何体'),
  ToolboxSample('assets/demo/art/speed-figure-3.jpg', '双人速写'),
];

const _figureRefs = <String>[
  'assets/demo/art/speed-figure-1.jpg',
  'assets/demo/art/speed-figure-2.jpg',
  'assets/demo/art/speed-figure-3.jpg',
  'assets/demo/art/speed-figure-4.jpg',
  'assets/demo/art/speed-figure-5.jpg',
];

const _sceneRefs = <String>[
  'assets/demo/art/speed-group-1.jpg',
  'assets/demo/art/speed-scene-1.jpg',
  'assets/demo/art/speed-figure-3.jpg',
  'assets/demo/art/speed-figure-4.jpg',
  'assets/demo/scene/exam-hall.jpg',
  'assets/demo/scene/studio-wall.jpg',
];

const _mixedRefs = <String>[
  ..._figureRefs,
  'assets/demo/art/speed-group-1.jpg',
  'assets/demo/art/speed-scene-1.jpg',
  'assets/demo/scene/exam-hall.jpg',
  'assets/demo/scene/studio-wall.jpg',
  'assets/demo/art/sketch-bust-1.jpg',
  'assets/demo/art/sketch-bust-3.jpg',
  'assets/demo/art/sketch-portrait-1.jpg',
  'assets/demo/art/sketch-still-1.jpg',
  'assets/demo/art/sketch-still-3.jpg',
  'assets/demo/art/sketch-geometry-1.jpg',
];

enum SketchReferenceSet {
  figures('人物动态', '单人、双人的站、坐、蹲等动态', _figureRefs),
  scenes('组合场景', '多人组合与街道、教室等场景', _sceneRefs),
  mixed('混合', '人物、场景与素描静物混合出题', _mixedRefs);

  const SketchReferenceSet(this.label, this.description, this.assets);

  final String label;
  final String description;
  final List<String> assets;
}

/// 每张参考图的限时（秒）。
const sketchIntervals = <int>[30, 60, 120, 300, 600];

const sketchCounts = <int>[5, 10, 20];

String sketchIntervalLabel(int seconds) =>
    seconds < 60 ? '$seconds秒' : '${seconds ~/ 60}分钟';

/// 按张数生成出题顺序：每轮打乱一次，数量不够时重新洗牌续上，且相邻两张不重复。
List<String> buildSketchSequence(
  List<String> pool,
  int count, [
  math.Random? random,
]) {
  if (pool.isEmpty || count <= 0) {
    return const <String>[];
  }
  final rng = random ?? math.Random();
  final result = <String>[];
  while (result.length < count) {
    final round = [...pool]..shuffle(rng);
    if (result.isNotEmpty && round.length > 1 && round.first == result.last) {
      round.add(round.removeAt(0));
    }
    result.addAll(round.take(count - result.length));
  }
  return result;
}
