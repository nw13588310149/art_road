import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/today_models.dart';
import '../today_style.dart';

/// 页面顶部的头图：问候、今天的进度环，以及下一步该做什么。
///
/// 品牌紫渐变底上只放三样东西——左边一句话说清今天还剩多少，中间一个进度环，
/// 右边一张白卡片写着现在最该做的那件事和一个直达的按钮。
class TodayHero extends StatelessWidget {
  const TodayHero({
    required this.board,
    required this.greeting,
    required this.dateLabel,
    required this.refreshing,
    required this.onRefresh,
    required this.onAct,
    required this.onShow,
    super.key,
  });

  final TodayBoard board;
  final String greeting;
  final String dateLabel;
  final bool refreshing;
  final VoidCallback onRefresh;

  /// 去做下一步。
  final ValueChanged<TodayStep> onAct;

  /// 看下一步怎么做。
  final ValueChanged<TodayStep> onShow;

  @override
  Widget build(BuildContext context) {
    final summary = board.summary;
    final String line;
    if (summary.total == 0) {
      line = '今天没有安排，可以给自己加几件事。';
    } else if (summary.allDone) {
      line = '今天的 ${summary.total} 件事都完成了。';
    } else {
      line =
          '今天共 ${summary.total} 件事，已完成 ${summary.done} 件，'
          '还有 ${summary.remaining} 件没做。';
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: TodayPalette.heroGradient,
        borderRadius: AppRadius.br16,
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: ExcludeSemantics(child: CustomPaint(painter: _HeroGlow())),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s20),
            child: LayoutBuilder(
              builder: (context, box) {
                final narrow = box.maxWidth < 780;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Semantics(
                        container: true,
                        label: board.title,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                _Pill(
                                  icon: Icons.calendar_today_outlined,
                                  label: dateLabel,
                                ),
                                const SizedBox(width: AppSpace.s8),
                                _GlassIconButton(
                                  icon: Icons.refresh_rounded,
                                  label: '刷新今日内容',
                                  enabled: !refreshing,
                                  onTap: onRefresh,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.s12),
                            Text(
                              greeting,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title24.copyWith(
                                color: AppColors.onBrand,
                              ),
                            ),
                            const SizedBox(height: AppSpace.s4),
                            Text(
                              line,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body14.copyWith(
                                color: AppColors.onBrand.withValues(
                                  alpha: 0.86,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpace.s12),
                            Wrap(
                              spacing: AppSpace.s8,
                              runSpacing: AppSpace.s8,
                              children: [
                                if (summary.streakDays > 0)
                                  _Pill(
                                    icon: Icons.local_fire_department_outlined,
                                    label:
                                        '已${summary.streakLabel} ${summary.streakDays} 天',
                                  ),
                                if (summary.overdue > 0)
                                  _Pill(
                                    icon: Icons.error_outline_rounded,
                                    label: '${summary.overdue} 件已超时',
                                    alert: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s16),
                    _ProgressRing(summary: summary, size: narrow ? 104 : 120),
                    SizedBox(width: narrow ? AppSpace.s16 : AppSpace.s24),
                    SizedBox(
                      width: narrow ? 264 : 316,
                      child: _NextStep(
                        step: board.focus,
                        reason: board.focusReason,
                        allDone: summary.allDone,
                        onAct: onAct,
                        onShow: onShow,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 头图上的两团柔光，让渐变不发平。
class _HeroGlow extends CustomPainter {
  const _HeroGlow();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..color = const Color(0x1AFFFFFF);
    canvas.drawCircle(Offset(size.width * 0.46, -size.height * 0.2), 150, glow);
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 1.25),
      120,
      Paint()..color = const Color(0x14FFFFFF),
    );
    canvas.drawCircle(
      Offset(size.width * 0.98, size.height * 1.1),
      170,
      Paint()..color = const Color(0x12FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 渐变底上的半透明胶囊：日期、连续天数、超时提醒。
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.alert = false});

  final IconData icon;
  final String label;

  /// 提醒：白底红字，从紫色底上跳出来。
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppColors.danger : AppColors.onBrand;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: alert ? AppColors.surface : const Color(0x29FFFFFF),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption12Strong.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: AppPressable(
        enabled: enabled,
        semanticLabel: label,
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0x29FFFFFF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.onBrand),
        ),
      ),
    );
  }
}

/// 进度环：完成了几成。环是一条带同色浅底的进度，中间写百分比和件数。
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.summary, required this.size});

  final TodaySummary summary;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ratio = summary.total == 0 ? 0.0 : summary.done / summary.total;
    return Semantics(
      container: true,
      label:
          '今日进度，已完成 ${summary.done} 件，共 ${summary.total} 件，'
          '完成 ${(ratio * 100).round()}%',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(ratio),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '今日进度',
                  style: AppText.caption12.copyWith(
                    color: AppColors.onBrand.withValues(alpha: 0.8),
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${summary.done}',
                        style: AppText.displayNumber(
                          size: 32,
                          color: AppColors.onBrand,
                        ),
                      ),
                      TextSpan(
                        text: ' / ${summary.total}',
                        style: AppText.number(
                          size: 14,
                          color: AppColors.onBrand.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.ratio);

  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0x38FFFFFF);
    canvas.drawCircle(center, radius, track);
    if (ratio <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.onBrand;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ratio.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

/// 「下一步」：浮在渐变底上的一张白卡片，只写一件事。
class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.step,
    required this.reason,
    required this.allDone,
    required this.onAct,
    required this.onShow,
  });

  final TodayStep? step;
  final String reason;
  final bool allDone;
  final ValueChanged<TodayStep> onAct;
  final ValueChanged<TodayStep> onShow;

  @override
  Widget build(BuildContext context) {
    final current = step;
    final overdue = current?.status == TodayStepStatus.overdue;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br16,
        boxShadow: [
          BoxShadow(
            color: Color(0x33251A8C),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: current == null
          ? Row(
              children: [
                TodayIconChip(
                  icon: allDone
                      ? Icons.check_rounded
                      : Icons.event_available_outlined,
                  tint: TodayTint.teal,
                  size: 44,
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        allDone ? '今天的安排都完成了' : '今天没有需要处理的事',
                        style: AppText.title16,
                      ),
                      const SizedBox(height: 2),
                      Text('可以休息一下，或者提前看看明天的安排。', style: AppText.body13),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AppTag(
                      label: overdue ? '先做这件' : '下一步',
                      tone: overdue ? AppTone.danger : AppTone.brand,
                    ),
                    const Spacer(),
                    if (current.timeRange.isNotEmpty)
                      Text(
                        current.timeRange,
                        style: AppText.number(
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.s12),
                Row(
                  children: [
                    TodayIconChip(
                      icon: todayStepIcon(current.kind),
                      tint: todayStepTint(current.kind),
                      size: 44,
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            current.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title16,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reason,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body13.copyWith(
                              color: overdue ? AppColors.danger : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: current.action?.label ?? '打勾',
                        size: AppButtonSize.sm,
                        expand: true,
                        onTap: () => onAct(current),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    AppButton(
                      label: '怎么做',
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.secondary,
                      onTap: () => onShow(current),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
