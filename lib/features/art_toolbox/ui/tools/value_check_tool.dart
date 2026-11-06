import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/image_ops.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 明度检查：灰度 / 色阶，检查黑白灰关系。
class ValueCheckTool extends StatelessWidget {
  const ValueCheckTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.value,
      onBack: onBack,
      builder: (context, image) =>
          _ValueCheckBody(key: ValueKey(image.version), image: image),
    );
  }
}

enum _ValueView {
  original('原图'),
  gray('灰度'),
  levels('色阶');

  const _ValueView(this.label);

  final String label;
}

class _Levels {
  const _Levels(this.image, this.distribution);

  final ui.Image image;
  final List<double> distribution;
}

class _ValueCheckBody extends StatefulWidget {
  const _ValueCheckBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_ValueCheckBody> createState() => _ValueCheckBodyState();
}

class _ValueCheckBodyState extends State<_ValueCheckBody> {
  static const _levelOptions = <int>[3, 5, 7];

  _ValueView _view = _ValueView.levels;
  int _levels = 3;
  bool _compare = false;
  ui.Image? _gray;
  bool _grayBusy = false;
  final Map<int, _Levels> _posterized = <int, _Levels>{};
  final Set<int> _levelsBusy = <int>{};

  @override
  void initState() {
    super.initState();
    _ensureDerived();
  }

  @override
  void dispose() {
    _gray?.dispose();
    for (final levels in _posterized.values) {
      levels.image.dispose();
    }
    super.dispose();
  }

  void _ensureDerived() {
    final needGray =
        _view == _ValueView.gray || (_compare && _view == _ValueView.original);
    if (needGray && _gray == null && !_grayBusy) {
      _computeGray();
    }
    if (_view == _ValueView.levels &&
        !_posterized.containsKey(_levels) &&
        !_levelsBusy.contains(_levels)) {
      _computeLevels(_levels);
    }
  }

  Future<void> _computeGray() async {
    _grayBusy = true;
    try {
      final data = await compute(grayscale, widget.image.data);
      final image = await artImageToUiImage(data);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _gray = image);
    } catch (_) {
      // 失败时保持处理中状态的占位，切换视图会重新尝试。
    } finally {
      _grayBusy = false;
    }
  }

  Future<void> _computeLevels(int levels) async {
    _levelsBusy.add(levels);
    try {
      final result = await compute(
        posterizeWithDistribution,
        PosterizeRequest(widget.image.data, levels),
      );
      final image = await artImageToUiImage(result.image);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _posterized[levels] = _Levels(image, result.distribution));
    } catch (_) {
      // 同上：下次切换色阶时重试。
    } finally {
      _levelsBusy.remove(levels);
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    _ensureDerived();
  }

  ui.Image? get _processed => switch (_view) {
    _ValueView.original => _compare ? _gray : widget.image.image,
    _ValueView.gray => _gray,
    _ValueView.levels => _posterized[_levels]?.image,
  };

  String get _processedLabel => switch (_view) {
    _ValueView.original => _compare ? '灰度' : '原图',
    _ValueView.gray => '灰度',
    _ValueView.levels => '$_levels 阶色阶',
  };

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context, bool wide) {
    final processed = StageImagePane(image: _processed, label: _processedLabel);
    if (!wide || !_compare) {
      return ToolStage(child: processed);
    }
    return Row(
      children: [
        Expanded(
          child: ToolStage(
            child: StageImagePane(image: widget.image.image, label: '原图'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: ToolStage(child: processed)),
      ],
    );
  }

  Widget _buildPanel(BuildContext context, bool wide) {
    final distribution = _view == _ValueView.levels
        ? _posterized[_levels]?.distribution
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '查看方式',
          child: ArtSegmentTabs<_ValueView>(
            items: _ValueView.values,
            value: _view,
            labelOf: (v) => v.label,
            onChanged: (v) => _update(() => _view = v),
          ),
        ),
        ToolPanelSection(
          title: '色阶数',
          trailing: Text('越少越概括', style: ArtText.caption(size: 11)),
          child: Opacity(
            opacity: _view == _ValueView.levels ? 1 : 0.5,
            child: ArtSegmentTabs<int>(
              items: _levelOptions,
              value: _levels,
              labelOf: (n) => '$n 阶',
              onChanged: (n) => _update(() {
                _levels = n;
                _view = _ValueView.levels;
              }),
            ),
          ),
        ),
        if (wide)
          ToolSwitchRow(
            label: '与原图并排对比',
            value: _compare,
            onChanged: (v) => _update(() => _compare = v),
          ),
        if (distribution != null)
          ToolPanelSection(
            title: '明度分布',
            child: _ValueDistribution(distribution: distribution),
          ),
        const ToolTipCard(
          title: '黑白灰关系',
          text:
              '眯起眼睛看画面，把复杂的明暗归纳成黑、白、灰三大层次：亮部要亮得透，暗部要重得稳，中间灰要有变化。'
              '3 阶适合检查整体明暗布局，5–7 阶适合检查形体塑造的层次。色彩作业同样适用：转成灰度后如果一片灰，说明明度对比不足。',
        ),
      ],
    );
  }
}

class _ValueDistribution extends StatelessWidget {
  const _ValueDistribution({required this.distribution});

  final List<double> distribution;

  Color _grayOf(int index) {
    final v = (index * 255 / (distribution.length - 1)).round();
    return Color.fromARGB(255, v, v, v);
  }

  String _nameOf(int index) {
    if (distribution.length == 3) {
      return const ['暗部', '中间调', '亮部'][index];
    }
    return '${index + 1} 阶';
  }

  /// 按明度三等分汇总，给出画面黑白灰比例的提示。
  String _verdict() {
    var dark = 0.0;
    var mid = 0.0;
    var light = 0.0;
    final n = distribution.length;
    for (var i = 0; i < n; i++) {
      final center = (i + 0.5) / n;
      if (center < 1 / 3) {
        dark += distribution[i];
      } else if (center > 2 / 3) {
        light += distribution[i];
      } else {
        mid += distribution[i];
      }
    }
    if (mid > 0.6) {
      return '中间调占比偏大，画面容易发「灰」，可适当加重暗部、提亮亮部。';
    }
    if (dark > 0.55) {
      return '暗部面积较大，画面整体偏重，注意亮部的层次与透气感。';
    }
    if (light > 0.55) {
      return '亮部面积较大，画面整体偏亮，可用更肯定的暗部稳住画面。';
    }
    return '黑白灰比例较均衡，明暗层次清楚。';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              border: Border.all(color: ArtColors.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                for (var i = 0; i < distribution.length; i++)
                  if (distribution[i] > 0)
                    Expanded(
                      flex: (distribution[i] * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: _grayOf(i)),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < distribution.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _grayOf(i),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: ArtColors.ink4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_nameOf(i)} ${(distribution[i] * 100).round()}%',
                    style: ArtText.caption(size: 11, color: ArtColors.ink2),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _verdict(),
          style: ArtText.caption(size: 12, color: ArtColors.ink2),
        ),
      ],
    );
  }
}
