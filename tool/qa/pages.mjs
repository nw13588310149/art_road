// 走查页面清单：每一步都从 route 重新载入（登录态保存在浏览器存储里），
// 再按 actions 依次点击（按无障碍名称匹配，字符串按包含匹配）。
// 新增页面时在对应角色下追加步骤即可。

const nav = (label) => ({ click: label, after: 1800 });
// 身份第一次进首页会弹新手引导（弹出即记为已看过），截首页本身前先关掉；没弹就跳过这一步。
const skipGuide = { click: '跳过', optional: true, attempts: 4, after: 800 };
// 首页对所有身份是同一套版式：九宫格与最新资讯在，按身份的卡片不在（它们在「今日」页）。
const homeStep = {
  id: 'home',
  route: '/',
  actions: [
    skipGuide,
    { check: /^作品墙$/ }, { check: /^题库$/ }, { check: /^最新$/ },
    { check: /^今日任务$/, absent: true }, { check: /^今日待办$/, absent: true },
    { check: '今日新交作品', absent: true },
  ],
  settle: 1800,
};
// 「今日」页：从侧栏进入，必须看到进度、清单和这个身份的内容。
const todayStep = (label, checks) => ({
  id: 'today',
  route: '/',
  actions: [
    skipGuide, nav(label),
    { check: /今日进度/ }, { check: /^今日清单$/ }, { check: /近 7 天完成/ },
    ...checks,
  ],
  settle: 1200,
});
// 首页周历会滚到「今天」，后半周时周一在可视区外、点不到，所以点今天这一格。
const todayChip = new RegExp(`^周${'日一二三四五六'[new Date().getDay()]}`);
const guideStep = {
  id: 'guide',
  route: '/help-guide',
  actions: [{ click: /^新手引导$/, after: 1500 }],
};
const noticeStep = {
  id: 'notices',
  route: '/',
  actions: [skipGuide, { click: /^通知/, after: 1500 }],
};
// 进入二级页后必须能看到的控件（工作台上没有），避免停在工作台也算通过。
const campusPageChecks = {
  classes: [{ check: /^创建班级$/, role: 'button' }],
  face: [{ check: /^上传照片$/, role: 'button' }],
  'my-class': [{ check: /^我的班级$/, role: 'heading' }],
  // 课堂考勤只读：看到课情况，没有签到按钮。
  'check-in': [
    { check: /^历史记录$/, role: 'button' }, { check: /^到课情况$/ },
    { check: /^上课签到$|^下课签到$/, absent: true },
  ],
  // 课程只有一种：课表和签课页上没有课型、申请和审核入口。
  schedule: [{ check: /申请小课|申请记录|小课审核|^大课$|^小课$/, absent: true }],
  sign: [{ check: /大课管理|小课管理|^大课$|^小课$/, absent: true }],
  grades: [{ check: /^全部考试$/, role: 'button' }],
  'dorm-check': [{ check: /^申请补卡$/, role: 'button' }],
  notice: [{ check: /^发布通知$/, role: 'button' }],
  'homework-review': [{ check: '待批改人次' }, { check: /^发布作品$/, role: 'button' }],
  workbench: [{ check: /发布通知/, role: 'button' }],
  'leave-approval': [{ check: /^待家长确认$/, role: 'button' }],
  'home-school': [{ check: '会话总数' }],
  'dorm-dynamic': [{ check: /^查寝记录$/, role: 'button' }],
};
const campusAction = (id, label) => ({
  id: `campus-${id}`,
  route: '/smart-campus',
  actions: [
    { wait: 1200 }, { click: label, after: 2200 },
    ...(['schedule', 'my-schedule'].includes(id) ? [
      { check: '教学周' }, { check: /^节次$/ },
    ] : []),
    ...(id === 'exam-review' ? [
      { click: '2026 年 10 月月考', after: 500 },
      { check: '已提交 14 人，共 14 人' },
      { check: /^评分$/, role: 'button' },
    ] : []),
    ...(id === 'circle-governance' ? [
      { check: '待处理' }, { check: '已处理' }, { check: '全部动态' },
    ] : []),
    ...(campusPageChecks[id] ?? []),
  ],
});
// 二级页里的子视图（页签、抽屉、弹窗）：先从工作台点进 entry，再执行 actions。
const campusSub = (id, entry, actions) => ({
  id: `campus-${id}`,
  route: '/smart-campus',
  actions: [{ wait: 1200 }, { click: entry, after: 2200 }, ...actions],
});
// 查寝历史日期条上「前天」那一格（条上是到今天为止的 14 天）及对应的日期文字。
const dormHistoryDay = new Date(Date.now() - 2 * 86400000);
const dormHistoryDayCell = new RegExp(
  `^${'日一二三四五六'[dormHistoryDay.getDay()]}\\s*${dormHistoryDay.getDate()}$`,
);
const dormHistoryDayText = [
  dormHistoryDay.getFullYear(),
  String(dormHistoryDay.getMonth() + 1).padStart(2, '0'),
  String(dormHistoryDay.getDate()).padStart(2, '0'),
].join('-');

const scheduleNextWeek = (label) => ({
  id: 'campus-schedule-next-week',
  route: '/smart-campus',
  actions: [
    { wait: 1200 }, label, { check: '教学周' },
    { click: /^下一周$/, after: 900 }, { check: /教学周第\s*13\s*周/ },
    { check: /^节次$/ },
  ],
});

// 第三项是看画分析工具用的示例画作（选图区里的缩略图名称）。
const toolSteps = [
  ['tool-value', '明度检查', '大卫石膏像'],
  ['tool-blur', '眯眼模糊', '暖调静物'],
  ['tool-simplify', '色块简化', '暖调静物'],
  ['tool-temperature', '冷暖分布', '冷调静物'],
  ['tool-edges', '轮廓线稿', '素描静物'],
  ['tool-mirror', '镜像翻转', '大卫石膏像'],
  ['tool-color', '取色', '花卉静物'],
  ['tool-measure', '比例测量', '大卫石膏像'],
  ['tool-grid', '构图网格', '秋日风景'],
  ['tool-perspective', '透视辅助', '石膏几何体'],
  ['tool-portrait', '头像比例', '大卫石膏像'],
  ['tool-sketch', '速写计时', null, '练习训练'],
  ['tool-figure', '人体比例参考', null, '练习训练'],
  ['tool-value-order', '明度排序训练', null, '练习训练'],
  ['tool-countdown', '考试倒计时', null, '备考助手'],
  ['tool-score', '综合分计算器', null, '备考助手'],
  ['tool-checklist', '考场物品清单', null, '备考助手'],
].map(([id, label, sample, group]) => ({
  id,
  route: '/toolbox',
  actions: [
    ...(group ? [{ click: group, after: 250 }] : []),
    { click: label, after: 2000 },
    ...(sample ? [{ click: sample, after: 2500 }] : []),
  ],
}));

const sharedContent = [
  {
    id: 'ai', route: '/', actions: [
      nav(/^小美同学$/), { check: '我是小美同学，很高兴见到你！' },
      { check: /切换模型，当前 DeepSeek/, role: 'button' },
    ],
  },
  {
    id: 'ai-model', route: '/personal-Ai', actions: [
      { click: /切换模型，当前 DeepSeek/, after: 300 }, { click: /^Doubao$/, role: 'menuitem' },
      { check: /切换模型，当前 Doubao/, role: 'button' },
      { click: /^联网搜索$/, after: 400 },
    ],
  },
  {
    id: 'ai-send', route: '/personal-Ai', actions: [
      { click: /明暗五大调子分别是什么？/, after: 350 },
      { click: /^发送$/, after: 2400 }, { check: /受光最直接/ },
    ],
  },
  {
    id: 'ai-history', route: '/personal-Ai', actions: [
      { click: /^色彩画面发灰怎么调整？$/, after: 350 },
      { click: /^发送$/, after: 2400 },
      { check: /^复制$/, role: 'button' },
      { click: /^对话操作$/, after: 350 }, { click: /^删除$/, after: 350 },
      { check: /^删除会话$/ },
      { click: /^确认$/, after: 900 },
      { check: '我是小美同学，很高兴见到你！' },
    ],
  },
  {
    id: 'ai-attachment', route: '/personal-Ai', actions: [
      {
        uploadText: { name: '构图练习.txt', content: '观察静物之间的疏密关系。' },
        into: /^添加附件$/,
      },
      { click: /预览附件 构图练习\.txt/, after: 500 },
      { check: '当前文件类型暂不支持在线预览' },
      { check: '复制文件地址', role: 'button' },
    ],
  },
  {
    id: 'ebooks-nav',
    route: '/',
    actions: [nav('电子书刊'), { check: '编辑推荐' }],
  },
  { id: 'courseware', route: '/', actions: [nav('校园资料')] },
  {
    id: 'gallery-nav',
    route: '/',
    actions: [nav('素材中心'), { check: '全部题材' }],
  },
  {
    id: 'topics-nav',
    route: '/',
    actions: [nav('优秀课件'), { check: '全部课件' }],
  },
  {
    id: 'courseware-speed',
    route: '/',
    actions: [
      nav('校园资料'),
      { click: /^速写课程/, role: 'button' },
      { check: /速写课堂实录|速写晚自习/ },
    ],
  },
  { id: 'cloud', route: '/', actions: [nav('我的云盘')] },
  { id: 'video', route: '/', actions: [nav('视频中心')] },
  {
    id: 'video-detail',
    route: '/',
    actions: [nav('视频中心'), { click: /石膏几何体结构/, after: 2500 }],
  },
  { id: 'notes', route: '/personal-center', actions: [
    { click: /^我的笔记$/, after: 1800 }, { check: /^新建笔记$/ },
  ] },
  { id: 'collection', route: '/personal-center', actions: [
    { click: /^我的收藏$/, after: 1800 }, { check: /^范画$/ },
  ] },
  { id: 'cloud-folder', route: '/courseware', actions: [
    { click: /石膏几何体/, role: 'group', after: 700 }, { check: '上传资料' },
  ] },
  { id: 'cloud-create', route: '/courseware', actions: [
    { click: /^新建文件夹$/, after: 400 },
    { type: '构图练习资料', into: '请输入文件夹名称' },
    { click: /^创建$/, after: 800 }, { check: /构图练习资料/ },
  ] },
  { id: 'notes-create', route: '/my-notes', actions: [
    { click: /^新建笔记$/, after: 400 },
    { type: '构图观察记录', into: '请输入笔记标题' },
    { click: /^确认$/, after: 500 }, { check: '请选择您的笔记样式' },
    { click: /^白纸$/, after: 200 }, { click: /^下一步$/, after: 600 },
    { check: /^保存$/ }, { check: '画笔粗细' },
    { drag: [[560, 330], [700, 430]], after: 300 },
    { check: /^撤销$/, role: 'button', enabled: true },
    { click: /^保存$/, after: 1800 }, { check: '构图观察记录' },
    { check: /^新建笔记$/, role: 'button' },
    { click: /构图观察记录/, after: 900 },
    { check: /^保存$/, role: 'button' },
    { check: /^撤销$/, role: 'button', enabled: true },
  ] },
  { id: 'collection-art', route: '/my-collection', actions: [
    { click: /^范画$/, after: 600 }, { check: /石膏像大卫/ },
  ] },
  { id: 'collection-books', route: '/my-collection', actions: [
    { click: /^书刊$/, after: 600 }, { check: /色彩静物冷暖关系/ },
  ] },

  { id: 'personal', route: '/', actions: [nav('个人中心')] },
  { id: 'personal-membership', route: '/personal-center', actions: [{ check: '年卡 365 天' }, { check: '季卡 90 天' }] },
  { id: 'personal-edit', route: '/personal-center', actions: [/^编辑资料$/, { check: '姓名' }] },
  { id: 'personal-gender', route: '/info', actions: [/^性别/, { check: '请选择性别' }] },
  { id: 'info', route: '/info' },
  { id: 'feedback', route: '/', actions: [nav('意见反馈'), { check: '写新反馈' }, { check: '提交反馈' }] },
  { id: 'help', route: '/help-guide', actions: [{ check: '操作指南' }, { check: /^新手引导$/ }] },
  { id: 'news', route: '/', actions: [{ click: '更多', after: 2000 }, { check: '资讯' }] },
  {
    id: 'news-detail',
    route: '/',
    actions: [{ click: /素描评分标准/, after: 2500 }, { check: '分享' }],
  },
  {
    id: 'circle',
    route: '/circle',
    actions: [{ check: '沉浸' }, { check: '列表' }],
  },
  {
    id: 'circle-list',
    route: '/circle',
    actions: [{ click: '列表', after: 600 }, { check: '列表' }],
  },
  {
    // 沉浸模式里作者写成「@姓名」，列表模式没有。
    id: 'circle-immersive',
    route: '/circle',
    actions: [{ click: '沉浸', after: 900 }, { check: /^@/ }],
  },
  { id: 'school-website', route: '/school-website', settle: 2500, actions: [
    { check: '官网加载失败', absent: true },
    { check: '学员可在「学情」中查看' },
  ] },
  { id: 'qrcode', route: '/qrcode', actions: [{ check: '我的二维码' }, { check: /保存/ }] },
  {
    id: 'search',
    route: '/',
    actions: [
      { type: '石膏', into: '搜索', after: 700 },
      { check: /^清空$/, role: 'button' },
      { check: /大卫石膏像/ },
    ],
  },
  {
    id: 'search-empty-clear',
    route: '/',
    actions: [
      { type: '无匹配的走查关键词', into: '搜索', after: 700 },
      { check: '暂无结果' },
      { click: /^清空$/, after: 250 },
      { check: '暂无结果', absent: true },
      { check: /^清空$/, role: 'button', absent: true },
    ],
  },
  {
    id: 'search-open-result',
    route: '/',
    actions: [
      { type: '大卫石膏像', into: '搜索', after: 700 },
      { click: /大卫石膏像 · 侧转头像/, after: 600 },
      { check: '点评要点' },
    ],
  },
];

export const ROLES = [
  {
    id: 'guest',
    steps: [
      { id: 'login', route: '/login', actions: [
        { check: '立即登录' },
        { check: '校长' },
        { check: '重置演示数据' },
      ] },
      { id: 'register', route: '/login', actions: [
        { click: '立即注册', after: 500 },
        { check: '请输入短信验证码', role: 'textbox' },
        { check: /^获取验证码$/, role: 'button' },
      ] },
      { id: 'forget', route: '/login', actions: [
        { click: '忘记密码', after: 1800 },
        { check: /找回|重置|验证码|新密码/ },
      ] },
      { id: 'terms', route: '/login', actions: [
        { click: '用户服务协议', after: 1800 },
        { check: /服务协议|隐私/ },
      ] },
    ],
  },
  {
    id: 'student',
    chip: '学生 · 林小雨',
    steps: [
      homeStep,
      {
        id: 'home-schedule', route: '/', actions: [
          skipGuide, { click: todayChip, after: 1500 },
          { check: /^节次$/ }, { check: '教学周' },
        ],
      },
      { id: 'rail-expanded', route: '/', actions: [skipGuide,
        { check: /^展开工具栏，拖动可移动$/ },
        { click: /^展开工具栏，拖动可移动$/ },
        { check: /^收起工具栏，拖动可移动$/ },
        { check: /^在当前页面使用比例测量$/ },
        { check: /^打开完整工具箱，17 个工具$/ },
      ] },
      { id: 'rail-collapse', route: '/', actions: [skipGuide,
        { click: /^展开工具栏，拖动可移动$/ },
        { click: /^收起工具栏，拖动可移动$/ },
        { check: /^展开工具栏，拖动可移动$/ },
        { check: /^恢复页面操作$/, absent: true },
      ] },
      { id: 'rail-precision-return', route: '/', actions: [skipGuide,
        { click: /^展开工具栏，拖动可移动$/ },
        { click: /^在当前页面使用比例测量$/ },
        { check: /^展开工具栏，拖动可移动$/ },
        { check: /^收起工具栏，拖动可移动$/, absent: true },
        { click: /^结束当前页面工具$/ },
        { check: /^恢复页面操作$/ },
        { click: /^收起工具栏，拖动可移动$/ },
        { check: /^展开工具栏，拖动可移动$/ },
      ] },
      { id: 'rail-grid', route: '/', actions: [skipGuide, { click: /^展开工具栏，拖动可移动$/ },
        { click: /^在当前页面使用构图网格$/ }, { check: /^九宫格$/ },
        { click: /^4 × 4$/ }, { click: /^收起工具参数$/ }, { check: /^调整$/ },
      ] },
      { id: 'rail-color', route: '/', actions: [skipGuide, { click: /^展开工具栏，拖动可移动$/ },
        { click: /^在当前页面使用取色与色卡$/ }, { check: /^点击页面取色$/ },
        { click: /^调整$/ }, { check: /^复制色值$/ }, { check: /^存入色卡$/ },
      ] },
      { id: 'rail-workspace-return', route: '/', actions: [skipGuide, { click: /^展开工具栏，拖动可移动$/ },
        { click: /^打开完整工具箱，17 个工具$/ }, { check: /^看画分析$/ },
        { click: /^收起工具$/ }, { check: /^课表$/ },
        { check: /^恢复页面操作$/ },
      ] },
      {
        id: 'home-toolbox-return', route: '/', actions: [
          skipGuide, { click: /^工具$/ },
          { check: '分析工具' }, /^返回$/, { check: /^课表$/ },
        ],
      },
      guideStep,
      noticeStep,
      { id: 'account-menu', route: '/', actions: [skipGuide, { click: /^账户菜单/, after: 500 }, { check: '资料修改', role: 'menuitem' }] },
      { id: 'study', route: '/study' },
      todayStep('今日学习', [
        { check: /^下一步$|^先做这件$/ }, { check: /练习时长/ }, { check: /三科成绩/ },
        { check: /最近作品得分/ },
      ]),
      { id: 'today-tick', route: '/today', actions: [
        { click: /^打勾：练习/, nth: 0, after: 900 },
        { check: /^取消打勾：练习/, role: 'button' }, { check: /今天已练 20 分钟/ },
      ] },
      { id: 'today-sheet', route: '/today', actions: [
        { click: /^未开始.*练习：/, nth: 0, after: 900 },
        { check: /^怎么做$/ }, { check: /推迟到晚上再做/ }, { check: /今天不做/ },
      ] },
      { id: 'today-add', route: '/today', actions: [
        { click: /^添加安排$/, after: 600 }, { check: '什么时候做' },
        { type: '临摹一张速写', into: '例如：临摹一张速写' },
        { click: /^晚上$/, after: 200 }, { click: /^添加$/, after: 900 },
        { check: /临摹一张速写/ },
      ] },
      { id: 'today-table', route: '/today', actions: [
        { click: /^近 7 天完成：看数据表$/, after: 500 },
        { check: /^近 7 天完成：看图表$/, role: 'button' },
      ] },
      { id: 'today-practice', route: '/today', actions: [
        { click: /^去练习$/, nth: 0, after: 1700 }, { check: /^今日清单$/, absent: true },
      ] },
      // 短板与练习闭环在学情的「作品成长」里。
      { id: 'focus-overview', route: '/study', actions: [
        { click: /^作品成长$/, after: 1400 }, { scroll: 500, after: 700 },
        { check: '分项观察' }, { check: '近期关注' }, { check: '制定练习' },
      ] },
      { id: 'focus-evidence', route: '/study', actions: [
        { click: /^作品成长$/, after: 1400 }, { scroll: 500, after: 700 },
        { click: /^查看依据$/, nth: 0 }, { check: '点评依据' }, { check: /^查看原作品$/ },
      ] },
      { id: 'focus-practice', route: '/study', actions: [
        { click: /^作品成长$/, after: 1400 }, { scroll: 500, after: 700 },
        { click: /^制定练习$/ }, { check: '提交前自检' }, { click: /^提交练习作品$/ },
        { check: /^上传作品$/ }, { check: '多位任课老师独立点评' },
      ] },
      { id: 'study-artwork-growth', route: '/study', actions: [
        { click: /^作品成长$/, after: 1400 }, { check: '近 7 天提交' }, { check: '问题解决率' }, { check: '分项趋势' },
      ] },
      { id: 'study-exam-growth', route: '/study', actions: [
        { click: /^成长曲线$/, after: 1200 }, { check: '历次成绩' },
      ] },
      { id: 'study-exam-report', route: '/study', actions: [
        { click: /^查看完整报告$/, after: 1200 }, { check: /^看原卷$/, role: 'button' },
      ] },
      { id: 'study-exam-paper', route: '/study', actions: [
        { click: /^查看完整报告$/, after: 1200 },
        { click: /^看原卷$/, after: 1200 }, { check: '对照样图' },
      ] },
      { id: 'artworks', route: '/artworks' },
      {
        id: 'artwork-detail',
        route: '/artworks',
        actions: [{ click: /石膏头像结构练习/, after: 2500 }, { check: '点评时间线' }],
      },
      {
        id: 'artwork-excellent',
        route: '/artworks/excellent',
        actions: [{ check: '优秀作品墙' }, { check: /素描|色彩|速写|还没有优秀作品/ }],
      },
      {
        id: 'artwork-upload',
        route: '/artworks',
        actions: [{ click: '上传作品', after: 1800 }, { check: '关联作品' }],
      },
      { id: 'gallery', route: '/gallery' },
      {
        id: 'gallery-compare', route: '/gallery', actions: [
          /大卫石膏像 · 侧转头像/, /^对比我的原卷$/,
          { check: /^我的原卷/ },
        ],
      },
      {
        id: 'gallery-toolbox-return', route: '/gallery', actions: [
          /大卫石膏像 · 侧转头像/, /^临摹网格$/,
          { check: /^构图网格$/ }, { check: /^大卫石膏像 · 侧转头像$/ },
          /^切换工具$/, /^镜像翻转$/, { check: /^镜像翻转$/ },
          /^返回$/, { check: /^临摹网格$/, role: 'button' },
        ],
      },
      { id: 'ebooks', route: '/ebooks' },
      {
        id: 'ebook-detail',
        route: '/ebooks',
        actions: [{ click: /联考素描静物高分解析/, after: 2200 }],
      },
      {
        id: 'ebook-reader', route: '/ebooks', actions: [
          /联考素描静物高分解析/, /^(开始|继续|重新)阅读/,
          { check: '目录与书签', role: 'button' },
        ],
      },
      { id: 'toolbox', route: '/toolbox', settle: 1600 },
      {
        id: 'toolbox-workspace-flow', route: '/toolbox', actions: [
          /^使用示例画作$/, /大卫石膏像/, { check: /^大卫石膏像$/ },
          /^镜像翻转/, { check: /^切换工具$/, role: 'button' },
          /^切换工具$/, /^构图网格$/, { check: /^构图网格$/ },
          { check: /^大卫石膏像$/ },
        ],
      },
      ...toolSteps,
      ...sharedContent,
      { id: 'quiz', route: '/camp', actions: [{ check: '练习方式' }, { check: '顺序练习' }] },
      { id: 'school-quiz', route: '/school-camp', actions: [{ check: '练习方式' }] },
      { id: 'school-video', route: '/school-video' },
      { id: 'mock', route: '/mock', actions: [{ check: '学情' }, { check: '查看完整报告' }] },
      { id: 'design-system', route: '/design-system' },
      {
        id: 'quiz-answer', route: '/camp', actions: [
          { click: /顺序练习/, after: 1200 },
          { check: '自动下一题' },
          { check: '当前题型' },
          { click: /^选项 A/, role: 'checkbox', after: 400 },
          { click: /^下一题$/, after: 600 },
          { check: /^下一题$/ },
        ],
      },
      {
        id: 'quiz-result', route: '/camp', actions: [
          { click: /顺序练习/, after: 1200 },
          { check: '自动下一题' },
          { click: /^返回$/, role: 'button', after: 800 },
          { check: '继续练习' },
          { check: '退出练习' },
        ],
      },
      { id: 'campus', route: '/smart-campus', settle: 1800 },
      campusAction('my-class', '我的班级'),
      campusAction('my-schedule', '我的课表'),
      scheduleNextWeek('我的课表'),
      campusAction('check-in', '课堂考勤'),
      campusAction('homework', '我的作品'),
      campusAction('grades', '我的考试'),
      campusAction('group-chat', '群聊'),
      campusAction('school-circle', '校圈'),
      campusAction('leave', '我的请假'),
      campusAction('dorm-check', '我的查寝'),
      campusAction('mailbox', '校长信箱'),
    ],
  },
  {
    id: 'teacher',
    chip: '任课老师 · 李静',
    steps: [
      homeStep,
      todayStep('今日工作', [
        { check: /点评学生作品/ }, { check: /点评进度/ }, { check: /作品提交情况/ },
        { check: /^需要关注的学生$/ },
      ]),
      { id: 'today-review-workspace', route: '/today', actions: [
        { click: /^开始点评$/, nth: 0, after: 1700 },
        { check: '保存并下一份', role: 'button' },
      ] },
      { id: 'today-follow', route: '/today', actions: [
        { click: /^标记已跟进$/, nth: 0, after: 900 }, { check: /^已跟进$/, role: 'button' },
      ] },
      { id: 'today-my-students', route: '/today', actions: [
        { scroll: 1800, after: 600 }, { click: /^我的学生$/, after: 1700 },
        { check: /最近提交/ }, { check: /查看学情与作品/ },
      ] },
      guideStep,
      noticeStep,
      { id: 'study', route: '/study' },
      { id: 'artworks', route: '/artworks' },
      {
        id: 'artwork-review',
        route: '/artworks',
        actions: [{ click: '开始点评', after: 2500 }, { check: '保存并下一份', role: 'button' }],
      },
      {
        id: 'artwork-tags',
        route: '/artworks',
        actions: [{ click: '点评标签', after: 1800 }],
      },
      { id: 'gallery', route: '/gallery' },
      { id: 'campus', route: '/smart-campus', settle: 1800 },
      campusAction('schedule', '授课课表'),
      {
        id: 'campus-switch-role', route: '/smart-campus', actions: [
          { click: /^班主任$/, after: 1400 }, { check: /^班级工作台$/, role: 'button' },
        ],
      },
      scheduleNextWeek('授课课表'),
      campusAction('sign', '签课管理'),
      campusAction('homework-review', '作品批改'),
      campusSub('homework-closed', '作品批改', [
        { click: /^已截止$/, after: 1200 },
        { check: '作品列表' }, { check: /已截止|暂无/ },
      ]),
      campusSub('homework-publish', '作品批改', [
        { click: /^发布作品$/, after: 900 },
        { check: '期望提交格式' }, { check: /^发布$/, role: 'button' },
      ]),
      campusSub('homework-history', '作品批改', [
        { click: /^历史作品$/, after: 900 }, { check: '历史发布记录' },
      ]),
      campusSub('homework-grade', '作品批改', [
        { click: /^查看(?:\/评分)?$/, after: 1200 },
        { check: '保存并下一份', role: 'button' },
      ]),
      campusAction('exam-review', '考评管理'),
      {
        id: 'campus-exam-score',
        route: '/smart-campus',
        actions: [
          { wait: 1200 }, { click: /^考评管理$/, after: 2200 },
          { click: /^评分$/, after: 800 }, { check: '评分与点评' },
          { check: /^提交评分$/, role: 'button' },
        ],
      },
      campusAction('roster', '学生名册'),
      campusAction('school-circle', '校圈'),
      campusAction('group-chat', '群聊'),
      campusAction('mailbox', '校长信箱'),
    ],
  },
  {
    // 教学组长：任课老师 + 组长权限，首页与任课老师相同，今日工作多出复核。
    id: 'groupLeader',
    chip: '组长 · 张明远',
    steps: [
      homeStep,
      guideStep,
      noticeStep,
      { id: 'study', route: '/study' },
      { id: 'artworks', route: '/artworks' },
      {
        id: 'artwork-lead-reviews',
        route: '/artworks/lead-reviews',
        actions: [
          { check: '复核池' },
          { check: '全部原因' },
        ],
      },
      {
        id: 'artwork-lead-workspace',
        route: '/artworks/lead-reviews',
        actions: [
          { click: /^复核$/, after: 1600 },
          { check: '点评质量（必选）' },
          { check: '提交复核', role: 'button' },
        ],
      },
      todayStep('今日工作', [
        { check: /复核本组点评/ }, { check: /本组点评及时率/ },
      ]),
      { id: 'today-lead-pool', route: '/today', actions: [
        { click: /^去复核$/, after: 1600 }, { check: '复核池' },
      ] },
      { id: 'campus', route: '/smart-campus', settle: 1800 },
      campusAction('schedule', '授课课表'),
      campusAction('group-chat', '群聊'),
    ],
  },
  {
    id: 'headTeacher',
    chip: '班主任 · 赵雪',
    steps: [
      homeStep,
      todayStep('今日工作', [
        { check: /审批学生请假/ }, { check: /班级到校/ }, { check: /班级查寝/ },
        { check: /^需要关注的学生$/ },
      ]),
      { id: 'today-leave', route: '/today', actions: [
        { click: /^去审批$/, nth: 0, after: 2000 }, { check: /^待家长确认$/, role: 'button' },
      ] },
      guideStep,
      { id: 'campus', route: '/smart-campus', settle: 1800 },
      campusAction('workbench', '班级工作台'),
      campusSub('workbench-notice', '班级工作台', [
        { click: /发布通知/, after: 800 }, { check: '发布班级通知' },
      ]),
      campusSub('workbench-students', '班级工作台', [
        { click: /^学生管理$/, after: 1500 }, { check: /学生及家长信息仅查看/ },
      ]),
      campusSub('workbench-student-detail', '班级工作台', [
        { click: /^学生管理$/, after: 1500 }, { click: /林小雨/, after: 1200 },
        { check: '家长与监护人' }, { check: /确认修改/ },
      ]),
      campusSub('workbench-grades', '班级工作台', [
        { click: /^成绩$/, after: 1800 }, { check: '班级成绩变化' }, { check: '考试记录' },
      ]),
      campusSub('workbench-score-detail', '班级工作台', [
        { click: /^成绩$/, after: 1800 }, { click: /^详情$/, after: 1200 },
        { check: '成绩详情' },
      ]),
      campusAction('leave-approval', '请假审批'),
      campusSub('leave-approval-approved', '请假审批', [
        { click: /^已通过$/, after: 1200 },
        { check: /代家长确认并通过/, absent: true }, { check: '许嘉懿' },
      ]),
      campusSub('leave-approval-reject', '请假审批', [
        { click: /^驳回$/, after: 800 }, { check: '驳回申请' }, { check: '审批意见' },
      ]),
      campusAction('home-school', '家校沟通'),
      campusSub('home-school-pending', '家校沟通', [
        { click: /^待回复$/, after: 1200 },
        { check: '邓雨萱', absent: true }, { check: '刘语桐' },
      ]),
      campusSub('home-school-chat', '家校沟通', [
        { click: /刘语桐/, after: 1500 }, { check: /^发送$/ },
      ]),
      campusSub('dorm-history', '查寝历史', [
        { check: '查寝历史记录' }, { check: /晚查寝 · 已归寝/ },
      ]),
      campusSub('dorm-history-day', '查寝历史', [
        { click: dormHistoryDayCell, after: 1500 }, { check: dormHistoryDayText },
      ]),
      campusSub('dorm-history-detail', '查寝历史', [
        { click: /林小雨/, after: 1500 }, { check: /查寝详情/ },
      ]),
      campusAction('group-chat', '群聊'),
      campusAction('mailbox', '校长信箱'),
    ],
  },
  {
    id: 'dormManager',
    chip: '宿管 · 马红梅',
    steps: [
      { ...homeStep, actions: [
        skipGuide, { check: /^值班$/ }, { check: /^查寝$/ }, { check: /^校长信箱$/ },
        { check: /^学情$/, absent: true }, { check: /^今日待办$/, absent: true },
      ] },
      todayStep('今日工作', [
        { check: /到岗打卡/ }, { check: /宿舍状态/ }, { check: /晚归与缺勤/ },
      ]),
      { id: 'today-patrol', route: '/today', actions: [
        { click: /^打勾：午间巡查$/, after: 900 }, { check: /^取消打勾：午间巡查$/, role: 'button' },
      ] },
      { id: 'today-dorm-check', route: '/today', actions: [
        { click: /^按宿舍查寝$/, nth: 0, after: 2000 }, { check: /^今日清单$/, absent: true },
      ] },
      guideStep,
      { id: 'campus', route: '/smart-campus', settle: 1800 },
      campusAction('check-by-room', '按宿舍查寝'),
      campusAction('dorm-dynamic', '查寝动态'),
      campusSub('dorm-dynamic-exception', '查寝动态', [
        { click: /^异常$/, after: 1000 },
        { check: /^查寝记录$/, role: 'button' }, { check: /^正常$/, absent: true },
      ]),
      campusSub('dorm-dynamic-audit', '查寝动态', [
        { click: /^补卡审核/, after: 1200 }, { check: /^待审核$/ },
      ]),
      campusSub('dorm-dynamic-audit-detail', '查寝动态', [
        { click: /^补卡审核/, after: 1200 }, { click: /^查看详情$/, after: 1200 },
        { check: /补卡详情/ },
      ]),
      campusAction('dorm-history', '查寝历史'),
      campusAction('punch', '到岗打卡'),
      campusAction('leave', '宿管请假'),
      campusAction('school-circle', '校圈'),
      campusAction('group-chat', '群聊'),
      campusAction('mailbox', '校长信箱'),
    ],
  },
  {
    id: 'admin',
    chip: '管理员 · 王敏',
    steps: [
      { ...homeStep, actions: [...homeStep.actions, { check: /^课表$/ }, { check: /^课程$/ }] },
      todayStep('今日工作', [
        { check: /审批教职工请假/ }, { check: /全校今日课程/ }, { check: /审批处理量/ },
      ]),
      { id: 'today-approve', route: '/today', actions: [
        { click: /^去审批$/, nth: 0, after: 2000 }, { check: /^今日清单$/, absent: true },
      ] },
      guideStep,
      { id: 'campus', route: '/smart-campus', settle: 1800 },
      campusAction('students', '学生管理'),
      campusAction('teachers', '教师管理'),
      campusAction('classes', '班级管理'),
      campusAction('schedule', '排课与课表'),
      scheduleNextWeek('排课与课表'),
      campusAction('sign', '签课管理'),
      campusAction('teacher-leave', '教师请'),
      campusAction('face', '人脸库'),
      campusAction('notice', '通知管理'),
      campusAction('group-chat', '群聊'),
      campusAction('mailbox', '校长信箱'),
      campusAction('circle-governance', '校圈治理'),
    ],
  },
  {
    id: 'principal',
    chip: '校长 · 陈建华',
    steps: [
      { ...homeStep, actions: [...homeStep.actions, { check: /^课表$/ }, { check: '校长驾驶舱', absent: true }] },
      todayStep('今日工作', [
        { check: /督办老师点评超时/ }, { check: /作品点评链/ }, { check: /校区对比/ },
        { check: /^教学跟进$/ },
      ]),
      { id: 'today-principal-overdue', route: '/today', actions: [
        { click: /^去查看$/, nth: 0, after: 1600 }, { check: '点评链概览' },
      ] },
      // 教学指标、趋势与报表入口在「全校学情」里。
      { id: 'study-principal', route: '/', actions: [skipGuide, nav('全校学情'),
        { check: '今日新交作品' }, { check: '教学趋势' }, { check: /^教学报表$/ },
        { check: '近期作品' }, { check: /^常用管理$/ }, { check: /^今日待办$/, absent: true },
      ] },
      { id: 'study-principal-campus', route: '/study', actions: [
        { click: /^城西校区$/, after: 1600 }, { check: '学生到校' }, { check: '教学趋势' },
      ] },
      { id: 'study-principal-review-chain', route: '/study', actions: [
        { click: /^作品点评链/, after: 1500 }, { check: '点评链概览' }, { check: '全部日期' },
      ] },
      { id: 'study-principal-teachers', route: '/study', actions: [
        { click: /^老师履职/, after: 1500 }, { check: '履职概览' }, { check: '签到准时率' },
      ] },
      { id: 'study-principal-attention', route: '/study', actions: [
        { click: /^需要关注的学生/, after: 1500 }, { check: /负责老师|暂无学生/ },
      ] },
      guideStep,
      noticeStep,
      { id: 'study', route: '/study' },
      { id: 'artworks', route: '/artworks' },
      {
        id: 'artwork-all',
        route: '/artworks',
        actions: [{ check: '全部作品' }, { check: /共 \d+ 件|暂无/ }],
      },
      { id: 'artwork-review-settings', route: '/artworks', actions: [
        { click: /^点评设置$/, after: 1200 }, { check: '教学组长' },
        { check: '保存设置', role: 'button' },
      ] },
      {
        id: 'artwork-excellent',
        route: '/artworks/excellent',
        actions: [{ check: '优秀作品墙' }, { check: /素描|色彩|速写|还没有优秀作品/ }],
      },
      { id: 'campus', route: '/smart-campus', settle: 1800 },
      campusAction('teachers', '教师管理'),
      campusAction('students', '学生管理'),
      campusAction('group-chat', '群聊'),
      campusSub('mailbox', '校长信箱', [
        { check: /^待回复$/, role: 'button' }, { check: /^已回复$/, role: 'button' },
        { click: /^已回复$/, after: 700 }, { check: '已回复' },
      ]),
      campusAction('circle-governance', '校圈治理'),
    ],
  },
];

// 3.1：优秀课件与集市为全身份入口，断言具体结果，避免路由回退页误通过。
for (const role of ROLES) {
  if (role.id === 'guest') continue;
  role.steps.push(
    { id: 'v31-topics', route: '/micro-lessons', actions: [{ check: '全部课件' }, { check: '把明暗交界线画进体积里' }] },
    { id: 'v31-topic-detail', route: '/micro-lessons', actions: [{ click: '把明暗交界线画进体积里' }, { check: '阅读资料' }, { check: '开始阅读' }] },
    { id: 'v31-topic-new', route: '/micro-lessons', actions: [{ click: '新增课件' }, { check: '课件内容' }, { check: '上传 PDF / 图片' }, { check: '发布课件' }] },
    { id: 'v31-market', route: '/market', actions: [{ check: '发现作品' }, { check: '午后的静物' }, { check: '数字授权' }] },
    { id: 'v31-market-detail', route: '/market', actions: [{ click: '午后的静物' }, { check: '个人学习使用' }, { check: '演示交易' }] },
    { id: 'v31-market-new', route: '/market', actions: [{ click: /^发布作品$/ }, { check: '创作信息' }, { check: '交易方式' }, { check: '上传作品图片' }] },
    { id: 'v31-market-orders', route: '/market', actions: [{ click: '我的订单' }, { check: '暂无匹配的订单' }] },
  );
}

ROLES.find((role) => role.id === 'principal').steps.push({
  id: 'v31-campus-chart', route: '/study', actions: [
    { click: /^班级学情/, after: 1500 }, { check: '校区学情对比' }, { check: '最近一次模考均分' },
  ],
});

ROLES.find((role) => role.id === 'student').steps.push(
  { id: 'v31-upload-reader-resume', route: '/micro-lessons', actions: [
    { click: '新增课件' }, { check: '每份不超过 20 MB' },
    { type: '两页体积观察', into: '例如：把明暗交界线画进体积里' },
    { type: '通过两页图片观察形体转折和明暗变化。', into: '这份课件解决什么问题？读完可以尝试什么？' },
    { uploadFiles: ['assets/demo/ebooks/eb-sketch-still-p02.jpg', 'assets/demo/ebooks/eb-sketch-still-p03.jpg'], into: '上传 PDF / 图片', after: 2000 },
    { check: '图片书籍 · 2 页' }, { click: '发布课件' },
    { click: '两页体积观察' }, { click: '开始阅读' }, { check: '1 / 2' },
    { click: '下一页' }, { check: '2 / 2' }, { click: '返回' },
    { click: '开始阅读' }, { check: '2 / 2' },
  ] },
  { id: 'v31-topic-publish', route: '/micro-lessons', actions: [
    { click: '新增课件' },
    { click: '发布课件' }, { check: '课件名称须为' },
    { type: '明暗关系阅读练习', into: '例如：把明暗交界线画进体积里' },
    { type: '通过图文对照观察明暗关系与形体转折。', into: '这份课件解决什么问题？读完可以尝试什么？' },
    { click: /^选择联考素描静物高分解析（示例）$/ },
    { click: /^选择联考素描静物高分解析（示例） · PDF$/ },
    { click: '发布课件' }, { check: '明暗关系阅读练习' },
    { click: '明暗关系阅读练习' }, { check: '2 份 · 点封面开始阅读' },
    { click: /^收藏$/ }, { check: '已收藏' },
  ] },
  { id: 'v31-topic-pdf', route: '/micro-lessons', actions: [
    { click: '一组静物，建立统一的色调' },
    { click: /色彩静物冷暖关系 30 讲（示例） · PDF/, role: 'button' },
    { check: '1 / 10', after: 1500 },
    { click: '下一页' }, { check: '2 / 10', after: 1500 },
  ] },
  { id: 'v31-topic-image-book', route: '/micro-lessons', actions: [
    { click: '把明暗交界线画进体积里' }, { click: '开始阅读' },
    { check: '目录与书签' }, { click: '下一页' }, { check: '联考素描静物高分解析', role: 'heading' },
  ] },
  { id: 'v31-market-publish', route: '/market', actions: [
    { click: /^发布作品$/ },
    { type: '光与空间练习', into: '给这份创作起个名字' },
    { type: '观察静物之间的遮挡与明暗，记录这次创作的过程。', into: '分享观察、材料与创作过程' },
    { click: '石膏头像长期作品' },
    { scroll: 750, at: [900, 580] }, { click: '确认作品发布权限' },
    { click: /^提交审核$/ }, { check: '光与空间练习' }, { check: '审核中' },
  ] },
  { id: 'v31-market-purchase', route: '/market', actions: [
    { click: '午后的静物' }, { scroll: 450, at: [950, 600] },
    { click: '购买使用许可' }, { check: '确认订单' },
    { scroll: 500, at: [950, 600] }, { click: '我已阅读并同意以上交易说明', role: 'any' },
    { click: '创建订单 ·' }, { check: '待付款' }, { click: '模拟支付 ¥' }, { click: /^确认模拟支付$/, nth: 0 },
    { check: '已完成' }, { check: '查看交付文件' },
  ] },
  { id: 'v31-market-order-read', route: '/market', actions: [
    { click: '我的订单' }, { click: '午后的静物' }, { click: '查看交付文件' }, { check: '保存许可凭证' }, { check: '保存文件 1' },
  ] },
);


for (const id of ['teacher', 'headTeacher', 'principal']) {
  ROLES.find((role) => role.id === id).steps.push({
    id: 'v31-independent-reviews', route: '/artworks', actions: [
      { click: /^全部$/, role: 'button' },
      { type: '几何体明暗关系', into: '搜索学生、校区或作品', enter: true },
      { click: '几何体明暗关系' },
      { check: '作品点评' }, { check: '3 / 3 位已点评' },
      { check: '王海波' }, { check: '校长评分独立展示' },
    ],
  });
}

ROLES.find((r) => r.id === 'student').steps.push(
  { id: 'v32-market-physical', route: '/market', actions: [
    { click: '石膏像的光' }, { scroll: 500, at: [950, 550] }, { click: '购买实物作品' }, { check: '收货地址' },
    { click: '新增收货地址' }, { type: '林小雨', into: '收货人' }, { type: '13809310001', into: '联系电话' }, { type: '示范画室城东校区一号楼前台', into: '省市区及详细地址' },
    { click: '保存地址' }, { scroll: 700, at: [950, 550] }, { click: '我已阅读并同意以上交易说明', role: 'any' }, { click: '创建订单 ·' }, { check: '待付款' }, { click: '模拟支付 ¥' }, { click: /^确认模拟支付$/ }, { check: '待发货' }, { check: '申请售后' },
  ] },
  { id: 'v32-market-seller', route: '/market', actions: [{ click: '创作者工作台' }, { check: '我的发布' }, { click: '卖出的订单' }, { check: '待发货' }] },
  { id: 'v32-market-share', route: '/market?listingId=market-1', actions: [{ check: '作品详情' }, { check: '午后的静物' }] },
);
ROLES.find((r) => r.id === 'principal').steps.push({id:'v32-market-moderation',route:'/market',actions:[{click:'集市审核'},{check:'待审核作品'},{check:'举报与争议'}]});

ROLES.find((r) => r.id === 'student').steps.push(
 {id:'v32-market-fulfillment',route:'/market',actions:[
  {account:'组长 · 张明远'}, {click:'创作者工作台'}, {click:'卖出的订单'}, {click:'石膏像的光'},
  {check:'待发货'}, {click:'填写发货信息'}, {type:'顺丰速运',into:'快递公司'}, {type:'SF1234567890',into:'物流单号'}, {click:/^提交$/}, {check:'待收货'},
  {account:'学生 · 林小雨'}, {click:'我的订单'}, {click:'石膏像的光'}, {click:/^确认收货$/}, {click:/^确认收货$/}, {check:'已完成'},
  {click:'申请售后'}, {type:'收到的作品边角有破损，需要退货处理。',into:'问题说明'}, {click:/^提交$/}, {check:'售后处理中'},
  {account:'组长 · 张明远'}, {click:'创作者工作台'}, {click:'卖出的订单'}, {click:'石膏像的光'}, {click:/^同意售后$/},
  {type:'已核对作品状态，同意寄回后退款。',into:'处理说明'}, {type:'张明远 13809310012 示范画室城东校区前台',into:'退货地址'}, {click:/^提交$/}, {check:'待寄回'},
  {account:'学生 · 林小雨'}, {click:'我的订单'}, {click:'石膏像的光'}, {click:'填写退货物流'}, {type:'顺丰速运',into:'快递公司'}, {type:'SF9988776655',into:'退货单号'}, {click:/^提交$/}, {check:'退货待签收'},
  {account:'组长 · 张明远'}, {click:'创作者工作台'}, {click:'卖出的订单'}, {click:'石膏像的光'}, {click:/^确认退货并退款$/}, {click:/^确认退货并退款$/}, {check:'已退款'},
  {account:'学生 · 林小雨'}, {click:'我的订单'}, {click:'石膏像的光'}, {check:'已退款'},
 ]},
 {id:'v32-market-audit-published',route:'/market',actions:[
  {account:'校长 · 陈建华'}, {click:'集市审核'}, {check:'光与空间练习'}, {click:'通过审核'}, {type:'作品与创作说明已核对，可以公开展示。',into:'处理依据'}, {click:/^通过审核$/}, {check:'当前没有待审核作品'},
  {account:'学生 · 林小雨'}, {click:'光与空间练习'}, {check:'管理这件作品'},
 ]},
);

ROLES.find((r) => r.id === 'teacher').steps.push(
 {id:'v32-teaching-followup',route:'/today',actions:[{scroll:1800,after:600},{click:/^我的学生$/},{check:'关注事项优先'},{click:'记录跟进'},{type:'已沟通明暗关系练习，安排下周复查局部改画。',into:'沟通结果、练习安排与下次复查要点'},{click:'保存跟进记录'},{check:'已沟通明暗关系练习'},{click:'查看学情与作品'},{check:'已提交作品'}]},
 {id:'v32-student-dimensions',route:'/today',actions:[{scroll:1800,after:600},{click:/^我的学生$/},{click:'查看学情与作品'},{check:'已提交作品'},{scroll:650,at:[950,550]},{check:'5 级评价'},{check:'同一作品多位老师取均值'}]},
);
ROLES.find((r) => r.id === 'groupLeader').steps.push(
 {id:'v32-next-course',route:'/',fixedTime:'2026-11-15T10:00:00+08:00',actions:[skipGuide,{check:'今日暂无排课'},{check:'下一次课程 · 11月16日'}]},
);
ROLES.find((r) => r.id === 'admin').steps.push(
 {id:'v32-notice-edit',route:'/smart-campus',actions:[{click:'通知管理'},{click:/^编辑$/},{check:'编辑通知'},{type:'（已核对）',into:'通知标题'},{click:'保存并定时'},{check:'已核对'}]},
);
ROLES.find((r) => r.id === 'student').steps.push(
 {id:'v32-picture-study',route:'/camp',actions:[{check:'看图赏析'},{click:'查看范画'},{check:'范画'}]},
);

ROLES.find((r) => r.id === 'student').steps.push(
 {id:'v32-market-dispute',route:'/market',actions:[
  {click:'我的订单'},{click:'午后的静物'},{click:'申请售后'},{type:'希望进一步核对本次数字授权的使用范围。',into:'问题说明'},{click:/^提交$/},{check:'售后处理中'},
  {account:'任课老师 · 李静'},{click:'创作者工作台'},{click:'卖出的订单'},{click:'午后的静物'},{click:'拒绝申请'},{type:'已提供下单时约定的文件和许可范围说明。',into:'拒绝原因'},{click:/^提交$/},{check:'已完成'},
  {account:'学生 · 林小雨'},{click:'我的订单'},{click:'午后的静物'},{click:'申请平台介入'},{type:'请平台对照下单许可说明协助处理。',into:'补充说明'},{click:/^提交$/},{check:'平台处理中'},
  {account:'校长 · 陈建华'},{click:'集市审核'},{click:'查看相关记录'},{check:'售后申请'},{click:/^关闭$/},{click:/^不支持申请$/},{type:'已核对订单条款和交付记录，暂不支持本次退款申请。',into:'处理依据'},{click:'确认处理'},{check:'已处理'},
  {account:'学生 · 林小雨'},{click:'我的订单'},{click:'午后的静物'},{check:'平台处理结果'},{check:'暂不支持本次退款申请'},
 ]},
);
