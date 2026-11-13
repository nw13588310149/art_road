import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/course_subject_tag.dart';
import '../../gallery/ui/widgets/library_controls.dart';
import '../data/ebook_models.dart';
import 'widgets/ebook_widgets.dart';

/// 书刊详情（页内视图）：封面与基本信息、简介、目录（点章节直接从该页阅读）、相关书刊。
///
/// 版式取自原版的文件预览：56 高的工具栏（返回、居中的书名、操作胶囊），正文左侧
/// 是浅色画布里的封面与信息，右侧 160 宽的白色栏（左分隔线）竖排相关书刊的封面。
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
          LibraryPreviewHeader(title: '书刊详情', onBack: onBack),
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
      );
    }
    final book = detail.book;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        // 工具栏太窄时「加入书架」只留图标，阅读按钮保留文字。
        final compact = constraints.maxWidth < 520;
        final main = _DetailMain(
          detail: detail,
          onRead: onRead,
          onOpenBook: onOpenBook,
          inlineRelated: !wide,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LibraryPreviewHeader(
              title: book.title,
              onBack: onBack,
              actions: [
                LibraryActionPill(
                  label: book.favorite ? '已在书架' : '加入书架',
                  iconAsset: book.favorite
                      ? AppAssets.videoV2StarFilled
                      : AppAssets.videoV2Star,
                  iconSize: book.favorite ? 14 : 20,
                  active: book.favorite,
                  compact: compact,
                  onTap: () => onToggleFavorite(book),
                ),
                LibraryActionPill(
                  label: ebookReadLabel(book),
                  iconAsset: AppAssets.videoV2RelatedPlay,
                  iconSize: 16,
                  primary: true,
                  onTap: () => onRead(book, ebookStartPage(book)),
                ),
              ],
            ),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: main),
                        _RelatedRail(
                          books: detail.related,
                          onOpenBook: onOpenBook,
                        ),
                      ],
                    )
                  : main,
            ),
          ],
        );
      },
    );
  }
}

class _DetailMain extends StatelessWidget {
  const _DetailMain({
    required this.detail,
    required this.onRead,
    required this.onOpenBook,
    required this.inlineRelated,
  });

  final EbookDetail detail;
  final void Function(EbookSummary book, int page) onRead;
  final ValueChanged<String> onOpenBook;

  /// 窄屏没有右侧栏，相关书刊排在正文末尾。
  final bool inlineRelated;

  @override
  Widget build(BuildContext context) {
    final book = detail.book;
    final toc = detail.toc;
    final related = detail.related;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Summary(book: book),
          const _Section(title: '内容简介'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle.withValues(alpha: 0.6),
              borderRadius: AppRadius.br8,
            ),
            child: Text(
              detail.description.isEmpty ? '暂无简介' : detail.description,
              style: libraryText(size: 13, color: AppColors.ink, height: 2),
            ),
          ),
          _Section(
            title: '目录',
            trailing: Text(
              '共 ${book.pageCount} 页',
              style: libraryText(size: 12, color: AppColors.textPlaceholder),
            ),
            bottom: 4,
          ),
          if (toc.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '这本书刊没有目录。',
                style: libraryText(size: 12, color: AppColors.textPlaceholder),
              ),
            )
          else
            for (var i = 0; i < toc.length; i++)
              _TocRow(
                entry: toc[i],
                divider: i < toc.length - 1,
                onTap: () => onRead(book, toc[i].page),
              ),
          if (inlineRelated) ...[
            const _Section(title: '相关书刊'),
            if (related.isEmpty)
              Text(
                '暂时没有相关书刊。',
                style: libraryText(size: 12, color: AppColors.textPlaceholder),
              )
            else
              SizedBox(
                height: _RelatedItem.height,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: related.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _RelatedItem(
                    book: related[index],
                    onTap: () => onOpenBook(related[index].id),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: AppRadius.br8,
            ),
            child: Text(
              '示例书刊，仅供演示：内容为「美育集」自制示例，非正式出版物，没有书号与定价。',
              style: libraryText(
                size: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 封面与基本信息：浅色画布（圆角 7）里左封面、右信息。
class _Summary extends StatelessWidget {
  const _Summary({required this.book});

  final EbookSummary book;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: LibraryCanvas.radius,
      child: ColoredBox(
        color: LibraryPalette.canvas,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (book.subtitle.isNotEmpty) ...[
                    Text(
                      book.subtitle,
                      style: libraryText(
                        size: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final subject in book.subjects)
                        CourseSubjectTag(name: subject),
                      if (book.categoryLabel.isNotEmpty)
                        LibraryTag(
                          book.categoryLabel,
                          background: AppColors.surface,
                        ),
                      LibraryTag.brand('示例'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MetaRow(label: '编者：', child: _MetaText(book.editor)),
                  _MetaRow(label: '出版：', child: _MetaText(book.publisher)),
                  _MetaRow(
                    label: '适用阶段：',
                    child: _StageScale(stage: book.stage),
                  ),
                  _MetaRow(
                    label: '页数：',
                    child: _MetaNumber(value: '${book.pageCount}', unit: ' 页'),
                  ),
                  if (book.publishDate.isNotEmpty)
                    _MetaRow(
                      label: '发布日期：',
                      child: _MetaNumber(value: book.publishDate),
                    ),
                  _MetaRow(
                    label: '阅读：',
                    child: _MetaNumber(value: '${book.readers}', unit: ' 人读过'),
                  ),
                  if (book.started) ...[
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: EbookProgressLine(book: book),
                    ),
                  ],
                ],
              );
              final cover = SizedBox(
                width: constraints.maxWidth >= 420 ? 168 : 112,
                child: EbookCover(
                  url: book.coverUrl,
                  favorite: book.favorite,
                  elevated: true,
                ),
              );
              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [cover, const SizedBox(height: 16), info],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cover,
                  const SizedBox(width: 20),
                  Expanded(child: info),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.trailing, this.bottom = 12});

  final String title;
  final Widget? trailing;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 20, bottom: bottom),
      child: LibrarySectionTitle(title, trailing: trailing),
    );
  }
}

/// 目录行：46 高、14 号字，右侧页码与箭头，行间 1px 细线。
class _TocRow extends StatelessWidget {
  const _TocRow({
    required this.entry,
    required this.divider,
    required this.onTap,
  });

  final EbookTocEntry entry;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: divider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: libraryText(size: 14, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '第 ${entry.page} 页',
              style: libraryText(size: 12, color: AppColors.textPlaceholder),
            ),
            const SizedBox(width: 2),
            const AppAssetGraphic(AppAssets.listChevron, width: 20, height: 20),
          ],
        ),
      ),
    );
  }
}

/// 右侧栏：160 宽、白底、左侧 1px 分隔线，竖排相关书刊的封面（128×170）。
class _RelatedRail extends StatelessWidget {
  const _RelatedRail({required this.books, required this.onOpenBook});

  final List<EbookSummary> books;
  final ValueChanged<String> onOpenBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Semantics(
              header: true,
              child: Text(
                '相关书刊',
                style: libraryText(
                  size: 16,
                  weight: AppFont.w600,
                  color: AppColors.ink,
                  height: 1,
                ),
              ),
            ),
          ),
          Expanded(
            child: books.isEmpty
                ? Center(
                    child: Text(
                      '暂无相关书刊',
                      style: libraryText(
                        size: 12,
                        color: AppColors.textPlaceholder,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: books.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _RelatedItem(
                      book: books[index],
                      onTap: () => onOpenBook(books[index].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 一本相关书刊：128×170 的封面（圆角 9、1px 浅描边），右下角徽标显示分类或
/// 阅读进度，下面是两行书名。
class _RelatedItem extends StatelessWidget {
  const _RelatedItem({required this.book, required this.onTap});

  final EbookSummary book;
  final VoidCallback onTap;

  static const double width = 128;
  static const double coverHeight = 170;
  static const double height = coverHeight + 6 + 32;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: book.title,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: coverHeight,
              child: EbookCoverImage(
                url: book.coverUrl,
                radius: 9,
                bordered: true,
                badge:
                    EbookCoverBadge.progressOf(book) ??
                    (book.categoryLabel.isEmpty
                        ? null
                        : EbookCoverBadge(book.categoryLabel)),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: libraryText(
                  size: 12,
                  weight: AppFont.w500,
                  color: AppColors.ink,
                  height: 16 / 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 键值行：标签列宽 80、14 号灰字，值 14 号墨色，行间 8。
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: libraryText(
                size: 14,
                color: AppColors.textPlaceholder,
                height: 1.4,
              ),
            ),
          ),
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
      style: libraryText(size: 14, color: AppColors.ink, height: 1.4),
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
      style: libraryText(size: 14, color: AppColors.ink, height: 1.4),
    );
  }
}

/// 基础 / 提高 / 冲刺，当前书刊适用的阶段带颜色，其余置灰。
class _StageScale extends StatelessWidget {
  const _StageScale({required this.stage});

  final String stage;

  static const _stages = ['基础', '提高', '冲刺'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final item in _stages)
          item == stage
              ? ebookStageBadge(item)
              : LibraryTag(
                  item,
                  foreground: AppColors.textPlaceholder,
                  background: AppColors.surface,
                ),
      ],
    );
  }
}
