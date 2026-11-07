import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../ebooks/data/ebook_collection.dart';
import '../data/my_collection_repository.dart';
import 'my_collection_state.dart';

final myCollectionControllerProvider =
    StateNotifierProvider.autoDispose<
      MyCollectionController,
      MyCollectionState
    >((ref) {
      final repository = ref.watch(myCollectionRepositoryProvider);
      return MyCollectionController(repository: repository);
    });

class MyCollectionController extends StateNotifier<MyCollectionState> {
  MyCollectionController({required MyCollectionRepository repository})
    : _repository = repository,
      super(
        const MyCollectionState(loading: true, tabs: kCollectionDefaultTabs),
      ) {
    unawaited(refresh());
  }

  final MyCollectionRepository _repository;

  Future<void> refresh() async {
    try {
      state = state.copyWith(loading: true, clearError: true);
      final categoryResponse = await _repository.getCategories();
      final tabs = _parseTabs(categoryResponse.data);
      final activeType = _resolveActiveType(tabs, state.activeType);
      final itemResponse = await _repository.getItems(type: activeType);
      state = state.copyWith(
        loading: false,
        tabs: tabs,
        activeType: activeType,
        items: _parseItems(itemResponse.data, activeType),
        errorMessage: itemResponse.isSuccess
            ? null
            : _apiError(itemResponse),
        shareClasses: const <CollectionShareClass>[],
        clearShareTarget: true,
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '');
    }
  }

  Future<void> selectType(int type) async {
    if (type == state.activeType) {
      return;
    }
    try {
      state = state.copyWith(
        activeType: type,
        fetchingItems: true,
        clearError: true,
        items: const <CollectionEntry>[],
        shareClasses: const <CollectionShareClass>[],
        clearShareTarget: true,
      );
      final response = await _repository.getItems(type: type);
      state = state.copyWith(
        fetchingItems: false,
        items: _parseItems(response.data, type),
        errorMessage: response.isSuccess
            ? null
            : _apiError(response),
      );
    } catch (_) {
      state = state.copyWith(fetchingItems: false, errorMessage: '');
    }
  }

  Future<String?> removeFavorite(CollectionEntry item) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.removeFavorite(
      targetId: item.targetId,
      type: item.type,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return _apiError(response);
    }
    state = state.copyWith(
      items: state.items.where((entry) => entry.id != item.id).toList(),
    );
    return null;
  }

  Future<String?> openShare(CollectionEntry item) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.getClassList();
    state = state.copyWith(busy: false);
    if (!response.isSuccess || response.data is! List) {
      return _apiError(response);
    }
    final classes = <CollectionShareClass>[];
    for (final raw in response.data as List) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = _toIdString(raw['id']);
      final name = (raw['groupName'] ?? raw['name'] ?? raw['className'] ?? '')
          .toString()
          .trim();
      final avatarUrl =
          (raw['logo'] ?? raw['groupLogo'] ?? raw['avatarUrl'] ?? '')
              .toString()
              .trim();
      if (id.isEmpty || name.isEmpty) {
        continue;
      }
      classes.add(
        CollectionShareClass(id: id, name: name, avatarUrl: avatarUrl),
      );
    }
    state = state.copyWith(shareTarget: item, shareClasses: classes);
    return null;
  }

  void toggleShareClass(String id) {
    state = state.copyWith(
      shareClasses: state.shareClasses.map((item) {
        if (item.id != id) {
          return item;
        }
        return item.copyWith(selected: !item.selected);
      }).toList(),
    );
  }

  void closeShare() {
    state = state.copyWith(
      shareClasses: const <CollectionShareClass>[],
      clearShareTarget: true,
    );
  }

  Future<String?> sendShare() async {
    final target = state.shareTarget;
    if (target == null) {
      return '请先选择要分享的收藏';
    }
    final selected = state.shareClasses.where((item) => item.selected).toList();
    if (selected.isEmpty) {
      return '请先选择要分享的班级';
    }

    state = state.copyWith(busy: true, clearError: true);
    for (final item in selected) {
      final response = await _repository.shareToClass(
        classId: item.id,
        type: target.type,
        payload: target.rawPayload,
      );
      if (!response.isSuccess) {
        state = state.copyWith(busy: false);
        return _apiError(response);
      }
    }
    state = state.copyWith(
      busy: false,
      shareClasses: const <CollectionShareClass>[],
      clearShareTarget: true,
    );
    return null;
  }

  /// 服务端返回的分类列表只是用来确认每个 Tab 是否启用，
  /// 顺序统一以 [kCollectionDefaultTabs] 为准。
  List<CollectionTabItem> _parseTabs(dynamic data) {
    final allowed = <int>{};
    if (data is List) {
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final label = item['name']?.toString().trim() ?? '';
        final type = kCollectionTypeByLabel[label];
        if (type != null) {
          allowed.add(type);
        }
      }
    }
    if (allowed.isEmpty) {
      return kCollectionDefaultTabs;
    }
    return kCollectionDefaultTabs
        .where((tab) => allowed.contains(tab.type))
        .toList(growable: false);
  }

  List<CollectionEntry> _parseItems(dynamic data, int activeType) {
    if (data is! List) {
      return const <CollectionEntry>[];
    }
    final result = <CollectionEntry>[];
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final rawType = _toInt(raw['type']);
      final type = rawType == 0 ? activeType : rawType;
      if (type == CollectionType.ebook) {
        final ebook = _ebookEntry(raw, type);
        if (ebook != null) {
          result.add(ebook);
        }
        continue;
      }
      final target = _resolveTarget(raw);
      if (target == null) {
        continue;
      }
      final title = (target['title'] ?? target['name'] ?? '').toString().trim();
      if (title.isEmpty) {
        continue;
      }
      final targetId = _toIdString(raw['targetId']);
      result.add(
        CollectionEntry(
          id: _toIdString(raw['id']),
          targetId: targetId.isNotEmpty ? targetId : _toIdString(target['id']),
          type: type,
          title: title,
          subtitle: _resolveSubtitle(target, type),
          coverUrl: _resolveCover(target),
          authorName: _resolveAuthor(target),
          avatarUrl: _resolveAvatar(target),
          metricText: _resolveMetric(target),
          durationText: _resolveDuration(target),
          rawPayload: Map<String, dynamic>.from(target),
        ),
      );
    }
    return result;
  }

  /// 书刊收藏的卡片字段由书刊模块定义（[EbookCollection.itemOf]）。
  CollectionEntry? _ebookEntry(Map<String, dynamic> raw, int type) {
    final book = EbookCollection.itemOf(<String, dynamic>{...raw, 'type': type});
    if (book == null || book.title.isEmpty) {
      return null;
    }
    return CollectionEntry(
      id: _toIdString(raw['id']),
      targetId: book.bookId,
      type: type,
      title: book.title,
      subtitle: book.subtitle,
      coverUrl: book.coverUrl,
      authorName: '',
      avatarUrl: '',
      metricText: '',
      durationText: '',
      rawPayload: <String, dynamic>{
        'id': book.bookId,
        'title': book.title,
        'subtitle': book.subtitle,
        'coverImg': book.coverUrl,
        'pageCount': book.pageCount,
      },
    );
  }

  Map<String, dynamic>? _resolveTarget(Map<String, dynamic> raw) {
    final target = raw['target'];
    if (target is Map<String, dynamic>) {
      return target;
    }
    if (target is Map) {
      return Map<String, dynamic>.from(target);
    }
    // 部分接口直接把目标字段平铺在收藏记录上（兼容历史返回）。
    if (raw.containsKey('title') || raw.containsKey('name')) {
      return raw;
    }
    return null;
  }

  int _resolveActiveType(List<CollectionTabItem> tabs, int current) {
    if (tabs.any((item) => item.type == current)) {
      return current;
    }
    return tabs.isNotEmpty ? tabs.first.type : CollectionType.all;
  }

  /// 副标题：优先使用收藏快照里的 `subtitle`（如「素描 · 李静」「联考政策 ·
  /// 2026-11-05」），缺失时按类型回退到分类 / 作者 / 发布时间。
  String _resolveSubtitle(Map<String, dynamic> target, int type) {
    String pickFirstNonEmpty(List<String> keys) {
      for (final key in keys) {
        final value = target[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    final subtitle = pickFirstNonEmpty(<String>['subtitle', 'description']);
    if (subtitle.isNotEmpty) {
      return subtitle;
    }
    return switch (type) {
      CollectionType.video => pickFirstNonEmpty(<String>[
        'category',
        'teacherName',
      ]),
      CollectionType.news => pickFirstNonEmpty(<String>[
        'shortText1',
        'updateTime',
      ]),
      CollectionType.artwork => pickFirstNonEmpty(<String>[
        'subject',
        'author',
      ]),
      _ => '',
    };
  }

  String _resolveCover(Map<String, dynamic> target) {
    for (final key in <String>[
      'coverImg',
      'cover',
      'imgUrl',
      'thumb',
      'shortText3',
      'imageUrl',
    ]) {
      final value = target[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'string') {
        return value;
      }
    }
    return '';
  }

  String _resolveAuthor(Map<String, dynamic> target) {
    for (final key in <String>[
      'teacherName',
      'author',
      'nickname',
      'realname',
      'userName',
    ]) {
      final value = target[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '美术之路';
  }

  String _resolveAvatar(Map<String, dynamic> target) {
    for (final key in <String>[
      'teacherAvatar',
      'avatarUrl',
      'headImg',
      'avatar',
      'userAvatar',
    ]) {
      final value = target[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'string') {
        return value;
      }
    }
    return '';
  }

  String _resolveMetric(Map<String, dynamic> target) {
    for (final key in <String>['playCount', 'viewCount', 'playNum']) {
      final value = _toInt(target[key]);
      if (value > 0) {
        return '$value';
      }
    }
    return '0';
  }

  String _resolveDuration(Map<String, dynamic> target) {
    for (final key in <String>['duration', 'durationText', 'totalTime']) {
      final value = target[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '00:00';
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _toIdString(dynamic value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value is num) return value.toInt().toString();
    final text = value.toString().trim();
    return text == 'null' ? '' : text;
  }

  String _apiError(ApiResponse response) => response.displayMsg;
}
