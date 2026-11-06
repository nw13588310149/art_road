import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';

class SchoolQuickAction {
  const SchoolQuickAction({
    required this.name,
    required this.icon,
    required this.route,
    this.firstMenu,
    this.comingSoon = false,
  });

  final String name;
  final String icon;
  final String route;

  /// 1.0 中通过 storage 写入的 firstMenu 初值；2.0 改为路由参数透传给二级页面。
  final int? firstMenu;

  /// 商城/模考 等"即将上线"按钮：点击不跳转，弹出占位提示。
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

class SchoolPageState {
  const SchoolPageState({
    this.loading = true,
    this.schoolId = '0',
    this.schoolName = '',
    this.quickActions = const [],
    this.bannerItems = const [],
    this.learningItems = const [],
    this.newsItems = const [],
    this.errorMessage = '',
  });

  final bool loading;
  final String schoolId;
  final String schoolName;
  final List<SchoolQuickAction> quickActions;
  final List<SchoolBannerItem> bannerItems;
  final List<SchoolLearningItem> learningItems;
  final List<SchoolNewsItem> newsItems;
  final String errorMessage;

  SchoolPageState copyWith({
    bool? loading,
    String? schoolId,
    String? schoolName,
    List<SchoolQuickAction>? quickActions,
    List<SchoolBannerItem>? bannerItems,
    List<SchoolLearningItem>? learningItems,
    List<SchoolNewsItem>? newsItems,
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
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 校园课件页六宫格按钮（校园专属资料，接口携带真实 schoolId）。
List<SchoolQuickAction> buildSchoolQuickActions() {
  return const <SchoolQuickAction>[
    SchoolQuickAction(
      name: '学情',
      icon: AppAssets.homeArtXueqing,
      route: RoutePaths.studyCenter,
    ),
    SchoolQuickAction(
      name: '作品',
      icon: AppAssets.homeArtZuopin,
      route: RoutePaths.artworks,
    ),
    SchoolQuickAction(
      name: '范画',
      icon: AppAssets.homeArtFanhua,
      route: RoutePaths.gallery,
    ),
    SchoolQuickAction(
      name: '刷题',
      icon: AppAssets.homeBtn5,
      route: RoutePaths.schoolCamp,
    ),
    SchoolQuickAction(
      name: '微校',
      icon: AppAssets.homeBtn8,
      route: RoutePaths.schoolWebsite,
    ),
    SchoolQuickAction(
      name: '视频',
      icon: AppAssets.schoolV2QuickVideo,
      route: RoutePaths.schoolVideo,
    ),
  ];
}
