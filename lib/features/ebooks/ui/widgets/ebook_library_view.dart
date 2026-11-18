import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/ebook_models.dart';
import '../../state/ebooks_state.dart';
import 'ebook_lead_strip.dart';
import 'ebook_widgets.dart';

/// 空、加载、出错时列表区域的高度，和正常的网格占同一个位置。
const double kEbookStateHeight = 360;

/// 书库视图在筛选条下面的部分：接着读、全部书刊的封面网格、列表末尾。
class EbookLibraryView extends StatelessWidget {
  const EbookLibraryView({
    required this.state,
    required this.wide,
    required this.onOpen,
    required this.onRead,
    required this.onRetry,
    required this.onClearSearch,
    required this.onShowAll,
    super.key,
  });

  final EbooksState state;
  final bool wide;
  final ValueChanged<EbookSummary> onOpen;
  final ValueChanged<EbookSummary> onRead;
  final VoidCallback onRetry;
  final VoidCallback onClearSearch;
  final VoidCallback onShowAll;

  /// 接着读的那一本：最近读过、还没读完的；没有时是第一本编辑推荐。
  static EbookSummary? leadOf(EbooksState state) {
    final reading = state.shelf.reading;
    if (reading.isNotEmpty) {
      return reading.first;
    }
    for (final book in state.books) {
      if (book.reading) {
        return book;
      }
    }
    return state.featured.isNotEmpty ? state.featured.first : null;
  }

  @override
  Widget build(BuildContext context) {
    if (state.books.isEmpty) {
      return SizedBox(height: kEbookStateHeight, child: _buildState());
    }
    final lead = state.hasFilters ? null : leadOf(state);
    final picks = [
      for (final book in state.featured)
        if (book.id != lead?.id) book,
    ];
    final label = state.categoryLabelOf(state.category);
    final title = state.keyword.isNotEmpty
        ? '搜索结果'
        : (state.category == EbookCategory.allKey || label.isEmpty
              ? '全部书刊'
              : label);
    final gap = AppPageBody.tileGap(wide);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lead != null) ...[
          const SizedBox(height: AppSpace.s24),
          EbookLeadStrip(
            lead: lead,
            picks: picks,
            wide: wide,
            onOpen: onOpen,
            onRead: onRead,
          ),
          const SizedBox(height: AppSpace.s24),
          const AppRule(),
        ],
        const SizedBox(height: AppSpace.s24),
        AppSectionTitle(title: title, note: '共 ${state.total} 本'),
        const SizedBox(height: AppSpace.s16),
        Stack(
          children: [
            AppTileGrid(
              columns: wide ? 5 : 4,
              gap: gap,
              children: [
                for (final book in state.books)
                  EbookTile(book: book, onTap: () => onOpen(book)),
              ],
            ),
            // 换筛选时先留着旧的书，等新结果回来再换。
            if (state.loading)
              const Positioned.fill(
                child: AppLoadingOverlay(scrimColor: Color(0xB3FFFFFF)),
              ),
          ],
        ),
        _ListEnd(state: state),
      ],
    );
  }

  Widget _buildState() {
    if (state.loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (state.errorMessage.isNotEmpty) {
      return AppErrorState(
        title: '书刊加载失败',
        description: state.errorMessage,
        onRetry: onRetry,
      );
    }
    if (state.keyword.isNotEmpty) {
      return AppEmptyState(
        icon: Icons.search_rounded,
        title: '没有找到与「${state.keyword}」相关的书刊',
        description: '换个书名、编者或知识点试试',
        actionLabel: '清除搜索',
        onAction: onClearSearch,
      );
    }
    return AppEmptyState(
      icon: Icons.menu_book_outlined,
      title: '这个分类下暂时还没有书刊',
      description: '换个分类看看',
      actionLabel: state.hasFilters ? '查看全部书刊' : null,
      onAction: state.hasFilters ? onShowAll : null,
    );
  }
}

class _ListEnd extends StatelessWidget {
  const _ListEnd({required this.state});

  final EbooksState state;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.s16),
        child: Center(child: AppLoadingIndicator()),
      );
    }
    if (state.hasMore) {
      return const SizedBox(height: AppSpace.s24);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s32),
      child: Center(
        child: Text(
          '已显示全部 ${state.books.length} 本',
          style: AppText.caption12,
        ),
      ),
    );
  }
}
