// 走查页面清单：每一步都从 route 重新载入（登录态保存在浏览器存储里），
// 再按 actions 依次点击（按无障碍名称匹配，字符串按包含匹配）。
// 新增页面时在对应角色下追加步骤即可。

const nav = (label) => ({ click: label, after: 1800 });
// 身份第一次进首页会弹新手引导（弹出即记为已看过），截首页本身前先关掉；没弹就跳过这一步。
const skipGuide = { click: '跳过', optional: true, attempts: 4, after: 800 };
const homeStep = { id: 'home', route: '/', actions: [skipGuide], settle: 1800 };
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
  'homework-review': [{ check: '待批改人次' }, { check: /^发布作业$/, role: 'button' }],
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
  { id: 'courseware', route: '/', actions: [nav('校园课件')] },
  {
    id: 'courseware-speed',
    route: '/',
    actions: [
      nav('校园课件'),
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
  { id: 'notes', route: '/', actions: [nav('我的笔记')] },
  { id: 'collection', route: '/', actions: [nav('我的收藏')] },
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
    { check: '我的学情' },
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
      {
        id: 'home-toolbox-return', route: '/', actions: [
          skipGuide, { click: /^工具箱$/ },
          { check: '分析工具' }, /^返回$/, { check: '今日练习' },
        ],
      },
      guideStep,
      noticeStep,
      { id: 'account-menu', route: '/', actions: [skipGuide, { click: /^账户菜单/, after: 500 }, { check: '资料修改', role: 'menuitem' }] },
      { id: 'study', route: '/study' },
      { id: 'artworks', route: '/artworks' },
      {
        id: 'artwork-detail',
        route: '/artworks',
        actions: [{ click: /石膏头像结构练习/, after: 2500 }],
      },
      {
        id: 'artwork-excellent',
        route: '/artworks/excellent',
        actions: [{ check: '优秀作品墙' }, { check: /素描|色彩|速写|还没有优秀作品/ }],
      },
      {
        id: 'artwork-upload',
        route: '/artworks',
        actions: [{ click: '上传作品', after: 1800 }],
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
      { id: 'mock', route: '/mock', actions: [{ check: '模拟考试' }, { check: '功能开发中' }] },
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
      campusAction('check-in', '课堂签到'),
      campusAction('homework', '我的作业'),
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
      guideStep,
      noticeStep,
      { id: 'study', route: '/study' },
      { id: 'artworks', route: '/artworks' },
      {
        id: 'artwork-review',
        route: '/artworks',
        actions: [{ click: '开始点评', after: 2500 }],
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
      campusAction('homework-review', '作业批改'),
      campusSub('homework-closed', '作业批改', [
        { click: /^已截止$/, after: 1200 },
        { check: /石膏头像结构练习/ }, { check: /素描几何体组合/, absent: true },
      ]),
      campusSub('homework-publish', '作业批改', [
        { click: /^发布作业$/, after: 900 },
        { check: '期望提交格式' }, { check: /^发布$/, role: 'button' },
      ]),
      campusSub('homework-history', '作业批改', [
        { click: /^历史作业$/, after: 900 }, { check: '历史发布记录' },
      ]),
      campusSub('homework-grade', '作业批改', [
        { click: /^查看\/评分$/, after: 900 },
        { check: '批改与点评' }, { check: /^发布批改$/, role: 'button' },
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
    // 教学组长：任课老师 + 组长权限，首页与任课老师同构。
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
          { check: /超时|石膏头像结构练习|暂无待复核作品/ },
        ],
      },
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
      homeStep,
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
      homeStep,
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
      homeStep,
      guideStep,
      noticeStep,
      { id: 'study', route: '/study' },
      { id: 'artworks', route: '/artworks' },
      {
        id: 'artwork-all',
        route: '/artworks',
        actions: [{ check: '全部作品' }, { check: /共 \d+ 件|暂无/ }],
      },
      {
        id: 'artwork-excellent',
        route: '/artworks/excellent',
        actions: [{ check: '优秀作品墙' }, { check: /素描|色彩|速写|还没有优秀作品/ }],
      },
      { id: 'campus', route: '/smart-campus', settle: 1800 },
      campusAction('teachers', '教师管理'),
      campusAction('students', '学生管理'),
      campusAction('group-chat', '群聊'),
      campusAction('mailbox', '校长信箱'),
      campusAction('circle-governance', '校圈治理'),
    ],
  },
];
