// 走查页面清单：每一步都从 route 重新载入（登录态保存在浏览器存储里），
// 再按 actions 依次点击（按无障碍名称匹配，字符串按包含匹配）。
// 新增页面时在对应角色下追加步骤即可。

const nav = (label) => ({ click: label, after: 1800 });
// 身份第一次进首页会弹新手引导（弹出即记为已看过），截首页本身前先关掉；没弹就跳过这一步。
const skipGuide = { click: '跳过', optional: true, attempts: 4, after: 800 };
const homeStep = { id: 'home', route: '/', actions: [skipGuide], settle: 1800 };
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
  ],
});

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
  { id: 'feedback', route: '/', actions: [nav('意见反馈')] },
  { id: 'help', route: '/help-guide' },
  { id: 'news', route: '/', actions: [{ click: '更多', after: 2000 }] },
  {
    id: 'news-detail',
    route: '/',
    actions: [{ click: /素描评分标准/, after: 2500 }],
  },
  { id: 'circle', route: '/circle' },
  { id: 'school-website', route: '/school-website' },
  { id: 'qrcode', route: '/qrcode' },
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
      { id: 'login', route: '/login' },
      { id: 'register', route: '/login', actions: [
        { click: '立即注册', after: 500 },
        { check: '请输入短信验证码', role: 'textbox' },
        { check: /^获取验证码$/, role: 'button' },
      ] },
      { id: 'forget', route: '/login', actions: [{ click: '忘记密码', after: 1800 }] },
      { id: 'terms', route: '/login', actions: [{ click: '用户服务协议', after: 1800 }] },
    ],
  },
  {
    id: 'student',
    chip: '学生 · 林小雨',
    steps: [
      homeStep,
      {
        id: 'home-schedule', route: '/', actions: [
          skipGuide, { click: /^周[一二三四五六日]/, after: 1500 },
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
      { id: 'quiz', route: '/camp', actions: [{ check: '练习方式' }] },
      { id: 'school-quiz', route: '/school-camp' },
      { id: 'school-video', route: '/school-video' },
      { id: 'mock', route: '/mock' },
      { id: 'design-system', route: '/design-system' },
      {
        id: 'quiz-answer', route: '/camp', actions: [
          /顺序练习/, { click: /^选项 A/, role: 'checkbox' }, /^下一题$/,
          { check: /^第 \d+ 题$/ },
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
    id: 'headTeacher',
    chip: '班主任 · 赵雪',
    steps: [
      homeStep,
      guideStep,
      { id: 'campus', route: '/smart-campus', settle: 1800 },
      campusAction('workbench', '班级工作台'),
      campusAction('leave-approval', '请假审批'),
      campusAction('home-school', '家校沟通'),
      campusAction('dorm-history', '查寝历史'),
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
];
