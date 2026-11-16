import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../shell/state/shell_controller.dart';
import '../data/today_models.dart';
import '../state/today_controller.dart';
import 'today_actions.dart';
import 'today_style.dart';
import 'widgets/today_charts.dart';
import 'widgets/today_checklist.dart';
import 'widgets/today_hero.dart';
import 'widgets/today_highlights.dart';
import 'widgets/today_step_sheet.dart';

/// 今日（`/today`）：学生「今日学习」，教职「今日工作」。
///
/// 一屏回答三个问题：今天做到哪了、下一步做什么、还有哪些没做。
/// - 头图：问候、进度环与下一步；
/// - 数字卡：这个身份今天最该知道的四个数；
/// - 左栏：从早到晚的时间线清单（可打勾、推迟、今天不做、添加自己的安排），
///   以及需要跟进的人；
/// - 右栏：这个身份当天要看的图表；底部是快捷入口。
///
/// 内容全部来自 `/app/today/board`，页面不自己拼数据。
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  static const double _gap = AppSpace.s16;

  TodayController get _controller => ref.read(todayControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // 看板由外壳一直持有（侧栏角标要用），进入页面时隔得久了就重新取一次。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refreshIfStale();
    });
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted || message.isEmpty) return;
    if (error) {
      AppToast.showError(context, message);
    } else {
      AppToast.showSuccess(context, message);
    }
  }

  /// 打勾或取消。跟着业务数据自动完成的事不能手动打勾。
  Future<void> _toggle(TodayStep step) async {
    if (!step.manual) {
      _toast('完成对应的操作后会自动打勾', error: true);
      return;
    }
    final wasDone = step.done;
    final message = await _controller.toggle(step);
    if (message.isNotEmpty) {
      _toast(message, error: true);
      return;
    }
    final summary = ref.read(todayControllerProvider).board?.summary;
    if (!wasDone && summary != null) {
      _toast(
        summary.allDone
            ? '今天的安排都完成了'
            : '已打勾，今天完成 ${summary.done} / ${summary.total} 件',
      );
    }
  }

  /// 去做一件事；没有对应页面的事直接打勾。回来后重新取数。
  Future<void> _act(TodayStep step) async {
    final action = step.action;
    if (action == null) {
      await _toggle(step);
      return;
    }
    final saved = await openTodayAction(context, ref, action);
    if (!mounted) return;
    if (saved) {
      _toast(action.parentId.isEmpty ? '作品已提交' : '改画已提交');
      // 改画重交这类要本人确认的事，提交成功就替他打勾。
      if (step.manual && !step.done) {
        await _controller.complete(step);
        return;
      }
    }
    await _controller.refresh();
  }

  Future<void> _show(TodayStep step) async {
    final choice = await showTodayStepSheet(context, step);
    if (!mounted || choice == null) return;
    switch (choice) {
      case TodayStepChoice.act:
        await _act(step);
      case TodayStepChoice.toggle:
        await _toggle(step);
      case TodayStepChoice.snooze:
        final message = await _controller.snooze(step);
        _toast(
          message.isNotEmpty ? message : (step.snoozed ? '已取消推迟' : '已推迟到晚上'),
          error: message.isNotEmpty,
        );
      case TodayStepChoice.skip:
        final restoring = step.status == TodayStepStatus.skipped;
        final message = await _controller.skip(step);
        _toast(
          message.isNotEmpty ? message : (restoring ? '已恢复到清单' : '今天不做这件事'),
          error: message.isNotEmpty,
        );
      case TodayStepChoice.delete:
        final confirmed = await showAppConfirm(
          context: context,
          title: '删除这件安排？',
          message: step.title,
          confirmLabel: '删除',
          danger: true,
        );
        if (!confirmed) return;
        final message = await _controller.deleteStep(step);
        _toast(message.isNotEmpty ? message : '已删除', error: message.isNotEmpty);
    }
  }

  Future<void> _add() async {
    final input = await showTodayAddStepDialog(context);
    if (input == null) return;
    final message = await _controller.addStep(
      title: input.title,
      slot: input.slot,
      detail: input.detail,
    );
    _toast(
      message.isNotEmpty ? message : '已添加到今天的清单',
      error: message.isNotEmpty,
    );
  }

  /// 图表、常用入口和跟进列表里的动作。
  Future<void> _open(TodayAction action) async {
    if (action.type == 'practiceLog') {
      final minutes = await showTodayPracticeDialog(context);
      if (minutes == null) return;
      final message = await _controller.logPractice(minutes);
      _toast(
        message.isNotEmpty ? message : '已记录 $minutes 分钟',
        error: message.isNotEmpty,
      );
      return;
    }
    await openTodayAction(context, ref, action);
    if (mounted) await _controller.refresh();
  }

  Future<void> _follow(TodayPerson person) async {
    final message = await _controller.follow(person);
    if (message.isNotEmpty) _toast(message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayControllerProvider);
    final name = ref.watch(
      shellControllerProvider.select((s) => s.user.displayName),
    );
    final board = state.board;
    final now = DateTime.now();

    if (board == null) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: state.errorMessage.isNotEmpty
            ? AppCard(
                child: SizedBox(
                  height: 320,
                  child: AppErrorState(
                    title: '今日内容加载失败',
                    description: state.errorMessage,
                    onRetry: _controller.refresh,
                  ),
                ),
              )
            : const _TodaySkeleton(),
      );
    }

    final people = board.people;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TodayHero(
            board: board,
            greeting: '${todayGreeting(now)}，$name',
            dateLabel: todayDateLabel(now),
            refreshing: state.loading,
            onRefresh: _controller.refresh,
            onAct: _act,
            onShow: _show,
          ),
          if (state.errorMessage.isNotEmpty) ...[
            const SizedBox(height: _gap),
            AppNotice(
              message: '刷新没有成功，下面是上一次的内容。',
              tone: AppTone.warning,
              action: AppButton(
                label: '重试',
                variant: AppButtonVariant.text,
                size: AppButtonSize.sm,
                onTap: _controller.refresh,
              ),
            ),
          ],
          if (board.highlights.isNotEmpty) ...[
            const SizedBox(height: _gap),
            TodayHighlights(items: board.highlights, onOpen: _open),
          ],
          const SizedBox(height: _gap),
          LayoutBuilder(
            builder: (context, box) {
              final sideWidth = box.maxWidth >= 900 ? 340.0 : 300.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TodayChecklist(
                          board: board,
                          filter: state.filter,
                          busy: state.busy,
                          now: now,
                          onFilter: _controller.setFilter,
                          onAdd: _add,
                          onToggle: _toggle,
                          onAct: _act,
                          onShow: _show,
                          onDismissTip: _controller.dismissTip,
                        ),
                        if (people != null) ...[
                          const SizedBox(height: _gap),
                          TodayPeopleCard(
                            people: people,
                            busy: state.busy,
                            onOpen: _open,
                            onFollow: _follow,
                          ),
                        ],
                        if (board.shortcuts.isNotEmpty) ...[
                          const SizedBox(height: _gap),
                          _Shortcuts(shortcuts: board.shortcuts, onOpen: _open),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: _gap),
                  SizedBox(
                    width: sideWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < board.charts.length; i++) ...[
                          if (i > 0) const SizedBox(height: _gap),
                          TodayChartCard(chart: board.charts[i], onOpen: _open),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: _gap),
        ],
      ),
    );
  }
}

/// 页头问候语：按时间段。
String todayGreeting(DateTime now) {
  final hour = now.hour;
  if (hour < 5) return '夜深了';
  if (hour < 11) return '早上好';
  if (hour < 13) return '中午好';
  if (hour < 18) return '下午好';
  return '晚上好';
}

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 页头日期：11月16日 周一。
String todayDateLabel(DateTime now) =>
    '${now.month}月${now.day}日 ${_weekdays[now.weekday - 1]}';

/// 快捷入口：这个身份常去的几个地方，一排带颜色的图标。
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.shortcuts, required this.onOpen});

  final List<TodayShortcut> shortcuts;
  final ValueChanged<TodayAction> onOpen;

  static const _tints = [
    TodayTint.purple,
    TodayTint.teal,
    TodayTint.pink,
    TodayTint.blue,
    TodayTint.amber,
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: '快捷入口',
      child: LayoutBuilder(
        builder: (context, box) {
          // 一行三个，窄的时候两个；每个入口占满自己那一格。
          final columns = box.maxWidth >= 480 ? 3 : 2;
          const gap = AppSpace.s8;
          final width = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < shortcuts.length; i++)
                SizedBox(
                  width: width,
                  child: AppPressable(
                    onTap: () => onOpen(shortcuts[i].action),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpace.s8),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: AppRadius.br12,
                      ),
                      child: Row(
                        children: [
                          TodayIconChip(
                            icon: todayIcon(shortcuts[i].icon),
                            tint: _tints[i % _tints.length],
                            size: 36,
                          ),
                          const SizedBox(width: AppSpace.s8),
                          Expanded(
                            child: Text(
                              shortcuts[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body14Strong,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.textPlaceholder,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 首次加载的占位：和正式版式同样的结构。
class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) {
    Widget card(int rows) => AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSkeleton(width: 96, height: 20),
          for (var i = 0; i < rows; i++) ...[
            const SizedBox(height: AppSpace.s16),
            const Row(
              children: [
                AppSkeleton(width: 28, height: 28, radius: 14),
                SizedBox(width: AppSpace.s12),
                Expanded(child: AppSkeletonText(lines: 2)),
              ],
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSkeleton(height: 168, radius: AppRadius.card),
        const SizedBox(height: AppSpace.s16),
        const Row(
          children: [
            Expanded(child: AppSkeleton(height: 104, radius: AppRadius.card)),
            SizedBox(width: AppSpace.s12),
            Expanded(child: AppSkeleton(height: 104, radius: AppRadius.card)),
            SizedBox(width: AppSpace.s12),
            Expanded(child: AppSkeleton(height: 104, radius: AppRadius.card)),
            SizedBox(width: AppSpace.s12),
            Expanded(child: AppSkeleton(height: 104, radius: AppRadius.card)),
          ],
        ),
        const SizedBox(height: AppSpace.s16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: card(5)),
            const SizedBox(width: AppSpace.s16),
            SizedBox(width: 340, child: card(3)),
          ],
        ),
      ],
    );
  }
}
