import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../data/gallery_models.dart';
import 'gallery_compare_page.dart';
import 'widgets/gallery_detail_panel.dart';
import 'widgets/gallery_images.dart';
import 'widgets/gallery_widgets.dart';

/// 范画详情（在素材中心页内展示，返回回到列表或上一幅作品）。
///
/// 画布加面板：页头是返回、作品名、收藏、临摹网格和唯一的主按钮「对比我的原卷」；
/// 左边是可缩放的大图，右边是出处、点评要点、说明、标签和相关作品。
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
    return AppPageBody(
      scrollable: false,
      builder: (context, wide) {
        final detail = this.detail;
        if (detail == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTitleBar(title: '范画详情', onBack: onBack),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTitleBar(
              title: work.title,
              onBack: onBack,
              actions: [
                GalleryFavoriteAction(
                  favorite: work.favorite,
                  onTap: () => onToggleFavorite(work),
                ),
                AppPlainButton(
                  label: '临摹网格',
                  icon: Icons.grid_on_rounded,
                  onTap: () => Navigator.of(context).pushNamed(
                    RoutePaths.artToolbox,
                    arguments: <String, dynamic>{
                      'tool': 'grid',
                      'imageUrl': work.imageUrl,
                      'title': work.title,
                    },
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                AppButton(
                  label: '对比我的原卷',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => GalleryComparePage(work: work),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s16),
            Expanded(
              child: AppCanvasLayout(
                wide: wide,
                hint: '双指缩放 · 双击放大',
                canvasActions: [
                  AppIconAction(
                    icon: Icons.fullscreen_rounded,
                    semanticLabel: '全屏查看',
                    onTap: work.imageUrl.isEmpty
                        ? null
                        : () => showImageGallery(
                            context,
                            images: [work.imageUrl],
                            titles: [work.title],
                          ),
                  ),
                ],
                canvas: Padding(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: GalleryZoomImage(src: work.imageUrl),
                ),
                panel: GalleryDetailPanel(
                  detail: detail,
                  onOpenWork: onOpenWork,
                  onTagSelected: onTagSelected,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
