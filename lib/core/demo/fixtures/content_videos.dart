import '../data/demo_favorites.dart';
import '../demo_backend.dart';
import '../demo_store.dart';
import 'content_common.dart';
import 'content_favorites.dart';

/// 视频中心一级 / 二级分类（`/app/common/menuList` type=6）。
const List<(int, String, List<(int, String)>)> _videoMenus = [
  (11, '素描', [(1101, '几何体'), (1102, '静物'), (1103, '石膏像'), (1104, '头像')]),
  (12, '色彩', [(1201, '静物色彩'), (1202, '风景色彩'), (1203, '色调训练')]),
  (13, '速写', [(1301, '人物动态'), (1302, '场景速写'), (1303, '组合速写')]),
  (14, '创作', [(1401, '命题创作'), (1402, '构图训练')]),
  (15, '设计', [(1501, '平面构成'), (1502, '色彩构成')]),
  (16, '联考解析', [(1601, '真题解析'), (1602, '评分标准')]),
  (17, '校考指导', [(1701, '院校考题'), (1702, '备考规划')]),
];

class _Video {
  const _Video({
    required this.id,
    required this.name,
    required this.sub,
    required this.teacher,
    required this.duration,
    required this.views,
    required this.cover,
    required this.clip,
    required this.steps,
    required this.desc,
    required this.time,
    this.school = false,
  });

  final String id;
  final String name;

  /// 二级分类 id，一级分类由前两位推出（1203 → 12）。
  final int sub;
  final String teacher;
  final String duration;
  final int views;
  final String cover;
  final String clip;

  /// 步骤图（详情页「步骤图」页签）。
  final List<String> steps;
  final String desc;
  final String time;

  /// 校园专属视频（示范画室）。
  final bool school;

  int get menu => sub ~/ 100;

  String get menuName {
    for (final menu in _videoMenus) {
      if (menu.$1 == this.menu) {
        return menu.$2;
      }
    }
    return '';
  }
}

final List<_Video> _videos = <_Video>[
  // ── 素描 ──────────────────────────────────────────────────────────────
  _Video(
    id: '6001',
    name: '石膏几何体结构：从立方体到多面体',
    sub: 1101,
    teacher: '李静',
    duration: '24:18',
    views: 3268,
    cover: ContentDemo.art('sketch-geometry-1'),
    clip: ContentDemo.clip('place-paper'),
    steps: [ContentDemo.paper('sketch'), ContentDemo.art('sketch-geometry-1')],
    desc:
        '从最基础的立方体入手，讲解透视中的视平线、消失点与近大远小，再延伸到多面体与组合几何体的结构穿插。适合刚进入集训的同学建立“结构先行”的观察习惯。',
    time: '2026-11-06 19:30:00',
  ),
  _Video(
    id: '6002',
    name: '排线与明暗五大调子实操',
    sub: 1101,
    teacher: '张明远',
    duration: '18:42',
    views: 4127,
    cover: ContentDemo.paper('sketch'),
    clip: ContentDemo.clip('hatching'),
    steps: [ContentDemo.paper('sketch'), ContentDemo.art('detail-sketch')],
    desc: '高光、亮灰部、明暗交界线、反光、投影——以球体和立方体为例，示范排线的方向、疏密与叠加方法，解决画面发灰、暗部发闷的问题。',
    time: '2026-11-05 20:10:00',
  ),
  _Video(
    id: '6003',
    name: '静物组合起形：瓶罐与衬布',
    sub: 1102,
    teacher: '李静',
    duration: '32:05',
    views: 2846,
    cover: ContentDemo.art('sketch-still-1'),
    clip: ContentDemo.clip('studio'),
    steps: [
      ContentDemo.art('sketch-still-1'),
      ContentDemo.art('sketch-still-3'),
    ],
    desc: '讲解静物组合的构图取舍、物体之间的比例与前后关系，示范用长直线切出大形，再逐步细化瓶口椭圆与衬布褶皱。',
    time: '2026-11-04 19:00:00',
  ),
  _Video(
    id: '6004',
    name: '玻璃器皿与金属质感表现',
    sub: 1102,
    teacher: '张明远',
    duration: '21:36',
    views: 1983,
    cover: ContentDemo.art('sketch-still-2'),
    clip: ContentDemo.clip('hatching'),
    steps: [ContentDemo.art('sketch-still-2')],
    desc: '透明玻璃和反光金属是静物素描的难点。本课示范如何利用环境反射、高光形状与边缘虚实，表现不同材质的质感。',
    time: '2026-11-02 21:00:00',
  ),
  _Video(
    id: '6005',
    name: '石膏像大卫：头部结构与透视',
    sub: 1103,
    teacher: '李静',
    duration: '41:20',
    views: 5310,
    cover: ContentDemo.art('sketch-bust-1'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.art('sketch-bust-1'), ContentDemo.art('detail-sketch')],
    desc: '以大卫石膏像为例，分析头部的骨点、肌肉体块与转面关系，示范从中线、眉弓线入手确定头部透视，再推进到五官和头发的整体刻画。',
    time: '2026-11-01 19:30:00',
  ),
  _Video(
    id: '6006',
    name: '素描头像：五官刻画与三庭五眼',
    sub: 1104,
    teacher: '张明远',
    duration: '36:48',
    views: 4682,
    cover: ContentDemo.art('sketch-portrait-1'),
    clip: ContentDemo.clip('hatching'),
    steps: [
      ContentDemo.art('sketch-portrait-1'),
      ContentDemo.art('detail-sketch'),
    ],
    desc: '用“三庭五眼”快速核对五官比例，再逐一讲解眼、鼻、嘴、耳的结构与明暗规律，最后统一整体关系。',
    time: '2026-10-30 20:00:00',
  ),
  _Video(
    id: '6007',
    name: '长期素描头像深入刻画',
    sub: 1104,
    teacher: '李静',
    duration: '45:12',
    views: 2241,
    cover: ContentDemo.art('sketch-bust-2'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.art('sketch-bust-2'), ContentDemo.art('sketch-bust-3')],
    desc: '长期作业如何避免“越画越碎”？本课示范分阶段推进：大关系—结构细化—质感刻画—整体调整，并讲解每个阶段的检查方法。',
    time: '2026-10-27 19:40:00',
  ),
  // ── 色彩 ──────────────────────────────────────────────────────────────
  _Video(
    id: '6008',
    name: '水粉静物：冷暖关系与色彩倾向',
    sub: 1201,
    teacher: '刘芳',
    duration: '28:16',
    views: 3895,
    cover: ContentDemo.art('color-still-1'),
    clip: ContentDemo.clip('place-paper'),
    steps: [ContentDemo.paper('color'), ContentDemo.art('color-still-1')],
    desc: '理解光源色、固有色与环境色的关系，示范如何确定画面的冷暖倾向，让亮部与暗部形成对比又统一在同一色调中。',
    time: '2026-11-06 14:20:00',
  ),
  _Video(
    id: '6009',
    name: '蔬果静物色彩写生示范',
    sub: 1201,
    teacher: '王海波',
    duration: '33:40',
    views: 2512,
    cover: ContentDemo.art('detail-color'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.art('detail-color'), ContentDemo.art('color-still-5')],
    desc: '完整示范一张 3 小时蔬果静物：铺大色、塑造体积、刻画质感与调整整体，重点讲解蔬果固有色的冷暖变化。',
    time: '2026-11-03 15:00:00',
  ),
  _Video(
    id: '6010',
    name: '风景色彩：天空与远山的空间层次',
    sub: 1202,
    teacher: '刘芳',
    duration: '26:55',
    views: 2177,
    cover: ContentDemo.art('color-landscape-1'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.art('color-landscape-1')],
    desc: '风景写生中如何拉开近、中、远景的空间？本课从色彩的纯度、明度与冷暖三方面讲解空间层次的表现方法。',
    time: '2026-10-31 16:30:00',
  ),
  _Video(
    id: '6011',
    name: '花卉色彩：边缘虚实与笔触',
    sub: 1203,
    teacher: '王海波',
    duration: '22:10',
    views: 1764,
    cover: ContentDemo.art('color-flower-1'),
    clip: ContentDemo.clip('hatching'),
    steps: [ContentDemo.art('color-flower-1')],
    desc: '花卉的难点在于形态多变与色彩丰富。本课示范如何概括花头的大形，用笔触的方向和厚薄表现花瓣的虚实与层次。',
    time: '2026-10-28 15:10:00',
  ),
  _Video(
    id: '6012',
    name: '暖色调与冷色调画面统一训练',
    sub: 1203,
    teacher: '刘芳',
    duration: '19:48',
    views: 2036,
    cover: ContentDemo.art('color-still-4'),
    clip: ContentDemo.clip('place-paper'),
    steps: [ContentDemo.art('color-still-4'), ContentDemo.art('color-still-3')],
    desc: '同一组静物分别画成暖色调与冷色调，对比讲解如何用背景和衬布统一画面色调，适合色彩分数卡在 70 分左右的同学。',
    time: '2026-10-25 14:40:00',
  ),
  // ── 速写 ──────────────────────────────────────────────────────────────
  _Video(
    id: '6013',
    name: '人物动态线：重心与动势',
    sub: 1301,
    teacher: '赵雪',
    duration: '16:32',
    views: 3540,
    cover: ContentDemo.art('speed-figure-1'),
    clip: ContentDemo.clip('hatching'),
    steps: [ContentDemo.paper('speed'), ContentDemo.art('speed-figure-1')],
    desc: '用“一竖两横”快速找准重心线、肩线与胯线，讲解站、走、坐等常见动态的规律，帮助大家告别僵硬的“木头人”。',
    time: '2026-11-05 21:30:00',
  ),
  _Video(
    id: '6014',
    name: '站姿坐姿人物比例速写',
    sub: 1301,
    teacher: '周强',
    duration: '20:14',
    views: 2398,
    cover: ContentDemo.art('speed-figure-3'),
    clip: ContentDemo.clip('place-paper'),
    steps: [ContentDemo.paper('speed'), ContentDemo.art('speed-figure-3')],
    desc: '以头长为单位讲解站姿七个半头、坐姿五个半头左右的比例关系，以及透视变化下的比例调整方法。',
    time: '2026-11-02 20:40:00',
  ),
  _Video(
    id: '6015',
    name: '衣纹处理：疏密与节奏',
    sub: 1301,
    teacher: '赵雪',
    duration: '17:45',
    views: 1921,
    cover: ContentDemo.art('speed-figure-5'),
    clip: ContentDemo.clip('hatching'),
    steps: [
      ContentDemo.art('speed-figure-5'),
      ContentDemo.art('speed-figure-2'),
    ],
    desc: '衣纹不是越多越好。本课讲解关节处的挤压褶、悬垂褶等常见衣纹的规律，以及如何用疏密对比让画面更有节奏。',
    time: '2026-10-29 21:00:00',
  ),
  _Video(
    id: '6016',
    name: '街景场景速写：透视与人物配景',
    sub: 1302,
    teacher: '周强',
    duration: '29:30',
    views: 1688,
    cover: ContentDemo.art('speed-scene-1'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.art('speed-scene-1')],
    desc: '场景速写先定视平线和消失点，再安排主体人物与配景。本课以街市为例，示范从构图到完成的全过程。',
    time: '2026-10-26 20:20:00',
  ),
  _Video(
    id: '6017',
    name: '三人组合速写构图',
    sub: 1303,
    teacher: '赵雪',
    duration: '25:08',
    views: 2105,
    cover: ContentDemo.art('speed-group-1'),
    clip: ContentDemo.clip('studio'),
    steps: [
      ContentDemo.art('speed-group-1'),
      ContentDemo.art('speed-figure-4'),
    ],
    desc: '组合速写考察人物之间的关系与画面组织。本课讲解三人组合的前后遮挡、大小对比与视觉中心的安排。',
    time: '2026-10-23 21:10:00',
  ),
  // ── 创作 / 设计 ───────────────────────────────────────────────────────
  _Video(
    id: '6018',
    name: '命题创作：从草图到完整画面',
    sub: 1401,
    teacher: '吴雨桐',
    duration: '34:12',
    views: 1432,
    cover: ContentDemo.art('color-still-5'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.art('speed-group-1'), ContentDemo.art('color-still-5')],
    desc: '拿到命题后如何快速构思？本课讲解审题、立意、草图推敲与画面完成四个步骤，并分析常见的构思误区。',
    time: '2026-10-30 15:00:00',
  ),
  _Video(
    id: '6019',
    name: '构图九宫格与视觉中心',
    sub: 1402,
    teacher: '李静',
    duration: '15:36',
    views: 2659,
    cover: ContentDemo.art('sketch-still-3'),
    clip: ContentDemo.clip('place-paper'),
    steps: [
      ContentDemo.art('sketch-still-3'),
      ContentDemo.art('sketch-still-1'),
    ],
    desc: '用九宫格辅助判断主体位置，讲解饱满、均衡、留白等构图原则，以及动笔前画小构图的方法。',
    time: '2026-10-24 19:20:00',
  ),
  _Video(
    id: '6020',
    name: '平面构成：点线面的组织',
    sub: 1501,
    teacher: '吴雨桐',
    duration: '23:44',
    views: 1215,
    cover: ContentDemo.paper('speed'),
    clip: ContentDemo.clip('place-paper'),
    steps: [ContentDemo.paper('speed'), ContentDemo.paper('sketch')],
    desc: '设计基础入门：讲解点、线、面的视觉属性以及重复、渐变、对比等构成形式，适合有设计类专业意向的同学。',
    time: '2026-10-21 16:00:00',
  ),
  _Video(
    id: '6021',
    name: '色彩构成：明度推移与色相环',
    sub: 1502,
    teacher: '刘芳',
    duration: '21:20',
    views: 1376,
    cover: ContentDemo.paper('color'),
    clip: ContentDemo.clip('place-paper'),
    steps: [ContentDemo.paper('color'), ContentDemo.art('color-still-3')],
    desc: '通过明度推移、纯度推移和色相环练习，建立对色彩三要素的直观认识，也为写生中的色彩判断打下基础。',
    time: '2026-10-19 15:30:00',
  ),
  // ── 联考解析 / 校考指导 ───────────────────────────────────────────────
  _Video(
    id: '6022',
    name: '联考素描真题解析（示例）',
    sub: 1601,
    teacher: '李静',
    duration: '38:25',
    views: 4876,
    cover: ContentDemo.scene('exam-hall'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.paper('sketch'), ContentDemo.art('sketch-geometry-1')],
    desc: '以示例真题为蓝本，讲解审题要点、考场时间分配与高分卷的共同特征。题目与分值为教学示例，具体以当年考试院发布为准。',
    time: '2026-11-04 10:00:00',
  ),
  _Video(
    id: '6023',
    name: '联考色彩评分标准逐档解读（示例）',
    sub: 1602,
    teacher: '刘芳',
    duration: '27:50',
    views: 3654,
    cover: ContentDemo.paper('color'),
    clip: ContentDemo.clip('place-paper'),
    steps: [ContentDemo.paper('color'), ContentDemo.art('color-still-2')],
    desc: '对照不同档次的示例试卷，讲解阅卷老师关注的色调、造型、空间与完整度，帮助大家明确提分方向。',
    time: '2026-10-28 10:30:00',
  ),
  _Video(
    id: '6024',
    name: '校考速写命题趋势与应对',
    sub: 1701,
    teacher: '赵雪',
    duration: '31:15',
    views: 2289,
    cover: ContentDemo.art('speed-figure-4'),
    clip: ContentDemo.clip('hatching'),
    steps: [
      ContentDemo.art('speed-figure-4'),
      ContentDemo.art('speed-scene-1'),
    ],
    desc: '梳理近年校考速写常见的命题方向（生活场景、组合人物、主题表达），并给出对应的训练方法。题型分析为教学示例。',
    time: '2026-10-22 20:00:00',
  ),
  _Video(
    id: '6025',
    name: '校考备考时间规划：集训到考前',
    sub: 1702,
    teacher: '吴雨桐',
    duration: '18:20',
    views: 1957,
    cover: ContentDemo.scene('studio-wall'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.scene('studio-wall')],
    desc: '联考结束后到校考之间时间紧、任务重。本课讲解如何根据目标院校安排专项训练、作品集整理与文化课复习。',
    time: '2026-10-18 19:00:00',
  ),
  // ── 校园专属（示范画室） ──────────────────────────────────────────────
  _Video(
    id: '7001',
    name: '九月月考素描讲评：石膏五官常见问题',
    sub: 1103,
    teacher: '李静',
    duration: '26:40',
    views: 486,
    cover: ContentDemo.art('sketch-bust-3'),
    clip: ContentDemo.clip('studio'),
    steps: [
      ContentDemo.art('sketch-bust-3'),
      ContentDemo.art('sketch-portrait-1'),
    ],
    desc: '示范画室九月月考素描讲评：逐一分析五官比例偏差、暗部发闷、背景处理等高频问题，并展示优秀试卷。',
    time: '2026-11-06 21:00:00',
    school: true,
  ),
  _Video(
    id: '7002',
    name: '城东校区色彩写生课：户外风景示范',
    sub: 1202,
    teacher: '刘芳',
    duration: '35:18',
    views: 352,
    cover: ContentDemo.art('color-landscape-1'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.art('color-landscape-1')],
    desc: '写生周现场录制：刘芳老师在户外完整示范一张色彩风景，讲解如何快速捕捉光线与色调。',
    time: '2026-11-05 18:30:00',
    school: true,
  ),
  _Video(
    id: '7003',
    name: '速写晚自习：人物动态默写训练',
    sub: 1301,
    teacher: '赵雪',
    duration: '19:05',
    views: 418,
    cover: ContentDemo.art('speed-figure-2'),
    clip: ContentDemo.clip('hatching'),
    steps: [ContentDemo.art('speed-figure-2'), ContentDemo.paper('speed')],
    desc: '联考冲刺班晚自习实录：先观察模特 3 分钟，再凭记忆完成动态速写，训练默写能力。',
    time: '2026-11-04 21:40:00',
    school: true,
  ),
  _Video(
    id: '7004',
    name: '新生入学：画板、画材准备与削笔',
    sub: 1101,
    teacher: '张明远',
    duration: '12:30',
    views: 621,
    cover: ContentDemo.art('detail-sketch'),
    clip: ContentDemo.clip('place-paper'),
    steps: [ContentDemo.art('detail-sketch')],
    desc: '新生必看：画板固定画纸、铅笔削法、可塑橡皮的使用等基础准备，养成良好的作画习惯。',
    time: '2026-10-31 10:00:00',
    school: true,
  ),
  _Video(
    id: '7005',
    name: '月考色彩试卷展评：静物色调统一',
    sub: 1203,
    teacher: '王海波',
    duration: '22:46',
    views: 297,
    cover: ContentDemo.art('color-still-3'),
    clip: ContentDemo.clip('place-paper'),
    steps: [ContentDemo.art('color-still-3'), ContentDemo.art('color-still-4')],
    desc: '城西校区十月月考色彩讲评：对比高分卷与中等卷在色调统一、环境色运用上的差距。',
    time: '2026-10-29 20:30:00',
    school: true,
  ),
  _Video(
    id: '7006',
    name: '联考冲刺班：素描限时三小时全程示范',
    sub: 1601,
    teacher: '李静',
    duration: '58:12',
    views: 734,
    cover: ContentDemo.art('sketch-portrait-1'),
    clip: ContentDemo.clip('studio'),
    steps: [
      ContentDemo.art('sketch-portrait-1'),
      ContentDemo.art('sketch-bust-1'),
    ],
    desc: '按联考时间要求完整示范一张素描头像，节奏与考场一致，适合考前反复观看。',
    time: '2026-10-27 09:00:00',
    school: true,
  ),
  _Video(
    id: '7007',
    name: '组合速写课堂实录：三人场景构图',
    sub: 1303,
    teacher: '周强',
    duration: '24:36',
    views: 263,
    cover: ContentDemo.art('speed-group-1'),
    clip: ContentDemo.clip('hatching'),
    steps: [ContentDemo.art('speed-group-1')],
    desc: '安宁校区组合速写课实录：讲解人物前后关系与场景道具的安排。',
    time: '2026-10-24 20:00:00',
    school: true,
  ),
  _Video(
    id: '7008',
    name: '校考提高班：创作构思与小稿推敲',
    sub: 1401,
    teacher: '吴雨桐',
    duration: '31:50',
    views: 189,
    cover: ContentDemo.art('color-still-5'),
    clip: ContentDemo.clip('studio'),
    steps: [ContentDemo.art('color-still-5'), ContentDemo.art('speed-scene-1')],
    desc: '校考提高班课堂：围绕“生活中的温度”命题，示范从多个小稿中挑选并完善构思。',
    time: '2026-10-20 15:30:00',
    school: true,
  ),
];

const _playsKey = 'content_video_plays';

/// 视频数据的只读访问（收藏等共用）。
abstract final class DemoContentVideos {
  static _Video? _find(String id) {
    for (final video in _videos) {
      if (video.id == id) {
        return video;
      }
    }
    return null;
  }

  static int _plays(_Video video) {
    final extra = DemoStore.map(_playsKey, () => <String, dynamic>{});
    return video.views + ContentDemo.toInt(extra[video.id]);
  }

  static Map<String, dynamic> _toJson(_Video v, String userId) {
    return <String, dynamic>{
      'id': v.id,
      'name': v.name,
      'coverImg': ContentDemo.url(v.cover),
      'duration': v.duration,
      'playCount': _plays(v),
      'vip': 0,
      'isFavorite': DemoFavorites.contains(
        userId,
        DemoFavorites.typeVideo,
        v.id,
      ),
      'firstMenu': '${v.menu}',
      'secondMenu': '${v.sub}',
      'category': v.menuName,
      'teacherName': v.teacher,
      'teacherAvatar': '',
      'createTime': v.time,
    };
  }

  static Map<String, dynamic>? find(String id, String userId) {
    final video = _find(id);
    return video == null ? null : _toJson(video, userId);
  }

  /// 收藏快照：标题、封面引用、副标题与分享所需字段。
  static ({
    String title,
    String cover,
    String subtitle,
    Map<String, dynamic> payload,
  })?
  favoriteInfo(String id) {
    final video = _find(id);
    if (video == null) {
      return null;
    }
    return (
      title: video.name,
      cover: video.cover,
      subtitle: '${video.menuName} · ${video.teacher}',
      payload: <String, dynamic>{
        'id': video.id,
        'name': video.name,
        'coverImg': video.cover,
        'duration': video.duration,
        'playCount': video.views,
        'teacherName': video.teacher,
        'vip': 0,
      },
    );
  }
}

List<Map<String, dynamic>> _menuJson() => <Map<String, dynamic>>[
  for (final menu in _videoMenus)
    <String, dynamic>{
      'id': menu.$1,
      'name': menu.$2,
      'type': 6,
      'children': <Map<String, dynamic>>[
        for (final child in menu.$3)
          <String, dynamic>{
            'id': child.$1,
            'name': child.$2,
            'parentId': menu.$1,
          },
      ],
    },
];

void registerContentVideoFixtures(DemoRouter r) {
  List<Map<String, dynamic>> list(DemoRequest req, {required bool school}) {
    DemoContentFavorites.ensureSeeded(req.account.userId);
    final first = req.str('firstMenu');
    final second = req.str('secondMenu');
    final matched = demoSearch<_Video>(
      _videos
          .where((v) => v.school == school)
          .where((v) => first.isEmpty || '${v.menu}' == first)
          .where((v) => second.isEmpty || '${v.sub}' == second)
          .toList(),
      req.str('keyword'),
      (v) => <String>[v.name, v.teacher, v.menuName, v.desc],
    )..sort((a, b) => b.time.compareTo(a.time));
    final userId = req.account.userId;
    return ContentDemo.slice(
      matched.map((v) => DemoContentVideos._toJson(v, userId)).toList(),
      req,
    );
  }

  Map<String, dynamic> detail(DemoRequest req) {
    final video = DemoContentVideos._find(req.str('id'));
    if (video == null) {
      throw const DemoApiException('视频不存在或已下架');
    }
    DemoContentFavorites.ensureSeeded(req.account.userId);
    final plays = DemoStore.map(_playsKey, () => <String, dynamic>{});
    plays[video.id] = ContentDemo.toInt(plays[video.id]) + 1;
    DemoStore.save(_playsKey);
    final userId = req.account.userId;
    final series = _videos
        .where(
          (v) =>
              v.id != video.id &&
              v.school == video.school &&
              v.menu == video.menu,
        )
        .take(6)
        .map((v) => DemoContentVideos._toJson(v, userId))
        .toList();
    return <String, dynamic>{
      ...DemoContentVideos._toJson(video, userId),
      'url': ContentDemo.url(video.clip),
      'param1': video.steps.map(ContentDemo.url).toList(),
      'param3': video.desc,
      'seriesVideoList': series,
    };
  }

  // 视频列表直接返回数组（视频中心与顶部搜索共用）。
  r.any('/app/user/videoTutorialList', (req) => list(req, school: false));
  r.any('/app/user/schoolVideoTutorialList', (req) => list(req, school: true));
  r.any('/app/user/videoTutorialDetail', detail);
  r.any('/app/user/schoolVideoTutorialDetail', detail);

  r.any('/app/common/menuList', (req) {
    final type = req.intOf('type', 6);
    return type == 6 ? _menuJson() : const <Map<String, dynamic>>[];
  });
}
