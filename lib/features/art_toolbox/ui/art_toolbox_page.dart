import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/art_widgets.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/toolbox_catalog.dart';
import '../state/countdown_controller.dart';
import '../state/toolbox_image_controller.dart';
import 'tools/color_picker_tool.dart';
import 'tools/countdown_tool.dart';
import 'tools/grid_tool.dart';
import 'tools/mirror_tool.dart';
import 'tools/quick_sketch_tool.dart';
import 'tools/value_check_tool.dart';
import 'widgets/image_tool_frame.dart';

/// 画室工具箱：明度检查、镜像翻转、构图网格、取色与色卡、速写计时练习、考试倒计时。
///
/// 路由参数（均可选）：`{'tool': 'value'|'mirror'|'grid'|'color'|'quickSketch'|'countdown',
/// 'imageUrl': String, 'title': String}`。带 `tool` 时直接打开该工具，返回即关闭本页；
/// `imageUrl` 会预先载入给图片类工具使用（如范画库「临摹网格」），`title` 为图片名称。
class ArtToolboxPage extends ConsumerStatefulWidget {
  const ArtToolboxPage({super.key});

  @override
  ConsumerState<ArtToolboxPage> createState() => _ArtToolboxPageState();
}

class _ArtToolboxPageState extends ConsumerState<ArtToolboxPage> {
  ArtTool? _tool;
  ArtTool? _entryTool;
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
    ArtTool.mirror => MirrorTool(onBack: _back),
    ArtTool.grid => GridTool(onBack: _back),
    ArtTool.color => ColorPickerTool(onBack: _back),
    ArtTool.quickSketch => QuickSketchTool(onBack: _back),
    ArtTool.countdown => CountdownTool(onBack: _back),
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
      AppToast.show(context, msg);
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
        borderRadius: BorderRadius.circular(ShellLayoutSpec.panelRadius),
        child: ToolboxImagePending(
          pending: _imagePending,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey<ArtTool?>(tool),
              child: tool == null
                  ? _ToolboxHome(
                      onOpen: _open,
                      onBack: canPop ? () => Navigator.of(context).pop() : null,
                    )
                  : _buildTool(tool),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolboxHome extends ConsumerWidget {
  const _ToolboxHome({required this.onOpen, required this.onBack});

  final ValueChanged<ArtTool> onOpen;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final next = ref.watch(countdownControllerProvider).nextUpcoming(now);
    String descriptionOf(ArtTool tool) {
      if (tool == ArtTool.countdown && next != null) {
        final days = next.daysLeftFrom(now);
        return days == 0 ? '「${next.name}」就是今天' : '距「${next.name}」还有 $days 天';
      }
      return tool.description;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArtPageHeader(
          title: '画室工具箱',
          subtitle: '离线可用 · 图片只在本机处理，不会上传',
          onBack: onBack,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HomeBanner(),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 14.0;
                    final width = constraints.maxWidth;
                    final columns = width >= 860 ? 3 : (width >= 520 ? 2 : 1);
                    final itemWidth = (width - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final tool in ArtTool.values)
                          SizedBox(
                            width: itemWidth,
                            child: _ToolCard(
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

class _HomeBanner extends StatelessWidget {
  const _HomeBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 132,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/demo/scene/studio-wall.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              filterQuality: FilterQuality.medium,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF25D45ED),
                    Color(0xCC715EFE),
                    Color(0x00715EFE),
                  ],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '画室小工具',
                    style: ArtText.title(size: 22, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      '看明度、翻镜像、打网格、取颜色，再加上速写计时和考试倒计时，课堂与自习随手可用。',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: ArtText.caption(
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ArtColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: tool.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tool.icon, color: tool.accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.label,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        color: ArtColors.ink,
                        fontWeight: AppFont.w600,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ArtText.caption(),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: ArtColors.ink4,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
