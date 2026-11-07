import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/toolbox_catalog.dart';
import '../state/countdown_controller.dart';
import '../state/toolbox_image_controller.dart';
import 'tools/blur_tool.dart';
import 'tools/checklist_tool.dart';
import 'tools/color_picker_tool.dart';
import 'tools/countdown_tool.dart';
import 'tools/edges_tool.dart';
import 'tools/figure_tool.dart';
import 'tools/grid_tool.dart';
import 'tools/measure_tool.dart';
import 'tools/mirror_tool.dart';
import 'tools/perspective_tool.dart';
import 'tools/portrait_tool.dart';
import 'tools/quick_sketch_tool.dart';
import 'tools/score_tool.dart';
import 'tools/simplify_tool.dart';
import 'tools/temperature_tool.dart';
import 'tools/value_check_tool.dart';
import 'tools/value_order_tool.dart';
import 'widgets/image_tool_frame.dart';

/// 画室工具箱：看画分析、练习训练、备考助手三组共 17 个工具。
///
/// 路由参数（均可选）：`{'tool': String, 'imageUrl': String, 'title': String}`。
/// `tool` 接受 [ArtTool.tryParse] 能识别的 key、中文名或简称（如 `grid`、`明度`、`三庭五眼`），
/// 带 `tool` 时直接打开该工具，返回即关闭本页；`imageUrl` 会预先载入给图片类工具使用
/// （如范画库「临摹网格」），`title` 为图片名称。
class ArtToolboxPage extends ConsumerStatefulWidget {
  const ArtToolboxPage({super.key});

  @override
  ConsumerState<ArtToolboxPage> createState() => _ArtToolboxPageState();
}

class _ArtToolboxPageState extends ConsumerState<ArtToolboxPage> {
  ArtTool? _tool;
  ArtTool? _entryTool;
  ArtToolGroup _group = ArtToolGroup.analysis;
  bool _argsApplied = false;
  bool _imagePending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) {
      return;
    }
    _argsApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      return;
    }
    final tool = ArtTool.tryParse(args['tool']?.toString());
    _tool = tool;
    _entryTool = tool;
    _group = tool?.group ?? _group;
    final imageUrl = args['imageUrl']?.toString().trim() ?? '';
    final title = args['title']?.toString().trim() ?? '';
    if (imageUrl.isEmpty) {
      return;
    }
    _imagePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _imagePending = false);
      ref
          .read(toolboxImageControllerProvider.notifier)
          .loadUrl(imageUrl, label: title.isEmpty ? '范画' : title);
    });
  }

  void _open(ArtTool tool) => setState(() => _tool = tool);

  /// 由路由参数直达的工具，返回时关闭整页回到来源页。
  void _back() {
    final tool = _tool;
    if (tool != null && tool == _entryTool) {
      _entryTool = null;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
    }
    setState(() => _tool = null);
  }

  Widget _buildTool(ArtTool tool) => switch (tool) {
    ArtTool.value => ValueCheckTool(onBack: _back),
    ArtTool.blur => BlurTool(onBack: _back),
    ArtTool.simplify => SimplifyTool(onBack: _back),
    ArtTool.temperature => TemperatureTool(onBack: _back),
    ArtTool.edges => EdgesTool(onBack: _back),
    ArtTool.mirror => MirrorTool(onBack: _back),
    ArtTool.color => ColorPickerTool(onBack: _back),
    ArtTool.measure => MeasureTool(onBack: _back),
    ArtTool.grid => GridTool(onBack: _back),
    ArtTool.perspective => PerspectiveTool(onBack: _back),
    ArtTool.portrait => PortraitTool(onBack: _back),
    ArtTool.quickSketch => QuickSketchTool(onBack: _back),
    ArtTool.figure => FigureTool(onBack: _back),
    ArtTool.valueOrder => ValueOrderTool(onBack: _back),
    ArtTool.countdown => CountdownTool(onBack: _back),
    ArtTool.score => ScoreTool(onBack: _back),
    ArtTool.checklist => ChecklistTool(onBack: _back),
  };

  @override
  Widget build(BuildContext context) {
    // 监听同时让共享图片在整页生命周期内保持（换工具不丢图）。
    ref.listen<ToolboxImageState>(toolboxImageControllerProvider, (
      previous,
      next,
    ) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) {
        return;
      }
      AppToast.showError(context, msg);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(toolboxImageControllerProvider.notifier).clearError();
        }
      });
    });

    final tool = _tool;
    final canPop = Navigator.of(context).canPop();
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.br16,
        child: ToolboxImagePending(
          pending: _imagePending,
          child: KeyedSubtree(
            key: ValueKey<ArtTool?>(tool),
            child: tool == null
                ? _ToolboxHome(
                    group: _group,
                    onGroupChanged: (group) => setState(() => _group = group),
                    onOpen: _open,
                    onBack: canPop ? () => Navigator.of(context).pop() : null,
                  )
                : _buildTool(tool),
          ),
        ),
      ),
    );
  }
}

class _ToolboxHome extends ConsumerWidget {
  const _ToolboxHome({
    required this.group,
    required this.onGroupChanged,
    required this.onOpen,
    required this.onBack,
  });

  final ArtToolGroup group;
  final ValueChanged<ArtToolGroup> onGroupChanged;
  final ValueChanged<ArtTool> onOpen;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final next = ref.watch(countdownControllerProvider).nextUpcoming(now);
    String descriptionOf(ArtTool tool) {
      if (tool == ArtTool.countdown && next != null) {
        final days = next.daysLeftFrom(now);
        return days == 0 ? '今天 · ${next.name}' : '还有 $days 天 · ${next.name}';
      }
      return tool.description;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: '画室工具箱',
          subtitle: '离线可用 · 图片只在本机处理，不会上传',
          onBack: onBack,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s16,
            AppSpace.s16,
            0,
          ),
          actions: [
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                primary: false,
                child: AppSegmented<ArtToolGroup>(
                  segments: [
                    for (final category in ArtToolGroup.values)
                      AppSegment(value: category, label: category.label),
                  ],
                  value: group,
                  onChanged: onGroupChanged,
                  neutral: true,
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            key: PageStorageKey(group),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(group.description, style: AppText.body13),
                const SizedBox(height: AppSpace.s8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = AppSpace.s24;
                    final width = constraints.maxWidth;
                    final itemWidth = width >= 660 ? (width - gap) / 2 : width;
                    return Wrap(
                      spacing: gap,
                      children: [
                        for (final tool in group.tools)
                          SizedBox(
                            width: itemWidth,
                            child: _ToolRow(
                              tool: tool,
                              description: descriptionOf(tool),
                              onTap: () => onOpen(tool),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.tool,
    required this.description,
    required this.onTap,
  });

  final ArtTool tool;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
        ),
        child: Row(
          children: [
            Icon(tool.icon, color: tool.accent, size: 20),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.label, style: AppText.body14Strong),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body13,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
