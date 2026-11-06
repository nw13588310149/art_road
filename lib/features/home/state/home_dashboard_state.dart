import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';

class HomeBannerItem {
  const HomeBannerItem({required this.imageUrl});

  final String imageUrl;
}

class HomeQuickAction {
  const HomeQuickAction({
    required this.name,
    required this.icon,
    required this.route,
    this.arguments,
  });

  final String name;
  final String icon;
  final String route;
  final Map<String, dynamic>? arguments;
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
  final String dateText;
  final int courseCount;
  final bool isToday;
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
    this.isSmallCourse = false,
    this.cardColorHex,
  });

  final String startTime;
  final String endTime;
  final String subjectName;
  final String teacherName;
  final String teacherAvatar;
  final String description;
  final HomeCourseStatus status;

  /// 课程类型：false = 大课（type 0），true = 小课（type 1）。
  final bool isSmallCourse;
  // 接口 `color` 字段，如 "#fed7aa"，用于卡片左侧彩色条
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
    this.bannerItems = const [],
    this.quickActions = const [],
    this.weekItems = const [],
    this.newsItems = const [],
    this.courseNotices = const [],
    this.errorMessage = '',
  });

  final bool loading;
  final List<HomeBannerItem> bannerItems;
  final List<HomeQuickAction> quickActions;
  final List<HomeWeekDayItem> weekItems;
  final List<HomeNewsItem> newsItems;
  final List<HomeCourseNotice> courseNotices;
  final String errorMessage;

  HomeDashboardState copyWith({
    bool? loading,
    List<HomeBannerItem>? bannerItems,
    List<HomeQuickAction>? quickActions,
    List<HomeWeekDayItem>? weekItems,
    List<HomeNewsItem>? newsItems,
    List<HomeCourseNotice>? courseNotices,
    String? errorMessage,
  }) {
    return HomeDashboardState(
      loading: loading ?? this.loading,
      bannerItems: bannerItems ?? this.bannerItems,
      quickActions: quickActions ?? this.quickActions,
      weekItems: weekItems ?? this.weekItems,
      newsItems: newsItems ?? this.newsItems,
      courseNotices: courseNotices ?? this.courseNotices,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 首页九宫格：美术学习入口（颜色按 3×3 交错排布）。
List<HomeQuickAction> buildQuickActions(bool _) {
  return const <HomeQuickAction>[
    HomeQuickAction(
      name: '学情',
      icon: AppAssets.homeArtXueqing,
      route: RoutePaths.studyCenter,
    ),
    HomeQuickAction(
      name: '作品',
      icon: AppAssets.homeArtZuopin,
      route: RoutePaths.artworks,
    ),
    HomeQuickAction(
      name: '范画',
      icon: AppAssets.homeArtFanhua,
      route: RoutePaths.gallery,
    ),
    HomeQuickAction(
      name: '工具箱',
      icon: AppAssets.homeArtGongju,
      route: RoutePaths.artToolbox,
    ),
    HomeQuickAction(
      name: '速写练习',
      icon: AppAssets.homeArtSuxie,
      route: RoutePaths.artToolbox,
      arguments: <String, dynamic>{'tool': 'quickSketch'},
    ),
    HomeQuickAction(
      name: '题库',
      icon: AppAssets.homeBtn5,
      route: RoutePaths.camp,
    ),
    HomeQuickAction(
      name: '资讯',
      icon: AppAssets.homeBtn4,
      route: RoutePaths.consultation,
    ),
    HomeQuickAction(
      name: '校圈',
      icon: AppAssets.homeBtn9,
      route: RoutePaths.circle,
    ),
    HomeQuickAction(
      name: '群聊',
      icon: AppAssets.homeBtn7,
      route: RoutePaths.smartCampus,
    ),
  ];
}
