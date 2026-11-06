import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/consultation_repository.dart';
import 'consultation_state.dart';

/// 资讯接口暂未联动用户省份，先按 1.0 默认值传「甘肃」。
const String _kDefaultProvince = '甘肃';

final consultationControllerProvider = StateNotifierProvider.autoDispose
    .family<ConsultationController, ConsultationState, ConsultationPageArgs>((
      ref,
      args,
    ) {
      final repo = ref.watch(consultationRepositoryProvider);
      return ConsultationController(repository: repo, args: args);
    });

class ConsultationController extends StateNotifier<ConsultationState> {
  ConsultationController({
    required ConsultationRepository repository,
    required ConsultationPageArgs args,
  }) : _repository = repository,
       _args = args,
       super(ConsultationState.initial) {
    unawaited(refresh());
  }

  static const int _pageSize = 18;

  final ConsultationRepository _repository;
  final ConsultationPageArgs _args;

  bool _loadInFlight = false;
  bool _useSchoolList = false;

  Future<void> refresh() => _loadPage(reset: true);

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore || _loadInFlight) {
      return;
    }
    await _loadPage(reset: false);
  }

  Future<void> _loadPage({required bool reset}) async {
    if (_loadInFlight) {
      return;
    }
    _loadInFlight = true;

    final page = reset ? 1 : state.currentPage + 1;
    if (reset) {
      _useSchoolList = false;
    }

    state = state.copyWith(
      loading: reset,
      loadingMore: !reset,
      clearErrorMessage: true,
    );

    try {
      if (reset && _args.schoolMode) {
        final schoolResponse = await _repository.getSchoolList(
          province: _kDefaultProvince,
          page: page,
          size: _pageSize,
        );
        if (!mounted) return;

        if (schoolResponse.isSuccess) {
          final schoolItems = _parseItems(schoolResponse.data);
          if (schoolItems.isNotEmpty) {
            _useSchoolList = true;
            _applyPageResult(
              reset: true,
              page: page,
              pageItems: schoolItems,
            );
            return;
          }
        }
      }

      final response = _useSchoolList
          ? await _repository.getSchoolList(
              province: _kDefaultProvince,
              page: page,
              size: _pageSize,
            )
          : await _repository.getList(
              province: _kDefaultProvince,
              page: page,
              size: _pageSize,
            );
      if (!mounted) return;

      if (!response.isSuccess) {
        state = state.copyWith(
          loading: false,
          loadingMore: false,
          items: reset ? const <ConsultationItem>[] : state.items,
          hasMore: reset ? true : state.hasMore,
          errorMessage: reset
              ? (response.displayMsg)
              : state.errorMessage,
        );
        return;
      }

      _applyPageResult(
        reset: reset,
        page: page,
        pageItems: _parseItems(response.data),
      );
    } finally {
      _loadInFlight = false;
    }
  }

  void _applyPageResult({
    required bool reset,
    required int page,
    required List<ConsultationItem> pageItems,
  }) {
    final baseItems = reset ? const <ConsultationItem>[] : state.items;
    final merged = _mergeUnique(baseItems, pageItems);
    final hasMore = pageItems.length >= _pageSize;

    state = state.copyWith(
      loading: false,
      loadingMore: false,
      items: merged,
      currentPage: page,
      hasMore: hasMore,
    );
  }

  List<ConsultationItem> _parseItems(dynamic raw) {
    if (raw is! List) {
      return const <ConsultationItem>[];
    }

    final items = <ConsultationItem>[];
    for (final node in raw) {
      if (node is Map) {
        items.add(ConsultationItem.fromJson(node));
      }
    }
    return items;
  }

  List<ConsultationItem> _mergeUnique(
    List<ConsultationItem> base,
    List<ConsultationItem> incoming,
  ) {
    final result = <ConsultationItem>[];
    final seen = <int>{};
    for (final item in <ConsultationItem>[...base, ...incoming]) {
      if (item.id <= 0 || !seen.add(item.id)) {
        continue;
      }
      result.add(item);
    }
    return result;
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }
}
