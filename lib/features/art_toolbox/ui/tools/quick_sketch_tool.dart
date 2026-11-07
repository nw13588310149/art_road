import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';
import 'quick_sketch_session_page.dart';

/// 速写计时练习：选择每张时长、张数与参考图集，进入全屏计时练习。
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final settings = _buildSettings();
          final preview = _ReferencePreview(set: _set);
          const padding = EdgeInsets.fromLTRB(
            AppSpace.page,
            0,
            AppSpace.page,
            AppSpace.s24,
          );
          if (constraints.maxWidth >= 760) {
            return SingleChildScrollView(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: settings),
                  const SizedBox(width: AppSpace.s16),
                  SizedBox(width: 320, child: preview),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [settings, const SizedBox(height: AppSpace.s16), preview],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettings() {
    return AppCard(
      child: Column(
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
            trailing: Text(_set.description),
            child: ToolSegmented<SketchReferenceSet>(
              values: SketchReferenceSet.values,
              value: _set,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _set = v),
            ),
          ),
          AppCard(
            color: AppColors.surfaceSubtle,
            bordered: false,
            padding: const EdgeInsets.all(AppSpace.s12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '共 $_count 张 · 每张 ${sketchIntervalLabel(_interval)}',
                        style: AppText.body14Strong,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '预计 $_totalText，时间到自动换下一张',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                AppButton(
                  label: '开始练习',
                  icon: Icons.play_arrow_rounded,
                  onTap: _start,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          const ToolTipCard(
            title: '怎么练',
            text:
                '计时开始后先观察 3–5 秒，抓住动态线与重心再下笔；时间到自动换下一张，不要回头补画。'
                '建议从 2 分钟开始，熟练后缩短到 30 秒～1 分钟，专门训练对大动态的捕捉。',
          ),
        ],
      ),
    );
  }
}

class _ReferencePreview extends StatelessWidget {
  const _ReferencePreview({required this.set});

  final SketchReferenceSet set;

  @override
  Widget build(BuildContext context) {
    final assets = set.assets.take(9).toList();
    return AppCard(
      title: '「${set.label}」参考图',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '共 ${set.assets.length} 张素材，随机出题，张数不够时循环使用',
            style: AppText.caption12,
          ),
          const SizedBox(height: AppSpace.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = AppSpace.s8;
              final size = (constraints.maxWidth - gap * 2) / 3;
              final decodeWidth =
                  (size * MediaQuery.devicePixelRatioOf(context) * 1.5).round();
              return Wrap(
                spacing: gap,
                runSpacing: gap,
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
              );
            },
          ),
        ],
      ),
    );
  }
}
