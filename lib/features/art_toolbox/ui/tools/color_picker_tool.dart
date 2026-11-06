import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/color_analysis.dart';
import '../../logic/color_harmony.dart';
import '../../logic/image_ops.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 取色与色卡：点击画面取色（HEX / RGB / HSB / 色彩三要素 / 冷暖），提取主色，生成配色色环。
class ColorPickerTool extends StatelessWidget {
  const ColorPickerTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.color,
      onBack: onBack,
      builder: (context, image) =>
          _ColorPickerBody(key: ValueKey(image.version), image: image),
    );
  }
}

class _ColorPickerBody extends StatefulWidget {
  const _ColorPickerBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_ColorPickerBody> createState() => _ColorPickerBodyState();
}

class _ColorPickerBodyState extends State<_ColorPickerBody> {
  final TransformationController _transform = TransformationController();
  ({int x, int y})? _picked;
  RgbColor? _color;
  List<PaletteSwatch>? _palette;
  bool _paletteFailed = false;
  HarmonyScheme _scheme = HarmonyScheme.complementary;
  ColorWheelKind _wheel = ColorWheelKind.artist;

  @override
  void initState() {
    super.initState();
    _computePalette();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _computePalette() async {
    setState(() => _paletteFailed = false);
    try {
      final palette = await compute(extractPalette, widget.image.data);
      if (mounted) {
        setState(() => _palette = palette);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _paletteFailed = true);
      }
    }
  }

  /// 点击位置是 InteractiveViewer 子组件坐标系（未缩放），按 contain 留白换算到像素。
  void _pick(Offset local, Size box) {
    final image = widget.image;
    final pixel = containPointToPixel(
      dx: local.dx,
      dy: local.dy,
      boxWidth: box.width,
      boxHeight: box.height,
      imageWidth: image.width,
      imageHeight: image.height,
    );
    if (pixel == null) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _picked = pixel;
      _color = pixelAt(image.data, pixel.x, pixel.y);
    });
  }

  /// 配色的基色：取到的颜色，没取色时用面积最大的主色。
  RgbColor? get _baseColor {
    final palette = _palette;
    return _color ??
        (palette == null || palette.isEmpty ? null : palette.first.color);
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context, bool wide) {
    return ToolStage(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = constraints.biggest;
            return Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    maxScale: 10,
                    child: SizedBox(
                      width: box.width,
                      height: box.height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RawImage(
                              image: widget.image.image,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) =>
                                  _pick(details.localPosition, box),
                            ),
                          ),
                          if (_picked != null && _color != null)
                            _buildMarker(box),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_picked == null)
                  const Positioned(
                    left: 0,
                    top: 0,
                    child: StageLabel('点击画面任意位置取色，双指放大可精确取色'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMarker(Size box) {
    final image = widget.image;
    final picked = _picked!;
    final point = pixelToContainPoint(
      x: picked.x,
      y: picked.y,
      boxWidth: box.width,
      boxHeight: box.height,
      imageWidth: image.width,
      imageHeight: image.height,
    );
    return ListenableBuilder(
      listenable: _transform,
      builder: (context, _) {
        final scale = _transform.value.getMaxScaleOnAxis().clamp(1.0, 100.0);
        final size = 30 / scale;
        return Positioned(
          left: point.dx - size / 2,
          top: point.dy - size / 2,
          width: size,
          height: size,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(_color!.argb),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3 / scale),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.45),
                    blurRadius: 6 / scale,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanel(BuildContext context, bool wide) {
    final color = _color;
    final palette = _palette;
    final base = _baseColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '取色结果',
          child: color == null
              ? Container(
                  height: 72,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: AppRadius.br8,
                  ),
                  child: Text('点击画面取色', style: AppText.body13),
                )
              : _PickedColorCard(
                  color: color,
                  position: _picked!,
                  onCopy: (hex) => copyHex(context, hex),
                ),
        ),
        ToolPanelSection(
          title: '配色色环',
          trailing: Text(color == null ? '以面积最大的主色为基色' : '以取到的颜色为基色'),
          child: base == null
              ? const AppSkeleton(height: 180, radius: AppRadius.control)
              : _HarmonySection(
                  base: base,
                  scheme: _scheme,
                  wheel: _wheel,
                  onScheme: (v) => setState(() => _scheme = v),
                  onWheel: (v) => setState(() => _wheel = v),
                ),
        ),
        ToolPanelSection(
          title: '画面主色',
          trailing: const Text('点击复制 HEX'),
          child: _paletteFailed
              ? AppErrorState(
                  title: '主色提取失败',
                  description: '可以重试或换一张图片',
                  onRetry: _computePalette,
                )
              : palette == null
              ? const AppSkeletonText(lines: 4, lineHeight: 20)
              : palette.isEmpty
              ? const AppEmptyState(
                  title: '没有提取到主色',
                  description: '换一张颜色更丰富的图片试试',
                  icon: Icons.palette_outlined,
                )
              : _PaletteView(palette: palette),
        ),
        const ToolTipCard(
          title: '用色卡读懂画面',
          text:
              '先看主色之间的冷暖与明度关系，再看点缀色如何与主色形成对比。'
              '配色色环里的颜色只换色相、保留原色的明度和纯度，可以作为调色时找对比色、协调色的参考。',
        ),
      ],
    );
  }
}

class _PickedColorCard extends StatelessWidget {
  const _PickedColorCard({
    required this.color,
    required this.position,
    required this.onCopy,
  });

  final RgbColor color;
  final ({int x, int y}) position;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final hsb = color.toHsb();
    final temperature = describeTemperature(color);
    final attributes = colorAttributesOf(color);
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppPressable(
                onTap: () => onCopy(color.hex),
                semanticLabel: '复制 ${color.hex}',
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Color(color.argb),
                    borderRadius: AppRadius.br8,
                    border: Border.all(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPressable(
                      onTap: () => onCopy(color.hex),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(color.hex, style: AppText.number(size: 20)),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.content_copy_rounded,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RGB ${color.r}, ${color.g}, ${color.b}',
                      style: AppText.number(
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'HSB ${hsb.hue.round()}°, ${(hsb.saturation * 100).round()}%, '
                      '${(hsb.brightness * 100).round()}%',
                      style: AppText.number(
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            '色相 ${attributes.hueName} · 明度 ${attributes.value} · 纯度 ${attributes.chroma}',
            style: AppText.body13,
          ),
          const SizedBox(height: AppSpace.s8),
          Row(
            children: [
              _TemperatureTag(info: temperature),
              const Spacer(),
              Text(
                '像素 ${position.x}, ${position.y}',
                style: AppText.caption12,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemperatureTag extends StatelessWidget {
  const _TemperatureTag({required this.info});

  final ColorTemperatureInfo info;

  @override
  Widget build(BuildContext context) {
    final label = '${info.label} · ${info.family}';
    return switch (info.temperature) {
      ColorTemperature.warm => AppTag(
        label: label,
        icon: Icons.wb_sunny_outlined,
        color: Color(kWarmMapColor.argb),
      ),
      ColorTemperature.cool => AppTag(
        label: label,
        icon: Icons.ac_unit_rounded,
        color: Color(kCoolMapColor.argb),
      ),
      ColorTemperature.neutral => AppTag(
        label: label,
        icon: Icons.contrast_rounded,
      ),
    };
  }
}

class _HarmonySection extends StatelessWidget {
  const _HarmonySection({
    required this.base,
    required this.scheme,
    required this.wheel,
    required this.onScheme,
    required this.onWheel,
  });

  final RgbColor base;
  final HarmonyScheme scheme;
  final ColorWheelKind wheel;
  final ValueChanged<HarmonyScheme> onScheme;
  final ValueChanged<ColorWheelKind> onWheel;

  static String _shortLabel(HarmonyScheme scheme) => switch (scheme) {
    HarmonyScheme.complementary => '互补',
    HarmonyScheme.analogous => '邻近',
    HarmonyScheme.triadic => '三角',
    HarmonyScheme.splitComplementary => '分裂',
  };

  static String _roleOf(HarmonyScheme scheme, HarmonySwatch swatch) {
    if (swatch.isBase) {
      return '基色';
    }
    return switch (scheme) {
      HarmonyScheme.complementary => '补色',
      HarmonyScheme.analogous => '邻近色',
      HarmonyScheme.triadic => '三角色',
      HarmonyScheme.splitComplementary => '分裂补色',
    };
  }

  @override
  Widget build(BuildContext context) {
    final swatches = harmonyOf(base, scheme, wheel: wheel);
    final grayish = colorAttributesOf(base).achromatic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmented<HarmonyScheme>(
          segments: [
            for (final s in HarmonyScheme.values)
              AppSegment(value: s, label: _shortLabel(s)),
          ],
          value: scheme,
          onChanged: onScheme,
          expand: true,
        ),
        const SizedBox(height: AppSpace.s8),
        AppSegmented<ColorWheelKind>(
          segments: [
            for (final w in ColorWheelKind.values)
              AppSegment(value: w, label: w.label),
          ],
          value: wheel,
          onChanged: onWheel,
          size: AppControlSize.sm,
          expand: true,
        ),
        const SizedBox(height: AppSpace.s12),
        Center(
          child: SizedBox.square(
            dimension: 168,
            child: CustomPaint(
              painter: _HueWheelPainter(wheel: wheel, swatches: swatches),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          '${scheme.label}：${scheme.description}',
          style: AppText.body13,
        ),
        Text(wheel.description, style: AppText.caption12),
        if (grayish) ...[
          const SizedBox(height: AppSpace.s8),
          const ToolNotice('基色接近黑白灰，色相不明显，配色仅供参考'),
        ],
        const SizedBox(height: AppSpace.s8),
        for (final swatch in swatches)
          _HarmonyRow(
            role: _roleOf(scheme, swatch),
            color: swatch.color,
            onCopy: (hex) => copyHex(context, hex),
          ),
      ],
    );
  }
}

class _HarmonyRow extends StatelessWidget {
  const _HarmonyRow({
    required this.role,
    required this.color,
    required this.onCopy,
  });

  final String role;
  final RgbColor color;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final attributes = colorAttributesOf(color);
    return AppPressable(
      onTap: () => onCopy(color.hex),
      semanticLabel: '复制 ${color.hex}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(color.argb),
                borderRadius: AppRadius.br8,
                border: Border.all(color: AppColors.line),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(role, style: AppText.body14Strong),
                      const SizedBox(width: AppSpace.s8),
                      Text(color.hex, style: AppText.number(size: 13)),
                    ],
                  ),
                  Text(
                    '色相 ${attributes.hueName} ${attributes.hue.round()}° · '
                    '明度 ${attributes.value} · 纯度 ${attributes.chroma}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
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

/// 色环：0° 在正上方顺时针排列，标出配色里各颜色的位置并连线。
class _HueWheelPainter extends CustomPainter {
  const _HueWheelPainter({required this.wheel, required this.swatches});

  final ColorWheelKind wheel;
  final List<HarmonySwatch> swatches;

  static const _segments = 72;

  Offset _pointAt(Offset center, double radius, double degrees) {
    final radians = (degrees - 90) * math.pi / 180;
    return center + Offset(math.cos(radians), math.sin(radians)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    const ring = 18.0;
    final mid = outer - ring / 2;
    final rect = Rect.fromCircle(center: center, radius: mid);
    const sweep = math.pi * 2 / _segments;
    for (var i = 0; i < _segments; i++) {
      final angle = i * 360 / _segments;
      final rgb = hsbToRgb(opticalHueOf(angle, wheel), 0.8, 0.95);
      canvas.drawArc(
        rect,
        (angle - 90) * math.pi / 180 - sweep / 2,
        sweep + 0.01,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring
          ..color = Color(rgb.argb),
      );
    }
    final spoke = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    final inner = mid - ring / 2 - 6;
    final points = [
      for (final s in swatches) _pointAt(center, inner, s.wheelHue),
    ];
    if (points.length > 2) {
      canvas.drawPath(Path()..addPolygon(points, true), spoke);
    } else if (points.length == 2) {
      canvas.drawLine(points[0], points[1], spoke);
    }
    for (var i = 0; i < swatches.length; i++) {
      final markerCenter = _pointAt(center, mid, swatches[i].wheelHue);
      final radius = swatches[i].isBase ? 11.0 : 8.0;
      canvas
        ..drawCircle(markerCenter, radius + 2, Paint()..color = AppColors.ink)
        ..drawCircle(
          markerCenter,
          radius + 0.5,
          Paint()..color = AppColors.surface,
        )
        ..drawCircle(
          markerCenter,
          radius - 2,
          Paint()..color = Color(swatches[i].color.argb),
        );
    }
    canvas.drawCircle(center, 3, Paint()..color = AppColors.textTertiary);
  }

  @override
  bool shouldRepaint(covariant _HueWheelPainter oldDelegate) =>
      oldDelegate.wheel != wheel ||
      !listEquals(
        [for (final s in oldDelegate.swatches) s.color],
        [for (final s in swatches) s.color],
      );
}

class _PaletteView extends StatelessWidget {
  const _PaletteView({required this.palette});

  final List<PaletteSwatch> palette;

  @override
  Widget build(BuildContext context) {
    final percents = percentagesOf([for (final s in palette) s.ratio]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RatioBar(
          colors: [for (final s in palette) Color(s.color.argb)],
          ratios: [for (final s in palette) s.ratio],
          height: 24,
        ),
        const SizedBox(height: AppSpace.s8),
        for (var i = 0; i < palette.length; i++)
          SwatchRow(
            color: Color(palette[i].color.argb),
            hex: palette[i].color.hex,
            caption: describeTemperature(palette[i].color).label,
            trailing: '${percents[i]}%',
            onCopy: (hex) => copyHex(context, hex),
          ),
      ],
    );
  }
}
