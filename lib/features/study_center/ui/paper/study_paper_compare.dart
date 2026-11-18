import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_models.dart';
import '../../state/study_detail_providers.dart';
import 'study_paper_watermark.dart';

/// 深色画布上的次级文字。
final _onDarkMuted = AppColors.onBrand.withValues(alpha: 0.64);

/// 对照样图：我的原卷和这一科最高档的样图同样高度并排，名称写在画的上方；
/// 中间的分隔条可以拖动，双击复位。
class StudyPaperCompareView extends StatelessWidget {
  const StudyPaperCompareView({
    required this.paper,
    required this.standard,
    required this.split,
    required this.onSplitChanged,
    required this.onRetryPaper,
    required this.onRetryStandard,
    super.key,
  });

  final AsyncValue<StudyPaper> paper;
  final AsyncValue<GradeStandard> standard;

  /// 左栏占比 0.2–0.8。
  final double split;
  final ValueChanged<double> onSplitChanged;
  final VoidCallback onRetryPaper;
  final VoidCallback onRetryStandard;

  static const _handleWidth = 24.0;
  static const _labelHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    final sampleGrade = standard.valueOrNull?.topBand?.grade ?? 'A';
    final mine = paper.when(
      loading: () => const Center(child: AppLoadingIndicator(size: 36)),
      error: (error, _) => StudyPaperMessage(
        icon: Icons.cloud_off_rounded,
        text: studyErrorText(error, '原卷加载失败'),
        actionLabel: '重试',
        onAction: onRetryPaper,
      ),
      data: (value) => value.viewable
          ? Stack(
              fit: StackFit.expand,
              children: [
                StudyZoomableImage(
                  key: ValueKey(value.imageUrl),
                  url: value.imageUrl,
                ),
                Positioned.fill(
                  child: StudyPaperWatermark(text: value.watermarkText),
                ),
              ],
            )
          : StudyPaperMessage(
              icon: Icons.image_not_supported_outlined,
              text: value.message.isEmpty ? '该科暂无原卷' : value.message,
            ),
    );
    final sample = standard.when(
      loading: () => const Center(child: AppLoadingIndicator(size: 36)),
      error: (error, _) => StudyPaperMessage(
        icon: Icons.cloud_off_rounded,
        text: studyErrorText(error, '样图加载失败'),
        actionLabel: '重试',
        onAction: onRetryStandard,
      ),
      data: (value) {
        final url = value.topBand?.imageUrl ?? '';
        return url.isEmpty
            ? StudyPaperMessage(
                icon: Icons.image_not_supported_outlined,
                text: '该科暂无 $sampleGrade 档样图',
              )
            : StudyZoomableImage(key: ValueKey(url), url: url);
      },
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = math.max(0.0, constraints.maxWidth - _handleWidth);
          final leftWidth = available * split;
          Widget pane(String label, Widget child, double width) => SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _labelHeight,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: AppCanvasLayout.radius,
                    child: ColoredBox(
                      color: AppColors.canvasDark,
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    pane('我的原卷', mine, leftWidth),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: available <= 0
                          ? null
                          : (details) => onSplitChanged(
                              ((leftWidth + details.delta.dx) / available)
                                  .clamp(0.2, 0.8),
                            ),
                      onDoubleTap: () => onSplitChanged(0.5),
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: SizedBox(
                          width: _handleWidth,
                          child: Padding(
                            padding: EdgeInsets.only(top: _labelHeight),
                            child: _DividerHandle(),
                          ),
                        ),
                      ),
                    ),
                    pane('$sampleGrade 档样图', sample, available - leftWidth),
                  ],
                ),
              ),
              SizedBox(
                height: AppCanvasLayout.footerHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '双指缩放 · 拖动中间的分隔条调整宽度，双击复位',
                    style: AppText.caption12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DividerHandle extends StatelessWidget {
  const _DividerHandle();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 1, color: AppColors.line),
        Container(
          width: 16,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.br8,
            border: Border.all(color: AppColors.line),
          ),
          child: const RotatedBox(
            quarterTurns: 1,
            child: Icon(
              Icons.drag_handle_rounded,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

class StudyZoomableImage extends StatelessWidget {
  const StudyZoomableImage({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image(
          image: CachedNetworkImageProvider(MediaUrl.resolve(url)),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              frame == null && !wasSynchronouslyLoaded
              ? const Center(child: AppLoadingIndicator(size: 36))
              : child,
          errorBuilder: (context, error, stackTrace) => const StudyPaperMessage(
            icon: Icons.broken_image_outlined,
            text: '图片加载失败',
          ),
        ),
      ),
    );
  }
}

/// 画布里的提示：默认在深色画布上；[dark] 为 false 时用在白色底板上。
class StudyPaperMessage extends StatelessWidget {
  const StudyPaperMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.dark = true,
    super.key,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: dark ? _onDarkMuted : AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpace.s12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppText.body14.copyWith(
                color: dark ? AppColors.onBrand : AppColors.ink,
              ),
            ),
            if (label != null && action != null) ...[
              const SizedBox(height: AppSpace.s16),
              AppButton(
                label: label,
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: action,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
