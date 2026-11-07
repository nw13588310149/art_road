import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/ebook_models.dart';
import '../navigation/ebook_navigation.dart';
import '../state/ebooks_controller.dart';
import '../state/ebooks_state.dart';
import 'ebook_detail_view.dart';
import 'widgets/ebook_widgets.dart';

/// 美术书刊：编辑推荐、分类浏览、搜索与排序、我的书架，以及页内详情。
///
/// 路由参数（均可选）：`{'bookId': String, 'category': 分类 key 或名称}`；
/// 带 `bookId` 时直接打开详情，详情返回即关闭本页（回到首页、收藏、搜索等来源页）。
class EbooksPage extends ConsumerStatefulWidget {
  const EbooksPage({this.args, super.key});

  /// 为 null 时读取当前路由的 arguments。
  final Map<String, dynamic>? args;

  @override
  ConsumerState<EbooksPage> createState() => _EbooksPageState();
}

class _EbooksPageState extends ConsumerState<EbooksPage> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  EbooksQuery? _query;

  EbooksQuery get _currentQuery => _query ?? const EbooksQuery();

  EbooksController get _controller =>
      ref.read(ebooksControllerProvider(_currentQuery).notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _query ??= EbooksQuery.fromArgs(
      widget.args ?? ModalRoute.of(context)?.settings.arguments,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_handleScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 480) {
      unawaited(_controller.loadMore());
    }
  }

  void _applyFilter(VoidCallback change) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    change();
  }

  void _onKeywordChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _applyFilter(() => _controller.setKeyword(value)),
    );
  }

  void _onKeywordSubmitted(String value) {
    _debounce?.cancel();
    _applyFilter(() => _controller.setKeyword(value));
  }

  void _resetFilters() {
    _debounce?.cancel();
    _search.clear();
    _applyFilter(_controller.resetFilters);
  }

  Future<void> _toggleFavorite(EbookSummary book) async {
    final ok = await _controller.toggleFavorite(book);
    if (!mounted) {
      return;
    }
    if (ok) {
      AppToast.showSuccess(context, book.favorite ? '已移出书架' : '已加入书架');
    } else {
      AppToast.showError(context, '操作失败，请稍后重试');
    }
  }

  Future<void> _read(EbookSummary book, [int page = 0]) async {
    final progress = await EbookNavigation.openReader(
      context,
      bookId: book.id,
      page: page,
    );
    if (!mounted) {
      return;
    }
    unawaited(_controller.applyReading(book.id, progress));
  }

  /// 通过 `bookId` 直达的详情返回时关闭整页，其余情况回到列表 / 上一本书。
  void _closeDetail(EbooksState state) {
    final entryId = _currentQuery.bookId;
    final isEntryDetail =
        entryId.isNotEmpty &&
        state.detailStack.length == 1 &&
        state.detailStack.first == entryId;
    if (isEntryDetail) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
    }
    _controller.closeDetail();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ebooksControllerProvider(_currentQuery);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<EbooksState>(provider, (previous, next) {
      if (!identical(previous?.books, next.books)) {
        // 首屏不足一屏时不会触发滚动，布局完成后再检查一次是否需要加载下一页。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleScroll();
          }
        });
      }
      final msg = next.errorMessage;
      // 列表为空时由错误状态展示，有旧数据时只弹轻提示。
      if (msg.isEmpty || msg == previous?.errorMessage || next.books.isEmpty) {
        return;
      }
      AppToast.showError(context, msg);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.clearError();
        }
      });
    });

    final openId = state.openBookId;
    final canPop = Navigator.of(context).canPop();
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.br16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: openId != null,
              child: TickerMode(
                enabled: openId == null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(state, canPop),
                    Expanded(
                      child: state.view == EbooksView.browse
                          ? _buildBrowse(state)
                          : _buildShelf(state),
                    ),
                  ],
                ),
              ),
            ),
            if (openId != null)
              ColoredBox(
                color: AppColors.surface,
                child: EbookDetailView(
                  key: ValueKey(openId),
                  detail: state.details[openId],
                  loading: state.detailLoading.contains(openId),
                  error: state.detailErrors[openId] ?? '',
                  onBack: () => _closeDetail(state),
                  onRetry: () => unawaited(controller.retryDetail()),
                  onRead: (book, page) => unawaited(_read(book, page)),
                  onToggleFavorite: (book) => unawaited(_toggleFavorite(book)),
                  onOpenBook: controller.openDetail,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(EbooksState state, bool canPop) {
    final browse = state.view == EbooksView.browse;
    return AppPageHeader(
      title: '美术书刊',
      subtitle: '精选美术教辅与期刊（示例内容）',
      onBack: canPop ? () => Navigator.of(context).maybePop() : null,
      actions: [
        if (browse)
          SizedBox(
            width: 220,
            child: AppSearchField(
              controller: _search,
              hint: '搜索书名、编者、知识点',
              onChanged: _onKeywordChanged,
              onSubmitted: _onKeywordSubmitted,
            ),
          ),
        AppSegmented<EbooksView>(
          segments: const [
            AppSegment(value: EbooksView.browse, label: '书库'),
            AppSegment(value: EbooksView.shelf, label: '我的书架'),
          ],
          value: state.view,
          onChanged: _controller.setView,
        ),
      ],
      bottom: browse ? _buildBrowseFilters(state) : _buildShelfFilters(state),
    );
  }

  Widget _buildBrowseFilters(EbooksState state) {
    final Widget tabs = state.categories.isEmpty
        ? const Align(
            alignment: Alignment.centerLeft,
            child: AppSkeleton(width: 420, height: 20),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AppTabs<String>(
              gap: AppSpace.s16,
              tabs: [
                for (final category in state.categories)
                  AppTab(value: category.key, label: category.label),
              ],
              value: state.category,
              onChanged: (key) =>
                  _applyFilter(() => _controller.setCategory(key)),
            ),
          );
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(child: SizedBox(height: 44, child: tabs)),
          const SizedBox(width: AppSpace.s16),
          AppSegmented<EbookSort>(
            segments: [
              for (final sort in EbookSort.values)
                AppSegment(value: sort, label: sort.label),
            ],
            value: state.sort,
            size: AppControlSize.sm,
            onChanged: (sort) => _applyFilter(() => _controller.setSort(sort)),
          ),
        ],
      ),
    );
  }

  Widget _buildShelfFilters(EbooksState state) {
    final shelf = state.shelf;
    int countOf(EbookShelfFilter filter) => switch (filter) {
      EbookShelfFilter.all => shelf.records.length,
      EbookShelfFilter.reading => shelf.reading.length,
      EbookShelfFilter.favorite => shelf.favorites.length,
    };
    return Row(
      children: [
        AppSegmented<EbookShelfFilter>(
          segments: [
            for (final filter in EbookShelfFilter.values)
              AppSegment(value: filter, label: '${filter.label} ${countOf(filter)}'),
          ],
          value: state.shelfFilter,
          size: AppControlSize.sm,
          onChanged: _controller.setShelfFilter,
        ),
        const SizedBox(width: AppSpace.s16),
        Expanded(
          child: Text(
            '收藏与读过的书刊都在这里，阅读进度自动保存',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppText.caption12,
          ),
        ),
      ],
    );
  }

  Widget _buildBrowse(EbooksState state) {
    if (state.books.isEmpty) {
      if (state.loading) {
        return const _GridSkeleton();
      }
      if (state.errorMessage.isNotEmpty) {
        return AppErrorState(
          title: '书刊加载失败',
          description: state.errorMessage,
          onRetry: () => unawaited(_controller.refresh()),
        );
      }
      return AppEmptyState(
        icon: Icons.menu_book_outlined,
        title: state.keyword.isNotEmpty
            ? '没有找到与「${state.keyword}」相关的书刊'
            : '这个分类下暂时还没有书刊',
        description: '换个关键词或分类试试',
        actionLabel: state.hasFilters ? '清除筛选' : null,
        onAction: state.hasFilters ? _resetFilters : null,
      );
    }
    final showFeatured = !state.hasFilters && state.featured.isNotEmpty;
    final label = state.categoryLabelOf(state.category);
    final title = state.keyword.isNotEmpty
        ? '搜索结果'
        : (showFeatured || label.isEmpty || state.category == EbookCategory.allKey
              ? '全部书刊'
              : label);
    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (showFeatured) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s4,
              AppSpace.page,
              AppSpace.s12,
            ),
            sliver: SliverToBoxAdapter(
              child: AppSectionHeader(title: '编辑推荐', subtitle: '画室老师挑选的示例书刊'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              0,
              AppSpace.page,
              AppSpace.s24,
            ),
            sliver: SliverToBoxAdapter(child: _buildFeatured(state.featured)),
          ),
        ],
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.page,
            showFeatured ? 0 : AppSpace.s4,
            AppSpace.page,
            AppSpace.s12,
          ),
          sliver: SliverToBoxAdapter(
            child: AppSectionHeader(title: title, subtitle: '共 ${state.total} 本'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
          sliver: EbookGrid(
            itemCount: state.books.length,
            itemBuilder: (context, index) {
              final book = state.books[index];
              return EbookCard(
                book: book,
                onTap: () => _controller.openDetail(book.id),
              );
            },
          ),
        ),
        SliverToBoxAdapter(child: _ListFooter(state: state)),
      ],
    );
  }

  Widget _buildFeatured(List<EbookSummary> featured) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 720 ? 3 : 2;
        final items = featured.take(count).toList();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.s16),
              Expanded(
                child: i < items.length
                    ? EbookFeaturedCard(
                        book: items[i],
                        onTap: () => _controller.openDetail(items[i].id),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildShelf(EbooksState state) {
    final items = state.shelfItems;
    if (items.isEmpty) {
      if (state.shelfLoading) {
        return const _GridSkeleton(withAction: true);
      }
      return AppEmptyState(
        icon: Icons.collections_bookmark_outlined,
        title: switch (state.shelfFilter) {
          EbookShelfFilter.all => '书架还是空的',
          EbookShelfFilter.reading => '没有正在读的书刊',
          EbookShelfFilter.favorite => '还没有加入书架的书刊',
        },
        description: '在书刊详情里点「加入书架」，或开始阅读后，书刊会出现在这里',
        actionLabel: '去书库看看',
        onAction: () => _controller.setView(EbooksView.browse),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s4,
            AppSpace.page,
            AppSpace.s24,
          ),
          sliver: EbookGrid(
            withAction: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final book = items[index];
              return EbookCard(
                book: book,
                onTap: () => _controller.openDetail(book.id),
                onRead: () => unawaited(_read(book, ebookStartPage(book))),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton({this.withAction = false});

  final bool withAction;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s4,
            AppSpace.page,
            AppSpace.s24,
          ),
          sliver: EbookGrid(
            withAction: withAction,
            itemCount: 10,
            itemBuilder: (context, index) => const EbookCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state});

  final EbooksState state;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.s16),
        child: Center(child: AppLoadingIndicator(size: 28)),
      );
    }
    if (state.hasMore) {
      return const SizedBox(height: AppSpace.s24);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s16,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: Center(
        child: Text(
          '已显示全部 ${state.books.length} 本 · 示例书刊仅供演示',
          style: AppText.caption12,
        ),
      ),
    );
  }
}
