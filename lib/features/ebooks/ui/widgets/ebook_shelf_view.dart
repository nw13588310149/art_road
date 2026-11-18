import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/ebook_models.dart';
import '../../state/ebooks_state.dart';
import 'ebook_library_view.dart';
import 'ebook_widgets.dart';

/// 书架的排列：在读的排在前面（最近读的在最前），其余保持原来的顺序。
List<EbookSummary> ebookShelfOrder(List<EbookSummary> items) {
  final reading = items.where((b) => b.reading).toList()
    ..sort((a, b) => b.progress!.updatedAt.compareTo(a.progress!.updatedAt));
  return [...reading, ...items.where((b) => !b.reading)];
}

/// 我的书架：收藏和读过的书，封面网格和书库一样，点封面进详情。
class EbookShelfView extends StatelessWidget {
  const EbookShelfView({
    required this.state,
    required this.wide,
    required this.onOpen,
    required this.onRetry,
    required this.onBrowse,
    super.key,
  });

  final EbooksState state;
  final bool wide;
  final ValueChanged<EbookSummary> onOpen;
  final VoidCallback onRetry;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final items = ebookShelfOrder(state.shelfItems);
    if (items.isEmpty) {
      return SizedBox(height: kEbookStateHeight, child: _buildState());
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s24),
      child: AppTileGrid(
        columns: wide ? 5 : 4,
        gap: AppPageBody.tileGap(wide),
        children: [
          for (final book in items)
            EbookTile(
              book: book,
              meta: book.started ? ebookProgressLabel(book) : '尚未开始阅读',
              onTap: () => onOpen(book),
            ),
        ],
      ),
    );
  }

  Widget _buildState() {
    if (state.shelfLoading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (state.shelfError.isNotEmpty) {
      return AppErrorState(
        title: '书架加载失败',
        description: state.shelfError,
        onRetry: onRetry,
      );
    }
    return AppEmptyState(
      icon: Icons.menu_book_outlined,
      title: switch (state.shelfFilter) {
        EbookShelfFilter.all => '书架还是空的',
        EbookShelfFilter.reading => '没有正在读的书刊',
        EbookShelfFilter.favorite => '还没有加入书架的书刊',
      },
      description: '在书刊详情里点「加入书架」，或开始阅读后，书刊会出现在这里',
      actionLabel: '去书库看看',
      onAction: onBrowse,
    );
  }
}

/// 书架里的小切换：全部 / 在读 / 收藏，带数量；右边一句说明。
class EbookShelfBar extends StatelessWidget {
  const EbookShelfBar({
    required this.state,
    required this.onChanged,
    super.key,
  });

  final EbooksState state;
  final ValueChanged<EbookShelfFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final shelf = state.shelf;
    int countOf(EbookShelfFilter filter) => switch (filter) {
      EbookShelfFilter.all => shelf.records.length,
      EbookShelfFilter.reading => shelf.reading.length,
      EbookShelfFilter.favorite => shelf.favorites.length,
    };
    return SizedBox(
      height: AppFilterBar.height,
      child: Row(
        children: [
          AppViewTabs<EbookShelfFilter>(
            dense: true,
            items: [
              for (final filter in EbookShelfFilter.values)
                AppViewTab(
                  value: filter,
                  label: filter.label,
                  count: countOf(filter),
                ),
            ],
            value: state.shelfFilter,
            onChanged: onChanged,
          ),
          const Spacer(),
          Text('阅读进度自动保存', style: AppText.caption12),
        ],
      ),
    );
  }
}
