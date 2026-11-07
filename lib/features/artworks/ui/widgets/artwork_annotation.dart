import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/ui/ui.dart';
import '../../data/artwork_models.dart';

/// 批注线宽的基准图宽：在不同尺寸下显示时按比例缩放，保持与作品的相对粗细。
const double kAnnotationReferenceWidth = 600;

String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// 批注笔（以 `#HEX` 保存到接口）：红 / 蓝 / 黑，取自色板与素描科目色。
final kAnnotationPenColors = <String>[
  _hexOf(AppColors.danger),
  _hexOf(ArtSubject.sketch.accent),
  _hexOf(AppColors.ink),
];

/// 批注线宽：细 / 中 / 粗。
const kAnnotationPenWidths = <double>[2, 4, 7];

@immutable
class AnnotationPen {
  const AnnotationPen({required this.color, required this.width});

  final String color;
  final double width;

  @override
  bool operator ==(Object other) =>
      other is AnnotationPen && other.color == color && other.width == width;

  @override
  int get hashCode => Object.hash(color, width);
}

/// 作品图 + 批注层：图片按原始比例完整显示，批注坐标相对图片归一化。
///
/// 传入 [pen] 时进入绘制模式，每画完一笔回调 [onStrokeEnd]。
class ArtworkAnnotatedImage extends StatefulWidget {
  const ArtworkAnnotatedImage({
    required this.url,
    this.strokes = const <AnnotationStroke>[],
    this.pen,
    this.imageIndex = 0,
    this.onStrokeEnd,
    this.onTap,
    super.key,
  });

  final String url;
  final List<AnnotationStroke> strokes;
  final AnnotationPen? pen;
  final int imageIndex;
  final ValueChanged<AnnotationStroke>? onStrokeEnd;
  final VoidCallback? onTap;

  @override
  State<ArtworkAnnotatedImage> createState() => _ArtworkAnnotatedImageState();
}

class _ArtworkAnnotatedImageState extends State<ArtworkAnnotatedImage> {
  final _active = _ActiveStroke();
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;
  bool _failed = false;

  ImageProvider get _provider =>
      CachedNetworkImageProvider(MediaUrl.resolve(widget.url));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ArtworkAnnotatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _imageSize = null;
      _failed = false;
      _resolve();
    }
  }

  @override
  void dispose() {
    _detach();
    _active.dispose();
    super.dispose();
  }

  void _resolve() {
    if (widget.url.trim().isEmpty) {
      _detach();
      _failed = true;
      return;
    }
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (_stream != null && stream.key == _stream!.key) {
      return;
    }
    _detach();
    final listener = ImageStreamListener(
      (info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        info.dispose();
        if (mounted) {
          setState(() => _imageSize = size);
        }
      },
      onError: (_, _) {
        if (mounted) {
          setState(() => _failed = true);
        }
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _detach() {
    final listener = _listener;
    if (listener != null) {
      _stream?.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  Offset _normalize(Offset local, Size box) => Offset(
    (local.dx / box.width).clamp(0.0, 1.0),
    (local.dy / box.height).clamp(0.0, 1.0),
  );

  void _finishStroke() {
    final pen = widget.pen;
    final points = _active.finish();
    if (pen == null || points.isEmpty) {
      return;
    }
    widget.onStrokeEnd?.call(
      AnnotationStroke(
        color: pen.color,
        width: pen.width,
        points: points,
        imageIndex: widget.imageIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = _imageSize;
        if (imageSize == null || imageSize.isEmpty) {
          return _Placeholder(failed: _failed);
        }
        final box = _containedSize(imageSize, constraints);
        final pen = widget.pen;
        return Center(
          child: SizedBox(
            width: box.width,
            height: box.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: _provider,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _AnnotationPainter(
                      strokes: widget.strokes,
                      active: _active,
                      pen: pen,
                    ),
                  ),
                ),
                if (pen != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onPanStart: (d) =>
                        _active.begin(_normalize(d.localPosition, box)),
                    onPanUpdate: (d) =>
                        _active.add(_normalize(d.localPosition, box)),
                    onPanEnd: (_) => _finishStroke(),
                    onPanCancel: _finishStroke,
                  )
                else if (widget.onTap != null)
                  AppPressable(
                    onTap: widget.onTap,
                    semanticLabel: '查看大图',
                    child: const SizedBox.expand(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Size _containedSize(Size image, BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : kAnnotationReferenceWidth;
    final maxHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : maxWidth * image.height / image.width;
    final scale = math.min(maxWidth / image.width, maxHeight / image.height);
    return Size(image.width * scale, image.height * scale);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: failed
          ? const Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: AppColors.textPlaceholder,
            )
          : const AppLoadingIndicator(size: 28),
    );
  }
}

class _ActiveStroke extends ChangeNotifier {
  final List<Offset> points = <Offset>[];

  void begin(Offset point) {
    points
      ..clear()
      ..add(point);
    notifyListeners();
  }

  void add(Offset point) {
    if (points.isEmpty || (points.last - point).distance < 0.002) {
      return;
    }
    points.add(point);
    notifyListeners();
  }

  List<Offset> finish() {
    final result = List<Offset>.of(points);
    points.clear();
    notifyListeners();
    return result;
  }
}

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter({required this.strokes, required this.active, this.pen})
    : super(repaint: active);

  final List<AnnotationStroke> strokes;
  final _ActiveStroke active;
  final AnnotationPen? pen;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / kAnnotationReferenceWidth;
    for (final stroke in strokes) {
      _paintStroke(
        canvas,
        size,
        stroke.points,
        ArtColors.fromHex(stroke.color, fallback: AppColors.danger),
        stroke.width * scale,
      );
    }
    final current = pen;
    if (current != null && active.points.isNotEmpty) {
      _paintStroke(
        canvas,
        size,
        active.points,
        ArtColors.fromHex(current.color, fallback: AppColors.danger),
        current.width * scale,
      );
    }
  }

  void _paintStroke(
    Canvas canvas,
    Size size,
    List<Offset> points,
    Color color,
    double width,
  ) {
    if (points.isEmpty) {
      return;
    }
    final strokeWidth = math.max(1.0, width);
    Offset at(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    if (points.length == 1) {
      canvas.drawCircle(
        at(points.first),
        strokeWidth / 2,
        Paint()..color = color,
      );
      return;
    }
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final point in points.skip(1)) {
      final p = at(point);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes) ||
      oldDelegate.pen != pen ||
      oldDelegate.active != active;
}
