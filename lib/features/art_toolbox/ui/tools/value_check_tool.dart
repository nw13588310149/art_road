import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/color_analysis.dart';
import '../../logic/image_filters.dart';
import '../../logic/image_ops.dart';
import '../widgets/image_job.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 明度检查：灰度、2/3/5/7 阶色阶与黑白剪影（Notan）。
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
  levels('色阶'),
  notan('剪影');

  const _ValueView(this.label);

  final String label;
}

class _Levels {
  const _Levels(this.image, this.distribution);

  final ui.Image image;
  final List<double> distribution;
}

typedef _NotanParams = ({int threshold, int smooth});

class _ValueCheckBody extends StatefulWidget {
  const _ValueCheckBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_ValueCheckBody> createState() => _ValueCheckBodyState();
}

class _ValueCheckBodyState extends State<_ValueCheckBody> {
  static const _levelOptions = <int>[2, 3, 5, 7];

  _ValueView _view = _ValueView.levels;
  int _levels = 3;
  bool _compare = false;
  ui.Image? _gray;
  bool _grayBusy = false;
  final Map<int, _Levels> _posterized = <int, _Levels>{};
  final Set<int> _levelsBusy = <int>{};

  bool _failed = false;

  int _threshold = 128;
  int? _autoThreshold;
  int _smooth = 2;
  ProcessedImage<double>? _notan;
  late final LatestImageJob<_NotanParams, double> _notanJob = LatestImageJob(
    run: (params) async {
      final work = await widget.image.workData();
      final result = await compute(
        notan,
        NotanRequest(work, params.threshold, smooth: params.smooth),
      );
      return (result.image, result.darkRatio);
    },
    onResult: (_, result) {
      disposeImageLater(_notan?.image);
      setState(() {
        _notan = result;
        _failed = false;
      });
    },
    onError: (_) {
      if (_notan == null) {
        setState(() => _failed = true);
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _ensureDerived();
    _loadAutoThreshold();
  }

  @override
  void dispose() {
    _notanJob.dispose();
    _gray?.dispose();
    _notan?.image.dispose();
    for (final levels in _posterized.values) {
      levels.image.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAutoThreshold() async {
    try {
      final work = await widget.image.workData();
      final histogram = await compute(luminanceHistogram, work);
      if (!mounted) {
        return;
      }
      final auto = otsuThreshold(histogram);
      setState(() {
        _autoThreshold = auto;
        _threshold = auto;
      });
      if (_view == _ValueView.notan) {
        _requestNotan();
      }
    } catch (_) {
      // 算不出自动阈值时保留默认的 128。
    }
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
    if (_view == _ValueView.notan && _notan == null) {
      _requestNotan();
    }
  }

  void _requestNotan() =>
      _notanJob.request((threshold: _threshold, smooth: _smooth));

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
      if (mounted) {
        setState(() => _failed = true);
      }
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
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      _levelsBusy.remove(levels);
    }
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _failed = false;
    });
    _ensureDerived();
  }

  void _retry() => _update(() {});

  ui.Image? get _processed => switch (_view) {
    _ValueView.original => _compare ? _gray : widget.image.image,
    _ValueView.gray => _gray,
    _ValueView.levels => _posterized[_levels]?.image,
    _ValueView.notan => _notan?.image,
  };

  String get _processedLabel => switch (_view) {
    _ValueView.original => _compare ? '灰度' : '原图',
    _ValueView.gray => '灰度',
    _ValueView.levels => '$_levels 阶色阶',
    _ValueView.notan => '黑白剪影',
  };

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(
      stage: (context) => CompareStage(
        original: widget.image.image,
        processed: _processed,
        label: _processedLabel,
        compare: _compare && _view != _ValueView.original,
        failed: _failed,
        onRetry: _retry,
      ),
      panel: _buildPanel,
    );
  }

  Widget _buildPanel(BuildContext context) {
    final distribution = _view == _ValueView.levels
        ? _posterized[_levels]?.distribution
        : null;
    final darkRatio = _notan?.info;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '查看方式',
          child: ToolSegmented<_ValueView>(
            values: _ValueView.values,
            value: _view,
            labelOf: (v) => v.label,
            onChanged: (v) => _update(() => _view = v),
          ),
        ),
        if (_view == _ValueView.notan) ...[
          ToolSliderRow(
            label: '黑白阈值',
            hint: '亮度低于阈值的地方归为黑色',
            value: _threshold.toDouble(),
            min: 1,
            max: 255,
            divisions: 254,
            valueLabel: '$_threshold',
            onChanged: (v) {
              setState(() => _threshold = v.round());
              _requestNotan();
            },
          ),
          ToolSliderRow(
            label: '概括细节',
            hint: '越大越忽略小的明暗变化',
            value: _smooth.toDouble(),
            min: 0,
            max: 8,
            divisions: 8,
            valueLabel: '$_smooth',
            onChanged: (v) {
              setState(() => _smooth = v.round());
              _requestNotan();
            },
          ),
          if (_autoThreshold != null)
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: '使用自动阈值（$_autoThreshold）',
                icon: Icons.auto_fix_high_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: _threshold == _autoThreshold
                    ? null
                    : () {
                        setState(() => _threshold = _autoThreshold!);
                        _requestNotan();
                      },
              ),
            ),
          const SizedBox(height: AppSpace.s16),
          if (darkRatio != null)
            ToolPanelSection(
              title: '黑白面积',
              child: _NotanShare(darkRatio: darkRatio),
            ),
        ] else
          ToolPanelSection(
            title: '色阶数',
            trailing: const Text('越少越概括'),
            child: ToolSegmented<int>(
              values: _levelOptions,
              value: _levels,
              labelOf: (n) => '$n 阶',
              onChanged: (n) => _update(() {
                _levels = n;
                _view = _ValueView.levels;
              }),
            ),
          ),
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
        if (_view == _ValueView.notan)
          const ToolTipCard(
            title: '黑白剪影怎么看',
            text:
                '把画面只分成黑、白两块，看大的明暗布局是否清楚、主体是否从背景里跳出来。'
                '先用自动阈值，再左右拖动看明暗分界的变化；剪影读不清的地方，往往就是画面关系含糊的地方。',
          )
        else
          const ToolTipCard(
            title: '黑白灰关系',
            text:
                '眯起眼睛看画面，把复杂的明暗归纳成黑、白、灰三大层次：亮部要亮得透，暗部要重得稳，中间灰要有变化。'
                '2–3 阶适合检查整体明暗布局，5–7 阶适合检查形体塑造的层次。色彩作业同样适用：转成灰度后如果一片灰，说明明度对比不足。',
          ),
      ],
    );
  }
}

class _NotanShare extends StatelessWidget {
  const _NotanShare({required this.darkRatio});

  final double darkRatio;

  @override
  Widget build(BuildContext context) {
    final percents = percentagesOf([darkRatio, 1 - darkRatio]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RatioBar(
          colors: const [AppColors.ink, AppColors.surface],
          ratios: [darkRatio, 1 - darkRatio],
        ),
        const SizedBox(height: AppSpace.s8),
        Row(
          children: [
            Text('黑 ', style: AppText.caption12),
            Text('${percents[0]}%', style: AppText.number(size: 13)),
            const SizedBox(width: AppSpace.s16),
            Text('白 ', style: AppText.caption12),
            Text('${percents[1]}%', style: AppText.number(size: 13)),
          ],
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

  String _nameOf(int index) => switch (distribution.length) {
    2 => const ['暗部', '亮部'][index],
    3 => const ['暗部', '中间调', '亮部'][index],
    _ => '${index + 1} 阶',
  };

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
    if (n > 2 && mid > 0.6) {
      return '中间调占比偏大，画面容易发灰，可适当加重暗部、提亮亮部。';
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
    final percents = percentagesOf(distribution);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RatioBar(
          colors: [for (var i = 0; i < distribution.length; i++) _grayOf(i)],
          ratios: distribution,
        ),
        const SizedBox(height: AppSpace.s8),
        Wrap(
          spacing: AppSpace.s12,
          runSpacing: AppSpace.s4,
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
                      borderRadius: AppRadius.br4,
                      border: Border.all(color: AppColors.textPlaceholder),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s4),
                  Text(_nameOf(i), style: AppText.caption12),
                  const SizedBox(width: 2),
                  Text(
                    '${percents[i]}%',
                    style: AppText.number(
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        Text(_verdict(), style: AppText.body13),
      ],
    );
  }
}
