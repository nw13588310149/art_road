import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exam_checklist.dart';

final examChecklistRepositoryProvider = Provider<ExamChecklistRepository>(
  (ref) => ExamChecklistRepository(),
);

final examChecklistControllerProvider =
    StateNotifierProvider.autoDispose<
      ExamChecklistController,
      ExamChecklistState
    >(
      (ref) =>
          ExamChecklistController(ref.watch(examChecklistRepositoryProvider)),
    );

class ExamChecklistState {
  const ExamChecklistState({
    this.loading = true,
    this.checklist = const ExamChecklist(),
  });

  final bool loading;
  final ExamChecklist checklist;
}

class ExamChecklistController extends StateNotifier<ExamChecklistState> {
  ExamChecklistController(this._repository)
    : super(const ExamChecklistState()) {
    unawaited(_load());
  }

  final ExamChecklistRepository _repository;

  Future<void> _load() async {
    final checklist = await _repository.load();
    if (mounted && state.loading) {
      state = ExamChecklistState(loading: false, checklist: checklist);
    }
  }

  Future<void> toggle(String id) => _save(state.checklist.toggle(id));

  /// 返回是否真的添加了（名称为空或同组重名时不添加）。
  Future<bool> add(ChecklistGroup group, String label) async {
    final next = state.checklist.add(group, label);
    if (identical(next, state.checklist)) {
      return false;
    }
    await _save(next);
    return true;
  }

  Future<void> remove(String id) => _save(state.checklist.remove(id));

  Future<void> reset({bool keepCustom = false}) =>
      _save(state.checklist.reset(keepCustom: keepCustom));

  Future<void> _save(ExamChecklist checklist) async {
    state = ExamChecklistState(loading: false, checklist: checklist);
    await _repository.save(checklist);
  }
}
