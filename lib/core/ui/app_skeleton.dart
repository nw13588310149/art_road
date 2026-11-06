import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// 加载骨架：静态浅灰块，没有闪光动画。骨架应与最终布局同尺寸，避免加载完跳动。
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    this.width,
    this.height = 14,
    this.radius = AppRadius.checkbox,
    super.key,
  }) : circle = false;

  /// 圆形占位（头像）。
  const AppSkeleton.circle({required double size, super.key})
    : width = size,
      height = size,
      radius = 0,
      circle = true;

  /// 为 null 时撑满父级宽度。
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// 段落骨架：[lines] 行文字占位，最后一行缩短到 60%。
class AppSkeletonText extends StatelessWidget {
  const AppSkeletonText({this.lines = 3, this.lineHeight = 14, super.key});

  final int lines;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 240.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lines; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.s8),
              AppSkeleton(
                width: i == lines - 1 && lines > 1 ? full * 0.6 : full,
                height: lineHeight,
              ),
            ],
          ],
        );
      },
    );
  }
}
