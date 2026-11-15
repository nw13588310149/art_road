import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/today_models.dart';
import '../../state/today_board.dart';

/// 「今日日程」：按时间排的课程或值班，正在进行的一项高亮。
class TodayAgendaCard extends StatelessWidget {
  const TodayAgendaCard({
    required this.board,
    required this.onOpen,
    this.scheduleLabel,
    super.key,
  });

  final TodayBoard board;
  final ValueChanged<TodayTarget> onOpen;

  /// 标题右侧「课表」链接的文字；为空时不显示。
  final String? scheduleLabel;

  @override
  Widget build(BuildContext context) {
    final items = board.agenda;
    final hidden = board.agendaTotal - items.length;
    final link = scheduleLabel;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(
            title: board.agendaTitle,
            titleStyle: AppText.title16,
            subtitle: board.agendaTotal > 0
                ? '${board.agendaTotal} ${board.role == 'dormManager' ? '项' : '节'}'
                : null,
            trailing: link == null
                ? null
                : AppButton(
                    label: link,
                    variant: AppButtonVariant.text,
                    size: AppButtonSize.sm,
                    onTap: () => onOpen(const TodayScheduleTarget()),
                  ),
          ),
          const SizedBox(height: AppSpace.s8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    size: 24,
                    color: AppColors.textPlaceholder,
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text(board.agendaEmpty, style: AppText.body13),
                ],
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              _AgendaRow(
                item: items[i],
                first: i == 0,
                last: i == items.length - 1,
                onTap: () => onOpen(items[i].target),
              ),
          if (hidden > 0) ...[
            const SizedBox(height: AppSpace.s8),
            AppPressable(
              onTap: () => onOpen(const TodayScheduleTarget()),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '还有 $hidden 节，查看全部课表',
                    style: AppText.body13.copyWith(color: AppColors.brand),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.item,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final TodayAgendaItem item;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ended = item.phase == TodayCoursePhase.ended;
    final active = item.phase == TodayCoursePhase.inProgress;
    final Widget? status;
    if (item.note.isNotEmpty) {
      status = AppTag(label: item.note, tone: AppTone.warning);
    } else if (active) {
      status = const AppTag(label: '进行中', tone: AppTone.brand);
    } else if (ended) {
      status = Text('已结束', style: AppText.caption12);
    } else {
      status = null;
    }
    return AppPressable(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.time,
                      style: AppText.number(
                        size: 14,
                        color: ended ? AppColors.textTertiary : AppColors.ink,
                      ),
                    ),
                    if (item.endTime.isNotEmpty)
                      Text(
                        item.endTime,
                        style: AppText.number(
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _Rail(active: active, ended: ended, first: first, last: last),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.brandWash : AppColors.surfaceSubtle,
                  borderRadius: AppRadius.br12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body14Strong.copyWith(
                                    color: ended
                                        ? AppColors.textSecondary
                                        : AppColors.ink,
                                  ),
                                ),
                              ),
                              if (item.tag.isNotEmpty) ...[
                                const SizedBox(width: AppSpace.s4),
                                Text(item.tag, style: AppText.caption12),
                              ],
                            ],
                          ),
                          if (item.subtitle.isNotEmpty)
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption12,
                            ),
                        ],
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: AppSpace.s8),
                      status,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 时间轴：一条竖线串起当天的日程，圆点标出每一项的状态。
class _Rail extends StatelessWidget {
  const _Rail({
    required this.active,
    required this.ended,
    required this.first,
    required this.last,
  });

  final bool active;
  final bool ended;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    const line = AppColors.line;
    return SizedBox(
      width: 12,
      child: Column(
        children: [
          Container(
            width: 1,
            height: 14,
            color: first ? Colors.transparent : line,
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.brand
                  : (ended ? AppColors.line : AppColors.surface),
              border: active || ended
                  ? null
                  : Border.all(color: AppColors.textTertiary, width: 1.5),
            ),
          ),
          Expanded(
            child: Container(width: 1, color: last ? Colors.transparent : line),
          ),
        ],
      ),
    );
  }
}
