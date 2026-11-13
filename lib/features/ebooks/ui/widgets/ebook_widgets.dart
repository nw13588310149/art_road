import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../gallery/ui/widgets/library_controls.dart';
import '../../data/ebook_models.dart';

/// 阅读按钮文案：开始阅读 / 继续阅读（第 N 页）/ 重新阅读。
String ebookReadLabel(EbookSummary book, {bool withPage = true}) {
  final progress = book.progress;
  if (progress == null) {
    return '开始阅读';
  }
  if (book.finished) {
    return '重新阅读';
  }
  return withPage ? '继续阅读（第 ${progress.page} 页）' : '继续阅读';
}

/// 打开阅读器的起始页：读完的从第 1 页重新开始，其余从进度继续（0）。
int ebookStartPage(EbookSummary book) => book.finished ? 1 : 0;

/// 阅读进度的一句话：读到第 N / M 页、已读完；没读过返回空串。
String ebookProgressLabel(EbookSummary book) {
  final progress = book.progress;
  if (progress == null) {
    return '';
  }
  return book.finished ? '已读完' : '读到第 ${progress.page} / ${book.pageCount} 页';
}

/// 适用阶段徽标：基础绿、提高蓝、冲刺品牌紫（原版类型徽标的三组配色）。
Widget ebookStageBadge(String stage, {bool dense = false}) {
  return switch (stage) {
    '基础' => LibraryTag.green(stage, dense: dense),
    '提高' => LibraryTag.blue(stage, dense: dense),
    '冲刺' => LibraryTag.brand(stage, dense: dense),
    _ => LibraryTag(stage, dense: dense),
  };
}

/// 封面图：铺满所在的盒子，圆角 [radius]；[favorite] 时右上角显示「已在书架」星标，
/// [badge] 贴在右下角（阅读进度、分类）。
class EbookCoverImage extends StatelessWidget {
  const EbookCoverImage({
    required this.url,
    this.radius = 8,
    this.favorite = false,
    this.badge,
    this.bordered = false,
    super.key,
  });

  final String url;
  final double radius;
  final bool favorite;
  final Widget? badge;

  /// 1px 浅描边，用在白底上的封面。
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.all(Radius.circular(radius));
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(
            src: url,
            placeholder: const ColoredBox(color: LibraryPalette.coverFallback),
          ),
          if (bordered)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: AppColors.lineSoft),
              ),
            ),
          if (favorite)
            Positioned(
              top: 6,
              right: 6,
              child: Semantics(
                label: '已在书架',
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.br4,
                  ),
                  child: const AppAssetGraphic(
                    AppAssets.videoV2StarFilled,
                    width: 14,
                    height: 14,
                  ),
                ),
              ),
            ),
          if (badge != null) Positioned(right: 0, bottom: 0, child: badge!),
        ],
      ),
    );
  }
}

/// 3:4 封面。
class EbookCover extends StatelessWidget {
  const EbookCover({
    required this.url,
    this.radius = 8,
    this.favorite = false,
    this.badge,
    this.bordered = false,
    this.elevated = false,
    super.key,
  });

  final String url;
  final double radius;
  final bool favorite;
  final Widget? badge;
  final bool bordered;

  /// 浅色画布上的封面带一层轻投影。
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final image = EbookCoverImage(
      url: url,
      radius: radius,
      favorite: favorite,
      badge: badge,
      bordered: bordered,
    );
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: elevated
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.all(Radius.circular(radius)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: image,
            )
          : image,
    );
  }
}

/// 封面右下角的徽标，样式取自预览缩略图的页码徽标：左上圆角 8、12 号字；
/// [active] 为浅紫底品牌紫字，否则浅灰底墨色字。
class EbookCoverBadge extends StatelessWidget {
  const EbookCoverBadge(this.label, {this.active = false, super.key});

  /// 阅读进度徽标：在读为强调色，读完为普通色；没读过返回 null。
  static Widget? progressOf(EbookSummary book) {
    if (!book.started) {
      return null;
    }
    return EbookCoverBadge(ebookProgressLabel(book), active: !book.finished);
  }

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? LibraryPalette.activeBadge : AppColors.surfaceSubtle,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: libraryText(
          size: 12,
          color: active ? AppColors.brand : AppColors.ink,
          height: 1,
        ),
      ),
    );
  }
}

/// 阅读进度：4 高进度条 + 「读到第 N / M 页」。
class EbookProgressLine extends StatelessWidget {
  const EbookProgressLine({required this.book, super.key});

  final EbookSummary book;

  @override
  Widget build(BuildContext context) {
    final progress = book.progress;
    if (progress == null) {
      return const SizedBox.shrink();
    }
    final muted = libraryText(
      size: 12,
      weight: AppFont.w500,
      color: AppColors.textPlaceholder,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LibraryProgressTrack(value: book.progressFraction),
        const SizedBox(height: 6),
        Text.rich(
          book.finished
              ? const TextSpan(text: '已读完')
              : TextSpan(
                  children: [
                    const TextSpan(text: '读到第 '),
                    TextSpan(
                      text: '${progress.page}',
                      style: const TextStyle(
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                    TextSpan(text: ' / ${book.pageCount} 页'),
                  ],
                ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: muted,
        ),
      ],
    );
  }
}

/// 书库网格里的书刊卡，外观取自原版资源卡：浅紫底、圆角 12、内距 12，
/// 封面圆角 8，书名 14 号中等字重，下面一行 12 号灰字。
class EbookCard extends StatelessWidget {
  const EbookCard({required this.book, required this.onTap, super.key});

  final EbookSummary book;
  final VoidCallback onTap;

  static const _padding = 12.0;

  /// 行高：内距 + 3:4 封面 + 8 + 书名一行 + 7 + 说明一行。
  static double extentFor(double width, {required TextScaler textScaler}) {
    final cover = (width - _padding * 2) * 4 / 3;
    return _padding * 2 +
        cover +
        8 +
        textScaler.scale(14) * 1.2 +
        7 +
        textScaler.scale(12) +
        1;
  }

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(_padding),
        decoration: const BoxDecoration(
          color: LibraryPalette.lilac,
          borderRadius: AppRadius.br12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EbookCoverImage(
                    url: book.coverUrl,
                    favorite: book.favorite,
                    badge: EbookCoverBadge.progressOf(book),
                  ),
                  if (book.stage.isNotEmpty)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: ebookStageBadge(book.stage, dense: true),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: libraryText(
                size: 14,
                weight: AppFont.w500,
                color: AppColors.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${book.editor} 编 · ${book.pageCount} 页',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: libraryText(
                size: 12,
                color: AppColors.textPlaceholder,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 横向书刊卡，外观取自原版课程卡：100 高、浅灰底、圆角 12、内距 10，左侧 60×80
/// 封面，书名 13 号中等字重，说明 11 号灰字，右下角 65×28 的深色按钮。
///
/// 编辑推荐、我的书架和首页的继续阅读都用它。[progressLabel] 不为空时说明只占一行，
/// 第二行显示阅读进度，并在按钮左侧画一条进度条。
class EbookLessonCard extends StatelessWidget {
  const EbookLessonCard({
    required this.book,
    required this.onTap,
    this.subtitle = '',
    this.progressLabel = '',
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final EbookSummary book;
  final VoidCallback onTap;
  final String subtitle;
  final String progressLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const double height = 100;

  /// 网格里一张卡的宽度上限（原版 260）。
  static const double maxExtent = 260;
  static const double gap = 16;

  /// 按可用宽度排几列：每列不超过 [maxExtent]，最多排满 [itemCount] 张。
  static int columnsFor(double width, {int? itemCount}) {
    final columns = (width / (maxExtent + gap)).ceil().clamp(1, 6);
    if (itemCount == null || itemCount <= 0) {
      return columns;
    }
    return columns.clamp(1, itemCount);
  }

  static SliverGridDelegate gridDelegate(double width, {int? itemCount}) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columnsFor(width, itemCount: itemCount),
      mainAxisExtent: height,
      crossAxisSpacing: gap,
      mainAxisSpacing: gap,
    );
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(
      fontFamily: 'PingFang SC',
      fontSize: 11,
      color: AppColors.textPlaceholder,
      height: 1.3,
    );
    final label = actionLabel;
    final hasProgress = progressLabel.isNotEmpty;
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              height: 80,
              child: EbookCoverImage(url: book.coverUrl),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 80,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: libraryText(
                              size: 13,
                              weight: AppFont.w500,
                              color: AppColors.ink,
                              height: 1.2,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: hasProgress ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: muted,
                            ),
                          ],
                          if (hasProgress)
                            Text(
                              progressLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: muted,
                            ),
                        ],
                      ),
                    ),
                    if (hasProgress && book.started)
                      Positioned(
                        left: 0,
                        right: label == null ? 0 : 73,
                        bottom: 12,
                        child: LibraryProgressTrack(
                          value: book.progressFraction,
                        ),
                      ),
                    if (label != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: AppPressable(
                          onTap: onAction,
                          enabled: onAction != null,
                          child: Container(
                            width: 65,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: LibraryPalette.darkAction,
                              borderRadius: AppRadius.br8,
                            ),
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              style: libraryText(
                                size: 11,
                                weight: AppFont.w500,
                                color: AppColors.onBrand,
                                height: 12 / 11,
                              ),
                            ),
                          ),
                        ),
                      ),
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

/// 书库网格：列宽上限 189、列缝 16、行缝 14（原版资源网格），行高随封面比例。
class EbookGrid extends StatelessWidget {
  const EbookGrid({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  static const double maxExtent = 189;
  static const double crossGap = 16;
  static const double mainGap = 14;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final count = (width / (maxExtent + crossGap)).ceil().clamp(1, 8);
        final itemWidth = (width - crossGap * (count - 1)) / count;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: mainGap,
            crossAxisSpacing: crossGap,
            mainAxisExtent: EbookCard.extentFor(
              itemWidth,
              textScaler: MediaQuery.textScalerOf(context),
            ),
          ),
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            childCount: itemCount,
          ),
        );
      },
    );
  }
}
