import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import 'help_guide_state.dart';

final helpGuideControllerProvider =
    NotifierProvider.autoDispose<HelpGuideController, HelpGuideState>(
      HelpGuideController.new,
    );

class HelpGuideController extends AutoDisposeNotifier<HelpGuideState> {
  @override
  HelpGuideState build() {
    return const HelpGuideState(
      selectedCategoryId: HelpGuideState.allCategoryId,
      categories: _categories,
      items: _items,
    );
  }

  void selectCategory(String categoryId) {
    if (categoryId == state.selectedCategoryId) return;
    if (!state.categories.any((category) => category.id == categoryId)) return;
    state = state.copyWith(selectedCategoryId: categoryId);
  }
}

const _categories = <HelpGuideCategory>[
  HelpGuideCategory(id: HelpGuideState.allCategoryId, label: '全部'),
  HelpGuideCategory(id: 'start', label: '快速上手'),
  HelpGuideCategory(id: 'study', label: '我的学情'),
  HelpGuideCategory(id: 'artworks', label: '作品档案与点评'),
  HelpGuideCategory(id: 'gallery', label: '范画库'),
  HelpGuideCategory(id: 'toolbox', label: '画室工具箱'),
  HelpGuideCategory(id: 'video', label: '视频中心'),
  HelpGuideCategory(id: 'campus', label: '智慧校园'),
  HelpGuideCategory(id: 'ai', label: '小美同学'),
  HelpGuideCategory(id: 'notes', label: '笔记与收藏'),
];

const _items = <HelpGuideItem>[
  HelpGuideItem(
    id: 'start-login',
    categoryId: 'start',
    title: '登录与身份说明',
    subtitle: '快速上手',
    summary: '使用画室登记的手机号登录，系统会按学生、老师等身份展示对应的功能。',
    steps: [
      '打开美术之路，输入画室登记的手机号和密码，勾选「服务协议与隐私政策」后登录。',
      '首次登录后，建议进入「个人中心」点击「编辑资料」，在「账号安全 · 修改密码」中设置新密码。',
      '学生端显示「我的学情」「作品档案」；任课老师、班主任等教职身份显示「班级学情」「作品点评」。',
      '忘记密码时，在登录页点击「忘记密码」，通过短信验证码重新设置。',
    ],
    tip: '身份由画室教务老师统一配置，如发现身份或班级有误，请联系教务老师调整。',
  ),
  HelpGuideItem(
    id: 'start-profile',
    categoryId: 'start',
    title: '完善个人资料',
    subtitle: '快速上手',
    summary: '完善专业方向、擅长科目和目标院校，方便老师了解你的备考目标。',
    steps: [
      '点击左侧导航「个人中心」，再点击「编辑资料」进入「个人信息」。',
      '依次设置头像、姓名、专业方向、擅长科目、所在地区和目标院校。',
      '在「个人简介」里写下当前阶段的目标，例如「联考素描 90 分以上」。',
    ],
    route: RoutePaths.info,
  ),
  HelpGuideItem(
    id: 'study-scores',
    categoryId: 'study',
    title: '查看月考成绩与排名',
    subtitle: '我的学情',
    summary: '每次月考阅卷完成后，成绩会自动同步到「我的学情」。',
    steps: [
      '点击左侧导航「我的学情」，选择要查看的考试。',
      '查看总分、素描 / 色彩 / 速写各科分数与档位，以及在画室和校区内的排名。',
      '打开成长曲线，对比历次考试的分数变化，找到进步明显和需要加强的科目。',
    ],
    tip: '阅卷进行中的考试会显示「阅卷中」，出分后会收到消息通知。',
    route: RoutePaths.studyCenter,
  ),
  HelpGuideItem(
    id: 'study-paper',
    categoryId: 'study',
    title: '查看原卷与评分标准',
    subtitle: '我的学情',
    summary: '对照原卷、阅卷老师评语和档位样卷，找到失分的具体原因。',
    steps: [
      '在「我的学情」中点击某一科成绩，进入该科详情。',
      '点击原卷图片放大查看，可以双指缩放观察画面细节。',
      '阅读评分标准与 A–E 档位说明，对照同档样卷，明确下一次的提升方向。',
    ],
    route: RoutePaths.studyCenter,
  ),
  HelpGuideItem(
    id: 'study-quiz',
    categoryId: 'study',
    title: '美术常识题库练习',
    subtitle: '题库',
    summary: '首页「题库」提供美术史、名作鉴赏、色彩理论等题目，支持顺序练习、随机练习、高频考点和错题本四种方式。',
    steps: [
      '在首页点击「题库」，选择一种练习方式开始答题。',
      '选择答案后会立即显示正误和题目解析；打开右上角「自动下一题」，答完会自动进入下一题。',
      '做错的题目会自动收进「错题本」，在错题本中答对后会自动移出。',
    ],
    route: RoutePaths.camp,
  ),
  HelpGuideItem(
    id: 'artworks-upload',
    categoryId: 'artworks',
    title: '上传日常作品',
    subtitle: '作品档案',
    summary: '把每天的作业拍照上传，作品会按时间和科目自动归档，形成个人成长档案。',
    steps: [
      '点击左侧导航「作品档案」，选择上传作品。',
      '拍照或从相册选择作品照片，拍摄时尽量正对画面、光线均匀、避免反光。',
      '选择科目并填写作品名称，提交后等待任课老师点评。',
    ],
    tip: '老师点评后会收到消息提醒，可以在作品详情中查看点评意见。',
    route: RoutePaths.artworks,
  ),
  HelpGuideItem(
    id: 'artworks-review',
    categoryId: 'artworks',
    title: '老师在线点评作品',
    subtitle: '作品点评',
    summary: '任课老师在「作品点评」中查看学生上传的作品，给出文字点评和评分。',
    steps: [
      '以老师身份登录后，点击左侧导航「作品点评」，查看待点评的作品。',
      '打开作品写下点评意见，可以参照联考标准给出档位和分数。',
      '提交后学生会收到通知，点评记录会保存在学生的作品档案中。',
    ],
    route: RoutePaths.artworks,
  ),
  HelpGuideItem(
    id: 'gallery-browse',
    categoryId: 'gallery',
    title: '浏览与收藏范画',
    subtitle: '范画库',
    summary: '范画库按素描、色彩、速写和高分卷分类，适合临摹和对比学习。',
    steps: [
      '点击左侧导航「范画库」，切换科目分类浏览范画。',
      '点击范画查看大图，双指缩放观察局部的笔触和处理方法。',
      '点击收藏后，范画会出现在「我的收藏」中，方便反复临摹。',
    ],
    route: RoutePaths.gallery,
  ),
  HelpGuideItem(
    id: 'toolbox-check',
    categoryId: 'toolbox',
    title: '明度检查与镜像对比',
    subtitle: '画室工具箱',
    summary: '用去色明度和镜像翻转检查作品，快速发现黑白灰层次和造型上的问题。',
    steps: [
      '点击左侧导航「画室工具箱」，选择「明度检查」，拍摄或导入作品照片。',
      '观察去色后的画面，检查亮、灰、暗三大层次是否拉开。',
      '使用「镜像」把作品左右翻转，歪斜和比例问题会变得一目了然。',
      '「构图网格」可以叠加辅助线检查构图，「取色色卡」可以吸取画面颜色对比色相与明度。',
    ],
    route: RoutePaths.artToolbox,
  ),
  HelpGuideItem(
    id: 'toolbox-timer',
    categoryId: 'toolbox',
    title: '速写计时与考试倒计时',
    subtitle: '画室工具箱',
    summary: '按考试节奏做限时训练，并随时掌握距离考试的天数。',
    steps: [
      '在「画室工具箱」中选择「速写计时」，设置每张的时长，例如 2 分钟动态或 15 分钟慢写。',
      '计时结束时会提示换下一张，适合晚自习集中训练。',
      '「考试倒计时」显示距离联考的剩余天数，帮助安排各阶段的练习计划。',
    ],
    route: RoutePaths.artToolbox,
  ),
  HelpGuideItem(
    id: 'video-course',
    categoryId: 'video',
    title: '观看专项课程',
    subtitle: '视频中心',
    summary: '视频中心提供排线、起形、铺色、速写动态等专项课程和老师示范。',
    steps: [
      '点击左侧导航「视频中心」，按分类选择课程。',
      '播放时可以调整倍速、拖动进度，或全屏观看示范细节。',
      '喜欢的课程可以收藏，之后在「我的收藏」中继续学习。',
    ],
    route: RoutePaths.videoTutorial,
  ),
  HelpGuideItem(
    id: 'campus-daily',
    categoryId: 'campus',
    title: '课表、考勤与宿舍',
    subtitle: '智慧校园',
    summary: '智慧校园集中展示课表、考勤签到、宿舍等画室日常信息。',
    steps: [
      '点击左侧导航「智慧校园」，首页显示今天的课程安排。',
      '在考勤中查看自己的签到记录，异常记录可以联系班主任处理。',
      '住校学生可以查看宿舍和床位信息，宿管老师在宿管端完成查寝。',
    ],
    tip: '不同身份看到的智慧校园首页不同，班主任和管理员还可以查看班级与校区的统计数据。',
    route: RoutePaths.smartCampus,
  ),
  HelpGuideItem(
    id: 'campus-circle',
    categoryId: 'campus',
    title: '班级群聊与校圈',
    subtitle: '智慧校园',
    summary: '班级群聊用于接收通知和交流，校圈用来分享作品、写生日记和画室日常。',
    steps: [
      '在「智慧校园」进入班级群聊，查看老师发布的通知并参与讨论。',
      '在首页点击「校圈」，可以在「卡片」和「大图」两种浏览方式之间切换。',
      '点击页头的「发布动态」分享图片或视频，还可以点赞、评论和收藏。',
    ],
    route: RoutePaths.circle,
  ),
  HelpGuideItem(
    id: 'ai-ask',
    categoryId: 'ai',
    title: '向小美同学提问',
    subtitle: '小美同学',
    summary: '小美同学是美术答疑助手，可以回答素描、色彩、速写和备考安排等美术常识问题。',
    steps: [
      '点击左侧导航「小美同学」，选择推荐问题或直接输入你的问题。',
      '开启「深度思考」可以先看到小美同学的思考过程，回答会更有条理。',
      '历史对话保存在左侧列表中，可以随时继续追问或删除。',
    ],
    tip: '回答由模型生成，仅供学习参考，作品评价请以任课老师的意见为准。',
    route: RoutePaths.personalAi,
  ),
  HelpGuideItem(
    id: 'ai-tips',
    categoryId: 'ai',
    title: '把问题问具体',
    subtitle: '小美同学',
    summary: '说明科目、题材和遇到的困难，小美同学的回答会更贴近你的问题。',
    steps: [
      '写明科目和题材，例如「色彩静物里白色衬布的暗部怎么画」。',
      '补充当前遇到的困难，例如「画面总是发灰」「结构总是画歪」。',
      '想请老师看作品时，把作品上传到「作品档案」，由任课老师点评。',
    ],
    route: RoutePaths.personalAi,
  ),
  HelpGuideItem(
    id: 'notes-write',
    categoryId: 'notes',
    title: '记录手写笔记',
    subtitle: '我的笔记',
    summary: '用手写笔记记录老师讲评的要点、构图小稿和自己的改进方法，方便考前复习。',
    steps: [
      '点击左侧导航「我的笔记」，先新建一个笔记分类，例如「素描讲评」。',
      '新建笔记时选择白纸或网格纸样式，用手指或触控笔直接书写、画草图。',
      '书写时可以撤销、清空或放大画布，完成后点击保存；笔记支持重命名和删除。',
    ],
    route: RoutePaths.myNotes,
  ),
  HelpGuideItem(
    id: 'notes-collection',
    categoryId: 'notes',
    title: '管理我的收藏',
    subtitle: '我的收藏',
    summary: '范画、视频和资讯都可以收藏，统一在「我的收藏」中查看。',
    steps: [
      '在范画库、视频中心或资讯页面点击收藏按钮。',
      '点击左侧导航「我的收藏」，按全部、范画、视频、资讯分类查看。',
      '再次点击收藏按钮即可取消收藏。',
    ],
    route: RoutePaths.myCollection,
  ),
];
