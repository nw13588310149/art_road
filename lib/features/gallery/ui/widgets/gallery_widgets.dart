import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../data/gallery_models.dart';
import '../../state/gallery_state.dart';
import 'library_controls.dart';

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

  /// 列缝与行缝，和视频网格一致。
  static const _gap = 16.0;

  static int columnsFor(double width) {
    if (width >= 860) {
      return 4;
    }
    if (width >= 580) {
      return 3;
    }
    return width >= 360 ? 2 : 1;
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
              GalleryWorkCard.infoHeight +
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

/// 范画卡：外观取自视频网格卡（浅灰底、圆角 12、标题 13 号中等字重、
/// 16 高的信息行），图片按画作比例显示。
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

  /// 图片下方信息区的高度：上 9 + 标题 + 信息行 16 + 下 10。
  static const double infoHeight = 56;

  /// 极端长图 / 宽图限制在合理范围内，卡片之间高度不至于悬殊。
  static double imageAspect(GalleryWork work) =>
      work.aspectRatio.clamp(0.68, 1.45).toDouble();

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: imageAspect(work),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    src: work.imageUrl,
                    placeholder: const ColoredBox(
                      color: LibraryPalette.coverFallback,
                    ),
                  ),
                  if (work.source != GallerySource.master)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: GallerySourceTag(source: work.source, dense: true),
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
            SizedBox(
              height: infoHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const Spacer(),
                    SizedBox(height: 16, child: _CardMeta(work: work)),
                  ],
                ),
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
    final grade = work.grade;
    // 高分卷这一行放档位与分数，作者与校区在详情里看；其余作品放作者。
    final examPaper = work.isExamPaper && grade.isNotEmpty;
    final muted = libraryText(
      size: 10,
      weight: AppFont.w500,
      color: AppColors.textPlaceholder,
      height: 1,
    );
    return Row(
      children: [
        if (examPaper) ...[
          _GradeMark(grade: grade),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatScore(work.score),
                    style: AppText.number(size: 12),
                  ),
                  TextSpan(text: ' 分', style: muted),
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
              style: muted,
            ),
          ),
        const SizedBox(width: 8),
        GalleryViewCount(views: work.views),
      ],
    );
  }
}

/// 档位：16 高的方角小标签，A 档用品牌色。
class _GradeMark extends StatelessWidget {
  const _GradeMark({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final top = grade == 'A';
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: top ? AppColors.tint(AppColors.brand, 0.1) : AppColors.surface,
        borderRadius: AppRadius.br4,
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          '$grade 档',
          style: libraryText(
            size: 10,
            weight: AppFont.w500,
            color: top ? AppColors.brand : AppColors.textSecondary,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// 浏览量：眼睛图标 + 12 号数字。
class GalleryViewCount extends StatelessWidget {
  const GalleryViewCount({required this.views, this.suffix = '', super.key});

  final int views;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppAssetGraphic(AppAssets.newsViews, width: 12, height: 12),
        const SizedBox(width: 4),
        Text(
          '${formatViewCount(views)}$suffix',
          style: libraryText(
            size: 12,
            weight: AppFont.w500,
            color: AppColors.textPlaceholder,
            height: 1,
          ),
        ),
      ],
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

/// 来源标签：联考高分卷（品牌色）/ 学生优秀作品（绿色）/ 名师范画（中性），方角浅底。
/// [dense] 用在图片上。
class GallerySourceTag extends StatelessWidget {
  const GallerySourceTag({required this.source, this.dense = false, super.key});

  final String source;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return switch (source) {
      GallerySource.examTop => LibraryTag.brand('高分卷', dense: dense),
      GallerySource.student => LibraryTag.green('优秀作品', dense: dense),
      _ => LibraryTag('名师范画', dense: dense),
    };
  }
}

/// 卡片上的收藏按钮：28 见方白底圆角 8，星形图标，点按立即切换。
class GalleryFavoriteButton extends StatelessWidget {
  const GalleryFavoriteButton({
    required this.favorite,
    required this.onTap,
    super.key,
  });

  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = favorite ? 14.0 : 20.0;
    return AppPressable(
      onTap: onTap,
      toggled: favorite,
      semanticLabel: favorite ? '取消收藏' : '收藏',
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br8,
        ),
        child: AppAssetGraphic(
          favorite ? AppAssets.videoV2StarFilled : AppAssets.videoV2Star,
          width: size,
          height: size,
        ),
      ),
    );
  }
}

/// 顶部一行（36 高）：左侧科目页签，右侧排序与搜索。
class GalleryToolbar extends StatelessWidget {
  const GalleryToolbar({
    required this.state,
    required this.onBack,
    required this.onSubjectChanged,
    required this.onSortChanged,
    required this.onKeywordChanged,
    super.key,
  });

  final GalleryState state;
  final VoidCallback? onBack;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<GallerySort> onSortChanged;
  final ValueChanged<String> onKeywordChanged;

  static const double height = 36;
  static const _subjects = <String>['', '素描', '色彩', '速写'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 搜索框原宽 254，窄横屏下让出页签的位置。
          final searchWidth = (constraints.maxWidth * 0.34)
              .clamp(140.0, 254.0)
              .toDouble();
          return Row(
            children: [
              if (onBack != null) ...[
                LibraryIconButton.back(onTap: onBack),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: AppTabs<String>(
                    textOnly: true,
                    gap: 20,
                    tabs: [
                      for (final subject in _subjects)
                        AppTab(
                          value: subject,
                          label: subject.isEmpty ? '全部科目' : subject,
                        ),
                    ],
                    value: state.subject,
                    onChanged: onSubjectChanged,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LibrarySortButton<GallerySort>(
                height: height,
                options: [
                  for (final sort in GallerySort.values)
                    LibraryOption(value: sort, label: sort.label),
                ],
                value: state.sort,
                onChanged: onSortChanged,
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: searchWidth,
                child: GallerySearchField(
                  keyword: state.keyword,
                  onChanged: onKeywordChanged,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 分类筛选条：「全部」+ 当前科目下的分类，单选。
class GalleryCategoryBar extends StatelessWidget {
  const GalleryCategoryBar({
    required this.state,
    required this.onChanged,
    super.key,
  });

  final GalleryState state;
  final ValueChanged<String> onChanged;

  /// 未选科目时只列跨科分类，选了科目再列该科目的分类。
  static List<GalleryCategory> categoriesOf(GalleryState state) => [
    for (final category in state.visibleCategories)
      if (category.key != GalleryCategory.allKey &&
          (state.subject.isNotEmpty || category.subject == null))
        category,
  ];

  /// 已选科目时去掉分类名里重复的科目前缀：「素描 · 石膏」→「石膏」。
  static String shortLabel(GalleryCategory category) {
    final subject = category.subject;
    if (subject == null) {
      return category.label;
    }
    final label = category.label.replaceFirst(RegExp('^$subject\\s*·\\s*'), '');
    return label.isEmpty ? category.label : label;
  }

  @override
  Widget build(BuildContext context) {
    return LibraryChipBar<String>(
      items: [
        const LibraryOption(value: GalleryCategory.allKey, label: '全部'),
        for (final category in categoriesOf(state))
          LibraryOption(value: category.key, label: shortLabel(category)),
      ],
      value: state.category,
      onChanged: onChanged,
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
    return LibrarySearchField(
      controller: _controller,
      hint: '搜索标题、作者、点评要点',
      height: GalleryToolbar.height,
      onChanged: _schedule,
      onSubmitted: _submit,
      onCleared: () => _submit(''),
    );
  }
}
