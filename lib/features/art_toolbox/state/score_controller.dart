import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/score_form_repository.dart';

final scoreFormRepositoryProvider = Provider<ScoreFormRepository>(
  (ref) => ScoreFormRepository(),
);

final scoreFormControllerProvider =
    StateNotifierProvider.autoDispose<ScoreFormController, ScoreFormState>(
      (ref) => ScoreFormController(ref.watch(scoreFormRepositoryProvider)),
    );

class ScoreFormState {
  const ScoreFormState({this.loading = true, this.data = const ScoreFormData()});

  final bool loading;
  final ScoreFormData data;
}

/// 综合分计算器：读取上次输入，每次修改后写回本地。
class ScoreFormController extends StateNotifier<ScoreFormState> {
  ScoreFormController(this._repository) : super(const ScoreFormState()) {
    unawaited(_load());
  }

  final ScoreFormRepository _repository;
  bool _edited = false;

  Future<void> _load() async {
    final data = await _repository.load();
    if (mounted && !_edited) {
      state = ScoreFormState(loading: false, data: data);
    } else if (mounted) {
      state = ScoreFormState(loading: false, data: state.data);
    }
  }

  void update(ScoreFormData Function(ScoreFormData data) change) {
    _edited = true;
    final data = change(state.data);
    state = ScoreFormState(loading: false, data: data);
    unawaited(_repository.save(data));
  }
}
