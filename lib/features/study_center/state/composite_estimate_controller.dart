import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../data/composite_estimate.dart';

class CompositeEstimateFormState {
  const CompositeEstimateFormState({
    this.loading = true,
    this.form = const CompositeEstimateForm(),
    this.loadError,
    this.saveError,
  });

  final bool loading;
  final CompositeEstimateForm form;
  final String? loadError;
  final String? saveError;
}

final compositeEstimateFormProvider =
    StateNotifierProvider<
      CompositeEstimateFormController,
      CompositeEstimateFormState
    >((ref) {
      final storage = ref.watch(appStorageProvider);
      final owner = storage.token;
      final session = storage.sessionToken;
      final onSessionChanged = ref.invalidateSelf;
      session.addListener(onSessionChanged);
      ref.onDispose(() => session.removeListener(onSessionChanged));
      return CompositeEstimateFormController(
        CompositeEstimateStore(client: ref.watch(markingApiClientProvider)),
        isCurrent: () =>
            owner.isNotEmpty &&
            storage.token == owner &&
            !storage.isGuestSession,
      );
    });

/// 按账号保留表单及写入队列，离开页面也能完成同一账号的保存。
class CompositeEstimateFormController
    extends StateNotifier<CompositeEstimateFormState> {
  CompositeEstimateFormController(
    this._store, {
    required bool Function() isCurrent,
  }) : _isCurrent = isCurrent,
       super(const CompositeEstimateFormState()) {
    unawaited(_load());
  }

  final CompositeEstimateStore _store;
  final bool Function() _isCurrent;
  Future<void>? _saving;
  int _latestEdit = 0;

  bool get _canSync => mounted && _isCurrent();

  Future<void> _load() async {
    if (!_canSync) {
      state = const CompositeEstimateFormState(
        loading: false,
        loadError: '请先登录后查看预估',
      );
      return;
    }
    state = CompositeEstimateFormState(form: state.form);
    try {
      final form = await _store.load();
      if (_canSync) {
        state = CompositeEstimateFormState(loading: false, form: form);
      }
    } catch (error) {
      if (_canSync) {
        state = CompositeEstimateFormState(
          loading: false,
          form: state.form,
          loadError: _message(error, '预估读取失败，请重试'),
        );
      }
    }
  }

  void retry() {
    if (state.loading) return;
    if (state.loadError != null) {
      unawaited(_load());
    } else if (state.saveError != null) {
      _enqueueSave(state.form);
    }
  }

  void update(
    CompositeEstimateForm Function(CompositeEstimateForm form) change,
  ) {
    if (!_canSync || state.loading || state.loadError != null) return;
    final form = change(state.form);
    state = CompositeEstimateFormState(
      loading: false,
      form: form,
      saveError: state.saveError,
    );
    _enqueueSave(form);
  }

  void _enqueueSave(CompositeEstimateForm form) {
    final revision = ++_latestEdit;
    final previous = _saving;
    final saving = previous == null
        ? _persist(form, revision)
        : previous.then((_) => _persist(form, revision));
    _saving = saving;
    unawaited(
      saving.whenComplete(() {
        if (identical(_saving, saving)) _saving = null;
      }),
    );
  }

  Future<void> _persist(CompositeEstimateForm form, int revision) async {
    if (!_canSync || revision != _latestEdit) return;
    try {
      await _store.save(form);
      if (_canSync && revision == _latestEdit && state.saveError != null) {
        state = CompositeEstimateFormState(loading: false, form: form);
      }
    } catch (error) {
      if (_canSync && revision == _latestEdit) {
        state = CompositeEstimateFormState(
          loading: false,
          form: form,
          saveError: _message(error, '预估保存失败，请重试'),
        );
      }
    }
  }

  String _message(Object error, String fallback) =>
      error is CompositeEstimateRequestFailure && error.message.isNotEmpty
      ? error.message
      : fallback;
}
