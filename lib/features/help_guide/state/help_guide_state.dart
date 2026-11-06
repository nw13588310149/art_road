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
  });

  final String id;
  final String categoryId;
  final String title;
  final String subtitle;
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
