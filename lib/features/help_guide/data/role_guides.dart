import 'package:flutter/foundation.dart';

import '../../../core/constants/app_assets.dart';

/// 新手引导的一步：介绍一个入口，[where] 说明在哪里找到它。
@immutable
class RoleGuideStep {
  const RoleGuideStep({
    required this.iconAsset,
    required this.title,
    required this.body,
    required this.where,
  });

  final String iconAsset;
  final String title;
  final String body;
  final String where;
}

@immutable
class RoleGuide {
  const RoleGuide({
    required this.role,
    required this.roleLabel,
    required this.steps,
  });

  /// `/myInfo` 的 role。
  final String role;
  final String roleLabel;
  final List<RoleGuideStep> steps;
}

/// 有新手引导的身份（与 `/myInfo` 的 role 取值一致）。
/// 教学组长的 role 仍是 teacher，与任课老师共用引导。
const roleGuideRoles = <String>[
  'student',
  'teacher',
  'headTeacher',
  'dormManager',
  'admin',
  'principal',
];

/// 各身份的新手引导，每步都指向该身份真实可见的入口；未知身份按学生处理。
RoleGuide roleGuideFor(String role) => switch (role.trim()) {
  'teacher' => _teacher,
  'headTeacher' => _headTeacher,
  'dormManager' => _dormManager,
  'admin' => _admin,
  'principal' => _principal,
  _ => _student,
};

const _student = RoleGuide(
  role: 'student',
  roleLabel: '学生',
  steps: [
    RoleGuideStep(
      iconAsset: AppAssets.leftNavJinri,
      title: '今日学习',
      body: '今天要交的作品、老师点评后的练习建议和当天课程都在这里，点一下就能去完成。',
      where: '左侧导航「今日学习」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavXueqing,
      title: '学情',
      body: '月考出分后，在这里看总分、排名和各科档位，也能打开原卷和评分标准对照着看。',
      where: '首页「学情」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavZuopin,
      title: '作品档案',
      body: '日常作品拍照上传后，由责任老师打分、写评语、在图上批注；需要时组长会复核，校长也可点评或推优。',
      where: '首页「作业」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavGongju,
      title: '画室工具箱',
      body: '看画分析、练习训练、备考助手三组工具，比如明度检查、眯眼模糊、速写计时练习和综合分计算器。',
      where: '首页「工具」',
    ),
  ],
);

const _teacher = RoleGuide(
  role: 'teacher',
  roleLabel: '任课老师',
  steps: [
    RoleGuideStep(
      iconAsset: AppAssets.leftNavJinri,
      title: '今日工作',
      body: '待点评的作品、要签的课和需要关注的学生都在这里，按轻重排好，点一下直接进入。',
      where: '左侧导航「今日工作」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavZuopin,
      title: '作品点评',
      body: '学生上传的作品会进入你的点评队列，可以打分、选标签、写评语，也能直接在图上批注。',
      where: '今日工作「待点评作品」，或首页「作业」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavXueqing,
      title: '班级学情',
      body: '按考试查看分数分布和各科均分，点开学生可以看成绩报告与成长曲线。',
      where: '左侧导航「班级学情」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavXiaoyuan,
      title: '智慧校园',
      body: '授课课表、签课管理、作品批改与考评管理都在这里，班级群聊也在这里。',
      where: '左侧导航「智慧校园」',
    ),
  ],
);

const _headTeacher = RoleGuide(
  role: 'headTeacher',
  roleLabel: '班主任',
  steps: [
    RoleGuideStep(
      iconAsset: AppAssets.leftNavJinri,
      title: '今日工作',
      body: '待点评作品、学生请假审批、查寝异常和家长消息集中在这里，点一下直接进入。',
      where: '左侧导航「今日工作」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavXiaoyuan,
      title: '班级工作台',
      body: '班级通知、请假审批、考勤和家校沟通，集中在智慧校园的班级工作台。',
      where: '今日工作底部「班级工作台」，或左侧导航「智慧校园」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavXueqing,
      title: '班级学情',
      body: '按考试查看分数分布和各科均分，点开学生可以看成绩报告与成长曲线。',
      where: '左侧导航「班级学情」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavZuopin,
      title: '作品点评',
      body: '分配给你的学生作品会进入点评队列，点评完成后学生会收到通知。',
      where: '今日工作「待点评作品」，或首页「作业」',
    ),
  ],
);

const _dormManager = RoleGuide(
  role: 'dormManager',
  roleLabel: '宿管',
  steps: [
    RoleGuideStep(
      iconAsset: AppAssets.leftNavJinri,
      title: '今日工作',
      body: '这一场查寝还有几人没打卡、待审核的补卡和当天的值班时间都在这里。',
      where: '左侧导航「今日工作」',
    ),
    RoleGuideStep(
      iconAsset:
          '${AppAssets.campusHomeActions}/dorm_manager/dorm_check_by_room.png',
      title: '按宿舍查寝',
      body: '按宿舍逐间登记学生的归寝情况，往期结果在「查寝历史」里查看。',
      where: '今日工作「按宿舍查寝」，或首页「查寝」',
    ),
    RoleGuideStep(
      iconAsset:
          '${AppAssets.campusHomeActions}/dorm_manager/punch_management.png',
      title: '到岗打卡',
      body: '宿管本人的上下班打卡，以及历次打卡记录。',
      where: '今日工作「到岗打卡」',
    ),
    RoleGuideStep(
      iconAsset: '${AppAssets.campusHomeActions}/dorm_manager/dorm_leave.png',
      title: '宿管请假',
      body: '需要请假时在这里提交申请，由管理员审批。',
      where: '今日工作底部「宿管请假」',
    ),
  ],
);

const _admin = RoleGuide(
  role: 'admin',
  roleLabel: '管理员',
  steps: [
    RoleGuideStep(
      iconAsset: AppAssets.leftNavJinri,
      title: '今日工作',
      body: '教职工请假审批、小课签课确认和小课申请集中在这里，常用的管理入口在页面底部。',
      where: '左侧导航「今日工作」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavXiaoyuan,
      title: '教务管理',
      body: '学生、教师、班级管理与排课都在智慧校园。',
      where: '左侧导航「智慧校园」',
    ),
    RoleGuideStep(
      iconAsset:
          '${AppAssets.campusHomeActions}/admin/notification_management.png',
      title: '通知管理',
      body: '向全校或指定班级发布通知，可以定时发布，也可以先存为草稿。',
      where: '今日工作底部「通知管理」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavXueqing,
      title: '班级学情',
      body: '按考试查看全画室的分数分布、各科均分与校区对比。',
      where: '左侧导航「班级学情」',
    ),
  ],
);

const _principal = RoleGuide(
  role: 'principal',
  roleLabel: '校长',
  steps: [
    RoleGuideStep(
      iconAsset: AppAssets.leftNavJinri,
      title: '今日工作',
      body: '超时未点评的作品、校长信箱、请假审批和需要跟进的教学事项集中在这里。',
      where: '左侧导航「今日工作」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavXueqing,
      title: '全校学情',
      body: '教学指标、近七天趋势和各类教学报表从这里进入，可以按校区查看，也能点开学生的成绩报告与成长曲线。',
      where: '左侧导航「全校学情」',
    ),
    RoleGuideStep(
      iconAsset: AppAssets.leftNavXiaoyuan,
      title: '智慧校园',
      body: '学生、教师、班级管理与排课都在这里，「校长信箱」里可以查看并回复师生来信。',
      where: '左侧导航「智慧校园」',
    ),
  ],
);
