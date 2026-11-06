import 'dart:math' as math;
import 'dart:ui';

/// 图片以 contain 方式放在容器里时，容器坐标与图片坐标的换算。
class ContainMapping {
  factory ContainMapping(Size box, int imageWidth, int imageHeight) {
    final scale = math.min(box.width / imageWidth, box.height / imageHeight);
    return ContainMapping._(
      imageWidth,
      imageHeight,
      scale,
      Offset(
        (box.width - imageWidth * scale) / 2,
        (box.height - imageHeight * scale) / 2,
      ),
    );
  }

  const ContainMapping._(
    this.imageWidth,
    this.imageHeight,
    this.scale,
    this.offset,
  );

  final int imageWidth;
  final int imageHeight;
  final double scale;
  final Offset offset;

  Rect get imageRect => offset & Size(imageWidth * scale, imageHeight * scale);

  /// 图片像素 → 容器坐标。
  Offset toBox(Offset pixel) => offset + pixel * scale;

  /// 容器坐标 → 图片像素（夹在图片范围内）。
  Offset toImage(Offset local) {
    final p = (local - offset) / scale;
    return Offset(
      p.dx.clamp(0, imageWidth.toDouble()),
      p.dy.clamp(0, imageHeight.toDouble()),
    );
  }

  /// 图片 0–1 归一化坐标 → 容器坐标。
  Offset fromUnit(Offset unit) =>
      offset + Offset(unit.dx * imageWidth, unit.dy * imageHeight) * scale;

  /// 容器坐标 → 图片 0–1 归一化坐标（不夹取）。
  Offset toUnit(Offset local) {
    final p = (local - offset) / scale;
    return Offset(p.dx / imageWidth, p.dy / imageHeight);
  }
}
