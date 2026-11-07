class CollectionTabItem {
  const CollectionTabItem({required this.type, required this.label});

  final int type;
  final String label;
}

/// 收藏类型（与 `favoriteList` / `favoriteSave` 的 type 一致，0 表示全部）。
///
/// 新增类型：在这里加常量并在 [kCollectionDefaultTabs] 追加一项；页签、类型标签、
/// 空状态文案都读这张表，打开方式登记在 `my_collection_page.dart` 的 `_openers`。
abstract final class CollectionType {
  static const all = 0;
  static const video = 6;
  static const news = 9;
  static const artwork = 11;

  static String labelOf(int type) {
    for (final tab in kCollectionDefaultTabs) {
      if (tab.type == type && type != all) {
        return tab.label;
      }
    }
    return '收藏';
  }
}

class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.targetId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.authorName,
    required this.avatarUrl,
    required this.metricText,
    required this.durationText,
    required this.rawPayload,
  });

  /// 收藏记录 id 与目标 id 都按字符串承载（雪花 id / 范画 `g-1` 等非数字 id）。
  final String id;
  final String targetId;
  final int type;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String authorName;
  final String avatarUrl;
  final String metricText;
  final String durationText;
  final Map<String, dynamic> rawPayload;

  bool get isVideo => type == CollectionType.video;
  bool get isNews => type == CollectionType.news;
  bool get isArtwork => type == CollectionType.artwork;
}

class CollectionShareClass {
  const CollectionShareClass({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.selected = false,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final bool selected;

  CollectionShareClass copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? selected,
  }) {
    return CollectionShareClass(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      selected: selected ?? this.selected,
    );
  }
}

class MyCollectionState {
  const MyCollectionState({
    this.loading = false,
    this.fetchingItems = false,
    this.busy = false,
    this.errorMessage,
    this.tabs = const <CollectionTabItem>[],
    this.activeType = CollectionType.all,
    this.items = const <CollectionEntry>[],
    this.shareClasses = const <CollectionShareClass>[],
    this.shareTarget,
  });

  final bool loading;
  /// Tab 切换拉取列表时为 true；不使用 [loading]，避免触发全页白色蒙层。
  final bool fetchingItems;
  final bool busy;
  final String? errorMessage;
  final List<CollectionTabItem> tabs;
  final int activeType;
  final List<CollectionEntry> items;
  final List<CollectionShareClass> shareClasses;
  final CollectionEntry? shareTarget;

  MyCollectionState copyWith({
    bool? loading,
    bool? fetchingItems,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    List<CollectionTabItem>? tabs,
    int? activeType,
    List<CollectionEntry>? items,
    List<CollectionShareClass>? shareClasses,
    CollectionEntry? shareTarget,
    bool clearShareTarget = false,
  }) {
    return MyCollectionState(
      loading: loading ?? this.loading,
      fetchingItems: fetchingItems ?? this.fetchingItems,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      tabs: tabs ?? this.tabs,
      activeType: activeType ?? this.activeType,
      items: items ?? this.items,
      shareClasses: shareClasses ?? this.shareClasses,
      shareTarget: clearShareTarget ? null : (shareTarget ?? this.shareTarget),
    );
  }
}

/// 我的收藏 Tab 顺序：全部 → 范画 → 视频 → 资讯。
const List<CollectionTabItem> kCollectionDefaultTabs = <CollectionTabItem>[
  CollectionTabItem(type: CollectionType.all, label: '全部'),
  CollectionTabItem(type: CollectionType.artwork, label: '范画'),
  CollectionTabItem(type: CollectionType.video, label: '视频'),
  CollectionTabItem(type: CollectionType.news, label: '资讯'),
];

/// 接口分类名 → 类型，由 [kCollectionDefaultTabs] 生成。
final Map<String, int> kCollectionTypeByLabel = <String, int>{
  for (final tab in kCollectionDefaultTabs) tab.label: tab.type,
};
