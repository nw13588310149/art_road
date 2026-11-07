import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/circle_api_mapper.dart';
import '../data/circle_repository.dart';
import 'circle_controller.dart';
import 'circle_governance_state.dart';

final circleGovernanceControllerProvider =
    StateNotifierProvider.autoDispose<
      CircleGovernanceController,
      CircleGovernanceState
    >((ref) => CircleGovernanceController(ref));

/// 「校圈治理」：待处理 / 已处理两份举报列表，保留或删除后记录立即移到「已处理」。
class CircleGovernanceController extends StateNotifier<CircleGovernanceState> {
  CircleGovernanceController(this._ref) : super(const CircleGovernanceState()) {
    Future.microtask(load);
  }

  final Ref _ref;

  CircleRepository get _repo => _ref.read(circleRepositoryProvider);

  void setTab(CircleGovernanceTab tab) {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab);
  }

  /// 同时拉取待处理与已处理；失败时保留已有数据并记下提示。
  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final responses = await Future.wait([
        _repo.postsReportList(status: 0),
        _repo.postsReportList(status: 1),
      ]);
      if (!mounted) return;
      final failed = responses.where((r) => !r.isSuccess).firstOrNull;
      if (failed != null) {
        final message = failed.displayMsg;
        state = state.copyWith(
          loading: false,
          error: message.isEmpty ? '举报记录加载失败，请稍后重试' : message,
        );
        return;
      }
      final pending = mapReportCasesData(responses[0].data);
      final handled = mapReportCasesData(responses[1].data);
      state = state.copyWith(
        loading: false,
        loaded: true,
        pending: pending,
        handled: handled,
        pendingTotal: mapPageTotal(responses[0].data, pending.length),
        handledTotal: mapPageTotal(responses[1].data, handled.length),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: '举报记录加载失败，请检查网络后重试');
    }
  }

  /// 保留：举报不成立，动态继续展示。成功返回 `null`，失败返回提示。
  Future<String?> keep(String caseId, {String remark = ''}) {
    return _handle(caseId, result: CircleReportResult.kept, remark: remark);
  }

  /// 删除：[reason] 必填，动态同时从校圈移除。成功返回 `null`，失败返回提示。
  Future<String?> delete(
    String caseId, {
    required String reason,
    String remark = '',
  }) {
    return _handle(
      caseId,
      result: CircleReportResult.deleted,
      reason: reason,
      remark: remark,
    );
  }

  /// 「全部动态」里删除任意一条动态（需写明原因）；有待处理的举报时一并结案。
  Future<String?> deletePost(
    String postId, {
    required String reason,
    String remark = '',
  }) async {
    final resp = await _repo.managerPostsDelete(
      postsId: postId,
      reason: reason,
      remark: remark,
    );
    if (!mounted) return null;
    if (!resp.isSuccess) return resp.displayMsg;
    _afterHandled(
      caseId: '',
      postId: postId,
      handled: mapSingleReportCase(resp.data),
      deleted: true,
    );
    return null;
  }

  Future<String?> _handle(
    String caseId, {
    required CircleReportResult result,
    String reason = '',
    String remark = '',
  }) async {
    if (state.busyIds.contains(caseId)) return '';
    final postId =
        state.pending.where((c) => c.id == caseId).firstOrNull?.postId ?? '';
    state = state.copyWith(busyIds: {...state.busyIds, caseId});
    final resp = await _repo.postsReportHandle(
      id: caseId,
      result: result.apiCode,
      reason: reason,
      remark: remark,
    );
    if (!mounted) return null;
    state = state.copyWith(busyIds: {...state.busyIds}..remove(caseId));
    if (!resp.isSuccess) return resp.displayMsg;
    _afterHandled(
      caseId: caseId,
      postId: postId,
      handled: mapSingleReportCase(resp.data),
      deleted: result == CircleReportResult.deleted,
    );
    return null;
  }

  /// 处理结果立即生效：移出「待处理」、放到「已处理」最前面；删除的动态同时移出校圈列表。
  void _afterHandled({
    required String caseId,
    required String postId,
    required CircleReportCase? handled,
    required bool deleted,
  }) {
    bool settled(CircleReportCase c) =>
        c.id == caseId ||
        c.id == handled?.id ||
        (postId.isNotEmpty && c.postId == postId);
    final pending = [
      for (final c in state.pending)
        if (!settled(c)) c,
    ];
    final removed = state.pending.length - pending.length;
    state = state.copyWith(
      pending: pending,
      pendingTotal: (state.pendingTotal - removed).clamp(0, 1 << 30),
      handled: [
        ?handled,
        for (final c in state.handled)
          if (c.id != handled?.id) c,
      ],
      handledTotal: handled == null ? null : state.handledTotal + 1,
    );
    final removedPostId = postId.isNotEmpty ? postId : (handled?.postId ?? '');
    if (deleted &&
        removedPostId.isNotEmpty &&
        _ref.exists(circleControllerProvider)) {
      _ref
          .read(circleControllerProvider.notifier)
          .removePostLocally(removedPostId);
    }
  }
}
