import 'package:flutter/material.dart' show IconData, Icons;

import '../../../app/router/route_paths.dart';

class HomeBannerItem {
  const HomeBannerItem({required this.imageUrl});

  final String imageUrl;
}

/// 打开智慧校园里的某个视图（宿管、管理员首页的工作入口）。
enum HomeCampusTarget {
  groupChat,
  schoolCircle,
  principalMailbox,
  dormCheckByRoom,
  dormDynamic,
  dormHistory,
  dormCheckIn,
  myLeave,
  studentManagement,
  teacherManagement,
  classManagement,
  scheduleManagement,
  signManagement,
  leaveApproval,
  faceLibrary,
  notificationManagement,
  classWorkbench,
}

/// 首页九宫格入口：名称与侧栏、页头、智慧校园入口保持同一叫法。
class HomeQuickAction {
  const HomeQuickAction({
    required this.name,
    required this.icon,
    this.route = RoutePaths.smartCampus,
    this.arguments,
    this.campus,
  });

  final String name;
  final IconData icon;
  final String route;
  final Map<String, dynamic>? arguments;

  /// 设置后打开智慧校园对应视图，[route] 不再使用。
  final HomeCampusTarget? campus;
}

class HomeNewsItem {
  const HomeNewsItem({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.tags,
    required this.viewCount,
    required this.createTime,
  });

  final int id;
  final String title;
  final String shortTitle;
  final List<String> tags;
  final int viewCount;
  final DateTime? createTime;
}

class HomeWeekDayItem {
  const HomeWeekDayItem({
    required this.weekText,
    required this.dayText,
    required this.dateText,
    required this.courseCount,
    required this.isToday,
  });

  final String weekText;
  final String dayText;

  /// YYYY-MM-DD。
  final String dateText;
  final int courseCount;
  final bool isToday;

  HomeWeekDayItem copyWith({int? courseCount}) {
    return HomeWeekDayItem(
      weekText: weekText,
      dayText: dayText,
      dateText: dateText,
      courseCount: courseCount ?? this.courseCount,
      isToday: isToday,
    );
  }
}

enum HomeCourseStatus { ended, inProgress, upcoming }

class HomeCourseNotice {
  const HomeCourseNotice({
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.teacherName,
    required this.teacherAvatar,
    required this.description,
    required this.status,
    this.date = '',
    this.isSmallCourse = false,
    this.cardColorHex,
  });

  final String startTime;
  final String endTime;
  final String subjectName;
  final String teacherName;
  final String teacherAvatar;

  /// 时长 · 班级 · 教室。
  final String description;
  final HomeCourseStatus status;

  /// 上课日期 YYYY-MM-DD；接口未给出时为空。
  final String date;

  /// 课程类型：false = 大课（type 0），true = 小课（type 1）。
  final bool isSmallCourse;
  // 接口 `color` 字段，如 "#fed7aa"，用于大课 / 小课标签的圆点
  final String? cardColorHex;

  String get statusText => switch (status) {
    HomeCourseStatus.ended => '已结束',
    HomeCourseStatus.inProgress => '进行中',
    HomeCourseStatus.upcoming => '待开始',
  };
}

class HomeDashboardState {
  const HomeDashboardState({
    this.loading = true,
    this.role = '',
    this.bannerItems = const [],
    this.quickActions = const [],
    this.weekItems = const [],
    this.newsItems = const [],
    this.courseNotices = const [],
    this.errorMessage = '',
  });

  final bool loading;

  /// `/myInfo` 的 role（student / teacher / headTeacher / dormManager / admin）。
  final String role;
  final List<HomeBannerItem> bannerItems;
  final List<HomeQuickAction> quickActions;

  /// 本周七天的课程数；没有个人课表的角色（宿管、管理员）为空，首页不显示周条。
  final List<HomeWeekDayItem> weekItems;
  final List<HomeNewsItem> newsItems;
  final List<HomeCourseNotice> courseNotices;
  final String errorMessage;

  /// 宿管首页显示值班与查寝，不显示课表和成绩。
  bool get isDormManager => role == 'dormManager';

  /// 至少有一块数据已到位。
  bool get hasContent =>
      bannerItems.isNotEmpty ||
      newsItems.isNotEmpty ||
      weekItems.isNotEmpty ||
      courseNotices.isNotEmpty;

  HomeDashboardState copyWith({
    bool? loading,
    String? role,
    List<HomeBannerItem>? bannerItems,
    List<HomeQuickAction>? quickActions,
    List<HomeWeekDayItem>? weekItems,
    List<HomeNewsItem>? newsItems,
    List<HomeCourseNotice>? courseNotices,
    String? errorMessage,
  }) {
    return HomeDashboardState(
      loading: loading ?? this.loading,
      role: role ?? this.role,
      bannerItems: bannerItems ?? this.bannerItems,
      quickActions: quickActions ?? this.quickActions,
      weekItems: weekItems ?? this.weekItems,
      newsItems: newsItems ?? this.newsItems,
      courseNotices: courseNotices ?? this.courseNotices,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 首页九宫格，按角色给入口：学生与任课老师、班主任是学习入口（教职工看「班级学情 /
/// 作品点评」），宿管是查寝与值班工具，管理员是教务管理工具（名称与智慧校园工作台一致）。
///
/// 数量不固定，首页按条目数排列，新增入口直接追加。
List<HomeQuickAction> buildQuickActions({bool isStaff = false, String role = ''}) {
  if (role == 'dormManager') {
    return const <HomeQuickAction>[
      HomeQuickAction(
        name: '按宿舍查寝',
        icon: Icons.king_bed_outlined,
        campus: HomeCampusTarget.dormCheckByRoom,
      ),
      HomeQuickAction(
        name: '查寝动态',
        icon: Icons.fact_check_outlined,
        campus: HomeCampusTarget.dormDynamic,
      ),
      HomeQuickAction(
        name: '查寝历史',
        icon: Icons.history_rounded,
        campus: HomeCampusTarget.dormHistory,
      ),
      HomeQuickAction(
        name: '到岗打卡',
        icon: Icons.how_to_reg_outlined,
        campus: HomeCampusTarget.dormCheckIn,
      ),
      HomeQuickAction(
        name: '宿管请假',
        icon: Icons.edit_note_rounded,
        campus: HomeCampusTarget.myLeave,
      ),
      HomeQuickAction(
        name: '校圈',
        icon: Icons.forum_outlined,
        campus: HomeCampusTarget.schoolCircle,
      ),
      HomeQuickAction(
        name: '群聊',
        icon: Icons.chat_outlined,
        campus: HomeCampusTarget.groupChat,
      ),
      HomeQuickAction(
        name: '校长信箱',
        icon: Icons.markunread_mailbox_outlined,
        campus: HomeCampusTarget.principalMailbox,
      ),
    ];
  }
  if (role == 'admin') {
    return const <HomeQuickAction>[
      HomeQuickAction(
        name: '学生管理',
        icon: Icons.groups_outlined,
        campus: HomeCampusTarget.studentManagement,
      ),
      HomeQuickAction(
        name: '教师管理',
        icon: Icons.badge_outlined,
        campus: HomeCampusTarget.teacherManagement,
      ),
      HomeQuickAction(
        name: '班级编辑',
        icon: Icons.class_outlined,
        campus: HomeCampusTarget.classManagement,
      ),
      HomeQuickAction(
        name: '排课与课表',
        icon: Icons.calendar_month_outlined,
        campus: HomeCampusTarget.scheduleManagement,
      ),
      HomeQuickAction(
        name: '签课管理',
        icon: Icons.how_to_reg_outlined,
        campus: HomeCampusTarget.signManagement,
      ),
      HomeQuickAction(
        name: '教师请假审批',
        icon: Icons.approval_outlined,
        campus: HomeCampusTarget.leaveApproval,
      ),
      HomeQuickAction(
        name: '人脸库',
        icon: Icons.face_outlined,
        campus: HomeCampusTarget.faceLibrary,
      ),
      HomeQuickAction(
        name: '通知管理',
        icon: Icons.campaign_outlined,
        campus: HomeCampusTarget.notificationManagement,
      ),
      HomeQuickAction(
        name: '班级学情',
        icon: Icons.insights_rounded,
        route: RoutePaths.studyCenter,
      ),
    ];
  }
  return <HomeQuickAction>[
    HomeQuickAction(
      name: isStaff ? '班级学情' : '我的学情',
      icon: Icons.insights_rounded,
      route: RoutePaths.studyCenter,
    ),
    HomeQuickAction(
      name: isStaff ? '作品点评' : '作品档案',
      icon: isStaff ? Icons.rate_review_outlined : Icons.collections_outlined,
      route: RoutePaths.artworks,
    ),
    const HomeQuickAction(
      name: '范画库',
      icon: Icons.photo_library_outlined,
      route: RoutePaths.gallery,
    ),
    const HomeQuickAction(
      name: '画室工具箱',
      icon: Icons.palette_outlined,
      route: RoutePaths.artToolbox,
    ),
    const HomeQuickAction(
      name: '速写计时练习',
      icon: Icons.timer_outlined,
      route: RoutePaths.artToolbox,
      arguments: <String, dynamic>{'tool': 'quickSketch'},
    ),
    const HomeQuickAction(
      name: '题库',
      icon: Icons.quiz_outlined,
      route: RoutePaths.camp,
    ),
    const HomeQuickAction(
      name: '资讯',
      icon: Icons.article_outlined,
      route: RoutePaths.consultation,
    ),
    const HomeQuickAction(
      name: '校圈',
      icon: Icons.forum_outlined,
      route: RoutePaths.circle,
    ),
    const HomeQuickAction(
      name: '群聊',
      icon: Icons.chat_outlined,
      campus: HomeCampusTarget.groupChat,
    ),
  ];
}
