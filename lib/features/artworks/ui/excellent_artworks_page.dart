import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/excellent_artworks_controller.dart';

/// 优秀作品墙：最小可用列表，后续按原版样式精修。
class ExcellentArtworksPage extends ConsumerStatefulWidget {
  const ExcellentArtworksPage({super.key});

  @override
  ConsumerState<ExcellentArtworksPage> createState() =>
      _ExcellentArtworksPageState();
}

class _ExcellentArtworksPageState extends ConsumerState<ExcellentArtworksPage> {
  final _scrollController = ScrollController();
  String _campusId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    _campusId = args is Map ? args['campusId']?.toString() ?? '' : '';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.extentAfter < 360) {
        unawaited(
          ref
              .read(excellentArtworksControllerProvider(_campusId).notifier)
              .loadMore(),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = excellentArtworksControllerProvider(_campusId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: '优秀作品墙',
          subtitle: '校长推优的全校优秀作品',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s8,
            AppSpace.page,
            AppSpace.s8,
          ),
          child: Wrap(
            spacing: AppSpace.s8,
            children: [
              for (final subject in const ['', '素描', '色彩', '速写'])
                AppChip(
                  label: subject.isEmpty ? '全部' : subject,
                  selected: state.subject == subject,
                  onTap: () => unawaited(controller.setSubject(subject)),
                ),
            ],
          ),
        ),
        Expanded(
          child: state.loading && state.items.isEmpty
              ? const Center(child: AppLoadingIndicator(size: 36))
              : state.errorMessage.isNotEmpty && state.items.isEmpty
              ? AppErrorState(
                  title: '优秀作品墙加载失败',
                  description: state.errorMessage,
                  onRetry: controller.refresh,
                )
              : AppRefreshIndicator(
                  onRefresh: controller.refresh,
                  child: state.items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            AppEmptyState(
                              icon: Icons.star_outline_rounded,
                              title: '还没有优秀作品',
                              description: '校长推优后会出现在这里',
                            ),
                          ],
                        )
                      : GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.page,
                            0,
                            AppSpace.page,
                            AppSpace.s24,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 220 / 240,
                              ),
                          itemCount: state.items.length,
                          itemBuilder: (context, index) {
                            final item = state.items[index];
                            return _ExcellentCard(
                              item: item,
                              onTap: () => Navigator.of(context).pushNamed(
                                RoutePaths.artworks,
                                arguments: <String, dynamic>{
                                  'artworkId': item.id,
                                  'readOnly': true,
                                },
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _ExcellentCard extends StatelessWidget {
  const _ExcellentCard({required this.item, required this.onTap});

  final ArtworkSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: '${item.title}，${item.studentName}',
      child: AppCard(
        color: const Color(0xFFF5F6FA),
        bordered: false,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: item.coverUrl.isEmpty
                    ? const ColoredBox(color: AppColors.surfaceSubtle)
                    : AppImage(src: item.coverUrl, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body13.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      item.studentName,
                      item.className,
                      item.subject,
                      if (item.finalScore != null)
                        '${ArtworkRules.displayScore(item.finalScore)} 分',
                    ].where((part) => part.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
