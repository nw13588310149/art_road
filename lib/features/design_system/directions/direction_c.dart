// 方向三「主视觉」：每页开头一条深色主视觉带，放这一页最重要的一件事；
// 下面是白色底板。临时代码，见 direction_kit.dart 开头的说明。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../ebooks/data/ebook_models.dart';
import '../../ebooks/state/ebooks_controller.dart';
import '../../ebooks/state/ebooks_state.dart';
import '../../ebooks/ui/widgets/ebook_widgets.dart';
import '../../shell/state/shell_state.dart';
import '../../shell/ui/shell_layout.dart';
import '../../today/data/today_models.dart';
import '../../today/state/today_controller.dart';
import '../../today/ui/today_actions.dart';
import '../../today/ui/today_page.dart';
import 'direction_kit.dart';

/// 主视觉带的底色：和左导航选中项同一种深色。
const _ink = AppColors.navSelection;

Color _onInk(double alpha) => AppColors.onBrand.withValues(alpha: alpha);

class _Band extends StatelessWidget {
  const _Band({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s32,
        vertical: AppSpace.s24,
      ),
      decoration: const BoxDecoration(color: _ink, borderRadius: AppRadius.br16),
      child: child,
    );
  }
}

/// 深色底上的次要按钮。
class _Ghost extends StatelessWidget {
  const _Ghost({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: () {},
      child: Container(
        height: AppSize.buttonMd,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _onInk(0.12),
          borderRadius: AppRadius.br12,
        ),
        child: Text(
          label,
          style: AppText.body16.copyWith(color: AppColors.onBrand),
        ),
      ),
    );
  }
}

class DirectionCToday extends ConsumerWidget {
  const DirectionCToday({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayControllerProvider);
    final controller = ref.read(todayControllerProvider.notifier);
    final role = ref.watch(todayRoleProvider);
    final board = state.board;
    final now = DateTime.now();
    if (board == null) return const Center(child: AppLoadingIndicator());
    final focus = board.focus;
    final week = board.charts.whereType<TodayColumnsChart>().firstOrNull;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final pad = wide ? AppSpace.s32 : AppSpace.s24;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Band(
              height: 224,
              child: Row(
                children: [
                  Expanded(
                    child: _Focus(
                      heading: '${todayNavLabel(role)} · ${todayDateLabel(now)}',
                      step: focus,
                      reason: board.focusReason,
                      onAct: focus == null
                          ? null
                          : focus.action == null
                          ? () => controller.toggle(focus)
                          : () => openTodayAction(context, ref, focus.action!),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s32),
                  SizedBox(
                    width: wide ? 320 : 264,
                    child: _BandSide(board: board),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s16),
            Expanded(
              child: ShellPageSurface(
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, AppSpace.s24, pad, AppSpace.s32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DraftChecklist(
                          board: board,
                          filter: state.filter,
                          now: now,
                          focusId: focus?.id ?? '',
                          onFilter: controller.setFilter,
                          onToggle: controller.toggle,
                        ),
                      ),
                      if (week != null) ...[
                        SizedBox(width: wide ? 48 : AppSpace.s32),
                        SizedBox(
                          width: wide ? 272 : 224,
                          child: _Week(chart: week),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Focus extends StatelessWidget {
  const _Focus({
    required this.heading,
    required this.step,
    required this.reason,
    required this.onAct,
  });

  final String heading;
  final TodayStep? step;
  final String reason;
  final VoidCallback? onAct;

  @override
  Widget build(BuildContext context) {
    final step = this.step;
    final head = Text(
      heading,
      style: AppText.caption12.copyWith(color: _onInk(0.6)),
    );
    if (step == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          const SizedBox(height: AppSpace.s12),
          Text(
            '今天的安排都完成了',
            style: AppText.display32.copyWith(color: AppColors.onBrand),
          ),
        ],
      );
    }
    final detail = reason.isNotEmpty ? reason : step.detail;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        const SizedBox(height: AppSpace.s12),
        DraftFocusLabel(
          step: step,
          labelColor: _onInk(0.85),
          timeColor: _onInk(0.6),
          overdueColor: const Color(0xFFFF9EA3),
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          step.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.display32.copyWith(color: AppColors.onBrand),
        ),
        if (detail.isNotEmpty)
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14.copyWith(color: _onInk(0.7)),
          ),
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
            const _Ghost(label: '怎么做'),
          ],
        ),
      ],
    );
  }
}

/// 主视觉带右侧：进度环和四个数。
class _BandSide extends StatelessWidget {
  const _BandSide({required this.board});

  final TodayBoard board;

  @override
  Widget build(BuildContext context) {
    final summary = board.summary;
    final done = summary.total - summary.remaining;
    final items = board.highlights;
    Widget cell(TodayHighlight item) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: item.value,
              children: [
                TextSpan(
                  text: ' ${item.unit}',
                  style: AppText.caption12.copyWith(color: _onInk(0.6)),
                ),
              ],
            ),
            style: AppText.number(size: 20, color: AppColors.onBrand),
          ),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption12.copyWith(color: _onInk(0.6)),
          ),
        ],
      ),
    );
    return Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DraftRing(
              ratio: summary.total == 0 ? 0 : done / summary.total,
              size: 88,
              stroke: 8,
              color: AppColors.brandSoft,
              track: _onInk(0.14),
              child: Text.rich(
                TextSpan(
                  text: '$done',
                  children: [
                    TextSpan(
                      text: ' / ${summary.total}',
                      style: AppText.number(size: 12, color: _onInk(0.6)),
                    ),
                  ],
                ),
                style: AppText.displayNumber(
                  size: 24,
                  color: AppColors.onBrand,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              '今日进度',
              style: AppText.caption12.copyWith(color: _onInk(0.6)),
            ),
          ],
        ),
        const SizedBox(width: AppSpace.s24),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var row = 0; row * 2 < items.length; row++) ...[
                if (row > 0) const SizedBox(height: AppSpace.s16),
                Row(
                  children: [
                    cell(items[row * 2]),
                    const SizedBox(width: AppSpace.s12),
                    if (row * 2 + 1 < items.length)
                      cell(items[row * 2 + 1])
                    else
                      const Spacer(),
                  ],
                ),
              ],
            ],
          ),
        ),
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
        Text(chart.title, style: AppText.title16),
        if (headline != null) ...[
          const SizedBox(height: AppSpace.s8),
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
            style: AppText.displayNumber(),
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        DraftBars(chart: chart),
        if (chart.subtitle.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          Text(chart.subtitle, style: AppText.caption12),
        ],
      ],
    );
  }
}

class DirectionCEbooks extends ConsumerWidget {
  const DirectionCEbooks({super.key});

  static const _query = EbooksQuery();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ebooksControllerProvider(_query));
    final controller = ref.read(ebooksControllerProvider(_query).notifier);
    if (state.books.isEmpty) return const Center(child: AppLoadingIndicator());
    final lead = draftLeadBook(state.books, state.featured)!;
    final picks = [
      for (final book in state.featured)
        if (book.id != lead.id) book,
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final pad = wide ? AppSpace.s32 : AppSpace.s24;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Band(
              height: 224,
              child: Row(
                children: [
                  SizedBox(
                    width: 132,
                    child: EbookCover(url: lead.coverUrl, radius: 6),
                  ),
                  const SizedBox(width: AppSpace.s24),
                  Expanded(child: _Lead(book: lead, wide: wide)),
                  const SizedBox(width: AppSpace.s32),
                  SizedBox(
                    width: wide ? 300 : 232,
                    child: _Picks(books: picks, wide: wide),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s16),
            Expanded(
              child: ShellPageSurface(
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, AppSpace.s12, pad, AppSpace.s32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            const DraftTextTab(label: '书库', selected: true),
                            const SizedBox(width: AppSpace.s24),
                            const DraftTextTab(label: '我的书架'),
                            const Spacer(),
                            SizedBox(
                              width: wide ? 260 : 220,
                              child: const AppSearchField(
                                hint: '搜索书名、编者、知识点',
                              ),
                            ),
                            DraftPlainButton(
                              label: state.sort.label,
                              icon: Icons.swap_vert_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.s12),
                      DraftCategories(
                        items: state.categories,
                        selected: state.category,
                        onSelect: controller.setCategory,
                      ),
                      const SizedBox(height: AppSpace.s20),
                      DraftBookGrid(
                        books: state.books,
                        columns: wide ? 5 : 4,
                        gap: wide ? 28 : AppSpace.s24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Lead extends StatelessWidget {
  const _Lead({required this.book, required this.wide});

  final EbookSummary book;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '电子书刊 · ${book.reading ? '接着读' : '编辑推荐'}',
          style: AppText.caption12.copyWith(color: _onInk(0.6)),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: (wide ? AppText.title24 : AppText.title20).copyWith(
            color: AppColors.onBrand,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        if (book.reading)
          Row(
            children: [
              SizedBox(
                width: 120,
                child: AppProgressBar(
                  value: book.progressFraction,
                  height: 4,
                  color: AppColors.onBrand,
                  trackColor: _onInk(0.2),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Text(
                ebookProgressLabel(book),
                style: AppText.caption12.copyWith(color: _onInk(0.7)),
              ),
            ],
          )
        else
          Text(
            book.featuredIntro,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14.copyWith(color: _onInk(0.7)),
          ),
        const SizedBox(height: AppSpace.s12),
        Row(
          children: [
            AppButton(
              label: ebookReadLabel(book, withPage: false),
              onTap: () {},
            ),
            const SizedBox(width: AppSpace.s8),
            const _Ghost(label: '查看详情'),
          ],
        ),
      ],
    );
  }
}

class _Picks extends StatelessWidget {
  const _Picks({required this.books, required this.wide});

  final List<EbookSummary> books;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '编辑推荐',
          style: AppText.caption12Strong.copyWith(color: _onInk(0.6)),
        ),
        for (final book in books.take(2)) ...[
          const SizedBox(height: AppSpace.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: EbookCover(url: book.coverUrl, radius: 4),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: wide ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong.copyWith(
                        color: AppColors.onBrand,
                      ),
                    ),
                    Text(
                      book.featuredIntro.isNotEmpty
                          ? book.featuredIntro
                          : book.intro,
                      maxLines: wide ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12.copyWith(color: _onInk(0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
