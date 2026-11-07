import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/composite_estimate.dart';

class CompositeEstimateFormState {
  const CompositeEstimateFormState({
    this.loading = true,
    this.form = const CompositeEstimateForm(),
  });

  final bool loading;
  final CompositeEstimateForm form;
}

final compositeEstimateFormProvider =
    StateNotifierProvider.autoDispose<
      CompositeEstimateFormController,
      CompositeEstimateFormState
    >((ref) {
      final account = ref.watch(appStorageProvider).mobile;
      return CompositeEstimateFormController(
        CompositeEstimateStore(account: account),
      );
    });

/// 综合分预估的输入：读取上次填写的内容，每次修改后写回本机。
class CompositeEstimateFormController
    extends StateNotifier<CompositeEstimateFormState> {
  CompositeEstimateFormController(this._store)
    : super(const CompositeEstimateFormState()) {
    unawaited(_load());
  }

  final CompositeEstimateStore _store;
  bool _edited = false;

  Future<void> _load() async {
    final form = await _store.load();
    if (!mounted) {
      return;
    }
    state = CompositeEstimateFormState(
      loading: false,
      form: _edited ? state.form : form,
    );
  }

  void update(CompositeEstimateForm Function(CompositeEstimateForm form) change) {
    _edited = true;
    final form = change(state.form);
    state = CompositeEstimateFormState(loading: false, form: form);
    unawaited(_store.save(form));
  }
}
