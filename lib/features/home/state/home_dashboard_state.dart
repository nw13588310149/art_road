import 'package:flutter/material.dart' show IconData;

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../smart_campus/state/campus_entry.dart';

class HomeBannerItem {
  const HomeBannerItem({required this.imageUrl, this.title = ''});

  final String imageUrl;
  final String title;
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
  final CampusEntry? campus;

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

  /// 本周七天的课程数。学生、任课老师、班主任是本人课表，管理员与校长是全校
  /// 课表；宿管没有课表，为空，首页不显示周条。
  final List<HomeWeekDayItem> weekItems;
  final List<HomeNewsItem> newsItems;
  final List<HomeCourseNotice> courseNotices;
  final String errorMessage;

  /// nextSchoolCourse 可以返回下一次有课日期，不把它当作今天的排课。
  bool get showingUpcomingCourses {
    final today = weekItems.where((day) => day.isToday).firstOrNull;
    final courseDate = DateTime.tryParse(courseNotices.firstOrNull?.date ?? '');
    final todayDate = DateTime.tryParse(today?.dateText ?? '');
    return courseDate != null &&
        todayDate != null &&
        courseDate.isAfter(todayDate);
  }

  String get courseHeading {
    if (!showingUpcomingCourses) return '课程';
    final date = DateTime.parse(courseNotices.first.date);
    return '下一次课程 · ${date.month}月${date.day}日';
  }

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

/// 首页九宫格：所有身份同一版式、同一顺序，从左到右、从上到下为
/// 学情、工具、作业、题库、作品墙、集市、群聊、资讯、校圈。
///
/// 每行每列都是粉、紫、青三色各一个。只有宿管不看成绩、不点评作品，
/// 前两个位置换成「校长信箱」和「查寝」，其余七个不变。
/// 「作业」打开作品档案（老师为作品点评）；各身份的工作入口在「今日」页。
List<HomeQuickAction> buildQuickActions({String role = ''}) {
  final dorm = role.trim() == 'dormManager';
  return <HomeQuickAction>[
    if (dorm)
      const HomeQuickAction(
        name: '校长信箱',
        iconAsset: AppAssets.homeQuickMailbox,
        campus: CampusEntry.principalMailbox,
      )
    else
      const HomeQuickAction(
        name: '学情',
        iconAsset: AppAssets.homeQuickStudy,
        route: RoutePaths.studyCenter,
      ),
    const HomeQuickAction(
      name: '工具',
      iconAsset: AppAssets.homeQuickTools,
      route: RoutePaths.artToolbox,
      arguments: <String, dynamic>{'returnToSource': true},
    ),
    if (dorm)
      const HomeQuickAction(
        name: '查寝',
        iconAsset: AppAssets.homeQuickDorm,
        campus: CampusEntry.dormCheckByRoom,
      )
    else
      const HomeQuickAction(
        name: '作业',
        iconAsset: AppAssets.homeQuickHomework,
        route: RoutePaths.artworks,
      ),
    const HomeQuickAction(
      name: '题库',
      iconAsset: AppAssets.homeQuickQuestionBank,
      route: RoutePaths.camp,
    ),
    const HomeQuickAction(
      name: '作品墙',
      iconAsset: AppAssets.homeQuickWall,
      route: RoutePaths.excellentArtworks,
    ),
    const HomeQuickAction(
      name: '集市',
      iconAsset: AppAssets.homeQuickMarket,
      route: RoutePaths.marketplace,
    ),
    const HomeQuickAction(
      name: '群聊',
      iconAsset: AppAssets.homeQuickGroupChat,
      campus: CampusEntry.groupChat,
    ),
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
  ];
}
