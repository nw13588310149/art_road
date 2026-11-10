import '../demo_backend.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';
import 'content_common.dart';

/// 资讯条目。正文 [blocks] 为极简标记：`## ` 小标题、`- ` 列表、
/// `img:<引用>` 图片、`> ` 灰色说明，其余为段落。
class _Article {
  const _Article({
    required this.id,
    required this.title,
    required this.headline,
    required this.tags,
    required this.cover,
    required this.time,
    required this.views,
    required this.blocks,
    this.source = '绘画星球',
    this.school = false,
  });

  final int id;
  final String title;

  /// 卡片主标题（`shortText1`）。
  final String headline;
  final List<String> tags;
  final String cover;
  final String time;
  final int views;
  final List<String> blocks;
  final String source;

  /// 校园专属资讯（示范画室）。
  final bool school;
}

final List<_Article> _articles = <_Article>[
  _Article(
    id: 9001,
    title: '2027 年美术与设计学类专业统考政策解读',
    headline: '联考政策解读',
    tags: const ['联考', '政策', '甘肃'],
    cover: ContentDemo.scene('exam-hall'),
    time: '2026-11-06 10:20:00',
    views: 3826,
    blocks: [
      '美术与设计学类专业统考（俗称「联考」）是大多数美术类考生必须参加的省级专业考试，成绩既是本省本科院校美术类专业录取的主要依据，也是部分院校校考报名的门槛。本文梳理考生最关心的几个要点，帮助大家合理安排最后阶段的备考。',
      '> 说明：文中分值与考试时长仅供参考，具体以本省教育考试院发布的正式公告为准。',
      '## 考试科目与分值',
      '- 素描：满分 100 分，考试时长 180 分钟，常见题型为石膏像、人物头像或静物组合的写生 / 默写。',
      '- 色彩：满分 100 分，考试时长 180 分钟，以静物写生或照片写生为主，水粉、水彩、丙烯均可。',
      '- 速写：满分 100 分，考试时长 60 分钟，以人物动态、组合人物或场景速写为主。',
      'img:${ContentDemo.scene('exam-hall')}',
      '## 需要特别关注的三点',
      '- 考场统一提供画板与画架，自带工具需符合清单要求，提前熟悉画材规格。',
      '- 默写类题目比例有所提升，平时练习要兼顾写生和默写两种能力。',
      '- 阅卷采用多位老师独立评分取平均的方式，画面整体效果和完整度尤为重要。',
      '## 备考建议',
      '最后阶段不建议再大幅更换画法。以近三年真题为样本做限时模拟，把时间分配固定下来：素描起形 30 分钟、铺大关系 60 分钟、深入刻画 70 分钟、整体调整 20 分钟。考前两周逐步把作息调整到与考试时间一致。',
    ],
  ),
  _Article(
    id: 9002,
    title: '联考素描评分标准解析：五个档次怎么拿分',
    headline: '素描评分标准',
    tags: const ['联考', '素描', '评分'],
    cover: ContentDemo.art('sketch-portrait-1'),
    time: '2026-11-05 15:30:00',
    views: 2931,
    blocks: [
      '素描阅卷通常先把试卷分档、再在档内给分。理解每个档次的「画面特征」，比单纯追求某个技法更能稳定拿分。下面以 100 分制为例，档位划分与绘画星球成绩中的 A–E 档一致（各省细则略有差异）。',
      '## A 档（90 分及以上）',
      '构图饱满、形体准确，明暗关系清楚且层次丰富，主体刻画深入、虚实对比明确，整体效果强。',
      '## B 档（80–89 分）',
      '构图合理、比例基本准确，黑白灰关系明确，局部刻画到位，但整体节奏或细节质感略有欠缺。',
      '## C 档（70–79 分）',
      '形体有小的偏差，明暗层次不够丰富，画面完成度一般，是大多数考生所在的档位。',
      '## D、E 档（69 分及以下）',
      '常见原因：构图过大或过小、比例结构明显错误、画面未完成或脏乱。',
      'img:${ContentDemo.art('sketch-still-3')}',
      '> 上图：A 档静物示例，构图饱满，黑白灰层次拉得开。',
      '## 三个最容易被扣分的地方',
      '- 明暗交界线画成「一条线」：交界线是形体转折的过渡带，要有虚实和宽窄变化。',
      '- 暗部画得太闷：暗部要留出反光，与投影拉开层次。',
      '- 只顾局部不顾整体：每画 20 分钟退后看一次画面，眯眼比较黑白灰。',
      '> 以上档次与分段为教学示例，用于帮助理解评分思路。',
    ],
  ),
  _Article(
    id: 9003,
    title: '色彩考试常见失分点与应对',
    headline: '色彩备考',
    tags: const ['色彩', '备考', '技巧'],
    cover: ContentDemo.art('color-still-1'),
    time: '2026-11-04 09:10:00',
    views: 2457,
    blocks: [
      '色彩是三科中拉分最明显的一科。很多同学造型能力不错，色彩却总在 70 分上下徘徊，问题往往不在「画得不像」，而在色彩关系没有建立起来。',
      '## 失分点一：色调不统一',
      '画面没有明确的冷暖倾向，每个物体各画各的颜色。开画前先确定整体色调——偏暖还是偏冷、偏亮还是偏灰，再让衬布、背景都服从这个调子。',
      '## 失分点二：暗部和投影「死黑」',
      '暗部直接用黑色或深褐色加重，会让画面发闷。暗部应当是固有色加环境色，冷暖要与亮部形成对比。',
      'img:${ContentDemo.art('color-still-2')}',
      '## 失分点三：笔触琐碎',
      '大面积用小笔反复涂抹，画面会显得碎和脏。铺大色时用大笔、厚薄结合，刻画阶段再收小笔。',
      '## 一周练习建议',
      '- 每天 1 张 40 分钟色彩小稿，只练色调与大关系。',
      '- 隔天 1 张 3 小时完整静物，严格按考试流程。',
      '- 每周做一次范画临摹，分析老师的调色与用笔。',
    ],
  ),
  _Article(
    id: 9004,
    title: '速写如何在 30 分钟内完成一张完整画面',
    headline: '速写提速',
    tags: const ['速写', '时间分配', '人物'],
    cover: ContentDemo.art('speed-figure-1'),
    time: '2026-11-03 20:05:00',
    views: 1984,
    blocks: [
      '速写考试时间短，「画不完」是最常见的问题。提速的关键不是线条画得快，而是减少犹豫——先确定动态，再按固定顺序推进。',
      '## 推荐时间分配（单人动态，30 分钟）',
      '- 0–3 分钟：观察动态，用 3–4 根线确定重心线、肩线、胯线。',
      '- 3–12 分钟：从头部开始画外轮廓，手脚交代清楚。',
      '- 12–24 分钟：组织衣纹，注意主次和疏密，不必每条褶皱都画。',
      '- 24–30 分钟：加重关键转折，补充投影或简单环境，整体调整。',
      'img:${ContentDemo.art('speed-figure-3')}',
      '## 三个提速小技巧',
      '- 默写常见动作的「动态骨架」，考试时直接套用再根据题目调整。',
      '- 线条一笔画到位，少用短线反复描。',
      '- 手和脚提前单独练熟，它们最耗时间也最容易暴露问题。',
    ],
  ),
  _Article(
    id: 9005,
    title: '校考简章怎么读？五个关键信息别漏看',
    headline: '校考简章要点',
    tags: const ['校考', '简章', '报考'],
    cover: ContentDemo.scene('studio-wall'),
    time: '2026-11-02 11:00:00',
    views: 2718,
    blocks: [
      '每年秋冬，各美术院校陆续发布本科招生简章。简章篇幅长、信息多，建议重点关注以下五项，并整理成自己的报考时间表。',
      '## 1. 报考条件',
      '是否要求联考成绩合格、是否限制生源省份、是否有单科成绩要求，这些决定你能不能报。',
      '## 2. 报名与考试时间',
      '网上报名、缴费、确认的截止时间往往不同；线上考试还会安排设备调试和模拟考环节。',
      '## 3. 考试科目与形式',
      '不同专业考试科目不同，造型类常考素描、色彩、速写或创作，设计类可能加试设计基础。',
      '## 4. 录取规则',
      '是按专业成绩排序、按综合分排序，还是专业合格后按文化分排序，直接影响你的备考重心。',
      '## 5. 文化课要求',
      '部分院校对外语、语文单科有最低分要求，别让短板科目耽误录取。',
      'img:${ContentDemo.scene('studio-wall')}',
      '> 提示：所有信息以院校当年发布的正式简章为准，本文仅作阅读方法参考。',
    ],
  ),
  _Article(
    id: 9006,
    title: '中央美术学院：专业设置与校考特点概览',
    headline: '美院介绍',
    tags: const ['美院', '校考', '北京'],
    cover: ContentDemo.art('sketch-bust-1'),
    time: '2026-10-31 16:40:00',
    views: 3412,
    blocks: [
      '中央美术学院位于北京，是国内美术教育的代表性院校之一，学科覆盖造型艺术、设计、建筑、艺术人文等多个方向。',
      '## 学科方向',
      '- 造型类：中国画、油画、版画、雕塑、实验艺术等。',
      '- 设计类：视觉传达、产品设计、数字媒体等方向。',
      '- 建筑与人文类：建筑学、艺术史论等。',
      '## 校考特点',
      '历年校考普遍重视造型基础与创作思维，考题常常在写生之外加入主题表达或命题创作，要求考生既有扎实的造型能力，也能在画面中体现思考。',
      'img:${ContentDemo.art('sketch-bust-1')}',
      '## 备考建议',
      '- 夯实素描造型，尤其是人物头像与半身像。',
      '- 平时积累速写本，练习从生活中提炼画面。',
      '- 多看展览、多读美术史，提升画面立意。',
      '> 招生专业、考试科目与录取规则以学校当年发布的招生简章为准。',
    ],
  ),
  _Article(
    id: 9007,
    title: '中国美术学院：学科特色与备考方向',
    headline: '美院介绍',
    tags: const ['美院', '杭州', '校考'],
    cover: ContentDemo.art('color-landscape-1'),
    time: '2026-10-29 14:15:00',
    views: 2896,
    blocks: [
      '中国美术学院位于杭州，学科门类完整，在中国画、书法、油画、设计等方向都有深厚积累，校园环境人文气息浓厚。',
      '## 学科特色',
      '- 传统艺术方向积淀深厚，重视笔墨与造型的结合。',
      '- 设计与新媒体方向发展迅速，跨学科项目较多。',
      '## 校考关注点',
      '历年考题注重写生能力和画面感受，色彩与速写常与生活场景结合，对构图组织和氛围表达要求较高。',
      'img:${ContentDemo.art('color-landscape-1')}',
      '## 备考建议',
      '- 色彩多做风景与场景写生，训练对环境色和氛围的把握。',
      '- 速写注重人物与场景的组合，练习画面的完整性。',
      '> 具体考试安排以学校当年发布的招生简章为准。',
    ],
  ),
  _Article(
    id: 9008,
    title: '西安美术学院：西北地区考生的热门选择',
    headline: '美院介绍',
    tags: const ['美院', '西安', '西北'],
    cover: ContentDemo.art('sketch-bust-2'),
    time: '2026-10-27 10:30:00',
    views: 2563,
    blocks: [
      '西安美术学院位于古都西安，是西北地区重要的美术院校，造型与设计类专业齐全，地缘优势使其成为甘肃、宁夏、青海等地考生的热门目标院校。',
      '## 为什么受西北考生青睐',
      '- 距离近，生活习惯相近，便于考试与就读。',
      '- 地域文化资源丰富，适合写生与创作采风。',
      '## 备考建议',
      '扎实的素描头像与色彩静物是基础，校考往往同样重视画面的完整度。建议以联考标准打牢基础，再针对校考题型做专项训练。',
      'img:${ContentDemo.art('sketch-bust-2')}',
      '> 招生计划与考试方式以学校当年发布的招生简章为准。',
    ],
  ),
  _Article(
    id: 9009,
    title: '集训三个月的备考经验与时间安排',
    headline: '备考经验',
    tags: const ['经验', '集训', '时间安排'],
    cover: ContentDemo.art('sketch-still-1'),
    time: '2026-10-25 20:40:00',
    views: 1268,
    blocks: [
      '以下是示范画室一位学员的集训分享（化名小林）：集训初期她起形慢、画面总是发灰，三个月里按阶段调整练习重点，慢慢找到了适合自己的节奏。',
      '## 第一个月：只练「形」',
      '「刚来的时候我总想把每个地方画细，结果比例越画越歪。老师让我每天只画两小时结构，不上明暗，一个月后起形速度和准确度都提高了很多。」',
      '## 第二个月：建立黑白灰',
      '「我开始用小稿练明暗关系，每张 30 分钟，只分三个调子。慢慢地，画面不再发灰，暗部也敢压下去了。」',
      'img:${ContentDemo.art('sketch-still-1')}',
      '## 第三个月：限时与复盘',
      '「每周两次限时模拟，结束后对照老师的点评和高分卷找差距，把高频问题写在笔记本上，下一张专门改这一个问题。」',
      '## 老师点评',
      '小林的经验在于目标清晰、问题聚焦。建议每位同学都建立自己的「问题清单」，比盲目加练更有效。',
    ],
  ),
  _Article(
    id: 9010,
    title: '联考前 30 天：作息、练习量与心态调整',
    headline: '考前冲刺',
    tags: const ['冲刺', '作息', '心态'],
    cover: ContentDemo.scene('studio-wall'),
    time: '2026-10-23 18:45:00',
    views: 3374,
    blocks: [
      '距离联考越来越近，很多同学开始焦虑：画得越多越好吗？要不要换画法？以下是我们给冲刺阶段同学的几条建议。',
      '## 作息',
      '- 逐步把作画时间调整到与考试时间一致，让身体在考试时段保持良好状态。',
      '- 每天睡够 7 小时，熬夜赶画只会降低第二天的效率。',
      '## 练习量',
      '- 每天三科都要动笔保持手感，以限时模拟为主，不再追求长期作业。',
      '- 每次模拟后用 10 分钟复盘，记录一个最需要改进的问题。',
      '## 心态',
      '考前状态有起伏很正常。把注意力放在「下一张画要解决什么问题」，而不是「我能考多少分」。',
      '> 画室老师会在每周模拟后发布点评，记得在作品档案里查看。',
    ],
  ),
  _Article(
    id: 9011,
    title: '示范画室秋季写生周圆满结束',
    headline: '画室动态',
    tags: const ['画室', '写生', '活动'],
    cover: ContentDemo.art('color-landscape-1'),
    time: '2026-10-20 17:20:00',
    views: 1638,
    source: '示范画室',
    blocks: [
      '10 月 13 日至 19 日，示范画室组织联考冲刺班和校考提高班学员开展秋季风景写生周。学员们走进乡村与街巷，在真实的光线和环境中完成色彩与速写练习。',
      'img:${ContentDemo.art('color-landscape-1')}',
      '## 写生安排',
      '- 上午：色彩风景写生，重点训练天空、远山与建筑的空间层次。',
      '- 下午：场景速写与人物速写，练习人物与环境的组合。',
      '- 晚上：作品点评与小结，老师逐一讲评当天作品。',
      'img:${ContentDemo.art('speed-scene-1')}',
      '本次写生共完成色彩作品 120 余张、速写 300 余张，优秀作品将在画室作品墙展出。',
    ],
  ),
  _Article(
    id: 9012,
    title: '九月月考优秀作品展评',
    headline: '画室动态',
    tags: const ['月考', '展评', '作品'],
    cover: ContentDemo.art('sketch-geometry-1'),
    time: '2026-10-08 12:00:00',
    views: 862,
    source: '示范画室',
    blocks: [
      '九月月考已完成阅卷，教研组从三个校区中评选出素描、色彩、速写各科优秀作品，供大家学习交流。',
      '## 素描',
      '几何体组合的明暗交界线处理肯定，投影虚实得当，整体完成度高。',
      'img:${ContentDemo.art('sketch-geometry-1')}',
      '## 色彩',
      '静物色调统一，冷暖对比明确，暗部加入了丰富的环境色。',
      'img:${ContentDemo.art('color-still-4')}',
      '## 速写',
      '人物动态自然，衣纹线条疏密有致，画面节奏感强。',
      'img:${ContentDemo.art('speed-figure-5')}',
      '> 个人成绩与点评可在「我的学情」查看。',
    ],
  ),
  _Article(
    id: 9013,
    title: '美术史常识：印象派的色彩革命',
    headline: '美术史',
    tags: const ['美术史', '印象派', '色彩'],
    cover: ContentDemo.art('color-flower-1'),
    time: '2026-10-15 19:30:00',
    views: 1452,
    blocks: [
      '19 世纪后半叶，一批年轻画家走出画室，在户外直接描绘光线下的风景与人物，他们被称为「印象派」。印象派对色彩的理解，至今仍深刻影响着我们的色彩写生。',
      '## 色彩观念的变化',
      '- 物体没有固定不变的颜色，颜色随光线和环境而变化。',
      '- 阴影不是黑色，而是带有冷暖倾向的颜色。',
      '- 用并置的笔触让颜色在观者眼中混合，画面更加明亮。',
      'img:${ContentDemo.art('color-flower-1')}',
      '## 对色彩写生的启发',
      '写生时先观察光源的冷暖，再判断亮部与暗部的色彩倾向；暗部大胆使用补色和环境色，是让画面「透气」的关键。',
      '## 代表画家',
      '莫奈、雷诺阿、德加、毕沙罗等。课后可以找莫奈的《干草堆》系列，对比同一对象在不同时间光线下的色彩变化。',
    ],
  ),
  _Article(
    id: 9014,
    title: '画材怎么选？素描纸、炭笔与水粉颜料指南',
    headline: '画材指南',
    tags: const ['画材', '工具', '新手'],
    cover: ContentDemo.art('detail-sketch'),
    time: '2026-10-12 10:00:00',
    views: 1876,
    blocks: [
      '好的画材不一定贵，但一定要「稳定」——考试时用的工具尽量和平时练习保持一致。',
      '## 素描',
      '- 铅笔：常备 2H–8B，起形用 HB–2B，深入用 4B–8B。',
      '- 炭笔：软中硬各备几支，适合大面积铺调子，注意及时定画。',
      '- 素描纸：选择 160g 以上、纹理适中的纸张，反复擦改不易起毛。',
      '- 橡皮与可塑橡皮：可塑橡皮用来提亮和减弱，不要只靠硬橡皮。',
      'img:${ContentDemo.art('detail-sketch')}',
      '## 色彩',
      '- 水粉颜料：常用色准备大支装，白色消耗快，可多备。',
      '- 画笔：大号平头笔铺色，中小号刻画，另备一支扇形笔处理衔接。',
      '- 调色盒与喷壶：保持颜料湿润，避免干裂结块。',
      '## 速写',
      '速写本加针管笔、钢笔或炭笔任选其一长期使用，形成稳定的线条手感。',
    ],
  ),
  _Article(
    id: 9015,
    title: '文化课与专业课如何平衡：艺考生时间管理',
    headline: '备考经验',
    tags: const ['文化课', '时间管理'],
    cover: ContentDemo.paper('sketch'),
    time: '2026-10-09 20:20:00',
    views: 2087,
    blocks: [
      '对美术生来说，专业课决定「能不能报」，文化课决定「能不能被录取」。两者都不能放松，关键在于不同阶段的侧重。',
      '## 集训期（9 月—联考）',
      '- 以专业为主，每天保留 1 小时文化课，重点是英语单词和语文积累。',
      '- 利用碎片时间背诵，保持语感。',
      '## 校考期（联考后—校考结束）',
      '- 针对目标院校题型做专项训练，文化课每天 2 小时。',
      '## 文化冲刺期（校考后—高考）',
      '- 全力回归文化课，制定每周复习计划，专业课每周画 1–2 张保持手感。',
      '> 时间安排为通用建议，可结合自身情况与老师沟通调整。',
    ],
  ),
  // ── 校园专属（示范画室） ──────────────────────────────────────────────
  _Article(
    id: 9101,
    title: '示范画室 11 月月考安排',
    headline: '月考通知',
    tags: const ['月考', '通知', '三校区'],
    cover: ContentDemo.scene('exam-hall'),
    time: '2026-11-06 18:00:00',
    views: 512,
    source: '示范画室',
    school: true,
    blocks: [
      '各位同学：11 月月考定于 11 月 15 日（周日）在三个校区同步进行，一天考完，考试科目与时间如下。',
      '- 08:30–11:30　素描（180 分钟）',
      '- 14:00–17:00　色彩（180 分钟）',
      '- 19:00–20:00　速写（60 分钟）',
      '## 注意事项',
      '- 请于开考前 20 分钟进入考场，按考号就座。',
      '- 画板、画架由画室统一提供，其余画材自备。',
      '- 阅卷结果将于考后三天内发布在「我的学情」，可查看原卷与评分。',
      'img:${ContentDemo.scene('exam-hall')}',
      '> 示范画室教务处',
    ],
  ),
  _Article(
    id: 9102,
    title: '城东校区色彩写生周（11 月 10 日—16 日）',
    headline: '写生通知',
    tags: const ['写生', '色彩', '城东'],
    cover: ContentDemo.art('color-landscape-1'),
    time: '2026-11-05 09:30:00',
    views: 386,
    source: '示范画室',
    school: true,
    blocks: [
      '为提升色彩风景表现能力，城东校区将于 11 月 10 日至 16 日组织色彩写生周，由刘芳老师带队。',
      '## 准备物品',
      '- 水粉颜料、画笔、调色盒、8 开写生画板',
      '- 小马扎、遮阳帽、保温水杯',
      '## 写生安排',
      '每天 08:00 在画室门口集合，上午风景色彩，下午场景速写，晚上统一讲评。',
      'img:${ContentDemo.art('color-landscape-1')}',
    ],
  ),
  _Article(
    id: 9103,
    title: '联考冲刺班晚自习调整说明',
    headline: '教务通知',
    tags: const ['晚自习', '冲刺班'],
    cover: ContentDemo.scene('studio-wall'),
    time: '2026-11-04 16:10:00',
    views: 298,
    source: '示范画室',
    school: true,
    blocks: [
      '自 11 月 9 日起，联考冲刺 1 班、2 班晚自习时间调整为 19:00—21:30，其中前 60 分钟为速写限时训练，后 90 分钟为个人查漏补缺。',
      '- 周一、周三：人物动态速写（赵雪老师）',
      '- 周二、周四：组合速写（周强老师）',
      '- 周五：本周作品复盘',
      '请各位同学按时签到，如需请假请在「智慧校园」提交申请。',
    ],
  ),
  _Article(
    id: 9104,
    title: '九月月考素描优秀试卷展评',
    headline: '作品展评',
    tags: const ['月考', '素描', '展评'],
    cover: ContentDemo.art('sketch-bust-3'),
    time: '2026-10-30 12:30:00',
    views: 674,
    source: '示范画室',
    school: true,
    blocks: [
      '九月月考素描科目以石膏五官写生为题，以下几份试卷在结构与明暗处理上表现突出。',
      'img:${ContentDemo.art('sketch-bust-3')}',
      '## 李静老师点评',
      '五官的位置先用「三庭五眼」核对再深入，结构清楚；暗部保留了反光，层次丰富。建议下一步加强头发与背景的虚实处理。',
      'img:${ContentDemo.art('sketch-portrait-1')}',
    ],
  ),
  _Article(
    id: 9105,
    title: '校考提高班报名启动',
    headline: '招生动态',
    tags: const ['校考', '报名', '安宁校区'],
    cover: ContentDemo.art('speed-group-1'),
    time: '2026-10-26 10:00:00',
    views: 731,
    source: '示范画室',
    school: true,
    blocks: [
      '为帮助有校考意向的同学做好准备，安宁校区校考提高班现开始报名。',
      '## 课程内容',
      '- 命题创作：构思方法、草图推敲与画面完成',
      '- 素描与速写：人物半身像、组合人物与场景',
      '- 院校考题分析：近年常见题型讲解',
      'img:${ContentDemo.art('speed-group-1')}',
      '报名请联系各班班主任，或在画室前台登记。',
    ],
  ),
  _Article(
    id: 9106,
    title: '画室安全与画材使用规范',
    headline: '画室管理',
    tags: const ['安全', '画材', '规范'],
    cover: ContentDemo.art('sketch-still-2'),
    time: '2026-10-21 08:40:00',
    views: 245,
    source: '示范画室',
    school: true,
    blocks: [
      '为保障大家的作画环境整洁安全，请遵守以下规范：',
      '- 定画液请在通风处使用，用后及时盖紧。',
      '- 美工刀削笔后收好刀片，不要随意放在画架上。',
      '- 洗笔水统一倒入指定水池，避免堵塞下水道。',
      '- 离开画室前关闭台灯与插线板电源。',
      '感谢大家的配合，一起维护良好的学习环境。',
    ],
  ),
];

const _viewsKey = 'content_news_views';

String _html(List<String> blocks) {
  final out = StringBuffer();
  var inList = false;
  for (final raw in blocks) {
    final line = raw.trim();
    final isItem = line.startsWith('- ');
    if (inList && !isItem) {
      out.write('</ul>');
      inList = false;
    }
    if (line.startsWith('## ')) {
      out.write('<h3>${line.substring(3)}</h3>');
    } else if (isItem) {
      if (!inList) {
        out.write('<ul>');
        inList = true;
      }
      out.write('<li>${line.substring(2)}</li>');
    } else if (line.startsWith('img:')) {
      out.write('<p><img src="${DemoMedia.url(line.substring(4))}"></p>');
    } else if (line.startsWith('> ')) {
      out.write(
        '<p style="color:#8B8993;font-size:12px;">${line.substring(2)}</p>',
      );
    } else {
      out.write('<p>$line</p>');
    }
  }
  if (inList) {
    out.write('</ul>');
  }
  return out.toString();
}

/// 资讯数据的只读访问（首页、收藏等共用）。
abstract final class DemoContentNews {
  static _Article? _find(int id) {
    for (final article in _articles) {
      if (article.id == id) {
        return article;
      }
    }
    return null;
  }

  static int _views(_Article article) {
    final extra = DemoStore.map(_viewsKey, () => <String, dynamic>{});
    return article.views + ContentDemo.toInt(extra['${article.id}']);
  }

  /// textbook 列表结构；[detail] 为 true 时附带 `longText1` 正文。
  static Map<String, dynamic> _toJson(_Article a, {bool detail = false}) {
    final cover = ContentDemo.url(a.cover);
    return <String, dynamic>{
      'id': a.id,
      'type': 9,
      'title': a.title,
      'shortText1': a.headline,
      'shortText2': a.tags.join(','),
      'shortText3': cover,
      'img1': <String>[cover],
      'source': a.source,
      'viewCount': _views(a),
      'createTime': a.time,
      'updateTime': a.time,
      'province': '甘肃',
      if (a.school) 'schoolId': '1',
      if (detail) 'longText1': _html(a.blocks),
    };
  }

  static Map<String, dynamic>? find(int id) {
    final article = _find(id);
    return article == null ? null : _toJson(article);
  }

  /// 收藏快照：标题、封面引用、副标题与分享所需字段。
  static ({
    String title,
    String cover,
    String subtitle,
    Map<String, dynamic> payload,
  })?
  favoriteInfo(int id) {
    final article = _find(id);
    if (article == null) {
      return null;
    }
    return (
      title: article.title,
      cover: article.cover,
      subtitle: '${article.headline} · ${article.time.substring(0, 10)}',
      payload: <String, dynamic>{
        'id': article.id,
        'title': article.title,
        'shortText3': article.cover,
        'updateTime': article.time,
        'viewCount': article.views,
      },
    );
  }

  static List<Map<String, dynamic>> _query({
    required bool school,
    String keyword = '',
  }) {
    final matched = demoSearch<_Article>(
      _articles.where((a) => a.school == school).toList(),
      keyword,
      (a) => <String>[a.title, a.headline, ...a.tags],
    )..sort((a, b) => b.time.compareTo(a.time));
    return matched.map(_toJson).toList();
  }

  static List<Map<String, dynamic>> latest({required bool school, int? take}) {
    final all = _query(school: school);
    return take == null ? all : all.take(take).toList();
  }
}

void registerContentNewsFixtures(DemoRouter r) {
  List<Map<String, dynamic>> list(DemoRequest req, {required bool school}) {
    final type = req.str('type');
    if (type.isNotEmpty && type != '9') {
      return const <Map<String, dynamic>>[];
    }
    final all = DemoContentNews._query(
      school: school,
      keyword: req.str('keyword'),
    );
    return ContentDemo.slice(all, req);
  }

  // 资讯列表直接返回数组（资讯页与顶部搜索都按数组解析）。
  r.any('/app/user/textbookList', (req) => list(req, school: false));
  r.any('/app/user/schoolTextbookList', (req) => list(req, school: true));

  r.any('/app/user/textbookDetail', (req) {
    final article = DemoContentNews._find(req.intOf('id'));
    if (article == null) {
      throw const DemoApiException('资讯不存在或已下架');
    }
    final views = DemoStore.map(_viewsKey, () => <String, dynamic>{});
    views['${article.id}'] = ContentDemo.toInt(views['${article.id}']) + 1;
    DemoStore.save(_viewsKey);
    return DemoContentNews._toJson(article, detail: true);
  });

  r.any(
    '/app/user/homeLatestInfo',
    (req) => DemoContentNews.latest(school: false, take: 8),
  );
  r.any(
    '/app/user/schoolHomeLatestInfo',
    (req) => DemoContentNews.latest(school: true),
  );
}
