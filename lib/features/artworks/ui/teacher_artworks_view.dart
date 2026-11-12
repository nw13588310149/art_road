import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/teacher_artworks_controller.dart';
import 'artwork_lead_review_workspace.dart';
import 'artwork_review_workspace.dart';
import 'artwork_tag_manager_dialog.dart';
import 'widgets/artwork_widgets.dart';

/// 教职「作品点评」：待点评队列、搜索、点评标签管理，点开进入点评工作台。
/// 科目组长多一个「组内复核」范围：本组老师点评完成的作品，点开进入复核工作台。
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

  /// true 为「组内复核」（只有科目组长能切到）。
  bool _leadScope = false;

  AutoDisposeStateNotifierProvider<
    TeacherArtworksController,
    TeacherArtworksState
  >
  get _provider => _leadScope
      ? leadArtworksControllerProvider
      : teacherArtworksControllerProvider;

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

  TeacherArtworksController get _controller => ref.read(_provider.notifier);

  void _setScope(bool lead) {
    if (lead == _leadScope) {
      return;
    }
    _searchDebounce?.cancel();
    _search.clear();
    setState(() {
      _leadScope = lead;
      _detailId = null;
    });
  }

  String _filterLabel(ArtworkStatusFilter filter) => _leadScope
      ? switch (filter) {
          ArtworkStatusFilter.pending => '待复核',
          ArtworkStatusFilter.reviewed => '已复核',
          ArtworkStatusFilter.all => '全部',
        }
      : filter.label;

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

  void _clearSearch() {
    _searchDebounce?.cancel();
    _search.clear();
    unawaited(_controller.setKeyword(''));
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
      AppToast.showInfo(context, _leadScope ? '暂无待复核的作品' : '暂无待点评的作品');
      return;
    }
    setState(() => _detailId = id);
  }

  void _openDetail(String id) => setState(() => _detailId = id);

  void _closeDetail() {
    setState(() => _detailId = null);
    unawaited(_controller.refresh());
    // 老师保存点评、组长复核后，待复核数量都可能变化。
    ref.invalidate(artworkLeadInfoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final controller = _controller;
    final leadInfo =
        ref.watch(artworkLeadInfoProvider).valueOrNull ??
        const ArtworkLeadInfo();
    ref.listen<TeacherArtworksState>(_provider, (previous, next) {
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
              child: _buildList(state, leadInfo),
            ),
          ),
          if (detailId != null && _leadScope)
            ArtworkLeadReviewWorkspace(
              key: ValueKey('lead-$detailId'),
              artworkId: detailId,
              onBack: _closeDetail,
              onOpenArtwork: _openDetail,
            )
          else if (detailId != null)
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

  Widget _buildList(TeacherArtworksState state, ArtworkLeadInfo leadInfo) {
    final pending = state.stats.pending;
    final lead = _leadScope;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: lead ? '组内复核' : '作品点评',
          subtitle: lead
              ? '${leadInfo.groupName}老师点评完成的作品，逐份复核；可以补充点评、改定分数或退回重评'
              : '多位老师独立点评，保存自己的点评后可查看其他老师的意见',
          actions: [
            if (leadInfo.isLead)
              AppSegmented<bool>(
                size: AppControlSize.sm,
                neutral: true,
                segments: [
                  const AppSegment(value: false, label: '我的点评'),
                  AppSegment(
                    value: true,
                    label: '组内复核',
                    badge: leadInfo.pending > 0 ? '${leadInfo.pending}' : null,
                  ),
                ],
                value: lead,
                onChanged: _setScope,
              ),
          ],
          bottom: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.s12,
            runSpacing: AppSpace.s8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSegmented<ArtworkStatusFilter>(
                    segments: [
                      for (final filter in _filters)
                        AppSegment(
                          value: filter,
                          label: _filterLabel(filter),
                          badge:
                              filter == ArtworkStatusFilter.pending &&
                                  pending > 0
                              ? '$pending'
                              : null,
                        ),
                    ],
                    value: state.filter,
                    onChanged: (f) => unawaited(_controller.setFilter(f)),
                  ),
                  if (state.loaded &&
                      !state.loadingList &&
                      !state.listFailed) ...[
                    const SizedBox(width: AppSpace.s12),
                    Text('共 ${state.total} 件', style: AppText.caption12),
                  ],
                ],
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  SizedBox(
                    width: 230,
                    child: AppSearchField(
                      controller: _search,
                      hint: lead ? '搜索学生、老师或作品' : '搜索学生、校区或作品',
                      onChanged: _onSearchChanged,
                      onCleared: _clearSearch,
                      onSubmitted: (value) {
                        _searchDebounce?.cancel();
                        unawaited(_controller.setKeyword(value));
                      },
                    ),
                  ),
                  if (!lead)
                    AppButton(
                      label: '点评标签',
                      icon: Icons.sell_outlined,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.sm,
                      onTap: () => showArtworkTagManager(context),
                    ),
                  AppButton(
                    label: lead ? '开始复核' : '开始点评',
                    icon: lead
                        ? Icons.fact_check_outlined
                        : Icons.rate_review_outlined,
                    size: AppButtonSize.sm,
                    loading: _starting,
                    onTap: _startReview,
                  ),
                ],
              ),
            ],
          ),
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
                    ..._listSlivers(state, columns),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpace.s32),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _listSlivers(TeacherArtworksState state, int columns) {
    SliverGridDelegate grid() => SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: AppSpace.s12,
      crossAxisSpacing: AppSpace.s12,
      mainAxisExtent: _TeacherArtworkCard.height,
    );
    const padding = EdgeInsets.fromLTRB(
      AppSpace.page,
      AppSpace.s4,
      AppSpace.page,
      0,
    );
    if (state.items.isEmpty) {
      if (!state.loaded || state.loadingList) {
        return [
          SliverPadding(
            padding: padding,
            sliver: SliverGrid(
              gridDelegate: grid(),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const AppSkeleton(
                  height: double.infinity,
                  radius: AppRadius.card,
                ),
                childCount: columns * 2,
              ),
            ),
          ),
        ];
      }
      if (state.listFailed) {
        return [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 280,
              child: AppErrorState(
                title: '作品加载失败',
                description: '请检查网络后重试',
                onRetry: _controller.refresh,
              ),
            ),
          ),
        ];
      }
      final searching = state.keyword.isNotEmpty;
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: AppEmptyState(
              icon: Icons.rate_review_outlined,
              title: searching
                  ? '没有找到「${state.keyword}」相关的作品'
                  : _leadScope
                  ? switch (state.filter) {
                      ArtworkStatusFilter.pending => '暂无待复核作品',
                      ArtworkStatusFilter.reviewed => '还没有复核过的作品',
                      ArtworkStatusFilter.all => '本组暂时没有需要复核的作品',
                    }
                  : switch (state.filter) {
                      ArtworkStatusFilter.pending => '暂无待点评作品',
                      ArtworkStatusFilter.reviewed => '还没有点评过的作品',
                      ArtworkStatusFilter.all => '暂时没有分配给你的作品',
                    },
              description: searching
                  ? '换个学生姓名、校区或作品名称试试'
                  : (_leadScope ? '本组老师点评完成后会出现在这里' : '学生提交作品后会出现在这里'),
              actionLabel: searching ? '清除搜索' : null,
              onAction: searching ? _clearSearch : null,
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: grid(),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _TeacherArtworkCard(
              item: state.items[index],
              lead: _leadScope,
              onTap: () => _openDetail(state.items[index].id),
            ),
            childCount: state.items.length,
          ),
        ),
      ),
      if (state.loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.s16),
            child: Center(child: AppLoadingIndicator(size: 30)),
          ),
        ),
    ];
  }
}

class _TeacherArtworkCard extends StatelessWidget {
  const _TeacherArtworkCard({
    required this.item,
    required this.onTap,
    this.lead = false,
  });

  static const height = 118.0;

  final ArtworkSummary item;
  final VoidCallback onTap;

  /// 组内复核列表：状态显示复核进度，副标题显示点评老师。
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final score = item.finalScore;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s12),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(src: item.coverUrl, borderRadius: AppRadius.br8),
                if (item.imageCount > 1)
                  Positioned(
                    right: AppSpace.s4,
                    bottom: AppSpace.s4,
                    child: ArtworkImageCountTag(count: item.imageCount),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      name: item.studentName,
                      url: item.avatarUrl,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Flexible(
                      child: Text(
                        item.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body14Strong,
                      ),
                    ),
                    if (item.organizationName.isNotEmpty) ...[
                      const SizedBox(width: AppSpace.s8),
                      Flexible(
                        child: Text(
                          item.organizationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title16,
                ),
                Row(
                  children: [
                    ArtworkSubjectTag(subject: item.subject),
                    if (item.exemplar) ...[
                      const SizedBox(width: AppSpace.s4),
                      const AppTag(label: '范例', tone: AppTone.success),
                    ],
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        lead && item.teacherNames.isNotEmpty
                            ? '${item.teacherNames}老师点评'
                            : '提交于 ${ArtworkRules.shortTime(item.createTime)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (lead)
                ArtworkLeadStatusTag(status: item.leadStatus)
              else if (item.returnReason.isNotEmpty)
                const AppTag(label: '组长退回', tone: AppTone.danger)
              else
                ArtworkStatusTag(done: item.myReviewed),
              if ((lead || item.myReviewed) && score != null)
                ArtworkScore(score: score, maxScore: item.maxScore, size: 16)
              else if (!lead && item.myReviewed && !item.reviewed)
                Text('等其他老师点评', style: AppText.caption12)
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textPlaceholder,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
