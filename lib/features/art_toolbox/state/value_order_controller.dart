import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/value_order_records.dart';
import '../logic/value_order_game.dart';

final valueOrderRecordRepositoryProvider = Provider<ValueOrderRecordRepository>(
  (ref) => ValueOrderRecordRepository(),
);

/// 明度排序训练的最佳用时表：键为 `色块数-难度`，值为毫秒。
final valueOrderRecordsProvider =
    StateNotifierProvider.autoDispose<ValueOrderRecordsController, Map<String, int>>(
      (ref) => ValueOrderRecordsController(
        ref.watch(valueOrderRecordRepositoryProvider),
      ),
    );

class ValueOrderRecordsController extends StateNotifier<Map<String, int>> {
  ValueOrderRecordsController(this._repository) : super(const <String, int>{}) {
    unawaited(_load());
  }

  final ValueOrderRecordRepository _repository;

  Future<void> _load() async {
    final records = await _repository.load();
    if (mounted) {
      state = {...records, ...state};
    }
  }

  int? bestOf(int count, ValueOrderLevel level) =>
      state[ValueOrderRecordRepository.keyOf(count, level)];

  /// 记录一次完成用时，刷新纪录时返回 true。
  Future<bool> submit(int count, ValueOrderLevel level, int millis) async {
    final next = recordIfBest(
      state,
      ValueOrderRecordRepository.keyOf(count, level),
      millis,
    );
    if (next == null) {
      return false;
    }
    state = next;
    await _repository.save(next);
    return true;
  }
}
