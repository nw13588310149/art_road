import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';
import 'quick_sketch_session_page.dart';

/// 速写计时练习：选择每张时长、张数与参考图集，进入全屏计时练习。
///
/// 版式与看画分析的工具一致：左侧画布预览参考图，右侧白色侧栏放练习设置。
class QuickSketchTool extends StatefulWidget {
  const QuickSketchTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<QuickSketchTool> createState() => _QuickSketchToolState();
}

class _QuickSketchToolState extends State<QuickSketchTool> {
  int _interval = 60;
  int _count = 10;
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
      bodyTopInset: 0,
      body: ImageToolLayout(
        stage: (_) => ToolStage(child: _ReferencePreview(set: _set)),
        panel: (_) => _buildSettings(),
        panelFooter: (_) => _buildStart(),
      ),
    );
  }

  /// 固定在参数下方的「开始练习」：原版练习设置页底部的主按钮（240×52）。
  Widget _buildStart() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToolNote(
          '共 $_count 张 · 每张 ${sketchIntervalLabel(_interval)} · 预计 $_totalText',
        ),
        const SizedBox(height: AppSpace.s8),
        SizedBox(
          width: 240,
          height: 52,
          child: AppButton(
            label: '开始练习',
            icon: Icons.play_arrow_rounded,
            expand: true,
            onTap: _start,
          ),
        ),
      ],
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
              const SizedBox(height: AppSpace.s8),
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

/// 画布里的参考图预览：最多九张，三列方图。
class _ReferencePreview extends StatelessWidget {
  const _ReferencePreview({required this.set});

  final SketchReferenceSet set;

  static const double _gap = AppSpace.s12;

  @override
  Widget build(BuildContext context) {
    final assets = set.assets.take(9).toList();
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 三列方图，整组不超过画布高度；画布太矮时可以滚动。
              final rows = (assets.length / 3).ceil();
              final byWidth = (constraints.maxWidth - 32 - _gap * 2) / 3;
              final byHeight =
                  (constraints.maxHeight - 88 - _gap * (rows - 1)) / rows;
              final size = byWidth
                  .clamp(48.0, byHeight.clamp(96.0, 240.0))
                  .floorToDouble();
              final decodeWidth =
                  (size * MediaQuery.devicePixelRatioOf(context) * 1.5).round();
              return Center(
                child: SingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(16, 44, 16, 44),
                  child: SizedBox(
                    width: size * 3 + _gap * 2,
                    child: Wrap(
                      spacing: _gap,
                      runSpacing: _gap,
                      children: [
                        for (final asset in assets)
                          ClipRRect(
                            borderRadius: AppRadius.br8,
                            child: Image.asset(
                              asset,
                              width: size,
                              height: size,
                              fit: BoxFit.cover,
                              cacheWidth: decodeWidth,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: StageLabel('「${set.label}」参考图'),
        ),
        StageHint('共 ${set.assets.length} 张素材，随机出题，张数不够时循环使用'),
      ],
    );
  }
}
