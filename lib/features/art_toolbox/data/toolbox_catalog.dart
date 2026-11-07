import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/art/art_subject.dart';
import '../../../core/ui/app_colors.dart';

/// 工具箱首页的三个分组。
enum ArtToolGroup {
  analysis('看画分析', '拍下作业或选一张范画，从明暗、色彩、结构几个角度检查'),
  practice('练习训练', '限时速写与基本功小练习'),
  exam('备考助手', '考试日程、综合分估算与考场物品准备');

  const ArtToolGroup(this.label, this.description);

  final String label;
  final String description;

  List<ArtTool> get tools => [
    for (final tool in ArtTool.values)
      if (tool.group == this) tool,
  ];
}

/// 画室工具箱的全部工具；[key] 即路由参数 `tool` 的取值，其他模块用它直达工具，已有的 key 不能改。
enum ArtTool {
  value(
    'value',
    '明度检查',
    ArtToolGroup.analysis,
    '灰度、色阶与黑白剪影，检查黑白灰关系',
    '切换色阶数看明暗层次，剪影模式拖动阈值只看黑白两大块',
    Icons.contrast_rounded,
    ArtSubject.sketch,
  ),
  blur(
    'blur',
    '眨眼模糊',
    ArtToolGroup.analysis,
    '模糊掉细节，像眯眼一样看大的形和色块',
    '加大模糊程度只看大关系，与原图对比检查整体是否成立',
    Icons.blur_on_rounded,
    ArtSubject.sketch,
  ),
  simplify(
    'simplify',
    '色块简化',
    ArtToolGroup.analysis,
    '把画面归纳成 3–12 个色块，看色彩布局',
    '减少颜色数看大的色块分布，色卡列出每种颜色的面积占比',
    Icons.palette_outlined,
    ArtSubject.color,
  ),
  temperature(
    'temperature',
    '冷暖分布',
    ArtToolGroup.analysis,
    '标出暖色、冷色和中性灰的区域与占比',
    '暖色显示为橙、冷色为蓝、中性灰为灰，对照原图看冷暖关系',
    Icons.thermostat_rounded,
    ArtSubject.color,
  ),
  edges(
    'edges',
    '轮廓线稿',
    ArtToolGroup.analysis,
    '提取轮廓线，检查形体结构与比例',
    '阈值越大线条越少，概括程度越大越只保留大的结构线',
    Icons.gesture_rounded,
    ArtSubject.sketch,
  ),
  mirror(
    'mirror',
    '镜像翻转',
    ArtToolGroup.analysis,
    '左右 / 上下翻转与反相，发现比例与透视问题',
    '翻转后像换了一双眼睛看画面，反相可以单独检查明暗关系',
    Icons.flip_rounded,
    ArtSubject.sketch,
  ),
  color(
    'color',
    '取色与色卡',
    ArtToolGroup.analysis,
    '点击取色，提取主色并生成配色色环',
    '点击画面取色，查看互补、邻近、三角与分裂互补配色',
    Icons.colorize_rounded,
    ArtSubject.color,
  ),
  measure(
    'measure',
    '比例测量',
    ArtToolGroup.analysis,
    '点选两段长度，量比例和倾斜角度',
    '每点两个点成一段，后面的线段都和 A 段比较；可显示铅垂线和水平线',
    Icons.straighten_rounded,
    ArtSubject.sketch,
  ),
  grid(
    'grid',
    '构图网格',
    ArtToolGroup.analysis,
    '三分法、黄金分割、对角线与画纸比例裁切',
    '叠加构图线检查主体位置，选画纸比例预览裁切范围',
    Icons.grid_4x4_rounded,
    ArtSubject.sketch,
  ),
  perspective(
    'perspective',
    '透视辅助',
    ArtToolGroup.analysis,
    '视平线与一至三个灭点，检查透视是否统一',
    '拖动视平线和灭点，让辅助线与画中物体的边线对齐',
    Icons.view_in_ar_rounded,
    ArtSubject.sketch,
  ),
  portrait(
    'portrait',
    '头像比例',
    ArtToolGroup.analysis,
    '三庭五眼框，对照五官的位置',
    '拖动方框对齐发际线和下巴，再拖眉线、鼻底线量出三庭比例',
    Icons.face_rounded,
    ArtSubject.sketch,
  ),
  quickSketch(
    'quickSketch',
    '速写计时练习',
    ArtToolGroup.practice,
    '限时看图默写，训练动态捕捉',
    '选好每张时长、张数与参考图，开始后时间到自动换下一张',
    Icons.timer_outlined,
    ArtSubject.speed,
  ),
  figure(
    'figure',
    '人体比例参考',
    ArtToolGroup.practice,
    '站七坐五蹲三半，以头长为单位看比例',
    '点选姿态查看比例要点，常用参考比例，写生时以对象为准',
    Icons.accessibility_new_rounded,
    ArtSubject.speed,
  ),
  valueOrder(
    'valueOrder',
    '明度排序训练',
    ArtToolGroup.practice,
    '把打乱的灰色块从暗到亮排好，练辨别明度',
    '点两个色块交换位置，或按住拖到目标位置，排好后点检查',
    Icons.gradient_rounded,
    ArtSubject.sketch,
  ),
  countdown(
    'countdown',
    '考试倒计时',
    ArtToolGroup.exam,
    '联考、校考日程一目了然',
    '点卡片修改名称和日期，默认日期仅为示例',
    Icons.event_available_rounded,
    null,
  ),
  score(
    'score',
    '综合分计算器',
    ArtToolGroup.exam,
    '按省份公式估算艺术类综合分',
    '输入文化课和专业成绩，查看计算过程，结果以考试院公布为准',
    Icons.calculate_outlined,
    null,
  ),
  checklist(
    'checklist',
    '考场物品清单',
    ArtToolGroup.exam,
    '证件与画具逐项打勾，考前不遗漏',
    '勾选已准备好的物品，可添加自己的物品，勾选状态保存在本机',
    Icons.checklist_rounded,
    null,
  );

  const ArtTool(
    this.key,
    this.label,
    this.group,
    this.description,
    this.help,
    this.icon,
    this.subject,
  );

  final String key;
  final String label;
  final ArtToolGroup group;

  /// 首页卡片上的一句话介绍。
  final String description;

  /// 工具页页头的一句话用法提示。
  final String help;
  final IconData icon;

  /// 主要服务的科目，图标沿用科目色；备考类工具为 null。
  final ArtSubject? subject;

  Color get accent => subject?.accent ?? AppColors.textSecondary;

  /// 需要先选择一张图片的工具（看画分析组）。
  bool get usesImage => group == ArtToolGroup.analysis;

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
    '剪影': ArtTool.value,
    '黑白剪影': ArtTool.value,
    '镜像': ArtTool.mirror,
    '反相': ArtTool.mirror,
    '网格': ArtTool.grid,
    '构图': ArtTool.grid,
    '取色': ArtTool.color,
    '取色色卡': ArtTool.color,
    '配色': ArtTool.color,
    '色环': ArtTool.color,
    '速写计时': ArtTool.quickSketch,
    '倒计时': ArtTool.countdown,
    '眨眼': ArtTool.blur,
    '模糊': ArtTool.blur,
    '色块': ArtTool.simplify,
    '冷暖': ArtTool.temperature,
    '线稿': ArtTool.edges,
    '轮廓': ArtTool.edges,
    '比例': ArtTool.measure,
    '透视': ArtTool.perspective,
    '三庭五眼': ArtTool.portrait,
    '人体比例': ArtTool.figure,
    '明度排序': ArtTool.valueOrder,
    '综合分': ArtTool.score,
    '物品清单': ArtTool.checklist,
    '考场清单': ArtTool.checklist,
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
    seconds < 60 ? '$seconds 秒' : '${seconds ~/ 60} 分钟';

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
