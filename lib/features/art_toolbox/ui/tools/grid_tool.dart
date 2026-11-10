import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/geometry.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 构图网格：三分法、黄金分割、对角线可叠加；九宫格 / 自定义网格用于临摹；
/// 按四开、八开、十六开画纸比例预览裁切，构图线随裁切范围走。
class GridTool extends StatelessWidget {
  const GridTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.grid,
      onBack: onBack,
      builder: (context, image) =>
          _GridBody(key: ValueKey(image.version), image: image),
    );
  }
}

enum _GridMode {
  none('不显示'),
  nine('九宫格'),
  custom('自定义');

  const _GridMode(this.label);

  final String label;
}

enum _LineColor {
  white('白', AppColors.surface),
  black('黑', AppColors.ink),
  red('红', AppColors.danger),
  purple('紫', AppColors.brand);

  const _LineColor(this.label, this.color);

  final String label;
  final Color color;
}

class _GridBody extends StatefulWidget {
  const _GridBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_GridBody> createState() => _GridBodyState();
}

class _GridBodyState extends State<_GridBody> {
  final TransformationController _transform = TransformationController();
  bool _thirds = false;
  bool _golden = false;
  bool _diagonal = false;
  _GridMode _grid = _GridMode.nine;
  int _rows = 6;
  int _cols = 6;
  bool _square = false;
  int _cells = 8;
  bool _labels = false;
  _LineColor _lineColor = _LineColor.white;
  double _opacity = 0.85;
  ExamPaper? _paper;
  late bool _landscape = widget.image.width >= widget.image.height;
  double _shift = 0.5;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Size get _imageSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  /// 构图范围（相对图片 0–1）：未选画纸时为整张图。
  Rect get _frame {
    final paper = _paper;
    if (paper == null) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    final size = _imageSize;
    final rect = fitAspectRect(
      size,
      paper.aspect(landscape: _landscape),
      shift: _shift,
    );
    return Rect.fromLTRB(
      rect.left / size.width,
      rect.top / size.height,
      rect.right / size.width,
      rect.bottom / size.height,
    );
  }

  /// 裁切框在图片里还能移动的方向。
  bool get _cropMovable {
    final frame = _frame;
    return _paper != null && (frame.width < 0.999 || frame.height < 0.999);
  }

  ({int rows, int cols})? get _gridCount => switch (_grid) {
    _GridMode.none => null,
    _GridMode.nine => (rows: 3, cols: 3),
    _GridMode.custom => _square ? null : (rows: _rows, cols: _cols),
  };

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context) {
    final image = widget.image;
    return ToolStage(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fitted = applyBoxFit(
            BoxFit.contain,
            _imageSize,
            Size(
              (constraints.maxWidth - 24).clamp(1.0, double.infinity),
              (constraints.maxHeight - 24).clamp(1.0, double.infinity),
            ),
          ).destination;
          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transform,
                  maxScale: 8,
                  child: Center(
                    child: SizedBox(
                      width: fitted.width,
                      height: fitted.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RawImage(
                            image: image.image,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.medium,
                          ),
                          CustomPaint(
                            painter: _GridPainter(
                              frame: _frame,
                              cropped: _paper != null,
                              thirds: _thirds,
                              golden: _golden,
                              diagonal: _diagonal,
                              grid: _gridCount,
                              squareCells: _grid == _GridMode.custom && _square
                                  ? _cells
                                  : null,
                              labels: _labels && _grid != _GridMode.none,
                              color: _lineColor.color,
                              opacity: _opacity,
                              transform: _transform,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpace.s12,
                top: AppSpace.s12,
                child: StageLabel(_stageLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  String get _stageLabel {
    final parts = <String>[
      if (_paper != null)
        '${_paper!.label} ${_paper!.sizeText(landscape: _landscape)}',
      if (_grid == _GridMode.nine) '九宫格',
      if (_grid == _GridMode.custom)
        _square ? '正方形格 · 长边 $_cells 格' : '$_rows × $_cols 网格',
    ];
    return parts.isEmpty ? '构图辅助线' : parts.join(' · ');
  }

  String get _enlargeHint {
    final paper = _paper;
    final count = _gridCount;
    if (_grid == _GridMode.none) {
      return '打开九宫格或自定义网格后，可以按格子对照起形。';
    }
    if (paper == null) {
      return '选择画纸比例后，会算出画纸上每格的实际尺寸。';
    }
    if (count == null) {
      final longMm = paper.longMm;
      return '${paper.label}画纸长边 ${longMm.round()}mm 分 $_cells 格，每格约 ${(longMm / _cells).round()}mm 见方。';
    }
    final cell = paperCellMm(
      paper,
      landscape: _landscape,
      rows: count.rows,
      cols: count.cols,
    );
    return '${paper.label}${_landscape ? '横向' : '竖向'} ${paper.sizeText(landscape: _landscape)}，'
        '${count.cols} 列 × ${count.rows} 行，每格约 ${cell.width.round()}×${cell.height.round()}mm。';
  }

  Widget _buildPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '构图线',
          trailing: const Text('可同时打开'),
          child: Column(
            children: [
              ToolSwitchRow(
                label: '三分法',
                hint: '主体放在交点附近更稳定、不呆板',
                value: _thirds,
                onChanged: (v) => setState(() => _thirds = v),
              ),
              ToolSwitchRow(
                label: '黄金分割',
                hint: '0.382 与 0.618 分割线',
                value: _golden,
                onChanged: (v) => setState(() => _golden = v),
              ),
              ToolSwitchRow(
                label: '对角线',
                hint: '检查主体与动势是否沿对角线展开',
                value: _diagonal,
                onChanged: (v) => setState(() => _diagonal = v),
              ),
            ],
          ),
        ),
        ToolPanelSection(
          title: '网格',
          child: ToolSegmented<_GridMode>(
            values: _GridMode.values,
            value: _grid,
            labelOf: (m) => m.label,
            onChanged: (m) => setState(() => _grid = m),
          ),
        ),
        if (_grid == _GridMode.custom) ...[
          ToolSwitchRow(
            label: '正方形格子',
            hint: '按长边等分，格子都是正方形',
            value: _square,
            onChanged: (v) => setState(() => _square = v),
          ),
          if (_square)
            ToolSliderRow(
              label: '长边格数',
              value: _cells.toDouble(),
              min: 2,
              max: 16,
              divisions: 14,
              valueLabel: '$_cells',
              onChanged: (v) => setState(() => _cells = v.round()),
            )
          else ...[
            ToolSliderRow(
              label: '行数',
              value: _rows.toDouble(),
              min: 2,
              max: 12,
              divisions: 10,
              valueLabel: '$_rows',
              onChanged: (v) => setState(() => _rows = v.round()),
            ),
            ToolSliderRow(
              label: '列数',
              value: _cols.toDouble(),
              min: 2,
              max: 12,
              divisions: 10,
              valueLabel: '$_cols',
              onChanged: (v) => setState(() => _cols = v.round()),
            ),
          ],
        ],
        if (_grid != _GridMode.none)
          ToolSwitchRow(
            label: '格子编号',
            hint: '列 A、B、C…，行 1、2、3…，方便对照临摹',
            value: _labels,
            onChanged: (v) => setState(() => _labels = v),
          ),
        ToolPanelSection(
          title: '画纸比例',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ToolSegmented<ExamPaper?>(
                values: const [null, ...ExamPaper.values],
                value: _paper,
                labelOf: (paper) => paper?.label ?? '不裁切',
                onChanged: (p) => setState(() {
                  _paper = p;
                  _shift = 0.5;
                }),
              ),
              if (_paper != null) ...[
                const SizedBox(height: AppSpace.s8),
                ToolSegmented<bool>(
                  values: const [true, false],
                  value: _landscape,
                  labelOf: (landscape) => landscape ? '横向' : '竖向',
                  onChanged: (v) => setState(() {
                    _landscape = v;
                    _shift = 0.5;
                  }),
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  '${_paper!.label} ${_paper!.sizeText(landscape: _landscape)}，框外为裁掉的部分',
                  style: AppText.caption12,
                ),
              ],
            ],
          ),
        ),
        if (_cropMovable)
          ToolSliderRow(
            label: '裁切位置',
            value: _shift,
            min: 0,
            max: 1,
            valueLabel: '${(_shift * 100).round()}%',
            onChanged: (v) => setState(() => _shift = v),
          ),
        ToolPanelSection(
          title: '线条颜色',
          child: ToolSegmented<_LineColor>(
            values: _LineColor.values,
            value: _lineColor,
            labelOf: (c) => c.label,
            onChanged: (c) => setState(() => _lineColor = c),
          ),
        ),
        ToolSliderRow(
          label: '不透明度',
          value: _opacity,
          min: 0.2,
          max: 1,
          valueLabel: '${(_opacity * 100).round()}%',
          onChanged: (v) => setState(() => _opacity = v),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: '复位缩放',
            icon: Icons.zoom_out_map_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () => _transform.value = Matrix4.identity(),
          ),
        ),
        const SizedBox(height: AppSpace.s20),
        ToolTipCard(
          title: '网格放大法',
          icon: Icons.grid_on_rounded,
          text:
              '在参考图和画纸上画出行列数相同的网格，逐格对照，把形体的位置和角度移到画纸上：先定大的比例与位置，再深入细节。'
              '$_enlargeHint',
        ),
      ],
    );
  }
}

/// 网格画在与图片等大的区域上；线宽与文字按当前缩放倍数反向补偿，放大后仍保持细线。
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.frame,
    required this.cropped,
    required this.thirds,
    required this.golden,
    required this.diagonal,
    required this.grid,
    required this.squareCells,
    required this.labels,
    required this.color,
    required this.opacity,
    required this.transform,
  }) : super(repaint: transform);

  /// 构图范围（相对图片 0–1）。
  final Rect frame;
  final bool cropped;
  final bool thirds;
  final bool golden;
  final bool diagonal;
  final ({int rows, int cols})? grid;
  final int? squareCells;
  final bool labels;
  final Color color;
  final double opacity;
  final TransformationController transform;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.value.getMaxScaleOnAxis().clamp(1.0, 100.0);
    final area = Rect.fromLTRB(
      frame.left * size.width,
      frame.top * size.height,
      frame.right * size.width,
      frame.bottom * size.height,
    );
    if (cropped) {
      final shade = Paint()..color = AppColors.ink.withValues(alpha: 0.55);
      canvas.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRect(area),
        shade,
      );
    }
    final lineColor = color.withValues(alpha: opacity);
    final haloColor =
        (color.computeLuminance() > 0.5 ? AppColors.ink : AppColors.surface)
            .withValues(alpha: opacity * 0.28);
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1.4 / scale
      ..style = PaintingStyle.stroke;
    final strong = Paint()
      ..color = lineColor
      ..strokeWidth = 2 / scale
      ..style = PaintingStyle.stroke;
    final halo = Paint()
      ..color = haloColor
      ..strokeWidth = 3.2 / scale
      ..style = PaintingStyle.stroke;

    void drawLine(Offset a, Offset b, [Paint? paint]) {
      canvas
        ..drawLine(a, b, halo)
        ..drawLine(a, b, paint ?? line);
    }

    double x(double t) => area.left + area.width * t;
    double y(double t) => area.top + area.height * t;

    final count = grid;
    if (count != null) {
      for (final t in evenFractions(count.cols)) {
        drawLine(Offset(x(t), area.top), Offset(x(t), area.bottom));
      }
      for (final t in evenFractions(count.rows)) {
        drawLine(Offset(area.left, y(t)), Offset(area.right, y(t)));
      }
    }
    final cells = squareCells;
    if (cells != null) {
      final lines = squareGridLines(area.size, cells);
      for (final dx in lines.xs) {
        drawLine(
          Offset(area.left + dx, area.top),
          Offset(area.left + dx, area.bottom),
        );
      }
      for (final dy in lines.ys) {
        drawLine(
          Offset(area.left, area.top + dy),
          Offset(area.right, area.top + dy),
        );
      }
    }
    void powerLines(List<double> fractions, double dot) {
      for (final t in fractions) {
        drawLine(Offset(x(t), area.top), Offset(x(t), area.bottom), strong);
        drawLine(Offset(area.left, y(t)), Offset(area.right, y(t)), strong);
      }
      final fill = Paint()..color = lineColor;
      final ring = Paint()..color = haloColor;
      for (final tx in fractions) {
        for (final ty in fractions) {
          final center = Offset(x(tx), y(ty));
          canvas
            ..drawCircle(center, (dot + 2) / scale, ring)
            ..drawCircle(center, dot / scale, fill);
        }
      }
    }

    if (thirds) {
      powerLines(const [1 / 3, 2 / 3], 4);
    }
    if (golden) {
      powerLines(const [kGoldenMinor, kGoldenMajor], 3);
    }
    if (diagonal) {
      drawLine(area.topLeft, area.bottomRight, strong);
      drawLine(area.topRight, area.bottomLeft, strong);
    }
    canvas.drawRect(area, cropped ? strong : line);
    if (labels) {
      _paintLabels(canvas, area, scale, lineColor, haloColor);
    }
  }

  void _paintLabels(
    Canvas canvas,
    Rect area,
    double scale,
    Color textColor,
    Color haloColor,
  ) {
    final style = AppText.number(size: 12, color: textColor).copyWith(
      fontSize: 12 / scale,
      shadows: [Shadow(color: haloColor, blurRadius: 3 / scale)],
    );
    void paintText(String text, Offset Function(Size textSize) position) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painter.paint(canvas, position(painter.size));
      painter.dispose();
    }

    final margin = 4 / scale;
    final List<double> columnCenters;
    final List<double> rowCenters;
    final count = grid;
    if (count != null) {
      columnCenters = [
        for (var c = 0; c < count.cols; c++)
          area.left + area.width * (c + 0.5) / count.cols,
      ];
      rowCenters = [
        for (var r = 0; r < count.rows; r++)
          area.top + area.height * (r + 0.5) / count.rows,
      ];
    } else {
      final lines = squareGridLines(area.size, squareCells ?? 1);
      final cell = lines.cell;
      columnCenters = [
        for (var v = cell / 2; v < area.width; v += cell) area.left + v,
      ];
      rowCenters = [
        for (var v = cell / 2; v < area.height; v += cell) area.top + v,
      ];
    }
    for (var c = 0; c < columnCenters.length && c < 26; c++) {
      paintText(
        String.fromCharCode(65 + c),
        (s) => Offset(columnCenters[c] - s.width / 2, area.top + margin),
      );
    }
    for (var r = 0; r < rowCenters.length; r++) {
      paintText(
        '${r + 1}',
        (s) => Offset(area.left + margin, rowCenters[r] - s.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.frame != frame ||
      old.cropped != cropped ||
      old.thirds != thirds ||
      old.golden != golden ||
      old.diagonal != diagonal ||
      old.grid != grid ||
      old.squareCells != squareCells ||
      old.labels != labels ||
      old.color != color ||
      old.opacity != opacity ||
      old.transform != transform;
}
