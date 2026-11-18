import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/ui/ui.dart';
import '../../data/ebook_models.dart';

/// 阅读按钮文案：开始阅读 / 继续阅读 / 重新阅读。
String ebookReadLabel(EbookSummary book) {
  if (book.progress == null) {
    return '开始阅读';
  }
  return book.finished ? '重新阅读' : '继续阅读';
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

/// 格子下面那一行：读过的写进度，没读过的写阶段、页数和是否在书架上。
String ebookTileMeta(EbookSummary book) {
  if (book.started) {
    return ebookProgressLabel(book);
  }
  return [
    if (book.stage.isNotEmpty) book.stage,
    '${book.pageCount} 页',
    if (book.favorite) '已在书架',
  ].join(' · ');
}

/// 正在读的书，说明那一行用 `brandDeep`，其余用三级文字色。
Color ebookMetaColor(EbookSummary book) =>
    book.reading ? AppColors.brandDeep : AppColors.textTertiary;

/// 科目标签：素描 / 色彩 / 速写用科目色，美术常识等其他科目用中性灰。
Widget ebookSubjectTag(String subject) {
  final isArt = ArtSubject.values.any((s) => subject.contains(s.label));
  return isArt ? AppTag.subject(subject) : AppTag(label: subject);
}

/// 3:4 封面，完整显示，上面不压任何东西。
///
/// 网格和详情里的大封面用 `AppImageTile.frame`（圆角 6、一圈细描边）；
/// [small] 用在 30 到 72 宽的小封面上，圆角缩成 3。
class EbookCover extends StatelessWidget {
  const EbookCover({required this.url, this.small = false, super.key});

  final String url;
  final bool small;

  static const _smallRadius = BorderRadius.all(Radius.circular(3));

  @override
  Widget build(BuildContext context) {
    final image = AppImage(
      src: url,
      placeholder: const ColoredBox(color: AppColors.canvas),
    );
    if (!small) {
      return AppImageTile.frame(aspectRatio: 3 / 4, child: image);
    }
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: _smallRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: _smallRadius,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.lineSoft),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 网格里的一本书：封面、两行书名、一行说明，整格可点。
/// [meta] 为空时用 [ebookTileMeta]。
class EbookTile extends StatelessWidget {
  const EbookTile({
    required this.book,
    required this.onTap,
    this.meta,
    super.key,
  });

  final EbookSummary book;
  final VoidCallback onTap;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return AppImageTile(
      image: EbookCover(url: book.coverUrl),
      title: book.title,
      meta: meta ?? ebookTileMeta(book),
      metaColor: ebookMetaColor(book),
      onTap: onTap,
    );
  }
}

/// 一本书的小行：小封面在左，书名和一行说明在右，整行可点。
///
/// 编辑推荐（[coverWidth] 33）和详情页的相关书刊（48）用它。
class EbookBookRow extends StatelessWidget {
  const EbookBookRow({
    required this.book,
    required this.note,
    required this.onTap,
    this.coverWidth = 33,
    this.titleLines = 1,
    super.key,
  });

  final EbookSummary book;
  final String note;
  final VoidCallback onTap;
  final double coverWidth;
  final int titleLines;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: note.isEmpty ? book.title : '${book.title}，$note',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              SizedBox(
                width: coverWidth,
                child: EbookCover(url: book.coverUrl, small: true),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong,
                    ),
                    if (note.isNotEmpty)
                      Text(
                        note,
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
      ),
    );
  }
}
