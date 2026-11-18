import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/toolbox_catalog.dart';
import '../state/toolbox_image_controller.dart';
import 'toolbox_home.dart';
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
/// 首页和各工具页都放在外壳给的白色底板上，版式按 `docs/新页面设计语言.md`：
/// 首页是两栏（三组工具 + 当前画作），工具页是画布加面板。
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

  /// 全局工作台直接占满画布，普通路由仍使用外壳的白色底板。
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
  bool _argsApplied = false;
  bool _imagePending = false;

  @override
  void initState() {
    super.initState();
    _tool = widget.initialTool;
  }

  @override
  void didUpdateWidget(covariant ArtToolboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTool != oldWidget.initialTool) {
      _tool = widget.initialTool;
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
            ? ToolboxHome(
                showTitle: !widget.embedded,
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
    return content;
  }
}
