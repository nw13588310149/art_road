import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import 'quick_sketch_session_page.dart';
import 'sketch_session_header.dart';

/// 练习回顾：左边是这一组画过的参考图（按原比例完整显示，用时和结果写在图下），
/// 右边四个数上下排开。
class SketchReview extends StatelessWidget {
  const SketchReview({
    required this.records,
    required this.total,
    required this.interval,
    required this.setLabel,
    required this.onRestart,
    required this.onClose,
    super.key,
  });

  final List<SketchRecord> records;
  final int total;
  final Duration interval;
  final String setLabel;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final totalTime = records.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + r.spent,
    );
    final completed = records
        .where((r) => r.outcome == SketchOutcome.completed)
        .length;
    final average = records.isEmpty
        ? Duration.zero
        : totalTime ~/ records.length;
    final stats = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStatRow(label: '按时完成', value: '$completed', unit: '/ $total 张'),
        const AppRule(),
        AppStatRow(label: '实际总用时', value: sketchDurationText(totalTime)),
        const AppRule(),
        AppStatRow(label: '平均每张', value: sketchDurationText(average)),
        const AppRule(),
        AppStatRow(
          label: '跳过 / 提前结束',
          value: '${records.length - completed}',
          unit: '张',
        ),
        const AppRule(),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SessionHeader(
          title: '练习回顾',
          caption: '$setLabel · 每张 ${sketchIntervalLabel(interval.inSeconds)}',
          actions: [
            AppPlainButton(
              label: '完成',
              icon: Icons.check_rounded,
              onTap: onClose,
            ),
            AppButton(
              label: '再练一组',
              icon: Icons.replay_rounded,
              onTap: onRestart,
            ),
          ],
        ),
        Expanded(
          child: AppPageBody(
            builder: (context, wide) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: records.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(top: AppSpace.s32),
                          child: AppEmptyState(
                            title: '这一组还没有开始画',
                            description: '点「再练一组」重新开始计时',
                            icon: Icons.timer_outlined,
                          ),
                        )
                      : AppTileGrid(
                          columns: wide ? 4 : 3,
                          gap: AppPageBody.tileGap(wide),
                          children: [
                            for (final (index, record) in records.indexed)
                              _RecordTile(index: index, record: record),
                          ],
                        ),
                ),
                SizedBox(width: AppPageBody.columnGap(wide)),
                SizedBox(width: AppPageBody.sideWidth(wide), child: stats),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.index, required this.record});

  final int index;
  final SketchRecord record;

  @override
  Widget build(BuildContext context) {
    final outcome = switch (record.outcome) {
      SketchOutcome.completed => '按时完成',
      SketchOutcome.skipped => '跳过',
      SketchOutcome.stopped => '提前结束',
    };
    return AppImageTile(
      image: AppImageTile.frame(
        aspectRatio: 3 / 4,
        child: ColoredBox(
          color: AppColors.canvas,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s8),
            child: Image.asset(
              record.asset,
              fit: BoxFit.contain,
              cacheWidth: 400,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
      title: '第 ${index + 1} 张',
      meta: '${sketchDurationText(record.spent)} · $outcome',
    );
  }
}
