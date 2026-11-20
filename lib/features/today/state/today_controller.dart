import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_accounts.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../shell/state/shell_controller.dart';
import '../data/today_models.dart';
import '../data/today_repository.dart';

/// 今日看板用的身份：优先 `/myInfo` 的 role；演示版回包前按登录 token 还原，
/// 页面不用等接口就能按身份显示名称。
String resolveTodayRole(
  String role, {
  required String token,
  bool demoMode = true,
}) {
  final value = role.trim();
  if (value.isNotEmpty) {
    return value;
  }
  if (!demoMode || !DemoAccounts.isDemoToken(token)) {
    return '';
  }
  return DemoAccounts.fromToken(token).roleKey;
}

final todayRoleProvider = Provider.autoDispose<String>((ref) {
  final role = ref.watch(shellControllerProvider.select((s) => s.user.role));
  return resolveTodayRole(role, token: ref.read(appStorageProvider).token);
});

/// 清单的筛选：全部、未完成、已完成。
enum TodayFilter {
  all('全部'),
  open('未完成'),
  done('已完成');

  const TodayFilter(this.label);

  final String label;

  bool accepts(TodayStep step) => switch (this) {
    TodayFilter.all => true,
    TodayFilter.open => step.status.open,
    TodayFilter.done => !step.status.open,
  };
}

@immutable
class TodayState {
  const TodayState({
    this.board,
    this.loading = false,
    this.errorMessage = '',
    this.filter = TodayFilter.all,
    this.busy = const <String>{},
    this.loadedAt,
  });

  final TodayBoard? board;

  /// 正在取看板；已有看板时页面继续显示旧的。
  final bool loading;
  final String errorMessage;
  final TodayFilter filter;

  /// 正在提交的事项 id，对应的行暂时不能再点。
  final Set<String> busy;
  final DateTime? loadedAt;

  TodayState copyWith({
    TodayBoard? board,
    bool? loading,
    String? errorMessage,
    TodayFilter? filter,
    Set<String>? busy,
    DateTime? loadedAt,
  }) => TodayState(
    board: board ?? this.board,
    loading: loading ?? this.loading,
    errorMessage: errorMessage ?? this.errorMessage,
    filter: filter ?? this.filter,
    busy: busy ?? this.busy,
    loadedAt: loadedAt ?? this.loadedAt,
  );
}

/// 今日看板：身份已知、学校信息就绪后取数；外壳一直持有它，侧栏角标也用这一份。
final todayControllerProvider =
    StateNotifierProvider.autoDispose<TodayController, TodayState>((ref) {
      final role = ref.watch(todayRoleProvider);
      // 智慧校园的接口要带学校 id，等学校信息就绪再取。
      final schoolReady = ref.watch(
        shellControllerProvider.select((s) => s.isSchoolReady),
      );
      return TodayController(
        ref.watch(todayRepositoryProvider),
        enabled: role.isNotEmpty && schoolReady,
      );
    });

/// 侧栏「今日」入口的角标：还没做完的件数。
final todayPendingCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(
    todayControllerProvider.select((s) => s.board?.summary.remaining ?? 0),
  );
});

class TodayController extends StateNotifier<TodayState> {
  TodayController(this._repository, {required bool enabled})
    : _enabled = enabled,
      super(TodayState(loading: enabled)) {
    if (enabled) {
      unawaited(refresh());
    }
  }

  final TodayRepository _repository;
  final bool _enabled;
  int _serial = 0;

  /// 重新取看板。在别的页面处理完事情回来、或手动刷新时调用。
  Future<void> refresh() async {
    if (!_enabled) return;
    final serial = ++_serial;
    state = state.copyWith(loading: true, errorMessage: '');
    final response = await _guard(_repository.board);
    if (!mounted || serial != _serial) return;
    _apply(response, fallback: '今日内容加载失败');
  }

  /// 距上次取数超过 [age] 才重新取，避免来回切页面时反复请求。
  Future<void> refreshIfStale([Duration age = const Duration(seconds: 20)]) {
    final loadedAt = state.loadedAt;
    if (state.loading ||
        (loadedAt != null && DateTime.now().difference(loadedAt) < age)) {
      return Future<void>.value();
    }
    return refresh();
  }

  void setFilter(TodayFilter filter) {
    if (state.filter != filter) {
      state = state.copyWith(filter: filter);
    }
  }

  /// 打勾或取消打勾。返回提示文字；成功时为空。
  Future<String> toggle(TodayStep step) => _mutate(
    step.id,
    () =>
        step.done ? _repository.reopen(step.id) : _repository.complete(step.id),
  );

  /// 做完一件要到别处操作的事（如改画重交）后，替它打勾。
  Future<String> complete(TodayStep step) =>
      _mutate(step.id, () => _repository.complete(step.id));

  Future<String> skip(TodayStep step) => _mutate(
    step.id,
    () => step.status == TodayStepStatus.skipped
        ? _repository.restore(step.id)
        : _repository.skip(step.id),
  );

  Future<String> snooze(TodayStep step) =>
      _mutate(step.id, () => _repository.snooze(step.id, on: !step.snoozed));

  Future<String> addStep({
    required String title,
    required String slot,
    String detail = '',
  }) => _mutate(
    '',
    () => _repository.saveStep(title: title, slot: slot, detail: detail),
  );

  Future<String> deleteStep(TodayStep step) =>
      _mutate(step.id, () => _repository.deleteStep(step.id));

  Future<String> logPractice(int minutes) =>
      _mutate('', () => _repository.logPractice(minutes));

  Future<String> follow(TodayPerson person) => _mutate(
    'person:${person.id}',
    () => _repository.follow(person.id, followed: !person.followed),
  );

  Future<void> dismissTip() => _mutate('', _repository.dismissTip);

  Future<String> _mutate(
    String id,
    Future<ApiResponse> Function() request,
  ) async {
    if (id.isNotEmpty) {
      if (state.busy.contains(id)) return '';
      state = state.copyWith(busy: {...state.busy, id});
    }
    final serial = ++_serial;
    final response = await _guard(request);
    if (!mounted) return '';
    if (id.isNotEmpty) {
      state = state.copyWith(busy: {...state.busy}..remove(id));
    }
    if (!response.isSuccess) {
      return response.displayMsg.isEmpty ? '操作没有成功，请重试' : response.displayMsg;
    }
    if (serial == _serial) {
      _apply(response, fallback: '');
    }
    return '';
  }

  void _apply(ApiResponse response, {required String fallback}) {
    if (response.isSuccess && response.data is Map) {
      state = state.copyWith(
        board: TodayBoard.fromJson(response.data),
        loading: false,
        errorMessage: '',
        loadedAt: DateTime.now(),
      );
      return;
    }
    state = state.copyWith(
      loading: false,
      errorMessage: response.displayMsg.isEmpty
          ? fallback
          : response.displayMsg,
    );
  }

  Future<ApiResponse> _guard(Future<ApiResponse> Function() request) async {
    try {
      return await request();
    } catch (_) {
      return const ApiResponse(code: -1, msg: '网络异常，请稍后重试', data: null);
    }
  }
}
