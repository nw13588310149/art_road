import 'package:flutter/foundation.dart';

import '../../../core/art/art_subject.dart';
import '../data/gallery_models.dart';

/// 范画库路由参数：`{'subject', 'keyword', 'category', 'workId'}`，均可选。
@immutable
class GalleryQuery {
  const GalleryQuery({
    this.subject = '',
    this.keyword = '',
    this.category = '',
    this.workId = '',
  });

  /// 素描 / 色彩 / 速写；空串表示全部科目。
  final String subject;
  final String keyword;

  /// 分类 key 或中文名称（如 `exam-top` / 「联考高分卷」）。
  final String category;

  /// 直接打开的作品详情。
  final String workId;

  factory GalleryQuery.fromArgs(Object? raw) {
    if (raw is! Map) {
      return const GalleryQuery();
    }
    String read(String key) {
      final value = raw[key]?.toString().trim() ?? '';
      return value == 'null' ? '' : value;
    }

    return GalleryQuery(
      subject: ArtSubject.tryParse(read('subject'))?.label ?? '',
      keyword: read('keyword'),
      category: read('category'),
      workId: read('workId'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GalleryQuery &&
          subject == other.subject &&
          keyword == other.keyword &&
          category == other.category &&
          workId == other.workId;

  @override
  int get hashCode => Object.hash(subject, keyword, category, workId);
}

@immutable
class GalleryState {
  const GalleryState({
    required this.categories,
    required this.subject,
    required this.category,
    required this.keyword,
    required this.sort,
    required this.works,
    required this.total,
    required this.currentPage,
    required this.hasMore,
    required this.loading,
    required this.loadingMore,
    required this.errorMessage,
    this.loadFailed = false,
    required this.detailStack,
    required this.details,
    required this.detailLoading,
    required this.detailErrors,
  });

  factory GalleryState.fromQuery(GalleryQuery query) {
    return GalleryState(
      categories: const <GalleryCategory>[],
      subject: query.subject,
      category: query.category.isEmpty
          ? GalleryCategory.allKey
          : query.category,
      keyword: query.keyword,
      sort: GallerySort.latest,
      works: const <GalleryWork>[],
      total: 0,
      currentPage: 0,
      hasMore: true,
      loading: true,
      loadingMore: false,
      errorMessage: '',
      detailStack: query.workId.isEmpty
          ? const <String>[]
          : <String>[query.workId],
      details: const <String, GalleryWorkDetail>{},
      detailLoading: const <String>{},
      detailErrors: const <String, String>{},
    );
  }

  final List<GalleryCategory> categories;
  final String subject;
  final String category;
  final String keyword;
  final GallerySort sort;
  final List<GalleryWork> works;
  final int total;
  final int currentPage;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String errorMessage;

  /// 列表首屏加载失败且没有可展示的作品，页面显示错误状态。
  final bool loadFailed;

  /// 详情页栈：从相关作品继续打开时逐层返回。
  final List<String> detailStack;
  final Map<String, GalleryWorkDetail> details;
  final Set<String> detailLoading;
  final Map<String, String> detailErrors;

  String? get openWorkId => detailStack.isEmpty ? null : detailStack.last;

  bool get hasFilters =>
      subject.isNotEmpty ||
      keyword.isNotEmpty ||
      category != GalleryCategory.allKey;

  /// 当前科目下展示的分类：跨科分类 + 该科目分类。
  List<GalleryCategory> get visibleCategories => subject.isEmpty
      ? categories
      : [
          for (final c in categories)
            if (c.subject == null || c.subject == subject) c,
        ];

  GalleryCategory? categoryByKey(String key) {
    for (final c in categories) {
      if (c.key == key) {
        return c;
      }
    }
    return null;
  }

  GalleryState copyWith({
    List<GalleryCategory>? categories,
    String? subject,
    String? category,
    String? keyword,
    GallerySort? sort,
    List<GalleryWork>? works,
    int? total,
    int? currentPage,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    String? errorMessage,
    bool? loadFailed,
    List<String>? detailStack,
    Map<String, GalleryWorkDetail>? details,
    Set<String>? detailLoading,
    Map<String, String>? detailErrors,
  }) {
    return GalleryState(
      categories: categories ?? this.categories,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      keyword: keyword ?? this.keyword,
      sort: sort ?? this.sort,
      works: works ?? this.works,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
      loadFailed: loadFailed ?? this.loadFailed,
      detailStack: detailStack ?? this.detailStack,
      details: details ?? this.details,
      detailLoading: detailLoading ?? this.detailLoading,
      detailErrors: detailErrors ?? this.detailErrors,
    );
  }
}
