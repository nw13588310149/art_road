import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/art/art_subject.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/art_subject_card.dart';
import '../../../core/widgets/dashboard_course_notice_card.dart';
import '../../../core/widgets/seamless_banner_carousel.dart';
import '../../shell/navigation/shell_notice_routes.dart';
import '../../shell/state/shell_controller.dart';
import '../../smart_campus/state/smart_campus_controller.dart';
import '../state/home_dashboard_controller.dart';
import '../state/home_dashboard_state.dart';
import '../state/home_sections.dart';
import '../state/home_staff_cards.dart';
import '../state/home_student_cards.dart';
import '../../ebooks/ui/home_ebook_shelf_section.dart';
import 'widgets/home_latest_review_card.dart';
import 'widgets/home_practice_card.dart';
import 'widgets/home_review_queue_card.dart';
import 'widgets/home_study_snapshot.dart';
import 'widgets/home_todo_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeDashboardControllerProvider);
    return _HomePageView(state: state);
  }
}

/// 首页版式：上方左栏（轮播 + 功能入口 + 三科入口）与右栏（课程或今日待办），
/// 下方按身份排列的卡片（[HomeSections]）、精选书刊与资讯。
///
/// 右栏与左栏等高；第二行的卡片左宽右窄，与上方两栏对齐，同一行等高。
class _HomePageView extends ConsumerStatefulWidget {
  const _HomePageView({required this.state});

  final HomeDashboardState state;

  @override
  ConsumerState<_HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  static const double _rightWidth = 307;
  static const double _gap = AppSpace.s16;
  static const double _boardHeight = 313;
  static const double _subjectWidth = 146;

  Future<void> _refresh() {
    ref
      ..invalidate(homePracticeProvider)
      ..invalidate(homeLatestReviewProvider)
      ..invalidate(homeReviewStatsProvider)
      ..invalidate(homeAdminTodoProvider);
    return ref.read(homeDashboardControllerProvider.notifier).refresh();
  }

  String get _role => resolveHomeRole(
    widget.state.role,
    token: ref.read(appStorageProvider).token,
  );

  void _onTodo(HomeTodoAction action) {
    switch (action) {
      case HomeTodoAction.artworks:
        Navigator.pushNamed(context, RoutePaths.artworks).then((_) {
          if (mounted) ref.invalidate(homeReviewStatsProvider);
        });
      case HomeTodoAction.notices:
        showShellNotices(context, ref);
      case HomeTodoAction.classWorkbench:
        _openCampus(HomeCampusTarget.classWorkbench);
      case HomeTodoAction.dormCheckByRoom:
        _openCampus(HomeCampusTarget.dormCheckByRoom);
      case HomeTodoAction.dormDynamic:
        _openCampus(HomeCampusTarget.dormDynamic);
      case HomeTodoAction.dormCheckIn:
        _openCampus(HomeCampusTarget.dormCheckIn);
      case HomeTodoAction.dormLeave:
        _openCampus(HomeCampusTarget.myLeave);
      case HomeTodoAction.leaveApproval:
        _openCampus(HomeCampusTarget.leaveApproval);
      case HomeTodoAction.signManagement:
        _openCampus(HomeCampusTarget.signManagement);
      case HomeTodoAction.scheduleManagement:
        _openCampus(HomeCampusTarget.scheduleManagement);
    }
  }

  /// 跳转到智慧校园课表：按 `/myInfo` 真实身份进入「授课课表」或「我的课表」。
  void _openMySchedule() {
    final user = ref.read(shellControllerProvider).user;
    ref
        .read(smartCampusControllerProvider.notifier)
        .openMyScheduleForUser(role: user.role, identity: user.identity);
    Navigator.pushNamed(context, RoutePaths.smartCampus);
  }

  void _onQuickActionTap(HomeQuickAction action) {
    final campus = action.campus;
    if (campus != null) {
      _openCampus(campus);
      return;
    }
    Navigator.pushNamed(context, action.route, arguments: action.arguments);
  }

  /// 先切到智慧校园对应视图，再进入智慧校园页。
  void _openCampus(HomeCampusTarget target) {
    final campus = ref.read(smartCampusControllerProvider.notifier);
    switch (target) {
      case HomeCampusTarget.groupChat:
        campus.openGroupChat();
      case HomeCampusTarget.schoolCircle:
        campus.openSchoolCircle();
      case HomeCampusTarget.principalMailbox:
        campus.openPrincipalMailbox();
      case HomeCampusTarget.dormCheckByRoom:
        campus.openDormCheckByRoom();
      case HomeCampusTarget.dormDynamic:
        campus.openDormDynamic();
      case HomeCampusTarget.dormHistory:
        campus.openDormHistory();
      case HomeCampusTarget.dormCheckIn:
        campus.openDormCheckInManagement();
      case HomeCampusTarget.myLeave:
        campus.openMyTeacherLeave();
      case HomeCampusTarget.studentManagement:
        campus.openStudentManagement();
      case HomeCampusTarget.teacherManagement:
        campus.openTeacherManagement();
      case HomeCampusTarget.classManagement:
        campus.openClassManagement();
      case HomeCampusTarget.scheduleManagement:
        campus.openScheduleManagement();
      case HomeCampusTarget.signManagement:
        campus.openSignManagement();
      case HomeCampusTarget.leaveApproval:
        campus.openDormLeaveApproval();
      case HomeCampusTarget.faceLibrary:
        campus.openFaceLibrary();
      case HomeCampusTarget.notificationManagement:
        campus.openNotificationManagement();
      case HomeCampusTarget.classWorkbench:
        campus.openClassWorkbench();
    }
    Navigator.pushNamed(context, RoutePaths.smartCampus);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (!state.loading && !state.hasContent && state.errorMessage.isNotEmpty) {
      return AppErrorState(
        title: '首页加载失败',
        description: state.errorMessage,
        onRetry: _refresh,
      );
    }
    final firstLoad = state.loading && !state.hasContent;
    final role = _role;
    final sections = homeSectionsFor(role);

    return LayoutBuilder(
      builder: (context, constraints) {
        final leftWidth = constraints.maxWidth - _rightWidth - _gap;
        final bannerHeight = leftWidth * 190 / 647;
        final leftHeight = bannerHeight + _gap + _boardHeight;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _sections(
              role: role,
              sections: sections,
              firstLoad: firstLoad,
              top: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: bannerHeight,
                          child: firstLoad
                              ? const AppSkeleton(radius: AppRadius.card)
                              : _HomeBanner(items: state.bannerItems),
                        ),
                        const SizedBox(height: _gap),
                        SizedBox(
                          height: _boardHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _QuickActionBoard(
                                  actions: state.quickActions,
                                  wide: !sections.subjects,
                                  onTap: _onQuickActionTap,
                                ),
                              ),
                              if (sections.subjects) ...[
                                const SizedBox(width: _gap),
                                const SizedBox(
                                  width: _subjectWidth,
                                  child: _SubjectColumn(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: _gap),
                  SizedBox(
                    width: _rightWidth,
                    height: leftHeight,
                    child: sections.sideTodo
                        ? HomeTodoCard(
                            role: role,
                            side: true,
                            onAction: _onTodo,
                            footer: _sideTodoFooter(role),
                          )
                        : _CoursePanel(
                            loading: firstLoad,
                            weekItems: state.weekItems,
                            courses: state.courseNotices,
                            onOpenSchedule: _openMySchedule,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 右栏今日待办底部的主操作：宿管直接开始查寝，管理员进入智慧校园工作台。
  Widget? _sideTodoFooter(String role) {
    return switch (role) {
      'dormManager' => AppButton(
        label: '按宿舍查寝',
        expand: true,
        onTap: () => _onTodo(HomeTodoAction.dormCheckByRoom),
      ),
      'admin' => AppButton(
        label: '进入智慧校园',
        variant: AppButtonVariant.secondary,
        expand: true,
        onTap: () => Navigator.pushNamed(context, RoutePaths.smartCampus),
      ),
      _ => null,
    };
  }

  /// 第二行：左侧卡片与上方左栏同宽，右侧卡片与右栏同宽，两张卡片等高。
  Widget _pair(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: _gap),
          SizedBox(width: _rightWidth, child: right),
        ],
      ),
    );
  }

  List<Widget> _sections({
    required String role,
    required HomeSections sections,
    required bool firstLoad,
    required Widget top,
  }) {
    return [
      top,
      if (sections.practice) ...[
        const SizedBox(height: _gap),
        _pair(const HomePracticeCard(), const HomeLatestReviewCard()),
      ],
      if (sections.studySnapshot) ...[
        const SizedBox(height: _gap),
        if (sections.reviewQueue)
          _pair(const HomeStudySnapshotCard(), const HomeReviewQueueCard())
        else if (sections.todo)
          _pair(
            const HomeStudySnapshotCard(),
            HomeTodoCard(role: role, onAction: _onTodo),
          )
        else
          const HomeStudySnapshotCard(),
      ],
      const SizedBox(height: _gap),
      const HomeEbookShelfSection(),
      const SizedBox(height: AppSpace.s24),
      AppSectionHeader(
        title: '最新资讯',
        onMore: () => Navigator.pushNamed(context, RoutePaths.consultation),
      ),
      const SizedBox(height: AppSpace.s12),
      _NewsGrid(
        loading: firstLoad,
        items: widget.state.newsItems,
        onOpen: (item) => Navigator.pushNamed(
          context,
          RoutePaths.consultationDetail,
          arguments: <String, dynamic>{'id': item.id},
        ),
      ),
      const SizedBox(height: _gap),
    ];
  }
}

// ─────────────────────── 轮播 ───────────────────────

class _HomeBanner extends StatefulWidget {
  const _HomeBanner({required this.items});

  final List<HomeBannerItem> items;

  @override
  State<_HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<_HomeBanner> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = [
      for (final item in widget.items)
        if (MediaUrl.resolve(item.imageUrl).isNotEmpty)
          MediaUrl.resolve(item.imageUrl),
    ];
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: AppColors.surfaceSubtle),
          ),
          Positioned.fill(
            child: SeamlessBannerCarousel(
              imageUrls: images,
              placeholder: const ColoredBox(color: AppColors.surfaceSubtle),
              empty: const ColoredBox(color: AppColors.surfaceSubtle),
              onPageChanged: (index) {
                if (mounted && _index != index) {
                  setState(() => _index = index);
                }
              },
            ),
          ),
          if (images.length > 1)
            Positioned(
              right: AppSpace.s16,
              bottom: AppSpace.s12,
              child: Row(
                children: [
                  for (var i = 0; i < images.length; i++)
                    Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : AppSpace.s4),
                      width: i == _index ? 20 : 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.onBrand.withValues(
                          alpha: i == _index ? 1 : 0.6,
                        ),
                        borderRadius: AppRadius.brPill,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────── 功能入口 ───────────────────────

class _QuickActionBoard extends StatelessWidget {
  const _QuickActionBoard({
    required this.actions,
    required this.onTap,
    this.wide = false,
  });

  final List<HomeQuickAction> actions;
  final ValueChanged<HomeQuickAction> onTap;

  /// 没有三科入口、独占左栏时，8 个入口排成 4 × 2。
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final columns = actions.length > 9 || (wide && actions.length == 8) ? 4 : 3;
    final rows = (actions.length / columns).ceil();
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s16,
      ),
      child: Column(
        children: [
          for (var row = 0; row < rows; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < columns; col++)
                    Expanded(
                      child: row * columns + col < actions.length
                          ? _QuickActionItem(
                              action: actions[row * columns + col],
                              onTap: () => onTap(actions[row * columns + col]),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({required this.action, required this.onTap});

  final HomeQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (action.iconAsset case final asset?)
            AppAssetGraphic(asset, width: 44, height: 44)
          else
            AppIconTile(icon: action.icon!),
          const SizedBox(height: AppSpace.s8),
          Text(
            action.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14,
          ),
        ],
      ),
    );
  }
}

/// 三科入口：素描 / 色彩 / 速写，点击进入对应科目的范画库。
class _SubjectColumn extends StatelessWidget {
  const _SubjectColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < ArtSubject.values.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s8),
          Expanded(
            child: ArtSubjectCard(
              subject: ArtSubject.values[i],
              borderRadius: AppRadius.card,
              onTap: () => Navigator.pushNamed(
                context,
                RoutePaths.gallery,
                arguments: <String, dynamic>{
                  'subject': ArtSubject.values[i].label,
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────── 课程 ───────────────────────

class _CoursePanel extends StatefulWidget {
  const _CoursePanel({
    required this.loading,
    required this.weekItems,
    required this.courses,
    required this.onOpenSchedule,
  });

  final bool loading;
  final List<HomeWeekDayItem> weekItems;
  final List<HomeCourseNotice> courses;
  final VoidCallback onOpenSchedule;

  @override
  State<_CoursePanel> createState() => _CoursePanelState();
}

class _CoursePanelState extends State<_CoursePanel> {
  static const double _dayWidth = 56;
  static const double _dayGap = AppSpace.s8;

  final _weekScroll = ScrollController();
  String _scrolledFor = '';

  @override
  void dispose() {
    _weekScroll.dispose();
    super.dispose();
  }

  /// 周条默认把今天放在可视区第二格，周末也不会被挡在屏幕外。
  void _scrollToToday() {
    final todayIndex = widget.weekItems.indexWhere((day) => day.isToday);
    final key = '${widget.weekItems.length}-$todayIndex';
    if (todayIndex < 0 || _scrolledFor == key) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_weekScroll.hasClients) return;
      final target = (todayIndex - 1) * (_dayWidth + _dayGap);
      _weekScroll.jumpTo(
        target.clamp(0.0, _weekScroll.position.maxScrollExtent),
      );
      _scrolledFor = key;
    });
  }

  static String _weekdayOf(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    return const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][parsed.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final courses = widget.courses;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final courseDate = courses.isEmpty ? '' : courses.first.date;
    final isToday = courseDate.isEmpty || courseDate == today;
    final title = isToday ? '今日课程' : '下次课程';
    final subtitle = isToday || courseDate.length < 10
        ? null
        : '${courseDate.substring(5)} ${_weekdayOf(courseDate)}';
    if (widget.weekItems.isNotEmpty) {
      _scrollToToday();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: AppButton(
              label: '完整课表',
              variant: AppButtonVariant.text,
              size: AppButtonSize.sm,
              onTap: widget.onOpenSchedule,
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          if (widget.loading) ...[
            const AppSkeleton(height: 88, radius: AppRadius.card),
            const SizedBox(height: AppSpace.s12),
            const AppSkeleton(height: 112, radius: AppRadius.card),
          ] else ...[
            if (widget.weekItems.isNotEmpty) ...[
              SizedBox(
                height: 88,
                child: ListView.separated(
                  controller: _weekScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: widget.weekItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _dayGap),
                  itemBuilder: (context, index) => _WeekDayChip(
                    item: widget.weekItems[index],
                    width: _dayWidth,
                    onTap: widget.onOpenSchedule,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
            ],
            if (courses.isEmpty)
              const SizedBox(
                height: 168,
                child: AppEmptyState(
                  icon: Icons.event_available_outlined,
                  title: '今天没有课程',
                  description: '排课后会在这里显示上课时间和任课老师',
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  itemCount: courses.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.s8),
                  itemBuilder: (context, index) => _courseCard(courses[index]),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _courseCard(HomeCourseNotice course) {
    final ended = course.status == HomeCourseStatus.ended;
    return AppCourseCard(
      startTime: course.startTime,
      endTime: course.endTime,
      subject: course.subjectName,
      teacherName: course.teacherName,
      subtitle: course.description,
      isSmallCourse: course.isSmallCourse,
      avatarUrl: course.teacherAvatar,
      status: switch (course.status) {
        HomeCourseStatus.ended => AppCourseStatus.ended,
        HomeCourseStatus.inProgress => AppCourseStatus.inProgress,
        HomeCourseStatus.upcoming => AppCourseStatus.upcoming,
      },
      classKindDotColor: DashboardCourseNoticeCard.dotColorFromHex(
        course.cardColorHex,
        ended: ended,
      ),
      onTap: widget.onOpenSchedule,
    );
  }
}

class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({
    required this.item,
    required this.width,
    required this.onTap,
  });

  final HomeWeekDayItem item;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = item.isToday;
    return AppPressable(
      onTap: onTap,
      selected: today,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        decoration: BoxDecoration(
          color: today ? AppColors.brand : AppColors.surface,
          image: today
              ? const DecorationImage(
                  image: AssetImage(AppAssets.homeTodayBg),
                  fit: BoxFit.cover,
                )
              : null,
          borderRadius: AppRadius.br12,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.weekText,
              style: AppText.caption12.copyWith(
                color: today ? AppColors.onBrand : AppColors.textTertiary,
              ),
            ),
            Text(
              item.dayText,
              style: AppText.number(
                size: 20,
                color: today ? AppColors.onBrand : AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            AppTag(
              label: '${item.courseCount} 节',
              color: today ? AppColors.brandDeep : AppColors.textSecondary,
              background: today ? AppColors.surface : AppColors.surfaceSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── 资讯 ───────────────────────

class _NewsGrid extends StatelessWidget {
  const _NewsGrid({
    required this.loading,
    required this.items,
    required this.onOpen,
  });

  final bool loading;
  final List<HomeNewsItem> items;
  final ValueChanged<HomeNewsItem> onOpen;

  @override
  Widget build(BuildContext context) {
    if (!loading && items.isEmpty) {
      return const AppCard(
        child: SizedBox(
          height: 168,
          child: AppEmptyState(
            icon: Icons.article_outlined,
            title: '暂无资讯',
            description: '联考政策、校考简章和备考经验发布后会显示在这里',
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 880
            ? 4
            : (constraints.maxWidth >= 600 ? 3 : 2);
        if (loading) {
          return Row(
            children: [
              for (var col = 0; col < columns; col++) ...[
                if (col > 0) const SizedBox(width: AppSpace.s16),
                const Expanded(child: _NewsSkeleton()),
              ],
            ],
          );
        }
        final rows = (items.length / columns).ceil();
        // 同一行的卡片等高：卡片高度随内容，不固定。
        return Column(
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: AppSpace.s16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < columns; col++) ...[
                      if (col > 0) const SizedBox(width: AppSpace.s16),
                      Expanded(child: _cell(row * columns + col)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _cell(int index) {
    if (index >= items.length) {
      return const SizedBox.shrink();
    }
    final item = items[index];
    return _NewsCard(item: item, onTap: () => onOpen(item));
  }
}

class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 120, height: 20),
          SizedBox(height: AppSpace.s12),
          AppSkeleton(),
          SizedBox(height: AppSpace.s8),
          AppSkeleton(width: 140),
          SizedBox(height: AppSpace.s24),
          AppSkeleton(width: 64, height: 22, radius: AppRadius.pill),
          SizedBox(height: AppSpace.s12),
          AppSkeleton(width: 56, height: 12),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.onTap});

  final HomeNewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final created = item.createTime;
    final fresh =
        created != null && now.difference(created) < const Duration(days: 1);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (fresh) ...[
                const AppTag(label: '最新', tone: AppTone.brand),
                const SizedBox(width: AppSpace.s8),
              ],
              Expanded(
                child: Text(
                  item.shortTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body13,
          ),
          const SizedBox(height: AppSpace.s12),
          const Spacer(),
          if (item.tags.isNotEmpty) ...[
            Wrap(
              spacing: AppSpace.s4,
              runSpacing: AppSpace.s4,
              children: [
                for (final tag in item.tags.take(2)) AppTag(label: tag),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
          ],
          Text(formatHomeNewsTime(created, now), style: AppText.caption12),
        ],
      ),
    );
  }
}

/// 资讯发布时间：一小时内「N 分钟前」，一天内「N 小时前」，一月内「N 天前」，更早显示日期。
String formatHomeNewsTime(DateTime? time, DateTime now) {
  if (time == null) {
    return '';
  }
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}
