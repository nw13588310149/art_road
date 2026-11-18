import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';
import 'quick_sketch_session_page.dart';

/// 速写计时练习：选择每张时长、张数与参考图集，进入全屏计时练习。
///
/// 版式与看画分析的工具一致：画布里按原比例预览这一组参考图，右边面板放练习
/// 设置，「开始练习」是页头里唯一的主按钮。
class QuickSketchTool extends StatefulWidget {
  const QuickSketchTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<QuickSketchTool> createState() => _QuickSketchToolState();
}

class _QuickSketchToolState extends State<QuickSketchTool> {
  int _interval = 60;
  int _count = sketchCounts.first;
  SketchReferenceSet _set = SketchReferenceSet.figures;

  String get _totalText {
    final minutes = _interval * _count / 60;
    return minutes == minutes.roundToDouble()
        ? '${minutes.round()} 分钟'
        : '${minutes.toStringAsFixed(1)} 分钟';
  }

  void _start() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => QuickSketchSessionPage(
          pool: _set.assets,
          count: _count,
          interval: Duration(seconds: _interval),
          setLabel: _set.label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolPageScaffold(
      tool: ArtTool.quickSketch,
      onBack: widget.onBack,
      caption:
          '共 $_count 张 · 每张 ${sketchIntervalLabel(_interval)} · 预计 $_totalText',
      actions: [
        AppButton(label: '开始练习', icon: Icons.play_arrow_rounded, onTap: _start),
      ],
      body: ImageToolLayout(
        hint: '共 ${_set.assets.length} 张素材，随机出题，张数不够时循环使用',
        stage: (_) => ToolStage(
          label: '「${_set.label}」参考图',
          child: _ReferencePreview(set: _set),
        ),
        panel: (_) => _buildSettings(),
      ),
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '每张时长',
          child: ToolSegmented<int>(
            values: sketchIntervals,
            value: _interval,
            labelOf: sketchIntervalLabel,
            onChanged: (v) => setState(() => _interval = v),
          ),
        ),
        ToolPanelSection(
          title: '练习张数',
          child: ToolSegmented<int>(
            values: sketchCounts,
            value: _count,
            labelOf: (v) => '$v 张',
            onChanged: (v) => setState(() => _count = v),
          ),
        ),
        ToolPanelSection(
          title: '参考图',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ToolSegmented<SketchReferenceSet>(
                values: SketchReferenceSet.values,
                value: _set,
                labelOf: (v) => v.label,
                onChanged: (v) => setState(() => _set = v),
              ),
              ToolNote(_set.description),
            ],
          ),
        ),
        const ToolTipCard(
          title: '怎么练',
          text:
              '计时开始后先观察 3–5 秒，抓住动态线与重心再下笔；时间到自动换下一张，不要回头补画。'
              '建议从 2 分钟开始，熟练后缩短到 30 秒～1 分钟，专门训练对大动态的捕捉。',
        ),
      ],
    );
  }
}

/// 画布里的参考图预览：最多九张，等高、按原比例排开，不裁。
class _ReferencePreview extends StatelessWidget {
  const _ReferencePreview({required this.set});

  final SketchReferenceSet set;

  static const double _gap = AppSpace.s16;

  @override
  Widget build(BuildContext context) {
    final assets = set.assets.take(9).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = assets.length <= 3 ? 2 : 3;
        final height = ((constraints.maxHeight - 48 - _gap * (rows - 1)) / rows)
            .clamp(72.0, 240.0)
            .floorToDouble();
        final decodeHeight =
            (height * MediaQuery.devicePixelRatioOf(context) * 1.5).round();
        return Center(
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.all(AppSpace.s24),
            child: Wrap(
              spacing: _gap,
              runSpacing: _gap,
              alignment: WrapAlignment.center,
              children: [
                for (final asset in assets)
                  AppImageTile.frame(
                    child: Image.asset(
                      asset,
                      height: height,
                      fit: BoxFit.contain,
                      cacheHeight: decodeHeight,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
