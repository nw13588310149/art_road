import 'package:flutter/material.dart' show IconData, Icons;

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';

class HomeBannerItem {
  const HomeBannerItem({required this.imageUrl, this.title = ''});

  final String imageUrl;
  final String title;
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
  myHomework,
  homeworkReview,
}

/// 首页九宫格入口：名称与侧栏、页头、智慧校园入口保持同一叫法。
class HomeQuickAction {
  const HomeQuickAction({
    required this.name,
    this.icon,
    this.iconAsset,
    this.route = RoutePaths.smartCampus,
    this.arguments,
    this.campus,
    this.comingSoon = false,
  }) : assert((icon == null) != (iconAsset == null));

  final String name;
  final IconData? icon;
  final String? iconAsset;
  final String route;
  final Map<String, dynamic>? arguments;

  /// 设置后打开智慧校园对应视图，[route] 不再使用。
  final HomeCampusTarget? campus;

  /// 功能还没有页面时，点击只提示即将上线。
  final bool comingSoon;
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

/// 首页按哪一类身份布局：科目组长沿用任课老师的首页，校长沿用管理员的首页。
/// 其他身份原样返回。
String homeRoleKind(String role) => switch (role.trim()) {
  'subjectLead' => 'teacher',
  'principal' => 'admin',
  final value => value,
};

/// 首页九宫格，按角色给入口。学生、任课老师、班主任从左到右、从上到下为：
/// 资讯、校圈、群聊、工具箱、作业、素材库、作品库、小课件、集市。
/// 作业对学生打开「我的作业」，对老师和班主任打开「作业批改」。
/// 素材库打开范画库，作品库打开作品档案（老师为作品点评），小课件打开校园课件。
/// 集市尚未上线。宿管是查寝与值班工具，管理员是教务管理工具。
List<HomeQuickAction> buildQuickActions({
  bool isStaff = false,
  String role = '',
}) {
  const campusIcons = AppAssets.campusHomeActions;
  role = homeRoleKind(role);
  if (role == 'dormManager') {
    return const <HomeQuickAction>[
      HomeQuickAction(
        name: '按宿舍查寝',
        iconAsset: '$campusIcons/dorm_manager/dorm_check_by_room.png',
        campus: HomeCampusTarget.dormCheckByRoom,
      ),
      HomeQuickAction(
        name: '查寝动态',
        iconAsset: '$campusIcons/head_teacher/dorm_dynamic.png',
        campus: HomeCampusTarget.dormDynamic,
      ),
      HomeQuickAction(
        name: '查寝历史',
        iconAsset: '$campusIcons/dorm_manager/dorm_history.png',
        campus: HomeCampusTarget.dormHistory,
      ),
      HomeQuickAction(
        name: '到岗打卡',
        iconAsset: '$campusIcons/dorm_manager/punch_management.png',
        campus: HomeCampusTarget.dormCheckIn,
      ),
      HomeQuickAction(
        name: '宿管请假',
        iconAsset: '$campusIcons/dorm_manager/dorm_leave.png',
        campus: HomeCampusTarget.myLeave,
      ),
      HomeQuickAction(
        name: '校圈',
        iconAsset: '$campusIcons/dorm_manager/school_circle.png',
        campus: HomeCampusTarget.schoolCircle,
      ),
      HomeQuickAction(
        name: '群聊',
        iconAsset: '$campusIcons/dorm_manager/group_chat.png',
        campus: HomeCampusTarget.groupChat,
      ),
      HomeQuickAction(
        name: '校长信箱',
        iconAsset: '$campusIcons/dorm_manager/principal_mailbox.png',
        campus: HomeCampusTarget.principalMailbox,
      ),
    ];
  }
  if (role == 'admin') {
    return const <HomeQuickAction>[
      HomeQuickAction(
        name: '学生管理',
        iconAsset: '$campusIcons/admin/student_management.png',
        campus: HomeCampusTarget.studentManagement,
      ),
      HomeQuickAction(
        name: '教师管理',
        iconAsset: '$campusIcons/admin/teacher_management.png',
        campus: HomeCampusTarget.teacherManagement,
      ),
      HomeQuickAction(
        name: '班级管理',
        iconAsset: '$campusIcons/admin/class_management.png',
        campus: HomeCampusTarget.classManagement,
      ),
      HomeQuickAction(
        name: '排课与课表',
        iconAsset: '$campusIcons/admin/schedule_management.png',
        campus: HomeCampusTarget.scheduleManagement,
      ),
      HomeQuickAction(
        name: '签课管理',
        iconAsset: '$campusIcons/admin/schedule_management.png',
        campus: HomeCampusTarget.signManagement,
      ),
      HomeQuickAction(
        name: '教师请假审批',
        iconAsset: '$campusIcons/admin/dorm_leave_approval.png',
        campus: HomeCampusTarget.leaveApproval,
      ),
      HomeQuickAction(
        name: '人脸库',
        iconAsset: '$campusIcons/admin/face_library.png',
        campus: HomeCampusTarget.faceLibrary,
      ),
      HomeQuickAction(
        name: '通知管理',
        iconAsset: '$campusIcons/admin/notification_management.png',
        campus: HomeCampusTarget.notificationManagement,
      ),
      HomeQuickAction(
        name: '班级学情',
        iconAsset: '$campusIcons/student/my_grades.png',
        route: RoutePaths.studyCenter,
      ),
    ];
  }
  return <HomeQuickAction>[
    const HomeQuickAction(
      name: '资讯',
      iconAsset: AppAssets.homeQuickNews,
      route: RoutePaths.consultation,
    ),
    const HomeQuickAction(
      name: '校圈',
      iconAsset: AppAssets.homeQuickSchoolCircle,
      route: RoutePaths.circle,
    ),
    const HomeQuickAction(
      name: '群聊',
      iconAsset: AppAssets.homeQuickGroupChat,
      campus: HomeCampusTarget.groupChat,
    ),
    const HomeQuickAction(
      name: '工具箱',
      iconAsset: '$campusIcons/head_teacher/class_workbench.png',
      route: RoutePaths.artToolbox,
      arguments: <String, dynamic>{'returnToSource': true},
    ),
    HomeQuickAction(
      name: '作业',
      iconAsset: '$campusIcons/student/my_homework.png',
      campus: isStaff
          ? HomeCampusTarget.homeworkReview
          : HomeCampusTarget.myHomework,
    ),
    const HomeQuickAction(
      name: '素材库',
      iconAsset: '$campusIcons/admin/class_management.png',
      route: RoutePaths.gallery,
    ),
    const HomeQuickAction(
      name: '作品库',
      iconAsset: '$campusIcons/teacher/student_roster.png',
      route: RoutePaths.artworks,
    ),
    const HomeQuickAction(
      name: '小课件',
      iconAsset: AppAssets.homeQuickQuestionBank,
      route: RoutePaths.school,
    ),
    const HomeQuickAction(
      name: '集市',
      icon: Icons.storefront_rounded,
      comingSoon: true,
    ),
  ];
}
