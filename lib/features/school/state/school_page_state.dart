import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';

class SchoolQuickAction {
  const SchoolQuickAction({
    required this.name,
    required this.iconAsset,
    required this.route,
    this.firstMenu,
    this.comingSoon = false,
  });

  final String name;
  final String iconAsset;
  final String route;

  /// 1.0 中通过 storage 写入的 firstMenu 初值；2.0 改为路由参数透传给二级页面。
  final int? firstMenu;

  /// 「即将上线」的入口：点击不跳转，只给出提示。
  final bool comingSoon;
}

class SchoolLearningItem {
  const SchoolLearningItem({
    required this.text,
    required this.completeCount,
    required this.allCount,
    required this.progress,
    required this.color,
    required this.background,
  });

  final String text;
  final int completeCount;
  final int allCount;

  /// 0–100 进度百分比。
  final int progress;
  final Color color;
  final Color background;

  int get remainingCount =>
      (allCount - completeCount).clamp(0, allCount > 0 ? allCount : 0);

  bool get completed =>
      progress >= 100 || (allCount > 0 && completeCount >= allCount);
}

class SchoolBannerItem {
  const SchoolBannerItem({required this.imageUrl});

  final String imageUrl;
}

class SchoolNewsItem {
  const SchoolNewsItem({
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

/// 画室课程视频（校园课件首屏的课件目录）。
class SchoolCourseVideo {
  const SchoolCourseVideo({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.duration,
    required this.teacherName,
    required this.category,
  });

  final String id;
  final String title;
  final String coverUrl;
  final String duration;
  final String teacherName;
  final String category;
}

class SchoolPageState {
  const SchoolPageState({
    this.loading = true,
    this.schoolId = '0',
    this.schoolName = '',
    this.quickActions = const [],
    this.bannerItems = const [],
    this.learningItems = const [],
    this.newsItems = const [],
    this.courseVideos = const [],
    this.errorMessage = '',
  });

  final bool loading;
  final String schoolId;
  final String schoolName;
  final List<SchoolQuickAction> quickActions;
  final List<SchoolBannerItem> bannerItems;
  final List<SchoolLearningItem> learningItems;
  final List<SchoolNewsItem> newsItems;
  final List<SchoolCourseVideo> courseVideos;
  final String errorMessage;

  SchoolPageState copyWith({
    bool? loading,
    String? schoolId,
    String? schoolName,
    List<SchoolQuickAction>? quickActions,
    List<SchoolBannerItem>? bannerItems,
    List<SchoolLearningItem>? learningItems,
    List<SchoolNewsItem>? newsItems,
    List<SchoolCourseVideo>? courseVideos,
    String? errorMessage,
  }) {
    return SchoolPageState(
      loading: loading ?? this.loading,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      quickActions: quickActions ?? this.quickActions,
      bannerItems: bannerItems ?? this.bannerItems,
      learningItems: learningItems ?? this.learningItems,
      newsItems: newsItems ?? this.newsItems,
      courseVideos: courseVideos ?? this.courseVideos,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 校园课件页的入口条（校园专属资料，接口携带真实 schoolId）；
/// 学情、作品、范画等与首页重复的入口不再放在这里。
List<SchoolQuickAction> buildSchoolQuickActions() {
  return const <SchoolQuickAction>[
    SchoolQuickAction(
      name: '课程视频',
      iconAsset: AppAssets.schoolQuickVideo,
      route: RoutePaths.schoolVideo,
    ),
    SchoolQuickAction(
      name: '题库',
      iconAsset: AppAssets.homeQuickQuestionBank,
      route: RoutePaths.schoolCamp,
    ),
    SchoolQuickAction(
      name: '画室官网',
      iconAsset: AppAssets.homeQuickSchoolCircle,
      route: RoutePaths.schoolWebsite,
    ),
    SchoolQuickAction(
      name: '校园资讯',
      iconAsset: AppAssets.homeQuickNews,
      route: RoutePaths.consultation,
    ),
  ];
}
