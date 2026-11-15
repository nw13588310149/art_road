import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../../artworks/ui/artwork_upload_dialog.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/state/shell_state.dart';
import '../../smart_campus/state/campus_entry.dart';
import '../../smart_campus/state/smart_campus_controller.dart';
import '../../teaching_overview/ui/teaching_overview_page.dart';
import '../data/today_models.dart';
import '../state/today_board.dart';
import '../state/today_controller.dart';
import 'widgets/today_agenda_card.dart';
import 'widgets/today_insight_cards.dart';
import 'widgets/today_student_cards.dart';
import 'widgets/today_task_card.dart';

/// 今日（`/today`）：学生「今日学习」，教职「今日工作」。
///
/// 所有身份同一个骨架：页头一句小结；左栏是待处理和值得关注，右栏是今日日程，
/// 底部是常用入口。只放当天要做的事，分析报表在学情里。
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  static const double _sideWidth = 307;
  static const double _gap = AppSpace.s16;

  /// 看板由外壳一直持有（导航角标要用），进入页面时超过这个时间就重新取一次。
  static const _staleAfter = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final snapshot = ref.read(todaySnapshotProvider).valueOrNull;
      if (snapshot != null &&
          !snapshot.isEmpty &&
          DateTime.now().difference(snapshot.now) > _staleAfter) {
        ref.invalidate(todaySnapshotProvider);
      }
    });
  }

  void _refresh() => ref.invalidate(todaySnapshotProvider);

  /// 打开一行对应的地方；回来后重新取数，处理完的事从列表里消失。
  Future<void> _open(TodayTarget target) async {
    final navigator = Navigator.of(context);
    switch (target) {
      case TodayRouteTarget(:final route, :final arguments):
        await navigator.pushNamed(route, arguments: arguments);
      case TodayCampusTarget(:final entry):
        ref.read(smartCampusControllerProvider.notifier).openEntry(entry);
        await navigator.pushNamed(RoutePaths.smartCampus);
      case TodayReportTarget(:final report, :final parameter, :final campus):
        await openTeachingReport(
          context,
          report,
          campus: campus,
          parameter: parameter,
        );
      case TodayUploadTarget(
        :final taskId,
        :final parentId,
        :final title,
        :final subject,
      ):
        final saved = await showArtworkUploadDialog(
          context,
          taskId: taskId,
          parentId: parentId,
          title: title,
          subject: subject,
        );
        if (mounted && saved == true) {
          AppToast.showSuccess(context, parentId.isEmpty ? '作品已提交' : '改画已提交');
        }
      case TodayScheduleTarget():
        final user = ref.read(shellControllerProvider).user;
        final campus = ref.read(smartCampusControllerProvider.notifier);
        final role = ref.read(todayRoleProvider);
        if (role == 'admin' || role == 'principal') {
          campus.openEntry(CampusEntry.scheduleManagement);
        } else {
          campus.openMyScheduleForUser(role: role, identity: user.identity);
        }
        await navigator.pushNamed(RoutePaths.smartCampus);
    }
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(todayRoleProvider);
    final snapshot = ref.watch(todaySnapshotProvider);
    final data = snapshot.valueOrNull;
    final name = ref.watch(
      shellControllerProvider.select((s) => s.user.displayName),
    );

    final board = data == null || data.isEmpty || data.allFailed
        ? null
        : buildTodayBoard(data);
    final Widget body;
    if (board != null) {
      body = _board(board, data!);
    } else if (snapshot.hasError || (data != null && data.allFailed)) {
      body = _failed();
    } else {
      body = const _TodaySkeleton(sideWidth: _sideWidth, gap: _gap);
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TodayHeader(
            title: todayNavLabel(role),
            greeting: '${todayGreeting(DateTime.now())}，$name',
            board: board,
            refreshing: snapshot.isLoading,
            onRefresh: _refresh,
          ),
          const SizedBox(height: _gap),
          body,
          const SizedBox(height: _gap),
        ],
      ),
    );
  }

  Widget _failed() => AppCard(
    child: SizedBox(
      height: 320,
      child: AppErrorState(
        title: '今日内容加载失败',
        description: '请检查网络后重试',
        onRetry: _refresh,
      ),
    ),
  );

  Widget _board(TodayBoard board, TodaySnapshot data) {
    final student = board.isStudent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.failedSources > 0) ...[
          AppNotice(
            message: '有 ${data.failedSources} 项内容暂时没有取到，其余内容照常显示。',
            tone: AppTone.warning,
            action: AppButton(
              label: '重试',
              variant: AppButtonVariant.text,
              size: AppButtonSize.sm,
              onTap: _refresh,
            ),
          ),
          const SizedBox(height: _gap),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TodayTaskCard(board: board, onOpen: _open),
                  if (student && board.practices.isNotEmpty) ...[
                    const SizedBox(height: _gap),
                    TodayPracticeCard(
                      practices: board.practices,
                      onOpen: _open,
                    ),
                  ],
                  if (board.signals.isNotEmpty) ...[
                    const SizedBox(height: _gap),
                    TodaySignalCard(board: board, onOpen: _open),
                  ],
                  if (board.notesTitle.isNotEmpty) ...[
                    const SizedBox(height: _gap),
                    TodayNoteCard(board: board, onOpen: _open),
                  ],
                ],
              ),
            ),
            const SizedBox(width: _gap),
            SizedBox(
              width: _sideWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TodayAgendaCard(
                    board: board,
                    onOpen: _open,
                    scheduleLabel: switch (board.role) {
                      'dormManager' => null,
                      'admin' || 'principal' => '排课',
                      _ => '课表',
                    },
                  ),
                  if (student) ...[
                    const SizedBox(height: _gap),
                    TodayLatestReviewCard(
                      review: board.latestReview,
                      onOpen: _open,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (board.shortcuts.isNotEmpty) ...[
          const SizedBox(height: _gap),
          TodayShortcutCard(shortcuts: board.shortcuts, onOpen: _open),
        ],
      ],
    );
  }
}

/// 页头：问候、一句小结、日期与刷新。
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.title,
    required this.greeting,
    required this.board,
    required this.refreshing,
    required this.onRefresh,
  });

  final String title;
  final String greeting;
  final TodayBoard? board;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final current = board;
    final pending = current?.pendingCount ?? 0;
    return Semantics(
      container: true,
      label: title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title24,
                ),
                const SizedBox(height: 2),
                if (current == null)
                  Text(
                    '正在整理今天的安排',
                    style: AppText.body14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  _Summary(summary: current.summary, pending: pending),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s16),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.br12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpace.s8),
                Text(todayDateLabel(DateTime.now()), style: AppText.body14),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          AppIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: '刷新今日内容',
            background: AppColors.surface,
            enabled: !refreshing,
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

/// 小结里的待处理数用品牌色，其余是说明文字。
class _Summary extends StatelessWidget {
  const _Summary({required this.summary, required this.pending});

  final String summary;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final base = AppText.body14.copyWith(color: AppColors.textSecondary);
    final number = '$pending';
    final index = pending > 0 ? summary.indexOf(number) : -1;
    if (index < 0) {
      return Text(
        summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: summary.substring(0, index)),
          TextSpan(
            text: number,
            style: AppText.number(size: 14, color: AppColors.brand),
          ),
          TextSpan(text: summary.substring(index + number.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 首次加载的占位：和正式版式同样的两栏。
class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton({required this.sideWidth, required this.gap});

  final double sideWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    Widget rows(int count) => AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSkeleton(width: 72, height: 20),
          for (var i = 0; i < count; i++) ...[
            const SizedBox(height: AppSpace.s16),
            const Row(
              children: [
                AppSkeleton(width: 40, height: 40, radius: 12),
                SizedBox(width: AppSpace.s12),
                Expanded(child: AppSkeletonText(lines: 2)),
              ],
            ),
          ],
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              rows(3),
              SizedBox(height: gap),
              rows(2),
            ],
          ),
        ),
        SizedBox(width: gap),
        SizedBox(width: sideWidth, child: rows(3)),
      ],
    );
  }
}
