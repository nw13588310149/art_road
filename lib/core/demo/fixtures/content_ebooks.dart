import '../data/demo_favorites.dart';
import '../demo_backend.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';

/// 「我的收藏」里书刊的收藏类型，与视频 6、资讯 9、范画 11 并列。
const int kDemoEbookFavoriteType = 12;

/// 美术书刊演示接口（平台客户端）：十本自制示例书刊，封面与内页由
/// `tool/ebooks/make_samples.py` 生成到 `assets/demo/ebooks/`。
///
/// 阅读进度、书签与阅读次数写入 [DemoStore]；收藏写入 [DemoFavorites]，
/// 因此会同步出现在「我的收藏」中。
void registerEbookFixtures(DemoRouter platform) {
  platform.get('/app/ebooks/categories', (req) {
    return [
      for (final category in _categories)
        <String, dynamic>{
          'key': category.key,
          'label': category.label,
          'count': _books.where((b) => _matches(b, category.key)).length,
        },
    ];
  });

  platform.get('/app/ebooks', (req) {
    final userId = _userOf(req);
    final category = _normalizeCategory(req.str('category'));
    var list = _books.where((b) => _matches(b, category)).toList();
    if (req.boolOf('featured')) {
      list = list.where((b) => b.featuredIntro.isNotEmpty).toList();
    }
    list = demoSearch(
      list,
      req.str('keyword'),
      (b) => [
        b.title,
        b.subtitle,
        b.editor,
        _categoryLabel(b.category),
        b.stage,
        ...b.subjects,
        ...b.tags,
      ],
    );
    final reads = _readStore();
    switch (req.str('sort', 'recommend')) {
      case 'latest':
        list.sort((a, b) => b.publishDate.compareTo(a.publishDate));
      case 'popular':
        list.sort((a, b) => _readersOf(b, reads).compareTo(_readersOf(a, reads)));
      default:
        list.sort((a, b) => a.rank.compareTo(b.rank));
    }
    return demoPage([for (final b in list) _summaryJson(b, userId, reads)], req);
  });

  platform.get('/app/ebooks/shelf', (req) {
    final userId = _userOf(req);
    final reads = _readStore();
    final progress = _progressStore(userId);
    final favoriteTimes = <String, String>{
      for (final f in DemoFavorites.of(userId))
        if (f['type'] == kDemoEbookFavoriteType)
          (f['targetId']?.toString() ?? ''): f['createTime']?.toString() ?? '',
    };
    final records = <Map<String, dynamic>>[];
    var reading = 0;
    for (final book in _books) {
      final saved = progress[book.id];
      final favoriteTime = favoriteTimes[book.id];
      if (saved is! Map && favoriteTime == null) {
        continue;
      }
      final readTime = saved is Map ? saved['updatedAt']?.toString() ?? '' : '';
      if (saved is Map && _toInt(saved['page']) < book.pageCount) {
        reading++;
      }
      final last = (favoriteTime ?? '').compareTo(readTime) > 0
          ? favoriteTime!
          : readTime;
      records.add(<String, dynamic>{
        ..._summaryJson(book, userId, reads),
        'lastActiveAt': last,
      });
    }
    records.sort(
      (a, b) => (b['lastActiveAt'] as String).compareTo(a['lastActiveAt'] as String),
    );
    return <String, dynamic>{
      'records': records,
      'total': records.length,
      'readingCount': reading,
      'favoriteCount': favoriteTimes.length,
    };
  });

  platform.get('/app/ebooks/{id}', (req) {
    final userId = _userOf(req);
    final book = _findBook(req.param('id'));
    final reads = _readStore();
    return <String, dynamic>{
      ..._summaryJson(book, userId, reads),
      'description': book.description,
      'toc': [
        for (final (title, page) in book.toc)
          <String, dynamic>{'title': title, 'page': page},
      ],
      'related': [
        for (final other in _relatedOf(book, reads))
          _summaryJson(other, userId, reads),
      ],
    };
  });

  platform.get('/app/ebooks/{id}/pages', (req) {
    final book = _findBook(req.param('id'));
    final reads = _readStore();
    reads[book.id] = _toInt(reads[book.id]) + 1;
    DemoStore.save(_readsKey);
    return <String, dynamic>{
      'bookId': book.id,
      'pageCount': book.pageCount,
      'pages': [
        for (var page = 1; page <= book.pageCount; page++)
          <String, dynamic>{
            'page': page,
            'imageUrl': DemoMedia.url(book.pageRef(page)),
            'width': 720,
            'height': 960,
          },
      ],
    };
  });

  platform.get('/app/ebooks/{id}/progress', (req) {
    final userId = _userOf(req);
    final book = _findBook(req.param('id'));
    final saved = _progressStore(userId)[book.id];
    return <String, dynamic>{
      'page': saved is Map ? _toInt(saved['page']) : null,
      'updatedAt': saved is Map ? saved['updatedAt'] : null,
      'bookmarks': _bookmarksOf(userId, book.id),
    };
  });

  platform.post('/app/ebooks/{id}/progress', (req) {
    final userId = _userOf(req);
    final book = _findBook(req.param('id'));
    final page = req.intOf('page');
    if (page < 1) {
      throw const DemoApiException('页码无效', code: 400);
    }
    final value = <String, dynamic>{
      'page': page > book.pageCount ? book.pageCount : page,
      'updatedAt': _now(),
    };
    _progressStore(userId)[book.id] = value;
    DemoStore.save(_progressKey(userId));
    return value;
  });

  platform.post('/app/ebooks/{id}/favorite', (req) {
    final userId = _userOf(req);
    final book = _findBook(req.param('id'));
    final favorite = req.boolOf('favorite', true);
    _setFavorite(userId, book, favorite);
    return <String, dynamic>{'favorite': favorite};
  });

  platform.post('/app/ebooks/{id}/bookmarks', (req) {
    final userId = _userOf(req);
    final book = _findBook(req.param('id'));
    final page = req.intOf('page');
    if (page < 1 || page > book.pageCount) {
      throw const DemoApiException('页码无效', code: 400);
    }
    final store = _bookmarkStore(userId);
    final pages = {..._bookmarksOf(userId, book.id)};
    if (req.boolOf('bookmarked', true)) {
      pages.add(page);
    } else {
      pages.remove(page);
    }
    final sorted = pages.toList()..sort();
    store[book.id] = sorted;
    DemoStore.save(_bookmarksKey(userId));
    return <String, dynamic>{'bookmarks': sorted};
  });
}

// ── 分类 ────────────────────────────────────────────────────────────────

const _allKey = 'all';

const _categories = <({String key, String label})>[
  (key: _allKey, label: '全部'),
  (key: 'exam', label: '联考真题解析'),
  (key: 'top-works', label: '高分范画集'),
  (key: 'sketch', label: '素描教程'),
  (key: 'color', label: '色彩教程'),
  (key: 'speed', label: '速写教程'),
  (key: 'academy', label: '美院校考'),
  (key: 'history', label: '美术史与鉴赏'),
  (key: 'magazine', label: '期刊'),
];

bool _matches(_Book book, String category) =>
    category == _allKey || book.category == category;

/// 分类既接受 key，也接受中文名称（如「期刊」「素描教程」）。
String _normalizeCategory(String raw) {
  final value = raw.trim();
  for (final category in _categories) {
    if (category.key == value || category.label == value) {
      return category.key;
    }
  }
  return _allKey;
}

String _categoryLabel(String key) {
  for (final category in _categories) {
    if (category.key == key) {
      return category.label;
    }
  }
  return '';
}

// ── 书目 ────────────────────────────────────────────────────────────────

class _Book {
  const _Book({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.editor,
    required this.category,
    required this.subjects,
    required this.stage,
    required this.tags,
    required this.pageCount,
    required this.intro,
    required this.description,
    required this.toc,
    required this.publishDate,
    required this.baseReaders,
    required this.rank,
    this.publisher = '示范画室教研组（示例）',
    this.featuredIntro = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String editor;
  final String publisher;
  final String category;
  final List<String> subjects;

  /// 适用阶段：基础 / 提高 / 冲刺。
  final String stage;
  final List<String> tags;
  final int pageCount;

  /// 列表卡片上的一句话简介。
  final String intro;
  final String description;

  /// 目录：章节标题与起始页（与 `tool/ebooks/manifest.json` 一致）。
  final List<(String, int)> toc;
  final String publishDate;
  final int baseReaders;

  /// 「推荐」排序的位置。
  final int rank;

  /// 编辑推荐语；非空即进入「编辑推荐」。
  final String featuredIntro;

  String get coverRef => 'asset:assets/demo/ebooks/$id-cover.jpg';

  String pageRef(int page) =>
      'asset:assets/demo/ebooks/$id-p${page.toString().padLeft(2, '0')}.jpg';
}

const _books = <_Book>[
  _Book(
    id: 'eb-sketch-still',
    title: '联考素描静物高分解析（示例）',
    subtitle: '构图 · 明暗 · 质感 · 空间',
    editor: '张明远、李静',
    category: 'top-works',
    subjects: ['素描'],
    stage: '提高',
    tags: ['静物', '构图', '明暗', '质感'],
    pageCount: 12,
    intro: '拆解素描静物高分作品在构图、明暗、质感与空间上的共同做法。',
    description:
        '以联考素描静物为线索，按「整体—构图—明暗—透视—步骤—质感—空间」的顺序，'
        '结合画室范画逐页讲解高分作品的处理方法，并附常见问题与改法。',
    toc: [
      ('高分作品的共同点', 3),
      ('构图：让画面稳定饱满', 4),
      ('明暗：三大面与五大调子', 5),
      ('透视：静物里的近大远小', 6),
      ('步骤一：起稿与铺大关系', 7),
      ('步骤二：深入塑造与整体调整', 8),
      ('质感：陶罐、玻璃与衬布', 9),
      ('空间：前后与虚实', 10),
      ('对照：一张范画的六个细节', 11),
      ('附 · 常见问题与改法', 12),
    ],
    publishDate: '2026-09-15',
    baseReaders: 3860,
    rank: 1,
    featuredIntro: '一张范画拆成十个知识点，联考前系统梳理素描静物。',
  ),
  _Book(
    id: 'eb-color-warmcool',
    title: '色彩静物冷暖关系 30 讲（示例）',
    subtitle: '光源色 · 固有色 · 环境色',
    editor: '刘芳',
    category: 'color',
    subjects: ['色彩'],
    stage: '基础',
    tags: ['静物', '冷暖', '环境色', '色调'],
    pageCount: 10,
    intro: '从光源色、固有色、环境色讲起，讲清色彩静物里的冷暖关系（节选 8 讲）。',
    description:
        '从色彩三要素、色相环讲起，逐步讲清光源色、固有色、环境色与冷暖关系，'
        '配合静物范画对照练习。示例书刊收录其中 8 讲。',
    toc: [
      ('第 1 讲 · 色彩三要素：色相、明度、纯度', 3),
      ('第 2 讲 · 色相环与补色', 4),
      ('第 3 讲 · 物体的颜色从哪里来', 5),
      ('第 4 讲 · 冷暖是比较出来的', 6),
      ('第 5 讲 · 环境色：白布与陶罐的暗部', 7),
      ('第 6 讲 · 色调：先定调子再画细节', 8),
      ('第 7 讲 · 写生步骤与冷暖控制', 9),
      ('第 8 讲 · 常见问题：粉、脏、灰、花', 10),
    ],
    publishDate: '2026-08-20',
    baseReaders: 3120,
    rank: 2,
    featuredIntro: '用对照图把“冷暖”讲成看得见的规律，适合色彩入门。',
  ),
  _Book(
    id: 'eb-speed-figure',
    title: '人物速写动态与比例（示例）',
    subtitle: '动态线 · 重心 · 比例 · 衣纹',
    editor: '何佳、高峰',
    category: 'speed',
    subjects: ['速写'],
    stage: '基础',
    tags: ['人物', '动态', '比例', '衣纹'],
    pageCount: 10,
    intro: '从动态线和重心入手，配合「站七坐五盘三半」练好单人速写的基本功。',
    description:
        '以动态线、重心线和「站七坐五盘三半」为主线，讲解单人速写的观察方法、'
        '比例、体块、衣纹与线条组织。',
    toc: [
      ('速写的观察方法', 3),
      ('动态线与重心线', 4),
      ('比例口诀：站七坐五盘三半', 5),
      ('比例的细节', 6),
      ('三大体块：头、胸腔、骨盆', 7),
      ('衣纹：画在结构转折处', 8),
      ('单人速写步骤', 9),
      ('线条与黑白：让画面有节奏', 10),
    ],
    publishDate: '2026-07-10',
    baseReaders: 2740,
    rank: 6,
  ),
  _Book(
    id: 'eb-cast-head',
    title: '石膏头像结构入门（示例）',
    subtitle: '三庭五眼 · 骨点 · 体块 · 明暗',
    editor: '王海波',
    category: 'sketch',
    subjects: ['素描'],
    stage: '基础',
    tags: ['石膏像', '结构', '三庭五眼', '头像'],
    pageCount: 10,
    intro: '用三庭五眼和头部体块理解石膏像结构，按步骤完成一张石膏头像。',
    description:
        '从常见石膏像入手，讲解三庭五眼、五官位置、头部体块与骨点，'
        '并按起稿—铺明暗—深入调整的步骤完成一张石膏头像。',
    toc: [
      ('认识常见石膏像', 3),
      ('三庭五眼', 4),
      ('五官的位置关系', 5),
      ('头部的体块与透视', 6),
      ('骨点与结构', 7),
      ('起稿：长直线切形', 8),
      ('铺明暗：从交界线开始', 9),
      ('深入与调整', 10),
    ],
    publishDate: '2026-06-18',
    baseReaders: 2210,
    rank: 5,
  ),
  _Book(
    id: 'eb-exam-sketch',
    title: '联考真题与评分要点·素描（示例）',
    subtitle: '示例命题 · 评分维度 · 档次对照',
    editor: '陈立、张明远',
    category: 'exam',
    subjects: ['素描'],
    stage: '冲刺',
    tags: ['联考', '评分标准', 'A–E 档', '静物', '头像'],
    pageCount: 12,
    intro: '以示例命题梳理素描评分维度与 A–E 档次特征，附考场时间分配建议。',
    description:
        '以示例命题为例，梳理素描评分的主要维度与 A–E 档次特征，附档次对照、'
        '考场时间分配与考前自查清单。书中命题均为示例，非真实考题。',
    toc: [
      ('读懂考试说明', 3),
      ('示例命题一：素描静物', 4),
      ('示例命题二：人物头像', 5),
      ('评分维度一：构图与造型', 6),
      ('评分维度二：明暗、体积与空间', 7),
      ('评分维度三：质感、刻画与完整度', 8),
      ('A–E 档次特征', 9),
      ('档次对照：差在哪里', 10),
      ('考场时间分配', 11),
      ('常见失分点与考前自查', 12),
    ],
    publishDate: '2026-10-20',
    baseReaders: 4280,
    rank: 4,
  ),
  _Book(
    id: 'eb-academy-works',
    title: '美院校考作品集选编（示例）',
    subtitle: '素描 · 色彩 · 速写 · 创作',
    editor: '赵雪、朱琳',
    category: 'academy',
    subjects: ['素描', '色彩', '速写'],
    stage: '冲刺',
    tags: ['校考', '作品集', '创作', '点评'],
    pageCount: 10,
    intro: '画室学员校考方向的练习作品选编，逐幅附点评与作品集整理建议。',
    description:
        '选编画室学员校考方向的素描、色彩、速写与创作练习作品，逐幅附点评，'
        '并整理作品集的整理建议。',
    toc: [
      ('校考与联考有什么不同', 3),
      ('素描 · 长期头像', 4),
      ('素描 · 人物头像', 5),
      ('色彩 · 静物', 6),
      ('色彩 · 风景', 7),
      ('速写 · 组合与场景', 8),
      ('创作 · 命题构思示例', 9),
      ('作品集整理建议', 10),
    ],
    publishDate: '2026-09-28',
    baseReaders: 1650,
    rank: 8,
  ),
  _Book(
    id: 'eb-art-history',
    title: '中外美术简史图说（示例）',
    subtitle: '从彩陶到现代艺术的时间线',
    editor: '郑可',
    category: 'history',
    subjects: ['美术常识'],
    stage: '基础',
    tags: ['美术史', '鉴赏', '美术常识', '时间线'],
    pageCount: 12,
    intro: '用时间线串起中外美术史的代表作品与流派，附美术常识速记表。',
    description:
        '按时间线梳理中外美术史上的代表作品与流派，介绍「描述—分析—解释—评价」的'
        '鉴赏方法，附美术常识速记表。',
    toc: [
      ('怎样欣赏一件美术作品', 3),
      ('中国美术（一）：从彩陶到秦汉', 4),
      ('中国美术（二）：魏晋至隋唐', 5),
      ('中国美术（三）：五代两宋', 6),
      ('中国美术（四）：元明清与近现代', 7),
      ('西方美术（一）：古希腊与文艺复兴', 8),
      ('西方美术（二）：巴洛克至浪漫主义', 9),
      ('西方美术（三）：现实主义与印象派', 10),
      ('西方美术（四）：走向现代', 11),
      ('美术常识速记表', 12),
    ],
    publishDate: '2026-05-12',
    baseReaders: 1380,
    rank: 10,
  ),
  _Book(
    id: 'eb-monthly-202610',
    title: '画室月刊 2026 年 10 月号（示例）',
    subtitle: '秋季集训开篇 · 色彩高级灰',
    editor: '画室月刊编辑部',
    publisher: '示范画室 编印（示例）',
    category: 'magazine',
    subjects: ['素描', '色彩', '速写'],
    stage: '提高',
    tags: ['月刊', '集训', '高级灰', '学员作品'],
    pageCount: 9,
    intro: '秋季集训特辑：一周练习安排、色彩高级灰、坐姿速写与学员作品展。',
    description:
        '本期聚焦秋季集训：一周练习安排、高分作品赏析、色彩高级灰的调法、'
        '坐姿速写要点、学员作品展与铅笔的选用。',
    toc: [
      ('卷首语', 1),
      ('本月话题 · 一周练习怎么排', 3),
      ('高分作品赏析 · 《陶罐与水果衬布》', 4),
      ('名师课堂 · 色彩里的“高级灰”', 5),
      ('速写一页通 · 坐姿', 6),
      ('学员作品展 · 本月优秀作业（示例）', 7),
      ('工具角 · 铅笔的软与硬', 8),
      ('画室日历 · 十月', 9),
    ],
    publishDate: '2026-10-01',
    baseReaders: 1960,
    rank: 9,
  ),
  _Book(
    id: 'eb-monthly-202611',
    title: '画室月刊 2026 年 11 月号（示例）',
    subtitle: '考前查漏补缺 · 场景速写透视',
    editor: '画室月刊编辑部',
    publisher: '示范画室 编印（示例）',
    category: 'magazine',
    subjects: ['素描', '色彩', '速写'],
    stage: '冲刺',
    tags: ['月刊', '查漏补缺', '场景速写', '考场须知'],
    pageCount: 9,
    intro: '考前一个月特辑：查漏补缺清单、场景速写透视、默写训练与考场须知。',
    description:
        '本期聚焦考前一个月：查漏补缺清单、色彩高分卷解读、场景速写的透视、'
        '默写训练、考场须知与状态调整。',
    toc: [
      ('卷首语', 1),
      ('本月话题 · 考前查漏补缺清单', 3),
      ('高分卷解读 · 色彩静物', 4),
      ('名师课堂 · 场景速写的透视', 5),
      ('默写训练 · 把常画的物体画熟', 6),
      ('示范作品展 · 画室老师示范（示例）', 7),
      ('考场须知 · 考前准备清单（示例）', 8),
      ('编读往来 · 保持状态的几个小习惯', 9),
    ],
    publishDate: '2026-11-01',
    baseReaders: 2480,
    rank: 3,
    featuredIntro: '考前一个月的查漏补缺清单与考场须知，帮你把节奏放稳。',
  ),
  _Book(
    id: 'eb-color-landscape',
    title: '色彩风景写生技法（示例）',
    subtitle: '取景 · 空间 · 天空 · 树与水',
    editor: '孙磊',
    category: 'color',
    subjects: ['色彩'],
    stage: '提高',
    tags: ['风景', '写生', '空间', '色彩透视'],
    pageCount: 10,
    intro: '从取景构图到空间层次，讲解天空、树木、建筑与水面的写生方法。',
    description:
        '围绕户外写生，讲解取景构图、色彩透视与空间层次，'
        '以及天空、树木、建筑、水面的表现方法和写生步骤。',
    toc: [
      ('写生前的准备与取景', 3),
      ('构图：地平线与视觉中心', 4),
      ('空间：近景、中景、远景', 5),
      ('天空与云', 6),
      ('树木：先画大形再画枝叶', 7),
      ('建筑与地面', 8),
      ('水面与倒影', 9),
      ('写生步骤小结', 10),
    ],
    publishDate: '2026-08-05',
    baseReaders: 1720,
    rank: 7,
  ),
];

_Book _findBook(String id) {
  for (final book in _books) {
    if (book.id == id) {
      return book;
    }
  }
  throw const DemoApiException('书刊不存在或已下架', code: 404);
}

/// 相关书刊：同分类优先，其次科目重合，再按阅读量。
List<_Book> _relatedOf(_Book book, Map<String, dynamic> reads) {
  int score(_Book other) =>
      (other.category == book.category ? 4 : 0) +
      other.subjects.where(book.subjects.contains).length;
  final others = _books.where((b) => b.id != book.id).toList()
    ..sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      return byScore != 0
          ? byScore
          : _readersOf(b, reads).compareTo(_readersOf(a, reads));
    });
  return others.take(4).toList();
}

// ── 用户状态 ────────────────────────────────────────────────────────────

const _readsKey = 'ebooks:reads';
const _seededKey = 'ebooks:seeded';

String _progressKey(String userId) => 'ebooks:progress:$userId';

String _bookmarksKey(String userId) => 'ebooks:bookmarks:$userId';

String _userOf(DemoRequest req) {
  final userId = req.account.userId;
  ensureDemoEbookSeeds(userId);
  return userId;
}

/// 首次访问时为账号预置两本书刊收藏，让书架与「我的收藏」有内容；
/// 「我的收藏」的演示数据也可以在预置时调用它。
void ensureDemoEbookSeeds(String userId) {
  final seeded = DemoStore.map(_seededKey, () => <String, dynamic>{});
  if (seeded[userId] == true) {
    return;
  }
  for (final id in const ['eb-monthly-202611', 'eb-color-warmcool']) {
    if (!DemoFavorites.contains(userId, kDemoEbookFavoriteType, id)) {
      _setFavorite(userId, _findBook(id), true);
    }
  }
  seeded[userId] = true;
  DemoStore.save(_seededKey);
}

/// 每个账号预置三条阅读记录：两本在读、一本已读完。
Map<String, dynamic> _progressStore(String userId) =>
    DemoStore.map(_progressKey(userId), () {
      return <String, dynamic>{
        'eb-sketch-still': <String, dynamic>{
          'page': 5,
          'updatedAt': '2026-11-06 20:15:00',
        },
        'eb-speed-figure': <String, dynamic>{
          'page': 3,
          'updatedAt': '2026-11-05 21:40:00',
        },
        'eb-monthly-202610': <String, dynamic>{
          'page': 9,
          'updatedAt': '2026-10-28 19:05:00',
        },
      };
    });

Map<String, dynamic> _bookmarkStore(String userId) =>
    DemoStore.map(_bookmarksKey(userId), () {
      return <String, dynamic>{
        'eb-sketch-still': <int>[5, 11],
      };
    });

List<int> _bookmarksOf(String userId, String bookId) {
  final raw = _bookmarkStore(userId)[bookId];
  if (raw is! List) {
    return const <int>[];
  }
  return [for (final item in raw) _toInt(item)]..sort();
}

Map<String, dynamic> _readStore() =>
    DemoStore.map(_readsKey, () => <String, dynamic>{});

int _readersOf(_Book book, Map<String, dynamic> reads) =>
    book.baseReaders + _toInt(reads[book.id]);

void _setFavorite(String userId, _Book book, bool favorite) {
  DemoFavorites.set(
    userId,
    type: kDemoEbookFavoriteType,
    targetId: book.id,
    favorite: favorite,
    title: book.title,
    cover: book.coverRef,
    subtitle: '${_categoryLabel(book.category)} · ${book.editor}',
    payload: <String, dynamic>{
      'bookId': book.id,
      'title': book.title,
      'editor': book.editor,
      'categoryLabel': _categoryLabel(book.category),
      'pageCount': book.pageCount,
      'cover': book.coverRef,
    },
  );
}

// ── 序列化 ──────────────────────────────────────────────────────────────

Map<String, dynamic> _summaryJson(
  _Book book,
  String userId,
  Map<String, dynamic> reads,
) {
  final saved = _progressStore(userId)[book.id];
  return <String, dynamic>{
    'id': book.id,
    'title': book.title,
    'subtitle': book.subtitle,
    'editor': book.editor,
    'publisher': book.publisher,
    'category': book.category,
    'categoryLabel': _categoryLabel(book.category),
    'subjects': book.subjects,
    'stage': book.stage,
    'tags': book.tags,
    'pageCount': book.pageCount,
    'coverUrl': DemoMedia.url(book.coverRef),
    'intro': book.intro,
    'featuredIntro': book.featuredIntro,
    'publishDate': book.publishDate,
    'readers': _readersOf(book, reads),
    'sample': true,
    'favorite': DemoFavorites.contains(
      userId,
      kDemoEbookFavoriteType,
      book.id,
    ),
    'progress': saved is Map
        ? <String, dynamic>{
            'page': _toInt(saved['page']),
            'updatedAt': saved['updatedAt'],
          }
        : null,
  };
}

int _toInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _now() {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)} '
      '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
}
