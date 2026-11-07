import '../data/demo_marking_data.dart';
import '../demo_accounts.dart';
import 'interaction_common.dart';

/// 演示版「小美同学」的一次回答。
class DemoAiAnswer {
  const DemoAiAnswer({required this.text, required this.reasoning});

  final String text;

  /// 深度思考模式下展示的思考过程。
  final String reasoning;
}

/// 用户随消息附带的文件（名称决定是否按作品图片分析）。
class DemoAiAttachment {
  const DemoAiAttachment({required this.name, required this.url});

  final String name;
  final String url;

  bool get isImage {
    final source = name.isNotEmpty ? name : url;
    final clean = source.split('?').first.toLowerCase();
    return const [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
      '.heic',
    ].any(clean.endsWith);
  }
}

/// 内置美术备考知识库：按关键词匹配主题，作品图片走「作品分析」模板。
abstract final class DemoAiTutor {
  static DemoAiAnswer answer({
    required DemoAccount account,
    required String question,
    List<DemoAiAttachment> attachments = const <DemoAiAttachment>[],
    bool webSearch = false,
  }) {
    final images = attachments.where((a) => a.isImage).toList();
    final files = attachments.where((a) => !a.isImage).toList();
    final context = _TutorContext(account);
    final buffer = StringBuffer();
    String topicTitle;

    if (images.isNotEmpty) {
      final subject = _subjectOf(question, images.first.name);
      topicTitle = '$subject作品分析';
      buffer.write(_artworkAnalysis(subject, images.first.name));
    } else {
      final topic = _match(question);
      topicTitle = topic?.title ?? '美术备考';
      if (files.isNotEmpty) {
        buffer
          ..writeln(
            '> 已收到附件《${files.first.name}》。演示模式下暂不解析文档内容，'
            '以下先按你的问题给出建议。',
          )
          ..writeln();
      }
      buffer.write(topic == null ? _fallback(question) : topic.build(context));
    }
    if (webSearch) {
      buffer
        ..writeln()
        ..writeln()
        ..write('> 演示模式未接入联网搜索，以上内容来自小美同学内置的美术备考知识库。');
    }
    return DemoAiAnswer(
      text: buffer.toString().trim(),
      reasoning: _reasoning(topicTitle, context, hasImage: images.isNotEmpty),
    );
  }

  static _Topic? _match(String question) {
    final text = question.toLowerCase();
    _Topic? best;
    var bestScore = 0;
    for (final topic in _topics) {
      var score = 0;
      for (final keyword in topic.keywords) {
        if (text.contains(keyword)) {
          score += keyword.length;
        }
      }
      if (score > bestScore) {
        best = topic;
        bestScore = score;
      }
    }
    return best;
  }

  static String _reasoning(
    String topicTitle,
    _TutorContext context, {
    required bool hasImage,
  }) {
    final brief = context.brief;
    final lines = <String>[
      hasImage ? '用户上传了一张作品照片，希望得到「$topicTitle」。' : '用户在问「$topicTitle」相关的问题。',
      hasImage
          ? '按联考阅卷顺序观察：先看整体印象和构图，再看造型结构与明暗或色彩，最后看细节完成度。'
          : '先明确这个知识点在联考评分中对应哪些得分点和常见扣分项。',
      '回答按「原理 → 步骤 → 常见错误 → 练习建议」组织，方便直接照着练。',
      if (brief != null)
        '结合用户最近一次「${brief.examName}」的成绩，薄弱科目是${brief.weakest.name}，建议里适当向它倾斜。',
      '最后补充一条可量化执行的练习安排，并提醒以任课老师的意见为准。',
    ];
    return lines.join('\n');
  }

  static String _subjectOf(String question, String fileName) {
    final text = '$question $fileName'.toLowerCase();
    if (text.contains('色彩') ||
        text.contains('水粉') ||
        text.contains('color') ||
        text.contains('风景')) {
      return '色彩';
    }
    if (text.contains('速写') ||
        text.contains('人物') ||
        text.contains('动态') ||
        text.contains('speed')) {
      return '速写';
    }
    if (text.contains('素描') ||
        text.contains('石膏') ||
        text.contains('几何') ||
        text.contains('sketch')) {
      return '素描';
    }
    return fileName.hashCode.isEven ? '素描' : '色彩';
  }
}

class _TutorContext {
  _TutorContext(this.account);

  final DemoAccount account;
  late final _ScoreBrief? brief = _ScoreBrief.of(account);

  bool get isStudent => account.role == DemoRole.student;

  String get targetSchool {
    final value = demoProfileOf(account)['targetSchool']?.toString().trim();
    return value == null || value.isEmpty ? '西安美术学院' : value;
  }
}

typedef _SubjectScore = ({String name, double score, String grade});

class _ScoreBrief {
  const _ScoreBrief({
    required this.examName,
    required this.subjects,
    required this.total,
    required this.delta,
  });

  final String examName;
  final List<_SubjectScore> subjects;
  final double total;

  /// 与上一次有成绩的考试相比的总分变化；没有上一次时为 null。
  final double? delta;

  _SubjectScore get weakest =>
      subjects.reduce((a, b) => b.score < a.score ? b : a);

  static _ScoreBrief? of(DemoAccount account) {
    final index = account.personIndex;
    if (account.role != DemoRole.student || index == null) {
      return null;
    }
    final data = DemoMarkingData.instance;
    final scored = data.entriesOf(index).where((e) => e.scored).toList();
    if (scored.isEmpty) {
      return null;
    }
    final latest = scored.last;
    final previous = data.previousScoredEntry(index, latest.exam.examId);
    return _ScoreBrief(
      examName: latest.exam.examName,
      subjects: [
        for (final s in latest.subjects!)
          (name: s.def.subjectName, score: s.score, grade: s.grade),
      ],
      total: latest.total!,
      delta: previous == null ? null : latest.total! - previous.total!,
    );
  }

  String toMarkdown() {
    final parts = [
      for (final s in subjects) '${s.name} ${_fmt(s.score)}（${s.grade} 档）',
    ].join('、');
    final change = delta == null
        ? ''
        : '，较上一次${delta! >= 0 ? '提高' : '下降'} ${_fmt(delta!.abs())} 分';
    return '根据你最近一次「$examName」的成绩：$parts，总分 ${_fmt(total)}$change。';
  }
}

String _fmt(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

class _Topic {
  const _Topic(this.title, this.keywords, this.build);

  final String title;
  final List<String> keywords;
  final String Function(_TutorContext context) build;
}

const _topics = <_Topic>[
  _Topic('打招呼', ['你好', '您好', 'hello', 'hi', '在吗', '你是谁', '介绍一下你'], _greeting),
  _Topic('素描起形与结构', [
    '起形',
    '起稿',
    '形不准',
    '型不准',
    '造型',
    '结构',
    '辅助线',
    '切形',
    '外轮廓',
    '石膏',
    '五官',
    '几何体',
    '素描',
  ], _sketchShape),
  _Topic('明暗五大调子', [
    '五大调子',
    '调子',
    '明暗',
    '交界线',
    '反光',
    '投影',
    '高光',
    '灰面',
    '暗部',
    '黑白灰',
    '层次',
    '体积',
    '立体感',
  ], _tones),
  _Topic('色彩冷暖与色调', [
    '色彩',
    '冷暖',
    '色调',
    '发灰',
    '发粉',
    '画脏',
    '发脏',
    '环境色',
    '固有色',
    '补色',
    '调色',
    '水粉',
    '纯度',
    '色相',
  ], _color),
  _Topic('速写人体比例与动态', [
    '速写',
    '人体',
    '头身',
    '动态',
    '重心',
    '动态线',
    '衣纹',
    '坐姿',
    '站姿',
    '蹲姿',
    '人物组合',
    '画手',
    '手脚',
  ], _figure),
  _Topic('构图法则', [
    '构图',
    '取景',
    '三角形',
    's形',
    '对角线',
    '留白',
    '饱满',
    '偏上',
    '偏下',
    '九宫格',
    '黄金分割',
    '主次',
  ], _composition),
  _Topic('透视', [
    '透视',
    '消失点',
    '灭点',
    '视平线',
    '一点透视',
    '两点透视',
    '近大远小',
    '椭圆',
  ], _perspective),
  _Topic('联考评分标准与档位', [
    '评分',
    '档位',
    '打分',
    '阅卷',
    '分数段',
    '评分标准',
    '给分',
    'a档',
    'b档',
    'a–e',
    'a-e',
    '几档',
    '扣分',
    '高分卷',
    '仲裁',
  ], _grading),
  _Topic('备考时间规划', [
    '计划',
    '规划',
    '备考',
    '冲刺',
    '集训',
    '时间安排',
    '每天',
    '作息',
    '阶段',
    '考试计划',
  ], _plan),
  _Topic('画具选择', [
    '画具',
    '铅笔',
    '炭笔',
    '橡皮',
    '素描纸',
    '颜料',
    '水粉笔',
    '画笔',
    '画板',
    '画材',
    '工具清单',
    '买什么',
    '刮刀',
    '调色盒',
  ], _tools),
  _Topic('心态调整', [
    '心态',
    '焦虑',
    '紧张',
    '压力',
    '失眠',
    '瓶颈',
    '退步',
    '没信心',
    '放弃',
    '烦躁',
    '考砸',
    '迷茫',
    '难过',
  ], _mindset),
  _Topic('美术之路功能使用', [
    '怎么用',
    '如何使用',
    '功能',
    '在哪',
    '哪里看',
    '原卷',
    '作品档案',
    '上传作品',
    '范画库',
    '工具箱',
    '校圈',
    '笔记',
    '收藏',
    '会员',
    '兑换',
    '刷题',
    '题库',
    '美术之路',
  ], _appGuide),
  _Topic('报考院校分析', [
    '院校',
    '志愿',
    '报考',
    '录取',
    '分数线',
    '校考',
    '美院',
    '美术学院',
    '大学',
    '综合分',
  ], _schools),
  _Topic('练习建议', [
    '练习建议',
    '怎么练',
    '提高成绩',
    '提高',
    '进步',
    '训练',
    '弱项',
    '短板',
    '练习',
  ], _practice),
  _Topic('美术常识', [
    '美术史',
    '美术常识',
    '画家',
    '名画',
    '名作',
    '印象派',
    '文艺复兴',
    '国画',
    '鉴赏',
  ], _artHistory),
];

String _greeting(_TutorContext context) {
  final brief = context.brief;
  final buffer = StringBuffer()
    ..writeln('你好，我是**小美同学**，美术之路的美术答疑助手，回答仅供参考。')
    ..writeln()
    ..writeln('我可以帮你：')
    ..writeln('- 解答素描、色彩、速写的专业问题，例如起形、明暗、冷暖、动态')
    ..writeln('- 讲解联考评分标准与 A–E 档位，帮你分析扣分点')
    ..writeln('- 结合你的成绩制定备考计划和练习建议')
    ..writeln('- 作品点评请上传到「作品档案」，由任课老师完成');
  if (brief != null) {
    buffer
      ..writeln()
      ..write('> ${brief.toMarkdown()}想从哪一科开始聊？');
  }
  return buffer.toString();
}

String _sketchShape(_TutorContext context) => '''
起形是素描的地基，形不准，后面画得再细也会被扣分。可以按下面的步骤来：

### 一、先定构图与大比例
1. 用长直线标出物体的最高点、最低点、最左点和最右点，确定画面占位，主体一般占画纸的三分之二左右。
2. 用铅笔测量最长与最短的比例，例如石膏头像先确定头长与头宽的比例。
3. 找到中线和动势线：头像先画面部中线，再画眉弓、鼻底、下颌三条横向辅助线。

### 二、用切形代替描边
- 用直线切出外轮廓的大转折，**宁方勿圆**，先概括后细分。
- 留意负形，也就是物体之间、物体与画面边框之间的空白，负形准了，正形自然准。

### 三、理解结构再画明暗
- 把复杂形体归纳成几何体：头部看作立方体，脖子看作圆柱，鼻子看作三棱柱。
- 画出看不见的结构线和透视线，检查左右对称与透视是否统一。

### 四、反复检查
> 每隔十五分钟离开画板两米看一次，或者用「画室工具箱」的镜像功能对比，最容易发现歪斜。

**练习建议**：每天 3 张 20 分钟的结构速写（几何体或石膏五官），只起形、不铺调子，坚持两周会明显感觉手更准了。''';

String _tones(_TutorContext context) => '''
物体受光后会形成「三大面、五大调子」，掌握它们，画面的体积感和空间感就有了。

### 五大调子（由亮到暗）
1. **高光**：受光最直接的地方，面积最小，一般预先留出，最后用可塑橡皮轻提。
2. **灰面**：亮部中的中间层次，决定质感是否细腻。
3. **明暗交界线**：亮面与暗面的转折处，**是整幅画里最重要的调子**，它不是一条线，而是一个有宽窄、虚实变化的面。
4. **反光**：暗部受环境反射的光，**再亮也不能超过亮部的灰面**。
5. **投影**：物体遮挡光线形成的影子，靠近物体处最实最重，越远越虚。

### 常见问题
- 暗部画花：反光提得太亮，破坏了暗部的整体，记住暗部要统一。
- 交界线画成一条黑线：要跟着结构走，有宽窄、虚实和强弱变化。
- 亮部画得太满：亮部要惜墨如金，用浅灰塑造即可。

> 口诀：亮部要透，暗部要沉，交界线要实，投影要虚。

**练习建议**：先画球体、立方体的五调子分析图，再过渡到苹果、陶罐等单个静物，最后用同样的方法分析石膏头像的眉弓和颧骨。''';

String _color(_TutorContext context) => '''
色彩考试最看重的是「色调统一、冷暖关系明确」。先弄清颜色从哪里来：

### 一、三种颜色来源
- **固有色**：物体本身的颜色，例如橙子是橙色。
- **光源色**：画室常见的天光偏冷，亮部会带一点冷色倾向。
- **环境色**：周围物体反射过来的颜色，暗部和反光最明显，例如白盘子靠近红苹果的一侧会泛红。

### 二、冷暖关系的规律
1. 光源冷，则亮部偏冷、暗部偏暖；光源暖，则亮部偏暖、暗部偏冷。
2. 同一块衬布的受光部和背光部要有明显的冷暖对比。
3. 主体物用更强的冷暖和纯度对比，背景和次要物体适当降低纯度。

### 三、画面发灰、发粉、发脏怎么办
- **发灰**：明度没拉开，先把最暗的地方（陶罐暗部、投影）压下去。
- **发粉**：亮部白色加得太多，改用柠檬黄、淡黄提亮，少用纯白。
- **发脏**：颜色在纸上反复覆盖，或一笔里调了三种以上的颜色，尽量调准再画、一笔到位。

> 色调先行：起稿后用大笔快速铺出大色块，先确定是暖黄调、蓝灰调还是高级灰调，再深入细节。

**练习建议**：用同一组静物画 3 张 30 分钟的色彩小稿，分别处理成暖调、冷调和灰调，体会背景色对整张画气氛的影响。''';

String _figure(_TutorContext context) => '''
速写的核心是「动态准、比例对、线条活」，下面是考场上最实用的要点：

### 一、常用人体比例
- 站姿约 **七到七个半头高**，坐姿约五个头，盘腿坐约三个半头，口诀是「立七坐五盘三半」。
- 肩宽约两个头宽，手臂自然下垂时，指尖大约到大腿中部。
- 全身的中点在耻骨附近，小腿与大腿的长度接近。

### 二、抓动态的三条线
1. **动态线**：从头顶经脊柱到承重脚的一条弧线，决定人物在做什么。
2. **肩线与胯线**：站立时两条线方向相反、一高一低，这就是对立平衡。
3. **重心线**：从颈窝向下作垂线，必须落在支撑面内，否则人物会站不稳。

### 三、作画步骤
1. 先用三到五条长线画出动态骨架，不画细节。
2. 用几何形概括头部、胸腔、骨盆三大体块，注意它们之间的扭转。
3. 衣纹只抓关节处的挤压纹和拉伸纹，忽略无关的小褶皱。
4. 最后刻画头、手、脚，**手和脚一定要画完整**，这是阅卷老师判断功底的地方。

**练习建议**：每天 10 张 2 分钟的动态速写、3 张 15 分钟的慢写，再加 20 个手部局部，坚持一个月，速写会稳定不少。''';

String _composition(_TutorContext context) => '''
构图是阅卷老师的第一印象，基本决定了一张画的档位起点。

### 一、基本原则
- **饱满而不拥挤**：主体物占画面约三分之二，四周留白上少下多、左右不均等。
- **主次分明**：主体物放在视觉中心附近（九宫格交叉点），不要放在正中间。
- **疏密有致**：物体之间有遮挡、有前后，避免一字排开。

### 二、常用构图形式
1. **三角形构图**：最稳定，适合静物组合，把高的物体放在后方作为顶点。
2. **S 形构图**：衬布走向形成 S 形曲线，画面更灵动。
3. **对角线构图**：适合速写场景和风景，能增强纵深感和动势。

### 三、常见扣分点
- 构图偏上或偏下：起稿时先用长线确定上下边界。
- 物体大小相同、间距相等：要有大小、高低和疏密变化。
- 衬布或背景的转折线正好穿过画面中线，把画面切成两半。

> 可以用「画室工具箱」的构图网格对照照片，快速检查主体位置和画面平衡。

**练习建议**：动笔前先画 2 到 3 个巴掌大的构图小稿，选最满意的一个放大，每次考试都坚持这个习惯。''';

String _perspective(_TutorContext context) => '''
透视错误是素描和速写里最硬的扣分点，先记住三条规律：近大远小、近实远虚、近宽远窄。

### 一、视平线与消失点
- **视平线**：与眼睛等高的水平线。高于视平线的物体能看到底面，低于视平线的能看到顶面。
- **消失点**：一组平行线向远处延伸后汇聚的点，一定在视平线上。

### 二、两种常用透视
1. **一点透视（平行透视）**：物体有一个面与画面平行，纵深线汇聚到一个消失点，常见于走廊、街道场景速写。
2. **两点透视（成角透视）**：物体与画面成一定角度，两组边分别消失于左右两个消失点，静物里的立方体、书本多属于这种。

### 三、圆形的透视
- 圆面透视后是椭圆，**越接近视平线越扁，越远离视平线越圆**。
- 陶罐的瓶口与底面都是椭圆，底面比瓶口更圆；椭圆两端是圆弧，不能画成尖角。

**练习建议**：画 10 个不同角度的立方体和圆柱体，每个都把透视线延长找到消失点，检查它们是否落在同一条视平线上。''';

String _grading(_TutorContext context) {
  final bands = DemoMarkingData.bands('素描', 100);
  String range(DemoGradeBand band) => band.min <= 0
      ? '${_fmt(bands[bands.length - 2].min)} 分以下'
      : '${_fmt(band.min)}–${_fmt(band.max)} 分';
  final lines = [
    for (final band in bands)
      '- **${band.grade} 档（${range(band)}）**：${band.description}',
  ].join('\n');
  return '''
美术联考按「先定档、再给分」的方式评卷，示范画室的月考也采用同样的规则。以素描满分 100 分为例：

### 一、档位划分
$lines

### 二、评分流程
1. 每份试卷至少由 2 位老师独立打分，大型考试由 5 位老师打分，去掉最高分和最低分后取平均。
2. 两位老师的分差超过 10 分时进入**仲裁**，由仲裁老师确定最终档位与分数。
3. 老师先根据整体印象判断档位，再在档内微调分数。

### 三、练习重点
- 想稳进 B 档：构图、比例不出错，黑白灰或冷暖的大关系拉开。
- 想冲 A 档：画面要有完整度和表现力，主体刻画深入，边缘有虚实变化。

> 在「我的学情」里可以查看每一科的评分标准、档位样卷和自己的原卷，对照着找差距最直观。''';
}

String _plan(_TutorContext context) {
  final brief = context.brief;
  final buffer = StringBuffer();
  if (brief != null) {
    final weakest = brief.weakest;
    buffer
      ..writeln(brief.toMarkdown())
      ..writeln()
      ..writeln('目前最需要加强的是**${weakest.name}**，下面的计划里每周给它多安排 2 次专项练习。')
      ..writeln();
  }
  buffer.write('''
### 联考备考三阶段
1. **基础阶段（6–8 月）**：素描从几何体、静物到石膏五官和头像；色彩从单个静物到组合；速写从单人动态开始。目标是会画、画对。
2. **强化阶段（9–10 月）**：按考试时长整卷练习，每周至少 2 次限时模考，重点解决构图和大关系。目标是画得稳。
3. **冲刺阶段（11 月至联考）**：以考题训练和默写为主，固定自己的作画步骤和配色方案，调整作息。目标是考场不失误。

### 每日时间分配参考
- 上午 08:00–11:30：素描（长期作业或考题）
- 下午 14:00–17:30：色彩（整卷或色调小稿）
- 晚上 19:00–21:00：速写（动态加慢写）
- 睡前 20 分钟：复盘当天作品，记下 1 个问题和 1 个改进办法

> 「画室工具箱」里的考试倒计时可以帮你随时看到剩余天数，「我的学情」的成长曲线能检验每个阶段的效果。''');
  return buffer.toString();
}

String _tools(_TutorContext context) => '''
考前准备一套用顺手的画具，比临时换高级画材更重要。

### 素描
- 铅笔：2H、HB、2B、4B、6B、8B 各 2 到 3 支，亮部用硬铅，暗部用软铅，最重处可用炭笔。
- 橡皮：普通橡皮、可塑橡皮（提亮、减弱调子）和笔形橡皮（提高光）。
- 纸：8 开或 4 开素描纸，选纹理适中、经得起反复擦改的。

### 色彩（水粉）
- 颜料：钛白、柠檬黄、土黄、群青、熟褐等常用色准备大瓶装，考前检查有没有干结。
- 画笔：大号底纹笔铺大色，中号水粉笔塑造，小号勾线笔刻画细节。
- 调色盒、喷壶、吸水海绵和一块旧毛巾。

### 速写
- 速写本或 8 开速写纸，铅笔、炭笔或针管笔选一种最熟悉的即可。

### 考场清单
画板、夹子、美工刀、胶带、准考证和身份证，**考前一天全部清点一遍**。

> 画具因人而异，以你在画室长期使用、最熟悉的工具为准。''';

String _mindset(_TutorContext context) => '''
集训期间情绪起伏很正常，几乎每个艺考生都会经历瓶颈期。

### 一、正确看待瓶颈期
- 瓶颈往往出现在**眼光提高了、手还没跟上**的时候，这恰恰说明你在进步。
- 不要和别人的优秀作品比较，和一个月前的自己比较。翻翻「作品档案」里的早期作品，会很有说服力。

### 二、考前紧张怎么办
1. 把考试当作一次普通模考，提前在画室按考试时间完整演练 2 到 3 次。
2. 准备一套固定的作画流程，到了考场按流程走，减少临场犹豫。
3. 考前一周保持正常作息，不熬夜赶画，睡眠比多画一张画更重要。

### 三、一次没考好
- 先看原卷和老师评语，找出 1 到 2 个最关键的问题，而不是否定全部。
- 把问题写进下周的练习计划，用具体行动代替焦虑。

> 如果长期失眠、情绪低落，请及时和班主任或家人沟通，你不是一个人在战斗。''';

String _appGuide(_TutorContext context) => '''
美术之路的主要功能都在左侧导航栏里：

- **我的学情**：查看每次月考的各科成绩、档位、排名、原卷和评分标准，成长曲线帮你看清进步轨迹。
- **作品档案**：拍照上传日常作品，任课老师会在线点评和标注，作品按时间自动归档。
- **范画库**：按素描、色彩、速写和高分卷分类浏览范画，收藏后可以反复临摹。
- **画室工具箱**：明度检查、镜像对比、构图网格、取色色卡、速写计时和考试倒计时。
- **视频中心**：排线、起形、铺色等专项课程，支持倍速播放。
- **智慧校园**：课表、考勤签到、宿舍、班级群聊和校圈动态。
- **题库**：首页「题库」入口，练习美术常识和名作鉴赏题，做错的题会自动收进错题本。
- **我的笔记 / 我的收藏**：记录课堂要点，收藏范画、视频和资讯。

> 更详细的步骤可以查看顶部的「操作指南」，遇到问题也可以在「意见反馈」里留言。''';

String _schools(_TutorContext context) {
  final brief = context.brief;
  final buffer = StringBuffer();
  if (brief != null) {
    buffer
      ..writeln('### 你的成绩概况')
      ..writeln(brief.toMarkdown())
      ..writeln()
      ..writeln(
        '个人资料里的目标院校是**${context.targetSchool}**。按目前的专业成绩，'
        '建议把它作为「冲一冲」的志愿，同时准备两到三所「稳一稳」的院校。',
      )
      ..writeln();
  } else if (!context.isStudent) {
    buffer
      ..writeln('可以在「班级学情」里查看学生的历次成绩，按下面的思路帮学生做志愿分析：')
      ..writeln();
  }
  buffer.write('''
### 志愿填报思路
1. **冲一冲**：专业要求高、往年录取线略高于你预估综合分的院校。
2. **稳一稳**：近三年录取线与你的综合分接近的院校，作为主力志愿。
3. **保一保**：录取线明显低于你的综合分、专业方向你也能接受的院校。

### 重点关注的信息
- 院校的**录取规则**：专业分优先、文化分优先，还是按比例折算的综合分。
- 是否组织**校考**以及校考时间，避免和联考复习冲突。
- 专业方向：绘画、设计、美术教育、动画等方向对专业能力的侧重点不同。

> 以上为演示数据下的通用建议。各院校每年的招生政策都会调整，请以院校发布的招生简章为准，并结合班主任的意见综合决定。''');
  return buffer.toString();
}

const _subjectDrills = <String, String>{
  '素描': '每天 1 张 3 小时石膏头像或静物长期作业，加 2 张 20 分钟结构速写，重点练明暗交界线和暗部的整体。',
  '色彩': '每天 1 张 3 小时整卷，加 2 张 30 分钟色调小稿，重点解决冷暖关系和画面发灰的问题。',
  '速写': '每天 10 张 2 分钟动态、3 张 15 分钟慢写，再加 20 个手脚局部，重点练动态线和手脚刻画。',
};

String _practice(_TutorContext context) {
  final brief = context.brief;
  final buffer = StringBuffer();
  if (brief != null) {
    final weakest = brief.weakest;
    buffer
      ..writeln(brief.toMarkdown())
      ..writeln()
      ..writeln('### 本周重点：${weakest.name}')
      ..writeln('- ${_subjectDrills[weakest.name]}')
      ..writeln('- 在「范画库」里找 2 张同类高分卷临摹，对照自己的原卷找差距。')
      ..writeln()
      ..writeln('### 保持手感');
    for (final s in brief.subjects.where((s) => s.name != weakest.name)) {
      buffer.writeln('- ${s.name}（${s.grade} 档）：每周 2 次限时整卷，保持状态即可。');
    }
  } else {
    buffer
      ..writeln('### 分科练习建议')
      ..writeln('- **素描**：${_subjectDrills['素描']}')
      ..writeln('- **色彩**：${_subjectDrills['色彩']}')
      ..writeln('- **速写**：${_subjectDrills['速写']}');
  }
  buffer
    ..writeln()
    ..write('> 每张作业完成后拍照上传到「作品档案」，老师的点评和你的成绩曲线会一起记录下来，方便复盘。');
  return buffer.toString();
}

String _artHistory(_TutorContext context) => '''
美术常识在部分省份的校考和文化考试中都会出现，重点掌握下面几块：

### 中国美术史
- 东晋顾恺之《洛神赋图》、唐代吴道子「吴带当风」、北宋张择端《清明上河图》、元代黄公望《富春山居图》。
- 「元四家」是黄公望、吴镇、倪瓒、王蒙。

### 外国美术史
- 文艺复兴三杰：达·芬奇、米开朗基罗、拉斐尔。
- 印象派得名于莫奈的《日出·印象》；后印象派代表有塞尚、梵高、高更。

### 学习方法
1. 按时间线整理画家、代表作和风格特点，不要零散记忆。
2. 名作鉴赏从构图、色彩、技法和时代背景四个角度分析。

> 首页「题库」里有 60 道美术常识题，做错的题会收进错题本，方便考前集中复习。''';

String _fallback(String question) => '''
这个问题我还没有找到最贴切的答案，可以换个说法，或者问问我这些内容：

- **素描**：起形与结构、明暗五大调子、透视
- **色彩**：冷暖关系、色调统一、画面发灰发粉怎么改
- **速写**：人体比例、动态线、手脚刻画
- **考试**：联考评分标准与 A–E 档位、备考时间规划、心态调整
- **工具**：画具选择、美术之路各项功能怎么用

想请老师看作品，可以上传到「作品档案」，由任课老师点评。''';

const _gradeGuesses = <String>[
  'B 档（演示估分 82–86 分）',
  'B 档偏上（演示估分 86–89 分）',
  'C 档偏上（演示估分 76–79 分）',
];

String _artworkAnalysis(String subject, String fileName) {
  final guess = _gradeGuesses[fileName.hashCode.abs() % _gradeGuesses.length];
  final body = switch (subject) {
    '色彩' => _colorAnalysis,
    '速写' => _figureAnalysis,
    _ => _sketchAnalysis,
  };
  return '''
### 作品分析（演示）
> 演示模式：以下为示例分析，小美同学没有真正识别这张图片，仅展示作品分析的维度和思路。正式点评请以任课老师在「作品档案」中的意见为准。

**预估档位**：$guess

$body''';
}

const _sketchAnalysis = '''
**整体印象**：画面完整度较高，黑白灰关系基本拉开，主体物的体积感表现较好，整体给人比较稳的感觉。

**构图**：主体略偏左，画面下方留白偏多，可以把整组物体整体上移一些，让构图更饱满。

**造型结构**：主要形体比例基本准确，椭圆透视处理得当；物体之间的穿插和前后关系略弱，边缘线的处理稍显生硬。

**明暗关系**：亮部层次细腻，明暗交界线位置准确；暗部的反光偏亮，暗部有些发花，可以整体压暗半个调子。

**细节刻画**：主体物的高光和转折处刻画到位；前景衬布的褶皱数量偏多，可以概括取舍。

### 改进建议
1. 暗部统一：用 4B 铅笔整体罩一遍暗部，再用可塑橡皮轻提反光。
2. 拉开空间：后方物体与背景交接的边缘画虚，前景物体的边缘画实。
3. 强化主体：把更强的黑白对比留给主体物，次要物体适当减弱。

### 推荐练习
- 本周完成 2 张 3 小时长期作业，重点练暗部整体和边缘虚实。
- 在「范画库」临摹 1 张同类高分卷，对比暗部的处理方法。
- 用「画室工具箱」的明度检查，确认黑白灰层次是否拉开。''';

const _colorAnalysis = '''
**整体印象**：色调倾向比较明确，主体物色彩饱和、跳得出来，画面有一定的感染力。

**构图**：主体组合呈三角形分布，比较稳定；右侧衬布占画面面积偏大，可以适当收一点，突出主体。

**造型结构**：陶罐和水果的形体基本准确，盘子的椭圆透视略扁，水果之间的前后遮挡可以再明确。

**色彩关系**：亮部与暗部有冷暖对比，但背景和衬布的纯度偏高，与主体抢戏；白衬布的暗部偏灰，可以加入一点环境色。

**细节刻画**：主体水果的笔触顺着形体走，塑造感较好；陶罐的高光略散，瓶口转折处可以更肯定。

### 改进建议
1. 降低背景纯度：背景色里调入少量补色或灰色，让主体物更突出。
2. 丰富白色：白衬布的亮部偏暖黄、暗部偏冷紫灰，避免直接用白加黑。
3. 收紧边缘：主体物受光一侧的边缘画实，背光一侧融入背景。

### 推荐练习
- 本周画 3 张 30 分钟色调小稿，分别练暖调、冷调和灰调。
- 在「范画库」挑 1 张同色调高分卷做色彩分析笔记。
- 用「画室工具箱」的取色色卡，对比自己作品和范画的主色差异。''';

const _figureAnalysis = '''
**整体印象**：人物动态生动，线条有一定的节奏感，整体完成度不错。

**构图**：人物在画面中的位置合适，脚下留白略少，组合人物时注意前后人物的大小差异。

**造型结构**：头、胸、骨盆三大体块的关系基本准确，重心稳定；手臂略短，肩线与胯线的对比可以更明显。

**明暗关系**：衣纹的疏密处理较好，关节处的挤压纹清楚；暗部的排线方向可以统一一些，避免画面发花。

**细节刻画**：头部刻画到位；手和鞋的结构偏弱，这是阅卷老师重点关注的地方。

### 改进建议
1. 先画动态线：落笔前用一条弧线确定动态，再找肩线和胯线的方向。
2. 手脚单练：手画成连指手套的形状再分出手指，鞋子先画成楔形块面。
3. 线条取舍：衣纹只保留关节处的主要褶皱，长线要肯定，避免反复描。

### 推荐练习
- 每天 10 张 2 分钟动态速写，加 20 个手脚局部。
- 在「范画库」临摹 2 张速写高分卷，体会线条的轻重和疏密。
- 用「画室工具箱」的速写计时功能做限时训练。''';
