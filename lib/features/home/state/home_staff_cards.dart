import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../artworks/data/artwork_models.dart';
import '../../artworks/data/artwork_repository.dart';
import '../data/home_repository.dart';

/// 今日待办里一行点开去哪里。
enum HomeTodoAction {
  artworks,
  classWorkbench,
  notices,
  dormCheckByRoom,
  dormDynamic,
  dormCheckIn,
  dormLeave,
  leaveApproval,
  signManagement,
  scheduleManagement,
}

@immutable
class HomeTodoItem {
  const HomeTodoItem({
    required this.action,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.value = '',
    this.unit = '',
    this.loading = false,
    this.attention = false,
  });

  final HomeTodoAction action;
  final IconData icon;
  final String title;
  final String subtitle;

  /// 右侧的数字或时间（如「7」「22:30」）；为空时只显示箭头。
  final String value;
  final String unit;

  /// 数字还在加载。
  final bool loading;

  /// 有待处理的事项：数字用提醒色。
  final bool attention;
}

/// 今日待办用到的数据，全部来自首页已有的数据源。
@immutable
class HomeTodoInput {
  const HomeTodoInput({
    this.pendingReviews,
    this.reviewsLoading = false,
    this.unreadNotices = 0,
    this.eveningCheck = '',
    this.morningCheck = '',
    this.checkLoading = false,
    this.leaveApprovals,
    this.signConfirmations,
    this.adminLoading = false,
  });

  final int? pendingReviews;
  final bool reviewsLoading;
  final int unreadNotices;
  final String eveningCheck;
  final String morningCheck;
  final bool checkLoading;
  final int? leaveApprovals;
  final int? signConfirmations;
  final bool adminLoading;
}

String _count(int? value) => value == null ? '—' : '$value';

/// 班主任、宿管、管理员首页的今日待办（其他身份为空）。
List<HomeTodoItem> buildHomeTodos(String role, HomeTodoInput input) {
  final notices = HomeTodoItem(
    action: HomeTodoAction.notices,
    icon: Icons.notifications_none_rounded,
    title: '未读消息',
    subtitle: '学情、作品点评与系统消息',
    value: '${input.unreadNotices}',
    unit: '条',
    attention: input.unreadNotices > 0,
  );
  switch (role.trim()) {
    case 'headTeacher':
      final pending = input.pendingReviews;
      return [
        HomeTodoItem(
          action: HomeTodoAction.artworks,
          icon: Icons.rate_review_outlined,
          title: '待点评作品',
          subtitle: '分配给你的学生作品',
          value: _count(pending),
          unit: '件',
          loading: input.reviewsLoading,
          attention: (pending ?? 0) > 0,
        ),
        const HomeTodoItem(
          action: HomeTodoAction.classWorkbench,
          icon: Icons.apartment_outlined,
          title: '班级工作台',
          subtitle: '班级通知、请假审批与考勤',
        ),
        notices,
      ];
    case 'dormManager':
      String time(String raw) {
        final text = raw.replaceAll('前', '').trim();
        return text.isEmpty ? '—' : text;
      }
      return [
        HomeTodoItem(
          action: HomeTodoAction.dormCheckByRoom,
          icon: Icons.king_bed_outlined,
          title: '晚查寝',
          subtitle: '学生在此时间前归寝打卡',
          value: time(input.eveningCheck),
          loading: input.checkLoading,
        ),
        HomeTodoItem(
          action: HomeTodoAction.dormDynamic,
          icon: Icons.wb_sunny_outlined,
          title: '早查寝',
          subtitle: '起床后在此时间前签到',
          value: time(input.morningCheck),
          loading: input.checkLoading,
        ),
        const HomeTodoItem(
          action: HomeTodoAction.dormCheckIn,
          icon: Icons.how_to_reg_outlined,
          title: '到岗打卡',
          subtitle: '本人上下班打卡与记录',
        ),
        const HomeTodoItem(
          action: HomeTodoAction.dormLeave,
          icon: Icons.edit_note_rounded,
          title: '宿管请假',
          subtitle: '提交与查看本人的请假',
        ),
        notices,
      ];
    case 'admin':
      final leaves = input.leaveApprovals;
      final signs = input.signConfirmations;
      return [
        HomeTodoItem(
          action: HomeTodoAction.leaveApproval,
          icon: Icons.approval_outlined,
          title: '教师请假审批',
          subtitle: '老师和宿管的请假申请',
          value: _count(leaves),
          unit: '条',
          loading: input.adminLoading,
          attention: (leaves ?? 0) > 0,
        ),
        HomeTodoItem(
          action: HomeTodoAction.signManagement,
          icon: Icons.fact_check_outlined,
          title: '小课签课确认',
          subtitle: '近一周学生已评价的小课',
          value: _count(signs),
          unit: '节',
          loading: input.adminLoading,
          attention: (signs ?? 0) > 0,
        ),
        const HomeTodoItem(
          action: HomeTodoAction.scheduleManagement,
          icon: Icons.calendar_month_outlined,
          title: '排课与课表',
          subtitle: '本周课表与小课申请',
        ),
        notices,
      ];
  }
  return const <HomeTodoItem>[];
}

/// 作品点评统计（任课老师的待点评卡、班主任的今日待办）。
final homeReviewStatsProvider = FutureProvider.autoDispose<ArtworkStats>((
  ref,
) async {
  final response = await ref
      .watch(artworkRepositoryProvider)
      .getTeacherStatistics();
  if (!response.isSuccess) {
    throw StateError(response.errorOr('作品点评统计加载失败'));
  }
  return ArtworkStats.fromJson(response.data);
});

/// 管理员今日待办里的两个数：教职工待审批请假、待确认的小课。
final homeAdminTodoProvider =
    FutureProvider.autoDispose<({int leaves, int signs})>((ref) async {
      final response = await ref.watch(homeRepositoryProvider).getAdminIndexSum();
      if (!response.isSuccess) {
        throw StateError(response.displayMsg);
      }
      var data = response.data;
      // 兼容外层再包一层 data 的返回。
      while (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      int read(String key) {
        final value = data is Map ? data[key] : null;
        if (value is num) return value.toInt();
        return int.tryParse('${value ?? ''}') ?? 0;
      }

      return (
        leaves: read('leaveStatus0Count'),
        signs: read('smallCourseSignStatus5Count'),
      );
    });
