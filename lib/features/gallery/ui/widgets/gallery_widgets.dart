import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/gallery_models.dart';

/// 来源的短称，写在格子和详情的出处里。
String gallerySourceLabel(String source) => switch (source) {
  GallerySource.examTop => '高分卷',
  GallerySource.student => '优秀作品',
  _ => '名师范画',
};

/// 格子说明那一行：高分卷写档位和分数（标题里已经有「高分卷」），其余写
/// 「来源 · 作者」。浏览量不放进格子，在详情里看。
String galleryTileMeta(GalleryWork work) {
  if (work.isExamPaper && work.score != null) {
    return [
      if (work.grade.isNotEmpty) '${work.grade} 档',
      '${formatScore(work.score)} 分',
    ].join(' · ');
  }
  return [
    gallerySourceLabel(work.source),
    work.author,
  ].where((part) => part.isNotEmpty).join(' · ');
}

/// 浏览量：过万显示「1.2 万」。
String formatViewCount(int views) {
  if (views >= 10000) {
    return '${(views / 10000).toStringAsFixed(1)} 万';
  }
  return '$views';
}

/// 收藏：星形图标，已收藏时是实心的品牌紫。
class GalleryFavoriteAction extends StatelessWidget {
  const GalleryFavoriteAction({
    required this.favorite,
    required this.onTap,
    super.key,
  });

  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppIconAction(
      icon: Icons.star_border_rounded,
      activeIcon: Icons.star_rounded,
      active: favorite,
      semanticLabel: favorite ? '取消收藏' : '收藏',
      onTap: onTap,
    );
  }
}

/// 一幅范画：图按原比例完整显示，名称和说明在图下，收藏在名称右边。
class GalleryWorkTile extends StatelessWidget {
  const GalleryWorkTile({
    required this.work,
    required this.onOpen,
    required this.onToggleFavorite,
    super.key,
  });

  final GalleryWork work;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  /// 极端的长图和宽图限制在这个范围里，图在框里完整显示，不裁。
  static double aspectOf(GalleryWork work) =>
      work.aspectRatio.clamp(0.6, 1.6).toDouble();

  @override
  Widget build(BuildContext context) {
    return AppImageTile(
      image: AppImageTile.frame(
        aspectRatio: aspectOf(work),
        child: ColoredBox(
          color: AppColors.canvas,
          child: AppImage(
            src: work.imageUrl,
            fit: BoxFit.contain,
            placeholder: const ColoredBox(color: AppColors.canvas),
          ),
        ),
      ),
      title: work.title,
      meta: galleryTileMeta(work),
      onTap: onOpen,
      action: GalleryFavoriteAction(
        favorite: work.favorite,
        onTap: onToggleFavorite,
      ),
    );
  }
}

/// 排序：写出当前的排序方式，点开是选择菜单。
class GallerySortButton extends StatelessWidget {
  const GallerySortButton({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final GallerySort value;
  final ValueChanged<GallerySort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchor) => AppPlainButton(
        label: value.label,
        icon: Icons.swap_vert_rounded,
        onTap: () async {
          final picked = await showAppMenu<GallerySort>(
            context: anchor,
            width: 120,
            selected: value,
            items: [
              for (final sort in GallerySort.values)
                AppMenuItem(value: sort, label: sort.label),
            ],
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
      ),
    );
  }
}

/// 搜索框：输入停顿后自动搜索，回车立即搜索；外部关键字变化（如点标签）时同步。
class GallerySearchBox extends StatefulWidget {
  const GallerySearchBox({
    required this.keyword,
    required this.onChanged,
    super.key,
  });

  final String keyword;
  final ValueChanged<String> onChanged;

  @override
  State<GallerySearchBox> createState() => _GallerySearchBoxState();
}

class _GallerySearchBoxState extends State<GallerySearchBox> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.keyword,
  );
  Timer? _debounce;

  @override
  void didUpdateWidget(covariant GallerySearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keyword != oldWidget.keyword &&
        widget.keyword != _controller.text.trim()) {
      _debounce?.cancel();
      _controller.value = TextEditingValue(
        text: widget.keyword,
        selection: TextSelection.collapsed(offset: widget.keyword.length),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _schedule(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => widget.onChanged(value),
    );
  }

  void _submit(String value) {
    _debounce?.cancel();
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: _controller,
      hint: '搜索标题、作者、要点',
      onChanged: _schedule,
      onSubmitted: _submit,
      onCleared: () => _submit(''),
    );
  }
}
