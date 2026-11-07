abstract final class AppAssets {
  static const authBg = 'assets/images/auth/bg_art.jpg';

  /// 艺考网标识（来自艺考网品牌库 yikao-marketing/brand/logo）。
  static const shellLogo = 'assets/images/brand/yikaowang_logo.svg';
  static const brandMark = 'assets/images/brand/yikaowang_mark.svg';

  static const leftNavHome = 'assets/images/shell/leftNav/home.png';
  static const leftNavAi = 'assets/images/shell/leftNav/AI.png';
  static const leftNavSchool = 'assets/images/shell/leftNav/school.png';
  static const leftNavYunpan = 'assets/images/shell/leftNav/yunpan.png';
  static const leftNavVideo = 'assets/images/shell/leftNav/video.png';
  static const leftNavXiaoyuan = 'assets/images/shell/leftNav/xiaoyuan.png';
  static const leftNavBiji = 'assets/images/shell/leftNav/biji.png';
  static const leftNavShoucang = 'assets/images/shell/leftNav/shoucang.png';
  static const leftNavInfo = 'assets/images/shell/leftNav/info.png';
  static const leftNavXueqing = 'assets/images/shell/leftNav/xueqing.png';
  static const leftNavZuopin = 'assets/images/shell/leftNav/zuopin.png';
  static const leftNavFanhua = 'assets/images/shell/leftNav/fanhua.png';
  static const leftNavGongju = 'assets/images/shell/leftNav/gongju.png';
  static const leftNavShukan = 'assets/images/shell/leftNav/shukan.png';

  static const shellV2Search = 'assets/images/shell/topbar_v2/search.png';
  static const shellV2Help = 'assets/images/shell/topbar_v2/help.png';
  static const shellV2Notice = 'assets/images/shell/topbar_v2/notice.png';
  static const shellV2Setting = 'assets/images/shell/topbar_v2/setting.png';

  /// 全局页面 loading / 下拉刷新动画。
  static const homeLoading = 'assets/images/home/loading.gif';

  // 用户菜单弹层图标（地区 / 资料修改 / 退出登录）

  /// 文件预览页顶部「重命名」按钮图标（紫色铅笔，替代原本的 Material
  /// `Icons.edit_outlined`，统一视觉风格）。
  static const homeRename = 'assets/images/home/rename.png';

  /// 日期选择器输入模式下「切回日历」按钮图标。
  static const homeRili = 'assets/images/home/rili.png';

  /// 课表页控制条 · 日期选择 pill 日历图标。
  static const iconScheduleCalendar = 'assets/images/new/0图标/课表-日历.png';

  /// 学生列表 · 性别图标（男 / 女）。个人信息页性别选择仍用 [infoGenderMale] 等。
  static const iconGenderMale = 'assets/images/new/0图标/男生.png';
  static const iconGenderFemale = 'assets/images/new/0图标/女生.png';

  /// 下拉选择弹层 · 选中项右侧标记。
  static const iconDropdownSelected =
      'assets/images/new/0图标/Frame 1912057260.png';

  /// 下拉选择弹层 · 未选中项右侧标记。
  static const iconDropdownUnselected =
      'assets/images/new/0图标/Frame 1912057261.png';

  // 首页九宫格通用图标
  static const homeQuickNews = 'assets/images/home/home4.png';
  static const homeQuickQuestionBank = 'assets/images/home/home5.png';
  static const homeQuickGroupChat = 'assets/images/home/home7.png';
  static const homeQuickSchoolCircle = 'assets/images/home/home9.png';
  static const campusHomeActions = 'assets/images/smartCampus/home_actions';

  /// 左侧导航选中态背景图：深色（≈ #202020）圆角矩形 PNG，替代原本写死的纯色。
  /// 在 [_NavTile] 展开/折叠两态都通过 `BoxFit.cover` 铺满命中区，外层
  /// `BorderRadius.circular(12)` 仍保留，把图本身边缘渐变的透明像素裁掉。
  /// 首页右侧周课表「今日」日期卡片的渐变背景图（≈ 64×88，#715EFE→#9585FF
  /// 顶到底的紫渐变，自带 12 圆角）。替代 [_WeekCard] 中写死的 LinearGradient。
  /// 侧栏底部「需求反馈」入口图标。
  static const homeFeedbackIcon = 'assets/images/home/yj.png';
  static const emptyCoursePlaceholder = 'assets/images/404/kc.png';
  static const emptyCollectionPlaceholder = 'assets/images/404/sc.png';
  static const emptyCloudPlaceholder = 'assets/images/404/wx.png';
  static const emptyNotesPlaceholder = 'assets/images/404/kj.png';

  /// 我的收藏页空状态插图。
  /// 考评 / 批改类空状态插图（执笔评卷）。
  /// 考试 / 成绩类空状态插图（翻开的书本）。
  static const emptyExamPlaceholder = 'assets/images/404/jp.png';

  /// 联网搜索 chip——未开启态：浅灰描边的地球 PNG。
  /// 联网搜索 chip——开启态：紫色描边的地球 PNG，与深度思考激活态色系
  /// （#715EFE）保持一致。
  // 小美同学欢迎区头像：单图自带渐变背景与阴影，直接铺成 52×52
  static const aiChatXiaoYiIcon = 'assets/images/aichat/qiu.gif';
  // 效率工具卡背景图（与原渐变同色调，直接平铺即可）

  static const videoV2Back = 'assets/images/video/2.png';
  static const videoV2CenterPlay = 'assets/images/video/3.png';
  static const videoV2CenterPause = 'assets/images/video/4.png';
  static const videoV2Reload = 'assets/images/video/reload.png';
  static const videoV2SeekBack15 = 'assets/images/video/5.png';
  static const videoV2SmallPlay = 'assets/images/video/6.png';
  static const videoV2SmallPause = 'assets/images/video/7.png';
  static const videoV2Pip = 'assets/images/video/8.png';
  static const videoV2Setting = 'assets/images/video/10.png';
  static const videoV2FullscreenExit = 'assets/images/video/11.png';
  static const videoV2Fullscreen = 'assets/images/video/12.png';
  static const videoV2SeekForward15 = 'assets/images/video/16.png';

  static const cloudCategorySelected = 'assets/images/home/nav4.png';
  static const cloudCategoryIdle = 'assets/images/home/nav5.png';
  static const cloudFolderIcon = 'assets/images/yunpan/yp1.png';
  static const cloudActionMore = 'assets/images/yunpan/yp2.png';
  static const cloudFolderFilledBg = 'assets/images/yunpan/yp8.png';
  static const cloudFolderEmptyBg = 'assets/images/yunpan/yp9.png';

  /// 我的云盘 / 课件中心 2.0 资产
  /// 1.png 上传弹窗顶部装饰图（含纸张、结构素描）
  static const coursewareUploadHeader = 'assets/images/courseware/1.png';
  static const coursewareSort = 'assets/images/courseware/4.png';
  static const coursewareUploadFab = 'assets/images/courseware/6.png';
  static const coursewareNewFolder = 'assets/images/courseware/13.png';
  static const noteCreate = 'assets/images/note/3.png';
  static const coursewareFileTypePdf = 'assets/images/courseware/7.png';
  static const coursewareFileTypeImage = 'assets/images/courseware/8.png';
  static const coursewareFileTypeDoc = 'assets/images/courseware/9.png';
  static const coursewareFileTypeKj = 'assets/images/courseware/10.png';
  static const coursewareUploadImage = 'assets/images/courseware/11.png';
  static const coursewareUploadFile = 'assets/images/courseware/12.png';

  /// 左侧分类卡片省略号弹出菜单图标
  static const coursewareActionDelete = 'assets/images/courseware/14.png';
  static const coursewareActionCopy = 'assets/images/courseware/15.png';
  static const coursewareActionRename = 'assets/images/courseware/16.png';
  static const coursewareActionShare = 'assets/images/courseware/17.png';

  /// 校圈（社区动态）
  static const xiaoquanHeaderBg = 'assets/images/xiaoquan/bg.png';

  /// 课表页顶栏背景（auth 模块 bgtop，白→淡紫渐变 + 顶圆角）
  static const authBgTop = 'assets/images/auth/bgtop.png';

  // 录音文件在文件夹列表里的占位卡片图（对齐我的云盘的占位风格）。

  /// 智慧校园二级页顶部 banner 背景（授课课表 / 我的课表等）。
  static const smartCampusBgAspectRatio = 3880 / 272;

  /// 班主任 · 查寝动态 · 顶部统计卡背景（从左到右）。
  static const headTeacherDormDynamicStatResident =
      'assets/images/smartCampus/head_teacher/dorm_dynamic_stat_resident.png';
  static const headTeacherDormDynamicStatReturned =
      'assets/images/smartCampus/head_teacher/dorm_dynamic_stat_returned.png';
  static const headTeacherDormDynamicStatException =
      'assets/images/smartCampus/head_teacher/dorm_dynamic_stat_exception.png';
  static const headTeacherDormDynamicStatPunchAudit =
      'assets/images/smartCampus/head_teacher/dorm_dynamic_stat_punch_audit.png';

  /// 班主任 · 家校沟通 · 顶部统计卡背景（从左到右）。
  static const headTeacherHomeSchoolStatUnread =
      'assets/images/smartCampus/head_teacher/home_school_stat_unread.png';
  static const headTeacherHomeSchoolStatPendingReply =
      'assets/images/smartCampus/head_teacher/home_school_stat_pending_reply.png';
  static const headTeacherHomeSchoolStatTotal =
      'assets/images/smartCampus/head_teacher/home_school_stat_total.png';

  /// 班主任 · 请假审批 · 顶部统计卡背景（从左到右）。
  static const headTeacherLeaveApprovalStatPending =
      'assets/images/smartCampus/head_teacher/leave_approval_stat_pending.png';
  static const headTeacherLeaveApprovalStatReviewing =
      'assets/images/smartCampus/head_teacher/leave_approval_stat_reviewing.png';
  static const headTeacherLeaveApprovalStatApproved =
      'assets/images/smartCampus/head_teacher/leave_approval_stat_approved.png';
  static const headTeacherLeaveApprovalStatRejected =
      'assets/images/smartCampus/head_teacher/leave_approval_stat_rejected.png';

  /// 课表 · 编辑/申请小课抽屉 · 字段标题前图标。
  static const scheduleEditCourseTime =
      'assets/images/smartCampus/schedule_edit/course_time.png';
  static const scheduleEditClass =
      'assets/images/smartCampus/schedule_edit/class.png';
  static const scheduleEditStudent =
      'assets/images/smartCampus/schedule_edit/student.png';
  static const scheduleEditClassroom =
      'assets/images/smartCampus/schedule_edit/classroom.png';
  static const scheduleEditSubject =
      'assets/images/smartCampus/schedule_edit/subject.png';
  static const scheduleEditTeacher =
      'assets/images/smartCampus/schedule_edit/teacher.png';
  static const scheduleEditColor =
      'assets/images/smartCampus/schedule_edit/color.png';
  static const scheduleEditRepeat =
      'assets/images/smartCampus/schedule_edit/repeat.png';

  /// 管理员 · 排课与课表 · 小课申请审核列表卡片 · 班级图标。
  static const adminSmallCourseApplyCardClass = 'assets/images/new/01/xk.png';

  /// 宿管 · 查寝（按宿舍 / 历史）· 顶部统计卡背景（从左到右）。
  static const dormCheckStatCard1 =
      'assets/images/smartCampus/dorm_check/stat_card_1.png';
  static const dormCheckStatCard2 =
      'assets/images/smartCampus/dorm_check/stat_card_2.png';
  static const dormCheckStatCard3 =
      'assets/images/smartCampus/dorm_check/stat_card_3.png';
  static const dormCheckStatCard4 =
      'assets/images/smartCampus/dorm_check/stat_card_4.png';

  /// 管理员 · 班级编组 · 顶部统计卡背景（从左到右）。
  static const adminClassManagementStatCard1 =
      'assets/images/smartCampus/admin/class_management/stat_card_1.png';
  static const adminClassManagementStatCard2 =
      'assets/images/smartCampus/admin/class_management/stat_card_2.png';
  static const adminClassManagementStatCard3 =
      'assets/images/smartCampus/admin/class_management/stat_card_3.png';
  static const adminClassManagementStatCard4 =
      'assets/images/smartCampus/admin/class_management/stat_card_4.png';

  /// 管理员 · 签课管理 · 顶部统计卡背景（从左到右）。
  static const adminSignManagementStatCard1 =
      'assets/images/smartCampus/admin/sign_management/stat_card_1.png';
  static const adminSignManagementStatCard2 =
      'assets/images/smartCampus/admin/sign_management/stat_card_2.png';
  static const adminSignManagementStatCard3 =
      'assets/images/smartCampus/admin/sign_management/stat_card_3.png';
  static const adminSignManagementStatCard4 =
      'assets/images/smartCampus/admin/sign_management/stat_card_4.png';
  static const adminSignManagementStudentIcon =
      'assets/images/smartCampus/admin/sign_management/student_icon.png';

  /// 管理员 · 教师管理 · 顶部统计卡背景（从左到右）。
  static const adminTeacherManagementStatCard1 =
      'assets/images/smartCampus/admin/teacher_management/stat_card_1.png';
  static const adminTeacherManagementStatCard2 =
      'assets/images/smartCampus/admin/teacher_management/stat_card_2.png';
  static const adminTeacherManagementStatCard3 =
      'assets/images/smartCampus/admin/teacher_management/stat_card_3.png';
  static const adminTeacherManagementStatCard4 =
      'assets/images/smartCampus/admin/teacher_management/stat_card_4.png';

  /// 管理员 · 人脸库 · 顶部统计卡背景（从左到右）。
  static const adminFaceLibraryStatCard1 =
      'assets/images/smartCampus/admin/face_library/stat_card_1.png';
  static const adminFaceLibraryStatCard2 =
      'assets/images/smartCampus/admin/face_library/stat_card_2.png';
  static const adminFaceLibraryStatCard3 =
      'assets/images/smartCampus/admin/face_library/stat_card_3.png';
  static const adminFaceLibraryStatCard4 =
      'assets/images/smartCampus/admin/face_library/stat_card_4.png';
  static const adminFaceLibraryEntryCardBg =
      'assets/images/smartCampus/admin/face_library/entry_card_bg.png';

  /// 管理员 · 人脸库 · 采集规范示例图（左→右：❌ ❌ ✅）。
  static const adminFaceLibraryStandardSample1 =
      'assets/images/new/01/001/Frame 1912057041.png';
  static const adminFaceLibraryStandardSample2 =
      'assets/images/new/01/001/Frame 1912057042.png';
  static const adminFaceLibraryStandardSample3 =
      'assets/images/new/01/001/Frame 1912057044.png';

  /// 管理员 · 通知管理 · 顶部统计卡背景（从左到右）。
  static const adminNotificationStatCard1 =
      'assets/images/smartCampus/admin/notification/stat_card_1.png';
  static const adminNotificationStatCard2 =
      'assets/images/smartCampus/admin/notification/stat_card_2.png';
  static const adminNotificationStatCard3 =
      'assets/images/smartCampus/admin/notification/stat_card_3.png';
  static const adminNotificationStatCard4 =
      'assets/images/smartCampus/admin/notification/stat_card_4.png';

  /// 管理员 · 教师/宿管请假审批 · 顶部统计卡背景（从左到右）。
  static const adminStaffLeaveStatCard1 =
      'assets/images/smartCampus/admin/staff_leave/stat_card_1.png';
  static const adminStaffLeaveStatCard2 =
      'assets/images/smartCampus/admin/staff_leave/stat_card_2.png';
  static const adminStaffLeaveStatCard3 =
      'assets/images/smartCampus/admin/staff_leave/stat_card_3.png';

  /// 管理员 · 学生管理 · 顶部统计卡背景（从左到右）。
  static const adminStudentManagementStatCard1 =
      'assets/images/smartCampus/admin/student_management/stat_card_1.png';
  static const adminStudentManagementStatCard2 =
      'assets/images/smartCampus/admin/student_management/stat_card_2.png';
  static const adminStudentManagementStatCard3 =
      'assets/images/smartCampus/admin/student_management/stat_card_3.png';
  static const adminStudentManagementStatCard4 =
      'assets/images/smartCampus/admin/student_management/stat_card_4.png';

  /// 学生 · 我的请假 · 顶部统计卡背景（从左到右）。
  static const studentLeaveStatCard1 =
      'assets/images/smartCampus/student/leave/stat_card_1.png';
  static const studentLeaveStatCard2 =
      'assets/images/smartCampus/student/leave/stat_card_2.png';
  static const studentLeaveStatCard3 =
      'assets/images/smartCampus/student/leave/stat_card_3.png';

  /// 任课老师 / 班主任 · 学生名册 · 顶部统计卡背景（当前列表 / 男 / 女）。
  static const teacherStudentRosterStatCard1 =
      'assets/images/smartCampus/teacher/student_roster/stat_card_1.png';
  static const teacherStudentRosterStatCard2 =
      'assets/images/smartCampus/teacher/student_roster/stat_card_2.png';
  static const teacherStudentRosterStatCard3 =
      'assets/images/smartCampus/teacher/student_roster/stat_card_3.png';

  /// 作业与批改 · 发布作业截止时间 / 学生我的作业截止时间。
  static const homeworkDeadlineIcon =
      'assets/images/smartCampus/teacher/homework/deadline_icon.png';

  /// 作业点评抽屉 · 附件下载 / 在线预览 / 语音点评 / 删除语音。
  static const homeworkReviewDownloadIcon =
      'assets/images/smartCampus/teacher/homework/review_download_icon.png';
  static const homeworkReviewPreviewIcon =
      'assets/images/smartCampus/teacher/homework/review_preview_icon.png';
  static const homeworkReviewVoiceIcon =
      'assets/images/smartCampus/teacher/homework/review_voice_icon.png';
  static const homeworkReviewVoiceActiveIcon =
      'assets/images/smartCampus/teacher/homework/review_voice_active_icon.png';
  static const homeworkReviewDeleteIcon =
      'assets/images/smartCampus/teacher/homework/review_delete_icon.png';

  /// 任课老师 · 考评管理 · 卡片「考场安排」图标。
  static const teacherExamSeatPlanIcon =
      'assets/images/smartCampus/teacher/exam/seat_plan_icon.png';

  // 智慧校园群聊
  static const groupChatPinAction = 'assets/images/groupChat/zd.png';
  static const groupChatPinActionOn = 'assets/images/groupChat/yzd.png';
  static const groupChatSet = 'assets/images/groupChat/set.png';
  static const groupChatInfo = 'assets/images/new/群聊/群聊-群公告.png';
  static const groupChatMessage = 'assets/images/new/群聊/群聊-消息.png';
  static const groupChatMessageMuted = 'assets/images/new/群聊/群聊-消息免打扰0.png';
  static const groupChatVoice = 'assets/images/groupChat/voice.png';
  static const groupChatVoiceMode = 'assets/images/groupChat/voice1.png';
  static const groupChatMsg = 'assets/images/groupChat/msg.png';
  static const groupChatUpload = 'assets/images/groupChat/sc.png';
  static const groupChatPlay = 'assets/images/groupChat/play.png';
  static const groupChatStop = 'assets/images/groupChat/stop.png';
  static const groupChatKj = 'assets/images/groupChat/kj.png';
  static const groupChatEmojiTab1 = 'assets/images/groupChat/face1.png';
  static const groupChatEmojiTab1Active = 'assets/images/groupChat/face1A.png';
  static const groupChatEmojiTab2 = 'assets/images/groupChat/face2.png';
  static const groupChatEmojiTab2Active = 'assets/images/groupChat/face2A.png';
  static const groupChatEmojiTab3 = 'assets/images/groupChat/face3.png';
  static const groupChatEmojiTab3Active = 'assets/images/groupChat/face3A.png';
  static const groupChatEmojiTab4 = 'assets/images/groupChat/face4.png';
  static const groupChatEmojiTab4Active = 'assets/images/groupChat/face4A.png';
  static const groupChatEmojiTab5 = 'assets/images/groupChat/face5.png';
  static const groupChatEmojiTab5Active = 'assets/images/groupChat/face5A.png';
  static const groupChatEmojiTab6 = 'assets/images/groupChat/face6.png';
  static const groupChatEmojiTab6Active = 'assets/images/groupChat/face6A.png';

  /// 微信经典表情雪碧图（11×10）。
  static const emojiSprite = 'assets/images/new/emoji-sprite.png';
}
