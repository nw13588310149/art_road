import 'package:flutter/foundation.dart';

import 'circle_state.dart';

/// 举报与治理删除共用的原因；选「其他」时必须写明说明。
const circleReportReasons = <String>[
  '广告营销',
  '代画作业',
  '不实考试信息',
  '攻击或嘲讽他人',
  '未经同意发布他人照片或作品',
  '与画室学习无关',
  circleOtherReason,
];

const circleOtherReason = '其他';

/// 「校圈治理」的页签。
enum CircleGovernanceTab { pending, handled, all }

/// 举报处理结果，与接口 `result` 一致：0 未处理 / 1 保留 / 2 删除。
enum CircleReportResult { none, kept, deleted }

extension CircleReportResultApi on CircleReportResult {
  int get apiCode => switch (this) {
    CircleReportResult.none => 0,
    CircleReportResult.kept => 1,
    CircleReportResult.deleted => 2,
  };
}

@immutable
class CircleReportReasonCount {
  const CircleReportReasonCount({required this.reason, required this.count});

  final String reason;
  final int count;
}

/// 一条被举报的动态：同一条动态的多次举报合并为一条。
@immutable
class CircleReportCase {
  const CircleReportCase({
    required this.id,
    required this.postId,
    required this.post,
    required this.postDeleted,
    required this.pending,
    required this.result,
    required this.reportCount,
    required this.reasons,
    required this.latestRemark,
    required this.lastReportTime,
    required this.handleReason,
    required this.handleRemark,
    required this.handlerName,
    required this.handleTime,
  });

  final String id;
  final String postId;

  /// 被举报的动态；已删除的是删除时留下的快照。
  final CirclePost? post;
  final bool postDeleted;
  final bool pending;
  final CircleReportResult result;
  final int reportCount;

  /// 按人数从多到少。
  final List<CircleReportReasonCount> reasons;

  /// 最近一条举报说明，没有时为空串。
  final String latestRemark;

  /// 最近一次举报时间，已格式化（如「今天 10:20」）。
  final String lastReportTime;
  final String handleReason;
  final String handleRemark;
  final String handlerName;

  /// 处理时间，已格式化。
  final String handleTime;
}

@immutable
class CircleGovernanceState {
  const CircleGovernanceState({
    this.tab = CircleGovernanceTab.pending,
    this.pending = const <CircleReportCase>[],
    this.handled = const <CircleReportCase>[],
    this.pendingTotal = 0,
    this.handledTotal = 0,
    this.loading = true,
    this.loaded = false,
    this.error,
    this.busyIds = const <String>{},
  });

  final CircleGovernanceTab tab;
  final List<CircleReportCase> pending;
  final List<CircleReportCase> handled;

  /// 待处理总数，与管理员工作台「校圈治理」的数字同源。
  final int pendingTotal;
  final int handledTotal;
  final bool loading;

  /// 至少成功加载过一次；之前页签不显示数量。
  final bool loaded;

  /// 最近一次加载失败的提示。
  final String? error;

  /// 正在提交处理的举报 id。
  final Set<String> busyIds;

  CircleGovernanceState copyWith({
    CircleGovernanceTab? tab,
    List<CircleReportCase>? pending,
    List<CircleReportCase>? handled,
    int? pendingTotal,
    int? handledTotal,
    bool? loading,
    bool? loaded,
    String? error,
    bool clearError = false,
    Set<String>? busyIds,
  }) {
    return CircleGovernanceState(
      tab: tab ?? this.tab,
      pending: pending ?? this.pending,
      handled: handled ?? this.handled,
      pendingTotal: pendingTotal ?? this.pendingTotal,
      handledTotal: handledTotal ?? this.handledTotal,
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      error: clearError ? null : (error ?? this.error),
      busyIds: busyIds ?? this.busyIds,
    );
  }
}
