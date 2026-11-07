import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/class_share_drawer.dart';
import '../../ebooks/data/ebook_collection.dart';
import '../navigation/collection_return.dart';
import '../state/my_collection_controller.dart';
import '../state/my_collection_state.dart';

/// 各收藏类型的打开方式；新增类型时在这里登记，未登记的类型提示暂不支持打开。
final Map<int, void Function(BuildContext context, String targetId)> _openers =
    {
      CollectionType.video: (context, id) => Navigator.pushNamed(
        context,
        RoutePaths.videoTutorial,
        arguments: CollectionReturnNavigator.wrapVideoArgs(id),
      ),
      CollectionType.news: (context, id) => Navigator.pushNamed(
        context,
        RoutePaths.consultationDetail,
        arguments: <String, dynamic>{'id': id},
      ),
      CollectionType.artwork: (context, id) => Navigator.pushNamed(
        context,
        RoutePaths.gallery,
        arguments: <String, dynamic>{'workId': id},
      ),
      CollectionType.ebook: (context, id) => Navigator.pushNamed(
        context,
        RoutePaths.ebooks,
        arguments: EbookCollection.routeArgs(id),
      ),
    };

/// 各类型的收藏入口，用于空状态说明。
const Map<int, String> _collectSources = {
  CollectionType.artwork: '范画库',
  CollectionType.video: '视频中心',
  CollectionType.news: '资讯',
  CollectionType.ebook: '美术书刊',
};

/// 「范画库、视频中心、资讯或美术书刊」。
String _allSourcesText() {
  final sources = _collectSources.values.toList();
  return '${sources.take(sources.length - 1).join('、')}或${sources.last}';
}

/// 群聊暂不能打开的分享类型（书刊分享卡还没有对应的打开方式）。
const Set<int> _unshareableTypes = {CollectionType.ebook};

/// 我的收藏：类型筛选和收藏卡片网格。
class MyCollectionPage extends ConsumerWidget {
  const MyCollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCollectionControllerProvider);
    final controller = ref.read(myCollectionControllerProvider.notifier);
    final loadingItems =
        (state.loading || state.fetchingItems) && state.items.isEmpty;
    final label = CollectionType.labelOf(state.activeType);

    final Widget body;
    if (loadingItems) {
      body = const _CollectionSkeleton();
    } else if (state.items.isEmpty && state.errorMessage != null) {
      body = AppErrorState(
        title: '收藏加载失败',
        description: state.errorMessage!.isEmpty
            ? '网络异常，请检查网络后重试'
            : state.errorMessage,
        onRetry: controller.refresh,
      );
    } else if (state.items.isEmpty) {
      final source = _collectSources[state.activeType];
      body = AppEmptyState(
        illustration: AppAssets.emptyCollectionPlaceholder,
        title: source == null ? '还没有收藏内容' : '还没有收藏的$label',
        description: '在${source ?? _allSourcesText()}里点击收藏，内容会出现在这里',
      );
    } else {
      body = _CollectionGrid(
        items: state.items,
        showTypeTag: state.activeType == CollectionType.all,
        videoLayout: state.activeType == CollectionType.video,
        onOpen: (item) => _openItem(context, item),
        onShare: (item) => _openShare(context, ref, item),
        onRemove: (item) => _removeItem(context, ref, item),
      );
    }

    final tabs = state.tabs;
    return AppCard(
      padding: EdgeInsets.zero,
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tabs.length >= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                AppSpace.s20,
                AppSpace.page,
                AppSpace.s12,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AppSegmented<int>(
                  neutral: true,
                  segments: [
                    for (final tab in tabs)
                      AppSegment(value: tab.type, label: tab.label),
                  ],
                  value: state.activeType,
                  onChanged: controller.selectType,
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }

  void _openItem(BuildContext context, CollectionEntry item) {
    // 目标 id 优先取 target 快照里的 id（与详情接口一致），再退回收藏记录的 targetId。
    final rawId = item.rawPayload['id']?.toString().trim() ?? '';
    final targetId = rawId.isNotEmpty ? rawId : item.targetId;
    if (targetId.isEmpty) {
      AppToast.showError(context, '收藏内容已失效');
      return;
    }
    final open = _openers[item.type];
    if (open == null) {
      AppToast.showInfo(context, '暂不支持打开该类型的收藏');
      return;
    }
    open(context, targetId);
  }

  Future<void> _openShare(
    BuildContext context,
    WidgetRef ref,
    CollectionEntry item,
  ) async {
    final controller = ref.read(myCollectionControllerProvider.notifier);
    final message = await controller.openShare(item);
    if (!context.mounted) {
      return;
    }
    if (message != null) {
      AppToast.showError(context, message);
      return;
    }
    await showClassShareDrawer<void>(
      context: context,
      child: const _CollectionShareDrawer(),
    );
    // 抽屉关闭后清掉分享状态，避免下一次分享复用旧的目标与班级勾选。
    controller.closeShare();
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    CollectionEntry item,
  ) async {
    final confirmed = await showAppConfirm(
      context: context,
      title: '取消收藏',
      message: '「${item.title}」将从我的收藏中移除。',
      danger: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final message = await ref
        .read(myCollectionControllerProvider.notifier)
        .removeFavorite(item);
    if (!context.mounted) {
      return;
    }
    if (message != null) {
      AppToast.showError(context, message);
    } else {
      AppToast.showSuccess(context, '已取消收藏');
    }
  }
}

int _columnsFor(double width) => width >= 840 ? 3 : (width >= 520 ? 2 : 1);

const _cardExtent = 112.0;
const _coverSize = 88.0;
const _videoDetailsHeight = 72.0;

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({
    required this.items,
    required this.showTypeTag,
    required this.videoLayout,
    required this.onOpen,
    required this.onShare,
    required this.onRemove,
  });

  final List<CollectionEntry> items;
  final bool showTypeTag;
  final bool videoLayout;
  final ValueChanged<CollectionEntry> onOpen;
  final ValueChanged<CollectionEntry> onShare;
  final ValueChanged<CollectionEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - AppSpace.page * 2;
        final columns = videoLayout
            ? (width >= 880
                  ? 4
                  : width >= 610
                  ? 3
                  : width >= 365
                  ? 2
                  : 1)
            : _columnsFor(width);
        final cardWidth = (width - AppSpace.s16 * (columns - 1)) / columns;
        final videoCoverHeight = (cardWidth - AppSpace.s12 * 2) * 9 / 16;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s4,
            AppSpace.page,
            AppSpace.s24,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpace.s16,
            mainAxisSpacing: AppSpace.s16,
            mainAxisExtent: videoLayout
                ? videoCoverHeight +
                      AppSpace.s12 * 2 +
                      AppSpace.s8 +
                      _videoDetailsHeight
                : _cardExtent,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _CollectionCard(
              item: item,
              showTypeTag: showTypeTag,
              videoLayout: videoLayout,
              onTap: () => onOpen(item),
              onShare: () => onShare(item),
              onRemove: () => onRemove(item),
            );
          },
        );
      },
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.item,
    required this.showTypeTag,
    required this.videoLayout,
    required this.onTap,
    required this.onShare,
    required this.onRemove,
  });

  final CollectionEntry item;
  final bool showTypeTag;
  final bool videoLayout;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final views = int.tryParse(item.metricText) ?? 0;
    final pages = item.isEbook
        ? int.tryParse('${item.rawPayload['pageCount'] ?? ''}') ?? 0
        : 0;
    final cover = _CollectionCover(item: item, wide: videoLayout);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: videoLayout ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.body14Strong,
        ),
        if (item.subtitle.isNotEmpty)
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption12,
          ),
        const Spacer(),
        Row(
          children: [
            if (showTypeTag) ...[
              AppTag(
                label: CollectionType.labelOf(item.type),
                tone: AppTone.brand,
              ),
              const SizedBox(width: AppSpace.s8),
            ],
            if (pages > 0) Text('$pages 页', style: AppText.caption12),
            if (views > 0 && !item.isArtwork && !item.isEbook) ...[
              AppAssetGraphic(
                item.isVideo ? AppAssets.videoV2CardViews : AppAssets.newsViews,
                width: 14,
                height: 14,
              ),
              const SizedBox(width: AppSpace.s4),
              Expanded(
                child: Text(
                  '$views',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12,
                ),
              ),
            ] else
              const Spacer(),
            Builder(
              builder: (anchor) => AppIconButton.asset(
                asset: AppAssets.cloudActionMore,
                assetSize: 20,
                semanticLabel: '收藏操作',
                size: AppButtonSize.sm,
                filled: false,
                onTap: () => _openMenu(anchor),
              ),
            ),
          ],
        ),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s12),
      onTap: onTap,
      child: videoLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cover),
                const SizedBox(height: AppSpace.s8),
                SizedBox(height: _videoDetailsHeight, child: details),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                const SizedBox(width: AppSpace.s12),
                Expanded(child: details),
              ],
            ),
    );
  }

  Future<void> _openMenu(BuildContext anchor) async {
    final action = await showAppMenu<_CollectionMenuAction>(
      context: anchor,
      width: 144,
      items: [
        if (!_unshareableTypes.contains(item.type))
          const AppMenuItem(
            value: _CollectionMenuAction.share,
            label: '分享给班级',
            iconAsset: AppAssets.coursewareActionShare,
          ),
        const AppMenuItem(
          value: _CollectionMenuAction.remove,
          label: '取消收藏',
          iconAsset: AppAssets.coursewareActionDelete,
          danger: true,
        ),
      ],
    );
    if (action == _CollectionMenuAction.share) onShare();
    if (action == _CollectionMenuAction.remove) onRemove();
  }
}

enum _CollectionMenuAction { share, remove }

class _CollectionCover extends StatelessWidget {
  const _CollectionCover({required this.item, this.wide = false});

  final CollectionEntry item;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final raw = item.coverUrl.trim();
    final src = raw.isEmpty || raw.toLowerCase() == 'string'
        ? ''
        : MediaUrl.resolve(raw);
    final duration = item.durationText.trim();
    return SizedBox(
      // 书刊封面是 3:4 竖版，其它类型裁成方图。
      width: wide
          ? double.infinity
          : (item.isEbook ? _coverSize * 3 / 4 : _coverSize),
      height: wide ? null : _coverSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(
            src: src,
            borderRadius: AppRadius.br8,
            error: _fallback(),
            placeholder: src.isEmpty ? _fallback() : null,
          ),
          if (item.isVideo && duration.isNotEmpty && duration != '00:00')
            Positioned(
              right: AppSpace.s4,
              bottom: AppSpace.s4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.6),
                  borderRadius: AppRadius.br4,
                ),
                child: Text(
                  duration,
                  style: AppText.number(size: 12, color: AppColors.onBrand),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br8,
      ),
      alignment: Alignment.center,
      child: Icon(switch (item.type) {
        CollectionType.video => Icons.play_circle_outline_rounded,
        CollectionType.news => Icons.feed_outlined,
        CollectionType.artwork => Icons.palette_outlined,
        CollectionType.ebook => Icons.menu_book_outlined,
        _ => Icons.bookmark_border_rounded,
      }, color: AppColors.textPlaceholder),
    );
  }
}

class _CollectionSkeleton extends StatelessWidget {
  const _CollectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth - AppSpace.page * 2);
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s4,
            AppSpace.page,
            AppSpace.s24,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpace.s16,
            mainAxisSpacing: AppSpace.s16,
            mainAxisExtent: _cardExtent,
          ),
          itemCount: columns * 2,
          itemBuilder: (_, _) => const AppCard(
            padding: EdgeInsets.all(AppSpace.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(
                  width: _coverSize,
                  height: _coverSize,
                  radius: AppRadius.control,
                ),
                SizedBox(width: AppSpace.s12),
                Expanded(child: AppSkeletonText(lines: 3)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 收藏分享：复用公共班级分享抽屉，班级勾选与发送交给控制器。
class _CollectionShareDrawer extends ConsumerWidget {
  const _CollectionShareDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCollectionControllerProvider);
    final controller = ref.read(myCollectionControllerProvider.notifier);
    final target = state.shareTarget;
    if (target == null) {
      // 外部关闭抽屉时控制器已清掉分享目标，这里渲染空抽屉等待出栈。
      return const ClassShareDrawer(
        title: '分享收藏',
        targetCard: SizedBox.shrink(),
        classes: <ClassShareItem>[],
        loading: false,
        sending: false,
        onToggleClass: _noopToggle,
        onSend: _noopSend,
      );
    }
    final hasClasses = state.shareClasses.isNotEmpty;
    return ClassShareDrawer(
      title: '分享收藏',
      targetCard: ShareTargetCard(
        label: '你将分享的内容',
        title: target.title,
        coverUrl: target.coverUrl,
        resolveUrl: MediaUrl.resolve,
      ),
      classes: state.shareClasses
          .map(
            (c) => ClassShareItem(
              id: c.id,
              name: c.name,
              avatarUrl: c.avatarUrl,
              checked: c.selected,
            ),
          )
          .toList(growable: false),
      loading: state.busy && !hasClasses,
      sending: state.busy && hasClasses,
      onToggleClass: (id) {
        if (id.isNotEmpty) {
          controller.toggleShareClass(id);
        }
      },
      onSend: () async {
        final message = await controller.sendShare();
        if (!context.mounted) return;
        if (message != null) {
          AppToast.showError(context, message);
          return;
        }
        Navigator.of(context).pop();
        AppToast.showSuccess(context, '已分享到班级群');
      },
    );
  }
}

void _noopToggle(String _) {}
Future<void> _noopSend() async {}
