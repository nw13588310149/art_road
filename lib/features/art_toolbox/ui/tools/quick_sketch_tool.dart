import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/toolbox_catalog.dart';
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
    final accent = ArtTool.quickSketch.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArtPageHeader(
          title: ArtTool.quickSketch.label,
          subtitle: ArtTool.quickSketch.description,
          onBack: widget.onBack,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final settings = _SettingsCard(
                accent: accent,
                interval: _interval,
                count: _count,
                set: _set,
                totalText: _totalText,
                onIntervalChanged: (v) => setState(() => _interval = v),
                onCountChanged: (v) => setState(() => _count = v),
                onSetChanged: (v) => setState(() => _set = v),
                onStart: _start,
              );
              final preview = _ReferencePreview(set: _set);
              if (constraints.maxWidth >= 760) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: settings),
                      const SizedBox(width: 20),
                      SizedBox(width: 320, child: preview),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [settings, const SizedBox(height: 16), preview],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.accent,
    required this.interval,
    required this.count,
    required this.set,
    required this.totalText,
    required this.onIntervalChanged,
    required this.onCountChanged,
    required this.onSetChanged,
    required this.onStart,
  });

  final Color accent;
  final int interval;
  final int count;
  final SketchReferenceSet set;
  final String totalText;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<SketchReferenceSet> onSetChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ArtColors.subtle,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToolPanelSection(
            title: '每张时长',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final seconds in sketchIntervals)
                  ToolOptionChip(
                    label: sketchIntervalLabel(seconds),
                    selected: seconds == interval,
                    accent: accent,
                    onTap: () => onIntervalChanged(seconds),
                  ),
              ],
            ),
          ),
          ToolPanelSection(
            title: '练习张数',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in sketchCounts)
                  ToolOptionChip(
                    label: '$value 张',
                    selected: value == count,
                    accent: accent,
                    onTap: () => onCountChanged(value),
                  ),
              ],
            ),
          ),
          ToolPanelSection(
            title: '参考图',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final option in SketchReferenceSet.values)
                  ToolOptionChip(
                    label: option.label,
                    selected: option == set,
                    accent: accent,
                    onTap: () => onSetChanged(option),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '共 $count 张 · 每张 ${sketchIntervalLabel(interval)}',
                        style: ArtText.body(weight: AppFont.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '预计 $totalText · ${set.description}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ArtText.caption(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ArtButton(
                  label: '开始练习',
                  icon: Icons.play_arrow_rounded,
                  height: 42,
                  onTap: onStart,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ArtColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('「${set.label}」参考图', style: ArtText.title(size: 15)),
          const SizedBox(height: 4),
          Text(
            '共 ${set.assets.length} 张素材，随机出题，张数不够时会重新洗牌',
            style: ArtText.caption(),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final size = (constraints.maxWidth - gap * 2) / 3;
              final decodeWidth =
                  (size * MediaQuery.devicePixelRatioOf(context) * 1.5).round();
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final asset in assets)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
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
