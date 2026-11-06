import 'package:flutter/foundation.dart';

@immutable
class HelpGuideCategory {
  const HelpGuideCategory({required this.id, required this.label});

  final String id;
  final String label;
}

@immutable
class HelpGuideItem {
  const HelpGuideItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.steps,
    this.tip = '',
    this.route,
  });

  final String id;
  final String categoryId;
  final String title;
  final String subtitle;

  /// 详情弹窗顶部的一句话说明。
  final String summary;

  /// 操作步骤，按顺序编号展示。
  final List<String> steps;

  /// 补充提示；空串时不展示。
  final String tip;

  /// 「去看看」跳转的页面路由；为 null 时只展示说明。
  final String? route;
}

@immutable
class HelpGuideState {
  const HelpGuideState({
    required this.selectedCategoryId,
    required this.categories,
    required this.items,
  });

  static const allCategoryId = 'all';

  final String selectedCategoryId;
  final List<HelpGuideCategory> categories;
  final List<HelpGuideItem> items;

  List<HelpGuideItem> get visibleItems {
    if (selectedCategoryId == allCategoryId) return items;
    return items
        .where((item) => item.categoryId == selectedCategoryId)
        .toList(growable: false);
  }

  HelpGuideState copyWith({String? selectedCategoryId}) {
    return HelpGuideState(
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      categories: categories,
      items: items,
    );
  }
}
