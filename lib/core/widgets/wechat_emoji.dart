import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../../features/shell/ui/shell_layout.dart';
import 'group_chat_unicode_emojis.dart';

/// 微信经典表情协议：消息体使用 `[名称]`，显示坐标与小程序
/// `components/mp-emoji/index.wxss` 完全一致。
class WechatEmoji {
  WechatEmoji._();

  static const spritePath = AppAssets.emojiSprite;
  static const columns = 11;
  static const rows = 10;
  static const spriteWidth = 724.0;
  static const spriteHeight = 658.0;
  static const sourceCellSize = 64.0;
  static const sourceCellStride = 66.0;

  /// 顺序来自小程序 `emoji-panel-data.js`，不是雪碧图物理排列顺序。
  static const List<String> names = [
    '微笑',
    '撇嘴',
    '色',
    '发呆',
    '得意',
    '流泪',
    '害羞',
    '闭嘴',
    '睡',
    '大哭',
    '尴尬',
    '发怒',
    '调皮',
    '呲牙',
    '惊讶',
    '难过',
    '冷汗',
    '抓狂',
    '吐',
    '偷笑',
    '愉快',
    '白眼',
    '傲慢',
    '困',
    '惊恐',
    '流汗',
    '憨笑',
    '悠闲',
    '奋斗',
    '咒骂',
    '疑问',
    '嘘',
    '晕',
    '衰',
    '骷髅',
    '敲打',
    '再见',
    '擦汗',
    '抠鼻',
    '鼓掌',
    '坏笑',
    '左哼哼',
    '右哼哼',
    '哈欠',
    '鄙视',
    '委屈',
    '快哭了',
    '阴险',
    '亲亲',
    '可怜',
    '菜刀',
    '西瓜',
    '啤酒',
    '咖啡',
    '猪头',
    '玫瑰',
    '凋谢',
    '嘴唇',
    '爱心',
    '心碎',
    '蛋糕',
    '炸弹',
    '便便',
    '月亮',
    '太阳',
    '拥抱',
    '强',
    '弱',
    '握手',
    '胜利',
    '抱拳',
    '勾引',
    '拳头',
    'OK',
    '跳跳',
    '发抖',
    '怄火',
    '转圈',
    '笑脸',
    '生病',
    '破涕为笑',
    '吐舌',
    '脸红',
    '恐惧',
    '失望',
    '无语',
    '嘿哈',
    '捂脸',
    '奸笑',
    '机智',
    '皱眉',
    '耶',
    '吃瓜',
    '加油',
    '汗',
    '天啊',
    'Emm',
    '社会社会',
    '旺柴',
    '好的',
    '打脸',
    '哇',
    '鬼魂',
    '合十',
    '强壮',
    '庆祝',
    '礼物',
    '红包',
  ];

  /// 每项是雪碧图中的物理格序号（row × 11 + column）。
  /// 坐标由小程序 `index.wxss` 的 `background-position` 逐项转换。
  static const List<int> _spriteSlots = [
    24,
    109,
    37,
    49,
    7,
    80,
    41,
    93,
    42,
    101,
    14,
    25,
    33,
    34,
    35,
    36,
    4,
    15,
    26,
    44,
    45,
    46,
    47,
    48,
    5,
    16,
    27,
    38,
    55,
    56,
    39,
    67,
    68,
    69,
    70,
    71,
    72,
    18,
    29,
    40,
    51,
    62,
    0,
    77,
    78,
    79,
    81,
    82,
    83,
    84,
    8,
    19,
    30,
    52,
    74,
    85,
    88,
    89,
    90,
    91,
    92,
    94,
    95,
    96,
    9,
    20,
    31,
    53,
    64,
    75,
    86,
    97,
    99,
    100,
    102,
    103,
    104,
    105,
    32,
    3,
    21,
    65,
    87,
    76,
    54,
    43,
    73,
    11,
    1,
    12,
    22,
    13,
    57,
    58,
    59,
    60,
    6,
    17,
    28,
    50,
    61,
    66,
    108,
    98,
    10,
    107,
    106,
    2,
  ];

  static final Map<String, int> _nameToIndex = {
    for (var i = 0; i < names.length; i++) names[i]: i,
  };

  static final RegExp _tokenPattern = RegExp(r'\[([^\[\]]+)\]');

  static String tokenForIndex(int index) {
    if (index < 0 || index >= names.length) return '';
    return '[${names[index]}]';
  }

  static int? indexForName(String name) => _nameToIndex[name];

  static int? indexForToken(String token) {
    final match = _tokenPattern.firstMatch(token);
    if (match == null || match.group(0) != token) return null;
    return indexForName(match.group(1)!);
  }

  static WechatEmojiSpriteCell? spriteCellForIndex(int index) {
    if (index < 0 || index >= _spriteSlots.length) return null;
    final slot = _spriteSlots[index];
    return WechatEmojiSpriteCell(
      left: (slot % columns) * sourceCellStride,
      top: (slot ~/ columns) * sourceCellStride,
      width: index == 1 ? 63 : sourceCellSize,
      height: sourceCellSize,
    );
  }

  static WechatEmojiSpriteCell? spriteCellForToken(String token) {
    final index = indexForToken(token);
    return index == null ? null : spriteCellForIndex(index);
  }

  /// 删除光标前一个完整 `[表情]`，否则按一个 grapheme 删除。
  static TextEditingValue deleteBeforeCursor(TextEditingValue value) {
    final text = value.text;
    if (text.isEmpty) return value;
    final sel = value.selection;
    if (sel.isValid && sel.start != sel.end) {
      final start = sel.start.clamp(0, text.length);
      final end = sel.end.clamp(0, text.length);
      return TextEditingValue(
        text: text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
    }
    final cursor = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    if (cursor == 0) return value;
    final before = text.substring(0, cursor);
    final tokenMatch = _tokenPattern.allMatches(before).lastOrNull;
    if (tokenMatch != null && tokenMatch.end == before.length) {
      final token = tokenMatch.group(0)!;
      if (indexForToken(token) != null) {
        final newBefore = before.substring(0, tokenMatch.start);
        return TextEditingValue(
          text: newBefore + text.substring(cursor),
          selection: TextSelection.collapsed(offset: newBefore.length),
          composing: TextRange.empty,
        );
      }
    }
    final beforeChars = before.characters;
    if (beforeChars.isEmpty) return value;
    final newBefore = beforeChars.skipLast(1).toString();
    return TextEditingValue(
      text: newBefore + text.substring(cursor),
      selection: TextSelection.collapsed(offset: newBefore.length),
      composing: TextRange.empty,
    );
  }
}

class WechatEmojiSpriteCell {
  const WechatEmojiSpriteCell({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class WechatEmojiSprite extends StatelessWidget {
  const WechatEmojiSprite({super.key, required this.index, required this.size});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cell = WechatEmoji.spriteCellForIndex(index);
    if (cell == null) return const SizedBox.shrink();
    final displayWidth = size * cell.width / WechatEmoji.sourceCellSize;
    return RepaintBoundary(
      child: SizedBox(
        width: displayWidth,
        height: size,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: cell.width,
            height: cell.height,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -cell.left,
                    top: -cell.top,
                    width: WechatEmoji.spriteWidth,
                    height: WechatEmoji.spriteHeight,
                    child: Image.asset(
                      WechatEmoji.spritePath,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<InlineSpan> buildWechatEmojiTextSpans({
  required String text,
  required TextStyle baseStyle,
  required double emojiSize,
}) {
  if (text.isEmpty) return const [];
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in WechatEmoji._tokenPattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
      );
    }
    final token = match.group(0)!;
    final index = WechatEmoji.indexForToken(token);
    if (index != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          style: baseStyle,
          child: WechatEmojiSprite(index: index, size: emojiSize),
        ),
      );
    } else {
      spans.add(TextSpan(text: token, style: baseStyle));
    }
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
  }
  return spans;
}

class WechatEmojiCategory {
  const WechatEmojiCategory({
    required this.label,
    required this.tabIconPath,
    required this.tabIconActivePath,
    this.wechatIndices = const [],
    this.unicodeEmojis = const [],
  });

  final String label;
  final String tabIconPath;
  final String tabIconActivePath;
  final List<int> wechatIndices;
  final List<String> unicodeEmojis;

  int get itemCount => wechatIndices.length + unicodeEmojis.length;

  int gridCrossAxisCount() {
    if (unicodeEmojis.isEmpty) return WechatEmoji.columns;
    return 9;
  }
}

const List<int> _kWechatFaceIndices = [
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
  37,
  38,
  39,
  40,
  41,
  42,
  43,
  44,
  45,
  46,
  47,
  48,
  49,
  50,
  51,
  52,
  53,
  54,
];

const List<int> _kWechatItemAndSymbolIndices = [
  55,
  56,
  57,
  58,
  59,
  60,
  61,
  62,
  63,
  64,
  65,
  66,
  67,
  68,
  69,
  70,
  71,
  72,
  73,
  74,
  75,
  76,
  77,
  78,
  79,
  80,
  81,
  82,
  83,
  84,
  85,
  86,
  87,
  88,
  89,
  90,
  91,
  92,
  93,
  94,
  95,
  96,
  97,
  98,
  99,
  100,
  101,
  102,
  103,
  104,
  105,
  106,
  107,
];

/// 群聊表情面板 6 个分类 Tab，与 1.0 群聊页 face1–face6 一致。
const List<WechatEmojiCategory> kWechatEmojiCategories = [
  WechatEmojiCategory(
    label: '表情',
    tabIconPath: AppAssets.groupChatEmojiTab1,
    tabIconActivePath: AppAssets.groupChatEmojiTab1Active,
    wechatIndices: _kWechatFaceIndices,
  ),
  WechatEmojiCategory(
    label: '手势',
    tabIconPath: AppAssets.groupChatEmojiTab2,
    tabIconActivePath: AppAssets.groupChatEmojiTab2Active,
    unicodeEmojis: GroupChatUnicodeEmojis.gestures,
  ),
  WechatEmojiCategory(
    label: '心心',
    tabIconPath: AppAssets.groupChatEmojiTab3,
    tabIconActivePath: AppAssets.groupChatEmojiTab3Active,
    unicodeEmojis: GroupChatUnicodeEmojis.hearts,
  ),
  WechatEmojiCategory(
    label: '动物',
    tabIconPath: AppAssets.groupChatEmojiTab4,
    tabIconActivePath: AppAssets.groupChatEmojiTab4Active,
    unicodeEmojis: GroupChatUnicodeEmojis.animals,
  ),
  WechatEmojiCategory(
    label: '食物',
    tabIconPath: AppAssets.groupChatEmojiTab5,
    tabIconActivePath: AppAssets.groupChatEmojiTab5Active,
    unicodeEmojis: GroupChatUnicodeEmojis.food,
  ),
  WechatEmojiCategory(
    label: '物品',
    tabIconPath: AppAssets.groupChatEmojiTab6,
    tabIconActivePath: AppAssets.groupChatEmojiTab6Active,
    wechatIndices: _kWechatItemAndSymbolIndices,
    unicodeEmojis: GroupChatUnicodeEmojis.objects,
  ),
];

/// 群聊 / 家校沟通共用的微信经典表情面板。
class WechatEmojiPanel extends StatefulWidget {
  const WechatEmojiPanel({
    super.key,
    required this.onPick,
    required this.onBackspace,
  });

  final ValueChanged<String> onPick;
  final VoidCallback onBackspace;

  @override
  State<WechatEmojiPanel> createState() => _WechatEmojiPanelState();
}

class _WechatEmojiPanelState extends State<WechatEmojiPanel> {
  int _categoryIndex = 0;
  late final List<ScrollController> _scrollControllers = List.generate(
    kWechatEmojiCategories.length,
    (_) => ScrollController(),
  );

  @override
  void dispose() {
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cat = kWechatEmojiCategories[_categoryIndex];
    return Container(
      height: ui(280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFE8E8EA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: ui(20),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              key: ValueKey<int>(_categoryIndex),
              controller: _scrollControllers[_categoryIndex],
              padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(8)),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cat.gridCrossAxisCount(),
                mainAxisSpacing: ui(2),
                crossAxisSpacing: ui(2),
                childAspectRatio: 1,
              ),
              itemCount: cat.itemCount,
              itemBuilder: (context, i) {
                final wechatCount = cat.wechatIndices.length;
                if (i < wechatCount) {
                  final index = cat.wechatIndices[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(ui(6)),
                    onTap: () =>
                        widget.onPick(WechatEmoji.tokenForIndex(index)),
                    child: Center(
                      child: WechatEmojiSprite(index: index, size: ui(26)),
                    ),
                  );
                }
                final emoji = cat.unicodeEmojis[i - wechatCount];
                return InkWell(
                  borderRadius: BorderRadius.circular(ui(6)),
                  onTap: () => widget.onPick(emoji),
                  child: Center(
                    child: Text(
                      emoji,
                      style: TextStyle(fontSize: ui(26), height: 1),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            height: ui(40),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F6FA),
              border: Border(top: BorderSide(color: Color(0xFFE8E8EA))),
            ),
            padding: EdgeInsets.symmetric(horizontal: ui(8)),
            child: Row(
              children: [
                for (var i = 0; i < kWechatEmojiCategories.length; i++)
                  _WechatEmojiCategoryTab(
                    iconPath: kWechatEmojiCategories[i].tabIconPath,
                    activeIconPath: kWechatEmojiCategories[i].tabIconActivePath,
                    label: kWechatEmojiCategories[i].label,
                    active: i == _categoryIndex,
                    onTap: () => setState(() => _categoryIndex = i),
                  ),
                const Spacer(),
                _WechatEmojiCategoryTab(
                  icon: Icons.backspace_outlined,
                  label: '退格',
                  active: false,
                  onTap: widget.onBackspace,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WechatEmojiCategoryTab extends StatelessWidget {
  const _WechatEmojiCategoryTab({
    this.icon,
    this.iconPath,
    this.activeIconPath,
    required this.label,
    required this.active,
    required this.onTap,
  }) : assert(icon != null || iconPath != null);

  final IconData? icon;
  final String? iconPath;
  final String? activeIconPath;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Tooltip(
        message: label,
        child: Container(
          width: ui(32),
          height: ui(28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(ui(6)),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: ui(18),
                  color: active
                      ? const Color(0xFF8741FF)
                      : const Color(0xFF6D6B75),
                )
              : Image.asset(
                  active ? activeIconPath! : iconPath!,
                  width: ui(18),
                  height: ui(18),
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }
}
