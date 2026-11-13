import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/art/art_tokens.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../data/gallery_models.dart';
import 'gallery_compare_page.dart';
import 'widgets/gallery_widgets.dart';
import 'widgets/library_controls.dart';

/// 范画详情（在范画库页内展示，返回回到列表或上一幅作品）。
///
/// 版式取自资料预览：56 高的工具栏（返回、居中的作品名、操作胶囊），下面是
/// 四周留 16 的画布和带左分隔线的白色侧栏。
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

  /// 侧栏宽度，与原版预览页的信息栏一致。
  static const double panelWidth = 320;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    if (detail == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryPreviewHeader(title: '范画详情', onBack: onBack),
          Expanded(
            child: error.isNotEmpty && !loading
                ? AppErrorState(
                    title: '范画加载失败',
                    description: error,
                    onRetry: onRetry,
                  )
                : const Center(child: AppLoadingIndicator()),
          ),
        ],
      );
    }
    final work = detail.work;
    final imageUrl = MediaUrl.resolve(work.imageUrl);
    void openFullscreen() => showImageGallery(
      context,
      images: [imageUrl],
      heroTagPrefix: 'gallery_${work.id}',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 工具栏太窄时操作只留图标。
        final compact = constraints.maxWidth < 560;
        final header = LibraryPreviewHeader(
          title: work.title,
          onBack: onBack,
          actions: [
            LibraryActionPill(
              label: work.favorite ? '已收藏' : '收藏',
              iconAsset: work.favorite
                  ? AppAssets.videoV2StarFilled
                  : AppAssets.videoV2Star,
              iconSize: work.favorite ? 14 : 20,
              active: work.favorite,
              compact: compact,
              onTap: () => onToggleFavorite(work),
            ),
            LibraryActionPill(
              label: '临摹网格',
              icon: Icons.grid_on_rounded,
              iconSize: 18,
              compact: compact,
              onTap: () => Navigator.of(context).pushNamed(
                RoutePaths.artToolbox,
                arguments: <String, dynamic>{
                  'tool': 'grid',
                  'imageUrl': work.imageUrl,
                  'title': work.title,
                },
              ),
            ),
            LibraryActionPill(
              label: '对比我的原卷',
              icon: Icons.compare_rounded,
              iconSize: 18,
              primary: true,
              compact: compact,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => GalleryComparePage(work: work),
                ),
              ),
            ),
          ],
        );
        final info = _DetailInfo(
          detail: detail,
          onOpenWork: onOpenWork,
          onTagSelected: onTagSelected,
        );
        if (constraints.maxWidth >= 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LibraryCanvas(
                        child: _ArtworkStage(
                          url: imageUrl,
                          onFullscreen: imageUrl.isEmpty
                              ? null
                              : openFullscreen,
                        ),
                      ),
                    ),
                    Container(
                      width: panelWidth,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          left: BorderSide(color: AppColors.lineSoft),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: info,
                      ),
                    ),
                  ],
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
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LibraryCanvas(
                      child: _ArtworkPreview(
                        work: work,
                        onFullscreen: imageUrl.isEmpty ? null : openFullscreen,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: info,
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

/// 宽屏：可缩放的大图（双指 / 双击缩放），右上角进入全屏查看。
class _ArtworkStage extends StatelessWidget {
  const _ArtworkStage({required this.url, required this.onFullscreen});

  final String url;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: url.isEmpty
              ? const SizedBox.shrink()
              : PhotoView(
                  key: ValueKey(url),
                  imageProvider: CachedNetworkImageProvider(url),
                  backgroundDecoration: const BoxDecoration(
                    color: LibraryPalette.canvas,
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  initialScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  filterQuality: FilterQuality.medium,
                  loadingBuilder: (context, event) =>
                      const Center(child: AppLoadingIndicator()),
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textPlaceholder,
                      size: 48,
                    ),
                  ),
                ),
        ),
        const Positioned(
          left: 10,
          bottom: 10,
          child: IgnorePointer(child: LibraryCounter('双指缩放 · 双击放大')),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: LibraryIconButton(
            icon: Icons.fullscreen_rounded,
            semanticLabel: '全屏查看',
            onTap: onFullscreen,
          ),
        ),
      ],
    );
  }
}

/// 窄屏：等比预览图，点击进入全屏查看（避免与页面滚动手势冲突）。
class _ArtworkPreview extends StatelessWidget {
  const _ArtworkPreview({required this.work, required this.onFullscreen});

  final GalleryWork work;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onFullscreen,
      semanticLabel: '查看大图',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: AspectRatio(
              aspectRatio: work.aspectRatio.clamp(0.5, 2.0).toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(src: work.imageUrl, fit: BoxFit.contain),
                  if (onFullscreen != null)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: LibraryCounter('点击查看大图'),
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

class _DetailInfo extends StatelessWidget {
  const _DetailInfo({
    required this.detail,
    required this.onOpenWork,
    required this.onTagSelected,
  });

  final GalleryWorkDetail detail;
  final ValueChanged<String> onOpenWork;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    final work = detail.work;
    final meta = [
      work.categoryLabel,
      if (work.source != GallerySource.examTop) work.source,
    ].where((part) => part.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AuthorCard(work: work),
        if (work.points.isNotEmpty) ...[
          const _Section(title: '点评要点'),
          for (var i = 0; i < work.points.length; i++)
            _PointRow(index: i + 1, text: work.points[i]),
        ],
        if (work.tags.isNotEmpty) ...[
          _Section(
            title: '标签',
            trailing: Text(
              '点击查看同类范画',
              style: libraryText(size: 12, color: AppColors.textPlaceholder),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in work.tags)
                LibraryChip(
                  label: tag,
                  selected: false,
                  onTap: () => onTagSelected(tag),
                ),
            ],
          ),
        ],
        if (detail.description.isNotEmpty) ...[
          const _Section(title: '作品说明'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle.withValues(alpha: 0.6),
              borderRadius: AppRadius.br8,
            ),
            child: Text(
              detail.description,
              style: libraryText(size: 13, color: AppColors.ink, height: 2),
            ),
          ),
        ],
        if (detail.related.isNotEmpty) ...[
          const _Section(title: '相关作品'),
          _RelatedGrid(works: detail.related, onOpen: onOpenWork),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            GalleryViewCount(views: work.views, suffix: ' 次浏览'),
            Expanded(
              child: Text(
                [
                  ' · 发布于 ${work.publishDate}',
                  if (meta.isNotEmpty) meta,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: libraryText(
                  size: 12,
                  weight: AppFont.w500,
                  color: AppColors.textPlaceholder,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// 作者信息：浅灰底圆角 12 的信息块，高分卷在右侧显示档位与分数。
class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.work});

  final GalleryWork work;

  @override
  Widget build(BuildContext context) {
    final author = work.author.isEmpty ? '佚名' : work.author;
    final subtitle = work.isExamPaper
        ? [
            work.authorTitle,
            work.examName,
          ].where((s) => s.isNotEmpty).join(' · ')
        : (work.authorTitle.isEmpty ? work.source : work.authorTitle);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br12,
      ),
      child: Row(
        children: [
          AppAvatar(name: author, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: libraryText(
                    size: 14,
                    weight: AppFont.w500,
                    color: AppColors.ink,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: libraryText(
                    size: 12,
                    color: AppColors.textPlaceholder,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (work.isExamPaper && work.score != null) ...[
            if (work.grade.isNotEmpty) ...[
              work.grade == 'A'
                  ? LibraryTag.brand('${work.grade} 档')
                  : LibraryTag(
                      '${work.grade} 档',
                      background: AppColors.surface,
                    ),
              const SizedBox(width: 8),
            ],
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatScore(work.score),
                    style: AppText.displayNumber(
                      size: 24,
                      color: AppColors.brand,
                    ),
                  ),
                  TextSpan(
                    text: ' 分',
                    style: libraryText(
                      size: 12,
                      color: AppColors.textPlaceholder,
                    ),
                  ),
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
  const _Section({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: LibrarySectionTitle(title, trailing: trailing),
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
      padding: const EdgeInsets.only(bottom: 8),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: libraryText(size: 14, color: AppColors.ink, height: 22 / 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// 相关作品：和列表同一种卡片外观的小卡，方图 + 标题 + 一行说明。
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
                child: AppPressable(
                  onTap: () => onOpen(work.id),
                  semanticLabel: work.title,
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: AppRadius.br12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: AppImage(
                            src: work.imageUrl,
                            placeholder: const ColoredBox(
                              color: LibraryPalette.coverFallback,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                work.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: libraryText(
                                  size: 13,
                                  weight: AppFont.w500,
                                  color: AppColors.ink,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                work.isExamPaper && work.score != null
                                    ? '${work.grade} 档 · ${formatScore(work.score)} 分'
                                    : work.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: libraryText(
                                  size: 10,
                                  weight: AppFont.w500,
                                  color: AppColors.textPlaceholder,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
