import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/teaching_overview_repository.dart';

final teachingOverviewProvider = StateNotifierProvider.autoDispose
    .family<TeachingOverviewController, AsyncValue<Object?>, TeachingRequest>((
      ref,
      request,
    ) {
      return TeachingOverviewController(
        ref.watch(teachingOverviewRepositoryProvider),
        request,
      );
    });

class TeachingOverviewController extends StateNotifier<AsyncValue<Object?>> {
  TeachingOverviewController(this._repository, this._request)
    : super(const AsyncLoading()) {
    unawaited(refresh());
  }

  final TeachingOverviewRepository _repository;
  final TeachingRequest _request;
  int _generation = 0;

  Future<void> refresh() async {
    final generation = ++_generation;
    state = const AsyncLoading();
    final response = await _repository.load(_request);
    if (!mounted || generation != _generation) return;
    state = response.isSuccess
        ? AsyncData(response.data)
        : AsyncError(
            response.displayMsg.isEmpty ? '加载失败，请稍后重试' : response.displayMsg,
            StackTrace.current,
          );
  }
}
