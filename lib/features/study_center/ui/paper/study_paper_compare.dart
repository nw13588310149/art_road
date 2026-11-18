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

/// 对照样图：我的原卷和这一科最高档的样图同样高度并排，名称写在画的上方
/// （`AppCompareView`）。默认锁定，放大一张，另一张看同一处；画布下面一行是提示
/// 和锁定、旋转、翻转、交换、复位。水印盖在原卷的画框上，缩放时不跟着移动，
/// 看到的每一处都有水印。
class StudyPaperCompareView extends StatelessWidget {
  const StudyPaperCompareView({
    required this.paper,
    required this.standard,
    required this.controller,
    required this.onRetryPaper,
    required this.onRetryStandard,
    super.key,
  });

  final AsyncValue<StudyPaper> paper;
  final AsyncValue<GradeStandard> standard;
  final AppCompareController controller;
  final VoidCallback onRetryPaper;
  final VoidCallback onRetryStandard;

  static const _mineLabel = '我的原卷';

  AppComparePane _minePane() {
    return paper.when(
      loading: () => const AppComparePane.placeholder(
        label: _mineLabel,
        child: Center(child: AppLoadingIndicator(size: 36)),
      ),
      error: (error, _) => AppComparePane.placeholder(
        label: _mineLabel,
        child: StudyPaperMessage(
          icon: Icons.cloud_off_rounded,
          text: studyErrorText(error, '原卷加载失败'),
          actionLabel: '重试',
          onAction: onRetryPaper,
        ),
      ),
      data: (value) => value.viewable
          ? AppComparePane(
              label: _mineLabel,
              image: _provider(value.imageUrl),
              overlay: StudyPaperWatermark(text: value.watermarkText),
              child: StudyPaperImage(url: value.imageUrl),
            )
          : AppComparePane.placeholder(
              label: _mineLabel,
              child: StudyPaperMessage(
                icon: Icons.image_not_supported_outlined,
                text: value.message.isEmpty ? '该科暂无原卷' : value.message,
              ),
            ),
    );
  }

  AppComparePane _samplePane() {
    final grade = standard.valueOrNull?.topBand?.grade ?? 'A';
    final label = '$grade 档样图';
    return standard.when(
      loading: () => AppComparePane.placeholder(
        label: label,
        child: const Center(child: AppLoadingIndicator(size: 36)),
      ),
      error: (error, _) => AppComparePane.placeholder(
        label: label,
        child: StudyPaperMessage(
          icon: Icons.cloud_off_rounded,
          text: studyErrorText(error, '样图加载失败'),
          actionLabel: '重试',
          onAction: onRetryStandard,
        ),
      ),
      data: (value) {
        final url = value.topBand?.imageUrl ?? '';
        return url.isEmpty
            ? AppComparePane.placeholder(
                label: label,
                child: StudyPaperMessage(
                  icon: Icons.image_not_supported_outlined,
                  text: '该科暂无 $grade 档样图',
                ),
              )
            : AppComparePane(
                label: label,
                image: _provider(url),
                child: StudyPaperImage(url: url),
              );
      },
    );
  }

  static ImageProvider _provider(String url) =>
      CachedNetworkImageProvider(MediaUrl.resolve(url));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppCanvasLayout.radius,
              child: ColoredBox(
                color: AppColors.canvasDark,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s16,
                    0,
                    AppSpace.s16,
                    AppSpace.s16,
                  ),
                  child: AppCompareView(
                    controller: controller,
                    first: _minePane(),
                    second: _samplePane(),
                    dark: true,
                    autofocus: true,
                  ),
                ),
              ),
            ),
          ),
          AppCompareFooter(controller: controller),
        ],
      ),
    );
  }
}

/// 一张卷子：完整显示，加载中转圈，失败显示提示。缩放由外面的对比画布负责。
class StudyPaperImage extends StatelessWidget {
  const StudyPaperImage({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: CachedNetworkImageProvider(MediaUrl.resolve(url)),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame == null && !wasSynchronouslyLoaded
          ? const Center(child: AppLoadingIndicator(size: 36))
          : child,
      errorBuilder: (context, error, stackTrace) => const StudyPaperMessage(
        icon: Icons.broken_image_outlined,
        text: '图片加载失败',
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
