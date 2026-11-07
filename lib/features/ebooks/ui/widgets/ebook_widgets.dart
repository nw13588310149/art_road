import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
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

/// 3:4 封面，圆角 8；[favorite] 时右上角显示「已在书架」角标。
class EbookCover extends StatelessWidget {
  const EbookCover({required this.url, this.favorite = false, super.key});

  final String url;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(src: url, borderRadius: AppRadius.br8),
          const DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.br8,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.lineSoft),
              ),
            ),
          ),
          if (favorite)
            Positioned(
              top: AppSpace.s4,
              right: AppSpace.s4,
              child: Semantics(
                label: '已在书架',
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.br4,
                  ),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 科目与适用阶段标签。
class EbookTags extends StatelessWidget {
  const EbookTags({required this.book, super.key});

  final EbookSummary book;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.s4,
      runSpacing: AppSpace.s4,
      children: [
        for (final subject in book.subjects) AppTag.subject(subject),
        if (book.stage.isNotEmpty) AppTag(label: book.stage),
      ],
    );
  }
}

/// 阅读进度：细进度条 + 「读到第 N / M 页」，读完转绿色。
class EbookProgressLine extends StatelessWidget {
  const EbookProgressLine({required this.book, super.key});

  final EbookSummary book;

  @override
  Widget build(BuildContext context) {
    final progress = book.progress;
    if (progress == null) {
      return const SizedBox.shrink();
    }
    final finished = book.finished;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppProgressBar(
          value: book.progressFraction,
          height: 4,
          color: finished ? AppColors.success : AppColors.brand,
        ),
        const SizedBox(height: AppSpace.s4),
        Text.rich(
          finished
              ? const TextSpan(text: '已读完')
              : TextSpan(
                  children: [
                    const TextSpan(text: '读到第 '),
                    TextSpan(
                      text: '${progress.page}',
                      style: AppText.number(size: 12, color: AppColors.brand),
                    ),
                    TextSpan(text: ' / ${book.pageCount} 页'),
                  ],
                ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption12,
        ),
      ],
    );
  }
}

/// 网格里的书刊卡：封面、书名、编者与页数、科目与阶段、阅读进度；
/// 传 [onRead] 时底部多一个阅读按钮（我的书架）。
class EbookCard extends StatelessWidget {
  const EbookCard({
    required this.book,
    required this.onTap,
    this.onRead,
    super.key,
  });

  final EbookSummary book;
  final VoidCallback onTap;
  final VoidCallback? onRead;

  static const _padding = AppSpace.s12;

  /// 固定行高：封面按卡片宽度 3:4，下方预留两行书名、两行标签与进度。
  static double extentFor(
    double width, {
    required TextScaler textScaler,
    bool withAction = false,
  }) {
    final cover = (width - _padding * 2) * 4 / 3;
    final metadata = width >= 180 ? 168 : 192;
    final textAllowance = (textScaler.scale(14) - 14).clamp(0.0, 30.0) * 8;
    return cover + metadata + textAllowance + (withAction ? 42 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final onRead = this.onRead;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(_padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EbookCover(url: book.coverUrl, favorite: book.favorite),
          const SizedBox(height: AppSpace.s12),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14Strong,
          ),
          const SizedBox(height: AppSpace.s4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${book.editor} 编 · '),
                TextSpan(
                  text: '${book.pageCount}',
                  style: AppText.number(
                    size: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                const TextSpan(text: ' 页'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption12,
          ),
          const SizedBox(height: AppSpace.s8),
          EbookTags(book: book),
          const Spacer(),
          EbookProgressLine(book: book),
          if (onRead != null) ...[
            const SizedBox(height: AppSpace.s8),
            AppButton(
              label: ebookReadLabel(book, withPage: false),
              variant: AppButtonVariant.quiet,
              size: AppButtonSize.sm,
              expand: true,
              onTap: onRead,
            ),
          ],
        ],
      ),
    );
  }
}

/// 编辑推荐卡：大封面 + 书名 + 一句推荐语。
class EbookFeaturedCard extends StatelessWidget {
  const EbookFeaturedCard({required this.book, required this.onTap, super.key});

  final EbookSummary book;
  final VoidCallback onTap;

  static const height = 176.0;

  @override
  Widget build(BuildContext context) {
    final intro = book.featuredIntro.isNotEmpty
        ? book.featuredIntro
        : book.intro;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: SizedBox(
        height: height - AppSpace.s12 * 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EbookCover(url: book.coverUrl, favorite: book.favorite),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title16,
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    intro,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body13,
                  ),
                  const Spacer(),
                  Text(
                    '${book.categoryLabel} · ${book.editor} 编',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 书刊网格骨架：与 [EbookCard] 同尺寸。
class EbookCardSkeleton extends StatelessWidget {
  const EbookCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: AppSkeleton(radius: AppRadius.control),
          ),
          SizedBox(height: AppSpace.s12),
          AppSkeletonText(lines: 2),
          SizedBox(height: AppSpace.s12),
          AppSkeleton(width: 72, height: AppSize.tag, radius: AppRadius.pill),
        ],
      ),
    );
  }
}

/// 按可用宽度排书刊网格：卡片不窄于 [minItemWidth]，行高固定。
class EbookGrid extends StatelessWidget {
  const EbookGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.withAction = false,
    this.minItemWidth = 160,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool withAction;
  final double minItemWidth;

  static const gap = AppSpace.s16;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final count = ((width + gap) / (minItemWidth + gap)).floor().clamp(
          1,
          8,
        );
        final itemWidth = (width - gap * (count - 1)) / count;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: EbookCard.extentFor(
              itemWidth,
              textScaler: MediaQuery.textScalerOf(context),
              withAction: withAction,
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
