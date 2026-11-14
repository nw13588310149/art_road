import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/creative_models.dart';
import '../data/creative_repository.dart';

class CreativeState<T> {
  const CreativeState({
    this.items = const [],
    this.loading = true,
    this.busy = false,
    this.error = '',
    this.keyword = '',
    this.subject = '',
    this.view = 'all',
  });
  final List<T> items;
  final bool loading, busy;
  final String error, keyword, subject, view;
  CreativeState<T> copyWith({
    List<T>? items,
    bool? loading,
    bool? busy,
    String? error,
    String? keyword,
    String? subject,
    String? view,
  }) => CreativeState<T>(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    error: error ?? this.error,
    keyword: keyword ?? this.keyword,
    subject: subject ?? this.subject,
    view: view ?? this.view,
  );
}

final learningTopicsProvider =
    StateNotifierProvider.autoDispose<
      LearningTopicsController,
      CreativeState<LearningTopic>
    >(
      (ref) =>
          LearningTopicsController(ref.watch(creativeRepositoryProvider))
            ..load(),
    );
final marketplaceProvider =
    StateNotifierProvider.autoDispose<
      MarketplaceController,
      CreativeState<MarketListing>
    >(
      (ref) =>
          MarketplaceController(ref.watch(creativeRepositoryProvider))..load(),
    );
final readingResourcesProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(creativeRepositoryProvider).resources(),
);
final marketOrdersProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(creativeRepositoryProvider).orders(),
);
final marketMyArtworksProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(creativeRepositoryProvider).myArtworks(),
);

abstract class CreativeController<T> extends StateNotifier<CreativeState<T>> {
  CreativeController(this.repository) : super(CreativeState<T>());
  final CreativeRepository repository;
  Future<List<T>> fetch();
  Future<void> load() async {
    if (mounted) state = state.copyWith(loading: true, error: '');
    try {
      final items = await fetch();
      if (mounted) state = state.copyWith(items: items, loading: false);
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          error: '$error'.replaceFirst('Bad state: ', ''),
          loading: false,
        );
      }
    }
  }

  void filter({String? keyword, String? subject, String? view}) =>
      state = state.copyWith(keyword: keyword, subject: subject, view: view);
  Future<String?> action(Future<void> Function() task) async {
    if (state.busy) return '正在保存，请稍候';
    state = state.copyWith(busy: true);
    try {
      await task();
      await load();
      return null;
    } catch (error) {
      return '$error'.replaceFirst('Bad state: ', '');
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }
}

class LearningTopicsController extends CreativeController<LearningTopic> {
  LearningTopicsController(super.repository);
  @override
  Future<List<LearningTopic>> fetch() => repository.topics();
  List<LearningTopic> get visible => state.items
      .where(
        (topic) =>
            (state.subject.isEmpty || topic.subject == state.subject) &&
            (state.view != 'saved' || topic.favorite) &&
            (state.view != 'mine' || topic.mine) &&
            '${topic.title} ${topic.intro} ${topic.tags.join(' ')}'.contains(
              state.keyword.trim(),
            ),
      )
      .toList();
  Future<String?> favorite(String id) =>
      action(() => repository.favorite('micro-lessons', id));
  Future<String?> publish(CreativeJson body) => action(() async {
    await repository.publish('micro-lessons', body);
    filter(keyword: '', subject: '', view: 'mine');
  });
}

class MarketplaceController extends CreativeController<MarketListing> {
  MarketplaceController(super.repository);
  @override
  Future<List<MarketListing>> fetch() => repository.listings();
  List<MarketListing> get visible => state.items
      .where(
        (work) =>
            (state.subject.isEmpty || work.subject == state.subject) &&
            (state.view != 'saved' || work.favorite) &&
            (state.view != 'mine' || work.mine) &&
            (state.view != 'sale' || work.forSale) &&
            '${work.title} ${work.author} ${work.description}'.contains(
              state.keyword.trim(),
            ),
      )
      .toList();
  Future<String?> favorite(String id) =>
      action(() => repository.favorite('market/listings', id));
  Future<String?> publish(CreativeJson body) => action(() async {
    await repository.publish('market/listings', body);
    filter(keyword: '', subject: '', view: 'mine');
  });
  Future<String?> buy(String id) => action(() async {
    await repository.buy(id);
  });
}

final creativeUploadProvider =
    StateNotifierProvider.autoDispose<CreativeUploadController, bool>(
      (ref) => CreativeUploadController(ref.watch(creativeRepositoryProvider)),
    );

class CreativeUploadController extends StateNotifier<bool> {
  CreativeUploadController(this.repository) : super(false);
  final CreativeRepository repository;
  Future<ReadingResource> upload({
    required String name,
    Uint8List? bytes,
    String? path,
  }) async {
    state = true;
    try {
      return await repository.upload(name: name, bytes: bytes, path: path);
    } finally {
      if (mounted) state = false;
    }
  }

  Future<ReadingResource> imageBook(List<String> ids) =>
      repository.imageBook(ids);
}

class CreativeReadingState {
  const CreativeReadingState({
    this.page = 0,
    this.loading = true,
    this.error = '',
  });
  final int page;
  final bool loading;
  final String error;
}

typedef CreativeReadingKey = ({String id, int pageCount});
final creativeReadingProvider = StateNotifierProvider.autoDispose
    .family<
      CreativeReadingController,
      CreativeReadingState,
      CreativeReadingKey
    >(
      (ref, key) =>
          CreativeReadingController(ref.watch(creativeRepositoryProvider), key)
            ..load(),
    );

class CreativeReadingController extends StateNotifier<CreativeReadingState> {
  CreativeReadingController(this.repository, this.key)
    : super(const CreativeReadingState());
  final CreativeRepository repository;
  final CreativeReadingKey key;
  Future<void> _saves = Future.value();

  Future<void> load() async {
    try {
      final page = await repository.readingProgress(key.id);
      if (mounted) {
        state = CreativeReadingState(
          page: page.clamp(0, key.pageCount - 1),
          loading: false,
        );
      }
    } catch (_) {
      if (mounted) {
        state = const CreativeReadingState(
          loading: false,
          error: '未能恢复阅读进度，可以继续阅读',
        );
      }
    }
  }

  Future<void> goTo(int page) {
    if (state.loading || page < 0 || page >= key.pageCount) {
      return Future.value();
    }
    state = CreativeReadingState(page: page, loading: false);
    // 连续翻页串行保存，避免旧请求晚返回而覆盖新页码。
    return _saves = _saves.then((_) async {
      try {
        await repository.saveReadingProgress(key.id, page);
      } catch (_) {
        if (mounted) {
          state = CreativeReadingState(
            page: state.page,
            loading: false,
            error: '阅读进度未保存，请检查网络后重试',
          );
        }
      }
    });
  }

  Future<void> flush() => _saves;
}
