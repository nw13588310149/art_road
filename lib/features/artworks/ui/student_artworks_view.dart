import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/art_widgets.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/student_artworks_controller.dart';
import 'artwork_upload_dialog.dart';
import 'student_artwork_detail_view.dart';
import 'widgets/artwork_widgets.dart';

/// 学生「作品档案」：统计、我的高频问题、按月分组的作品墙，点开进入作品详情。
class StudentArtworksView extends ConsumerStatefulWidget {
  const StudentArtworksView({this.initialArtworkId, super.key});

  final String? initialArtworkId;

  @override
  ConsumerState<StudentArtworksView> createState() =>
      _StudentArtworksViewState();
}

class _StudentArtworksViewState extends ConsumerState<StudentArtworksView> {
  final _scrollController = ScrollController();
  String? _detailId;

  @override
  void initState() {
    super.initState();
    _detailId = widget.initialArtworkId;
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 360) {
      unawaited(
        ref.read(studentArtworksControllerProvider.notifier).loadMore(),
      );
    }
  }

  Future<void> _upload() async {
    final created = await showArtworkUploadDialog(context);
    if (created == true && mounted) {
      AppToast.showSuccess(context, '上传成功，等待老师点评');
    }
  }

  void _openDetail(String id) => setState(() => _detailId = id);

  void _closeDetail() => setState(() => _detailId = null);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentArtworksControllerProvider);
    final controller = ref.read(studentArtworksControllerProvider.notifier);
    ref.listen<StudentArtworksState>(studentArtworksControllerProvider, (
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
    return PopScope(
      canPop: detailId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _detailId != null) {
          _closeDetail();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: detailId != null,
            child: TickerMode(
              enabled: detailId == null,
              child: _buildList(state, controller),
            ),
          ),
          if (detailId != null)
            StudentArtworkDetailView(
              key: ValueKey(detailId),
              artworkId: detailId,
              onBack: _closeDetail,
            ),
        ],
      ),
    );
  }

  Widget _buildList(
    StudentArtworksState state,
    StudentArtworksController controller,
  ) {
    return PageInitLoadingShell(
      loading: state.loading && !state.loaded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArtPageHeader(
            title: '作品档案',
            subtitle: '记录每一张画，收好老师的每一次点评',
            actions: [
              ArtButton(
                label: '上传作品',
                icon: Icons.add_photo_alternate_outlined,
                onTap: _upload,
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AppRefreshIndicator(
                  onRefresh: controller.refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: _StatsRow(stats: state.stats),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _InsightsCard(insights: state.insights),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              ArtSegmentTabs<ArtworkStatusFilter>(
                                items: ArtworkStatusFilter.values,
                                value: state.filter,
                                labelOf: (f) => f.label,
                                onChanged: (f) =>
                                    unawaited(controller.setFilter(f)),
                              ),
                              const Spacer(),
                              Text(
                                '共 ${state.total} 件',
                                style: ArtText.caption(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ..._gridSlivers(state, constraints.maxWidth - 40),
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

  List<Widget> _gridSlivers(StudentArtworksState state, double width) {
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
      final canUpload = state.filter != ArtworkStatusFilter.reviewed;
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: ArtEmptyState(
              icon: Icons.photo_library_outlined,
              message: switch (state.filter) {
                ArtworkStatusFilter.all => '还没有作品，上传第一张画请老师点评吧',
                ArtworkStatusFilter.pending => '没有待点评的作品',
                ArtworkStatusFilter.reviewed => '还没有完成点评的作品',
              },
              actionLabel: canUpload ? '上传作品' : null,
              onAction: canUpload ? _upload : null,
            ),
          ),
        ),
      ];
    }

    const spacing = 14.0;
    final columns = math.max(2, ((width + spacing) / (200 + spacing)).floor());
    final cardWidth = (width - spacing * (columns - 1)) / columns;
    final extent = cardWidth * 3 / 4 + _ArtworkCard.infoHeight;
    final groups = ArtworkRules.groupByMonth(
      state.items,
      (item) => item.drawingDate,
    );
    return [
      for (final (month, works) in groups) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Text(
              ArtworkRules.monthLabel(month),
              style: ArtText.title(size: 15),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: extent,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ArtworkCard(
                item: works[index],
                onTap: () => _openDetail(works[index].id),
              ),
              childCount: works.length,
            ),
          ),
        ),
      ],
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
  const _StatsRow({required this.stats});

  final ArtworkStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ArtworkStatCard(
            label: '累计作品',
            value: stats.total,
            icon: Icons.collections_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ArtworkStatCard(
            label: '已点评',
            value: stats.reviewed,
            icon: Icons.task_alt_rounded,
            color: ArtColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ArtworkStatCard(
            label: '待点评',
            value: stats.pending,
            icon: Icons.hourglass_top_rounded,
            color: ArtColors.warn,
          ),
        ),
      ],
    );
  }
}

/// 「我的高频问题」：老师点评标签的高频统计 + 针对性练习入口。
class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final ArtworkInsights insights;

  @override
  Widget build(BuildContext context) {
    final hasTags = insights.topTags.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArtColors.brandWash,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArtColors.brandTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                size: 18,
                color: ArtColors.brand,
              ),
              const SizedBox(width: 6),
              Text('我的高频问题', style: ArtText.title(size: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasTags ? '基于 ${insights.reviewedCount} 份已点评作品' : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArtText.caption(),
                ),
              ),
            ],
          ),
          if (!hasTags) ...[
            const SizedBox(height: 10),
            Text(
              '老师点评后，这里会汇总你最常出现的问题，并推荐对应的范画、教程与工具。',
              style: ArtText.body(size: 13, color: ArtColors.ink2),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (insights.averageScore != null)
                  _MetaPill(
                    label: '平均分',
                    value: ArtworkRules.formatScore(insights.averageScore),
                  ),
                if (insights.bestSubject.isNotEmpty)
                  _MetaPill(label: '最佳科目', value: insights.bestSubject),
                if (insights.weakestSubject.isNotEmpty)
                  _MetaPill(label: '待加强', value: insights.weakestSubject),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in insights.topTags)
                  ArtworkTagChip(
                    name: tag.name,
                    color: tag.color,
                    count: tag.count,
                    tooltip: tag.explanation,
                  ),
              ],
            ),
            for (final suggestion in insights.suggestions) ...[
              const SizedBox(height: 8),
              _SuggestionRow(suggestion: suggestion),
            ],
          ],
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label ', style: ArtText.caption()),
            TextSpan(
              text: value,
              style: ArtText.body(
                size: 12,
                color: ArtColors.brandDeep,
                weight: AppFont.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion});

  final ArtworkSuggestion suggestion;

  void _open(BuildContext context, String route, Map<String, dynamic> args) {
    Navigator.of(context).pushNamed(route, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: ArtColors.fromHex(s.color),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(s.tag, style: ArtText.body(size: 13, weight: AppFont.w500)),
      ],
    );
    final text = Text(
      s.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: ArtText.body(size: 13, color: ArtColors.ink2),
    );
    final actions = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _LinkPill(
          icon: Icons.photo_library_outlined,
          label: '看范画',
          onTap: () => _open(context, '/gallery', <String, dynamic>{
            'subject': s.gallerySubject,
            'keyword': s.galleryKeyword,
          }),
        ),
        _LinkPill(
          icon: Icons.play_circle_outline_rounded,
          label: '看教程',
          onTap: () => _open(context, '/video-tutorial', <String, dynamic>{
            'keyword': s.galleryKeyword,
          }),
        ),
        if (s.tool.isNotEmpty)
          _LinkPill(
            icon: Icons.handyman_outlined,
            label: s.tool,
            onTap: () =>
                _open(context, '/toolbox', <String, dynamic>{'tool': s.tool}),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    label,
                    const SizedBox(width: 8),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: 8),
                actions,
              ],
            );
          }
          return Row(
            children: [
              label,
              const SizedBox(width: 10),
              Expanded(child: text),
              const SizedBox(width: 10),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _LinkPill extends StatelessWidget {
  const _LinkPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: ArtColors.brandWash,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: ArtColors.brandDeep),
            const SizedBox(width: 4),
            Text(
              label,
              style: ArtText.body(
                size: 12,
                color: ArtColors.brandDeep,
                weight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({required this.item, required this.onTap});

  /// 封面以下信息区的固定高度。
  static const infoHeight = 76.0;

  final ArtworkSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ArtCard(
      padding: EdgeInsets.zero,
      color: ArtColors.subtle,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArtNetworkImage(
                  item.coverUrl,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: ArtworkStatusBadge(done: item.reviewed, solid: true),
                ),
                if (item.imageCount > 1)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${item.imageCount} 张',
                        style: ArtText.caption(size: 11, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ArtText.body(weight: AppFont.w500),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: ArtworkSubjectChip(subject: item.subject),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ArtworkRules.dotDate(item.drawingDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ArtText.caption(size: 11),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _CardScore(item: item),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardScore extends StatelessWidget {
  const _CardScore({required this.item});

  final ArtworkSummary item;

  @override
  Widget build(BuildContext context) {
    final score = item.finalScore;
    if (item.reviewed && score != null) {
      return Text(
        ArtworkRules.formatScore(score),
        style: ArtText.number(size: 17, color: ArtColors.brandDeep),
      );
    }
    if (item.reviewed) {
      return Text('看评语', style: ArtText.caption(size: 11));
    }
    return Text(
      '${item.reviewedCount}/${item.teacherCount} 已评',
      style: ArtText.caption(size: 11, color: ArtColors.warn),
    );
  }
}
