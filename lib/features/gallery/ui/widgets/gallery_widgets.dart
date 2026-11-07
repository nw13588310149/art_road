import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
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

  static const _gap = AppSpace.s16;
  static const _infoHeight = 70.0;

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

/// 瀑布流加载骨架：与作品卡同宽，高度错落。
class GalleryMasonrySkeleton extends StatelessWidget {
  const GalleryMasonrySkeleton({super.key});

  static const _heights = <double>[220, 300, 260, 200, 280, 240, 320, 210];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = GalleryMasonryGrid.columnsFor(constraints.maxWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: AppSpace.s16),
              Expanded(
                child: Column(
                  children: [
                    for (var r = 0; r < 2; r++) ...[
                      if (r > 0) const SizedBox(height: AppSpace.s16),
                      AppSkeleton(
                        height: _heights[(c + r * columns) % _heights.length],
                        radius: AppRadius.card,
                      ),
                    ],
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
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: imageAspect(work),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card - 1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(src: work.imageUrl),
                  if (work.source != GallerySource.master)
                    Positioned(
                      left: AppSpace.s8,
                      top: AppSpace.s8,
                      child: GallerySourceTag(source: work.source),
                    ),
                  Positioned(
                    right: AppSpace.s8,
                    top: AppSpace.s8,
                    child: GalleryFavoriteButton(
                      favorite: work.favorite,
                      onTap: onToggleFavorite,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s12,
              AppSpace.s8,
              AppSpace.s12,
              AppSpace.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  work.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
                const SizedBox(height: AppSpace.s4),
                _CardMeta(work: work),
              ],
            ),
          ),
        ],
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
    final grade = work.grade;
    // 高分卷这一行放档位与分数，作者与校区在详情里看；其余作品放作者。
    final examPaper = work.isExamPaper && grade.isNotEmpty;
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          if (examPaper) ...[
            AppTag(
              label: '$grade 档',
              tone: grade == 'A' ? AppTone.brand : AppTone.neutral,
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatScore(work.score),
                      style: AppText.number(size: 14),
                    ),
                    TextSpan(text: ' 分', style: AppText.caption12),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ] else
            Expanded(
              child: Text(
                byline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12,
              ),
            ),
          const SizedBox(width: AppSpace.s8),
          const Icon(
            Icons.visibility_outlined,
            size: 14,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 2),
          Text(formatViewCount(work.views), style: AppText.caption12),
        ],
      ),
    );
  }
}

/// 浏览量：过万显示「1.2 万」。
String formatViewCount(int views) {
  if (views >= 10000) {
    return '${(views / 10000).toStringAsFixed(1)} 万';
  }
  return '$views';
}

/// 来源角标：联考高分卷（品牌色）/ 学生优秀作品（成功色），浅底深字。
class GallerySourceTag extends StatelessWidget {
  const GallerySourceTag({required this.source, super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    return switch (source) {
      GallerySource.examTop => const AppTag(
        label: '高分卷',
        tone: AppTone.brand,
      ),
      GallerySource.student => const AppTag(
        label: '优秀作品',
        tone: AppTone.success,
      ),
      _ => const AppTag(label: '名师范画'),
    };
  }
}

/// 收藏按钮：白底圆钮，点按立即切换，不做缩放动画。
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
    return AppPressable(
      onTap: onTap,
      toggled: favorite,
      semanticLabel: favorite ? '取消收藏' : '收藏',
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: size * 0.56,
          color: favorite ? AppColors.danger : AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// 筛选：科目 AppSegmented + 该科目下的分类 AppChip（可取消，取消即全部）。
class GalleryFilterBar extends StatelessWidget {
  const GalleryFilterBar({
    required this.state,
    required this.onSubjectChanged,
    required this.onCategoryChanged,
    super.key,
  });

  final GalleryState state;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onCategoryChanged;

  static const _subjects = <String>['', '素描', '色彩', '速写'];

  /// 已选科目时去掉分类名里重复的科目前缀：「素描 · 石膏」→「石膏」。
  static String shortLabel(GalleryCategory category) {
    final subject = category.subject;
    if (subject == null) {
      return category.label;
    }
    final label = category.label.replaceFirst(
      RegExp('^$subject\\s*·\\s*'),
      '',
    );
    return label.isEmpty ? category.label : label;
  }

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final category in state.visibleCategories)
        if (category.key != GalleryCategory.allKey &&
            (state.subject.isNotEmpty || category.subject == null))
          category,
    ];
    return Wrap(
      spacing: AppSpace.s12,
      runSpacing: AppSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppSegmented<String>(
          segments: [
            for (final subject in _subjects)
              AppSegment(
                value: subject,
                label: subject.isEmpty ? '全部科目' : subject,
              ),
          ],
          value: state.subject,
          onChanged: onSubjectChanged,
        ),
        for (final category in chips)
          AppChip(
            label: category.count > 0
                ? '${shortLabel(category)} ${category.count}'
                : shortLabel(category),
            selected: category.key == state.category,
            onTap: () => onCategoryChanged(
              category.key == state.category
                  ? GalleryCategory.allKey
                  : category.key,
            ),
          ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: _controller,
      hint: '搜索标题、作者、点评要点',
      onChanged: _schedule,
      onSubmitted: _submit,
      onCleared: () => _submit(''),
    );
  }
}
