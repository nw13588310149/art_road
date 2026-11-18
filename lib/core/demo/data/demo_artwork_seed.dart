/// 作品点评链的种子数据：每次按「现在」重新生成最近 8 周的作品、作品、点评、复核、
/// 校长点评与改画版本，不落盘。
///
/// 两部分数据：
/// - 日常数据按「日期 + 学生 + 作品」取固定随机数，同一份作品在哪天生成结果都一样，
///   只有「现在」之后才发生的事件看不到；
/// - 留给演示账号的待办（林小雨的故事线、李静与赵雪的待点评、张明远的待复核、
///   王海波的超时作品）按相对「现在」的时间编排，id 固定，被操作后整条存进
///   `DemoStore` 覆盖种子。
///
/// 没有演示账号的老师按各自的节奏点评，未到点评时间的作品显示为待点评；有演示账号
/// 的老师和组长名下，日常作品总是已经处理完，待办只来自上面的编排，数量不随时刻变化。
library;

import 'dart:math' as math;

import '../demo_accounts.dart';
import 'demo_artwork_data.dart';
import 'demo_campus_data.dart';
import 'demo_marking_data.dart';

class DemoArtworkSeedResult {
  const DemoArtworkSeedResult({
    required this.now,
    required this.works,
    required this.tasks,
    required this.annotations,
  });

  final DateTime now;
  final List<Map<String, dynamic>> works;
  final List<Map<String, dynamic>> tasks;

  /// `{artworkId: {teacherId: [stroke]}}`；坐标按图片宽高归一化到 0–1。
  final Map<String, dynamic> annotations;
}

/// 固定种子的伪随机数（xorshift32），只用 32 位位运算，各端序列一致。
class _Rng {
  _Rng(String key) {
    final seed = DemoArtworkData.hash32(key);
    _x = seed == 0 ? 0x9E3779B9 : seed;
    _next();
    _next();
  }

  late int _x;

  int _next() {
    var x = _x;
    x = (x ^ ((x << 13) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    x = (x ^ (x >>> 17)) & 0xFFFFFFFF;
    x = (x ^ ((x << 5) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    _x = x;
    return x;
  }

  double next() => _next() / 4294967296;

  int nextInt(int n) => (next() * n).floor();

  bool chance(double p) => next() < p;

  double range(num a, num b) => a + (b - a) * next();

  T pick<T>(List<T> list) => list[nextInt(list.length)];
}

enum _Style { full, medium, brief }

/// 各位老师的点评节奏与风格：拉开差距，校长才看得出问题。
class _Profile {
  const _Profile({
    required this.minDelay,
    required this.maxDelay,
    required this.style,
    this.lateProb = 0,
    this.lateMax = 1100,
    this.bias = 0,
    this.requestProb = 0,
    this.dimFill = 1,
  });

  /// 点评用时（白天的分钟数，08:30–21:30 每天 780 分钟；少于 780 即在时限内）。
  final int minDelay;
  final int maxDelay;

  /// 超过时限才点评的比例与最长用时。
  final double lateProb;
  final int lateMax;

  /// 打分相对学生月考水平的偏移。
  final double bias;
  final _Style style;

  /// 主动请组长复核的比例。
  final double requestProb;

  /// 填写分项的比例。
  final double dimFill;
}

const _profiles = <String, _Profile>{
  // 李静：及时、评语充分。
  't-1': _Profile(
    minDelay: 20,
    maxDelay: 240,
    style: _Style.full,
    bias: 0.5,
    requestProb: 0.06,
  ),
  't-2': _Profile(
    minDelay: 60,
    maxDelay: 420,
    style: _Style.full,
    lateProb: 0.02,
    lateMax: 1000,
    bias: -1,
    dimFill: 0.95,
  ),
  't-3': _Profile(
    minDelay: 60,
    maxDelay: 480,
    style: _Style.medium,
    lateProb: 0.03,
    dimFill: 0.9,
  ),
  // 赵雪：居中。
  't-4': _Profile(
    minDelay: 120,
    maxDelay: 600,
    style: _Style.medium,
    lateProb: 0.1,
    lateMax: 1300,
    bias: 1,
    requestProb: 0.05,
    dimFill: 0.85,
  ),
  // 王海波：偏慢，评语偏短。
  't-5': _Profile(
    minDelay: 420,
    maxDelay: 760,
    style: _Style.brief,
    lateProb: 0.35,
    lateMax: 1500,
    bias: 1.5,
    requestProb: 0.02,
    dimFill: 0.5,
  ),
  // 周强：偏严，打分低于组内均值。
  't-6': _Profile(
    minDelay: 90,
    maxDelay: 540,
    style: _Style.medium,
    lateProb: 0.03,
    bias: -5,
    dimFill: 0.9,
  ),
};

const _fallbackProfile = _Profile(
  minDelay: 60,
  maxDelay: 480,
  style: _Style.medium,
);

/// 组长复核用时（白天的分钟数，都在 48 小时时限内）。
const _leadDelay = <String, (int, int)>{
  't-2': (60, 600),
  't-3': (120, 900),
  't-6': (180, 1000),
};

/// 质量星级的基准：李静高，王海波低。
const _qualityBase = <String, double>{'t-1': 4.6, 't-4': 3.9, 't-5': 2.8};

/// 每个班每周每科 1 次作品，由该科老师在有课的那天上午布置：周一、周三、周五
/// 各一科，三个班错开（值为星期几）。
const _plan = <String, Map<String, int>>{
  '501': {'素描': 1, '速写': 3, '色彩': 5},
  '502': {'色彩': 1, '素描': 3, '速写': 5},
  '503': {'速写': 1, '色彩': 3, '素描': 5},
};

const _subjectCode = <String, String>{'素描': 'sk', '色彩': 'cl', '速写': 'sp'};

/// 课后提交时段：11:30–13:00、17:00–18:30、20:30–21:30（开始分钟、时长）。
const _slotStart = <int>[690, 1020, 1230];
const _slotLength = <int>[90, 90, 60];

const _dayOpen = 510;
const _dayClose = 1290;

const _taskPool = <String, List<(String, String)>>{
  '素描': [
    ('石膏头像写生', '四开纸，三小时，注意头部的大体块和明暗交界线。'),
    ('静物结构素描', '以线为主，交代清楚物体的结构和透视。'),
    ('几何体组合素描', '三个几何体的组合，注意投影和反光。'),
    ('石膏五官写生', '任选一个五官，深入刻画结构转折。'),
    ('人物头像素描', '照片写生，先抓大的明暗关系。'),
    ('静物组合明暗', '陶罐、水果与衬布，拉开黑白灰。'),
    ('长期素描头像', '两次课完成，注意整体推进。'),
    ('立方体组合素描', '注意透视统一和体面转折。'),
  ],
  '色彩': [
    ('静物色彩写生', '四开纸，注意整体色调和冷暖关系。'),
    ('罐子与水果色彩', '先铺大色块，再塑造主体物。'),
    ('花卉色彩写生', '注意花朵的虚实和背景的统一。'),
    ('暖色调静物组合', '控制暖色调下的冷暖对比。'),
    ('冷色调静物组合', '注意暗部的颜色倾向。'),
    ('色彩风景小稿', '三张小色稿，训练色调概括。'),
    ('蔬菜静物写生', '注意固有色与环境色的关系。'),
    ('衬布与水果色彩', '衬布的褶皱要概括，突出主体。'),
  ],
  '速写': [
    ('人物动态速写', '站姿与坐姿各两张，每张十五分钟。'),
    ('站姿与坐姿速写', '注意重心线和头身比例。'),
    ('组合人物速写', '两到三人的组合，注意前后关系。'),
    ('场景速写', '人物与环境结合，注意透视。'),
    ('人物头像速写', '五分钟一张，抓住特征。'),
    ('校园人物速写', '课间写生，画五张动态。'),
    ('车站场景速写', '照片写生，注意人物与场景的比例。'),
    ('双人组合速写', '注意两人之间的呼应关系。'),
  ],
};

/// 作品的参考范画（范画库里的作品 id），隔一次布置一张。
const _referenceWorks = <String, List<String>>{
  '素描': ['7101', '7102', '7103', '7104', '7106'],
  '色彩': ['7111', '7112', '7114', '7115'],
  '速写': ['7122', '7124', '7125', '7127'],
};

const _freeTitles = <String, List<String>>{
  '素描': ['静物素描小稿', '石膏头像练习', '五官结构练习'],
  '色彩': ['静物色彩小稿', '色调练习', '水果色彩练习'],
  '速写': ['人物动态速写', '速写默写练习', '生活场景速写'],
};

/// 按作品名里的关键词挑演示图；空串是该科目的默认图。
const _imagePool = <String, List<(String, List<String>)>>{
  '素描': [
    ('石膏', ['art/sketch-bust-1', 'art/sketch-bust-2', 'art/sketch-bust-3']),
    ('五官', ['art/sketch-bust-2', 'art/detail-sketch']),
    ('几何', ['art/sketch-geometry-1']),
    ('立方', ['art/sketch-geometry-1']),
    ('头像', ['art/sketch-portrait-1', 'art/sketch-bust-3']),
    ('', ['art/sketch-still-1', 'art/sketch-still-2', 'art/sketch-still-3']),
  ],
  '色彩': [
    ('花卉', ['art/color-flower-1']),
    ('风景', ['art/color-landscape-1']),
    ('蔬菜', ['art/detail-color', 'art/color-still-3']),
    (
      '',
      [
        'art/color-still-1',
        'art/color-still-2',
        'art/color-still-3',
        'art/color-still-4',
        'art/color-still-5',
      ],
    ),
  ],
  '速写': [
    ('场景', ['art/speed-scene-1']),
    ('组合', ['art/speed-group-1', 'art/speed-figure-3']),
    (
      '',
      [
        'art/speed-figure-1',
        'art/speed-figure-2',
        'art/speed-figure-4',
        'art/speed-figure-5',
      ],
    ),
  ],
};

const _studentNotes = <String, List<String>>{
  '素描': [
    '画了两个课时，想请老师看看整体关系。',
    '暗部总是画不透气，请老师指点。',
    '这次尝试了新的起稿方法。',
    '时间有点紧，后半段画得比较赶。',
  ],
  '色彩': ['颜色调了很多遍还是觉得脏。', '想请老师看一下整体色调。', '尝试了偏暖的整体色调。', '背景不知道怎么处理比较好。'],
  '速写': ['人物比例不太确定。', '想请老师看一下动态。', '课间在操场画的。', '三个人物的前后关系不太会处理。'],
};

/// 各分项做得好时的一句话。
const _praise = <String, Map<String, String>>{
  '素描': {
    'composition': '构图饱满，主体位置得当',
    'form': '形体结构交代清楚，比例准确',
    'value': '黑白灰关系明确，明暗层次拉得开',
    'rendering': '主体刻画深入，质感表现到位',
  },
  '色彩': {
    'composition': '构图稳定，主次安排合理',
    'form': '形体塑造扎实，笔触跟着结构走',
    'color': '色调统一，冷暖关系协调',
    'rendering': '主体物塑造充分，质感区分明确',
  },
  '速写': {
    'composition': '画面布局合理，人物位置安排得当',
    'gesture': '动态抓得准，重心稳定',
    'line': '线条流畅，有轻重缓急的变化',
    'rendering': '头手脚交代清楚，细节取舍得当',
  },
};

/// 问题标签对应的一句话。
const _problemClause = <String, String>{
  '结构错误': '形体比例还有偏差，起稿时先用辅助线核对大的比例关系',
  '明暗层次弱': '暗部与亮部之间的过渡层次不够，画面略显发平',
  '构图失衡': '主体偏向一侧，画面重心不稳，动笔前先画小构图推敲',
  '线条生硬': '线条轻重变化不足，转折处可以再松动一些',
  '色调不统一': '局部颜色跳出了整体色调，注意环境色的相互影响',
  '透视错误': '透视线没有统一到同一条视平线，先定视平线再起形',
  '暗部偏闷': '暗部画得偏死，加入反光和冷暖变化会更透气',
  '环境色不足': '暗部和投影缺少环境色，物体显得孤立',
  '动态僵硬': '人物动势不够明确，先用动态线定出重心和姿态',
  '画面偏灰': '颜色纯度不足，亮部可以再明快一些',
  '比例失调': '头身比例偏长，先定头顶、脚底和重心线',
};

/// 没有选问题标签时，按较弱的分项给一句改进意见。
const _improve = <String, String>{
  'composition': '构图还可以再推敲，留白与主体的关系要更明确',
  'form': '造型还可以再严谨，注意形体转折处的结构',
  'value': '明暗对比可以再拉开一些',
  'color': '色彩关系可以再大胆一些，注意冷暖对比',
  'gesture': '比例动态还要多观察，注意重心线',
  'line': '线条可以更肯定，减少反复描画',
  'rendering': '主体刻画还可以再深入，注意主次取舍',
};

const _adviceClause = <String, List<String>>{
  '素描': ['下一张先画两个小构图再起稿', '画到一半退远看整体，再回到局部', '多做结构素描的短期练习', '收尾时检查边缘线的虚实'],
  '色彩': ['调色时多与旁边的颜色比较', '先铺大色块再进入局部', '多做小色稿训练色调', '收尾时统一一下暗部的颜色'],
  '速写': ['每天坚持画几张动态速写', '起稿时先定头、肩、胯三条线', '多观察衣纹与结构的关系', '限时练习时先保证大的动态'],
};

/// 偏短的评语（不到 20 字）。
const _briefComments = <String, List<String>>{
  '素描': ['整体可以，暗部再丰富些', '形还不够准，多比较', '黑白灰再拉开一点', '完成度一般，继续深入'],
  '色彩': [
    '色调还行，暗部再丰富些',
    '整体可以，颜色再明快点',
    '构图稳，冷暖再拉开',
    '塑造不够，继续深入',
    '色彩关系基本到位',
    '背景偏花，注意统一',
    '暗部偏灰，多用补色',
  ],
  '速写': ['动态还行，线条再放松', '比例注意一下', '整体可以，细节再交代', '重心不稳，多观察'],
};

const _leadSupplement = <String, String>{
  '素描': '补充一点：暗部可以再透气一些，注意反光与投影的层次。',
  '色彩': '补充一点：先确定大色调，再用环境色把物体和背景联系起来。',
  '速写': '补充一点：先用动态线确定重心，再刻画头、手、脚的结构。',
};

const _qualityNotes = <int, String>{
  5: '评语具体，指出了问题也给了改进方法。',
  4: '点评到位，分项填写完整。',
  3: '评语可以再具体一些，写明怎么改。',
  2: '评语偏短，学生看不出下一步怎么练。',
  1: '点评过于简略，请补充问题与改进建议。',
};

const _featureComments = <String>[
  '构图稳，黑白灰关系明确，已推荐到优秀作品墙，继续保持。',
  '色调统一，画面完整度高，可以作为同学们的参考。',
  '动态生动，线条有节奏，这张很有代表性。',
  '画面干净利落，主次分明，值得大家看一看。',
  '塑造扎实，细节取舍得当，继续往深入里走。',
  '进步很明显，这样的练习状态要保持住。',
];

const _plainComments = <String>[
  '改画之后问题改掉了不少，这种反复打磨的习惯很好。',
  '看得出下了功夫，下一张注意整体关系。',
  '这张暴露的问题比较典型，按老师的建议多练几张。',
];

/// 各科常用的问题标签（老师标签库里的序号）；序号 8 是各老师自己的标签。
const _problemTags = <String, List<int>>{
  '素描': [1, 2, 3, 7],
  '色彩': [5, 3, 2],
  '速写': [4, 1, 3],
};

class _Task {
  _Task({
    required this.id,
    required this.classId,
    required this.subject,
    required this.teacherId,
    required this.title,
    required this.requirement,
    required this.day,
    required this.created,
    required this.due,
    required this.referenceWorkId,
  });

  final String id;
  final String classId;
  final String subject;
  final String teacherId;
  final String title;
  final String requirement;

  /// 布置当天。
  final DateTime day;
  final DateTime created;
  final DateTime due;
  final String referenceWorkId;
}

class _W {
  _W({
    required this.id,
    required this.person,
    required this.subject,
    required this.title,
    required this.submit,
    required this.teacherId,
    this.description = '',
    this.images = const <String>[],
    this.taskId,
    this.scripted = false,
    this.parent,
  });

  final String id;
  final int person;
  final String subject;
  String title;
  final DateTime submit;
  final String teacherId;
  final String description;
  List<String> images;
  String? taskId;

  /// 相对「现在」编排的演示待办与故事线（id 固定）。
  final bool scripted;
  final _W? parent;

  // 点评：时间与内容都是固定抽样，与「现在」无关。
  DateTime? reviewAt;
  double? score;
  String content = '';
  Map<String, int> dims = <String, int>{};
  List<int> tags = <int>[];
  bool request = false;
  List<(String, bool)> resolutions = <(String, bool)>[];

  /// 编排：分数取该生近期同科均分加上这个偏移。
  int? meanDelta;

  /// 编排：指定的评语。
  String? fixedContent;

  // 复核。
  List<String> reasons = <String>[];
  String? leaderId;
  DateTime? leadAt;
  String? action;
  double? leadScore;
  String leadReason = '';
  String leadContent = '';
  int stars = 0;
  String note = '';

  /// 编排：留在复核池里等演示的人处理。
  bool leadPending = false;

  final List<Map<String, dynamic>> supplements = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> principalComments = <Map<String, dynamic>>[];
  DateTime? featuredAt;

  // 「现在」这一刻的状态。
  bool visible = false;
  bool reviewed = false;
  DateTime? reviewEff;
  bool leadDone = false;
  DateTime? leadEff;

  /// 还没到的点评 / 复核时间（没有演示账号的老师、组长）。
  DateTime? pendingReviewAt;
  DateTime? pendingLeadAt;

  int get version => parent == null ? 1 : parent!.version + 1;

  String get rootId => parent?.rootId ?? id;

  /// 走完复核后的最终分（与「现在」无关）。
  double? get stableFinal =>
      action == DemoArtworkData.actionAdjust && leadScore != null
      ? leadScore
      : score;

  /// 最后一个事件的时间（「现在」这一刻）。
  DateTime get lastEvent => leadEff ?? reviewEff ?? submit;
}

abstract final class DemoArtworkSeed {
  /// 生成最近几周的数据。
  static const weeks = 8;

  /// 种子里的进池判断按默认的点评设置。
  static const settings = DemoReviewSettings();

  // 林小雨故事线里的作品（id 固定，消息、首页和测试都按它们对齐）。
  static const storyPendingId = 'aw-lin-11';
  static const storyPendingId2 = 'aw-lin-12';

  /// 《石膏头像结构练习》：李静已点评，在张明远的复核池里。
  static const storyInReviewId = 'aw-lin-09';

  /// 《几何体明暗关系》：李静点评 → 张明远调分 → 校长点评并推优。
  static const storyChainId = 'aw-lin-10';

  /// 《秋日静物色彩写生》：第 1 版有问题，第 2 版改善。
  static const storyRevisionV1Id = 'aw-lin-05';
  static const storyRevisionV2Id = 'aw-lin-06';

  static DemoArtworkSeedResult build(DateTime now) => _Builder(now).run();

  /// 没有演示账号的老师的代点评（用户新交的作品走这里），内容按作品 id 固定。
  ///
  /// [previousTags] 是上一版点评里的问题标签，改画版本要逐个标「已改善 / 仍需加强」。
  static Map<String, dynamic> autoReview(
    Map<String, dynamic> work, {
    required DateTime at,
    List<Map<String, dynamic>> previousTags = const <Map<String, dynamic>>[],
    double? previousScore,
  }) {
    final teacherId = DemoArtworkData.text(work['teacherId']);
    final subject = DemoArtworkData.text(work['subject']);
    final draft = _W(
      id: DemoArtworkData.text(work['id']),
      person: DemoArtworkData.personOf(work),
      subject: subject,
      title: DemoArtworkData.text(work['title']),
      submit: at,
      teacherId: teacherId,
    )..reviewAt = at;
    final problems = <String>[
      for (final tag in previousTags)
        if (!DemoArtworkData.isHighlightTag(
          DemoArtworkData.text(tag['name']),
          DemoArtworkData.text(tag['color']),
        ))
          DemoArtworkData.text(tag['name']),
    ];
    _drawReview(
      draft,
      baseScore: previousScore,
      previousProblems: DemoArtworkData.versionOf(work) > 1 ? problems : null,
      organic: false,
    );
    return _reviewMap(draft, at);
  }

  /// 没有演示账号的组长的代复核，写进 [lead]（进入复核池时生成的记录）。
  static void autoLead(
    Map<String, dynamic> work,
    Map<String, dynamic> lead, {
    required List<double> recentFinals,
    required DateTime at,
  }) {
    final review = DemoArtworkData.reviewOf(work);
    final score = review?['score'];
    final draft =
        _W(
            id: DemoArtworkData.text(work['id']),
            person: DemoArtworkData.personOf(work),
            subject: DemoArtworkData.text(work['subject']),
            title: DemoArtworkData.text(work['title']),
            submit: at,
            teacherId: DemoArtworkData.text(work['teacherId']),
          )
          ..score = score is num ? score.toDouble() : null
          ..reasons = <String>[
            for (final reason
                in (lead['reasons'] as List? ?? const <dynamic>[]))
              '$reason',
          ]
          ..leaderId = DemoArtworkData.text(lead['leaderId']);
    final recent = recentFinals.take(DemoArtworkData.anomalyHistory).toList();
    _drawLead(
      draft,
      recent.length < DemoArtworkData.anomalyMinHistory
          ? null
          : recent.reduce((a, b) => a + b) / recent.length,
    );
    lead
      ..['action'] = draft.action
      ..['score'] = draft.leadScore
      ..['reason'] = draft.leadReason
      ..['content'] = draft.leadContent
      ..['qualityStars'] = draft.stars
      ..['qualityNote'] = draft.note
      ..['time'] = DemoArtworkData.fmt(at);
  }
}

// ── 日历与时间 ──────────────────────────────────────────────────────────

DateTime _d(DateTime day, int addDays) =>
    DateTime(day.year, day.month, day.day + addDays);

DateTime _at(DateTime day, int minutes, [int seconds = 0]) => DateTime(
  day.year,
  day.month,
  day.day,
  minutes ~/ 60,
  minutes % 60,
  seconds,
);

bool _school(DateTime day) => DemoArtworkData.isSchoolDay(day);

DateTime _schoolBack(DateTime day, int n) {
  var result = day;
  for (var left = n; left > 0;) {
    result = _d(result, -1);
    if (_school(result)) {
      left--;
    }
  }
  return result;
}

DateTime _schoolForward(DateTime day, int n) {
  var result = day;
  for (var left = n; left > 0;) {
    result = _d(result, 1);
    if (_school(result)) {
      left--;
    }
  }
  return result;
}

/// 自 2024-01-01（周一）起的天数，用 UTC 计算，不受夏令时影响。
int _ordinal(DateTime day) => DateTime.utc(
  day.year,
  day.month,
  day.day,
).difference(DateTime.utc(2024)).inDays;

String _two(int v) => v.toString().padLeft(2, '0');

String _dayCode(DateTime day) =>
    '${_two(day.year % 100)}${_two(day.month)}${_two(day.day)}';

/// 课后时段里的一个时刻；[frac]、[secFrac] 取 0–1。
DateTime _slotTime(
  DateTime day,
  int slot,
  double frac, [
  double secFrac = 0.5,
]) => _at(
  day,
  _slotStart[slot] + (frac * (_slotLength[slot] - 1)).floor(),
  (secFrac * 59).floor(),
);

/// 从 [from] 起再过 [minutes] 个白天的分钟（08:30–21:30，周日不算）。
DateTime _workAdd(DateTime from, int minutes) {
  var day = DemoArtworkData.dateOnly(from);
  var minute = from.hour * 60 + from.minute;
  var seconds = from.second;
  if (!_school(day) || minute >= _dayClose) {
    day = _schoolForward(day, 1);
    minute = _dayOpen;
    seconds = 0;
  } else if (minute < _dayOpen) {
    minute = _dayOpen;
    seconds = 0;
  }
  var left = minutes < 0 ? 0 : minutes;
  while (true) {
    final room = _dayClose - minute;
    if (left < room) {
      return _at(day, minute + left, seconds);
    }
    left -= room;
    day = _schoolForward(day, 1);
    minute = _dayOpen;
  }
}

/// [a] 到 [b] 之间白天的分钟数。
int _workSpan(DateTime a, DateTime b) {
  if (!b.isAfter(a)) {
    return 0;
  }
  var total = 0;
  var day = DemoArtworkData.dateOnly(a);
  final last = DemoArtworkData.dateOnly(b);
  while (!day.isAfter(last)) {
    if (_school(day)) {
      final open = _at(day, _dayOpen);
      final close = _at(day, _dayClose);
      final from = a.isAfter(open) ? a : open;
      final to = b.isBefore(close) ? b : close;
      if (to.isAfter(from)) {
        total += to.difference(from).inMinutes;
      }
    }
    day = _d(day, 1);
  }
  return total;
}

String _ref(String name) => 'asset:assets/demo/$name.jpg';

// ── 学生水平 ────────────────────────────────────────────────────────────

final Map<String, double> _centerCache = <String, double>{};

/// 学生某科的水平：最近一次有成绩的月考的同科分数。
double _center(int person, String subject) {
  return _centerCache.putIfAbsent('$person|$subject', () {
    final subjectId = DemoMarkingData.subjectIds[subject];
    final entries = DemoMarkingData.instance.entriesOf(person).reversed;
    for (final entry in entries) {
      if (!entry.scored) {
        continue;
      }
      if (subjectId == null) {
        return entry.total! / (entry.subjects?.length ?? 3);
      }
      final score = entry.subject(subjectId)?.score;
      if (score != null) {
        return score;
      }
    }
    return 78;
  });
}

// ── 点评与复核的固定抽样 ────────────────────────────────────────────────

List<int> _candidateTags(String teacherId, String subject) => <int>[
  ...?_problemTags[subject],
  if (DemoArtworkData.exclusiveTags.containsKey(teacherId) &&
      DemoArtworkData.teacherOf(teacherId)?.subject == subject)
    8,
];

String _tagName(String teacherId, int index) =>
    DemoArtworkData.tagDefs(teacherId)[index - 1].$1;

/// 生成一份点评的内容与用时（写进 [w]；点评时间在 [w.submit] 之后）。
void _drawReview(
  _W w, {
  double? baseScore,
  List<String>? previousProblems,
  bool organic = true,
  double? fixedScore,
}) {
  final rng = _Rng('review|${w.id}');
  final profile = _profiles[w.teacherId] ?? _fallbackProfile;

  // 用时。林小雨的日常作品都很快点评，她名下的待办只来自故事线。
  final overtime = rng.chance(profile.lateProb);
  var delay = overtime
      ? rng.range(800, profile.lateMax).round()
      : rng.range(profile.minDelay, profile.maxDelay).round();
  if (organic && w.person == 1) {
    delay = 30 + rng.nextInt(120);
  }
  w.reviewAt ??= _workAdd(w.submit, delay);

  // 分数：以该生最近月考的同科成绩为中心上下浮动。
  final center = _center(w.person, w.subject);
  final noise = (rng.next() + rng.next() - 1) * 4;
  var raw = center + profile.bias + noise;
  final swing = rng.chance(0.035);
  final swingSize = 16 + rng.nextInt(5);
  final swingUp = rng.chance(0.5);
  if (organic && swing && w.person != 1) {
    raw += (center >= 80 || !swingUp) ? -swingSize : swingSize;
  }
  final scoreless = rng.chance(0.02);
  double? score = raw.round().clamp(45, 98).toDouble();
  if (baseScore != null) {
    score = (baseScore + 2 + rng.nextInt(5)).clamp(45, 98).toDouble();
  }
  if (fixedScore != null) {
    score = fixedScore;
  } else if (organic &&
      scoreless &&
      !swing &&
      baseScore == null &&
      w.person != 1) {
    // 少数点评只写评语、不打分。
    score = null;
  }
  w.score = score;

  // 分项：按分数定基准，学生各有一项偏弱。
  final defs = DemoArtworkData.dimensionsOf(w.subject);
  final reference = score ?? center;
  final dims = <String, int>{};
  if (defs.isNotEmpty) {
    final base = reference >= 90
        ? 5
        : reference >= 82
        ? 4
        : reference >= 74
        ? 3
        : reference >= 66
        ? 2
        : 1;
    final weak =
        DemoArtworkData.hash32('weak|${w.person}|${w.subject}') % defs.length;
    for (var i = 0; i < defs.length; i++) {
      var level = base - (i == weak ? 1 : 0);
      final shift = rng.chance(0.25);
      final up = rng.chance(0.5);
      if (shift) {
        level += up ? 1 : -1;
      }
      dims[defs[i].key] = level.clamp(1, 5);
    }
  }
  final fill = rng.chance(profile.dimFill);
  w.dims = fill ? dims : <String, int>{};

  // 标签：分数越低问题越多，每个学生有一个常犯的问题。
  final candidates = _candidateTags(w.teacherId, w.subject);
  final tags = <int>[];
  final roll = rng.next();
  final habitRoll = rng.next();
  final second = rng.nextInt(math.max(1, candidates.length));
  final highlight = rng.chance(0.4);
  if (previousProblems != null) {
    // 改画版本：上一版的问题逐个标记，约七成已改善，没改好的继续留在标签里。
    final resolutions = <(String, bool)>[];
    for (final name in previousProblems) {
      final resolved = rng.chance(0.7);
      resolutions.add((name, resolved));
      if (!resolved) {
        final index = DemoArtworkData.tagDefs(
          w.teacherId,
        ).indexWhere((def) => def.$1 == name);
        if (index >= 0) {
          tags.add(index + 1);
        }
      }
    }
    w.resolutions = resolutions;
  } else if (candidates.isNotEmpty) {
    final count = reference >= 90
        ? (roll < 0.3 ? 1 : 0)
        : reference >= 80
        ? (roll < 0.25 ? 0 : (roll < 0.85 ? 1 : 2))
        : (roll < 0.1 ? 0 : (roll < 0.55 ? 1 : 2));
    if (count > 0) {
      final habit =
          candidates[DemoArtworkData.hash32('habit|${w.person}|${w.subject}') %
              candidates.length];
      final first = habitRoll < 0.55
          ? habit
          : candidates[(habitRoll * 1000).floor() % candidates.length];
      tags.add(first);
      if (count > 1) {
        final other = candidates[second];
        if (other != first) {
          tags.add(other);
        }
      }
    }
  }
  if (reference >= 86 && highlight) {
    tags.add(6);
  }
  w.tags = tags;

  // 评语。
  final problems = <String>[
    for (final index in tags)
      if (index != 6) _tagName(w.teacherId, index),
  ];
  String strongest = '';
  String weakest = '';
  if (dims.isNotEmpty) {
    final ordered = dims.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    strongest = ordered.first.key;
    weakest = ordered.last.key;
  }
  final praise =
      _praise[w.subject]?[strongest] ??
      (w.subject.isEmpty ? '画面完整' : '画面完整，看得出认真观察了对象');
  final problem = problems.isNotEmpty
      ? (_problemClause[problems.first] ?? '还有一些细节需要调整')
      : (_improve[weakest] ?? '细节还可以再推敲');
  final advice = rng.pick(
    _adviceClause[w.subject] ?? const <String>['多画多比较，保持练习的节奏'],
  );
  final briefPool = _briefComments[w.subject] ?? _briefComments['素描']!;
  final brief = rng.pick(briefPool);
  final briefRoll = rng.next();
  w.content = switch (profile.style) {
    _Style.full => '$praise；$problem。$advice。',
    _Style.medium => '$praise，$problem。',
    _Style.brief => briefRoll < 0.7 ? brief : '$praise，$problem。',
  };

  // 请组长复核：只有组员会勾选。
  final request = rng.chance(profile.requestProb);
  w.request =
      organic && request && DemoArtworkData.leaderIdFor(w.teacherId) != null;
}

/// 组长的复核结果（写进 [w]）；[mean] 是该生近期同科最终分占满分的比例。
void _drawLead(_W w, double? mean) {
  final rng = _Rng('lead|${w.id}');
  final leaderId = w.leaderId ?? '';
  final range = _leadDelay[leaderId] ?? (120, 900);
  final delay = rng.range(range.$1, range.$2).round();
  final from = w.reviewAt;
  if (from != null) {
    w.leadAt ??= _workAdd(from, delay);
  }
  final anomaly = w.reasons.contains(DemoArtworkData.reasonScoreAnomaly);
  final brief = w.reasons.contains(DemoArtworkData.reasonBrief);
  final score = w.score;
  final roll = rng.next();
  final nudge = rng.nextInt(5) - 2;
  final small = 2 + rng.nextInt(3);
  final smallUp = rng.chance(0.5);
  if (anomaly && roll < 0.7 && mean != null && score != null) {
    var target = ((mean * 100).round() + nudge).clamp(40, 98).toDouble();
    if (target == score) {
      target = (target + 3).clamp(40, 98).toDouble();
    }
    _adjust(w, target);
  } else if (brief && roll < 0.65) {
    w.action = DemoArtworkData.actionSupplement;
    w.leadContent = _leadSupplement[w.subject] ?? _leadSupplement['素描']!;
  } else if (!anomaly && !brief && roll < 0.06 && score != null) {
    _adjust(w, (score + (smallUp ? small : -small)).clamp(40, 98).toDouble());
  } else if (!anomaly && !brief && roll < 0.14) {
    w.action = DemoArtworkData.actionSupplement;
    w.leadContent = _leadSupplement[w.subject] ?? _leadSupplement['素描']!;
  } else {
    w.action = DemoArtworkData.actionKeep;
  }

  // 质量星级：评语过简或被调分的点评星级偏低。
  final base = _qualityBase[w.teacherId] ?? 4;
  var stars = (base + (rng.next() + rng.next() - 1) * 0.9).round();
  if (brief || (anomaly && w.action == DemoArtworkData.actionAdjust)) {
    stars = math.min(stars, 3);
  }
  w.stars = stars.clamp(1, 5);
  w.note = rng.chance(0.6) ? (_qualityNotes[w.stars] ?? '') : '';
}

void _adjust(_W w, double target) {
  final score = w.score ?? target;
  w.action = DemoArtworkData.actionAdjust;
  w.leadScore = target;
  final text = target.round();
  w.leadReason = target >= score
      ? '对照联考评分标准，这张的造型与完成度应在 $text 分档，原分数偏低。'
      : '形体和画面关系还有明显问题，按评分标准应在 $text 分档，原分数偏高。';
}

Map<String, dynamic> _reviewMap(_W w, DateTime at) => <String, dynamic>{
  'teacherId': w.teacherId,
  'score': w.score,
  'maxScore': 100.0,
  'content': w.content,
  'reviewedTime': DemoArtworkData.fmt(at),
  'dimensions': <String, dynamic>{...w.dims},
  'tags': <Map<String, dynamic>>[
    for (final index in w.tags)
      ?DemoArtworkData.tagSnapshot(w.teacherId, index),
  ],
  'voiceRef': '',
  'voiceSeconds': 0,
  'requestLeadReview': w.request,
  'tagResolutions': <Map<String, dynamic>>[
    for (final item in w.resolutions)
      <String, dynamic>{'tag': item.$1, 'resolved': item.$2},
  ],
};

// ── 生成 ────────────────────────────────────────────────────────────────

class _Builder {
  _Builder(this.now) : today = DemoArtworkData.dateOnly(now) {
    base = _school(today) ? today : _d(today, -1);
  }

  final DateTime now;
  final DateTime today;

  /// 最近一个在校日（周日取周六），编排里的「今天」。
  late final DateTime base;

  final List<_Task> tasks = <_Task>[];

  /// 已被编排占用的「作品 + 学生」，日常数据不再生成。
  final Set<String> claimed = <String>{};

  /// 日常作品走完复核后的最终分（占满分的比例），按点评时间先后。
  final Map<String, List<(DateTime, double)>> history =
      <String, List<(DateTime, double)>>{};

  final DemoReviewSettings settings = DemoArtworkSeed.settings;

  DemoArtworkSeedResult run() {
    _buildTasks();
    final scripted = _buildScripted();
    final organic = _buildOrganic();
    _reviewOrganic(organic);
    _leadOrganic(organic);
    organic.sort((a, b) => a.submit.compareTo(b.submit));
    for (final work in organic) {
      work.visible = _resolve(work);
    }
    _finishScripted(scripted);
    final shown = <_W>[...scripted, ...organic.where((w) => w.visible)];
    _principalPicks(shown);
    shown.sort((a, b) => b.submit.compareTo(a.submit));
    final seededWorks = <Map<String, dynamic>>[
      for (final work in shown) _toMap(work),
    ];
    final chain = seededWorks
        .where((w) => w['id'] == DemoArtworkSeed.storyChainId)
        .first;
    chain['teacherIds'] = ['t-1', 't-4', 't-5'];
    chain['teacherReviews'] = [
      {
        'teacherId': 't-4',
        'score': 89,
        'maxScore': 100,
        'content': '形体转折明确，建议用长线条概括边缘，让局部服从整体。',
        'reviewedTime': DemoArtworkData.fmt(_clock(4, 14, 20)),
        'marks': [_mark('mk-1', 0.475, 0.42, '立方体右侧这条边线断得太碎，用一根长线拉下来。')],
      },
      {
        'teacherId': 't-5',
        'score': 90,
        'maxScore': 100,
        'content': '黑白灰组织清晰，可以继续控制反光的亮度，保留暗部的整体性。',
        'reviewedTime': DemoArtworkData.fmt(_clock(4, 16, 10)),
      },
    ];
    for (final comment in chain['principalComments'] as List) {
      comment['score'] = 93;
    }
    _seedMarks(seededWorks);
    return DemoArtworkSeedResult(
      now: now,
      works: seededWorks,
      tasks: <Map<String, dynamic>>[
        for (final task in tasks.reversed) _taskMap(task),
      ],
      annotations: _annotations(),
    );
  }

  // ── 作品 ──────────────────────────────────────────────────────────────

  void _buildTasks() {
    final monday = _d(today, -(today.weekday - 1));
    final classes = DemoCampusData.classes;
    for (var week = DemoArtworkSeed.weeks - 1; week >= 0; week--) {
      final weekMonday = _d(monday, -7 * week);
      final ordinal = _ordinal(weekMonday) ~/ 7;
      for (var c = 0; c < classes.length; c++) {
        final plan = _plan[classes[c].id];
        if (plan == null) {
          continue;
        }
        for (final entry in plan.entries) {
          final day = _d(weekMonday, entry.value - 1);
          final created = _at(day, 11 * 60 + 20);
          if (created.isAfter(now)) {
            continue;
          }
          final subject = entry.key;
          final pool = _taskPool[subject]!;
          final picked = pool[(ordinal + c * 3) % pool.length];
          final references = _referenceWorks[subject]!;
          tasks.add(
            _Task(
              id: 'tk-${_dayCode(day)}-${classes[c].id}${_subjectCode[subject]}',
              classId: classes[c].id,
              subject: subject,
              teacherId: DemoArtworkData.responsibleTeacherId(
                classes[c].id,
                subject,
              ),
              title: picked.$1,
              requirement: picked.$2,
              day: day,
              created: created,
              due: _at(_d(day, 1), _dayClose),
              referenceWorkId: (ordinal + c).isEven
                  ? references[(ordinal ~/ 2 + c) % references.length]
                  : '',
            ),
          );
        }
      }
    }
    tasks.sort((a, b) => a.created.compareTo(b.created));
  }

  Map<String, dynamic> _taskMap(_Task task) => <String, dynamic>{
    'id': task.id,
    'teacherId': task.teacherId,
    'classIds': <String>[task.classId],
    'subject': task.subject,
    'title': task.title,
    'requirement': task.requirement,
    'dueTime': DemoArtworkData.fmt(task.due),
    'createTime': DemoArtworkData.fmt(task.created),
    'referenceWorkId': task.referenceWorkId,
  };

  // ── 日常提交 ──────────────────────────────────────────────────────────

  List<String> _imagesFor(String subject, String title, _Rng rng) {
    final pools = _imagePool[subject] ?? _imagePool['素描']!;
    var pool = pools.last.$2;
    for (final entry in pools) {
      if (entry.$1.isNotEmpty && title.contains(entry.$1)) {
        pool = entry.$2;
        break;
      }
    }
    final first = rng.pick(pool);
    final extra = rng.chance(0.15);
    final detail = switch (subject) {
      '素描' => 'art/detail-sketch',
      '色彩' => 'art/detail-color',
      _ => 'art/speed-figure-2',
    };
    return <String>[first, if (extra && detail != first) detail];
  }

  List<_W> _buildOrganic() {
    final result = <_W>[];
    for (final task in tasks) {
      final cls = DemoCampusData.classById(task.classId);
      if (cls == null) {
        continue;
      }
      for (final person in cls.students) {
        final index = person.index;
        if (!DemoArtworkData.isActiveStudent(index) ||
            claimed.contains('${task.id}|$index')) {
          continue;
        }
        final rng = _Rng('submit|${task.id}|$index');
        final roll = rng.next();
        final slotRoll = rng.next();
        final frac = rng.next();
        final secFrac = rng.next();
        final lateDays = 2 + rng.nextInt(2);
        final lateSlot = rng.nextInt(3);
        final noteRoll = rng.next();
        final DateTime time;
        if (index == 1) {
          // 林小雨每次都在布置当天中午交，开放中的作品留给演示的人提交。
          if (!now.isAfter(task.due)) {
            continue;
          }
          time = _slotTime(task.day, 0, frac * 0.45, secFrac);
        } else if (roll < 0.88) {
          // 按时交：布置当天或次日的课后时段。
          const weights = <double>[0.15, 0.35, 0.6, 0.7, 0.85, 1];
          final pick = weights.indexWhere((w) => slotRoll < w);
          time = _slotTime(_d(task.day, pick ~/ 3), pick % 3, frac, secFrac);
        } else if (roll < 0.95) {
          // 迟交：截止后一两个在校日补交。
          time = _slotTime(
            _schoolForward(task.day, lateDays),
            lateSlot,
            frac,
            secFrac,
          );
        } else {
          continue;
        }
        if (time.isAfter(now)) {
          continue;
        }
        final notes = _studentNotes[task.subject]!;
        result.add(
          _W(
            id:
                'aw-${_dayCode(task.day)}-${task.classId}'
                '${_subjectCode[task.subject]}-${_two(index)}',
            person: index,
            subject: task.subject,
            title: task.title,
            submit: time,
            teacherId: task.teacherId,
            description: noteRoll < 0.3
                ? notes[(noteRoll * 1000).floor() % notes.length]
                : '',
            images: _imagesFor(task.subject, task.title, rng),
            taskId: task.id,
          ),
        );
      }
    }

    // 少量自主练习：不关联作品，交给本班该科的老师。
    final monday = _d(today, -(today.weekday - 1));
    final first = _d(monday, -7 * (DemoArtworkSeed.weeks - 1));
    for (var day = first; !day.isAfter(today); day = _d(day, 1)) {
      if (!_school(day)) {
        continue;
      }
      for (final person in DemoMarkingData.instance.persons) {
        final index = person.index;
        if (index == 1 || !DemoArtworkData.isActiveStudent(index)) {
          continue;
        }
        final rng = _Rng('free|${_dayCode(day)}|$index');
        if (!rng.chance(0.04)) {
          continue;
        }
        final subject = rng.pick(DemoArtworkData.subjects);
        final time = _slotTime(day, 1 + rng.nextInt(2), rng.next(), rng.next());
        if (time.isAfter(now)) {
          continue;
        }
        final title = rng.pick(_freeTitles[subject]!);
        result.add(
          _W(
            id: 'aw-${_dayCode(day)}-f${_subjectCode[subject]}-${_two(index)}',
            person: index,
            subject: subject,
            title: title,
            submit: time,
            teacherId: DemoArtworkData.responsibleTeacherId(
              DemoArtworkData.classOf(index).id,
              subject,
            ),
            images: _imagesFor(subject, title, rng),
          ),
        );
      }
    }
    return result;
  }

  /// 给日常作品生成点评；约 8% 带问题标签的作品有改画的第 2 版。
  void _reviewOrganic(List<_W> works) {
    for (final work in List<_W>.of(works)) {
      _drawReview(work);
      final problems = <String>[
        for (final index in work.tags)
          if (index != 6) _tagName(work.teacherId, index),
      ];
      if (problems.isEmpty || work.person == 1) {
        continue;
      }
      final rng = _Rng('revise|${work.id}');
      if (!rng.chance(0.08)) {
        continue;
      }
      final day = _schoolForward(
        DemoArtworkData.dateOnly(work.reviewAt!),
        1 + rng.nextInt(3),
      );
      final second = _W(
        id: '${work.id}-v2',
        person: work.person,
        subject: work.subject,
        title: work.title,
        submit: _slotTime(day, 1 + rng.nextInt(2), rng.next(), rng.next()),
        teacherId: work.teacherId,
        description: '按老师的意见改了一版。',
        images: _imagesFor(work.subject, work.title, rng),
        taskId: work.taskId,
        parent: work,
      );
      _drawReview(
        second,
        baseScore: work.score ?? _center(work.person, work.subject),
        previousProblems: problems,
      );
      works.add(second);
    }
  }

  List<double> _recentFinals(int person, String subject, DateTime before) {
    final list = history['$person|$subject'] ?? const <(DateTime, double)>[];
    return <double>[
      for (final item in list.reversed)
        if (item.$1.isBefore(before)) item.$2,
    ];
  }

  /// 按点评先后判断是否进入复核池，并生成组长的处理结果。
  void _leadOrganic(List<_W> works) {
    final ordered = List<_W>.of(works)
      ..sort((a, b) {
        final byTime = a.reviewAt!.compareTo(b.reviewAt!);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    for (final work in ordered) {
      final recent = _recentFinals(work.person, work.subject, work.reviewAt!);
      final leaderId = DemoArtworkData.leaderIdFor(work.teacherId);
      if (leaderId != null) {
        final reasons = DemoArtworkData.leadReasons(
          id: work.id,
          requested: work.request,
          score: work.score,
          maxScore: 100,
          recentFinals: recent,
          content: work.content,
          hasAnnotations: false,
          spotCheckPercent: settings.spotCheckPercent,
        );
        if (reasons.isNotEmpty) {
          work
            ..reasons = reasons
            ..leaderId = leaderId;
          final sample = recent.take(DemoArtworkData.anomalyHistory).toList();
          _drawLead(
            work,
            sample.length < DemoArtworkData.anomalyMinHistory
                ? null
                : sample.reduce((a, b) => a + b) / sample.length,
          );
        }
      }
      final finalScore = work.stableFinal;
      if (finalScore != null) {
        history
            .putIfAbsent(
              '${work.person}|${work.subject}',
              () => <(DateTime, double)>[],
            )
            .add((work.reviewAt!, finalScore / 100));
      }
    }
  }

  /// 把时间提前到「现在」之前：取 [from] 与现在之间白天时段里的一个时刻。
  /// 两者相隔不到 10 分钟时返回 null（这份作品先不出现）。
  DateTime? _advance(DateTime from, String key) {
    final span = _workSpan(from, now);
    if (span < 10) {
      return null;
    }
    final frac = 0.35 + 0.55 * _Rng('advance|$key').next();
    return _workAdd(from, math.max(5, (span * frac).round()));
  }

  /// 过了时限才完成：取时限与现在之间的一个时刻。
  DateTime _lateDone(DateTime limit, String key) {
    final span = _workSpan(limit, now);
    if (span < 2) {
      return now;
    }
    final frac = 0.3 + 0.6 * _Rng('late|$key').next();
    final at = _workAdd(limit, math.max(1, (span * frac).round()));
    return at.isAfter(now) ? now : at;
  }

  /// 「现在」这一刻这份日常作品的状态；返回 false 表示还看不到。
  bool _resolve(_W w) {
    if (w.submit.isAfter(now)) {
      return false;
    }
    final parent = w.parent;
    if (parent != null && !(parent.visible && parent.reviewed)) {
      return false;
    }
    final demoStudent = w.person == 1;
    var reviewAt = w.reviewAt!;
    if (reviewAt.isAfter(now)) {
      if (demoStudent || DemoArtworkData.hasDemoAccount(w.teacherId)) {
        // 演示账号名下的日常作品总是已经点评，待办只来自编排。
        final advanced = _advance(w.submit, 'r|${w.id}');
        if (advanced == null) {
          return false;
        }
        reviewAt = advanced;
      } else {
        final limit = DemoArtworkData.deadline(w.submit, settings.reviewHours);
        if (now.isAfter(limit)) {
          // 超时的作品只留编排里的那几份，其余记为超时后完成。
          reviewAt = _lateDone(limit, 'r|${w.id}');
        } else {
          w.pendingReviewAt = reviewAt;
          return true;
        }
      }
    }
    w
      ..reviewed = true
      ..reviewEff = reviewAt;
    if (w.reasons.isEmpty) {
      return true;
    }
    var leadAt = w.leadAt!;
    if (leadAt.isAfter(now) || !leadAt.isAfter(reviewAt)) {
      if (demoStudent || DemoArtworkData.hasDemoAccount(w.leaderId ?? '')) {
        final advanced = _advance(reviewAt, 'l|${w.id}');
        if (advanced == null) {
          return false;
        }
        leadAt = advanced;
      } else {
        final limit = DemoArtworkData.deadline(reviewAt, settings.leadHours);
        if (now.isAfter(limit)) {
          leadAt = _lateDone(limit, 'l|${w.id}');
        } else {
          w.pendingLeadAt = leadAt;
          return true;
        }
      }
    }
    w
      ..leadDone = true
      ..leadEff = leadAt;
    return true;
  }

  // ── 编排：演示账号的待办与林小雨的故事线 ──────────────────────────────

  /// 往回数第 [k] 个「时刻不晚于现在」的课后时段（0 为最近一个）。
  DateTime _slotBack(int k, double frac) {
    var left = k;
    for (var day = today; ; day = _d(day, -1)) {
      if (!_school(day)) {
        continue;
      }
      for (var slot = 2; slot >= 0; slot--) {
        final time = _slotTime(day, slot, frac);
        if (time.isAfter(now)) {
          continue;
        }
        if (left == 0) {
          return time;
        }
        left--;
      }
    }
  }

  /// [n] 个在校日之前的课后时段。
  DateTime _dayBack(int n, int slot, double frac) =>
      _slotTime(_schoolBack(base, n), slot, frac);

  /// [n] 个在校日之前的某个钟点（n ≥ 1）。
  DateTime _clock(int n, int hour, int minute) =>
      _at(_schoolBack(base, n), hour * 60 + minute);

  _Task? _openTaskAt(int person, String subject, DateTime time) {
    final classId = DemoArtworkData.classOf(person).id;
    for (final task in tasks.reversed) {
      if (task.classId == classId &&
          task.subject == subject &&
          !task.created.isAfter(time) &&
          !time.isAfter(task.due)) {
        return task;
      }
    }
    return null;
  }

  /// 一份待点评的编排作品；提交时刻正好落在本班该科作品的开放期内时，记为这次作品
  /// 的提交（日常数据里不再重复生成）。
  _W _pending(
    String id,
    int person,
    String subject,
    String title,
    DateTime submit, {
    String description = '',
    List<String> images = const <String>[],
    bool link = true,
  }) {
    final classId = DemoArtworkData.classOf(person).id;
    final work = _W(
      id: id,
      person: person,
      subject: subject,
      title: title,
      submit: submit,
      teacherId: DemoArtworkData.responsibleTeacherId(classId, subject),
      description: description,
      images: images,
      scripted: true,
    );
    final task = link ? _openTaskAt(person, subject, submit) : null;
    if (task != null) {
      work
        ..taskId = task.id
        ..title = task.title;
      claimed.add('${task.id}|$person');
    }
    if (work.images.isEmpty) {
      work.images = _imagesFor(subject, work.title, _Rng('image|$id'));
    }
    return work;
  }

  /// 一份已点评的编排作品（自主练习）。
  _W _reviewed(
    String id,
    int person,
    String subject,
    String title,
    DateTime submit,
    DateTime reviewAt, {
    String description = '',
    List<String> images = const <String>[],
    double? score,
    int? meanDelta,
    String? content,
    List<int>? tags,
    Map<String, int>? dims,
    bool request = false,
    _W? parent,
    List<(String, bool)>? resolutions,
  }) {
    final classId = DemoArtworkData.classOf(person).id;
    final work = _W(
      id: id,
      person: person,
      subject: subject,
      title: title,
      submit: submit,
      teacherId: DemoArtworkData.responsibleTeacherId(classId, subject),
      description: description,
      images: images,
      scripted: true,
      parent: parent,
    )..reviewAt = reviewAt;
    _drawReview(work, organic: false, fixedScore: score);
    work
      ..meanDelta = meanDelta
      ..request = request
      ..fixedContent = content
      ..content = content ?? work.content
      ..tags = tags ?? work.tags
      ..dims = dims ?? work.dims
      ..resolutions = resolutions ?? work.resolutions;
    if (work.images.isEmpty) {
      work.images = _imagesFor(subject, title, _Rng('image|$id'));
    }
    return work;
  }

  List<_W> _buildScripted() {
    final principal = DemoAccounts.principal;
    final list = <_W>[];

    // ── 林小雨：待点评 2 份，在李静的队列里，新的一份是最近一个课后时段交的。
    list
      ..add(
        _pending(
          DemoArtworkSeed.storyPendingId,
          1,
          '素描',
          '石膏头像长期作品',
          _slotBack(0, 0.12),
          description: '画了两个课时，重点练习头部结构和明暗交界线，耳朵的位置感觉没有画准。',
          images: const ['art/sketch-bust-1', 'art/detail-sketch'],
          link: false,
        ),
      )
      ..add(
        _pending(
          DemoArtworkSeed.storyPendingId2,
          1,
          '素描',
          '陶罐与水果素描',
          _slotBack(1, 0.55),
          description: '想请老师看一下投影的处理。',
          images: const ['art/sketch-still-1'],
          link: false,
        ),
      );

    // 《石膏头像结构练习》：李静点评并请组长复核，现在在张明远的复核池里。
    list.add(
      _reviewed(
        DemoArtworkSeed.storyInReviewId,
        1,
        '素描',
        '石膏头像结构练习',
        _dayBack(1, 0, 0.56),
        _clock(1, 19, 40),
        description: '这次重点练习头部结构和明暗交界线。',
        images: const ['art/sketch-bust-3'],
        score: 88,
        content: '结构交代清楚，暗部再整体一些；五官位置略有偏差，先用三庭五眼核对比例再刻画细节。',
        tags: const [2],
        dims: const {'composition': 4, 'form': 4, 'value': 3, 'rendering': 4},
        request: true,
      )..leadPending = true,
    );

    list.add(
      _reviewed(
        'aw-lin-08',
        1,
        '色彩',
        '花卉色彩写生',
        _dayBack(2, 1, 0.5),
        _clock(1, 10, 30),
        description: '尝试了偏暖的整体色调，花瓣的颜色不知道是不是太跳。',
        images: const ['art/color-flower-1'],
        score: 83,
        content: '花卉的色彩倾向明确，花瓣边缘的虚实处理得不错，背景还可以再统一一些。',
        tags: const [6, 5],
        dims: const {'composition': 4, 'form': 4, 'color': 3, 'rendering': 4},
      ),
    );

    list.add(
      _reviewed(
        'aw-lin-04',
        1,
        '速写',
        '人物动态速写',
        _dayBack(3, 2, 0.3),
        _clock(2, 19, 48),
        images: const [
          'art/speed-figure-1',
          'art/speed-figure-3',
          'art/speed-figure-4',
        ],
        score: 86,
        content: '动态抓取比较准确，人物重心稳定。下一次加强手部的结构交代，让线条更有节奏。',
        tags: const [4],
        dims: const {'composition': 4, 'gesture': 4, 'line': 3, 'rendering': 4},
      ),
    );

    // 改画链：第 1 版色调偏花，第 2 版改善。
    final first = _reviewed(
      DemoArtworkSeed.storyRevisionV1Id,
      1,
      '色彩',
      '秋日静物色彩写生',
      _dayBack(8, 1, 0.35),
      _clock(7, 11, 10),
      description: '尝试用补色处理暗部。',
      images: const ['art/color-still-2'],
      score: 78,
      content: '画面完整，但整体色调偏花，暗部缺少环境色；建议先定大色调再铺局部，改一版再交。',
      tags: const [5, 8],
      dims: const {'composition': 4, 'form': 3, 'color': 2, 'rendering': 3},
    );
    list
      ..add(first)
      ..add(
        _reviewed(
          DemoArtworkSeed.storyRevisionV2Id,
          1,
          '色彩',
          '秋日静物色彩写生',
          _dayBack(4, 2, 0.6),
          _clock(3, 14, 40),
          description: '按老师的意见先定了大色调，重新画了一版。',
          images: const ['art/color-still-3'],
          score: 84,
          content: '色调比上一版统一多了，暗部也有了冷暖变化；衬布的环境色还可以再大胆一些。',
          tags: const [8],
          dims: const {'composition': 4, 'form': 4, 'color': 4, 'rendering': 3},
          parent: first,
          resolutions: const [('色调不统一', true), ('环境色不足', false)],
        ),
      );

    // 《几何体明暗关系》：李静点评 → 张明远调分 → 校长点评并推优。
    final chain =
        _reviewed(
            DemoArtworkSeed.storyChainId,
            1,
            '素描',
            '几何体明暗关系',
            _dayBack(5, 2, 0.4),
            _clock(4, 10, 5),
            description: '练习投影和反光。',
            images: const ['art/sketch-geometry-1'],
            score: 87,
            content: '明暗交界线处理肯定，投影的虚实关系得当，整体完成度高；暗部反光可以再含蓄一些。',
            tags: const [6],
            dims: const {
              'composition': 4,
              'form': 5,
              'value': 4,
              'rendering': 4,
            },
          )
          ..action = DemoArtworkData.actionAdjust
          ..leadScore = 91
          ..leadReason = '对照联考评分标准，这张的造型和明暗完成度已到 90 分档，原分数偏低。'
          ..stars = 4
          ..note = '评语具体到位，分数可以再放开一些。'
          ..leadAt = _clock(3, 16, 30)
          ..featuredAt = _at(_schoolBack(base, 2), 10 * 60 + 21);
    chain.principalComments.add(<String, dynamic>{
      'id': 'pc-${chain.id}',
      'userId': principal.userId,
      'name': principal.name,
      'content': '构图稳，黑白灰关系明确，已推荐到优秀作品墙，继续保持。',
      'time': DemoArtworkData.fmt(_clock(2, 10, 20)),
    });
    list.add(chain);

    final still = _reviewed(
      'aw-lin-03',
      1,
      '素描',
      '静物结构素描',
      _dayBack(6, 1, 0.7),
      _clock(5, 20, 12),
      description: '第一次画玻璃瓶，反光有点难。',
      images: const ['art/sketch-still-2'],
      score: 82,
      content: '碗口的透视椭圆偏窄，瓶身中轴线要垂直；右侧衬布占比过大，画面重心偏右。',
      tags: const [7, 1, 3],
      dims: const {'composition': 3, 'form': 3, 'value': 4, 'rendering': 4},
    );
    still.supplements.add(<String, dynamic>{
      'teacherId': 't-2',
      'content': '形体塑造扎实，背景衬布的褶皱可以再概括。',
      'time': DemoArtworkData.fmt(_clock(4, 9, 30)),
    });
    list
      ..add(still)
      ..add(
        _reviewed(
          'aw-lin-02',
          1,
          '色彩',
          '暖色调静物组合',
          _dayBack(12, 2, 0.5),
          _clock(11, 15, 5),
          images: const ['art/color-still-4'],
          score: 80,
          content: '色彩关系较协调，冷暖对比还可以拉开，背景用笔再概括一些。',
          tags: const [5],
          dims: const {'composition': 4, 'form': 3, 'color': 3, 'rendering': 3},
        ),
      );

    // ── 李静：2 份超时（两三个在校日前交的），6 份刚交的。
    list
      ..add(_pending('aw-bk-t1-o1', 18, '素描', '石膏五官练习', _dayBack(2, 1, 0.4)))
      ..add(_pending('aw-bk-t1-o2', 25, '素描', '立方体组合练习', _dayBack(3, 2, 0.6)))
      ..add(_pending('aw-bk-t1-01', 4, '素描', '静物素描练习', _slotBack(0, 0.3)))
      ..add(_pending('aw-bk-t1-02', 6, '素描', '石膏头像练习', _slotBack(0, 0.62)))
      ..add(
        _pending(
          'aw-bk-t1-03',
          9,
          '素描',
          '静物明暗练习',
          _slotBack(0, 0.85),
          description: '想请老师看一下投影的处理。',
        ),
      )
      ..add(_pending('aw-bk-t1-04', 15, '素描', '石膏几何体练习', _slotBack(1, 0.25)))
      ..add(_pending('aw-bk-t1-05', 21, '素描', '素描头像练习', _slotBack(1, 0.5)))
      ..add(_pending('aw-bk-t1-06', 34, '素描', '静物结构练习', _slotBack(1, 0.78)));

    // ── 赵雪：4 份刚交的速写。
    list
      ..add(_pending('aw-bk-t4-01', 3, '速写', '人物动态练习', _slotBack(0, 0.2)))
      ..add(_pending('aw-bk-t4-02', 24, '速写', '站姿速写练习', _slotBack(0, 0.7)))
      ..add(
        _pending(
          'aw-bk-t4-03',
          30,
          '速写',
          '组合人物练习',
          _slotBack(1, 0.35),
          description: '三个人物的前后关系不太会处理。',
        ),
      )
      ..add(_pending('aw-bk-t4-04', 36, '速写', '场景速写练习', _slotBack(1, 0.8)));

    // ── 张明远自己带的校考提高班：3 份刚交的素描。
    list
      ..add(_pending('aw-bk-t2-01', 5, '素描', '石膏头像练习', _slotBack(0, 0.45)))
      ..add(_pending('aw-bk-t2-02', 14, '素描', '静物素描练习', _slotBack(1, 0.15)))
      ..add(_pending('aw-bk-t2-03', 23, '素描', '构图小稿练习', _slotBack(1, 0.65)));

    // ── 王海波：6 份超时未点评的色彩。
    const slow = <(int, int, int, double, String)>[
      (7, 2, 1, 0.3, '静物色彩练习'),
      (10, 2, 2, 0.6, '色调练习'),
      (13, 3, 0, 0.5, '水果色彩练习'),
      (16, 3, 2, 0.2, '静物色彩练习'),
      (19, 4, 1, 0.7, '色调练习'),
      (22, 5, 2, 0.4, '水果色彩练习'),
    ];
    for (var i = 0; i < slow.length; i++) {
      final item = slow[i];
      list.add(
        _pending(
          'aw-bk-t5-o${i + 1}',
          item.$1,
          '色彩',
          item.$5,
          _dayBack(item.$2, item.$3, item.$4),
        ),
      );
    }

    // ── 张明远的复核池：李静点评过、等组长处理的素描（另有林小雨的 1 份）。
    // 5 份是上一个在校日点评的，2 份已经超过 48 小时。
    const queue = <(String, int, int, int, int, int, int, bool, String?)>[
      // id、学生、提交（几个在校日前、时段）、点评（几个在校日前、时、分）、
      // 分数相对均分、是否请组长复核、指定评语
      ('aw-lq-1', 27, 2, 1, 10, 40, -2, true, null),
      ('aw-lq-2', 33, 2, 2, 11, 15, -17, false, null),
      ('aw-lq-3', 28, 2, 0, 14, 20, 1, false, null),
      ('aw-lq-4', 31, 2, 2, 16, 5, -3, false, null),
      ('aw-lq-5', 39, 2, 1, 19, 30, 0, false, '整体不错，继续保持。'),
      ('aw-lq-9', 37, 4, 2, 9, 40, -4, false, null),
      ('aw-lq-7', 40, 5, 1, 15, 10, 2, true, null),
    ];
    const reviewDay = <int>[1, 1, 1, 1, 1, 3, 4];
    for (var i = 0; i < queue.length; i++) {
      final item = queue[i];
      final title = _freeTitles['素描']![i % 3];
      list.add(
        _reviewed(
          item.$1,
          item.$2,
          '素描',
          title,
          _dayBack(item.$3, item.$4, 0.2 + 0.1 * i),
          _clock(reviewDay[i], item.$5, item.$6),
          meanDelta: item.$7,
          request: item.$8,
          content: item.$9,
        )..leadPending = true,
      );
    }
    return list;
  }

  /// 编排里已点评的作品：按真实规则判断是否进入复核池。
  void _finishScripted(List<_W> scripted) {
    final ordered = scripted.where((w) => w.reviewAt != null).toList()
      ..sort((a, b) => a.reviewAt!.compareTo(b.reviewAt!));
    final own = <String, List<(DateTime, double)>>{};
    for (final work in scripted) {
      work.visible = true;
    }
    for (final work in ordered) {
      final key = '${work.person}|${work.subject}';
      final at = work.reviewAt!;
      final merged = <(DateTime, double)>[
        for (final item in history[key] ?? const <(DateTime, double)>[])
          if (item.$1.isBefore(at)) item,
        ...?own[key],
      ]..sort((a, b) => b.$1.compareTo(a.$1));
      final recent = <double>[for (final item in merged) item.$2];
      final sample = recent.take(DemoArtworkData.anomalyHistory).toList();
      final mean = sample.length < DemoArtworkData.anomalyMinHistory
          ? null
          : sample.reduce((a, b) => a + b) / sample.length;
      final delta = work.meanDelta;
      if (delta != null) {
        // 分数相对该生近期均分给定，分项、标签与评语按这个分数重新生成。
        final centre = mean == null
            ? _center(work.person, work.subject)
            : mean * 100;
        final request = work.request;
        _drawReview(
          work,
          organic: false,
          fixedScore: (centre.round() + delta).clamp(40, 98).toDouble(),
        );
        work
          ..request = request
          ..content = work.fixedContent ?? work.content;
      }
      work
        ..reviewed = true
        ..reviewEff = at;
      final leaderId = DemoArtworkData.leaderIdFor(work.teacherId);
      final reasons = leaderId == null
          ? const <String>[]
          : DemoArtworkData.leadReasons(
              id: work.id,
              requested: work.request,
              score: work.score,
              maxScore: 100,
              recentFinals: recent,
              content: work.content,
              hasAnnotations: _annotated.contains(work.id),
              spotCheckPercent: settings.spotCheckPercent,
            );
      if (reasons.isNotEmpty) {
        work
          ..reasons = reasons
          ..leaderId = leaderId;
        if (work.action != null) {
          work
            ..leadDone = true
            ..leadEff = work.leadAt;
        } else if (!work.leadPending) {
          // 没有另外编排的，按组长的日常节奏维持原分。
          _drawLead(work, mean);
          work
            ..action = DemoArtworkData.actionKeep
            ..leadScore = null
            ..leadReason = ''
            ..leadContent = ''
            ..leadDone = true
            ..leadEff = work.leadAt!.isAfter(now)
                ? (_advance(at, 'l|${work.id}') ?? now)
                : work.leadAt;
        }
      } else {
        assert(
          work.action == null && !work.leadPending,
          '编排作品 ${work.id} 没有命中任何进入复核池的规则',
        );
        work
          ..action = null
          ..leadPending = false;
      }
      final finalScore = work.stableFinal;
      if (finalScore != null) {
        own.putIfAbsent(key, () => <(DateTime, double)>[]).add((
          at,
          finalScore / 100,
        ));
      }
    }
  }

  // ── 校长：约 12 份优秀作品（三科都有）、约 15 条点评 ──────────────────

  void _principalPicks(List<_W> shown) {
    final principal = DemoAccounts.principal;
    bool settled(_W w) =>
        !w.scripted &&
        w.person != 1 &&
        w.reviewed &&
        (w.reasons.isEmpty || w.leadDone) &&
        w.content.runes.length >= DemoArtworkData.briefLength;
    DateTime actAt(_W w, int salt) => _workAdd(
      w.lastEvent,
      300 + DemoArtworkData.hash32('principal|${w.id}|$salt') % 500,
    );
    void comment(_W w, String content, DateTime at) {
      w.principalComments.add(<String, dynamic>{
        'id': 'pc-${w.id}',
        'userId': principal.userId,
        'name': principal.name,
        'content': content,
        'time': DemoArtworkData.fmt(at),
      });
    }

    var featured = 0;
    final featuredPersons = <int>{};
    for (final subject in DemoArtworkData.subjects) {
      final quota = subject == '素描' ? 3 : 4;
      final candidates =
          shown
              .where(
                (w) =>
                    settled(w) &&
                    w.subject == subject &&
                    w.parent == null &&
                    (w.stableFinal ?? 0) >= 86 &&
                    !actAt(w, 1).isAfter(now),
              )
              .toList()
            ..sort((a, b) {
              final byScore = b.stableFinal!.compareTo(a.stableFinal!);
              return byScore != 0 ? byScore : a.id.compareTo(b.id);
            });
      var taken = 0;
      for (final work in candidates) {
        if (taken >= quota) {
          break;
        }
        if (!featuredPersons.add(work.person)) {
          continue;
        }
        final at = actAt(work, 1);
        comment(
          work,
          _featureComments[(featured + taken) % _featureComments.length],
          at,
        );
        work.featuredAt = at.add(const Duration(minutes: 1));
        taken++;
      }
      featured += taken;
    }

    // 另外 3 条不推优的点评：先看改画的第 2 版，不够再补近期的作品。
    final extras =
        shown
            .where(
              (w) =>
                  settled(w) &&
                  w.featuredAt == null &&
                  w.principalComments.isEmpty &&
                  !actAt(w, 2).isAfter(now),
            )
            .toList()
          ..sort((a, b) {
            final byRevision = (b.parent == null ? 0 : 1).compareTo(
              a.parent == null ? 0 : 1,
            );
            if (byRevision != 0) {
              return byRevision;
            }
            final byTime = b.submit.compareTo(a.submit);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    final extraPersons = <int>{};
    var added = 0;
    for (final work in extras) {
      if (added >= 3) {
        break;
      }
      if (!extraPersons.add(work.person)) {
        continue;
      }
      comment(
        work,
        work.parent != null
            ? _plainComments.first
            : _plainComments[1 + added % 2],
        actAt(work, 2),
      );
      added++;
    }
  }

  // ── 输出 ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _toMap(_W w) {
    final principal = DemoAccounts.principal;
    final featuredAt = w.featuredAt;
    Map<String, dynamic>? lead;
    if (w.reviewed && w.reasons.isNotEmpty && w.leaderId != null) {
      lead = <String, dynamic>{
        'reasons': <String>[...w.reasons],
        'enteredTime': DemoArtworkData.fmt(w.reviewEff!),
        'leaderId': w.leaderId,
        'action': w.leadDone ? w.action : null,
        'score': w.leadDone ? w.leadScore : null,
        'reason': w.leadDone ? w.leadReason : '',
        'content': w.leadDone ? w.leadContent : '',
        'qualityStars': w.leadDone ? w.stars : 0,
        'qualityNote': w.leadDone ? w.note : '',
        'time': w.leadDone ? DemoArtworkData.fmt(w.leadEff!) : '',
        if (!w.leadDone && w.pendingLeadAt != null)
          'seedLeadAt': DemoArtworkData.fmt(w.pendingLeadAt!),
      };
    }
    return <String, dynamic>{
      'id': w.id,
      'rootId': w.rootId,
      'version': w.version,
      'parentId': w.parent?.id ?? '',
      'personIndex': w.person,
      'title': w.title,
      'subject': w.subject,
      'drawingDate': DemoArtworkData.ymd(w.submit),
      'createTime': DemoArtworkData.fmt(w.submit),
      'description': w.description,
      'images': <Map<String, dynamic>>[
        for (var i = 0; i < w.images.length; i++)
          <String, dynamic>{'id': '${w.id}-${i + 1}', 'ref': _ref(w.images[i])},
      ],
      'taskId': w.taskId ?? '',
      'teacherId': w.teacherId,
      'review': w.reviewed ? _reviewMap(w, w.reviewEff!) : null,
      'supplements': <Map<String, dynamic>>[
        for (final item in w.supplements) <String, dynamic>{...item},
      ],
      'leadReview': lead,
      'principalComments': <Map<String, dynamic>>[
        for (final item in w.principalComments) <String, dynamic>{...item},
      ],
      'featured': featuredAt != null,
      'featuredTime': featuredAt == null ? '' : DemoArtworkData.fmt(featuredAt),
      'featuredBy': featuredAt == null ? '' : principal.name,
      if (!w.reviewed && w.pendingReviewAt != null)
        'seedReviewAt': DemoArtworkData.fmt(w.pendingReviewAt!),
    };
  }

  // ── 定点点评 ──────────────────────────────────────────────────────────

  /// 两份编排作品上的定点点评，位置对着批注和评语里说到的地方（赵雪的那一处
  /// 写在 `teacherReviews` 里）。演示包里没有人声录音，种子只有文字；语音由
  /// 老师在点评工作台里现录。
  void _seedMarks(List<Map<String, dynamic>> works) {
    Map<String, dynamic> review(String id) =>
        works.firstWhere((w) => w['id'] == id)['review']
            as Map<String, dynamic>;

    // 《石膏头像结构练习》：李静的评语说五官位置有偏差、暗部要整体。
    review(DemoArtworkSeed.storyInReviewId)['marks'] = [
      _mark('mk-1', 0.53, 0.318, '两眼的位置偏高，眼睛应在头顶到下巴的二分之一处，先用三庭五眼量一遍。'),
      _mark('mk-2', 0.285, 0.5, '耳朵偏低，上缘对齐眉弓、下缘对齐鼻底，参考画上的两条横线。'),
      _mark('mk-3', 0.64, 0.64, '脖子暗部的笔触太碎，用大的调子压一遍，让暗部连成一片。'),
    ];

    // 《几何体明暗关系》：李静说反光要含蓄。
    review(DemoArtworkSeed.storyChainId)['marks'] = [
      _mark('mk-1', 0.47, 0.68, '球体暗部的反光偏亮，压低一个层次，不要亮过灰面。'),
      _mark('mk-2', 0.84, 0.6, '圆柱的明暗交界线画得肯定，保持这样的力度。'),
    ];
  }

  static Map<String, dynamic> _mark(
    String id,
    double x,
    double y,
    String text,
  ) => <String, dynamic>{
    'id': id,
    'imageIndex': 0,
    'x': x,
    'y': y,
    'text': text,
    'voiceRef': '',
    'voiceSeconds': 0,
  };

  // ── 批注 ──────────────────────────────────────────────────────────────

  /// 带批注的编排作品（判断「点评过简」时要用）。
  static const _annotated = <String>{
    DemoArtworkSeed.storyChainId,
    DemoArtworkSeed.storyInReviewId,
    'aw-lin-04',
    'aw-lin-03',
  };

  Map<String, dynamic> _annotations() {
    // 与批注笔一致：红取色板危险色，蓝取素描科目色。
    const red = '#E5323B';
    const blue = '#4A74D6';
    return <String, dynamic>{
      DemoArtworkSeed.storyChainId: <String, dynamic>{
        't-1': <Map<String, dynamic>>[
          _stroke(
            _curve([0.30, 0.52], [0.47, 0.60], [0.40, 0.72]),
            color: blue,
            width: 3,
          ),
          _stroke(_ellipse(0.46, 0.735, 0.16, 0.045), color: red),
          _stroke([
            [0.13, 0.33],
            [0.16, 0.36],
            [0.22, 0.30],
          ], color: red),
        ],
      },
      DemoArtworkSeed.storyInReviewId: <String, dynamic>{
        't-1': <Map<String, dynamic>>[
          _stroke(
            [
              [0.36, 0.327],
              [0.70, 0.327],
            ],
            color: blue,
            width: 2,
          ),
          _stroke(
            [
              [0.36, 0.449],
              [0.70, 0.449],
            ],
            color: blue,
            width: 2,
          ),
          _stroke(
            [
              [0.36, 0.557],
              [0.70, 0.557],
            ],
            color: blue,
            width: 2,
          ),
          _stroke(_ellipse(0.462, 0.356, 0.075, 0.032), color: red),
          _stroke(_ellipse(0.312, 0.43, 0.035, 0.055), color: red),
        ],
      },
      'aw-lin-04': <String, dynamic>{
        't-4': <Map<String, dynamic>>[
          _stroke([
            [0.48, 0.07],
            [0.49, 0.17],
            [0.47, 0.32],
            [0.47, 0.46],
            [0.44, 0.58],
            [0.42, 0.68],
            [0.42, 0.80],
            [0.43, 0.90],
          ], color: blue),
          _stroke(_ellipse(0.33, 0.41, 0.06, 0.045), color: red),
        ],
      },
      'aw-lin-03': <String, dynamic>{
        't-1': <Map<String, dynamic>>[
          _stroke(_ellipse(0.555, 0.518, 0.16, 0.06), color: red),
          _stroke(
            [
              [0.293, 0.04],
              [0.293, 0.80],
            ],
            color: blue,
            width: 2,
          ),
          _stroke([
            [0.94, 0.30],
            [0.86, 0.60],
          ], color: red),
          _stroke([
            [0.84, 0.53],
            [0.86, 0.60],
            [0.905, 0.555],
          ], color: red),
        ],
      },
    };
  }

  static Map<String, dynamic> _stroke(
    List<List<double>> points, {
    required String color,
    double width = 4,
    int imageIndex = 0,
  }) {
    double r4(double v) => (v * 10000).round() / 10000;
    return <String, dynamic>{
      'color': color,
      'width': width,
      'imageIndex': imageIndex,
      'points': <List<double>>[
        for (final p in points) <double>[r4(p[0]), r4(p[1])],
      ],
    };
  }

  static List<List<double>> _ellipse(
    double cx,
    double cy,
    double rx,
    double ry,
  ) {
    const segments = 48;
    return <List<double>>[
      for (var i = 0; i <= segments; i++)
        <double>[
          cx + rx * math.cos(2 * math.pi * i / segments),
          cy + ry * math.sin(2 * math.pi * i / segments),
        ],
    ];
  }

  /// 二次贝塞尔曲线：起点 [a]、控制点 [c]、终点 [b]。
  static List<List<double>> _curve(
    List<double> a,
    List<double> c,
    List<double> b,
  ) {
    const segments = 24;
    final points = <List<double>>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final u = 1 - t;
      points.add(<double>[
        u * u * a[0] + 2 * u * t * c[0] + t * t * b[0],
        u * u * a[1] + 2 * u * t * c[1] + t * t * b[1],
      ]);
    }
    return points;
  }
}
