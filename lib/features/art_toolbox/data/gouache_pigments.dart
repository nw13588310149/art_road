/// 一支水粉颜料：名称和大致的 sRGB 颜色（0xRRGGBB）。
class GouachePigment {
  const GouachePigment(this.name, this.rgb, {this.earth = false});

  final String name;
  final int rgb;

  /// 土色（土黄、赭石、熟褐、橄榄绿）：本身偏灰，常用来压纯度，和对比色同调
  /// 不算「调脏」。
  final bool earth;

  int get r => (rgb >> 16) & 0xFF;
  int get g => (rgb >> 8) & 0xFF;
  int get b => rgb & 0xFF;

  bool get isWhite => name == '白';
  bool get isBlack => name == '黑';
}

/// 国内学生水粉常见的 25 色。
///
/// 颜色是对常见品牌色卡的**近似值**，只用于估算调色配方：不同品牌、批次和干湿
/// 状态都有色差，界面上要提示以实际调出的颜色为准。顺序即配方里同份数时的排列顺序。
const List<GouachePigment> kGouachePigments = [
  GouachePigment('柠檬黄', 0xF2E21B),
  GouachePigment('中黄', 0xF6C200),
  GouachePigment('土黄', 0xC99A3B, earth: true),
  GouachePigment('桔黄', 0xF08A14),
  GouachePigment('朱红', 0xE2421E),
  GouachePigment('大红', 0xC8201E),
  GouachePigment('深红', 0x96161E),
  GouachePigment('玫瑰红', 0xC21E5A),
  GouachePigment('赭石', 0x9C5A2D, earth: true),
  GouachePigment('熟褐', 0x5A3A28, earth: true),
  GouachePigment('草绿', 0x6E9A2A),
  GouachePigment('中绿', 0x2E8B3A),
  GouachePigment('翠绿', 0x0F9A5A),
  GouachePigment('橄榄绿', 0x6B6B2A, earth: true),
  GouachePigment('粉绿', 0x8CCFB0),
  GouachePigment('墨绿', 0x1E4632),
  GouachePigment('湖蓝', 0x1E9AC8),
  GouachePigment('天蓝', 0x6EB4E0),
  GouachePigment('钴蓝', 0x2A64B4),
  GouachePigment('群青', 0x2A3C9A),
  GouachePigment('普蓝', 0x1A2A50),
  GouachePigment('青莲', 0x6A3A8A),
  GouachePigment('紫罗兰', 0x8A3C9E),
  GouachePigment('白', 0xF5F4EE),
  GouachePigment('黑', 0x262628),
];
