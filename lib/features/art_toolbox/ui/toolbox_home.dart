import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/toolbox_catalog.dart';
import '../data/toolbox_image_source.dart';
import '../state/countdown_controller.dart';
import '../state/toolbox_image_controller.dart';
import 'widgets/tool_panel.dart';
import 'widgets/toolbox_samples.dart';

/// 画室工具箱的首页（设计语言第二节的两栏）：主栏是三组工具，每个工具一行，
/// 整行可点；侧栏是看画分析各工具共用的当前画作和示例画作。
class ToolboxHome extends StatelessWidget {
  const ToolboxHome({
    required this.onOpen,
    required this.onBack,
    this.showTitle = true,
    super.key,
  });

  final ValueChanged<ArtTool> onOpen;
  final VoidCallback? onBack;

  /// 全局工作台自己有「画室工具箱」的页头，这里不再重复。
  final bool showTitle;

  /// 主栏窄于这个宽度时工具排成一列。
  static const double _twoColumnWidth = 460;

  @override
  Widget build(BuildContext context) {
    return AppPageBody(
      builder: (context, wide) => LayoutBuilder(
        builder: (context, box) {
          final side = AppPageBody.sideWidth(wide);
          final gap = AppPageBody.columnGap(wide);
          final stacked = box.maxWidth - side - gap < _twoColumnWidth;
          final tools = _ToolSections(
            onOpen: onOpen,
            columnGap: wide ? AppSpace.s32 : AppSpace.s24,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTitle) ...[
                AppTitleBar(title: '画室工具箱', onBack: onBack),
                const SizedBox(height: AppSpace.s24),
              ],
              if (stacked) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: const _PaintingColumn(),
                ),
                const SizedBox(height: AppSpace.s32),
                tools,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tools),
                    SizedBox(width: gap),
                    SizedBox(width: side, child: const _PaintingColumn()),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 三组工具：分区标题写组名和一句用途，下面每个工具一行，两列排开。
class _ToolSections extends ConsumerWidget {
  const _ToolSections({required this.onOpen, required this.columnGap});

  final ValueChanged<ArtTool> onOpen;
  final double columnGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final next = ref.watch(countdownControllerProvider).nextUpcoming(now);
    final days = next?.daysLeftFrom(now);
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= ToolboxHome._twoColumnWidth ? 2 : 1;
        Widget rowOf(ArtTool tool) => tool == ArtTool.countdown && next != null
            ? _ToolRow(
                tool: tool,
                description: next.name,
                trailing: _DaysLeft(days: days!),
                onTap: () => onOpen(tool),
              )
            : _ToolRow(
                tool: tool,
                description: tool.description,
                onTap: () => onOpen(tool),
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, group) in ArtToolGroup.values.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpace.s32),
              AppSectionTitle(title: group.label, note: group.description),
              const SizedBox(height: AppSpace.s4),
              // 同一行的两格一样高，行线连成一条。
              for (var i = 0; i < group.tools.length; i += columns)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < columns; c++) ...[
                        if (c > 0) SizedBox(width: columnGap),
                        Expanded(
                          child: i + c < group.tools.length
                              ? rowOf(group.tools[i + c])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// 一个工具：图标、名称和一句用途，右边可有一个短标注，行尾浅灰箭头。整行可点，
/// 至少 64 高，行与行之间一条细线。
class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.tool,
    required this.description,
    required this.onTap,
    this.trailing,
  });

  final ArtTool tool;
  final String description;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: '${tool.label}，$description',
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
        ),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 36,
                child: Icon(
                  toolIconOf(tool),
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tool.label, style: AppText.body14Strong),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body13,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.s8),
                trailing!,
              ],
              const SizedBox(width: AppSpace.s4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textPlaceholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 下一场考试还有几天：首页里唯一会变的数，用数字字体写在行尾。
class _DaysLeft extends StatelessWidget {
  const _DaysLeft({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    if (days == 0) {
      return Text('今天', style: AppText.body14Strong);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$days', style: AppText.number(size: 20)),
          TextSpan(text: ' 天', style: AppText.caption12),
        ],
      ),
    );
  }
}

/// 首页工具行的图标：统一用线性的一套（目录里的图标给随页工具栏用，保持不动）。
IconData toolIconOf(ArtTool tool) => switch (tool) {
  ArtTool.value => Icons.contrast_outlined,
  ArtTool.blur => Icons.blur_on_outlined,
  ArtTool.simplify => Icons.palette_outlined,
  ArtTool.temperature => Icons.thermostat_outlined,
  ArtTool.edges => Icons.gesture_outlined,
  ArtTool.mirror => Icons.flip_outlined,
  ArtTool.color => Icons.colorize_outlined,
  ArtTool.measure => Icons.straighten_outlined,
  ArtTool.grid => Icons.grid_4x4_outlined,
  ArtTool.perspective => Icons.view_in_ar_outlined,
  ArtTool.portrait => Icons.face_outlined,
  ArtTool.quickSketch => Icons.timer_outlined,
  ArtTool.figure => Icons.accessibility_new_outlined,
  ArtTool.valueOrder => Icons.gradient_outlined,
  ArtTool.countdown => Icons.event_available_outlined,
  ArtTool.score => Icons.calculate_outlined,
  ArtTool.checklist => Icons.checklist_outlined,
};

/// 侧栏：当前画作（看画分析的工具共用）和示例画作。点一张示例就换成它。
class _PaintingColumn extends ConsumerWidget {
  const _PaintingColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolboxImageControllerProvider);
    final controller = ref.read(toolboxImageControllerProvider.notifier);
    final image = state.image;
    final count = ArtToolGroup.analysis.tools.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionTitle(title: '当前画作'),
        const SizedBox(height: AppSpace.s12),
        if (image != null) ...[
          _CurrentPainting(image: image),
          const SizedBox(height: AppSpace.s12),
          Text(image.label, style: AppText.body14Strong),
          Text('看画分析的 $count 个工具共用这张画，图片只在本机处理。', style: AppText.caption12),
        ] else if (state.loading)
          AppImageTile.frame(
            aspectRatio: 4 / 3,
            child: const ColoredBox(
              color: AppColors.canvas,
              child: Center(child: AppLoadingIndicator(size: 32)),
            ),
          )
        else
          Text(
            '先选一张画。看画分析的 $count 个工具共用它，上传自己的作品，或点下面的示例。图片只在本机处理。',
            style: AppText.body13,
          ),
        ToolInlineAction(
          label: '上传图片',
          icon: Icons.upload_rounded,
          onTap: state.loading ? null : controller.pickFromAlbum,
        ),
        const SizedBox(height: AppSpace.s16),
        const AppSectionTitle(title: '示例画作'),
        const SizedBox(height: AppSpace.s12),
        SampleGrid(
          samples: toolboxSamples,
          current: image?.label,
          onTap: state.loading ? null : controller.loadSample,
        ),
      ],
    );
  }
}

/// 当前画作：按原比例完整显示，最高 240，四周是中性灰的画框底。
class _CurrentPainting extends StatelessWidget {
  const _CurrentPainting({required this.image});

  final ToolboxImage image;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final height = math.min(240.0, box.maxWidth / image.aspectRatio);
        return AppImageTile.frame(
          child: ColoredBox(
            color: AppColors.canvas,
            child: SizedBox(
              width: box.maxWidth,
              height: height,
              child: RawImage(
                image: image.image,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        );
      },
    );
  }
}
