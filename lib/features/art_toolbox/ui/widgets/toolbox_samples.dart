import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';

/// 示例画作网格：按 [columns] 列等宽排开，列距 16。
class SampleGrid extends StatelessWidget {
  const SampleGrid({
    required this.samples,
    required this.onTap,
    this.columns = 3,
    this.current,
    super.key,
  });

  final List<ToolboxSample> samples;
  final ValueChanged<ToolboxSample>? onTap;
  final int columns;

  /// 正在用的那一张，名称用深紫标出。
  final String? current;

  static const double gap = AppSpace.s16;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    return AppTileGrid(
      columns: columns,
      gap: gap,
      children: [
        for (final sample in samples)
          SampleThumb(
            sample: sample,
            current: sample.label == current,
            onTap: tap == null ? null : () => tap(sample),
          ),
      ],
    );
  }
}

/// 一张示例画作：方形画框里按原比例完整显示（中性灰底留白，不裁），名称在下面。
class SampleThumb extends StatelessWidget {
  const SampleThumb({
    required this.sample,
    required this.onTap,
    this.current = false,
    super.key,
  });

  final ToolboxSample sample;
  final VoidCallback? onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context) * 2)
            .round()
            .clamp(64, 800);
        return AppPressable(
          onTap: onTap,
          semanticLabel: current ? '${sample.label}，正在用' : sample.label,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppImageTile.frame(
                aspectRatio: 1,
                child: ColoredBox(
                  color: AppColors.canvas,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: Image.asset(
                      sample.asset,
                      fit: BoxFit.contain,
                      cacheWidth: decodeWidth,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: Text(
                  sample.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: current
                      ? AppText.caption12Strong.copyWith(
                          color: AppColors.brandDeep,
                        )
                      : AppText.caption12.copyWith(
                          color: AppColors.textSecondary,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 示例画作选择弹窗；返回选中的示例，取消返回 null。
Future<ToolboxSample?> showToolboxSamplePicker(
  BuildContext context, {
  String? current,
}) {
  return showAppDialog<ToolboxSample>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: '选择示例画作',
      width: AppSize.dialogWide,
      child: SampleGrid(
        samples: toolboxSamples,
        columns: 4,
        current: current,
        onTap: (sample) => Navigator.of(dialogContext).pop(sample),
      ),
    ),
  );
}
