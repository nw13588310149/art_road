import 'package:flutter/foundation.dart';

import '../data/consultation_cover.dart';

@immutable
class ConsultationPageArgs {
  const ConsultationPageArgs({this.schoolMode = false, this.sourceName});

  final bool schoolMode;

  /// 校园课件入口透传 schoolList.name，供列表进详情时覆盖默认来源。
  final String? sourceName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsultationPageArgs &&
          schoolMode == other.schoolMode &&
          sourceName == other.sourceName;

  @override
  int get hashCode => Object.hash(schoolMode, sourceName);
}

@immutable
class ConsultationItem {
  const ConsultationItem({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.createTime,
    required this.viewCount,
    this.headline = '',
    this.tags = const <String>[],
  });

  final int id;
  final String title;
  final String coverUrl;

  /// 发布时间，原始 yyyy-MM-dd HH:mm:ss。
  final DateTime? createTime;

  final int viewCount;

  /// 栏目短标题（`shortText1`），如「联考政策解读」。
  final String headline;

  /// 标签（`shortText2`，英文逗号分隔），用于页内分类。
  final List<String> tags;

  factory ConsultationItem.fromJson(Map raw) {
    final tags = raw['shortText2']?.toString() ?? '';
    return ConsultationItem(
      id: _toInt(raw['id']) ?? 0,
      title: raw['title']?.toString() ?? '',
      coverUrl: parseConsultationCoverUrl(raw),
      createTime: _toDate(raw['createTime']),
      viewCount: _toInt(raw['viewCount']) ?? 0,
      headline: raw['shortText1']?.toString().trim() ?? '',
      tags: tags
          .split(RegExp('[,，]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// 24 小时内发布的资讯显示「最新」。
  bool isLatest([DateTime? now]) {
    final time = createTime;
    if (time == null) return false;
    final diff = (now ?? DateTime.now()).difference(time);
    return !diff.isNegative && diff < const Duration(hours: 24);
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str.replaceFirst(' ', 'T'));
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

@immutable
class ConsultationState {
  const ConsultationState({
    required this.loading,
    required this.loadingMore,
    required this.items,
    required this.currentPage,
    required this.hasMore,
    required this.errorMessage,
  });

  final bool loading;
  final bool loadingMore;
  final List<ConsultationItem> items;
  final int currentPage;
  final bool hasMore;
  final String errorMessage;

  ConsultationState copyWith({
    bool? loading,
    bool? loadingMore,
    List<ConsultationItem>? items,
    int? currentPage,
    bool? hasMore,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ConsultationState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
    );
  }

  static const ConsultationState initial = ConsultationState(
    loading: true,
    loadingMore: false,
    items: <ConsultationItem>[],
    currentPage: 0,
    hasMore: true,
    errorMessage: '',
  );
}

/// 资讯页内分类：接口没有栏目字段，按标签归类；「全部」包含所有条目。
enum ConsultationCategory {
  all('全部', <String>[]),
  policy('联考政策', <String>['联考', '政策', '评分']),
  college('院校校考', <String>['校考', '美院', '简章']),
  experience('备考经验', <String>['经验', '备考', '冲刺', '技巧', '时间管理', '时间分配', '文化课']),
  knowledge('美术常识', <String>['美术史', '画材', '工具', '新手']),
  studio('画室动态', <String>['画室', '月考', '展评', '活动', '通知', '写生']);

  const ConsultationCategory(this.label, this.keywords);

  final String label;
  final List<String> keywords;

  bool matches(ConsultationItem item) {
    if (this == ConsultationCategory.all) return true;
    return item.tags.any(keywords.contains);
  }
}

/// 列表时间：1 小时内「N 分钟前」，当天「N 小时前」，7 天内「N 天前」，
/// 更早显示日期（同年 MM-DD，跨年 YYYY-MM-DD）。
String formatRelativeTime(DateTime? time, [DateTime? reference]) {
  if (time == null) return '';
  final now = reference ?? DateTime.now();
  final diff = now.difference(time);
  String two(int v) => v.toString().padLeft(2, '0');
  if (diff.isNegative || diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  if (time.year == now.year) return '${two(time.month)}-${two(time.day)}';
  return '${time.year}-${two(time.month)}-${two(time.day)}';
}
