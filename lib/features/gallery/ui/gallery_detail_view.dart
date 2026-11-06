import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/art/art_tokens.dart';
import '../../../core/network/media_url.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/art_widgets.dart';
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
          ArtPageHeader(title: '范画详情', onBack: onBack),
          Expanded(
            child: error.isNotEmpty && !loading
                ? ArtEmptyState(
                    icon: Icons.broken_image_outlined,
                    message: error,
                    actionLabel: '重新加载',
                    onAction: onRetry,
                  )
                : const Center(child: AppLoadingIndicator()),
          ),
        ],
      );
    }
    final work = detail.work;
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = ArtPageHeader(
          title: work.title,
          subtitle: _subtitleOf(work),
          onBack: onBack,
          actions: [
            _HeaderIconButton(
              icon: Icons.fullscreen_rounded,
              tooltip: '全屏查看',
              onTap: () => showImageGallery(
                context,
                images: [MediaUrl.resolve(work.imageUrl)],
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _ArtworkStage(work: work)),
                      const SizedBox(width: 20),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ArtworkPreview(work: work),
                    const SizedBox(height: 18),
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

const _stageColor = Color(0xFFF2F1F6);

/// 宽屏：可缩放的大图（双指 / 双击缩放）。
class _ArtworkStage extends StatelessWidget {
  const _ArtworkStage({required this.work});

  final GalleryWork work;

  @override
  Widget build(BuildContext context) {
    final url = MediaUrl.resolve(work.imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: url.isEmpty
                ? const ColoredBox(color: _stageColor)
                : PhotoView(
                    key: ValueKey(url),
                    imageProvider: CachedNetworkImageProvider(url),
                    backgroundDecoration: const BoxDecoration(
                      color: _stageColor,
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
                        color: ArtColors.ink4,
                        size: 36,
                      ),
                    ),
                  ),
          ),
          const Positioned(
            left: 12,
            bottom: 12,
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
    return GestureDetector(
      onTap: () => showImageGallery(
        context,
        images: [url],
        heroTagPrefix: 'gallery_${work.id}',
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _stageColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: AspectRatio(
              aspectRatio: work.aspectRatio.clamp(0.5, 2.0).toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ArtNetworkImage(
                    url,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const Positioned(
                    right: 8,
                    bottom: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: ArtText.caption(size: 11, color: Colors.white)),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ArtColors.subtle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: ArtColors.ink2),
        ),
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
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ArtButton(
              label: work.favorite ? '已收藏' : '收藏',
              icon: work.favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              primary: false,
              onTap: onToggleFavorite,
            ),
            ArtButton(
              label: '临摹网格',
              icon: Icons.grid_on_rounded,
              primary: false,
              onTap: onOpenGrid,
            ),
            ArtButton(
              label: '对比我的原卷',
              icon: Icons.compare_rounded,
              onTap: onCompare,
            ),
          ],
        ),
        if (work.points.isNotEmpty) ...[
          const _SectionTitle('点评要点'),
          for (var i = 0; i < work.points.length; i++)
            _PointRow(index: i + 1, text: work.points[i]),
        ],
        if (work.tags.isNotEmpty) ...[
          const _SectionTitle('标签'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in work.tags)
                _TagChip(label: tag, onTap: () => onTagSelected(tag)),
            ],
          ),
          const SizedBox(height: 6),
          Text('点击标签查看更多同类范画', style: ArtText.caption(size: 11)),
        ],
        if (detail.description.isNotEmpty) ...[
          const _SectionTitle('作品说明'),
          Text(
            detail.description,
            style: ArtText.body(color: ArtColors.ink2, height: 1.65),
          ),
        ],
        if (detail.related.isNotEmpty) ...[
          const _SectionTitle('相关作品'),
          _RelatedGrid(works: detail.related, onOpen: onOpenWork),
        ],
        const SizedBox(height: 16),
        Text(
          '${formatViewCount(work.views)} 次浏览 · 发布于 ${work.publishDate}',
          style: ArtText.caption(size: 11, color: ArtColors.ink4),
        ),
        const SizedBox(height: 8),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: work.isExamPaper ? ArtColors.brandWash : ArtColors.subtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ArtAvatar(name: work.author, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work.author.isEmpty ? '佚名' : work.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArtText.body(size: 15, weight: AppFont.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArtText.caption(),
                ),
              ],
            ),
          ),
          if (work.isExamPaper && work.score != null) ...[
            const SizedBox(width: 8),
            ArtGradeBadge(grade: work.grade, size: 28),
            const SizedBox(width: 8),
            Text(
              formatScore(work.score),
              style: ArtText.number(size: 26, color: ArtColors.brandDeep),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('分', style: ArtText.caption()),
            ),
          ] else
            GallerySourceBadge(
              label: work.source == GallerySource.student ? '优秀作品' : '名师范画',
              examTop: work.source != GallerySource.student,
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: ArtColors.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: ArtText.title(size: 15)),
        ],
      ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ArtColors.brandTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: ArtText.number(size: 11, color: ArtColors.brandDeep),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: ArtText.body(height: 1.5))),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ArtColors.brandLight),
        ),
        child: Text(
          '# $label',
          style: ArtText.caption(size: 12, color: ArtColors.brandDeep),
        ),
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
        const gap = 12.0;
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onOpen(work.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ArtNetworkImage(
                          work.imageUrl,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        work.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ArtText.body(size: 13, weight: AppFont.w500),
                      ),
                      Text(
                        work.isExamPaper && work.score != null
                            ? '${work.grade} 档 · ${formatScore(work.score)} 分'
                            : work.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ArtText.caption(size: 11),
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
