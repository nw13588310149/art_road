// 方向一「留白」：一整张白色底板，靠字号、间距和细线分区，不用卡片。
// 临时代码，见 direction_kit.dart 开头的说明。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../ebooks/data/ebook_models.dart';
import '../../ebooks/state/ebooks_controller.dart';
import '../../ebooks/state/ebooks_state.dart';
import '../../ebooks/ui/widgets/ebook_widgets.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/state/shell_state.dart';
import '../../shell/ui/shell_layout.dart';
import '../../today/data/today_models.dart';
import '../../today/state/today_controller.dart';
import '../../today/ui/today_actions.dart';
import '../../today/ui/today_page.dart';
import 'direction_kit.dart';

const _rule = Divider(height: 1, thickness: 1, color: AppColors.lineSoft);

/// 页头：页面名称加一行说明，右边放这一页的操作。所有页面同一个位置、同一种字号。
class _PageHead extends StatelessWidget {
  const _PageHead({
    required this.title,
    this.caption = '',
    this.middle = const <Widget>[],
    this.actions = const <Widget>[],
  });

  final String title;
  final String caption;
  final List<Widget> middle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Text(title, style: AppText.title20),
          ...middle,
          if (caption.isNotEmpty) ...[
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body13,
              ),
            ),
          ] else
            const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

class DirectionAToday extends ConsumerWidget {
  const DirectionAToday({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayControllerProvider);
    final controller = ref.read(todayControllerProvider.notifier);
    final role = ref.watch(todayRoleProvider);
    final name = ref.watch(
      shellControllerProvider.select((s) => s.user.displayName),
    );
    final board = state.board;
    final now = DateTime.now();
    return ShellPageSurface(
      clipBehavior: Clip.antiAlias,
      child: board == null
          ? const Center(child: AppLoadingIndicator())
          : LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 900;
                final pad = wide ? AppSpace.s32 : AppSpace.s24;
                final focus = board.focus;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, AppSpace.s20, pad, AppSpace.s32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PageHead(
                        title: todayNavLabel(role),
                        caption: '${todayDateLabel(now)} · ${todayGreeting(now)}，$name',
                        actions: const [
                          DraftPlainButton(
                            label: '添加安排',
                            icon: Icons.add_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (focus != null) ...[
                                  _Focus(
                                    step: focus,
                                    reason: board.focusReason,
                                    onAct: focus.action == null
                                        ? () => controller.toggle(focus)
                                        : () => openTodayAction(
                                            context,
                                            ref,
                                            focus.action!,
                                          ),
                                  ),
                                  const SizedBox(height: AppSpace.s24),
                                  _rule,
                                  const SizedBox(height: AppSpace.s24),
                                ],
                                DraftChecklist(
                                  board: board,
                                  filter: state.filter,
                                  now: now,
                                  focusId: focus?.id ?? '',
                                  onFilter: controller.setFilter,
                                  onToggle: controller.toggle,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: wide ? 48 : AppSpace.s32),
                          SizedBox(width: wide ? 280 : 232, child: _Side(board: board)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// 下一步：全屏唯一带主按钮的地方。
class _Focus extends StatelessWidget {
  const _Focus({required this.step, required this.reason, required this.onAct});

  final TodayStep step;
  final String reason;
  final VoidCallback onAct;

  @override
  Widget build(BuildContext context) {
    final detail = reason.isNotEmpty ? reason : step.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DraftFocusLabel(step: step),
        const SizedBox(height: AppSpace.s8),
        Text(
          step.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.title24,
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s4),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        Row(
          children: [
            AppButton(
              label: step.action?.label.isNotEmpty == true
                  ? step.action!.label
                  : '标记完成',
              onTap: onAct,
            ),
            const SizedBox(width: AppSpace.s8),
            const DraftPlainButton(label: '怎么做'),
          ],
        ),
      ],
    );
  }
}

/// 右栏：进度、四个数、一张图。不用卡片，用细线隔开。
class _Side extends StatelessWidget {
  const _Side({required this.board});

  final TodayBoard board;

  @override
  Widget build(BuildContext context) {
    final summary = board.summary;
    final done = summary.total - summary.remaining;
    final week = board.charts.whereType<TodayColumnsChart>().firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('今日进度', style: AppText.caption12Strong),
        const SizedBox(height: AppSpace.s12),
        Row(
          children: [
            DraftRing(
              ratio: summary.total == 0 ? 0 : done / summary.total,
              size: 56,
              track: AppColors.line,
            ),
            const SizedBox(width: AppSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: '$done',
                      children: [
                        TextSpan(
                          text: ' / ${summary.total} 件',
                          style: AppText.number(
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    style: AppText.displayNumber(),
                  ),
                  if (summary.streakDays > 0)
                    Text(
                      '已${summary.streakLabel} ${summary.streakDays} 天',
                      style: AppText.caption12,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
        for (final item in board.highlights) ...[
          _rule,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label, style: AppText.body14),
                      if (item.caption.isNotEmpty)
                        Text(
                          item.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Text.rich(
                  TextSpan(
                    text: item.value,
                    children: [
                      TextSpan(text: ' ${item.unit}', style: AppText.caption12),
                    ],
                  ),
                  style: AppText.number(size: 20),
                ),
              ],
            ),
          ),
        ],
        if (week != null) ...[
          _rule,
          const SizedBox(height: AppSpace.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(week.title, style: AppText.body14)),
              if (week.headline != null)
                Text.rich(
                  TextSpan(
                    text: week.headline!.value,
                    children: [
                      TextSpan(
                        text: '${week.headline!.unit} ${week.headline!.label}',
                        style: AppText.caption12,
                      ),
                    ],
                  ),
                  style: AppText.number(size: 20),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          DraftBars(chart: week, height: 64),
        ],
      ],
    );
  }
}

class DirectionAEbooks extends ConsumerWidget {
  const DirectionAEbooks({super.key});

  static const _query = EbooksQuery();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ebooksControllerProvider(_query));
    final controller = ref.read(ebooksControllerProvider(_query).notifier);
    final lead = draftLeadBook(state.books, state.featured);
    final picks = [
      for (final book in state.featured)
        if (book.id != lead?.id) book,
    ];
    return ShellPageSurface(
      clipBehavior: Clip.antiAlias,
      child: state.books.isEmpty
          ? const Center(child: AppLoadingIndicator())
          : LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 900;
                final pad = wide ? AppSpace.s32 : AppSpace.s24;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, AppSpace.s20, pad, AppSpace.s32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PageHead(
                        title: '电子书刊',
                        middle: const [
                          SizedBox(width: AppSpace.s32),
                          DraftTextTab(label: '书库', selected: true),
                          SizedBox(width: AppSpace.s24),
                          DraftTextTab(label: '我的书架'),
                        ],
                        actions: [
                          SizedBox(
                            width: wide ? 260 : 220,
                            child: const AppSearchField(hint: '搜索书名、编者、知识点'),
                          ),
                          DraftPlainButton(
                            label: state.sort.label,
                            icon: Icons.swap_vert_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s12),
                      DraftCategories(
                        items: state.categories,
                        selected: state.category,
                        onSelect: controller.setCategory,
                      ),
                      if (!state.hasFilters && lead != null) ...[
                        const SizedBox(height: AppSpace.s24),
                        _LeadStrip(lead: lead, picks: picks, wide: wide),
                        const SizedBox(height: AppSpace.s24),
                        _rule,
                      ],
                      const SizedBox(height: AppSpace.s24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            state.hasFilters
                                ? state.categoryLabelOf(state.category)
                                : '全部书刊',
                            style: AppText.title16,
                          ),
                          const SizedBox(width: AppSpace.s8),
                          Text('共 ${state.total} 本', style: AppText.caption12),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s16),
                      DraftBookGrid(
                        books: state.books,
                        columns: wide ? 5 : 4,
                        gap: wide ? 28 : AppSpace.s24,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// 接着读的那一本放在最前面，旁边是另外两本编辑推荐。
class _LeadStrip extends StatelessWidget {
  const _LeadStrip({
    required this.lead,
    required this.picks,
    required this.wide,
  });

  final EbookSummary lead;
  final List<EbookSummary> picks;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: wide ? 5 : 3,
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: EbookCover(url: lead.coverUrl, radius: 6, bordered: true),
                ),
                const SizedBox(width: AppSpace.s16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.reading ? '接着读' : '编辑推荐',
                        style: AppText.caption12Strong,
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        lead.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title16,
                      ),
                      const SizedBox(height: AppSpace.s8),
                      if (lead.reading)
                        Wrap(
                          spacing: AppSpace.s8,
                          runSpacing: AppSpace.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 96,
                              child: AppProgressBar(
                                value: lead.progressFraction,
                                height: 4,
                              ),
                            ),
                            Text(
                              ebookProgressLabel(lead),
                              style: AppText.caption12,
                            ),
                          ],
                        )
                      else
                        Text(
                          lead.featuredIntro,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body13,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s16),
                AppButton(
                  label: ebookReadLabel(lead, withPage: false),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 49, thickness: 1, color: AppColors.lineSoft),
          Expanded(
            flex: wide ? 4 : 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('编辑推荐', style: AppText.caption12Strong),
                for (final book in picks.take(2)) ...[
                  const SizedBox(height: AppSpace.s8),
                  DraftPickRow(book: book),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
