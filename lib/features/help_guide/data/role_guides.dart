import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

/// 新手引导的一步：介绍一个入口，[where] 说明在哪里找到它。
@immutable
class RoleGuideStep {
  const RoleGuideStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.where,
  });

  final IconData icon;
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
const roleGuideRoles = <String>[
  'student',
  'teacher',
  'headTeacher',
  'dormManager',
  'admin',
];

/// 各身份的新手引导，每步都指向该身份真实可见的入口；未知身份按学生处理。
RoleGuide roleGuideFor(String role) => switch (role.trim()) {
  'teacher' => _teacher,
  'headTeacher' => _headTeacher,
  'dormManager' => _dormManager,
  'admin' => _admin,
  _ => _student,
};

const _student = RoleGuide(
  role: 'student',
  roleLabel: '学生',
  steps: [
    RoleGuideStep(
      icon: Icons.insights_rounded,
      title: '我的学情',
      body: '月考出分后，在这里看总分、排名和各科档位，也能打开原卷和评分标准对照着看。',
      where: '左侧导航「我的学情」',
    ),
    RoleGuideStep(
      icon: Icons.collections_outlined,
      title: '作品档案',
      body: '日常作业拍照上传后，任课老师会打分、写评语、在图上批注，点评完成会收到通知。',
      where: '左侧导航「作品档案」',
    ),
    RoleGuideStep(
      icon: Icons.palette_outlined,
      title: '画室工具箱',
      body: '看画分析、练习训练、备考助手三组工具，比如明度检查、眯眼模糊、速写计时练习和综合分计算器。',
      where: '左侧导航「画室工具箱」',
    ),
    RoleGuideStep(
      icon: Icons.menu_book_outlined,
      title: '美术书刊',
      body: '美术教辅与画室月刊，读到哪一页会记下来，下次从那一页继续。',
      where: '左侧导航「美术书刊」，首页「继续阅读」',
    ),
  ],
);

const _teacher = RoleGuide(
  role: 'teacher',
  roleLabel: '任课老师',
  steps: [
    RoleGuideStep(
      icon: Icons.rate_review_outlined,
      title: '作品点评',
      body: '学生上传的作品会进入你的点评队列，可以打分、选标签、写评语，也能直接在图上批注。',
      where: '左侧导航「作品点评」，首页显示待点评件数',
    ),
    RoleGuideStep(
      icon: Icons.insights_rounded,
      title: '班级学情',
      body: '按考试查看分数分布和各科均分，点开学生可以看成绩报告与成长曲线。',
      where: '左侧导航「班级学情」',
    ),
    RoleGuideStep(
      icon: Icons.apartment_outlined,
      title: '智慧校园',
      body: '授课课表、签课管理、作业批改与考评管理都在这里，班级群聊也在这里。',
      where: '左侧导航「智慧校园」',
    ),
  ],
);

const _headTeacher = RoleGuide(
  role: 'headTeacher',
  roleLabel: '班主任',
  steps: [
    RoleGuideStep(
      icon: Icons.apartment_outlined,
      title: '班级工作台',
      body: '班级通知、请假审批、考勤和家校沟通，集中在智慧校园的班级工作台。',
      where: '左侧导航「智慧校园」',
    ),
    RoleGuideStep(
      icon: Icons.insights_rounded,
      title: '班级学情',
      body: '按考试查看分数分布和各科均分，点开学生可以看成绩报告与成长曲线。',
      where: '左侧导航「班级学情」',
    ),
    RoleGuideStep(
      icon: Icons.rate_review_outlined,
      title: '作品点评',
      body: '分配给你的学生作品会进入点评队列，点评完成后学生会收到通知。',
      where: '左侧导航「作品点评」',
    ),
    RoleGuideStep(
      icon: Icons.checklist_rounded,
      title: '今日待办',
      body: '首页汇总待点评作品、班级工作台和未读消息，点一下直接进入。',
      where: '首页「今日待办」',
    ),
  ],
);

const _dormManager = RoleGuide(
  role: 'dormManager',
  roleLabel: '宿管',
  steps: [
    RoleGuideStep(
      icon: Icons.checklist_rounded,
      title: '今日待办',
      body: '首页右侧显示今晚和明早的查寝时间，以及到岗打卡和未读消息。',
      where: '首页「今日待办」',
    ),
    RoleGuideStep(
      icon: Icons.king_bed_outlined,
      title: '按宿舍查寝',
      body: '按宿舍逐间登记学生的归寝情况，往期结果在「查寝历史」里查看。',
      where: '首页功能入口「按宿舍查寝」',
    ),
    RoleGuideStep(
      icon: Icons.how_to_reg_outlined,
      title: '到岗打卡',
      body: '宿管本人的上下班打卡，以及历次打卡记录。',
      where: '首页功能入口「到岗打卡」',
    ),
    RoleGuideStep(
      icon: Icons.edit_note_rounded,
      title: '宿管请假',
      body: '需要请假时在这里提交申请，由管理员审批。',
      where: '首页功能入口「宿管请假」',
    ),
  ],
);

const _admin = RoleGuide(
  role: 'admin',
  roleLabel: '管理员',
  steps: [
    RoleGuideStep(
      icon: Icons.apartment_outlined,
      title: '教务管理',
      body: '学生、教师、班级编辑与排课都在智慧校园，首页的功能入口可以直接打开。',
      where: '左侧导航「智慧校园」',
    ),
    RoleGuideStep(
      icon: Icons.approval_outlined,
      title: '审批与签课',
      body: '老师和宿管的请假在「教师请假审批」处理，小课签课在「签课管理」确认。',
      where: '首页「今日待办」与功能入口',
    ),
    RoleGuideStep(
      icon: Icons.campaign_outlined,
      title: '通知管理',
      body: '向全校或指定班级发布通知，可以定时发布，也可以先存为草稿。',
      where: '首页功能入口「通知管理」',
    ),
    RoleGuideStep(
      icon: Icons.insights_rounded,
      title: '班级学情',
      body: '按考试查看全画室的分数分布、各科均分与校区对比。',
      where: '左侧导航「班级学情」',
    ),
  ],
);
