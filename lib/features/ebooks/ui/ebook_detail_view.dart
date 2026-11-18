import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/ebook_models.dart';
import 'widgets/ebook_widgets.dart';

/// 书刊详情（页内视图）：页头是书名、加入书架和阅读；主栏是封面与出处、简介、
/// 目录（点章节从那一页读起），侧栏是相关书刊。整页一起滚动。
class EbookDetailView extends StatelessWidget {
  const EbookDetailView({
    required this.detail,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onRetry,
    required this.onRead,
    required this.onToggleFavorite,
    required this.onOpenBook,
    super.key,
  });

  final EbookDetail? detail;
  final bool loading;
  final String error;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  /// 打开阅读器；[page] 为 0 时从上次的进度继续。
  final void Function(EbookSummary book, int page) onRead;
  final ValueChanged<EbookSummary> onToggleFavorite;
  final ValueChanged<String> onOpenBook;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    if (detail == null) {
      return AppPageBody(
        scrollable: false,
        builder: (context, wide) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTitleBar(title: '书刊详情', onBack: onBack),
            Expanded(
              child: loading || error.isEmpty
                  ? const Center(child: AppLoadingIndicator())
                  : AppErrorState(
                      title: '书刊加载失败',
                      description: error,
                      onRetry: onRetry,
                    ),
            ),
          ],
        ),
      );
    }
    final book = detail.book;
    return AppPageBody(
      builder: (context, wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTitleBar(
            title: book.title,
            onBack: onBack,
            actions: [
              AppPlainButton(
                label: book.favorite ? '已在书架' : '加入书架',
                icon: book.favorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                onTap: () => onToggleFavorite(book),
              ),
              const SizedBox(width: AppSpace.s8),
              AppButton(
                label: ebookReadLabel(book),
                onTap: () => onRead(book, ebookStartPage(book)),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DetailMain(detail: detail, wide: wide, onRead: onRead),
              ),
              SizedBox(width: AppPageBody.columnGap(wide)),
              SizedBox(
                width: AppPageBody.sideWidth(wide),
                child: _Related(books: detail.related, onOpenBook: onOpenBook),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailMain extends StatelessWidget {
  const _DetailMain({
    required this.detail,
    required this.wide,
    required this.onRead,
  });

  final EbookDetail detail;
  final bool wide;
  final void Function(EbookSummary book, int page) onRead;

  @override
  Widget build(BuildContext context) {
    final book = detail.book;
    final toc = detail.toc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: wide ? 168 : 136,
              child: EbookCover(url: book.coverUrl),
            ),
            const SizedBox(width: AppSpace.s24),
            Expanded(child: _Facts(book: book)),
          ],
        ),
        const SizedBox(height: AppSpace.s24),
        const AppRule(),
        const SizedBox(height: AppSpace.s24),
        const AppSectionTitle(title: '内容简介'),
        const SizedBox(height: AppSpace.s12),
        Text(
          detail.description.isEmpty ? '暂无简介' : detail.description,
          style: AppText.body14.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.s24),
        const AppRule(),
        const SizedBox(height: AppSpace.s24),
        AppSectionTitle(
          title: '目录',
          note: toc.isEmpty
              ? '共 ${book.pageCount} 页'
              : '共 ${book.pageCount} 页 · 点章节从那一页读起',
        ),
        const SizedBox(height: AppSpace.s8),
        if (toc.isEmpty)
          Text('这本书刊没有目录。', style: AppText.body13)
        else
          for (final (index, entry) in toc.indexed) ...[
            if (index > 0) const AppRule(),
            _TocRow(
              entry: entry,
              current: book.reading && _currentChapter(book, toc) == index,
              onTap: () => onRead(book, entry.page),
            ),
          ],
        const SizedBox(height: AppSpace.s24),
        Text(
          '示例书刊，仅供演示：内容为「美育集」自制示例，非正式出版物，没有书号与定价。',
          style: AppText.caption12,
        ),
      ],
    );
  }

  /// 读到的那一页所在的章节序号；读到目录第一章之前时返回 -1。
  static int _currentChapter(EbookSummary book, List<EbookTocEntry> toc) {
    final page = book.progress?.page ?? 0;
    var match = -1;
    for (final (index, entry) in toc.indexed) {
      if (entry.page <= page) {
        match = index;
      }
    }
    return match;
  }
}

/// 封面右边：副标题、科目和分类、出处、阅读进度。
class _Facts extends StatelessWidget {
  const _Facts({required this.book});

  final EbookSummary book;

  @override
  Widget build(BuildContext context) {
    final source = [
      if (book.publisher.isNotEmpty) book.publisher,
      if (book.publishDate.isNotEmpty) '${book.publishDate} 发布',
    ].join(' · ');
    final scope = [
      if (book.stage.isNotEmpty) '适用阶段 ${book.stage}',
      '${book.pageCount} 页',
      '${book.readers} 人读过',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (book.subtitle.isNotEmpty) ...[
          Text(book.subtitle, style: AppText.body16),
          const SizedBox(height: AppSpace.s12),
        ],
        Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s4,
          children: [
            for (final subject in book.subjects) ebookSubjectTag(subject),
            if (book.categoryLabel.isNotEmpty)
              AppTag(label: book.categoryLabel),
          ],
        ),
        const SizedBox(height: AppSpace.s16),
        if (book.editor.isNotEmpty)
          Text('${book.editor} 编', style: AppText.body14),
        if (source.isNotEmpty) Text(source, style: AppText.body13),
        Text(scope, style: AppText.body13),
        if (book.started) ...[
          const SizedBox(height: AppSpace.s16),
          Text(
            ebookProgressLabel(book),
            style: AppText.body14Strong.copyWith(color: ebookMetaColor(book)),
          ),
        ],
      ],
    );
  }
}

/// 目录的一行：左边 44 宽的页码，中间章节名，右边箭头；读到的那一章加粗并注明。
class _TocRow extends StatelessWidget {
  const _TocRow({
    required this.entry,
    required this.current,
    required this.onTap,
  });

  final EbookTocEntry entry;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: current
          ? '${entry.title}，第 ${entry.page} 页，读到这里'
          : '${entry.title}，第 ${entry.page} 页',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '${entry.page}',
                  style: AppText.number(size: 14, color: AppColors.textTertiary),
                ),
              ),
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: current ? AppText.body14Strong : AppText.body14,
                ),
              ),
              if (current) ...[
                const SizedBox(width: AppSpace.s12),
                Text('读到这里', style: AppText.caption12Strong),
              ],
              const SizedBox(width: AppSpace.s8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textPlaceholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 侧栏：相关书刊，小封面加书名，比主封面小得多。
class _Related extends StatelessWidget {
  const _Related({required this.books, required this.onOpenBook});

  final List<EbookSummary> books;
  final ValueChanged<String> onOpenBook;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionTitle(title: '相关书刊'),
        const SizedBox(height: AppSpace.s12),
        if (books.isEmpty)
          Text('暂时没有相关书刊。', style: AppText.body13)
        else
          for (final (index, book) in books.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpace.s16),
            EbookBookRow(
              book: book,
              coverWidth: 48,
              titleLines: 2,
              note: book.started
                  ? ebookProgressLabel(book)
                  : [
                      if (book.categoryLabel.isNotEmpty) book.categoryLabel,
                      if (book.stage.isNotEmpty) book.stage,
                    ].join(' · '),
              onTap: () => onOpenBook(book.id),
            ),
          ],
      ],
    );
  }
}
