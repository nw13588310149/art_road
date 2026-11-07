import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ebook_models.dart';
import '../data/ebook_repository.dart';
import 'ebook_spread.dart';

@immutable
class EbookReaderArgs {
  const EbookReaderArgs({required this.bookId, this.initialPage = 0});

  final String bookId;

  /// 打开时跳到的页码；0 表示从上次的进度继续。
  final int initialPage;

  @override
  bool operator ==(Object other) =>
      other is EbookReaderArgs &&
      other.bookId == bookId &&
      other.initialPage == initialPage;

  @override
  int get hashCode => Object.hash(bookId, initialPage);
}

@immutable
class EbookReaderState {
  const EbookReaderState({
    required this.bookId,
    this.loading = true,
    this.errorMessage = '',
    this.title = '',
    this.pages = const <EbookPage>[],
    this.toc = const <EbookTocEntry>[],
    this.page = 1,
    this.bookmarks = const <int>{},
  });

  final String bookId;
  final bool loading;
  final String errorMessage;
  final String title;
  final List<EbookPage> pages;
  final List<EbookTocEntry> toc;

  /// 当前这一屏的起始页（1 起）。
  final int page;
  final Set<int> bookmarks;

  int get pageCount => pages.length;

  bool isBookmarked(int page) => bookmarks.contains(page);

  EbookPage? pageAt(int page) =>
      page >= 1 && page <= pages.length ? pages[page - 1] : null;

  EbookReaderState copyWith({
    bool? loading,
    String? errorMessage,
    String? title,
    List<EbookPage>? pages,
    List<EbookTocEntry>? toc,
    int? page,
    Set<int>? bookmarks,
  }) {
    return EbookReaderState(
      bookId: bookId,
      loading: loading ?? this.loading,
      errorMessage: errorMessage ?? this.errorMessage,
      title: title ?? this.title,
      pages: pages ?? this.pages,
      toc: toc ?? this.toc,
      page: page ?? this.page,
      bookmarks: bookmarks ?? this.bookmarks,
    );
  }
}

final ebookReaderControllerProvider = StateNotifierProvider.autoDispose
    .family<EbookReaderController, EbookReaderState, EbookReaderArgs>((
      ref,
      args,
    ) {
      final repository = ref.watch(ebookRepositoryProvider);
      return EbookReaderController(repository: repository, args: args);
    });

/// 阅读器：加载内页、目录、进度与书签；翻页后延迟保存进度（这一屏的最后一页）。
class EbookReaderController extends StateNotifier<EbookReaderState> {
  EbookReaderController({
    required EbookRepository repository,
    required EbookReaderArgs args,
  }) : _repository = repository,
       _args = args,
       super(EbookReaderState(bookId: args.bookId)) {
    unawaited(load());
  }

  static const saveDelay = Duration(milliseconds: 400);

  final EbookRepository _repository;
  final EbookReaderArgs _args;
  Timer? _saveTimer;

  /// 已保存到后端的页码与时间。
  int _savedPage = 0;
  String _savedAt = '';

  /// 等待保存的页码。
  int _pendingPage = 0;

  Future<void> load() async {
    state = state.copyWith(loading: true, errorMessage: '');
    final id = _args.bookId;
    final responses = await Future.wait([
      _repository.getDetail(id),
      _repository.getPages(id),
      _repository.getProgress(id),
    ]);
    if (!mounted) {
      return;
    }
    final pagesResponse = responses[1];
    final pages = pagesResponse.isSuccess
        ? EbookPage.listFrom(pagesResponse.data)
        : const <EbookPage>[];
    if (pages.isEmpty) {
      state = state.copyWith(
        loading: false,
        errorMessage: !pagesResponse.isSuccess && pagesResponse.displayMsg.isNotEmpty
            ? pagesResponse.displayMsg
            : '书刊内容加载失败，请稍后重试',
      );
      return;
    }
    final detailData = responses[0].data;
    final detail = responses[0].isSuccess && detailData is Map
        ? EbookDetail.fromJson(detailData)
        : null;
    final reading = responses[2].isSuccess
        ? EbookReading.fromJson(responses[2].data)
        : const EbookReading(progress: null, bookmarks: <int>[]);
    _savedPage = reading.progress?.page ?? 0;
    _savedAt = reading.progress?.updatedAt ?? '';
    final requested = _args.initialPage > 0 ? _args.initialPage : _savedPage;
    final start = requested.clamp(1, pages.length);
    state = state.copyWith(
      loading: false,
      title: detail?.book.title ?? state.title,
      pages: pages,
      toc: detail?.toc ?? const <EbookTocEntry>[],
      page: start,
      bookmarks: reading.bookmarks.toSet(),
    );
    // 打开即记一次进度，书刊马上出现在「我的书架」和「继续阅读」里。
    if (start != _savedPage) {
      _pendingPage = start;
      unawaited(_save());
    }
  }

  /// 翻到 [page] 所在的一屏；进度记为这一屏的最后一页。
  void goTo(int page, EbookSpread spread) {
    if (state.pageCount == 0) {
      return;
    }
    final start = spread.startOf(page);
    if (start != state.page) {
      state = state.copyWith(page: start);
    }
    final last = spread.lastVisible(start);
    if (last != _savedPage || _pendingPage != last) {
      _pendingPage = last;
      _scheduleSave();
    }
  }

  void next(EbookSpread spread) {
    final target = spread.next(state.page);
    if (target != null) {
      goTo(target, spread);
    }
  }

  void previous(EbookSpread spread) {
    final target = spread.previous(state.page);
    if (target != null) {
      goTo(target, spread);
    }
  }

  /// 书签开关（先乐观更新，失败回滚）；返回是否成功。
  Future<bool> toggleBookmark(int page) async {
    final target = !state.isBookmarked(page);
    _applyBookmark(page, target);
    final response = await _repository.setBookmark(
      _args.bookId,
      page,
      bookmarked: target,
    );
    if (!mounted) {
      return false;
    }
    if (!response.isSuccess) {
      _applyBookmark(page, !target);
      return false;
    }
    final data = response.data;
    if (data is Map && data['bookmarks'] is List) {
      state = state.copyWith(
        bookmarks: EbookReading.fromJson(data).bookmarks.toSet(),
      );
    }
    return true;
  }

  void _applyBookmark(int page, bool bookmarked) {
    final bookmarks = {...state.bookmarks};
    bookmarked ? bookmarks.add(page) : bookmarks.remove(page);
    state = state.copyWith(bookmarks: bookmarks);
  }

  /// 立即保存未落盘的进度（关闭阅读器前调用），返回最新进度。
  Future<EbookProgress?> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _save();
    return _savedPage > 0
        ? EbookProgress(page: _savedPage, updatedAt: _savedAt)
        : null;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => unawaited(_save()));
  }

  Future<void> _save() async {
    final page = _pendingPage;
    if (page <= 0 || page == _savedPage) {
      return;
    }
    final previous = _savedPage;
    _savedPage = page;
    final response = await _repository.saveProgress(_args.bookId, page);
    if (!response.isSuccess) {
      if (_savedPage == page) {
        _savedPage = previous;
      }
      return;
    }
    _savedAt = EbookProgress.fromJson(response.data)?.updatedAt ?? _savedAt;
  }

  @override
  void dispose() {
    final pending = _saveTimer?.isActive ?? false;
    _saveTimer?.cancel();
    if (pending && _pendingPage > 0 && _pendingPage != _savedPage) {
      unawaited(_repository.saveProgress(_args.bookId, _pendingPage));
    }
    super.dispose();
  }
}
