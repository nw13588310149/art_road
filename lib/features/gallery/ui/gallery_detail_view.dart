import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/art/art_tokens.dart';
import '../../../core/network/media_url.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../data/gallery_models.dart';
import 'gallery_compare_page.dart';
import 'widgets/gallery_widgets.dart';

/// 范画详情（在范画库页内展示，返回回到列表或上一幅作品）。
class GalleryDetailView extends StatelessWidget {
  const GalleryDetailView({
    required this.detail,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onRetry,
    required this.onToggleFavorite,
    required this.onOpenWork,
    required this.onTagSelected,
    super.key,
  });

  final GalleryWorkDetail? detail;
  final bool loading;
  final String error;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final ValueChanged<GalleryWork> onToggleFavorite;
  final ValueChanged<String> onOpenWork;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    if (detail == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(title: '范画详情', onBack: onBack),
          Expanded(
            child: error.isNotEmpty && !loading
                ? AppErrorState(
                    title: '范画加载失败',
                    description: error,
                    onRetry: onRetry,
                  )
                : const Center(child: AppLoadingIndicator(size: 36)),
          ),
        ],
      );
    }
    final work = detail.work;
    final imageUrl = MediaUrl.resolve(work.imageUrl);
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = AppPageHeader(
          title: work.title,
          subtitle: _subtitleOf(work),
          onBack: onBack,
          actions: [
            AppIconButton(
              icon: Icons.fullscreen_rounded,
              semanticLabel: '全屏查看',
              size: AppButtonSize.sm,
              onTap: imageUrl.isEmpty
                  ? null
                  : () => showImageGallery(
                      context,
                      images: [imageUrl],
                      heroTagPrefix: 'gallery_${work.id}',
                    ),
            ),
          ],
        );
        final info = _DetailInfo(
          detail: detail,
          onToggleFavorite: () => onToggleFavorite(work),
          onOpenWork: onOpenWork,
          onTagSelected: onTagSelected,
          onOpenGrid: () => Navigator.of(context).pushNamed(
            RoutePaths.artToolbox,
            arguments: <String, dynamic>{
              'tool': 'grid',
              'imageUrl': work.imageUrl,
              'title': work.title,
            },
          ),
          onCompare: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => GalleryComparePage(work: work),
            ),
          ),
        );
        if (constraints.maxWidth >= 760) {
          final panelWidth = (constraints.maxWidth * 0.36)
              .clamp(300.0, 380.0)
              .toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    AppSpace.s4,
                    AppSpace.page,
                    AppSpace.s20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _ArtworkStage(work: work)),
                      const SizedBox(width: AppSpace.s16),
                      SizedBox(
                        width: panelWidth,
                        child: SingleChildScrollView(child: info),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  AppSpace.s4,
                  AppSpace.page,
                  AppSpace.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ArtworkPreview(work: work),
                    const SizedBox(height: AppSpace.s16),
                    info,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _subtitleOf(GalleryWork work) {
    final parts = <String>[
      work.categoryLabel,
      if (work.source != GallerySource.examTop) work.source,
      work.author,
    ];
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }
}

/// 宽屏：可缩放的大图（双指 / 双击缩放），舞台底色与作品点评一致。
class _ArtworkStage extends StatelessWidget {
  const _ArtworkStage({required this.work});

  final GalleryWork work;

  @override
  Widget build(BuildContext context) {
    final url = MediaUrl.resolve(work.imageUrl);
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: Stack(
        children: [
          Positioned.fill(
            child: url.isEmpty
                ? const ColoredBox(color: AppColors.surfaceSubtle)
                : PhotoView(
                    key: ValueKey(url),
                    imageProvider: CachedNetworkImageProvider(url),
                    backgroundDecoration: const BoxDecoration(
                      color: AppColors.surfaceSubtle,
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    initialScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    filterQuality: FilterQuality.medium,
                    loadingBuilder: (context, event) =>
                        const Center(child: AppLoadingIndicator(size: 36)),
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textPlaceholder,
                        size: 36,
                      ),
                    ),
                  ),
          ),
          const Positioned(
            left: AppSpace.s12,
            bottom: AppSpace.s12,
            child: IgnorePointer(child: _StageHint(text: '双指缩放 · 双击放大')),
          ),
        ],
      ),
    );
  }
}

/// 窄屏：等比预览图，点击进入全屏查看（避免与页面滚动手势冲突）。
class _ArtworkPreview extends StatelessWidget {
  const _ArtworkPreview({required this.work});

  final GalleryWork work;

  @override
  Widget build(BuildContext context) {
    final url = MediaUrl.resolve(work.imageUrl);
    return AppPressable(
      onTap: url.isEmpty
          ? null
          : () => showImageGallery(
              context,
              images: [url],
              heroTagPrefix: 'gallery_${work.id}',
            ),
      semanticLabel: '查看大图',
      child: AppCard(
        color: AppColors.surfaceSubtle,
        bordered: false,
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: AspectRatio(
              aspectRatio: work.aspectRatio.clamp(0.5, 2.0).toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    src: work.imageUrl,
                    fit: BoxFit.contain,
                    borderRadius: AppRadius.br8,
                  ),
                  if (url.isNotEmpty)
                    const Positioned(
                      right: AppSpace.s8,
                      bottom: AppSpace.s8,
                      child: _StageHint(text: '点击查看大图'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageHint extends StatelessWidget {
  const _StageHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s8,
        vertical: AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.56),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        text,
        style: AppText.caption12.copyWith(color: AppColors.onBrand),
      ),
    );
  }
}

class _DetailInfo extends StatelessWidget {
  const _DetailInfo({
    required this.detail,
    required this.onToggleFavorite,
    required this.onOpenWork,
    required this.onTagSelected,
    required this.onOpenGrid,
    required this.onCompare,
  });

  final GalleryWorkDetail detail;
  final VoidCallback onToggleFavorite;
  final ValueChanged<String> onOpenWork;
  final ValueChanged<String> onTagSelected;
  final VoidCallback onOpenGrid;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final work = detail.work;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthorCard(work: work),
        const SizedBox(height: AppSpace.s12),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            AppButton(
              label: work.favorite ? '已收藏' : '收藏',
              icon: work.favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.sm,
              onTap: onToggleFavorite,
            ),
            AppButton(
              label: '临摹网格',
              icon: Icons.grid_on_rounded,
              variant: AppButtonVariant.quiet,
              size: AppButtonSize.sm,
              onTap: onOpenGrid,
            ),
            AppButton(
              label: '对比我的原卷',
              icon: Icons.compare_rounded,
              size: AppButtonSize.sm,
              onTap: onCompare,
            ),
          ],
        ),
        if (work.points.isNotEmpty) ...[
          const _Section(title: '点评要点'),
          for (var i = 0; i < work.points.length; i++)
            _PointRow(index: i + 1, text: work.points[i]),
        ],
        if (work.tags.isNotEmpty) ...[
          const _Section(title: '标签', subtitle: '点击标签查看同类范画'),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final tag in work.tags)
                AppChip(
                  label: tag,
                  icon: Icons.tag_rounded,
                  selected: false,
                  onTap: () => onTagSelected(tag),
                ),
            ],
          ),
        ],
        if (detail.description.isNotEmpty) ...[
          const _Section(title: '作品说明'),
          Text(
            detail.description,
            style: AppText.body14.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (detail.related.isNotEmpty) ...[
          const _Section(title: '相关作品'),
          _RelatedGrid(works: detail.related, onOpen: onOpenWork),
        ],
        const SizedBox(height: AppSpace.s16),
        Text(
          '${formatViewCount(work.views)} 次浏览 · 发布于 ${work.publishDate}',
          style: AppText.caption12,
        ),
        const SizedBox(height: AppSpace.s8),
      ],
    );
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.work});

  final GalleryWork work;

  @override
  Widget build(BuildContext context) {
    final subtitle = work.isExamPaper
        ? [
            work.authorTitle,
            work.examName,
          ].where((s) => s.isNotEmpty).join(' · ')
        : (work.authorTitle.isEmpty ? work.source : work.authorTitle);
    return AppCard(
      title: work.title,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Row(
        children: [
          AppAvatar(name: work.author.isEmpty ? '佚名' : work.author, size: 40),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work.author.isEmpty ? '佚名' : work.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          if (work.isExamPaper && work.score != null) ...[
            if (work.grade.isNotEmpty) ...[
              AppTag(
                label: '${work.grade} 档',
                tone: work.grade == 'A' ? AppTone.brand : AppTone.neutral,
              ),
              const SizedBox(width: AppSpace.s8),
            ],
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatScore(work.score),
                    style: AppText.number(size: 24, color: AppColors.brand),
                  ),
                  TextSpan(text: ' 分', style: AppText.caption12),
                ],
              ),
            ),
          ] else
            GallerySourceTag(source: work.source),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s20, bottom: AppSpace.s12),
      child: AppSectionHeader(title: title, subtitle: subtitle),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: AppText.number(size: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(child: Text(text, style: AppText.body14)),
        ],
      ),
    );
  }
}

class _RelatedGrid extends StatelessWidget {
  const _RelatedGrid({required this.works, required this.onOpen});

  final List<GalleryWork> works;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpace.s12;
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final work in works)
              SizedBox(
                width: itemWidth,
                child: AppPressable(
                  onTap: () => onOpen(work.id),
                  semanticLabel: work.title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: AppImage(
                          src: work.imageUrl,
                          borderRadius: AppRadius.br8,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        work.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body13.copyWith(color: AppColors.ink),
                      ),
                      Text(
                        work.isExamPaper && work.score != null
                            ? '${work.grade} 档 · ${formatScore(work.score)} 分'
                            : work.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
