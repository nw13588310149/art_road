// 方向二「栅格」：浅色页面底上放白色模块，和首页是同一种底子。
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
import '../../today/data/today_models.dart';
import '../../today/state/today_controller.dart';
import '../../today/ui/today_actions.dart';
import '../../today/ui/today_page.dart';
import 'direction_kit.dart';

const double _gap = AppSpace.s16;

/// 白色模块：圆角 16，没有描边和阴影，直接放在页面底色上。
class _Module extends StatelessWidget {
  const _Module({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.s20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br16,
      ),
      child: child,
    );
  }
}

/// 页头：直接写在页面底色上。
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
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: AppSpace.s4),
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

class DirectionBToday extends ConsumerWidget {
  const DirectionBToday({super.key});

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
    if (board == null) return const Center(child: AppLoadingIndicator());
    final focus = board.focus;
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth >= 900 ? 300.0 : 248.0;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageHead(
                title: todayNavLabel(role),
                caption: '${todayDateLabel(now)} · ${todayGreeting(now)}，$name',
                actions: [
                  AppButton(
                    label: '添加安排',
                    icon: Icons.add_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: _gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Module(
                        child: focus == null
                            ? Align(
                                alignment: Alignment.centerLeft,
                                child: Text('今天的安排都完成了', style: AppText.title20),
                              )
                            : _Focus(
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
                      ),
                    ),
                    const SizedBox(width: _gap),
                    SizedBox(
                      width: side,
                      child: _Module(child: _Progress(summary: board.summary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Module(
                      child: DraftChecklist(
                        board: board,
                        filter: state.filter,
                        now: now,
                        focusId: focus?.id ?? '',
                        onFilter: controller.setFilter,
                        onToggle: controller.toggle,
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  SizedBox(
                    width: side,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (board.highlights.isNotEmpty)
                          _Module(
                            padding: EdgeInsets.zero,
                            child: _Stats(items: board.highlights),
                          ),
                        for (final chart
                            in board.charts.whereType<TodayColumnsChart>().take(
                              1,
                            )) ...[
                          const SizedBox(height: _gap),
                          _Module(child: _Week(chart: chart)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _gap),
            ],
          ),
        );
      },
    );
  }
}

class _Focus extends StatelessWidget {
  const _Focus({required this.step, required this.reason, required this.onAct});

  final TodayStep step;
  final String reason;
  final VoidCallback onAct;

  @override
  Widget build(BuildContext context) {
    final detail = reason.isNotEmpty ? reason : step.detail;
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DraftFocusLabel(step: step),
              const SizedBox(height: AppSpace.s8),
              Text(
                step.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title20,
              ),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s4),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body13,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s16),
        const DraftPlainButton(label: '怎么做'),
        const SizedBox(width: AppSpace.s8),
        AppButton(
          label: step.action?.label.isNotEmpty == true
              ? step.action!.label
              : '标记完成',
          onTap: onAct,
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.summary});

  final TodaySummary summary;

  @override
  Widget build(BuildContext context) {
    final done = summary.total - summary.remaining;
    return Row(
      children: [
        DraftRing(
          ratio: summary.total == 0 ? 0 : done / summary.total,
          size: 64,
          stroke: 7,
        ),
        const SizedBox(width: AppSpace.s16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日进度', style: AppText.caption12Strong),
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
    );
  }
}

/// 四个数排成两行两列，用细线隔开，不带图标。
class _Stats extends StatelessWidget {
  const _Stats({required this.items});

  final List<TodayHighlight> items;

  @override
  Widget build(BuildContext context) {
    Widget cell(TodayHighlight item) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption12Strong,
            ),
            const SizedBox(height: AppSpace.s4),
            Text.rich(
              TextSpan(
                text: item.value,
                children: [
                  TextSpan(text: ' ${item.unit}', style: AppText.caption12),
                ],
              ),
              style: AppText.number(size: 24),
            ),
            if (item.caption.isNotEmpty)
              Text(
                item.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12,
              ),
          ],
        ),
      ),
    );
    const vertical = VerticalDivider(
      width: 1,
      thickness: 1,
      color: AppColors.lineSoft,
    );
    return Column(
      children: [
        for (var row = 0; row * 2 < items.length; row++) ...[
          if (row > 0)
            const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cell(items[row * 2]),
                vertical,
                if (row * 2 + 1 < items.length)
                  cell(items[row * 2 + 1])
                else
                  const Spacer(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.chart});

  final TodayColumnsChart chart;

  @override
  Widget build(BuildContext context) {
    final headline = chart.headline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(chart.title, style: AppText.body14Strong)),
            if (headline != null)
              Text.rich(
                TextSpan(
                  text: headline.value,
                  children: [
                    TextSpan(
                      text: '${headline.unit} ${headline.label}',
                      style: AppText.caption12,
                    ),
                  ],
                ),
                style: AppText.number(size: 20),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s16),
        DraftBars(chart: chart, height: 64),
      ],
    );
  }
}

class DirectionBEbooks extends ConsumerWidget {
  const DirectionBEbooks({super.key});

  static const _query = EbooksQuery();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ebooksControllerProvider(_query));
    final controller = ref.read(ebooksControllerProvider(_query).notifier);
    if (state.books.isEmpty) return const Center(child: AppLoadingIndicator());
    final lead = draftLeadBook(state.books, state.featured);
    final picks = [
      for (final book in state.featured)
        if (book.id != lead?.id) book,
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageHead(
                title: '电子书刊',
                middle: const [
                  SizedBox(width: AppSpace.s20),
                  _Segments(labels: ['书库', '我的书架']),
                ],
                actions: [
                  SizedBox(
                    width: wide ? 260 : 200,
                    child: const AppSearchField(hint: '搜索书名、编者、知识点'),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  AppButton(
                    label: state.sort.label,
                    icon: Icons.swap_vert_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: _gap),
              DraftCategories(
                items: state.categories,
                selected: state.category,
                onSelect: controller.setCategory,
                idle: AppColors.surface,
                active: AppColors.navSelection,
                activeText: AppColors.onBrand,
              ),
              if (!state.hasFilters && lead != null) ...[
                const SizedBox(height: _gap),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: wide ? 5 : 3,
                        child: _Module(child: _Lead(book: lead)),
                      ),
                      const SizedBox(width: _gap),
                      Expanded(
                        flex: wide ? 4 : 2,
                        child: _Module(child: _Picks(books: picks)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s20),
              Padding(
                padding: const EdgeInsets.only(left: AppSpace.s4),
                child: Row(
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
              ),
              const SizedBox(height: AppSpace.s12),
              DraftBookGrid(
                books: state.books,
                columns: wide ? 5 : 4,
                gap: _gap,
                tileBuilder: (book) => _Module(
                  padding: const EdgeInsets.all(AppSpace.s12),
                  child: DraftBookTile(book: book),
                ),
              ),
              const SizedBox(height: _gap),
            ],
          ),
        );
      },
    );
  }
}

/// 视图切换：白色轨道，选中项用导航同款的深色。
class _Segments extends StatelessWidget {
  const _Segments({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, label) in labels.indexed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index == 0 ? AppColors.navSelection : null,
                borderRadius: AppRadius.br8,
              ),
              child: Text(
                label,
                style: index == 0
                    ? AppText.body14Strong.copyWith(color: AppColors.onBrand)
                    : AppText.body14.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _Lead extends StatelessWidget {
  const _Lead({required this.book});

  final EbookSummary book;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: EbookCover(url: book.coverUrl, radius: 6, bordered: true),
        ),
        const SizedBox(width: AppSpace.s16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.reading ? '接着读' : '编辑推荐',
                style: AppText.caption12Strong,
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.title16,
              ),
              const SizedBox(height: AppSpace.s8),
              if (book.reading) ...[
                AppProgressBar(value: book.progressFraction, height: 4),
                const SizedBox(height: AppSpace.s4),
                Text(ebookProgressLabel(book), style: AppText.caption12),
              ] else
                Text(
                  book.featuredIntro,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body13,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s16),
        AppButton(label: ebookReadLabel(book, withPage: false), onTap: () {}),
      ],
    );
  }
}

class _Picks extends StatelessWidget {
  const _Picks({required this.books});

  final List<EbookSummary> books;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('编辑推荐', style: AppText.caption12Strong),
        for (final book in books.take(2)) ...[
          const SizedBox(height: AppSpace.s8),
          DraftPickRow(book: book),
        ],
      ],
    );
  }
}
