import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/consultation_controller.dart';
import '../state/consultation_detail_state.dart';
import '../state/consultation_state.dart';

const _titleColor = Color(0xFF1A1A1A);
const _metaColor = Color(0xFF6D6B75);
const _backIconColor = Color(0xFF1C274C);
const _thumbPlaceholder = Color(0xFFEFEFF4);

class ConsultationPage extends ConsumerStatefulWidget {
  const ConsultationPage({super.key});

  @override
  ConsumerState<ConsultationPage> createState() => _ConsultationPageState();
}

class _ConsultationPageState extends ConsumerState<ConsultationPage> {
  ConsultationCategory _category = ConsultationCategory.all;

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final args = _parseArgs(ModalRoute.of(context)?.settings.arguments);
    final provider = consultationControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<ConsultationState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) return;
      // 首屏失败由错误状态承接；已有内容时（加载更多失败）只轻提示。
      if (next.items.isNotEmpty) {
        AppToast.showError(context, msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.mounted) controller.clearError();
        });
      }
    });

    final counts = <ConsultationCategory, int>{
      for (final category in ConsultationCategory.values)
        category: state.items.where(category.matches).length,
    };
    final tabs = ConsultationCategory.values
        .where((c) => c == ConsultationCategory.all || counts[c]! > 0)
        .toList(growable: false);
    final category = tabs.contains(_category)
        ? _category
        : ConsultationCategory.all;

    final Widget body;
    if (state.loading && state.items.isEmpty) {
      body = const SizedBox.shrink();
    } else if (state.items.isEmpty && state.errorMessage.isNotEmpty) {
      body = AppErrorState(
        title: '资讯加载失败',
        description: state.errorMessage,
        onRetry: controller.refresh,
      );
    } else if (state.items.isEmpty) {
      body = const _ConsultationEmpty();
    } else {
      body = _ConsultationBody(
        items: state.items,
        tabs: tabs.length > 2 ? tabs : const [],
        counts: counts,
        category: category,
        onCategoryChanged: (value) => setState(() => _category = value),
        loadingMore: state.loadingMore,
        sourceName: args.sourceName,
        onLoadMore: controller.loadMore,
      );
    }

    return ShellPageSurface(
      child: ClipRRect(
        borderRadius: AppRadius.br16,
        child: PageInitLoadingShell(
          loading: state.loading && state.items.isEmpty,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConsultationHeader(
                title: args.schoolMode ? '校园资讯' : '资讯',
                onBack: _back,
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  ConsultationPageArgs _parseArgs(dynamic raw) {
    if (raw is ConsultationPageArgs) {
      return raw;
    }
    if (raw is Map) {
      return ConsultationPageArgs(
        schoolMode: _isTruthy(raw['schoolMode']) || _isTruthy(raw['school']),
        sourceName:
            raw['sourceName']?.toString() ?? raw['schoolName']?.toString(),
      );
    }
    return const ConsultationPageArgs();
  }
}

/// 仿 JS `!!value` 语义：null/false/0/空串视为假，其他视为真。
bool _isTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower != 'false' && lower != '0';
  }
  return true;
}

/// 资讯列表与详情共用的 56 高页头：左返回、标题居中、底部细线，右侧可放操作。
class ConsultationHeader extends StatelessWidget {
  const ConsultationHeader({
    required this.title,
    required this.onBack,
    this.trailing,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        children: [
          ConsultationBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: AppFont.w600,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ),
          ),
          trailing ?? const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class ConsultationBackButton extends StatelessWidget {
  const ConsultationBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: '返回',
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br8,
          border: Border.all(color: AppColors.lineSoft),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.chevron_left, color: _backIconColor, size: 20),
      ),
    );
  }
}

class _ConsultationBody extends StatefulWidget {
  const _ConsultationBody({
    required this.items,
    required this.tabs,
    required this.counts,
    required this.category,
    required this.onCategoryChanged,
    required this.loadingMore,
    required this.onLoadMore,
    this.sourceName,
  });

  final List<ConsultationItem> items;

  /// 资讯分类页签；分类少于两个时为空，不显示页签。
  final List<ConsultationCategory> tabs;
  final Map<ConsultationCategory, int> counts;
  final ConsultationCategory category;
  final ValueChanged<ConsultationCategory> onCategoryChanged;
  final bool loadingMore;
  final String? sourceName;
  final Future<void> Function() onLoadMore;

  @override
  State<_ConsultationBody> createState() => _ConsultationBodyState();
}

class _ConsultationBodyState extends State<_ConsultationBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 320) {
      unawaited(widget.onLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = widget.items
        .where(widget.category.matches)
        .toList(growable: false);
    const gap = 16.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth - 40 >= 700 ? 3 : 2;
          return CustomScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _ConsultationBanner(
                    item: widget.items.first,
                    sourceName: widget.sourceName,
                  ),
                ),
              ),
              if (widget.tabs.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: AppTabs<ConsultationCategory>(
                        tabs: [
                          for (final tab in widget.tabs)
                            AppTab(
                              value: tab,
                              label: tab.label,
                              count: widget.counts[tab],
                            ),
                        ],
                        value: widget.category,
                        onChanged: widget.onCategoryChanged,
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  widget.tabs.isEmpty ? 16 : 12,
                  20,
                  8,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    mainAxisExtent: 94,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ConsultationCard(
                      item: items[index],
                      latest: items[index].isLatest(now),
                      sourceName: widget.sourceName,
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
              if (widget.loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: AppLoadingIndicator(size: 24)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

void _openItem(
  BuildContext context,
  ConsultationItem item,
  String? sourceName,
) {
  Navigator.pushNamed(
    context,
    RoutePaths.consultationDetail,
    arguments: ConsultationDetailArgs(id: item.id, sourceName: sourceName),
  );
}

/// 200 高横幅：使用最新一条资讯的美术封面与标题。
class _ConsultationBanner extends StatelessWidget {
  const _ConsultationBanner({required this.item, this.sourceName});

  final ConsultationItem item;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: () => _openItem(context, item, sourceName),
      child: ClipRRect(
        borderRadius: AppRadius.br12,
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(src: item.coverUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xD90B081A), Colors.transparent],
                    stops: [0, 0.75],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s20),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title20.copyWith(color: AppColors.onBrand),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({
    required this.item,
    required this.latest,
    this.sourceName,
  });

  final ConsultationItem item;
  final bool latest;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: () => _openItem(context, item, sourceName),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br12,
        ),
        // 「最新」角标贴在卡片左上角，距上、左各 8。
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppImage(
                    src: item.coverUrl,
                    width: 70,
                    height: 70,
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    placeholder: const _ThumbnailPlaceholder(),
                    error: const _ThumbnailPlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _titleColor,
                            fontSize: 14,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            height: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                formatRelativeTime(item.createTime),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _metaColor,
                                  fontSize: 12,
                                  fontFamily: 'PingFang SC',
                                  height: 20 / 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ViewCountLabel(count: item.viewCount),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (latest)
              const Positioned(left: 8, top: 8, child: _LatestBadge()),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _thumbPlaceholder,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textPlaceholder,
          size: 28,
        ),
      ),
    );
  }
}

class _LatestBadge extends StatelessWidget {
  const _LatestBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.brand,
        borderRadius: AppRadius.br4,
      ),
      child: Text(
        '最新',
        style: TextStyle(
          color: AppColors.onBrand,
          fontSize: 10,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 16 / 10,
        ),
      ),
    );
  }
}

/// 浏览量：眼睛图标 + 数字，资讯列表与详情共用。
class ViewCountLabel extends StatelessWidget {
  const ViewCountLabel({required this.count, this.fontSize = 12, super.key});

  final int count;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(AppAssets.newsViews, width: 14, fit: BoxFit.contain),
        const SizedBox(width: AppSpace.s4),
        Text(
          '$count',
          style: TextStyle(
            color: _metaColor,
            fontSize: fontSize,
            fontFamily: 'PingFang SC',
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _ConsultationEmpty extends StatelessWidget {
  const _ConsultationEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.feed_outlined, color: AppColors.textPlaceholder, size: 48),
          SizedBox(height: 12),
          Text(
            '暂无资讯',
            style: TextStyle(
              color: AppColors.textPlaceholder,
              fontSize: 14,
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}
