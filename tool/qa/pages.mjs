// 走查页面清单：每一步都从 route 重新载入（登录态保存在浏览器存储里），
// 再按 actions 依次点击（按无障碍名称匹配，字符串按包含匹配）。
// 新增页面时在对应角色下追加步骤即可。

const nav = (label) => ({ click: label, after: 1800 });
// 身份第一次进首页会弹新手引导（弹出即记为已看过），截首页本身前先关掉；没弹就跳过这一步。
const skipGuide = { click: '跳过', optional: true, attempts: 4, after: 800 };
const homeStep = { id: 'home', route: '/', actions: [skipGuide] };
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
  actions: [{ wait: 1200 }, { click: label, after: 2200 }],
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
  ['tool-sketch', '速写计时'],
  ['tool-figure', '人体比例参考'],
  ['tool-value-order', '明度排序训练'],
  ['tool-countdown', '考试倒计时'],
  ['tool-score', '综合分计算器'],
  ['tool-checklist', '考场物品清单'],
].map(([id, label, sample]) => ({
  id,
  route: '/toolbox',
  actions: [
    { click: label, after: 2000 },
    ...(sample ? [{ click: sample, after: 2500 }] : []),
  ],
}));

const sharedContent = [
  { id: 'ai', route: '/', actions: [nav(/小[艺美]同学/)] },
  { id: 'courseware', route: '/', actions: [nav('校园课件')] },
  { id: 'cloud', route: '/', actions: [nav('我的云盘')] },
  { id: 'video', route: '/', actions: [nav('视频中心')] },
  {
    id: 'video-detail',
    route: '/',
    actions: [nav('视频中心'), { click: /石膏几何体结构/, after: 2500 }],
  },
  { id: 'notes', route: '/', actions: [nav('我的笔记')] },
  { id: 'collection', route: '/', actions: [nav('我的收藏')] },
  { id: 'personal', route: '/', actions: [nav('个人中心')] },
  { id: 'personal-membership', route: '/personal-center', actions: [/^会员权益与套餐$/] },
  { id: 'personal-edit', route: '/personal-center', actions: [/^编辑资料$/, { check: '姓名' }] },
  { id: 'personal-gender', route: '/info', actions: [/^性别/, { check: '选择性别' }] },
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
      { check: '没有找到相关内容' },
      { click: /^清空$/, after: 250 },
      { check: '没有找到相关内容', absent: true },
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
      guideStep,
      noticeStep,
      { id: 'demo-tag', route: '/', actions: [skipGuide, { click: '演示版', after: 1200 }] },
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
      { id: 'toolbox', route: '/toolbox' },
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
      { id: 'campus', route: '/smart-campus' },
      campusAction('my-class', '我的班级'),
      campusAction('my-schedule', '我的课表'),
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
      { id: 'campus', route: '/smart-campus' },
      campusAction('schedule', '授课课表'),
      campusAction('sign', '签课管理'),
      campusAction('homework-review', '作业批改'),
      campusAction('exam-review', '考评管理'),
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
      { id: 'campus', route: '/smart-campus' },
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
      { id: 'campus', route: '/smart-campus' },
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
      { id: 'campus', route: '/smart-campus' },
      campusAction('students', '学生管理'),
      campusAction('teachers', '教师管理'),
      campusAction('classes', '班级管理'),
      campusAction('schedule', '排课与课表'),
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
