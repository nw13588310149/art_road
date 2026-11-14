import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../gallery/ui/widgets/library_controls.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/toolbox_catalog.dart';
import '../data/toolbox_image_source.dart';
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
/// 首页取原版工具类页面的写法：白色内容板内左上是分组页签（距板边 18，页签下 18
/// 起内容），页签下是工具卡片网格，卡片取原版练习页的关卡卡片（三列、100 高、
/// 浅灰底圆角 12、左侧 60×80 封面）；看画分析一组在网格上方多一块选图卡，用来
/// 选定各工具共用的画作。
///
/// 路由参数（均可选）：`{'tool': String, 'imageUrl': String, 'title': String, 'returnToSource': bool}`。
/// `tool` 接受 [ArtTool.tryParse] 能识别的 key、中文名或简称（如 `grid`、`明度`、`三庭五眼`），
/// 带 `tool` 时直接打开该工具，返回即关闭本页；`imageUrl` 会预先载入给图片类工具使用
/// （如范画库「临摹网格」），`title` 为图片名称。
class ArtToolboxPage extends ConsumerStatefulWidget {
  const ArtToolboxPage({
    this.embedded = false,
    this.initialTool,
    this.onToolChanged,
    super.key,
  });

  /// 全局工作台直接占满画布，普通路由仍使用原有页面容器。
  final bool embedded;
  final ArtTool? initialTool;
  final ValueChanged<ArtTool?>? onToolChanged;

  @override
  ConsumerState<ArtToolboxPage> createState() => _ArtToolboxPageState();
}

class _ArtToolboxPageState extends ConsumerState<ArtToolboxPage> {
  ArtTool? _tool;
  bool _directEntry = false;
  bool _returnToSource = false;
  ArtToolGroup _group = ArtToolGroup.analysis;
  bool _argsApplied = false;
  bool _imagePending = false;

  @override
  void initState() {
    super.initState();
    _tool = widget.initialTool;
    _group = _tool?.group ?? _group;
  }

  @override
  void didUpdateWidget(covariant ArtToolboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTool != oldWidget.initialTool) {
      _tool = widget.initialTool;
      _group = _tool?.group ?? _group;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) {
      return;
    }
    _argsApplied = true;
    if (widget.embedded) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      return;
    }
    final tool = ArtTool.tryParse(args['tool']?.toString());
    _tool = tool;
    _directEntry = tool != null;
    _returnToSource = args['returnToSource'] == true;
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

  void _open(ArtTool tool) {
    setState(() => _tool = tool);
    widget.onToolChanged?.call(tool);
  }

  /// 由路由参数直达的工具，返回时关闭整页回到来源页。
  void _back() {
    if (_directEntry) {
      _directEntry = false;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
    }
    setState(() => _tool = null);
    widget.onToolChanged?.call(null);
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
    final content = ToolboxWorkspaceScope(
      pending: _imagePending,
      onSwitchTool: _open,
      child: KeyedSubtree(
        key: ValueKey<ArtTool?>(tool),
        child: tool == null
            ? _ToolboxHome(
                group: _group,
                onGroupChanged: (group) => setState(() => _group = group),
                onOpen: _open,
                onBack: _returnToSource && canPop
                    ? () => Navigator.of(context).pop()
                    : null,
              )
            : _buildTool(tool),
      ),
    );
    if (widget.embedded) {
      // 全局工作台没有外壳的白色内容板，这里补上同样的白底圆角板。
      return ClipRRect(
        borderRadius: AppRadius.br16,
        child: ColoredBox(color: AppColors.surface, child: content),
      );
    }
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(borderRadius: AppRadius.br16, child: content),
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

  /// 页签距内容板左上 18，页签下 18 起内容，内容左右 18、下 16（原版工具页）。
  static const double _inset = 18;

  static String _gridTitle(ArtToolGroup group) => switch (group) {
    ArtToolGroup.analysis => '分析工具',
    ArtToolGroup.practice => '训练工具',
    ArtToolGroup.exam => '备考工具',
  };

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

    final tools = group.tools;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_inset, _inset, _inset, 0),
          child: Row(
            children: [
              if (onBack != null) ...[
                LibraryIconButton.back(onTap: onBack),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  child: LibrarySegmented<ArtToolGroup>(
                    items: [
                      for (final category in ArtToolGroup.values)
                        LibraryOption(value: category, label: category.label),
                    ],
                    value: group,
                    onChanged: onGroupChanged,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  group.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: libraryText(
                    size: 12,
                    weight: AppFont.w500,
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _inset),
        Expanded(
          child: SingleChildScrollView(
            key: PageStorageKey(group),
            padding: const EdgeInsets.fromLTRB(_inset, 0, _inset, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (group == ArtToolGroup.analysis) ...[
                  const _WorkspaceCard(),
                  const SizedBox(height: 20),
                ],
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 10),
                  child: LibraryGroupTitle(
                    _gridTitle(group),
                    count: tools.length,
                    unit: '个',
                  ),
                ),
                _ToolGrid(
                  tools: tools,
                  descriptionOf: descriptionOf,
                  onOpen: onOpen,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 看画分析的选图卡：选定各工具共用的画作。外形取原版工具页页签下的信息卡
/// （140 高、浅灰底、圆角 12、内距 16）。没选图时可以直接点常用示例；选好后显示
/// 这张画和它的名称，随时可以换一张。
class _WorkspaceCard extends ConsumerWidget {
  const _WorkspaceCard();

  /// 卡片 140 高、上下内距 16，内容区 108 高（原版信息卡里的图也是 108 高）。
  static const double _contentHeight = 108;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolboxImageControllerProvider);
    final controller = ref.read(toolboxImageControllerProvider.notifier);
    final image = state.image;

    Future<void> pickSample() async {
      final sample = await showToolboxSamplePicker(context);
      if (sample != null && context.mounted) {
        await controller.loadSample(sample);
      }
    }

    final Widget lead;
    if (image != null) {
      lead = _WorkspaceImage(image: image, height: _contentHeight);
    } else if (state.loading) {
      lead = const SizedBox(
        width: _contentHeight,
        height: _contentHeight,
        child: Center(child: AppLoadingIndicator(size: 32)),
      );
    } else {
      final featured = [
        for (final sample in toolboxSamples)
          if (sample.featured) sample,
      ];
      lead = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < featured.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            SampleThumb(
              sample: featured[i],
              size: 82,
              showLabel: true,
              onTap: () => controller.loadSample(featured[i]),
            ),
          ],
        ],
      );
    }
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          image?.label ?? '先选一张要分析的画作',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: libraryText(
            size: 16,
            weight: AppFont.w500,
            color: AppColors.ink,
            height: 28 / 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          image == null
              ? '上传一张作业或范画，或直接点一张示例。同一张图可在各工具中继续使用，图片只在本机处理。'
              : '当前画作 · 同一张图可在各工具中继续使用，图片只在本机处理。',
          style: libraryText(
            size: 12,
            color: AppColors.textPlaceholder,
            height: 1.5,
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        LibraryActionPill(
          label: '上传图片',
          icon: Icons.upload_rounded,
          iconSize: 18,
          primary: true,
          onTap: state.loading ? null : controller.pickFromAlbum,
        ),
        LibraryActionPill(
          label: '使用示例画作',
          icon: Icons.collections_outlined,
          iconSize: 18,
          onTap: state.loading ? null : pickSample,
        ),
      ],
    );
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 700) {
            return Row(
              children: [
                lead,
                const SizedBox(width: 16),
                Expanded(child: texts),
                const SizedBox(width: 16),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                primary: false,
                child: lead,
              ),
              const SizedBox(height: 12),
              texts,
              const SizedBox(height: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

/// 选图卡里的当前画作：按画作比例裁成 108 高的缩略图，圆角 8。
class _WorkspaceImage extends StatelessWidget {
  const _WorkspaceImage({required this.image, required this.height});

  final ToolboxImage image;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = (height * image.aspectRatio)
        .clamp(height * 0.66, height * 1.8)
        .toDouble();
    return ClipRRect(
      borderRadius: AppRadius.br8,
      child: SizedBox(
        width: width,
        height: height,
        child: RawImage(
          image: image.image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

/// 工具卡片网格，数值取原版练习页的关卡网格：三列、列距 12、行距 10、卡高 100。
/// 内容区很窄时减为两列或一列。
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({
    required this.tools,
    required this.descriptionOf,
    required this.onOpen,
  });

  final List<ArtTool> tools;
  final String Function(ArtTool tool) descriptionOf;
  final ValueChanged<ArtTool> onOpen;

  static const double _crossGap = 12;
  static const double _mainGap = 10;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600
            ? 3
            : (constraints.maxWidth >= 380 ? 2 : 1);
        final width =
            ((constraints.maxWidth - _crossGap * (columns - 1)) / columns)
                .floorToDouble();
        return Wrap(
          spacing: _crossGap,
          runSpacing: _mainGap,
          children: [
            for (final tool in tools)
              SizedBox(
                width: width,
                child: _ToolCard(
                  tool: tool,
                  description: descriptionOf(tool),
                  onTap: () => onOpen(tool),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 工具卡片，数值取自原版的关卡卡片：100 高、浅灰底、圆角 12、内距 10，左侧
/// 60×80 圆角 8 的封面（这里放工具图标），名称 13 号中等字重，说明 11 号灰字，
/// 右下角 72×28 的深色按钮。整张卡片可点。
///
/// 工具的一句话介绍比关卡副标题长，说明最多排两行（原版只有一行）。
class _ToolCard extends StatelessWidget {
  const _ToolCard({
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
        height: 100,
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 80,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: AppRadius.br8,
              ),
              child: Icon(tool.icon, size: 28, color: AppColors.brand),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 80,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 4,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tool.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: libraryText(
                              size: 13,
                              weight: AppFont.w500,
                              color: AppColors.ink,
                              height: 12 / 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: libraryText(
                              size: 11,
                              color: AppColors.textPlaceholder,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: ExcludeSemantics(
                        child: Container(
                          width: 72,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: LibraryPalette.darkAction,
                            borderRadius: AppRadius.br8,
                          ),
                          child: Text(
                            '去使用',
                            maxLines: 1,
                            softWrap: false,
                            style: libraryText(
                              size: 11,
                              weight: AppFont.w500,
                              color: AppColors.onBrand,
                              height: 12 / 11,
                            ),
                          ),
                        ),
                      ),
                    ),
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
