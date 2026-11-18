import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';

/// 画布里的一块画面。画布本身（中性灰底、圆角）由 `AppCanvasLayout` 给出，
/// 这里只负责名称：[label] 写在画面上方一行，不压在画上。
class ToolStage extends StatelessWidget {
  const ToolStage({required this.child, this.label, super.key});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) {
      return child;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s12,
            AppSpace.s12,
            AppSpace.s12,
            0,
          ),
          child: SizedBox(height: 24, child: StageLabel(text)),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// 画面上方的名称（原图、3 阶色阶、九宫格…）：12 号二级文字，居中，一行。
class StageLabel extends StatelessWidget {
  const StageLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppText.caption12.copyWith(color: AppColors.textSecondary),
    );
  }
}

/// 等比完整显示一张图；[image] 为空时显示处理中，[failed] 时显示错误状态与重试。
/// 有 [label] 时名称紧贴在图的上方。
class StageImagePane extends StatelessWidget {
  const StageImagePane({
    required this.image,
    this.label,
    this.failed = false,
    this.onRetry,
    super.key,
  });

  final ui.Image? image;
  final String? label;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image == null) {
      final state = failed
          ? AppErrorState(
              title: '处理失败',
              description: '这张图片暂时无法处理，可以重试或换一张图片',
              icon: Icons.broken_image_outlined,
              onRetry: onRetry,
            )
          : const Center(child: AppLoadingIndicator(size: 32));
      return ToolStage(label: label, child: state);
    }
    return LabeledStage(
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      label: label,
      child: RawImage(
        image: image,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// 把一张画按原比例放进画布（四周留 12），[label] 写在画的正上方一行。
/// [child] 拿到的就是画所占的那块区域，按 `BoxFit.fill` 画即可。
class LabeledStage extends StatelessWidget {
  const LabeledStage({
    required this.imageSize,
    required this.child,
    this.label,
    super.key,
  });

  final Size imageSize;
  final String? label;
  final Widget child;

  static const double _inset = AppSpace.s12;
  static const double _labelExtent = 26;

  @override
  Widget build(BuildContext context) {
    final text = label;
    return LayoutBuilder(
      builder: (context, box) {
        final reserved = text == null ? 0.0 : _labelExtent;
        final fitted = applyBoxFit(
          BoxFit.contain,
          imageSize,
          Size(
            (box.maxWidth - _inset * 2).clamp(1.0, double.infinity),
            (box.maxHeight - _inset * 2 - reserved).clamp(1.0, double.infinity),
          ),
        ).destination;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (text != null)
                SizedBox(
                  width: math.max(fitted.width, 120),
                  height: _labelExtent,
                  child: StageLabel(text),
                ),
              SizedBox.fromSize(size: fitted, child: child),
            ],
          ),
        );
      },
    );
  }
}

/// 处理结果与原图：打开对比时左右并排、同样高度，各自的名称写在上方；否则只显示结果。
class CompareStage extends StatelessWidget {
  const CompareStage({
    required this.original,
    required this.processed,
    required this.label,
    required this.compare,
    this.failed = false,
    this.onRetry,
    super.key,
  });

  final ui.Image original;
  final ui.Image? processed;
  final String label;
  final bool compare;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final result = StageImagePane(
      image: processed,
      label: label,
      failed: failed,
      onRetry: onRetry,
    );
    if (!compare) {
      return result;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: StageImagePane(image: original, label: '原图'),
        ),
        Expanded(child: result),
      ],
    );
  }
}
