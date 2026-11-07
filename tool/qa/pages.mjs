// 走查页面清单：每一步都从 route 重新载入（登录态保存在浏览器存储里），
// 再按 actions 依次点击（按无障碍名称匹配，字符串按包含匹配）。
// 新增页面时在对应角色下追加步骤即可。

const nav = (label) => ({ click: label, after: 1800 });
const campusAction = (id, label) => ({
  id: `campus-${id}`,
  route: '/smart-campus',
  actions: [{ wait: 1200 }, { click: label, after: 2200 }],
});

const toolSteps = [
  ['tool-value', '明度检查'],
  ['tool-mirror', '镜像翻转'],
  ['tool-grid', '构图网格'],
  ['tool-color', '取色'],
  ['tool-sketch', '速写计时'],
  ['tool-countdown', '考试倒计时'],
].map(([id, label]) => ({
  id,
  route: '/toolbox',
  actions: [{ click: label, after: 2000 }],
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
    actions: [{ type: '石膏', into: '搜索', enter: true, after: 2200 }],
  },
];

export const ROLES = [
  {
    id: 'guest',
    steps: [
      { id: 'login', route: '/login' },
      { id: 'register', route: '/login', actions: [{ click: '立即注册', after: 1800 }] },
      { id: 'forget', route: '/login', actions: [{ click: '忘记密码', after: 1800 }] },
      { id: 'terms', route: '/login', actions: [{ click: '服务协议与隐私政策', after: 1800 }] },
    ],
  },
  {
    id: 'student',
    chip: '学生 · 林小雨',
    steps: [
      { id: 'home', route: '/' },
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
      { id: 'ebooks', route: '/ebooks' },
      {
        id: 'ebook-detail',
        route: '/ebooks',
        actions: [{ click: /联考素描静物高分解析/, after: 2200 }],
      },
      { id: 'toolbox', route: '/toolbox' },
      ...toolSteps,
      ...sharedContent,
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
      { id: 'home', route: '/' },
      { id: 'study', route: '/study' },
      { id: 'artworks', route: '/artworks' },
      {
        id: 'artwork-review',
        route: '/artworks',
        actions: [{ click: /待我点评/, after: 2500 }],
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
      { id: 'home', route: '/' },
      { id: 'campus', route: '/smart-campus' },
      campusAction('workbench', '班级工作台'),
      campusAction('leave-approval', '请假审批'),
      campusAction('home-school', '家校沟通'),
      campusAction('dorm-dynamic', '查寝动态'),
      campusAction('dorm-history', '查寝历史'),
      campusAction('group-chat', '群聊'),
      campusAction('mailbox', '校长信箱'),
    ],
  },
  {
    id: 'dormManager',
    chip: '宿管 · 马红梅',
    steps: [
      { id: 'home', route: '/' },
      { id: 'campus', route: '/smart-campus' },
      campusAction('check-by-room', '按宿舍查寝'),
      campusAction('dorm-dynamic', '查寝动态'),
      campusAction('dorm-history', '查寝历史'),
      campusAction('punch', '打卡管理'),
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
      { id: 'home', route: '/' },
      { id: 'campus', route: '/smart-campus' },
      campusAction('students', '学生管理'),
      campusAction('teachers', '教师管理'),
      campusAction('classes', '班级编辑'),
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
