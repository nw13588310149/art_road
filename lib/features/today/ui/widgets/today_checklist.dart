import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/today_models.dart';
import '../../state/today_controller.dart';
import '../today_style.dart';

/// 今日清单：一条从早到晚的时间线，做完一件勾一件。
///
/// 左边是时间，中间一条线串起每件事的状态（圆圈：没做；紫点：进行中；绿勾：做完；
/// 红叹号：超时），右边是这件事的卡片和直达按钮。当前时段里有一条「现在」的线，
/// 一眼看出哪些已经过去、接下来是哪件。整行点开看「怎么做」。
class TodayChecklist extends StatelessWidget {
  const TodayChecklist({
    required this.board,
    required this.filter,
    required this.busy,
    required this.now,
    required this.onFilter,
    required this.onAdd,
    required this.onToggle,
    required this.onAct,
    required this.onShow,
    required this.onDismissTip,
    super.key,
  });

  final TodayBoard board;
  final TodayFilter filter;
  final Set<String> busy;
  final DateTime now;
  final ValueChanged<TodayFilter> onFilter;
  final VoidCallback onAdd;

  /// 点时间线上的圆圈：打勾或取消。
  final ValueChanged<TodayStep> onToggle;

  /// 点右边的按钮：去做这件事。
  final ValueChanged<TodayStep> onAct;

  /// 点整行：看详情和怎么做。
  final ValueChanged<TodayStep> onShow;
  final VoidCallback onDismissTip;

  @override
  Widget build(BuildContext context) {
    final all = board.steps.toList();
    int count(TodayFilter f) => all.where(f.accepts).length;
    final groups = [
      for (final group in board.groups)
        if (group.steps.any(filter.accepts)) group,
    ];
    final currentSlot = now.hour < 12
        ? 'morning'
        : (now.hour < 18 ? 'afternoon' : 'evening');
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final segmented = AppSegmented<TodayFilter>(
                size: AppControlSize.sm,
                expand: box.maxWidth < 520,
                value: filter,
                onChanged: onFilter,
                segments: [
                  for (final item in TodayFilter.values)
                    AppSegment(
                      value: item,
                      label: '${item.label} ${count(item)}',
                    ),
                ],
              );
              final add = AppButton(
                label: '添加安排',
                icon: Icons.add_rounded,
                size: AppButtonSize.sm,
                variant: AppButtonVariant.quiet,
                onTap: onAdd,
              );
              // 窄屏时筛选单独占一行，不和标题、按钮挤在一起。
              if (box.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('今日清单', style: AppText.title16)),
                        add,
                      ],
                    ),
                    const SizedBox(height: AppSpace.s8),
                    segmented,
                  ],
                );
              }
              return Row(
                children: [
                  Text('今日清单', style: AppText.title16),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: segmented,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  add,
                ],
              );
            },
          ),
          if (!board.tipSeen) ...[
            const SizedBox(height: AppSpace.s12),
            _Tip(onDismiss: onDismissTip),
          ],
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
              child: AppEmptyState(
                icon: filter == TodayFilter.open
                    ? Icons.check_circle_outline_rounded
                    : Icons.inbox_outlined,
                title: switch (filter) {
                  TodayFilter.open => '没有未完成的事了',
                  TodayFilter.done => '还没有做完的事',
                  TodayFilter.all => '今天没有安排',
                },
                description: switch (filter) {
                  TodayFilter.open => '今天的安排都做完了。',
                  TodayFilter.done => '做完一件，这里就多一件。',
                  TodayFilter.all => '可以点「添加安排」给自己安排几件事。',
                },
              ),
            )
          else
            for (final group in groups)
              _Group(
                group: group,
                filter: filter,
                focusId: board.focusStepId,
                busy: busy,
                // 「现在」只画在当前时段里，筛选已完成时不画。
                now: group.id == currentSlot && filter != TodayFilter.done
                    ? now
                    : null,
                onToggle: onToggle,
                onAct: onAct,
                onShow: onShow,
              ),
        ],
      ),
    );
  }
}

/// 第一次来时的用法提示，看过就不再出现。
class _Tip extends StatelessWidget {
  const _Tip({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: const BoxDecoration(
        color: AppColors.brandWash,
        borderRadius: AppRadius.br12,
      ),
      child: Row(
        children: [
          const TodayIconChip(
            icon: Icons.lightbulb_outline_rounded,
            tint: TodayTint.purple,
            size: 32,
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Text(
              '从上往下做，做完一件点一下时间线上的圆圈打勾。'
              '标着「建议」的可以按自己的时间来，点开任意一行看怎么做。',
              style: AppText.body13.copyWith(color: AppColors.ink),
            ),
          ),
          AppButton(
            label: '知道了',
            variant: AppButtonVariant.text,
            size: AppButtonSize.sm,
            onTap: onDismiss,
          ),
        ],
      ),
    );
  }
}

const double _timeWidth = 44;
const double _railWidth = 34;

({IconData icon, TodayTint tint}) _groupBadge(String id) => switch (id) {
  'urgent' => (icon: Icons.priority_high_rounded, tint: TodayTint.pink),
  'morning' => (icon: Icons.wb_twilight_rounded, tint: TodayTint.amber),
  'afternoon' => (icon: Icons.wb_sunny_outlined, tint: TodayTint.amber),
  'evening' => (icon: Icons.nightlight_outlined, tint: TodayTint.purple),
  _ => (icon: Icons.all_inclusive_rounded, tint: TodayTint.teal),
};

int? _minutes(String clock) {
  final parts = clock.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  return hour == null || minute == null ? null : hour * 60 + minute;
}

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.filter,
    required this.focusId,
    required this.busy,
    required this.now,
    required this.onToggle,
    required this.onAct,
    required this.onShow,
  });

  final TodayGroup group;
  final TodayFilter filter;
  final String focusId;
  final Set<String> busy;

  /// 不为空时在这一组里画出「现在」的位置。
  final DateTime? now;
  final ValueChanged<TodayStep> onToggle;
  final ValueChanged<TodayStep> onAct;
  final ValueChanged<TodayStep> onShow;

  @override
  Widget build(BuildContext context) {
    final steps = group.steps.where(filter.accepts).toList();
    final counted = [
      for (final step in group.steps)
        if (step.status != TodayStepStatus.skipped) step,
    ];
    final done = counted.where((step) => step.done).length;
    final badge = _groupBadge(group.id);
    final current = now;
    // 「现在」排在第一件还没到点的事前面；都过了点就排在最后。
    var nowIndex = -1;
    if (current != null) {
      final minutes = current.hour * 60 + current.minute;
      nowIndex = steps.indexWhere((step) {
        final start = _minutes(step.time);
        return start != null && start > minutes;
      });
      if (nowIndex < 0) nowIndex = steps.length;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpace.s16,
            bottom: AppSpace.s4,
          ),
          child: Row(
            children: [
              TodayIconChip(icon: badge.icon, tint: badge.tint, size: 24),
              const SizedBox(width: AppSpace.s8),
              Text(group.title, style: AppText.body14Strong),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  group.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12,
                ),
              ),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  '$done / ${counted.length}',
                  style: AppText.number(
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < steps.length; i++) ...[
          if (i == nowIndex && current != null) _NowLine(now: current),
          _StepRow(
            step: steps[i],
            focus: steps[i].id == focusId,
            busy: busy.contains(steps[i].id),
            first: i == 0,
            last: i == steps.length - 1,
            onToggle: () => onToggle(steps[i]),
            onAct: () => onAct(steps[i]),
            onShow: () => onShow(steps[i]),
          ),
        ],
        if (nowIndex == steps.length && current != null && steps.isNotEmpty)
          _NowLine(now: current),
      ],
    );
  }
}

/// 时间线上的「现在」。
class _NowLine extends StatelessWidget {
  const _NowLine({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Semantics(
      container: true,
      label: '现在 $clock',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 20,
          child: Row(
            children: [
              SizedBox(
                width: _timeWidth,
                child: Text(
                  clock,
                  style: AppText.number(size: 12, color: AppColors.brand),
                ),
              ),
              SizedBox(
                width: _railWidth,
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(height: 1.5, color: AppColors.brandTint),
              ),
              const SizedBox(width: AppSpace.s8),
              Text(
                '现在',
                style: AppText.caption12Strong.copyWith(color: AppColors.brand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.focus,
    required this.busy,
    required this.first,
    required this.last,
    required this.onToggle,
    required this.onAct,
    required this.onShow,
  });

  final TodayStep step;
  final bool focus;
  final bool busy;
  final bool first;
  final bool last;
  final VoidCallback onToggle;
  final VoidCallback onAct;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final closed = !step.status.open;
    final overdue = step.status == TodayStepStatus.overdue;
    final progress = step.progress;
    final action = step.action;
    final detail = [
      step.detail,
      if (step.minutes > 0 && !closed) '约 ${step.minutes} 分钟',
    ].where((t) => t.isNotEmpty).join(' · ');

    final Widget? trailing;
    if (step.status == TodayStepStatus.skipped) {
      trailing = Text('今天不做', style: AppText.caption12);
    } else if (closed) {
      trailing = action == null
          ? null
          : AppButton(
              label: action.label,
              size: AppButtonSize.sm,
              variant: AppButtonVariant.text,
              onTap: onAct,
            );
    } else {
      trailing = AppButton(
        label: action?.label ?? '打勾',
        size: AppButtonSize.sm,
        variant: focus ? AppButtonVariant.primary : AppButtonVariant.secondary,
        enabled: !busy,
        onTap: action == null ? onToggle : onAct,
      );
    }

    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: focus
            ? (overdue ? AppColors.dangerSoft : AppColors.brandWash)
            : (closed ? AppColors.surface : AppColors.surfaceSubtle),
        borderRadius: AppRadius.br12,
        // 做完的事不描边、不铺底，退到后面去；没做的铺一层浅灰。
        border: Border.all(
          color: focus
              ? (overdue ? AppColors.danger : AppColors.brand).withValues(
                  alpha: 0.45,
                )
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          TodayIconChip(
            icon: todayStepIcon(step.kind),
            tint: todayStepTint(step.kind),
            size: 36,
            muted: closed,
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            // 这一行的文字已经写进整行的无障碍标签里，这里不再重复念一遍。
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          step.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: closed
                              ? AppText.body14.copyWith(
                                  color: AppColors.textSecondary,
                                )
                              : AppText.body14Strong,
                        ),
                      ),
                      if (focus && !overdue) ...[
                        const SizedBox(width: AppSpace.s8),
                        const AppTag(label: '下一步', tone: AppTone.brand),
                      ],
                      if (step.tag.isNotEmpty && !closed) ...[
                        const SizedBox(width: AppSpace.s8),
                        AppTag(
                          label: step.tag,
                          tone: TodayPalette.tagTone(step.tagTone),
                        ),
                      ] else if (!step.required && !closed && !focus) ...[
                        const SizedBox(width: AppSpace.s8),
                        const AppTag(label: '建议'),
                      ],
                    ],
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AppProgressBar(
                            value: progress.ratio,
                            height: 6,
                            color: overdue
                                ? TodayPalette.bad
                                : TodayPalette.brand,
                            trackColor: AppColors.surface,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s8),
                        Text(
                          '${progress.done} / ${progress.total} ${progress.unit}',
                          style: AppText.number(
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpace.s12),
            trailing,
          ],
        ],
      ),
    );

    return Stack(
      children: [
        // 时间线：一条竖线贯穿这一行，第一行不往上画，最后一行不往下画。
        if (!(first && last))
          Positioned(
            left: _timeWidth + _railWidth / 2 - 1,
            top: first ? 28 : 0,
            bottom: last ? null : 0,
            height: last ? 28 : null,
            child: Container(width: 2, color: AppColors.lineSoft),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _timeWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.time,
                      style: AppText.number(
                        size: 13,
                        color: closed ? AppColors.textTertiary : AppColors.ink,
                      ),
                    ),
                    if (step.endTime.isNotEmpty)
                      Text(
                        step.endTime,
                        style: AppText.number(
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _railWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 11),
                child: TodayStatusMark(
                  step: step,
                  enabled: !busy,
                  onTap: onToggle,
                ),
              ),
            ),
            Expanded(
              child: AppPressable(
                onTap: onShow,
                semanticLabel: [
                  step.status.label,
                  if (step.time.isNotEmpty) step.timeRange,
                  step.title,
                  if (focus && !overdue) '下一步',
                  if (!step.required && step.status.open) '建议',
                  detail,
                  step.tag,
                  if (progress != null)
                    '已完成 ${progress.done} ${progress.unit}，'
                        '共 ${progress.total} ${progress.unit}',
                ].where((t) => t.isNotEmpty).join('，'),
                child: card,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 时间线上的状态标记。需要本人确认的事点它打勾，其余的只表示状态。
class TodayStatusMark extends StatelessWidget {
  const TodayStatusMark({
    required this.step,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final TodayStep step;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Widget mark = switch (step.status) {
      TodayStepStatus.done => const _Mark(
        fill: TodayPalette.good,
        icon: Icons.check_rounded,
        iconColor: AppColors.onBrand,
      ),
      TodayStepStatus.doing => const _Mark(
        border: TodayPalette.brand,
        dot: TodayPalette.brand,
      ),
      TodayStepStatus.overdue => const _Mark(
        border: TodayPalette.bad,
        icon: Icons.priority_high_rounded,
        iconColor: TodayPalette.bad,
      ),
      TodayStepStatus.skipped => const _Mark(
        fill: AppColors.surfaceSubtle,
        icon: Icons.remove_rounded,
        iconColor: AppColors.textTertiary,
      ),
      TodayStepStatus.todo => _Mark(
        border: step.manual ? AppColors.textTertiary : AppColors.line,
      ),
    };
    final padded = Padding(
      padding: const EdgeInsets.all(6),
      child: Center(child: mark),
    );
    if (!step.manual || step.status == TodayStepStatus.skipped) {
      return ExcludeSemantics(child: padded);
    }
    return AppPressable(
      enabled: enabled,
      semanticLabel: step.done ? '取消打勾：${step.title}' : '打勾：${step.title}',
      onTap: onTap,
      child: padded,
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({this.fill, this.border, this.icon, this.iconColor, this.dot});

  final Color? fill;
  final Color? border;
  final IconData? icon;
  final Color? iconColor;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    final center = dot;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 白底把后面的时间线盖住。
        color: fill ?? AppColors.surface,
        border: border == null ? null : Border.all(color: border!, width: 1.5),
      ),
      child: glyph != null
          ? Icon(glyph, size: 14, color: iconColor)
          : (center == null
                ? null
                : Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: center,
                      shape: BoxShape.circle,
                    ),
                  )),
    );
  }
}
