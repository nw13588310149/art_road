import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/ebook_models.dart';
import 'widgets/ebook_widgets.dart';

/// 书刊详情（页内视图）：封面与基本信息、简介、目录（点章节直接从该页阅读）、相关书刊。
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(title: '书刊详情', onBack: onBack),
          Expanded(
            child: loading || error.isEmpty
                ? const _DetailSkeleton()
                : AppErrorState(
                    title: '书刊加载失败',
                    description: error,
                    onRetry: onRetry,
                  ),
          ),
        ],
      );
    }
    final book = detail.book;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: book.title,
          subtitle: '${book.categoryLabel} · ${book.editor} 编',
          onBack: onBack,
          actions: [
            AppButton(
              label: book.favorite ? '已在书架' : '加入书架',
              icon: book.favorite
                  ? Icons.bookmark_added_rounded
                  : Icons.bookmark_add_outlined,
              variant: AppButtonVariant.secondary,
              onTap: () => onToggleFavorite(book),
            ),
            AppButton(
              label: ebookReadLabel(book),
              icon: Icons.menu_book_rounded,
              onTap: () => onRead(book, ebookStartPage(book)),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s4,
              AppSpace.page,
              AppSpace.s24,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final main = _DetailMain(detail: detail, onRead: onRead);
                final side = _DetailSide(
                  detail: detail,
                  onOpenBook: onOpenBook,
                );
                if (constraints.maxWidth >= 760) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: main),
                      const SizedBox(width: AppSpace.s16),
                      SizedBox(width: 300, child: side),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    main,
                    const SizedBox(height: AppSpace.s16),
                    side,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailMain extends StatelessWidget {
  const _DetailMain({required this.detail, required this.onRead});

  final EbookDetail detail;
  final void Function(EbookSummary book, int page) onRead;

  @override
  Widget build(BuildContext context) {
    final book = detail.book;
    final toc = detail.toc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: AppText.title24),
                  if (book.subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      book.subtitle,
                      style: AppText.body14.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s12),
                  Wrap(
                    spacing: AppSpace.s4,
                    runSpacing: AppSpace.s4,
                    children: [
                      for (final subject in book.subjects)
                        AppTag.subject(subject),
                      if (book.categoryLabel.isNotEmpty)
                        AppTag(label: book.categoryLabel),
                      const AppTag(label: '示例', tone: AppTone.info),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s16),
                  _MetaRow(label: '编者', child: _MetaText(book.editor)),
                  _MetaRow(label: '出版', child: _MetaText(book.publisher)),
                  _MetaRow(
                    label: '适用阶段',
                    child: _StageScale(stage: book.stage),
                  ),
                  _MetaRow(
                    label: '页数',
                    child: _MetaNumber(value: '${book.pageCount}', unit: ' 页'),
                  ),
                  if (book.publishDate.isNotEmpty)
                    _MetaRow(
                      label: '发布日期',
                      child: _MetaNumber(value: book.publishDate),
                    ),
                  _MetaRow(
                    label: '阅读',
                    child: _MetaNumber(value: '${book.readers}', unit: ' 人读过'),
                  ),
                  if (book.started) ...[
                    const SizedBox(height: AppSpace.s12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: EbookProgressLine(book: book),
                    ),
                  ],
                ],
              );
              final cover = SizedBox(
                width: constraints.maxWidth >= 420 ? 168 : 112,
                child: EbookCover(url: book.coverUrl, favorite: book.favorite),
              );
              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cover,
                    const SizedBox(height: AppSpace.s16),
                    info,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cover,
                  const SizedBox(width: AppSpace.s20),
                  Expanded(child: info),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        AppCard(
          title: '内容简介',
          child: Text(detail.description, style: AppText.body14),
        ),
        const SizedBox(height: AppSpace.s16),
        AppCard(
          title: '目录',
          subtitle: '共 ${book.pageCount} 页',
          child: toc.isEmpty
              ? Text('这本书刊没有目录。', style: AppText.body13)
              : Column(
                  children: [
                    for (var i = 0; i < toc.length; i++)
                      AppListRow(
                        title: toc[i].title,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s12,
                        ),
                        divider: i < toc.length - 1,
                        chevron: true,
                        trailing: Text(
                          '第 ${toc[i].page} 页',
                          style: AppText.caption12,
                        ),
                        onTap: () => onRead(book, toc[i].page),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DetailSide extends StatelessWidget {
  const _DetailSide({required this.detail, required this.onOpenBook});

  final EbookDetail detail;
  final ValueChanged<String> onOpenBook;

  @override
  Widget build(BuildContext context) {
    final related = detail.related;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          title: '相关书刊',
          child: related.isEmpty
              ? Text('暂时没有相关书刊。', style: AppText.body13)
              : Column(
                  children: [
                    for (var i = 0; i < related.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpace.s12),
                      _RelatedRow(
                        book: related[i],
                        onTap: () => onOpenBook(related[i].id),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.s16),
        AppCard(
          color: AppColors.surfaceSubtle,
          bordered: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  '示例书刊，仅供演示：内容为「美育集」自制示例，非正式出版物，没有书号与定价。',
                  style: AppText.body13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.book, required this.onTap});

  final EbookSummary book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: book.title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 54, child: EbookCover(url: book.coverUrl)),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  '${book.categoryLabel} · ${book.editor} 编',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12,
                ),
                if (book.started) ...[
                  const SizedBox(height: AppSpace.s8),
                  EbookProgressLine(book: book),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 72, child: Text(label, style: AppText.caption12)),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.body14,
    );
  }
}

class _MetaNumber extends StatelessWidget {
  const _MetaNumber({required this.value, this.unit = ''});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value, style: AppText.number(size: 14)),
          if (unit.isNotEmpty) TextSpan(text: unit),
        ],
      ),
      maxLines: 1,
      style: AppText.body14,
    );
  }
}

/// 基础 / 提高 / 冲刺，当前书刊适用的阶段为选中态。
class _StageScale extends StatelessWidget {
  const _StageScale({required this.stage});

  final String stage;

  static const _stages = ['基础', '提高', '冲刺'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.s4,
      runSpacing: AppSpace.s4,
      children: [
        for (final item in _stages)
          AppTag(
            label: item,
            tone: item == stage ? AppTone.brand : AppTone.neutral,
          ),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s4,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 168,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: AppSkeleton(radius: AppRadius.control),
              ),
            ),
            SizedBox(width: AppSpace.s20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 280, height: 24),
                  SizedBox(height: AppSpace.s12),
                  AppSkeleton(width: 180),
                  SizedBox(height: AppSpace.s24),
                  AppSkeletonText(lines: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
