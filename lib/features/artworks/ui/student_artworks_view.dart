import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/student_artworks_controller.dart';
import 'artwork_upload_dialog.dart';
import 'student_artwork_detail_view.dart';
import 'widgets/artwork_widgets.dart';

/// 学生「作品档案」：统计、点评小结、按月分组的作品墙，点开进入作品详情。
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
  bool _showSuggestions = false;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: '作品档案',
          subtitle: '记录每一张画，收好老师的每一次点评',
          actions: [
            AppButton(
              label: '上传作品',
              icon: Icons.add_photo_alternate_outlined,
              size: AppButtonSize.sm,
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
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.page,
                        AppSpace.s4,
                        AppSpace.page,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: state.loaded
                            ? _StatsCard(stats: state.stats)
                            : const AppSkeleton(
                                height: 96,
                                radius: AppRadius.card,
                              ),
                      ),
                    ),
                    if (state.loaded)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.page,
                          AppSpace.s16,
                          AppSpace.page,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _InsightsCard(
                            insights: state.insights,
                            showSuggestions: _showSuggestions,
                            onToggleSuggestions: () => setState(
                              () => _showSuggestions = !_showSuggestions,
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.page,
                        AppSpace.s24,
                        AppSpace.page,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            AppSegmented<ArtworkStatusFilter>(
                              segments: [
                                for (final filter in ArtworkStatusFilter.values)
                                  AppSegment(
                                    value: filter,
                                    label: filter.label,
                                  ),
                              ],
                              value: state.filter,
                              onChanged: (f) =>
                                  unawaited(controller.setFilter(f)),
                            ),
                            const Spacer(),
                            if (state.loaded &&
                                !state.loadingList &&
                                !state.listFailed)
                              Text(
                                '共 ${state.total} 件',
                                style: AppText.caption12,
                              ),
                          ],
                        ),
                      ),
                    ),
                    ..._gridSlivers(
                      state,
                      controller,
                      constraints.maxWidth - AppSpace.page * 2,
                    ),
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

  List<Widget> _gridSlivers(
    StudentArtworksState state,
    StudentArtworksController controller,
    double width,
  ) {
    const spacing = AppSpace.s16;
    final columns = math.max(2, ((width + spacing) / (200 + spacing)).floor());
    final cardWidth = (width - spacing * (columns - 1)) / columns;
    final extent = cardWidth * 3 / 4 + _ArtworkCard.infoHeight;
    SliverGridDelegate grid() => SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      mainAxisExtent: extent,
    );

    if (state.items.isEmpty) {
      if (!state.loaded || state.loadingList) {
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s16,
              AppSpace.page,
              0,
            ),
            sliver: SliverGrid(
              gridDelegate: grid(),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const AppSkeleton(
                  height: double.infinity,
                  radius: AppRadius.card,
                ),
                childCount: columns,
              ),
            ),
          ),
        ];
      }
      if (state.listFailed) {
        return [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: AppErrorState(
                title: '作品加载失败',
                description: '请检查网络后重试',
                onRetry: controller.refresh,
              ),
            ),
          ),
        ];
      }
      final canUpload = state.filter != ArtworkStatusFilter.reviewed;
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 240,
            child: AppEmptyState(
              icon: Icons.photo_library_outlined,
              title: switch (state.filter) {
                ArtworkStatusFilter.all => '还没有作品',
                ArtworkStatusFilter.pending => '没有待点评的作品',
                ArtworkStatusFilter.reviewed => '还没有完成点评的作品',
              },
              description: switch (state.filter) {
                ArtworkStatusFilter.all => '把日常作业拍照上传，老师会逐一点评',
                ArtworkStatusFilter.pending => '上传的作品在老师点评完成前会出现在这里',
                ArtworkStatusFilter.reviewed => '全部老师点评完成后，作品会出现在这里',
              },
              actionLabel: canUpload ? '上传作品' : null,
              onAction: canUpload ? _upload : null,
            ),
          ),
        ),
      ];
    }

    final groups = ArtworkRules.groupByMonth(
      state.items,
      (item) => item.drawingDate,
    );
    return [
      for (final (month, works) in groups) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s20,
            AppSpace.page,
            AppSpace.s12,
          ),
          sliver: SliverToBoxAdapter(
            child: AppSectionHeader(
              title: ArtworkRules.monthLabel(month),
              trailing: Text('${works.length} 件', style: AppText.caption12),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
          sliver: SliverGrid(
            gridDelegate: grid(),
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
            padding: EdgeInsets.symmetric(vertical: AppSpace.s16),
            child: Center(child: AppLoadingIndicator(size: 30)),
          ),
        ),
    ];
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final ArtworkStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('累计作品', stats.total),
      ('已点评', stats.reviewed),
      ('待点评', stats.pending),
    ];
    return AppCard(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s12),
            Expanded(
              child: AppStatTile(
                label: items[i].$1,
                value: '${items[i].$2}',
                unit: '件',
                boxed: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 点评小结：只统计全部老师点评完成的日常作品；问题与亮点分开展示。
class _InsightsCard extends StatelessWidget {
  const _InsightsCard({
    required this.insights,
    required this.showSuggestions,
    required this.onToggleSuggestions,
  });

  final ArtworkInsights insights;
  final bool showSuggestions;
  final VoidCallback onToggleSuggestions;

  @override
  Widget build(BuildContext context) {
    final problems = [
      for (final tag in insights.topTags)
        if (!ArtworkRules.isHighlightTag(tag.color, positive: tag.positive))
          tag,
    ];
    final highlights = [
      for (final tag in insights.topTags)
        if (ArtworkRules.isHighlightTag(tag.color, positive: tag.positive)) tag,
    ];
    final hasData = insights.reviewedCount > 0;
    return AppCard(
      title: '点评小结',
      subtitle: hasData ? '基于 ${insights.reviewedCount} 件已点评的日常作品' : null,
      trailing: hasData && insights.suggestions.isNotEmpty
          ? AppButton(
              label: showSuggestions ? '收起练习建议' : '查看练习建议',
              icon: showSuggestions
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              variant: AppButtonVariant.text,
              size: AppButtonSize.sm,
              onTap: onToggleSuggestions,
            )
          : null,
      child: !hasData
          ? Text(
              '老师点评后，这里会汇总你常出现的问题和做得好的地方，并推荐对应的范画、教程与工具',
              style: AppText.body13.copyWith(color: AppColors.textTertiary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpace.s24,
                  runSpacing: AppSpace.s8,
                  children: [
                    if (insights.averageScore != null)
                      _MetaItem(
                        label: '平均分',
                        value:
                            '${ArtworkRules.displayScore(insights.averageScore)} 分',
                      ),
                    if (insights.bestSubject.isNotEmpty)
                      _MetaItem(label: '得分最高科目', value: insights.bestSubject),
                    if (insights.weakestSubject.isNotEmpty)
                      _MetaItem(label: '有待加强', value: insights.weakestSubject),
                  ],
                ),
                if (problems.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s16),
                  _TagGroup(label: '高频问题', tags: problems),
                ],
                if (highlights.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s12),
                  _TagGroup(label: '做得好的地方', tags: highlights),
                ],
                if (showSuggestions && insights.suggestions.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s16),
                  for (var i = 0; i < insights.suggestions.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpace.s8),
                    _SuggestionRow(suggestion: insights.suggestions[i]),
                  ],
                ],
              ],
            ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label  ', style: AppText.caption12),
          TextSpan(text: value, style: AppText.body14Strong),
        ],
      ),
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({required this.label, required this.tags});

  final String label;
  final List<ArtworkInsightTag> tags;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(label, style: AppText.caption12),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final tag in tags)
                ArtworkReviewTag(
                  name: tag.name,
                  color: tag.color,
                  positive: tag.positive,
                  count: tag.count,
                  tooltip: tag.explanation,
                ),
            ],
          ),
        ),
      ],
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
    final label = AppTag(label: s.tag, tone: AppTone.warning);
    final text = Text(
      s.text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppText.body13,
    );
    final actions = Wrap(
      spacing: AppSpace.s4,
      children: [
        AppButton(
          label: '看范画',
          icon: Icons.photo_library_outlined,
          variant: AppButtonVariant.text,
          size: AppButtonSize.sm,
          onTap: () => _open(context, RoutePaths.gallery, <String, dynamic>{
            'subject': s.gallerySubject,
            'keyword': s.galleryKeyword,
          }),
        ),
        AppButton(
          label: '看教程',
          icon: Icons.play_circle_outline_rounded,
          variant: AppButtonVariant.text,
          size: AppButtonSize.sm,
          onTap: () => _open(
            context,
            RoutePaths.videoTutorial,
            <String, dynamic>{'keyword': s.galleryKeyword},
          ),
        ),
        if (s.tool.isNotEmpty)
          AppButton(
            label: s.tool,
            icon: Icons.handyman_outlined,
            variant: AppButtonVariant.text,
            size: AppButtonSize.sm,
            onTap: () => _open(
              context,
              RoutePaths.artToolbox,
              <String, dynamic>{'tool': s.tool},
            ),
          ),
      ],
    );
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    label,
                    const SizedBox(width: AppSpace.s8),
                    Expanded(child: text),
                  ],
                ),
                actions,
              ],
            );
          }
          return Row(
            children: [
              label,
              const SizedBox(width: AppSpace.s12),
              Expanded(child: text),
              const SizedBox(width: AppSpace.s12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({required this.item, required this.onTap});

  /// 封面以下信息区的固定高度。
  static const infoHeight = 78.0;

  final ArtworkSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card - 1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(src: item.coverUrl),
                  Positioned(
                    left: AppSpace.s8,
                    top: AppSpace.s8,
                    child: ArtworkStatusTag(done: item.reviewed),
                  ),
                  if (item.imageCount > 1)
                    Positioned(
                      right: AppSpace.s8,
                      bottom: AppSpace.s8,
                      child: ArtworkImageCountTag(count: item.imageCount),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14Strong,
                  ),
                  Row(
                    children: [
                      ArtworkSubjectTag(subject: item.subject),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          ArtworkRules.dateText(item.drawingDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s4),
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
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: ArtworkRules.displayScore(score),
              style: AppText.number(size: 16),
            ),
            TextSpan(text: ' 分', style: AppText.caption12),
          ],
        ),
      );
    }
    if (item.reviewed) {
      return Text('看评语', style: AppText.caption12);
    }
    return Text(
      '${item.reviewedCount}/${item.teacherCount} 位已评',
      style: AppText.caption12,
    );
  }
}
