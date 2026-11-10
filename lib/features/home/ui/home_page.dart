import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/art/art_subject.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/ui/ui.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/smooth_circle_network_avatar.dart';
import '../../shell/ui/shell_layout.dart';
import 'widgets/home_course_notice_card.dart';
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
      const SizedBox(height: 14),
      _HomeLatestHeader(
        title: '最新',
        onMoreTap: () => Navigator.pushNamed(context, RoutePaths.consultation),
      ),
      const SizedBox(height: 10),
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
    final slides = [
      for (final item in widget.items)
        if (item.imageUrl.trim().isNotEmpty)
          (url: MediaUrl.resolve(item.imageUrl), title: item.title),
    ];
    return ClipRRect(
      borderRadius: AppRadius.br16,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: AppColors.surfaceSubtle),
          ),
          Positioned.fill(
            child: SeamlessBannerCarousel(
              imageUrls: [for (final slide in slides) slide.url],
              placeholder: const AppSkeleton(radius: 16),
              empty: const ColoredBox(color: AppColors.surfaceSubtle),
              animationDuration: const Duration(milliseconds: 420),
              animationCurve: Curves.easeInOutCubic,
              onPageChanged: (index) {
                if (mounted && _index != index) {
                  setState(() => _index = index);
                }
              },
            ),
          ),
          if (slides.length > 1)
            Positioned(
              right: AppSpace.s16,
              bottom: AppSpace.s12,
              child: Row(
                children: [
                  for (var i = 0; i < slides.length; i++)
                    Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : AppSpace.s4),
                      width: i == _index ? 21 : 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.onBrand.withValues(
                          alpha: i == _index ? 1 : 0.85,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const itemWidth = 44.0;
            const idealGap = 105.0;
            const idealOuterPad = 66.0;
            final idealExtra = (columns - 1) * idealGap + 2 * idealOuterPad;
            final extra = (constraints.maxWidth - columns * itemWidth).clamp(
              0.0,
              double.infinity,
            );
            final factor = math.min(1.0, extra / idealExtra);
            final gap = math.max(8.0, idealGap * factor);
            final outerPad = math.max(12.0, idealOuterPad * factor);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: outerPad, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var row = 0; row < rows; row++)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var col = 0; col < columns; col++) ...[
                          if (col > 0) SizedBox(width: gap),
                          SizedBox(
                            width: itemWidth,
                            child: row * columns + col < actions.length
                                ? _QuickActionItem(
                                    action: actions[row * columns + col],
                                    onTap: () =>
                                        onTap(actions[row * columns + col]),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
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

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({required this.action, required this.onTap});

  final HomeQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (action.iconAsset case final asset?)
            AppAssetGraphic(asset, width: 44, height: 44)
          else
            AppIconTile(icon: action.icon!),
          const SizedBox(height: 6),
          OverflowBox(
            fit: OverflowBoxFit.deferToChild,
            minWidth: 0,
            maxWidth: 112,
            child: Text(
              action.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF1A1A1A),
                fontWeight: AppFont.w500,
                fontFamily: 'PingFang SC',
                height: 1,
              ),
            ),
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
  static const double _dayGap = AppSpace.s8;
  static const int _visibleDays = 4;

  final _weekScroll = ScrollController();
  (int, int, double)? _scrolledFor;

  @override
  void dispose() {
    _weekScroll.dispose();
    super.dispose();
  }

  /// 周一至周四显示前四格，周五起显示末四格，每格完整可见。
  void _scrollToToday(double dayWidth) {
    final todayIndex = widget.weekItems.indexWhere((day) => day.isToday);
    final count = widget.weekItems.length;
    final key = (count, todayIndex, dayWidth);
    if (_scrolledFor == key) return;
    _scrolledFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_weekScroll.hasClients || _scrolledFor != key) return;
      final first = todayIndex < _visibleDays ? 0 : count - _visibleDays;
      final target = first * (dayWidth + _dayGap);
      _weekScroll.jumpTo(
        target.clamp(0.0, _weekScroll.position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = widget.courses;
    return AppCard(
      bordered: false,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('课表', style: _courseHeading),
          const SizedBox(height: 6),
          if (widget.loading) ...[
            const AppSkeleton(height: 88, radius: AppRadius.card),
            const SizedBox(height: AppSpace.s12),
            const AppSkeleton(height: 112, radius: AppRadius.card),
          ] else ...[
            if (widget.weekItems.isNotEmpty) ...[
              SizedBox(
                height: 88,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const dayWidth = 64.0;
                    _scrollToToday(dayWidth);
                    return ListView.separated(
                      controller: _weekScroll,
                      padding: EdgeInsets.zero,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      itemCount: widget.weekItems.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: _dayGap),
                      itemBuilder: (context, index) => _WeekDayChip(
                        item: widget.weekItems[index],
                        width: dayWidth,
                        onTap: widget.onOpenSchedule,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text('课程', style: _courseHeading),
            const SizedBox(height: 6),
            if (courses.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    '今日暂无排课',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFFB6B5BB),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  itemCount: courses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 11),
                  itemBuilder: (context, index) => _courseCard(courses[index]),
                ),
              ),
          ],
        ],
      ),
    );
  }

  TextStyle get _courseHeading => TextStyle(
    fontSize: 18,
    color: const Color(0xFF1A1A1A),
    fontWeight: AppFont.w500,
    fontFamily: 'PingFang SC',
  );

  Widget _courseCard(HomeCourseNotice course) => AppPressable(
    onTap: widget.onOpenSchedule,
    child: HomeCourseNoticeCard(
      startTime: course.startTime,
      endTime: course.endTime,
      subjectName: course.subjectName,
      displayName: course.teacherName,
      subtitle: course.description,
      isSmallCourse: course.isSmallCourse,
      avatar: SmoothCircleNetworkAvatar(
        url: MediaUrl.resolve(course.teacherAvatar),
        size: 40,
      ),
      runState: switch (course.status) {
        HomeCourseStatus.ended => DashboardCourseRunState.ended,
        HomeCourseStatus.inProgress => DashboardCourseRunState.inProgress,
        HomeCourseStatus.upcoming => DashboardCourseRunState.upcoming,
      },
      tagDotColor: DashboardCourseNoticeCard.dotColorFromHex(
        course.cardColorHex,
        ended: course.status == HomeCourseStatus.ended,
      ),
    ),
  );
}

class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({
    required this.item,
    required this.width,
    required this.onTap,
  });
  final double width;
  final VoidCallback onTap;

  final HomeWeekDayItem item;

  @override
  Widget build(BuildContext context) {
    final active = item.isToday;

    return AppPressable(
      onTap: onTap,
      selected: active,
      child: Container(
        width: width,
        height: 88,
        decoration: BoxDecoration(
          // 「今日」高亮背景：从代码渐变改为预设 PNG（[AppAssets.homeTodayBg]
          // = bgc.png，64×88 顶紫底浅渐变，自带 12 圆角）。BoxFit.cover 让位图
          // 撑满整个卡片；外层 borderRadius 仍保留 12，与图本身的圆角对齐时
          // 顺便裁掉 PNG 边缘可能的透明像素，避免在白底上露出锯齿。
          image: active
              ? const DecorationImage(
                  image: AssetImage(AppAssets.homeTodayBg),
                  fit: BoxFit.cover,
                )
              : null,
          // Figma：非今天卡片底色为 white（与右侧面板同色，仅 chip/文本可见）
          color: active ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 6,
              child: Text(
                item.weekText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: active
                      ? const Color(0xFFBBB5F3)
                      : const Color(0xFFA9A9A9),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.43,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 27,
              child: Text(
                item.dayText,
                textAlign: TextAlign.center,
                // 设计稿要求：周课表日期数字 = Manrope Medium（w500）。
                // 字体文件 [assets/fonts/Manrope Medium.ttf] 在 pubspec 里以
                // weight: 500 注册到 Manrope family，下面 w500 直接命中。
                style: TextStyle(
                  fontSize: 20,
                  color: active ? Colors.white : const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  fontFamily: 'Manrope',
                ),
              ),
            ),
            Positioned(
              left: 6,
              top: 61,
              child: Container(
                width: 52,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : const Color(0xFFF1F2F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.courseCount}节',
                  style: TextStyle(
                    fontSize: 14,
                    color: active
                        ? const Color(0xFF715EFE)
                        : const Color(0xFFA9A9A9),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.43,
                  ),
                ),
              ),
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
    if (!loading && items.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 138,
      ),
      itemCount: loading ? 4 : items.length,
      itemBuilder: (context, index) => loading
          ? const AppSkeleton(height: 138, radius: 16)
          : AppPressable(
              onTap: () => onOpen(items[index]),
              child: _NewsCard(item: items[index]),
            ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final HomeNewsItem item;

  @override
  Widget build(BuildContext context) {
    final tags = item.tags.take(3).toList();

    return RepaintBoundary(
      child: Container(
        height: 138,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            const Positioned(left: 16, top: 17.5, child: _NewsBadge()),
            Positioned(
              left: 55,
              top: 15,
              right: 14,
              child: Text(
                item.shortTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF0B081A),
                  fontWeight: AppFont.w500,
                  fontFamily: 'PingFang SC',
                  height: 1.375,
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 44.5,
              right: 16,
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6D6B75),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.43,
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 72.5,
              right: 16,
              height: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (int i = 0; i < tags.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tags[i],
                        style: TextStyle(
                          fontSize: 9.52,
                          color: Color(0xFF6D6B75),
                          fontWeight: AppFont.w400,
                          height: 1,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 16,
              top: 110.5,
              child: Opacity(
                opacity: 0.8,
                child: Text(
                  _formatTime(item.createTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF788698),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.36,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '刚刚';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    final days = diff.inDays;
    if (days < 30) return '$days天前';
    if (days < 365) return '${(days / 30).floor()}月前';
    return '${(days / 365).floor()}年前';
  }
}

class _NewsBadge extends StatelessWidget {
  const _NewsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF715EFE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white,
          height: 1,
          fontWeight: FontWeight.w500,
          fontFamily: 'Gilroy',
        ),
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

class _HomeLatestHeader extends StatelessWidget {
  const _HomeLatestHeader({required this.title, required this.onMoreTap});

  final String title;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    return SizedBox(
      width: double.infinity,
      height: ui(30),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: ui(20),
                color: Color(0xFF1A1A1A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
          GestureDetector(
            onTap: onMoreTap,
            child: Container(
              width: ui(58),
              height: ui(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  ui(ShellLayoutSpec.smallRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '更多',
                    style: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFFA9A9A9),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: ui(2)),
                  AppAssetGraphic(
                    AppAssets.shellV2MoreArrow,
                    width: ui(10),
                    height: ui(10),
                    fit: BoxFit.contain,
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
