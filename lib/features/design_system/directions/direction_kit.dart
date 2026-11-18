// 新页面方向稿共用的小部件。
//
// 临时代码：三个方向各做了今日和电子书刊的首屏，供选定方向用。选定之后，
// 留用的部分整理进 lib/core/ui，这个目录整体删除。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../ebooks/data/ebook_models.dart';
import '../../ebooks/ui/widgets/ebook_widgets.dart';
import '../../today/data/today_models.dart';
import '../../today/state/today_controller.dart';

String draftClock(DateTime now) =>
    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

/// 进度环：一圈底色加一段弧，中间放数字。
class DraftRing extends StatelessWidget {
  const DraftRing({
    required this.ratio,
    required this.size,
    this.stroke = 6,
    this.color = AppColors.brand,
    this.track = AppColors.surfaceSubtle,
    this.child,
    super.key,
  });

  final double ratio;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          ratio: ratio.clamp(0.0, 1.0),
          stroke: stroke,
          color: color,
          track: track,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ratio,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double ratio;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    if (ratio > 0) {
      canvas.drawArc(
        arc,
        -math.pi / 2,
        math.pi * 2 * ratio,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.color != color || old.track != track;
}

/// 一件事左边的状态。要本人打勾的是圆圈，跟着业务数据自动完成的是小圆点，
/// 一眼能分出哪些可以点。
class DraftStepMark extends StatelessWidget {
  const DraftStepMark({required this.step, this.onToggle, super.key});

  final TodayStep step;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final status = step.status;
    final Widget mark;
    if (status == TodayStepStatus.done) {
      mark = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 14,
          color: AppColors.onBrand,
        ),
      );
    } else if (!step.manual) {
      mark = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: status == TodayStepStatus.overdue
              ? AppColors.danger
              : status == TodayStepStatus.doing
              ? AppColors.brand
              : AppColors.textPlaceholder,
          shape: BoxShape.circle,
        ),
      );
    } else {
      mark = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            width: 1.5,
            color: status == TodayStepStatus.overdue
                ? AppColors.danger
                : AppColors.textPlaceholder,
          ),
        ),
      );
    }
    final box = SizedBox(width: 44, height: 44, child: Center(child: mark));
    if (onToggle == null || !step.manual) return box;
    return AppPressable(
      onTap: onToggle,
      semanticLabel: step.done ? '取消打勾' : '打勾',
      child: box,
    );
  }
}

/// 清单里的一行：时间、状态、标题和说明。整行可点，行里没有按钮。
class DraftStepRow extends StatelessWidget {
  const DraftStepRow({required this.step, this.onToggle, super.key});

  final TodayStep step;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final closed = !step.status.open;
    final overdue = step.status == TodayStepStatus.overdue;
    final note = step.tag.isNotEmpty ? step.tag : (overdue ? '已超时' : '');
    final noteColor = switch (step.tagTone) {
      'danger' => AppColors.danger,
      'warning' => AppColors.warning,
      _ => overdue ? AppColors.danger : AppColors.textTertiary,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.time.isNotEmpty)
                  Text(
                    step.time,
                    style: AppText.number(
                      size: 13,
                      color: overdue
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                if (step.endTime.isNotEmpty)
                  Text(
                    step.endTime,
                    style: AppText.number(
                      size: 12,
                      color: AppColors.textPlaceholder,
                    ),
                  ),
              ],
            ),
          ),
          DraftStepMark(step: step, onToggle: onToggle),
          const SizedBox(width: AppSpace.s4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14Strong.copyWith(
                      color: closed ? AppColors.textTertiary : AppColors.ink,
                    ),
                  ),
                  if (step.detail.isNotEmpty)
                    Text(
                      step.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                ],
              ),
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(width: AppSpace.s12),
            Text(note, style: AppText.caption12.copyWith(color: noteColor)),
          ],
          const SizedBox(width: AppSpace.s4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textPlaceholder,
          ),
        ],
      ),
    );
  }
}

/// 「现在」线：一条细线加当前时间，插在已经过去和还没到的事之间。
class DraftNowLine extends StatelessWidget {
  const DraftNowLine({required this.now, super.key});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              draftClock(now),
              style: AppText.number(size: 12, color: AppColors.brandDeep),
            ),
          ),
          const SizedBox(
            width: 44,
            child: Center(
              child: SizedBox(
                width: 6,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1, color: AppColors.brandTint)),
          const SizedBox(width: AppSpace.s8),
          Text(
            '现在',
            style: AppText.caption12.copyWith(color: AppColors.brandDeep),
          ),
        ],
      ),
    );
  }
}

/// 今日清单：筛选、分组和每一行。[focusId] 那件事已经在页面上方单独展示，
/// 这里不再重复。
class DraftChecklist extends StatelessWidget {
  const DraftChecklist({
    required this.board,
    required this.filter,
    required this.now,
    required this.onFilter,
    required this.onToggle,
    this.focusId = '',
    super.key,
  });

  final TodayBoard board;
  final TodayFilter filter;
  final DateTime now;
  final ValueChanged<TodayFilter> onFilter;
  final ValueChanged<TodayStep> onToggle;
  final String focusId;

  @override
  Widget build(BuildContext context) {
    final summary = board.summary;
    final counts = {
      TodayFilter.all: summary.total,
      TodayFilter.open: summary.remaining,
      TodayFilter.done: summary.total - summary.remaining,
    };
    final clock = draftClock(now);
    // 「现在」线放在第一件还没到时间的事前面；那件事是分组里的第一件时，
    // 线画在分组标题上面，仍然落在上一个时段的末尾。
    String? nextId;
    for (final step in board.steps) {
      if (step.id != focusId &&
          filter.accepts(step) &&
          step.time.isNotEmpty &&
          step.status.open &&
          step.time.compareTo(clock) > 0) {
        nextId = step.id;
        break;
      }
    }
    final groups = <Widget>[];
    for (final group in board.groups) {
      final steps = [
        for (final step in group.steps)
          if (step.id != focusId && filter.accepts(step)) step,
      ];
      if (steps.isEmpty) continue;
      final done = group.steps.where((s) => !s.status.open).length;
      if (groups.isNotEmpty && steps.first.id == nextId) {
        groups.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s8),
            child: DraftNowLine(now: now),
          ),
        );
      }
      groups.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s20, bottom: AppSpace.s4),
          child: Row(
            children: [
              Text(
                group.title,
                style: AppText.caption12Strong.copyWith(color: AppColors.ink),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  group.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12,
                ),
              ),
              Text(
                '$done / ${group.steps.length}',
                style: AppText.number(size: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      );
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i];
        if (i > 0 && step.id == nextId) {
          groups.add(DraftNowLine(now: now));
        }
        groups.add(
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: i == 0 || step.id == nextId
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.lineSoft),
              ),
            ),
            child: DraftStepRow(step: step, onToggle: () => onToggle(step)),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('今日清单', style: AppText.title16),
            const SizedBox(width: AppSpace.s20),
            for (final item in TodayFilter.values)
              AppPressable(
                onTap: () => onFilter(item),
                selected: item == filter,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(right: AppSpace.s16),
                  child: Text.rich(
                    TextSpan(
                      text: '${item.label} ',
                      children: [
                        TextSpan(
                          text: '${counts[item]}',
                          style: AppText.number(
                            size: 13,
                            color: item == filter
                                ? AppColors.ink
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    style: item == filter
                        ? AppText.body14Strong
                        : AppText.body14.copyWith(
                            color: AppColors.textTertiary,
                          ),
                  ),
                ),
              ),
          ],
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s32),
            child: Text(
              filter == TodayFilter.done ? '今天还没有做完的事' : '这里没有别的事了',
              style: AppText.body13,
            ),
          )
        else
          ...groups,
      ],
    );
  }
}

/// 近几天的小柱状图：浅色的底是计划量，实心的是完成量，今天那根用品牌色。
class DraftBars extends StatelessWidget {
  const DraftBars({
    required this.chart,
    this.height = 72,
    this.fill = const Color(0xFFC7CAD3),
    this.track = AppColors.surfaceSubtle,
    this.accent = AppColors.brand,
    this.labelColor = AppColors.textTertiary,
    super.key,
  });

  final TodayColumnsChart chart;
  final double height;
  final Color fill;
  final Color track;
  final Color accent;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final peak = chart.items.fold<double>(
      1,
      (peak, item) => math.max(peak, math.max(item.total ?? 0, item.value ?? 0)),
    );
    return Semantics(
      label: chart.table.join('；'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final item in chart.items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: height,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          FractionallySizedBox(
                            heightFactor: ((item.total ?? item.value ?? 0) / peak)
                                .clamp(0.04, 1.0),
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: track,
                                borderRadius: AppRadius.br4,
                              ),
                            ),
                          ),
                          if ((item.value ?? 0) > 0)
                            FractionallySizedBox(
                              heightFactor: (item.value! / peak).clamp(0.04, 1.0),
                              widthFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: item.emphasis ? accent : fill,
                                  borderRadius: AppRadius.br4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: item.emphasis
                          ? AppText.caption12Strong.copyWith(color: AppColors.ink)
                          : AppText.caption12.copyWith(color: labelColor),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 封面下面那一行：读过的写进度，没读过的写阶段和页数。
String draftBookMeta(EbookSummary book) {
  if (book.started) return ebookProgressLabel(book);
  return [
    if (book.stage.isNotEmpty) book.stage,
    '${book.pageCount} 页',
    if (book.favorite) '已在书架',
  ].join(' · ');
}

/// 一本书：封面完整显示，上面不压任何标签；书名给两行，不截断。
class DraftBookTile extends StatelessWidget {
  const DraftBookTile({required this.book, this.onDark = false, super.key});

  final EbookSummary book;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EbookCover(url: book.coverUrl, radius: 6, bordered: true),
        const SizedBox(height: AppSpace.s12),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.body14Strong,
        ),
        const SizedBox(height: 2),
        Text(
          draftBookMeta(book),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption12.copyWith(
            color: book.reading ? AppColors.brandDeep : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// 封面网格：按可用宽度排 [columns] 列，每格等宽，高度随内容。
class DraftBookGrid extends StatelessWidget {
  const DraftBookGrid({
    required this.books,
    required this.columns,
    required this.gap,
    this.tileBuilder,
    super.key,
  });

  final List<EbookSummary> books;
  final int columns;
  final double gap;
  final Widget Function(EbookSummary book)? tileBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = ((box.maxWidth - gap * (columns - 1)) / columns)
            .floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final book in books)
              SizedBox(
                width: width,
                child: tileBuilder?.call(book) ?? DraftBookTile(book: book),
              ),
          ],
        );
      },
    );
  }
}

/// 次要操作：墨色文字，不用品牌紫，把紫色留给主按钮。
class DraftPlainButton extends StatelessWidget {
  const DraftPlainButton({
    required this.label,
    this.icon,
    this.onTap,
    this.color = AppColors.ink,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap ?? () {},
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpace.s4),
            ],
            Text(label, style: AppText.body14Strong.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// 「下一步」上面那一行小字：标签和时间。超时的时候时间用红色，不再另写「已超时」，
/// 因为下面的说明已经讲了。
class DraftFocusLabel extends StatelessWidget {
  const DraftFocusLabel({
    required this.step,
    this.labelColor = AppColors.textSecondary,
    this.timeColor = AppColors.textTertiary,
    this.overdueColor = AppColors.danger,
    super.key,
  });

  final TodayStep step;
  final Color labelColor;
  final Color timeColor;
  final Color overdueColor;

  @override
  Widget build(BuildContext context) {
    final overdue = step.status == TodayStepStatus.overdue;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '下一步',
          style: AppText.caption12Strong.copyWith(color: labelColor),
        ),
        if (step.time.isNotEmpty) ...[
          const SizedBox(width: AppSpace.s8),
          Text(
            step.timeRange,
            style: AppText.number(
              size: 12,
              color: overdue ? overdueColor : timeColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// 编辑推荐里的一本：小封面、完整的书名、一行推荐语。
class DraftPickRow extends StatelessWidget {
  const DraftPickRow({
    required this.book,
    this.titleColor = AppColors.ink,
    this.introColor = AppColors.textTertiary,
    this.bordered = true,
    super.key,
  });

  final EbookSummary book;
  final Color titleColor;
  final Color introColor;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 33,
          child: EbookCover(url: book.coverUrl, radius: 3, bordered: bordered),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body14Strong.copyWith(color: titleColor),
              ),
              Text(
                book.featuredIntro.isNotEmpty ? book.featuredIntro : book.intro,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12.copyWith(color: introColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 视图切换：文字加一条下划线。
class DraftTextTab extends StatelessWidget {
  const DraftTextTab({required this.label, this.selected = false, super.key});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: selected ? AppColors.ink : const Color(0x00000000),
          ),
        ),
      ),
      child: Text(
        label,
        style: selected
            ? AppText.title16
            : AppText.body16.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

/// 分类筛选：一行文字，选中的那个垫一块底色。
class DraftCategories extends StatelessWidget {
  const DraftCategories({
    required this.items,
    required this.selected,
    required this.onSelect,
    this.idle,
    this.active = AppColors.surfaceSubtle,
    this.activeText = AppColors.ink,
    super.key,
  });

  final List<EbookCategory> items;
  final String selected;
  final ValueChanged<String> onSelect;

  /// 没选中时的底色；为空表示不垫底。
  final Color? idle;
  final Color active;
  final Color activeText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            // 看得见的是 36 高的胶囊，能点的范围是 44 高。
            AppPressable(
              onTap: () => onSelect(item.key),
              selected: item.key == selected,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                padding: EdgeInsets.only(
                  right: idle == null ? AppSpace.s4 : AppSpace.s8,
                ),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.key == selected ? active : idle,
                    borderRadius: AppRadius.brPill,
                  ),
                  child: Text(
                    item.label,
                    style: item.key == selected
                        ? AppText.body14Strong.copyWith(color: activeText)
                        : AppText.body14.copyWith(
                            color: AppColors.textSecondary,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 没有读到一半的书时，主推第一本编辑推荐。
EbookSummary? draftLeadBook(List<EbookSummary> books, List<EbookSummary> featured) {
  for (final book in books) {
    if (book.reading) return book;
  }
  return featured.isNotEmpty
      ? featured.first
      : (books.isNotEmpty ? books.first : null);
}
