import 'dart:async';

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/consultation_controller.dart';
import '../state/consultation_detail_state.dart';
import '../state/consultation_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class ConsultationPage extends ConsumerWidget {
  const ConsultationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = _parseArgs(ModalRoute.of(context)?.settings.arguments);
    final provider = consultationControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<ConsultationState>(provider, (
      previous,
      next,
    ) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) return;
      AppToast.show(context, msg);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) controller.clearError();
      });
    });

    final ui = DashboardScaleScope.of(context).ui;
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        // 与 ShellPageSurface 默认 panelRadius=16 保持一致，避免 header 顶角溢出。
        borderRadius: BorderRadius.circular(ui(16)),
        child: PageInitLoadingShell(
          loading: state.loading && state.items.isEmpty,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ConsultationHeader(onBack: () => Navigator.of(context).maybePop()),
              Expanded(
                child: state.loading && state.items.isEmpty
                    ? const SizedBox.shrink()
                    : state.items.isEmpty
                    ? const _ConsultationEmpty()
                    : _ConsultationBody(
                        state: state,
                        sourceName: args.sourceName,
                        onLoadMore: controller.loadMore,
                      ),
              ),
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

// ─────────────────────────────────────────────────────────────────────
// 顶部 56 header（左返回 + 中标题"资讯"）
// ─────────────────────────────────────────────────────────────────────

class _ConsultationHeader extends StatelessWidget {
  const _ConsultationHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(56),
      padding: EdgeInsets.symmetric(horizontal: ui(20)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      child: Row(
        children: [
          ConsultationBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                '资讯',
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(16),
                  fontWeight: AppFont.w600,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
          // 占位与左侧对称（保持标题居中）
          SizedBox(width: ui(32)),
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
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.chevron_left,
          color: const Color(0xFF1C274C),
          size: ui(20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 主体（banner 200 高度 + 3 列网格）
// ─────────────────────────────────────────────────────────────────────

class _ConsultationBody extends ConsumerStatefulWidget {
  const _ConsultationBody({
    required this.state,
    this.sourceName,
    required this.onLoadMore,
  });

  final ConsultationState state;
  final String? sourceName;
  final Future<void> Function() onLoadMore;

  @override
  ConsumerState<_ConsultationBody> createState() => _ConsultationBodyState();
}

class _ConsultationBodyState extends ConsumerState<_ConsultationBody> {
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
    final ui = DashboardScaleScope.of(context).ui;
    final items = widget.state.items;
    const columns = 3;
    final gap = ui(16);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(12)),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(ui(20), ui(4), ui(20), 0),
            sliver: const SliverToBoxAdapter(child: _ConsultationBanner()),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(ui(20), ui(16), ui(20), ui(8)),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
                mainAxisExtent: ui(94),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _ConsultationCard(
                    item: items[index],
                    showLatestBadge: index < 3,
                    sourceName: widget.sourceName,
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
          if (widget.state.loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: ui(12)),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: AppLoadingIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsultationBanner extends StatelessWidget {
  const _ConsultationBanner();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(200),
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(12)),
        child: Image.asset(
          'assets/images/home/consultation_banner.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6FA),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: ui(28)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '资讯中心',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ui(22),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w600,
                          ),
                        ),
                        SizedBox(height: ui(8)),
                        Text(
                          '艺考热点 · 招生简章一手掌握',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: ui(13),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.campaign_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: ui(56),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({
    required this.item,
    required this.showLatestBadge,
    this.sourceName,
  });

  final ConsultationItem item;
  final bool showLatestBadge;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: const Color(0xFFF5F6FA),
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ui(12)),
        onTap: () => Navigator.pushNamed(
          context,
          RoutePaths.consultationDetail,
          arguments: ConsultationDetailArgs(
            id: item.id,
            sourceName: sourceName,
          ),
        ),
        child: SizedBox(
          height: ui(116),
          // Stack：底层是原有的卡片内容；顶层把「最新」徽标贴到左上角（距上/左各 8）。
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(ui(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardThumbnail(url: item.coverUrl),
                    SizedBox(width: ui(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF1A1A1A),
                              fontSize: ui(14),
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w500,
                              height: 1.5,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                formatRelativeTime(item.createTime),
                                style: TextStyle(
                                  color: const Color(0xFF6D6B75),
                                  fontSize: ui(12),
                                  fontFamily: 'PingFang SC',
                                  height: 20 / 12,
                                ),
                              ),
                              SizedBox(width: ui(12)),
                              _ViewCount(count: item.viewCount),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showLatestBadge)
                Positioned(
                  left: ui(8),
                  top: ui(8),
                  child: const _LatestBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardThumbnail extends StatelessWidget {
  const _CardThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cacheWidth =
        (ui(70) * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(6)),
      child: SizedBox(
        width: ui(70),
        height: ui(70),
        child: url.isEmpty
            ? const _ThumbnailPlaceholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stack) =>
                    const _ThumbnailPlaceholder(),
              ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      color: const Color(0xFFEFEFF4),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: const Color(0xFFB6B5BB),
        size: ui(28),
      ),
    );
  }
}

class _ViewCount extends StatelessWidget {
  const _ViewCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/home/eye.png',
          width: ui(14),
          fit: BoxFit.contain,
        ),
        SizedBox(width: ui(4)),
        Text(
          count.toString(),
          style: TextStyle(
            color: const Color(0xFF6D6B75),
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _LatestBadge extends StatelessWidget {
  const _LatestBadge();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: const Color(0xFF8741FF),
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        '最新',
        style: TextStyle(
          color: Colors.white,
          fontSize: ui(10),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 16 / 10,
        ),
      ),
    );
  }
}

class _ConsultationEmpty extends StatelessWidget {
  const _ConsultationEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.feed_outlined,
            color: const Color(0xFFB6B5BB),
            size: ui(48),
          ),
          SizedBox(height: ui(12)),
          Text(
            '暂无资讯',
            style: TextStyle(
              color: const Color(0xFFB6B5BB),
              fontSize: ui(14),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}
