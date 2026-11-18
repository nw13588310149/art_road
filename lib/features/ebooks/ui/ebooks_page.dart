import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../data/ebook_models.dart';
import '../navigation/ebook_navigation.dart';
import '../state/ebooks_controller.dart';
import '../state/ebooks_state.dart';
import 'ebook_detail_view.dart';
import 'widgets/ebook_library_view.dart';
import 'widgets/ebook_shelf_view.dart';
import 'widgets/ebook_widgets.dart';

/// 电子书刊：书库（接着读、编辑推荐、分类、搜索与排序）、我的书架，以及页内详情。
///
/// 用外壳给的白色底板，版式按 `docs/新页面设计语言.md`：页头是名称、书库 / 我的书架
/// 切换、搜索和排序；下面是筛选条，再下面是封面网格。整页一起滚动。
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

  /// 从别的页面带参数进来（例如 `bookId`）时页头才有返回，和素材中心一致。
  /// 左导航进入是替换路由，没有返回。
  bool _openedFromPage = false;

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
    if (_query == null) {
      final args = widget.args ?? ModalRoute.of(context)?.settings.arguments;
      _openedFromPage = args is Map && args.isNotEmpty;
      _query = EbooksQuery.fromArgs(args);
    }
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
    final browse =
        ref.read(ebooksControllerProvider(_currentQuery)).view ==
        EbooksView.browse;
    if (browse && _scroll.hasClients && _scroll.position.extentAfter < 480) {
      unawaited(_controller.loadMore());
    }
  }

  void _applyFilter(VoidCallback change) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    change();
  }

  /// 书库和书架共用一个滚动位置，切换时回到页顶。
  void _setView(EbooksView view) => _applyFilter(() => _controller.setView(view));

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

  void _clearSearch() {
    _search.clear();
    _onKeywordSubmitted('');
  }

  Future<void> _pickSort(BuildContext anchor, EbookSort current) async {
    final sort = await showAppMenu<EbookSort>(
      context: anchor,
      width: 120,
      selected: current,
      items: [
        for (final sort in EbookSort.values)
          AppMenuItem(value: sort, label: sort.label),
      ],
    );
    if (sort != null && mounted) {
      _applyFilter(() => _controller.setSort(sort));
    }
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

  Future<void> _read(EbookSummary book, [int? page]) async {
    final progress = await EbookNavigation.openReader(
      context,
      bookId: book.id,
      page: page ?? ebookStartPage(book),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: openId != null,
          child: TickerMode(enabled: openId == null, child: _buildList(state)),
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
    );
  }

  Widget _buildList(EbooksState state) {
    final browse = state.view == EbooksView.browse;
    // 只看这一页下面有没有页面：排序菜单这类盖在上面的浮层不算。
    final canPop =
        _openedFromPage && (ModalRoute.of(context)?.canPop ?? false);
    void open(EbookSummary book) => _controller.openDetail(book.id);
    void read(EbookSummary book) => unawaited(_read(book));
    return AppRefreshIndicator(
      onRefresh: browse ? _controller.refresh : _controller.refreshShelf,
      child: AppPageBody.slivers(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: (context, wide) => [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTitleBar(state, wide, canPop),
                const SizedBox(height: AppSpace.s12),
                if (browse)
                  _buildCategoryBar(state)
                else
                  EbookShelfBar(
                    state: state,
                    onChanged: _controller.setShelfFilter,
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: browse
                ? EbookLibraryView(
                    state: state,
                    wide: wide,
                    onOpen: open,
                    onRead: read,
                    onRetry: () => unawaited(_controller.refresh()),
                    onClearSearch: _clearSearch,
                    onShowAll: () => _applyFilter(
                      () => _controller.setCategory(EbookCategory.allKey),
                    ),
                  )
                : EbookShelfView(
                    state: state,
                    wide: wide,
                    onOpen: open,
                    onRetry: () => unawaited(_controller.refreshShelf()),
                    onBrowse: () => _setView(EbooksView.browse),
                  ),
          ),
        ],
      ),
    );
  }

  /// 页头：名称、书库 / 我的书架；书库视图右边是搜索框和排序。
  Widget _buildTitleBar(EbooksState state, bool wide, bool canPop) {
    final browse = state.view == EbooksView.browse;
    return AppTitleBar(
      title: '电子书刊',
      onBack: canPop ? () => Navigator.of(context).maybePop() : null,
      tabs: AppViewTabs<EbooksView>(
        items: const [
          AppViewTab(value: EbooksView.browse, label: '书库'),
          AppViewTab(value: EbooksView.shelf, label: '我的书架'),
        ],
        value: state.view,
        onChanged: _setView,
      ),
      actions: [
        if (browse) ...[
          SizedBox(
            width: wide ? 260 : 220,
            child: AppSearchField(
              controller: _search,
              hint: '搜索书名、编者、知识点',
              onChanged: _onKeywordChanged,
              onSubmitted: _onKeywordSubmitted,
              onCleared: () => _onKeywordSubmitted(''),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Builder(
            builder: (anchor) => AppPlainButton(
              label: state.sort.label,
              icon: Icons.swap_vert_rounded,
              onTap: () => unawaited(_pickSort(anchor, state.sort)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryBar(EbooksState state) {
    if (state.categories.isEmpty) {
      return const SizedBox(height: AppFilterBar.height);
    }
    return AppFilterBar<String>(
      items: [
        for (final category in state.categories)
          AppFilterItem(value: category.key, label: category.label),
      ],
      value: state.category,
      onChanged: (key) => _applyFilter(() => _controller.setCategory(key)),
    );
  }
}
