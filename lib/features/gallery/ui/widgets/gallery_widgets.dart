import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/gallery_models.dart';
import '../../state/gallery_state.dart';

/// 瀑布流：按卡片预估高度把作品分配到最短的一列，图片按真实宽高比占位。
class GalleryMasonryGrid extends StatelessWidget {
  const GalleryMasonryGrid({
    required this.works,
    required this.onOpen,
    required this.onToggleFavorite,
    super.key,
  });

  final List<GalleryWork> works;
  final ValueChanged<GalleryWork> onOpen;
  final ValueChanged<GalleryWork> onToggleFavorite;

  static const _gap = 14.0;
  static const _infoHeight = 66.0;

  static int columnsFor(double width) {
    if (width >= 860) {
      return 4;
    }
    return width >= 580 ? 3 : 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);
        final columnWidth =
            (constraints.maxWidth - _gap * (columns - 1)) / columns;
        final buckets = List.generate(columns, (_) => <GalleryWork>[]);
        final heights = List<double>.filled(columns, 0);
        for (final work in works) {
          var target = 0;
          for (var c = 1; c < columns; c++) {
            if (heights[c] < heights[target] - 0.5) {
              target = c;
            }
          }
          buckets[target].add(work);
          heights[target] +=
              columnWidth / GalleryWorkCard.imageAspect(work) +
              _infoHeight +
              _gap;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: _gap),
              SizedBox(
                width: columnWidth,
                child: Column(
                  children: [
                    for (final work in buckets[c])
                      Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: GalleryWorkCard(
                          work: work,
                          onTap: () => onOpen(work),
                          onToggleFavorite: () => onToggleFavorite(work),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class GalleryWorkCard extends StatelessWidget {
  const GalleryWorkCard({
    required this.work,
    required this.onTap,
    required this.onToggleFavorite,
    super.key,
  });

  final GalleryWork work;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  /// 极端长图 / 宽图限制在合理范围内，卡片之间高度不至于悬殊。
  static double imageAspect(GalleryWork work) =>
      work.aspectRatio.clamp(0.68, 1.45).toDouble();

  @override
  Widget build(BuildContext context) {
    final badge = switch (work.source) {
      GallerySource.examTop => '高分卷',
      GallerySource.student => '优秀作品',
      _ => '',
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ArtColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D1B1446),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: imageAspect(work),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ArtNetworkImage(work.imageUrl),
                  if (badge.isNotEmpty)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: GallerySourceBadge(
                        label: badge,
                        examTop: work.source == GallerySource.examTop,
                      ),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GalleryFavoriteButton(
                      favorite: work.favorite,
                      onTap: onToggleFavorite,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ArtText.body(weight: AppFont.w500, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  _CardMeta(work: work),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.work});

  final GalleryWork work;

  @override
  Widget build(BuildContext context) {
    final byline = switch (work.source) {
      GallerySource.master => '${work.source} · ${work.author}',
      _ => [
        work.author,
        work.authorTitle,
      ].where((s) => s.isNotEmpty).join(' · '),
    };
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          if (work.isExamPaper && work.grade.isNotEmpty) ...[
            ArtGradeBadge(grade: work.grade, size: 18),
            const SizedBox(width: 6),
            Text(
              formatScore(work.score),
              style: ArtText.number(size: 15, color: ArtColors.brandDeep),
            ),
            const SizedBox(width: 2),
            Text('分', style: ArtText.caption(size: 11)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              byline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ArtText.caption(),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.visibility_outlined,
            size: 13,
            color: ArtColors.ink4,
          ),
          const SizedBox(width: 3),
          Text(
            formatViewCount(work.views),
            style: ArtText.caption(size: 11, color: ArtColors.ink4),
          ),
        ],
      ),
    );
  }
}

/// 浏览量：过万显示「1.2万」。
String formatViewCount(int views) {
  if (views >= 10000) {
    return '${(views / 10000).toStringAsFixed(1)}万';
  }
  return '$views';
}

class GallerySourceBadge extends StatelessWidget {
  const GallerySourceBadge({
    required this.label,
    this.examTop = false,
    super.key,
  });

  final String label;
  final bool examTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: examTop ? ArtColors.brandGradient : null,
        color: examTop ? null : ArtColors.success,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          height: 1.3,
          fontWeight: AppFont.w500,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

class GalleryFavoriteButton extends StatelessWidget {
  const GalleryFavoriteButton({
    required this.favorite,
    required this.onTap,
    this.size = 30,
    super.key,
  });

  final bool favorite;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(favorite),
            size: size * 0.56,
            color: favorite ? ArtColors.down : ArtColors.ink3,
          ),
        ),
      ),
    );
  }
}

/// 科目页签 + 分类标签。
class GalleryFilterBar extends StatelessWidget {
  const GalleryFilterBar({
    required this.state,
    required this.onSubjectChanged,
    required this.onCategoryChanged,
    this.stacked = false,
    super.key,
  });

  final GalleryState state;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onCategoryChanged;

  /// 窄屏时科目页签与分类标签上下排列。
  final bool stacked;

  static const _subjects = <String>['', '素描', '色彩', '速写'];

  @override
  Widget build(BuildContext context) {
    final tabs = ArtSegmentTabs<String>(
      items: _subjects,
      value: state.subject,
      labelOf: (s) => s.isEmpty ? '全部科目' : s,
      onChanged: onSubjectChanged,
    );
    final chips = GalleryCategoryChips(
      categories: state.visibleCategories,
      selected: state.category,
      onSelected: onCategoryChanged,
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: tabs),
          const SizedBox(height: 10),
          chips,
        ],
      );
    }
    return Row(
      children: [
        tabs,
        const SizedBox(width: 14),
        Expanded(child: chips),
      ],
    );
  }
}

class GalleryCategoryChips extends StatelessWidget {
  const GalleryCategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<GalleryCategory> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final active = category.key == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(category.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: active ? ArtColors.brandGradient : null,
                color: active ? null : ArtColors.subtle,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      color: active ? Colors.white : ArtColors.ink2,
                      fontWeight: active ? AppFont.w500 : AppFont.w400,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  if (category.count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${category.count}',
                      style: ArtText.number(
                        size: 12,
                        color: active
                            ? Colors.white.withValues(alpha: 0.8)
                            : ArtColors.ink4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 搜索框：输入停顿后自动搜索，回车立即搜索；外部关键字变化（如点标签）时同步。
class GallerySearchField extends StatefulWidget {
  const GallerySearchField({
    required this.keyword,
    required this.onChanged,
    super.key,
  });

  final String keyword;
  final ValueChanged<String> onChanged;

  @override
  State<GallerySearchField> createState() => _GallerySearchFieldState();
}

class _GallerySearchFieldState extends State<GallerySearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.keyword,
  );
  Timer? _debounce;

  @override
  void didUpdateWidget(covariant GallerySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keyword != oldWidget.keyword &&
        widget.keyword != _controller.text.trim()) {
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

  void _clear() {
    _controller.clear();
    _submit('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: ArtColors.subtle,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: ArtColors.ink3),
          const SizedBox(width: 6),
          Expanded(
            child: AppTextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: _schedule,
              onSubmitted: _submit,
              style: ArtText.body(),
              cursorColor: ArtColors.brand,
              decoration: InputDecoration.collapsed(
                hintText: '搜索标题、作者、点评要点',
                hintStyle: ArtText.caption(size: 13, color: ArtColors.ink4),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) {
                return const SizedBox(width: 8);
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _clear,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.clear_rounded,
                    size: 16,
                    color: ArtColors.ink3,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
