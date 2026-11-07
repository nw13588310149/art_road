import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../consultation/state/consultation_state.dart';
import '../state/school_page_controller.dart';
import '../state/school_page_state.dart';

/// 校园课件：画室自己的课程视频（课件目录）+ 学习进度 + 校园资源入口 + 校园资讯。
class SchoolCoursewareV2Page extends ConsumerWidget {
  const SchoolCoursewareV2Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolPageControllerProvider);
    final ctrl = ref.read(schoolPageControllerProvider.notifier);
    final navigator = Navigator.of(context);
    final empty =
        state.courseVideos.isEmpty &&
        state.learningItems.isEmpty &&
        state.newsItems.isEmpty;

    final Widget body;
    if (state.loading && empty) {
      body = const _SchoolSkeleton();
    } else if (empty && state.errorMessage.isNotEmpty) {
      body = AppErrorState(
        title: '校园课件加载失败',
        description: state.errorMessage,
        onRetry: ctrl.refresh,
      );
    } else {
      body = _SchoolBody(state: state, onRefresh: ctrl.refresh);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: '校园课件',
          subtitle: state.schoolName.isEmpty
              ? '画室的课程视频、练习与资讯'
              : '${state.schoolName}的课程视频、练习与资讯',
          onBack: navigator.canPop() ? navigator.pop : null,
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// 进入校园专属页面时透传的学校标记：二级页按 truthy 解析为校园模式。
Map<String, dynamic> _schoolArgs(SchoolPageState state) => <String, dynamic>{
  'school': state.schoolId != '0' ? state.schoolId : true,
  if (state.schoolName.isNotEmpty) 'sourceName': state.schoolName,
};

class _SchoolBody extends StatelessWidget {
  const _SchoolBody({required this.state, required this.onRefresh});

  final SchoolPageState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final videos = _CourseVideosCard(state: state);
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LearningProgressCard(items: state.learningItems),
        const SizedBox(height: AppSpace.s16),
        _QuickEntriesCard(state: state),
      ],
    );
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s4,
              AppSpace.page,
              AppSpace.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: videos),
                      const SizedBox(width: AppSpace.s16),
                      SizedBox(width: 300, child: side),
                    ],
                  )
                else ...[
                  videos,
                  const SizedBox(height: AppSpace.s16),
                  side,
                ],
                const SizedBox(height: AppSpace.s24),
                AppSectionHeader(
                  title: '校园资讯',
                  subtitle: '画室发布的通知与动态',
                  moreLabel: '查看全部',
                  onMore: () => Navigator.pushNamed(
                    context,
                    RoutePaths.consultation,
                    arguments: _schoolArgs(state),
                  ),
                ),
                const SizedBox(height: AppSpace.s12),
                _NewsGrid(items: state.newsItems, sourceName: state.schoolName),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CourseVideosCard extends StatelessWidget {
  const _CourseVideosCard({required this.state});

  final SchoolPageState state;

  void _open(BuildContext context, [String? videoId]) {
    Navigator.pushNamed(
      context,
      RoutePaths.schoolVideo,
      arguments: <String, dynamic>{
        ..._schoolArgs(state),
        'openVideoId': ?videoId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = state.courseVideos;
    return AppCard(
      title: '课程视频',
      subtitle: '老师录制的讲评与示范',
      trailing: AppButton(
        label: '全部视频',
        variant: AppButtonVariant.text,
        size: AppButtonSize.sm,
        onTap: () => _open(context),
      ),
      child: videos.isEmpty
          ? const SizedBox(
              height: 220,
              child: AppEmptyState(
                icon: Icons.video_library_outlined,
                title: '画室还没有发布课程视频',
                description: '老师上传讲评与示范视频后会显示在这里',
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                const gap = AppSpace.s16;
                final columns = constraints.maxWidth >= 520 ? 3 : 2;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final video in videos)
                      SizedBox(
                        width: width,
                        child: _CourseVideoTile(
                          video: video,
                          onTap: () => _open(context, video.id),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _CourseVideoTile extends StatelessWidget {
  const _CourseVideoTile({required this.video, required this.onTap});

  final SchoolCourseVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (video.teacherName.isNotEmpty) video.teacherName,
      if (video.category.isNotEmpty) video.category,
    ].join(' · ');
    return AppPressable(
      onTap: onTap,
      semanticLabel: video.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(src: video.coverUrl, borderRadius: AppRadius.br8),
                if (video.duration.isNotEmpty)
                  Positioned(
                    right: AppSpace.s4,
                    bottom: AppSpace.s4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.6),
                        borderRadius: AppRadius.br4,
                      ),
                      child: Text(
                        video.duration,
                        style: AppText.number(
                          size: 12,
                          color: AppColors.onBrand,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          SizedBox(
            height: 44,
            child: Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body14Strong,
            ),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption12,
            ),
        ],
      ),
    );
  }
}

class _LearningProgressCard extends StatelessWidget {
  const _LearningProgressCard({required this.items});

  final List<SchoolLearningItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: '学习进度',
      subtitle: '按课时统计',
      child: items.isEmpty
          ? Text('暂无课时安排', style: AppText.caption12)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpace.s16),
                  _ProgressRow(item: items[i]),
                ],
              ],
            ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.item});

  final SchoolLearningItem item;

  @override
  Widget build(BuildContext context) {
    final completed = item.completed;
    final progress = item.progress.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppTag.subject(item.text),
            const Spacer(),
            if (completed)
              const AppTag(label: '已完成', tone: AppTone.success)
            else
              Text('$progress%', style: AppText.number(size: 14)),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        AppProgressBar(
          value: progress / 100,
          color: completed ? AppColors.success : item.color,
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          completed
              ? '${item.text}课程已全部完成'
              : '已上 ${item.completeCount} / 共 ${item.allCount} 课时，剩余 ${item.remainingCount} 课时',
          style: AppText.caption12,
        ),
      ],
    );
  }
}

class _QuickEntriesCard extends StatelessWidget {
  const _QuickEntriesCard({required this.state});

  final SchoolPageState state;

  @override
  Widget build(BuildContext context) {
    final actions = state.quickActions;
    return AppCard(
      padding: const EdgeInsets.only(bottom: AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s4,
            ),
            child: Text('校园资源', style: AppText.title16),
          ),
          for (var i = 0; i < actions.length; i++)
            AppListRow(
              title: actions[i].name,
              leading: AppIconTile(icon: actions[i].icon, size: 36),
              chevron: true,
              divider: i < actions.length - 1,
              onTap: () {
                final action = actions[i];
                if (action.comingSoon) {
                  AppToast.showInfo(context, '「${action.name}」即将开放');
                  return;
                }
                Navigator.pushNamed(
                  context,
                  action.route,
                  arguments: <String, dynamic>{
                    ..._schoolArgs(state),
                    if (action.firstMenu != null)
                      'firstMenu': action.firstMenu.toString(),
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _NewsGrid extends StatelessWidget {
  const _NewsGrid({required this.items, required this.sourceName});

  final List<SchoolNewsItem> items;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppCard(
        child: SizedBox(
          height: 160,
          child: AppEmptyState(
            icon: Icons.feed_outlined,
            title: '画室还没有发布资讯',
            description: '通知、写生安排与作品展评会显示在这里',
          ),
        ),
      );
    }
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpace.s16,
            mainAxisSpacing: AppSpace.s16,
            mainAxisExtent: 150,
          ),
          itemCount: items.take(4).length,
          itemBuilder: (context, i) =>
              _NewsCard(item: items[i], sourceName: sourceName, now: now),
        );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.sourceName,
    required this.now,
  });

  final SchoolNewsItem item;
  final String sourceName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final created = item.createTime;
    final latest =
        created != null &&
        !now.difference(created).isNegative &&
        now.difference(created) < const Duration(hours: 24);
    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        RoutePaths.consultationDetail,
        arguments: <String, dynamic>{
          'id': item.id,
          if (sourceName.isNotEmpty) 'sourceName': sourceName,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14Strong,
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s4,
            runSpacing: AppSpace.s4,
            children: [for (final tag in item.tags.take(2)) AppTag(label: tag)],
          ),
          const Spacer(),
          Row(
            children: [
              if (latest) ...[
                const AppTag(label: '最新', tone: AppTone.brand),
                const SizedBox(width: AppSpace.s8),
              ],
              Flexible(
                child: Text(
                  formatRelativeTime(created),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SchoolSkeleton extends StatelessWidget {
  const _SchoolSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s4,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppCard(
              child: Column(
                children: [
                  AppSkeletonText(lines: 1, lineHeight: 18),
                  SizedBox(height: AppSpace.s16),
                  AppSkeleton(height: 120, radius: AppRadius.control),
                  SizedBox(height: AppSpace.s16),
                  AppSkeleton(height: 120, radius: AppRadius.control),
                ],
              ),
            ),
          ),
          SizedBox(width: AppSpace.s16),
          SizedBox(
            width: 300,
            child: AppCard(child: AppSkeletonText(lines: 8)),
          ),
        ],
      ),
    );
  }
}
