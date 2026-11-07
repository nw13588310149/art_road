import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/ebook_models.dart';
import '../navigation/ebook_navigation.dart';
import '../state/home_ebook_shelf.dart';
import 'widgets/ebook_widgets.dart';

/// 首页「精选书刊 / 继续阅读」：左侧是在读的书刊（直接回到上次的页码），
/// 右侧是按推荐排序的精选封面；宽度不足 720 时上下排列。
class HomeEbookShelfSection extends ConsumerWidget {
  const HomeEbookShelfSection({super.key});

  static const _bodyHeight = 212.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(homeEbookShelfProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppSectionHeader(
                  title: '精选书刊',
                  subtitle: '美术教辅与期刊 · 示例内容',
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              AppButton(
                label: '全部书刊',
                variant: AppButtonVariant.text,
                size: AppButtonSize.sm,
                onTap: () => EbookNavigation.openEbooks(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          shelf.when(
            loading: () => const _ShelfSkeleton(height: _bodyHeight),
            error: (_, _) => SizedBox(
              height: _bodyHeight,
              child: AppErrorState(
                title: '书刊加载失败',
                description: '请稍后重试',
                onRetry: () => ref.invalidate(homeEbookShelfProvider),
              ),
            ),
            data: (data) {
              if (data.picks.isEmpty && data.reading.isEmpty) {
                return const SizedBox(
                  height: _bodyHeight,
                  child: AppEmptyState(
                    icon: Icons.menu_book_outlined,
                    title: '暂时还没有书刊',
                    description: '书刊上架后会出现在这里',
                  ),
                );
              }
              return _ShelfBody(
                data: data,
                onOpen: (book) =>
                    EbookNavigation.openEbooks(context, bookId: book.id),
                onContinue: (book) async {
                  await EbookNavigation.openReader(context, bookId: book.id);
                  if (context.mounted) {
                    ref.invalidate(homeEbookShelfProvider);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShelfBody extends StatelessWidget {
  const _ShelfBody({required this.data, required this.onOpen, required this.onContinue});

  final HomeEbookShelfData data;
  final ValueChanged<EbookSummary> onOpen;
  final ValueChanged<EbookSummary> onContinue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final reading = data.reading.take(2).toList();
        final continueCard = reading.isEmpty
            ? null
            : _ContinueReading(books: reading, onContinue: onContinue);
        final picks = data.picks.isEmpty
            ? null
            : _Picks(books: data.picks, onOpen: onOpen);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (continueCard != null) ...[
                SizedBox(width: 340, child: continueCard),
                if (picks != null) const SizedBox(width: AppSpace.s16),
              ],
              if (picks != null) Expanded(child: picks),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?continueCard,
            if (continueCard != null && picks != null)
              const SizedBox(height: AppSpace.s16),
            ?picks,
          ],
        );
      },
    );
  }
}

class _ContinueReading extends StatelessWidget {
  const _ContinueReading({required this.books, required this.onContinue});

  final List<EbookSummary> books;
  final ValueChanged<EbookSummary> onContinue;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('继续阅读', style: AppText.body14Strong),
          for (final book in books) ...[
            const SizedBox(height: AppSpace.s12),
            Row(
              children: [
                SizedBox(width: 48, child: EbookCover(url: book.coverUrl)),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body14Strong,
                      ),
                      const SizedBox(height: AppSpace.s8),
                      EbookProgressLine(book: book),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                AppButton(
                  label: '继续阅读',
                  variant: AppButtonVariant.quiet,
                  size: AppButtonSize.sm,
                  onTap: () => onContinue(book),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Picks extends StatelessWidget {
  const _Picks({required this.books, required this.onOpen});

  final List<EbookSummary> books;
  final ValueChanged<EbookSummary> onOpen;

  static const _minItemWidth = 96.0;
  static const _maxItemWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpace.s12;
        final width = constraints.maxWidth;
        final count = ((width + gap) / (_minItemWidth + gap)).floor().clamp(1, books.length);
        final itemWidth = ((width - gap * (count - 1)) / count).clamp(_minItemWidth, _maxItemWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: itemWidth,
                child: AppPressable(
                  onTap: () => onOpen(books[i]),
                  semanticLabel: books[i].title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EbookCover(url: books[i].coverUrl, favorite: books[i].favorite),
                      const SizedBox(height: AppSpace.s8),
                      Text(
                        books[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body13.copyWith(color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ShelfSkeleton extends StatelessWidget {
  const _ShelfSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (constraints.maxWidth >= 720) ...[
              const SizedBox(
                width: 340,
                child: AppSkeleton(height: 160, radius: AppRadius.card),
              ),
              const SizedBox(width: AppSpace.s16),
            ],
            const Expanded(child: AppSkeleton(height: 160, radius: AppRadius.card)),
          ],
        ),
      ),
    );
  }
}
