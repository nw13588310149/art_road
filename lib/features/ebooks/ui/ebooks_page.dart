import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../gallery/ui/widgets/library_controls.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/ebook_models.dart';
import '../navigation/ebook_navigation.dart';
import '../state/ebooks_controller.dart';
import '../state/ebooks_state.dart';
import 'ebook_detail_view.dart';
import 'widgets/ebook_widgets.dart';

/// 美术书刊：编辑推荐、分类浏览、搜索与排序、我的书架，以及页内详情。
///
/// 版式取自原版的收藏页与资源网格：白色内容板内，左上是分段工具栏（书库 /
/// 我的书架），同一行右侧放搜索和排序；下面依次是筛选条和书刊网格。
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
  /// 内容板四周的留白与工具栏高度，对应原版收藏页「左上 20、内容从 82 开始」。
  static const _inset = 20.0;
  static const _toolbarHeight = 42.0;

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
    final browse = state.view == EbooksView.browse;
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_inset, _inset, _inset, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildToolbar(state, canPop),
                      const SizedBox(height: _inset),
                      browse ? _buildCategoryBar(state) : _buildShelfBar(state),
                      const SizedBox(height: 16),
                      Expanded(
                        child: browse
                            ? _buildBrowse(state)
                            : _buildShelf(state),
                      ),
                    ],
                  ),
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

  /// 工具栏：左侧分段（书库 / 我的书架），书库视图右侧是 324×40 的搜索框和排序按钮。
  Widget _buildToolbar(EbooksState state, bool canPop) {
    final browse = state.view == EbooksView.browse;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '美术书刊',
      hint: '精选美术教辅与期刊（示例内容）',
      child: SizedBox(
        height: _toolbarHeight,
        child: Row(
          children: [
            if (canPop) ...[
              LibraryIconButton.back(
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
            ],
            LibrarySegmented<EbooksView>(
              items: const [
                LibraryOption(value: EbooksView.browse, label: '书库'),
                LibraryOption(value: EbooksView.shelf, label: '我的书架'),
              ],
              value: state.view,
              onChanged: _controller.setView,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: browse
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 324),
                        child: LibrarySearchField(
                          controller: _search,
                          hint: '搜索书名、编者、知识点',
                          height: 40,
                          onChanged: _onKeywordChanged,
                          onSubmitted: _onKeywordSubmitted,
                          onCleared: () => _onKeywordSubmitted(''),
                        ),
                      )
                    : Text(
                        '阅读进度自动保存',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: libraryText(
                          size: 12,
                          weight: AppFont.w500,
                          color: AppColors.textPlaceholder,
                        ),
                      ),
              ),
            ),
            if (browse) ...[
              const SizedBox(width: 12),
              LibrarySortButton<EbookSort>(
                options: [
                  for (final sort in EbookSort.values)
                    LibraryOption(value: sort, label: sort.label),
                ],
                value: state.sort,
                onChanged: (sort) =>
                    _applyFilter(() => _controller.setSort(sort)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBar(EbooksState state) {
    if (state.categories.isEmpty) {
      return const SizedBox(height: LibraryChip.height);
    }
    return LibraryChipBar<String>(
      items: [
        for (final category in state.categories)
          LibraryOption(value: category.key, label: category.label),
      ],
      value: state.category,
      onChanged: (key) => _applyFilter(() => _controller.setCategory(key)),
    );
  }

  Widget _buildShelfBar(EbooksState state) {
    final shelf = state.shelf;
    int countOf(EbookShelfFilter filter) => switch (filter) {
      EbookShelfFilter.all => shelf.records.length,
      EbookShelfFilter.reading => shelf.reading.length,
      EbookShelfFilter.favorite => shelf.favorites.length,
    };
    return LibraryChipBar<EbookShelfFilter>(
      items: [
        for (final filter in EbookShelfFilter.values)
          LibraryOption(
            value: filter,
            label: '${filter.label} ${countOf(filter)}',
          ),
      ],
      value: state.shelfFilter,
      onChanged: _controller.setShelfFilter,
    );
  }

  Widget _buildBrowse(EbooksState state) {
    if (state.books.isEmpty) {
      if (state.loading) {
        return const Center(child: AppLoadingIndicator());
      }
      if (state.errorMessage.isNotEmpty) {
        return AppErrorState(
          title: '书刊加载失败',
          description: state.errorMessage,
          onRetry: () => unawaited(_controller.refresh()),
        );
      }
      return LibraryEmptyState(
        message: state.keyword.isNotEmpty
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
        : (showFeatured ||
                  label.isEmpty ||
                  state.category == EbookCategory.allKey
              ? '全部书刊'
              : label);
    const groupPadding = EdgeInsets.only(left: 2, bottom: 10);
    return AppRefreshIndicator(
      onRefresh: _controller.refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (showFeatured) ...[
            const SliverPadding(
              padding: groupPadding,
              sliver: SliverToBoxAdapter(child: LibraryGroupTitle('编辑推荐')),
            ),
            SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                gridDelegate: EbookLessonCard.gridDelegate(
                  constraints.crossAxisExtent,
                  itemCount: state.featured.length,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final book = state.featured[index];
                  return EbookLessonCard(
                    book: book,
                    subtitle: book.featuredIntro.isNotEmpty
                        ? book.featuredIntro
                        : book.intro,
                    actionLabel: ebookReadLabel(book, withPage: false),
                    onAction: () => unawaited(_read(book, ebookStartPage(book))),
                    onTap: () => _controller.openDetail(book.id),
                  );
                }, childCount: state.featured.length),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
          SliverPadding(
            padding: groupPadding,
            sliver: SliverToBoxAdapter(
              child: LibraryGroupTitle(title, count: state.total, unit: '本'),
            ),
          ),
          EbookGrid(
            itemCount: state.books.length,
            itemBuilder: (context, index) {
              final book = state.books[index];
              return EbookCard(
                book: book,
                onTap: () => _controller.openDetail(book.id),
              );
            },
          ),
          SliverToBoxAdapter(child: _ListFooter(state: state)),
        ],
      ),
    );
  }

  Widget _buildShelf(EbooksState state) {
    final items = state.shelfItems;
    if (items.isEmpty) {
      if (state.shelfLoading) {
        return const Center(child: AppLoadingIndicator());
      }
      if (state.shelfError.isNotEmpty) {
        return AppErrorState(
          title: '书架加载失败',
          description: state.shelfError,
          onRetry: () => unawaited(_controller.refreshShelf()),
        );
      }
      return LibraryEmptyState(
        imageAsset: AppAssets.emptyCollectionPlaceholder,
        message: switch (state.shelfFilter) {
          EbookShelfFilter.all => '书架还是空的',
          EbookShelfFilter.reading => '没有正在读的书刊',
          EbookShelfFilter.favorite => '还没有加入书架的书刊',
        },
        description: '在书刊详情里点「加入书架」，或开始阅读后，书刊会出现在这里',
        actionLabel: '去书库看看',
        onAction: () => _controller.setView(EbooksView.browse),
      );
    }
    return AppRefreshIndicator(
      onRefresh: _controller.refreshShelf,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverGrid(
              gridDelegate: EbookLessonCard.gridDelegate(
                constraints.crossAxisExtent,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final book = items[index];
                return EbookLessonCard(
                  book: book,
                  subtitle: '${book.categoryLabel} · ${book.editor} 编',
                  progressLabel: book.started
                      ? ebookProgressLabel(book)
                      : '尚未开始阅读',
                  actionLabel: ebookReadLabel(book, withPage: false),
                  onAction: () => unawaited(_read(book, ebookStartPage(book))),
                  onTap: () => _controller.openDetail(book.id),
                );
              }, childCount: items.length),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: _inset)),
        ],
      ),
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
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: AppLoadingIndicator()),
      );
    }
    if (state.hasMore) {
      return const SizedBox(height: 24);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '已显示全部 ${state.books.length} 本 · 示例书刊仅供演示',
          style: libraryText(size: 12, color: AppColors.textPlaceholder),
        ),
      ),
    );
  }
}
