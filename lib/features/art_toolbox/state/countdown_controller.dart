import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/countdown_repository.dart';

final countdownRepositoryProvider = Provider<CountdownRepository>(
  (ref) => CountdownRepository(),
);

final countdownControllerProvider =
    StateNotifierProvider.autoDispose<CountdownController, CountdownState>(
      (ref) => CountdownController(ref.watch(countdownRepositoryProvider)),
    );

class CountdownState {
  const CountdownState({this.loading = true, this.items = const []});

  final bool loading;
  final List<ExamCountdown> items;

  /// 按日期排序：未到期的在前（最近的排第一），已结束的在后。
  List<ExamCountdown> sorted(DateTime now) {
    final upcoming = items.where((c) => c.daysLeftFrom(now) >= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = items.where((c) => c.daysLeftFrom(now) < 0).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return [...upcoming, ...past];
  }

  ExamCountdown? nextUpcoming(DateTime now) {
    final list = sorted(now);
    return list.isNotEmpty && list.first.daysLeftFrom(now) >= 0
        ? list.first
        : null;
  }
}

class CountdownController extends StateNotifier<CountdownState> {
  CountdownController(this._repository) : super(const CountdownState()) {
    unawaited(_load());
  }

  final CountdownRepository _repository;

  Future<void> _load() async {
    final items = await _repository.load();
    if (mounted) {
      state = CountdownState(loading: false, items: items);
    }
  }

  Future<void> add(String name, DateTime date) {
    final item = ExamCountdown(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      date: DateTime(date.year, date.month, date.day),
    );
    return _save([...state.items, item]);
  }

  Future<void> update(String id, String name, DateTime date) {
    return _save([
      for (final item in state.items)
        item.id == id
            ? item.copyWith(
                name: name.trim(),
                date: DateTime(date.year, date.month, date.day),
              )
            : item,
    ]);
  }

  Future<void> remove(String id) => _save([
    for (final item in state.items)
      if (item.id != id) item,
  ]);

  Future<void> _save(List<ExamCountdown> items) async {
    state = CountdownState(loading: false, items: items);
    await _repository.save(items);
  }
}
