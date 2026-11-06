import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/art_widgets.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/teacher_artworks_controller.dart';
import 'artwork_review_workspace.dart';
import 'artwork_tag_manager_dialog.dart';
import 'widgets/artwork_widgets.dart';

/// 教职「作品点评」：待点评队列、搜索、点评标签管理，点开进入点评工作台。
class TeacherArtworksView extends ConsumerStatefulWidget {
  const TeacherArtworksView({this.initialArtworkId, super.key});

  final String? initialArtworkId;

  @override
  ConsumerState<TeacherArtworksView> createState() =>
      _TeacherArtworksViewState();
}

class _TeacherArtworksViewState extends ConsumerState<TeacherArtworksView> {
  static const _filters = <ArtworkStatusFilter>[
    ArtworkStatusFilter.pending,
    ArtworkStatusFilter.reviewed,
    ArtworkStatusFilter.all,
  ];

  final _scrollController = ScrollController();
  final _search = TextEditingController();
  Timer? _searchDebounce;
  String? _detailId;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _detailId = widget.initialArtworkId;
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  TeacherArtworksController get _controller =>
      ref.read(teacherArtworksControllerProvider.notifier);

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 360) {
      unawaited(_controller.loadMore());
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        unawaited(_controller.setKeyword(value));
      }
    });
  }

  Future<void> _startReview() async {
    if (_starting) {
      return;
    }
    setState(() => _starting = true);
    final result = await _controller.firstPendingId();
    if (!mounted) {
      return;
    }
    setState(() => _starting = false);
    if (result.error.isNotEmpty) {
      AppToast.showError(context, result.error);
      return;
    }
    final id = result.id;
    if (id == null) {
      AppToast.showSuccess(context, '太棒了，暂时没有待点评的作品');
      return;
    }
    setState(() => _detailId = id);
  }

  void _openDetail(String id) => setState(() => _detailId = id);

  void _closeDetail() {
    setState(() => _detailId = null);
    unawaited(_controller.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherArtworksControllerProvider);
    final controller = _controller;
    ref.listen<TeacherArtworksState>(teacherArtworksControllerProvider, (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) {
        return;
      }
      AppToast.showError(context, message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.clearError();
        }
      });
    });

    final detailId = _detailId;
    // 点评工作台自己处理返回（可能有未保存的点评）。
    return PopScope(
      canPop: detailId == null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: detailId != null,
            child: TickerMode(
              enabled: detailId == null,
              child: _buildList(state),
            ),
          ),
          if (detailId != null)
            ArtworkReviewWorkspace(
              key: ValueKey(detailId),
              artworkId: detailId,
              onBack: _closeDetail,
              onOpenArtwork: _openDetail,
            ),
        ],
      ),
    );
  }

  Widget _buildList(TeacherArtworksState state) {
    return PageInitLoadingShell(
      loading: state.loading && !state.loaded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArtPageHeader(
            title: '作品点评',
            subtitle: '多位老师独立点评，保存自己的点评后可查看其他老师的意见',
            actions: [
              ArtButton(
                label: '点评标签',
                primary: false,
                icon: Icons.sell_outlined,
                onTap: () => showArtworkTagManager(context),
              ),
              const SizedBox(width: 8),
              ArtButton(
                label: '开始点评',
                icon: Icons.play_arrow_rounded,
                loading: _starting,
                onTap: _startReview,
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 2 : 1;
                return AppRefreshIndicator(
                  onRefresh: _controller.refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: _StatsRow(
                            stats: state.stats,
                            onSelect: (f) =>
                                unawaited(_controller.setFilter(f)),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              ArtSegmentTabs<ArtworkStatusFilter>(
                                items: _filters,
                                value: state.filter,
                                labelOf: (f) => f.label,
                                onChanged: (f) =>
                                    unawaited(_controller.setFilter(f)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 280,
                                    ),
                                    child: _SearchField(
                                      controller: _search,
                                      onChanged: _onSearchChanged,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ..._listSlivers(state, columns),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _listSlivers(TeacherArtworksState state, int columns) {
    if (state.items.isEmpty) {
      if (state.loadingList) {
        return const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: AppLoadingIndicator(size: 36)),
            ),
          ),
        ];
      }
      if (!state.loaded) {
        return const [];
      }
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: ArtEmptyState(
              icon: Icons.rate_review_outlined,
              message: state.keyword.isNotEmpty
                  ? '没有找到「${state.keyword}」相关的作品'
                  : state.stats.total == 0
                  ? '暂时没有分配给你的作品'
                  : switch (state.filter) {
                      ArtworkStatusFilter.pending => '待点评的作品都处理完了，辛苦啦',
                      ArtworkStatusFilter.reviewed => '还没有点评过的作品',
                      ArtworkStatusFilter.all => '暂时没有分配给你的作品',
                    },
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: _TeacherArtworkCard.height,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _TeacherArtworkCard(
              item: state.items[index],
              onTap: () => _openDetail(state.items[index].id),
            ),
            childCount: state.items.length,
          ),
        ),
      ),
      if (state.loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: AppLoadingIndicator(size: 30)),
          ),
        ),
    ];
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.onSelect});

  final ArtworkStats stats;
  final ValueChanged<ArtworkStatusFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ArtworkStatCard(
            label: '待点评',
            value: stats.pending,
            icon: Icons.pending_actions_rounded,
            color: ArtColors.warn,
            onTap: () => onSelect(ArtworkStatusFilter.pending),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ArtworkStatCard(
            label: '已点评',
            value: stats.reviewed,
            icon: Icons.task_alt_rounded,
            color: ArtColors.success,
            onTap: () => onSelect(ArtworkStatusFilter.reviewed),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ArtworkStatCard(
            label: '全部',
            value: stats.total,
            icon: Icons.collections_outlined,
            onTap: () => onSelect(ArtworkStatusFilter.all),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: AppTextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: ArtText.body(size: 13),
        decoration: artworkInputDecoration(
          hint: '搜索学生、校区或作品',
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: ArtColors.ink3,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
        ),
      ),
    );
  }
}

class _TeacherArtworkCard extends StatelessWidget {
  const _TeacherArtworkCard({required this.item, required this.onTap});

  static const height = 116.0;

  final ArtworkSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ArtCard(
      color: ArtColors.subtle,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArtNetworkImage(
                  item.coverUrl,
                  borderRadius: BorderRadius.circular(12),
                ),
                if (item.imageCount > 1)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${item.imageCount} 张',
                        style: ArtText.caption(size: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ArtAvatar(
                      name: item.studentName,
                      url: item.avatarUrl,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        item.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ArtText.body(size: 13, weight: AppFont.w500),
                      ),
                    ),
                    if (item.organizationName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.organizationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ArtText.caption(size: 11),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArtText.body(size: 15, weight: AppFont.w500),
                ),
                Row(
                  children: [
                    ArtworkSubjectChip(subject: item.subject),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '提交于 ${ArtworkRules.shortTime(item.createTime)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ArtText.caption(size: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ArtworkStatusBadge(
                done: item.myReviewed,
                label: item.myReviewed ? '我已点评' : '待我点评',
              ),
              if (item.myReviewed && item.finalScore != null)
                ArtworkScore(
                  score: item.finalScore,
                  maxScore: item.maxScore,
                  size: 18,
                )
              else if (item.myReviewed && !item.reviewed)
                Text('等其他老师', style: ArtText.caption(size: 11))
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: ArtColors.ink4,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
