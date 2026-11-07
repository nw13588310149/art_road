import '../data/demo_favorites.dart';
import '../data/demo_marking_data.dart';
import '../demo_backend.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';

/// 范画库演示接口（阅卷客户端）：名师范画（作者均为画室在册老师）与学生优秀作品取自演示画作，
/// 联考高分卷取自阅卷演示数据中最近一场已出分月考（9 月）的各科最高分，与学情中心同源。
void registerMarkingGalleryFixtures(DemoRouter marking) {
  marking.get('/app/gallery/categories', (req) {
    final subject = _normalizeSubject(req.str('subject'));
    final works = _galleryWorks();
    return [
      for (final category in _categories)
        <String, dynamic>{
          'key': category.key,
          'label': category.label,
          'subject': category.subject,
          'count': works
              .where(
                (w) =>
                    _matchesCategory(w, category.key) &&
                    (subject.isEmpty || w.subject == subject),
              )
              .length,
        },
    ];
  });

  marking.get('/app/gallery/works', (req) {
    final category = _normalizeCategory(req.str('category'));
    final subject = _normalizeSubject(req.str('subject'));
    final views = _viewStore();
    var list = _galleryWorks()
        .where(
          (w) =>
              _matchesCategory(w, category) &&
              (subject.isEmpty || w.subject == subject),
        )
        .toList();
    list = demoSearch(
      list,
      req.str('keyword'),
      (w) => [
        w.title,
        w.author,
        ...w.tags,
        ...w.points,
        w.subject,
        w.categoryLabel,
        w.examName,
      ],
    );
    switch (req.str('sort', 'latest')) {
      case 'score':
        list.sort((a, b) {
          final byScore = (b.score ?? -1).compareTo(a.score ?? -1);
          return byScore != 0 ? byScore : b.createTime.compareTo(a.createTime);
        });
      case 'popular':
        list.sort((a, b) => _viewsOf(b, views).compareTo(_viewsOf(a, views)));
      default:
        list.sort((a, b) => b.createTime.compareTo(a.createTime));
    }
    final userId = req.account.userId;
    return demoPage([for (final w in list) _workJson(w, userId, views)], req);
  });

  marking.get('/app/gallery/works/{id}', (req) {
    final work = _findWork(req.param('id'));
    final views = _viewStore();
    views[work.id] = ((views[work.id] as num?)?.toInt() ?? 0) + 1;
    DemoStore.save(_viewsKey);
    final related =
        _galleryWorks()
            .where((w) => w.id != work.id && w.subject == work.subject)
            .toList()
          ..sort((a, b) {
            final aSame = a.category == work.category ? 0 : 1;
            final bSame = b.category == work.category ? 0 : 1;
            if (aSame != bSame) {
              return aSame - bSame;
            }
            return _viewsOf(b, views).compareTo(_viewsOf(a, views));
          });
    final userId = req.account.userId;
    return <String, dynamic>{
      ..._workJson(work, userId, views),
      'description': '${work.intro}\n\n${_studyTips[work.category] ?? ''}'
          .trim(),
      'related': [for (final w in related.take(4)) _workJson(w, userId, views)],
    };
  });

  marking.post('/app/gallery/works/{id}/favorite', (req) {
    final work = _findWork(req.param('id'));
    final favorite = req.boolOf('favorite', true);
    DemoFavorites.set(
      req.account.userId,
      type: DemoFavorites.typeGallery,
      targetId: work.id,
      favorite: favorite,
      title: work.title,
      cover: work.imageRef,
      subtitle: work.score == null
          ? '${work.source} · ${work.author}'
          : '${work.source} · ${work.author} · ${_scoreText(work.score!)} 分',
      payload: <String, dynamic>{
        'subject': work.subject,
        'imageUrl': work.imageRef,
      },
    );
    return <String, dynamic>{'favorite': favorite};
  });
}

// ── 分类 ────────────────────────────────────────────────────────────────

class _Category {
  const _Category(this.key, this.label, this.subject);

  final String key;
  final String label;
  final String? subject;
}

const _allKey = 'all';
const _examKey = 'exam-top';

const _categories = <_Category>[
  _Category(_allKey, '全部', null),
  _Category('sketch-cast', '素描 · 石膏', '素描'),
  _Category('sketch-still', '素描 · 静物', '素描'),
  _Category('sketch-head', '素描 · 头像', '素描'),
  _Category('color-still', '色彩 · 静物', '色彩'),
  _Category('color-landscape', '色彩 · 风景', '色彩'),
  _Category('speed-single', '速写 · 单人', '速写'),
  _Category('speed-group', '速写 · 组合场景', '速写'),
  _Category(_examKey, '联考高分卷', null),
];

const _sourceMaster = '名师范画';
const _sourceExam = '联考高分卷';
const _sourceStudent = '学生优秀作品';

/// 分类既接受 key，也接受中文名称（如「联考高分卷」「素描·石膏」）。
String _normalizeCategory(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return _allKey;
  }
  final compact = value.replaceAll('·', '').replaceAll(' ', '');
  for (final category in _categories) {
    if (category.key == value ||
        category.label == value ||
        category.label.replaceAll('·', '') == compact) {
      return category.key;
    }
  }
  return _allKey;
}

String _normalizeSubject(String raw) => switch (raw.trim()) {
  '素描' || 'sketch' => '素描',
  '色彩' || 'color' => '色彩',
  '速写' || 'speed' => '速写',
  _ => '',
};

bool _matchesCategory(_Work work, String category) => switch (category) {
  _allKey => true,
  _examKey => work.source == _sourceExam,
  _ => work.category == category,
};

String _categoryLabel(String key) {
  for (final category in _categories) {
    if (category.key == key) {
      return category.label;
    }
  }
  return '';
}

const _studyTips = <String, String>{
  'sketch-cast':
      '临摹建议：先用长直线切出外轮廓与中轴线，确定头、颈、胸的转向；再沿明暗交界线铺出暗部，最后从五官与骨点处深入，始终保持整体。',
  'sketch-still': '临摹建议：先确定主体物在画面中的位置与大小，再处理物体之间的前后遮挡；排线随形体结构走，质感区分留到最后一遍深入。',
  'sketch-head': '临摹建议：抓住三庭五眼与头部转向，先找骨点再画肌肉；局部刻画时随时退后观察整体，避免把画面画「花」。',
  'color-still': '临摹建议：先定整体色调，用大笔铺出背景、衬布与主体的冷暖关系；塑造时注意亮部与暗部的冷暖对比要统一。',
  'color-landscape': '临摹建议：按天空、远景、中景、近景的顺序铺色，远处偏冷偏灰、近处偏暖偏纯，用冷暖与纯度拉开空间。',
  'speed-single': '临摹建议：先找动态线与重心，再用长线概括躯干与四肢的方向，衣纹只画结构转折处，控制在 10–15 分钟内完成。',
  'speed-group': '临摹建议：先安排人物的主次与前后遮挡，再统一透视与地平线；背景线条做减法，用疏密对比突出主体。',
  _examKey: '高分卷代表阅卷老师认可的完成度与画面效果。建议对照评分标准，重点观察构图、整体关系与主体刻画的取舍。',
};

// ── 作品 ────────────────────────────────────────────────────────────────

class _Work {
  const _Work({
    required this.id,
    required this.title,
    required this.subject,
    required this.category,
    required this.source,
    required this.author,
    required this.authorTitle,
    required this.image,
    required this.tags,
    required this.points,
    required this.intro,
    required this.createTime,
    required this.baseViews,
    this.score,
    this.grade = '',
    this.examName = '',
  });

  final String id;
  final String title;
  final String subject;
  final String category;
  final String source;
  final String author;
  final String authorTitle;

  /// 资源路径（`assets/demo/...`）。
  final String image;
  final List<String> tags;
  final List<String> points;
  final String intro;
  final String createTime;
  final int baseViews;
  final double? score;
  final String grade;
  final String examName;

  String get imageRef => 'asset:$image';

  String get categoryLabel => source == _sourceExam
      ? _categoryLabel(_examKey)
      : _categoryLabel(category);
}

class _Seed {
  const _Seed({
    required this.id,
    required this.image,
    required this.title,
    required this.category,
    required this.tags,
    required this.points,
    required this.intro,
    required this.date,
    this.author = '',
    this.studentIndex,
  });

  final String id;
  final String image;
  final String title;
  final String category;
  final List<String> tags;
  final List<String> points;
  final String intro;
  final String date;

  /// 名师范画的作者；学生作品留空，由 [studentIndex] 取演示学生姓名。
  final String author;
  final int? studentIndex;
}

const _seeds = <_Seed>[
  _Seed(
    id: '7101',
    image: 'assets/demo/art/sketch-bust-1.jpg',
    title: '大卫石膏像 · 侧转头像',
    category: 'sketch-cast',
    author: '张明远',
    tags: ['结构', '明暗', '体块', '石膏像'],
    points: [
      '头、颈、胸三大体块的转向关系明确，动势自然',
      '卷发按体块归纳成组，疏密有节奏，不琐碎',
      '明暗交界线肯定，暗部透气、反光克制',
      '眉弓、颧骨、下颌角等骨点结构交代清楚',
    ],
    intro: '大卫像头部向左侧转，颈部胸锁乳突肌拉伸明显，是练习头颈肩转折关系的经典角度。',
    date: '2026-10-28',
  ),
  _Seed(
    id: '7102',
    image: 'assets/demo/art/sketch-bust-2.jpg',
    title: '荷马石膏像 · 长期作业',
    category: 'sketch-cast',
    author: '李静',
    tags: ['明暗', '色调', '结构', '石膏像'],
    points: [
      '整体色调沉稳，黑白灰层次拉得开',
      '胡须与卷发成组塑造，避免平均刻画',
      '额头横纹与眉弓骨点的起伏刻画细腻',
      '背光面统一成大块暗部，画面整体感强',
    ],
    intro: '荷马像面部结构起伏大、胡须体积丰富，适合练习长期作业中的深入刻画与整体控制。',
    date: '2026-10-12',
  ),
  _Seed(
    id: '7103',
    image: 'assets/demo/art/sketch-geometry-1.jpg',
    title: '石膏几何体组合',
    category: 'sketch-cast',
    author: '张明远',
    tags: ['透视', '结构', '明暗', '构图', '几何体'],
    points: [
      '立方体、圆柱的透视统一，近大远小准确',
      '球体明暗五大调子完整，过渡柔和',
      '投影方向一致，投影边缘近实远虚',
      '四个形体前后错落，构图稳定有变化',
    ],
    intro: '立方体、圆锥、球体、圆柱四种基本形体的组合，是理解透视与明暗规律的入门必画。',
    date: '2026-08-30',
  ),
  _Seed(
    id: '7128',
    image: 'assets/demo/art/sketch-bust-3.jpg',
    title: '维纳斯石膏像 · 线性起稿',
    category: 'sketch-cast',
    author: '李静',
    tags: ['结构', '线条', '构图', '起稿'],
    points: [
      '三庭五眼比例准确，中轴线清晰',
      '用线轻松肯定，轮廓虚实有变化',
      '先定大形再分体块，起稿步骤规范',
      '发髻按组概括，为后续铺调子打好基础',
    ],
    intro: '起稿阶段示范：只用线条确定比例与结构，是长期作业前最关键的一步。',
    date: '2026-07-18',
  ),
  _Seed(
    id: '7104',
    image: 'assets/demo/art/sketch-portrait-1.jpg',
    title: '女青年头像 · 四分之三侧面',
    category: 'sketch-head',
    author: '张明远',
    tags: ['结构', '明暗', '虚实', '头像'],
    points: [
      '头部转向与颈部动势协调，重心稳定',
      '鼻梁、眼窝、颧骨的结构转折交代清楚',
      '背景局部压暗衬托受光面，主次分明',
      '发丝按体块组织，边缘虚实变化丰富',
    ],
    intro: '四分之三侧面能同时看到正面与侧面的结构，是头像写生中最常考、也最考验造型的角度。',
    date: '2026-10-20',
  ),
  _Seed(
    id: '7105',
    image: 'assets/demo/art/detail-sketch.jpg',
    title: '五官局部 · 眼睛深入刻画',
    category: 'sketch-head',
    author: '李静',
    tags: ['结构', '线条', '明暗', '五官', '局部'],
    points: [
      '眼球体积感强，高光位置与光源一致',
      '上眼睑的厚度与投影交代到位',
      '眉毛顺着生长方向排线，疏密自然',
      '局部深入但不脱离眼眶整体结构',
    ],
    intro: '五官局部放大示范，重点看眼睑厚度、眼球体积与眉毛的排线方法。',
    date: '2026-09-18',
  ),
  _Seed(
    id: '7106',
    image: 'assets/demo/art/sketch-still-1.jpg',
    title: '陶罐与水果衬布',
    category: 'sketch-still',
    author: '李静',
    tags: ['构图', '线条', '质感', '静物'],
    points: [
      '主体陶罐位于视觉中心，构图稳定饱满',
      '衬布褶皱穿插关系清楚，有主有次',
      '排线方向随形体转折，体积感明确',
      '苹果与梨的质感区分明确',
    ],
    intro: '典型的联考素描静物组合，陶罐、水果与衬布三类质感齐全，适合练习完整的作画步骤。',
    date: '2026-09-26',
  ),
  _Seed(
    id: '7107',
    image: 'assets/demo/art/sketch-still-2.jpg',
    title: '酒瓶、陶碗与洋葱 · 重调子',
    category: 'sketch-still',
    author: '张明远',
    tags: ['色调', '明暗', '质感', '透视', '静物'],
    points: [
      '深色背景衬托主体，画面色调浓郁统一',
      '玻璃瓶的反光与通透感表现到位',
      '陶碗的粗糙质感与洋葱纹理对比鲜明',
      '条纹衬布随结构起伏，透视准确',
    ],
    intro: '重调子画法的长期作业示范：用深背景压住画面，以黑白灰对比突出不同物体的质感。',
    date: '2026-10-05',
  ),
  _Seed(
    id: '7108',
    image: 'assets/demo/art/sketch-still-3.jpg',
    title: '陶罐、玻璃瓶与苹果',
    category: 'sketch-still',
    studentIndex: 6,
    tags: ['透视', '构图', '明暗', '质感'],
    points: [
      '桌面透视与台面边缘关系准确',
      '玻璃瓶透明质感处理轻松',
      '衬布大褶皱概括，小褶皱取舍得当',
      '整体灰调统一，可再加强前后虚实',
    ],
    intro: '学生课堂作业（3 小时），整体关系完整，被评为本月素描优秀作业。',
    date: '2026-10-14',
  ),
  _Seed(
    id: '7111',
    image: 'assets/demo/art/color-still-1.jpg',
    title: '陶罐水果与蓝白衬布',
    category: 'color-still',
    author: '刘芳',
    tags: ['色调', '冷暖', '笔触', '静物'],
    points: [
      '蓝白衬布与深暖背景冷暖对比强烈，色调明确',
      '笔触方向随形体走，塑造感强',
      '陶罐高光与环境色相互呼应',
      '白布亮部提得足，暗部有冷暖变化',
    ],
    intro: '深暖背景配蓝白衬布的经典色调组合，示范如何用冷暖对比组织画面。',
    date: '2026-09-11',
  ),
  _Seed(
    id: '7112',
    image: 'assets/demo/art/color-still-2.jpg',
    title: '暖黄调静物 · 陶罐与果盘',
    category: 'color-still',
    author: '王海波',
    tags: ['色调', '冷暖', '构图', '静物'],
    points: [
      '暖黄背景统一画面色调',
      '苹果、橙子固有色饱和但不跳',
      '灰蓝衬布与暖背景形成冷暖呼应',
      '果盘受光面与暗部的冷暖变化细腻',
    ],
    intro: '以暖黄为主调的静物示范，重点看主体水果与衬布之间的冷暖呼应。',
    date: '2026-09-14',
  ),
  _Seed(
    id: '7113',
    image: 'assets/demo/art/color-still-3.jpg',
    title: '灰调静物 · 高级灰练习',
    category: 'color-still',
    studentIndex: 15,
    tags: ['色调', '冷暖', '色彩关系'],
    points: ['整体灰调和谐，纯度控制得当', '水果作为纯色点缀，主次分明', '白布受光面偏暖、暗部偏冷', '笔触平整，可再加强体积塑造'],
    intro: '学生色彩周练作品，灰调把握准确，适合对照学习纯度的控制方法。',
    date: '2026-09-29',
  ),
  _Seed(
    id: '7114',
    image: 'assets/demo/art/color-still-4.jpg',
    title: '蓝调静物 · 冷色背景',
    category: 'color-still',
    author: '刘芳',
    tags: ['冷暖', '色调', '空间', '静物'],
    points: [
      '蓝紫背景营造冷调，橙色水果形成补色对比',
      '陶罐暗部融入环境色，不孤立',
      '白衬布亮部笔触大胆概括',
      '空间层次由前到后逐渐减弱',
    ],
    intro: '冷色调静物示范：在蓝紫环境中用橙色水果制造视觉中心。',
    date: '2026-08-22',
  ),
  _Seed(
    id: '7115',
    image: 'assets/demo/art/color-flower-1.jpg',
    title: '菊花与橙子 · 花卉静物',
    category: 'color-still',
    author: '王海波',
    tags: ['构图', '冷暖', '色调', '花卉'],
    points: [
      '花头疏密聚散有致，构图生动',
      '蓝玻璃瓶的透明感与环境色表现到位',
      '白菊暗部用冷紫灰，避免直接加黑',
      '条纹衬布引导视线，画面饱满',
    ],
    intro: '花卉静物示范，重点看白花暗部的冷暖处理与花头的疏密组织。',
    date: '2026-07-30',
  ),
  _Seed(
    id: '7116',
    image: 'assets/demo/art/color-still-5.jpg',
    title: '浅灰调静物写生',
    category: 'color-still',
    studentIndex: 9,
    tags: ['色调', '笔触', '构图'],
    points: ['留白背景轻松透气，色调明确', '红苹果暗部色彩饱满，不脏不闷', '白盘中的环境色反射丰富', '衬布笔触概括，可再拉开冷暖'],
    intro: '学生写生作品（2.5 小时），色彩干净，入选本月色彩优秀作业。',
    date: '2026-11-02',
  ),
  _Seed(
    id: '7117',
    image: 'assets/demo/art/detail-color.jpg',
    title: '橙子局部 · 笔触塑造',
    category: 'color-still',
    author: '刘芳',
    tags: ['笔触', '冷暖', '局部', '色彩关系'],
    points: [
      '笔触随球体结构排列，体积感强',
      '亮部暖黄、暗部橙红，冷暖过渡自然',
      '盘中投影的蓝灰色与橙子形成补色关系',
      '厚涂技法干净利落，适合临摹学习',
    ],
    intro: '水果局部放大示范，专门演示厚涂笔触如何顺着形体塑造体积。',
    date: '2026-09-08',
  ),
  _Seed(
    id: '7118',
    image: 'assets/demo/art/color-landscape-1.jpg',
    title: '秋日村落 · 白杨与远山',
    category: 'color-landscape',
    author: '王海波',
    tags: ['色调', '冷暖', '空间', '构图', '透视', '风景'],
    points: [
      '近景土墙暖黄、远山蓝紫，色彩推远空间',
      '白杨树高低错落，构图有节奏',
      '天空云层松动，与地面形成虚实对比',
      '整体色调明快统一，季节感强',
    ],
    intro: '西北秋季村落写生示范，用冷暖对比表现大空间，是风景色彩的典型构图。',
    date: '2026-10-16',
  ),
  _Seed(
    id: '7121',
    image: 'assets/demo/art/speed-figure-2.jpg',
    title: '坐姿读书',
    category: 'speed-single',
    studentIndex: 12,
    tags: ['动态', '透视', '结构', '线条'],
    points: ['坐姿重心稳定，凳子透视准确', '手部与书本的关系交代清楚', '腿部衣纹随结构起伏', '排线概括暗部，画面黑白分明'],
    intro: '学生速写课堂作业（15 分钟），坐姿动态准确，入选本周速写优秀作业。',
    date: '2026-10-24',
  ),
  _Seed(
    id: '7122',
    image: 'assets/demo/art/speed-figure-1.jpg',
    title: '插兜站立 · 男青年',
    category: 'speed-single',
    author: '赵雪',
    tags: ['动态', '线条', '比例', '衣纹'],
    points: [
      '重心落在支撑腿上，站姿自然放松',
      '外套衣纹概括，肩、肘结构点清晰',
      '线条松弛有力，长短线结合',
      '头身比例准确，动态线明确',
    ],
    intro: '单人站姿速写示范，重点看重心与衣纹的概括方式。',
    date: '2026-10-08',
  ),
  _Seed(
    id: '7123',
    image: 'assets/demo/art/speed-figure-5.jpg',
    title: '蹲姿系鞋带',
    category: 'speed-single',
    author: '周强',
    tags: ['动态', '透视', '线条', '明暗'],
    points: ['强烈的透视缩短处理到位', '肩背弧线与手部动作连贯', '重色压住鞋与暗部，节奏感强', '线条奔放但结构不乱'],
    intro: '蹲姿是速写考试中的难点动态，示范如何处理肢体的透视缩短。',
    date: '2026-09-22',
  ),
  _Seed(
    id: '7124',
    image: 'assets/demo/art/speed-figure-3.jpg',
    title: '街头相遇 · 双人组合',
    category: 'speed-group',
    author: '赵雪',
    tags: ['动态', '构图', '透视', '组合'],
    points: ['两人呼应关系明确，画面有情节', '行走动态步伐交错，节奏自然', '背景线条简化，主次分明', '地面透视线统一画面空间'],
    intro: '双人组合速写示范，用人物间的呼应与地面透视组织画面。',
    date: '2026-10-02',
  ),
  _Seed(
    id: '7125',
    image: 'assets/demo/art/speed-figure-4.jpg',
    title: '集市买卖 · 三人组合',
    category: 'speed-group',
    author: '周强',
    tags: ['构图', '透视', '动态', '组合'],
    points: ['人物高低错落，组合关系紧凑', '箩筐、货箱透视准确', '人物与道具的前后遮挡清楚', '手部动作与情节呼应'],
    intro: '三人组合加道具的命题速写示范，适合练习情节性画面的组织。',
    date: '2026-08-26',
  ),
  _Seed(
    id: '7126',
    image: 'assets/demo/art/speed-group-1.jpg',
    title: '课间 · 教室三人场景',
    category: 'speed-group',
    author: '赵雪',
    tags: ['构图', '透视', '比例', '场景'],
    points: ['三人姿态各异，避免雷同', '课桌椅透视统一，空间合理', '人物与环境比例协调', '线条疏密对比突出主体'],
    intro: '校园生活场景速写示范，联考常见「课间」类命题。',
    date: '2026-10-22',
  ),
  _Seed(
    id: '7127',
    image: 'assets/demo/art/speed-scene-1.jpg',
    title: '老街集市 · 场景速写',
    category: 'speed-group',
    author: '赵雪',
    tags: ['透视', '构图', '场景', '明暗'],
    points: ['一点透视街道纵深感强', '人物大小随距离变化，比例准确', '近景人物刻画充分、远景概括', '黑白灰布局合理，画面完整'],
    intro: '大场景速写示范：先定透视与地平线，再安排近、中、远三层人物。',
    date: '2026-11-04',
  ),
];

/// 演示图片宽高比（宽 / 高）。
const _aspects = <String, double>{
  'assets/demo/art/sketch-bust-1.jpg': 729 / 1017,
  'assets/demo/art/sketch-bust-2.jpg': 0.75,
  'assets/demo/art/sketch-bust-3.jpg': 0.75,
  'assets/demo/art/sketch-geometry-1.jpg': 0.75,
  'assets/demo/art/sketch-portrait-1.jpg': 0.75,
  'assets/demo/art/speed-figure-1.jpg': 0.75,
  'assets/demo/art/speed-figure-2.jpg': 0.75,
  'assets/demo/art/speed-figure-5.jpg': 0.75,
  'assets/demo/art/detail-sketch.jpg': 1,
  'assets/demo/art/detail-color.jpg': 1,
  'assets/demo/papers/sketch.jpg': 1200 / 860,
  'assets/demo/papers/color.jpg': 1200 / 860,
  'assets/demo/papers/speed.jpg': 1200 / 860,
};

double _aspectOf(String image) => _aspects[image] ?? 4 / 3;

String _subjectOfCategory(String category) {
  if (category.startsWith('sketch')) {
    return '素描';
  }
  if (category.startsWith('color')) {
    return '色彩';
  }
  return '速写';
}

/// 学生姓名脱敏：林小雨 → 林*雨。
String _maskName(String name) {
  final chars = name.trim().runes.map(String.fromCharCode).toList();
  if (chars.length <= 1) {
    return name;
  }
  if (chars.length == 2) {
    return '${chars.first}*';
  }
  return '${chars.first}${'*' * (chars.length - 2)}${chars.last}';
}

/// 演示浏览量：按来源给出不同量级（高分卷 > 名师范画 > 学生作品），同来源内按 id 打散。
int _baseViewsOf(String id, String source) {
  var hash = 0x811C9DC5;
  for (final unit in id.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  final spread = (hash % 1000) / 1000;
  final (low, high) = switch (source) {
    _sourceExam => (3200, 12800),
    _sourceStudent => (180, 1600),
    _ => (860, 7200),
  };
  return low + ((high - low) * spread * spread).round();
}

String _two(int value) => value.toString().padLeft(2, '0');

String _scoreText(double score) => score == score.roundToDouble()
    ? score.toStringAsFixed(0)
    : score.toStringAsFixed(1);

List<_Work>? _cache;

/// 高分卷用的是学生原卷图；与之重复的范画不再同时出现，同一页不会有两张一样的图。
List<_Work> _galleryWorks() => _cache ??= () {
  final examTop = _examTopWorks();
  final used = {for (final work in examTop) work.image};
  return [
    for (final seed in _seeds)
      if (!used.contains(seed.image)) _workFromSeed(seed),
    ...examTop,
  ];
}();

_Work _workFromSeed(_Seed seed) {
  final subject = _subjectOfCategory(seed.category);
  final studentIndex = seed.studentIndex;
  final student = studentIndex == null
      ? null
      : DemoMarkingData.instance.person(studentIndex);
  final hour = 8 + int.parse(seed.id) % 10;
  final source = student == null ? _sourceMaster : _sourceStudent;
  return _Work(
    id: seed.id,
    title: seed.title,
    subject: subject,
    category: seed.category,
    source: source,
    author: student == null ? seed.author : _maskName(student.name),
    authorTitle: student == null
        ? '${DemoMarkingData.schoolName} · $subject'
        : student.organizationName,
    image: seed.image,
    tags: seed.tags,
    points: seed.points,
    intro: seed.intro,
    createTime: '${seed.date} ${_two(hour)}:30:00',
    baseViews: _baseViewsOf(seed.id, source),
  );
}

const _examTags = <String, List<String>>{
  '素描': ['结构', '明暗', '构图', '高分卷'],
  '色彩': ['色调', '冷暖', '构图', '高分卷'],
  '速写': ['动态', '线条', '比例', '高分卷'],
};

/// 最近一场已出分月考（9 月）每科最高分各一份。
List<_Work> _examTopWorks() {
  final data = DemoMarkingData.instance;
  final works = <_Work>[];
  for (final examId in const ['26']) {
    final exam = data.exam(examId);
    if (exam == null || !exam.reviewed) {
      continue;
    }
    final scored = data.entriesOfExam(examId).where((e) => e.scored).toList();
    for (var k = 0; k < exam.subjects.length; k++) {
      final def = exam.subjects[k];
      DemoExamEntry? best;
      DemoSubjectScore? bestScore;
      for (final entry in scored) {
        final s = entry.subject(def.subjectId);
        if (s != null && (bestScore == null || s.score > bestScore.score)) {
          best = entry;
          bestScore = s;
        }
      }
      if (best == null || bestScore == null) {
        continue;
      }
      final person = best.person;
      final subject = def.subjectName;
      final grade = bestScore.grade;
      final band = DemoMarkingData.bands(
        subject,
        def.fullScore,
      ).where((b) => b.grade == grade).firstOrNull;
      final comments = bestScore.result.comments.isNotEmpty
          ? bestScore.result.comments
          : [
              for (var j = 0; j < 2; j++)
                DemoMarkingData.commentFor(subject, person.index, j),
            ];
      final paperRef = DemoMarkingData.paperRef(subject, person.index, examId);
      final image = paperRef.startsWith('asset:')
          ? paperRef.substring('asset:'.length)
          : paperRef;
      final published = DateTime.parse(
        exam.examDate,
      ).add(const Duration(days: 3));
      final score = bestScore.score;
      works.add(
        _Work(
          id: '73$examId${k + 1}',
          title: '${exam.examName} · $subject高分卷',
          subject: subject,
          category: _examKey,
          source: _sourceExam,
          author: _maskName(person.name),
          authorTitle: person.organizationName,
          image: image,
          tags: _examTags[subject] ?? const ['高分卷'],
          points: [
            if (band != null) '$grade 档标准：${band.description}',
            ...comments,
          ],
          intro:
              '${exam.examName}$subject全画室最高分（${_scoreText(score)} 分，$grade 档），来自${person.organizationName}。',
          createTime:
              '${published.year}-${_two(published.month)}-${_two(published.day)} 18:00:00',
          baseViews: _baseViewsOf('73$examId${k + 1}', _sourceExam),
          score: score,
          grade: grade,
          examName: exam.examName,
        ),
      );
    }
  }
  return works;
}

_Work _findWork(String id) {
  for (final work in _galleryWorks()) {
    if (work.id == id) {
      return work;
    }
  }
  throw const DemoApiException('作品不存在或已下架', code: 404);
}

// ── 浏览量与序列化 ──────────────────────────────────────────────────────

const _viewsKey = 'gallery:views';

Map<String, dynamic> _viewStore() =>
    DemoStore.map(_viewsKey, () => <String, dynamic>{});

int _viewsOf(_Work work, Map<String, dynamic> views) =>
    work.baseViews + ((views[work.id] as num?)?.toInt() ?? 0);

Map<String, dynamic> _workJson(
  _Work work,
  String userId,
  Map<String, dynamic> views,
) {
  return <String, dynamic>{
    'id': work.id,
    'title': work.title,
    'subject': work.subject,
    'category': work.category,
    'categoryLabel': work.categoryLabel,
    'source': work.source,
    'author': work.author,
    'authorTitle': work.authorTitle,
    'imageUrl': DemoMedia.url(work.imageRef),
    'aspectRatio': _aspectOf(work.image),
    'score': work.score,
    'grade': work.grade.isEmpty ? null : work.grade,
    'examName': work.examName.isEmpty ? null : work.examName,
    'tags': work.tags,
    'points': work.points,
    'favorite': DemoFavorites.contains(
      userId,
      DemoFavorites.typeGallery,
      work.id,
    ),
    'views': _viewsOf(work, views),
    'createTime': work.createTime,
  };
}
