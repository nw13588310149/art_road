// =============================================================================
// 任课老师 / 班主任端「考评管理」独立页面
//
// 入口：教师 dashboard 快捷区「考评管理」按钮 → controller.openExamReview()
//      → mainView == examReview + role == teacher/headTeacher → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 与「作业批改」(teacher_homework_review_view.dart) 共用同款双列骨架，
// 但只读语义（不可新建考试），并在视觉/数据上有以下差异：
//
//   1. 整页底色：#EFF3FC（区别于作业批改的默认浅灰）。
//   2. Banner（62 高，白→#F9EDFF 渐变）：左返回 / 居中标题 "考评管理" 16/600
//      + 副标题 12/400 #B6B5BB「列表展示已关联到您任教的月考科目；教师仅可
//      查看学生提交并进行评分与点评，不可新建考试。」/ 右上仅一个 "历史月考"
//      胶囊按钮（紫色钟铃图标 + 白底 1px #F3F2F3 边）。
//   3. 状态 tabs：全部 / 成绩未发布 / 成绩已发布。
//   4. 统计面板（真实班级筛选 + 6 项统计）：
//      6 项统计 = 待评分人次 / 关联考试科目 / 已评人次 / 已评均分 / 最高分 /
//      最低分。
//   5. 左侧考试列表卡（白卡 + 灰底 #F5F6FA / 选中态紫底 #F4F4FF）：每张卡
//      左下显示 28/16 Barlow N/M 提交比（如 4/11），随后是截止时间 / 班级 /
//      tag(2026年4月 月考 + 科目 + 待评(N) 11px) / 标题 16/500，顶部右侧
//      68×22 圆角左下右上"已截止/进行中"角标。
//   6. 右侧考试详情：标题 + 截止 + 12/12 紫色 #8741FF 同步说明行 +
//      灰底【教务月考要求】+ 4 项 _ProgressMetricCell（参与人数 / 未交人数 /
//      待评人数 / 已评人数）+ 学生提交表（同作业批改）。
//   7. 右抽屉：
//        · 历史月考（344 宽）：与 _HistoryDrawer 视觉一致，标题改为"历史月考"。
//        · 评分（600 宽）：与 _ReviewDrawer 同款表单，标题"评分"，附件标
//          媒体类型按学生提交（音频）+ 分数/100 + 点评对象 + 点评形态 +
//          评语；底部紫色渐变"提交评分" CTA。
//
// 颜色：白卡 / #F5F6FA / #F4F4FF / #F3F2F3 / #8741FF / #FF6A00 / #12CE51 /
//      #71717A 表头灰 / #B6B5BB 提示灰 / #EFF3FC 页底
// 字体：PingFang SC（10/11/12/13/14/16/600）+ Barlow（28 数值 + 16 分母）
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../courseware/ui/courseware_url_opener.dart';
import '../data/teacher_exam_data.dart';
import '../data/teacher_repository.dart';
import '../state/teacher_exam_controller.dart';
import '../../shell/ui/shell_layout.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'student_homework_submission_preview.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_empty_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ---- 配色 -------------------------------------------------------------------
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardBg = Colors.white;
const Color _kPageGrey = Color(0xFFF5F6FA);
const Color _kPickGrey = Color(0xFFF4F4FF);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextBlack = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextMuted = Color(0xFF71717A);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleEnd = Color(0xFFB68EFF);
const Color _kPurpleStart = Color(0xFF8640FF);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeBg = Color(0xFFFFEDD3);
const Color _kGreen = Color(0xFF12CE51);
const Color _kGreenBg = Color(0xFFE4FFED);
const Color _kPillIconColor = Color(0xFF1C274C);

/// 页面各板块之间的固定间距。
const double _kSectionGap = 14;

// ---- 数据模型 ---------------------------------------------------------------

enum _SubmissionState { passed, pending, missing, reviewed }

typedef _Submission = TeacherExamSubmission;
typedef _ExamItem = TeacherExamItem;
typedef _ExamOverviewStats = TeacherExamOverviewStats;
typedef _CornerKind = TeacherExamCornerKind;

extension _SubmissionStateCompat on TeacherExamSubmissionState {
  _SubmissionState get uiState => switch (this) {
    TeacherExamSubmissionState.passed => _SubmissionState.passed,
    TeacherExamSubmissionState.pending => _SubmissionState.pending,
    TeacherExamSubmissionState.missing => _SubmissionState.missing,
    TeacherExamSubmissionState.reviewed => _SubmissionState.reviewed,
  };
}

int _avatarSeedFor(String studentId, String studentName) {
  if (studentId.isNotEmpty) return studentId.hashCode.abs();
  return studentName.hashCode.abs();
}

String? _resolveMediaUrl(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final resolved = MediaUrl.resolve(trimmed);
  return resolved.isEmpty ? null : resolved;
}

String _fileNameFromPath(String path, String fallback) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return fallback;
  return segments.last;
}

// ---- 数据模型（UI 层复用 [TeacherExamSubmission] 等 API 模型）---------------

const List<String> _kStatusTabs = ['全部', '成绩未发布', '成绩已发布'];

// ---- 入口 view --------------------------------------------------------------

class TeacherExamReviewView extends ConsumerStatefulWidget {
  const TeacherExamReviewView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherExamReviewView> createState() =>
      _TeacherExamReviewViewState();
}

class _TeacherExamReviewViewState extends ConsumerState<TeacherExamReviewView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherExamControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final examState = ref.watch(teacherExamControllerProvider);
    final visibleItems = examState.visibleExams;
    final activeIdx = visibleItems.isEmpty
        ? 0
        : examState.activeIdx.clamp(0, visibleItems.length - 1);
    final active = visibleItems.isEmpty ? null : visibleItems[activeIdx];

    return SmartCampusSecondaryPageShell(
      backgroundColor: _kPageBg,
      bodyScrollable: false,
      bodyBorderRadius: 8,
      header: _ExamBanner(
        onBack: widget.onBack,
        onOpenHistory: _openHistoryDrawer,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusTabsRow(
            tabs: _kStatusTabs,
            activeIdx: examState.statusTab,
            onTap: (i) => ref
                .read(teacherExamControllerProvider.notifier)
                .selectStatusTab(i),
          ),
          SizedBox(height: ui(_kSectionGap)),
          _StatsPanel(
            stats: examState.overviewStats,
            classFilter: examState.classFilter,
            classOptions: examState.classOptions,
            onClassChanged: (value) => ref
                .read(teacherExamControllerProvider.notifier)
                .selectClass(value),
          ),
          SizedBox(height: ui(_kSectionGap)),
          Expanded(
            child: active == null
                ? Center(
                    child: Text(
                      examState.error.isNotEmpty
                          ? examState.error
                          : '暂无考试数据',
                      style: TextStyle(
                        color: _kTextHint,
                        fontSize: ui(14),
                      ),
                    ),
                  )
                : _BodyRow(
                    items: visibleItems,
                    activeIdx: activeIdx,
                    loadingDetail: examState.loadingDetail,
                    onSelect: (i) => ref
                        .read(teacherExamControllerProvider.notifier)
                        .selectExam(i),
                    active: active,
                    onOpenScore: (s) {
                      if (s.state == TeacherExamSubmissionState.missing) {
                        _remindStudent(active, s);
                      } else {
                        _openScoreDrawer(active, s);
                      }
                    },
                    onOpenSeatPlan: () => _openSeatPlanDrawer(active),
                  ),
          ),
        ],
      ),
    );
  }

  void _openHistoryDrawer() {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭历史月考',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _HistoryDrawer(
              items: ref.read(teacherExamControllerProvider).exams,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  void _openSeatPlanDrawer(_ExamItem item) {
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭考场安排',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _SeatPlanDrawer(examId: item.id, examTitle: item.title),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Future<void> _remindStudent(_ExamItem item, _Submission submission) async {
    final response = await ref
        .read(teacherExamControllerProvider.notifier)
        .remindStudent(
          examId: item.id,
          subjectId: item.subjectId,
          studentId: submission.studentId,
        );
    if (!mounted) return;
    AppToast.show(
      context,
      response.isSuccess ? '催交提醒已发送' : response.displayMsg,
      type: response.isSuccess ? AppToastType.success : AppToastType.error,
    );
  }

  void _openScoreDrawer(_ExamItem item, _Submission submission) {
    if (submission.state == TeacherExamSubmissionState.missing) return;
    final scale = DashboardScaleScope.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭评分',
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return Align(
          alignment: Alignment.centerRight,
          child: DashboardScaleScope(
            data: scale,
            child: _ScoreDrawer(
              item: item,
              submission: submission,
              onScored: () => ref
                  .read(teacherExamControllerProvider.notifier)
                  .refreshActiveExam(),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }
}

// =============================================================================
// 顶部 banner（白→#F9EDFF 渐变；左返回 + 居中标题/副标题 + 右"历史月考"按钮）
// =============================================================================

class _ExamBanner extends StatelessWidget {
  const _ExamBanner({required this.onBack, required this.onOpenHistory});

  final VoidCallback onBack;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: smartCampusPageBannerDecoration(ui),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                width: ui(32),
                height: ui(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: _kPillIconColor,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '考评管理',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: ui(2)),
                  Text(
                    '列表展示已关联到您任教的月考科目；教师仅可查看学生提交并进行评分与点评，不可新建考试。',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: ui(12),
            top: ui(15),
            child: _BannerActionButton(
              assetIcon: AppAssets.teacherExamHistoryIcon,
              label: '历史月考',
              onTap: onOpenHistory,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerActionButton extends StatelessWidget {
  const _BannerActionButton({
    this.icon,
    this.assetIcon,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || assetIcon != null);

  final IconData? icon;
  final String? assetIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(33),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetIcon != null)
              AppAssetGraphic(
                assetIcon!,
                width: ui(16),
                height: ui(16),
                fit: BoxFit.contain,
              )
            else
              Icon(icon, size: ui(16), color: _kPurple),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 状态 tabs（5 项）
// =============================================================================

class _StatusTabsRow extends StatelessWidget {
  const _StatusTabsRow({
    required this.tabs,
    required this.activeIdx,
    required this.onTap,
  });

  final List<String> tabs;
  final int activeIdx;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _StatusTabPill(
              label: tabs[i],
              active: i == activeIdx,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class _StatusTabPill extends StatelessWidget {
  const _StatusTabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        margin: EdgeInsets.symmetric(horizontal: ui(2)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            height: 1,
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 统计面板（班级筛选 + 累计/本学期/本月 + 6 张 stat 卡）
// =============================================================================

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.stats,
    required this.classFilter,
    required this.classOptions,
    required this.onClassChanged,
  });

  final _ExamOverviewStats stats;
  final String classFilter;
  final List<String> classOptions;
  final ValueChanged<String> onClassChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: ui(180),
                height: ui(42),
                child: PopupSelectorField<String>(
                  value: classFilter,
                  items: classOptions,
                  itemLabel: (s) => s,
                  onChanged: onClassChanged,
                  fieldHeight: 42,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(_kSectionGap)),
          Row(
            children: [
              Expanded(
                child: _StatCell(value: '${stats.pending}', label: '待评分人次'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: '${stats.subjects}', label: '关联考试科目'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: '${stats.reviewed}', label: '已评人次'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: stats.averageLabel, label: '已评均分'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: stats.maxLabel, label: '最高分'),
              ),
              const _StatGap(),
              Expanded(
                child: _StatCell(value: stats.minLabel, label: '最低分'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatGap extends StatelessWidget {
  const _StatGap();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(width: ui(_kSectionGap));
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: smartCampusStatValueTextStyle(ui),
          ),
          SizedBox(height: ui(2)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 主体双列：左 340 考试列表 + 右 615 考试详情 / 提交表
// =============================================================================

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.items,
    required this.activeIdx,
    required this.onSelect,
    required this.active,
    required this.onOpenScore,
    required this.onOpenSeatPlan,
    this.loadingDetail = false,
  });

  final List<_ExamItem> items;
  final int activeIdx;
  final ValueChanged<int> onSelect;
  final _ExamItem active;
  final ValueChanged<_Submission> onOpenScore;
  final VoidCallback onOpenSeatPlan;
  final bool loadingDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: ui(340),
          child: _ExamListPanel(
            items: items,
            activeIdx: activeIdx,
            onSelect: onSelect,
          ),
        ),
        SizedBox(width: ui(_kSectionGap)),
        Expanded(
          child: loadingDetail
              ? Container(
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(ui(16)),
                  ),
                  alignment: Alignment.center,
                  child: AppLoadingIndicator(),
                )
              : _ExamDetailPanel(
                  item: active,
                  onOpenScore: onOpenScore,
                  onOpenSeatPlan: onOpenSeatPlan,
                ),
        ),
      ],
    );
  }
}

// ---- 左侧考试列表 -----------------------------------------------------------

class _ExamListPanel extends StatelessWidget {
  const _ExamListPanel({
    required this.items,
    required this.activeIdx,
    required this.onSelect,
  });

  final List<_ExamItem> items;
  final int activeIdx;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: ui(4)),
            child: Text(
              '考试列表',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextBlack,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(height: ui(8)),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) SizedBox(height: ui(8)),
                    _ExamListCard(
                      item: items[i],
                      active: i == activeIdx,
                      onTap: () => onSelect(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamListCard extends StatelessWidget {
  const _ExamListCard({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _ExamItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = active ? _kPickGrey : _kPageGrey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: ui(104)),
            padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.publishedRatio.submitted}',
                      style: TextStyle(
                        fontSize: ui(28),
                        color: _kTextDark,
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: ui(2)),
                    Padding(
                      padding: EdgeInsets.only(bottom: ui(4)),
                      child: Text(
                        '/${item.publishedRatio.total}',
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kTextHint,
                          fontFamily: 'Barlow',
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ui(2)),
                Text(
                  '截止 ${item.deadline}',
                  style: TextStyle(
                    fontSize: ui(10),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  item.classLabel,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: ui(6)),
                Row(
                  children: [
                    _SubjectTag(label: item.examLabel),
                    SizedBox(width: ui(4)),
                    _SubjectTag(label: item.subject),
                    SizedBox(width: ui(4)),
                    if (item.pendingReview > 0)
                      _PendingReviewTag(count: item.pendingReview),
                  ],
                ),
                SizedBox(height: ui(6)),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextBlack,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _CornerLabel(label: item.cornerLabel, kind: item.cornerKind),
          ),
        ],
      ),
    );
  }
}

class _SubjectTag extends StatelessWidget {
  const _SubjectTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(11),
          color: _kTextHint,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

class _PendingReviewTag extends StatelessWidget {
  const _PendingReviewTag({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: _kOrangeBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        '待评($count)',
        style: TextStyle(
          fontSize: ui(11),
          color: _kOrange,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

class _CornerLabel extends StatelessWidget {
  const _CornerLabel({required this.label, required this.kind});

  final String label;
  final _CornerKind kind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final bg = kind == TeacherExamCornerKind.published
        ? const Color(0xFFE6E9F1)
        : _kOrangeBg;
    final fg = kind == TeacherExamCornerKind.published ? _kTextHint : _kOrange;
    return Container(
      height: ui(22),
      padding: EdgeInsets.symmetric(horizontal: ui(10)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(ui(12)),
          bottomLeft: Radius.circular(ui(12)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

// ---- 右侧考试详情 + 4 项指标 + 学生表格 -------------------------------------

class _ExamDetailPanel extends StatelessWidget {
  const _ExamDetailPanel({
    required this.item,
    required this.onOpenScore,
    required this.onOpenSeatPlan,
  });

  final _ExamItem item;
  final ValueChanged<_Submission> onOpenScore;
  final VoidCallback onOpenSeatPlan;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: ui(16),
                            color: _kTextBlack,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(width: ui(12)),
                      _BannerActionButton(
                        assetIcon: AppAssets.teacherExamSeatPlanIcon,
                        label: '考场安排',
                        onTap: onOpenSeatPlan,
                      ),
                      SizedBox(width: ui(12)),
                      Text(
                        '截止 ${item.deadline}',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextSecondary,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ui(8)),
                  Text(
                    item.syncNote,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kPurple,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: ui(_kSectionGap)),
                  _OfficialBlock(description: item.officialDesc),
                  SizedBox(height: ui(_kSectionGap)),
                  _ProgressMetrics(item: item),
                  if (item.hasScoreSummary) ...[
                    SizedBox(height: ui(_kSectionGap)),
                    _ScoreSummaryStrip(item: item),
                  ],
                  SizedBox(height: ui(_kSectionGap)),
                  _SubmissionsTable(
                    submissions: item.submissions,
                    onOpenScore: onOpenScore,
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

class _OfficialBlock extends StatelessWidget {
  const _OfficialBlock({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '【教务月考要求】',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.6,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            description,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetrics extends StatelessWidget {
  const _ProgressMetrics({required this.item});

  final _ExamItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _ProgressMetricCell(
            label: '参与人数',
            value: '${item.attended}',
            icon: Icons.people_alt_rounded,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '未交人数',
            value: '${item.unsubmitted}',
            icon: Icons.person_off_rounded,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '待评人数',
            value: '${item.pendingReview}',
            icon: Icons.fact_check_outlined,
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: _ProgressMetricCell(
            label: '已评人数',
            value: '${item.reviewed}',
            icon: Icons.task_alt_rounded,
          ),
        ),
      ],
    );
  }
}

class _ProgressMetricCell extends StatelessWidget {
  const _ProgressMetricCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(width: ui(4)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(6)),
          Container(
            width: ui(28),
            height: ui(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kTextDark, _kPurple],
              ),
              borderRadius: BorderRadius.circular(ui(6)),
            ),
            child: Icon(icon, size: ui(16), color: _kPageGrey),
          ),
        ],
      ),
    );
  }
}

/// 成绩聚合条：已评后展示均分 / 最高 / 最低 / 及格率 / 优秀率。
/// 数据来自 `examStudentStat`（此前被丢弃，现按设计语言可视化）。
class _ScoreSummaryStrip extends StatelessWidget {
  const _ScoreSummaryStrip({required this.item});

  final _ExamItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(1);
    final cells = <({String label, String value, Color color})>[
      (label: '均分', value: fmt(item.avgScore), color: _kPurple),
      (label: '最高', value: fmt(item.maxScore), color: _kGreen),
      (label: '最低', value: fmt(item.minScore), color: _kOrange),
      if (item.passRate.isNotEmpty)
        (label: '及格率', value: item.passRate, color: _kGreen),
      if (item.excellentRate.isNotEmpty)
        (label: '优秀率', value: item.excellentRate, color: _kPurple),
    ];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFF7F3FF), Color(0xFFFCFAFF)],
        ),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kPurple.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: ui(22),
                color: _kPurple.withValues(alpha: 0.1),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cells[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(16),
                      color: cells[i].color,
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: ui(3)),
                  Text(
                    cells[i].label,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextSecondary,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 考场安排右抽屉（examFullDetail → 全部学生座位，按教室分组）
// =============================================================================

class _SeatPlanDrawer extends ConsumerStatefulWidget {
  const _SeatPlanDrawer({required this.examId, required this.examTitle});

  final String examId;
  final String examTitle;

  @override
  ConsumerState<_SeatPlanDrawer> createState() => _SeatPlanDrawerState();
}

class _SeatPlanDrawerState extends ConsumerState<_SeatPlanDrawer> {
  bool _loading = true;
  String _error = '';
  List<TeacherExamSeatEntry> _seats = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final res = await ref
        .read(teacherRepositoryProvider)
        .examFullDetail(examId: widget.examId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess) {
        _seats = parseTeacherExamSeats(res.data);
      } else {
        _error = res.displayMsg.isNotEmpty ? res.displayMsg : '考场安排加载失败';
      }
    });
  }

  /// 按教室分组：已编排教室在前（按名称），未编排归入末尾「待编排」；
  /// 同一考场内同一考生多科目座位合并为一条。
  List<({String room, List<TeacherExamSeatGroupEntry> students})> _grouped() {
    final map = <String, List<TeacherExamSeatEntry>>{};
    for (final s in _seats) {
      final key = s.classroomName.isNotEmpty ? s.classroomName : '';
      map.putIfAbsent(key, () => []).add(s);
    }
    final keys = map.keys.toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return a.compareTo(b);
      });
    return [
      for (final k in keys)
        (
          room: k.isEmpty ? '待编排考场' : k,
          students: () {
            final grouped = groupTeacherExamSeatsByStudent(map[k]!);
            grouped.sort((a, b) {
              final sa = a.seatNo ?? 1 << 30;
              final sb = b.seatNo ?? 1 << 30;
              if (sa != sb) return sa.compareTo(sb);
              return a.studentNo.compareTo(b.studentNo);
            });
            return grouped;
          }(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: ui(420),
        height: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DrawerTitleBar(title: '考场安排'),
              SizedBox(height: ui(6)),
              Text(
                widget.examTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
              SizedBox(height: ui(16)),
              Container(height: 1, color: _kBorderSoft),
              SizedBox(height: ui(12)),
              Expanded(child: _buildBody(ui)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double Function(double) ui) {
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: SmartCampusEmptyState(
          icon: Icons.cloud_off_rounded,
          title: '考场安排加载失败',
          subtitle: _error,
          actionLabel: '重新加载',
          onAction: _load,
        ),
      );
    }
    if (_seats.isEmpty) {
      return const Center(
        child: SmartCampusEmptyState(
          icon: Icons.event_seat_outlined,
          title: '暂未编排考场',
          subtitle: '教务完成本场考试的考场与座位编排后，将在此展示全部考生座位。',
        ),
      );
    }
    final groups = _grouped();
    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, _) => SizedBox(height: ui(16)),
      itemBuilder: (_, i) =>
          _SeatRoomGroup(room: groups[i].room, students: groups[i].students),
    );
  }
}

class _SeatRoomGroup extends StatelessWidget {
  const _SeatRoomGroup({required this.room, required this.students});

  final String room;
  final List<TeacherExamSeatGroupEntry> students;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.meeting_room_outlined, size: ui(16), color: _kPurple),
              SizedBox(width: ui(6)),
              Expanded(
                child: Text(
                  room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.2,
                  ),
                ),
              ),
              Text(
                '${students.length}人',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          for (var i = 0; i < students.length; i++) ...[
            if (i > 0) SizedBox(height: ui(6)),
            _SeatStudentRow(entry: students[i]),
          ],
        ],
      ),
    );
  }
}

class _SeatStudentRow extends StatelessWidget {
  const _SeatStudentRow({required this.entry});

  final TeacherExamSeatGroupEntry entry;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          _AvatarCircle(
            name: entry.studentName,
            seed: _avatarSeedFor(entry.studentId, entry.studentName),
            size: 28,
          ),
          SizedBox(width: ui(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
                if (entry.studentNo.isNotEmpty ||
                    entry.className.isNotEmpty) ...[
                  SizedBox(height: ui(2)),
                  Text(
                    [
                      if (entry.studentNo.isNotEmpty) '学号 ${entry.studentNo}',
                      if (entry.className.isNotEmpty) entry.className,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ],
                if (entry.subjectNames.isNotEmpty) ...[
                  SizedBox(height: ui(2)),
                  Text(
                    '科目 ${entry.subjectNames.join('、')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kPurple,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          if (entry.seatNo != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
              decoration: BoxDecoration(
                color: _kPickGrey,
                borderRadius: BorderRadius.circular(ui(6)),
              ),
              child: Text(
                '${entry.seatNo}号',
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kPurple,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            )
          else
            Text(
              '待编排',
              style: TextStyle(
                fontSize: ui(11),
                color: _kTextHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }
}

// ---- 学生提交表格 -----------------------------------------------------------

class _SubmissionsTable extends StatelessWidget {
  const _SubmissionsTable({
    required this.submissions,
    required this.onOpenScore,
  });

  final List<_Submission> submissions;
  final ValueChanged<_Submission> onOpenScore;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: ui(40),
          padding: EdgeInsets.symmetric(horizontal: ui(8)),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            children: const [
              SizedBox(width: 90 + 4, child: _ColHeader('学生')),
              Expanded(child: _ColHeader('状态')),
              Expanded(child: _ColHeader('科目')),
              Expanded(child: _ColHeader('介质')),
              Expanded(child: _ColHeader('上传时间')),
              SizedBox(width: 80, child: _ColHeader('操作')),
            ],
          ),
        ),
        for (final s in submissions)
          _SubmissionRow(item: s, onOpenScore: () => onOpenScore(s)),
      ],
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextMuted,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1.4,
      ),
    );
  }
}

class _SubmissionRow extends ConsumerWidget {
  const _SubmissionRow({required this.item, required this.onOpenScore});

  final _Submission item;
  final VoidCallback onOpenScore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;
    final isMissing = item.state == TeacherExamSubmissionState.missing;
    final isReminding =
        ref.watch(teacherExamControllerProvider).remindingStudentId ==
        item.studentId;
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(12)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorderSoft, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: ui(94),
            child: Row(
              children: [
                _AvatarCircle(
                  name: item.studentName,
                  seed: _avatarSeedFor(item.studentId, item.studentName),
                  imageUrl: item.avatarUrl,
                ),
                SizedBox(width: ui(4)),
                Flexible(
                  child: Text(
                    item.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(child: _StatusPill(state: item.state.uiState)),
          Expanded(child: _CellText(item.subject)),
          Expanded(child: _CellText(item.medium)),
          Expanded(child: _CellText(item.uploadAt)),
          SizedBox(
            width: ui(90),
            child: InkWell(
              onTap: isReminding ? null : onOpenScore,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                height: ui(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isMissing ? _kOrangeBg : _kTextDark,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: isMissing
                      ? Border.all(color: _kOrange.withValues(alpha: 0.35))
                      : null,
                ),
                child: Text(
                  isMissing && isReminding ? '发送中…' : item.action,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: isMissing ? _kOrange : Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1.4,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final _SubmissionState state;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final ({Color bg, Color fg, String text}) tone = switch (state) {
      _SubmissionState.passed => (bg: _kGreenBg, fg: _kGreen, text: '已通过'),
      _SubmissionState.pending => (bg: _kOrangeBg, fg: _kOrange, text: '待评'),
      _SubmissionState.missing => (
        bg: const Color(0xFFFFE5E5),
        fg: const Color(0xFFE54848),
        text: '未交',
      ),
      _SubmissionState.reviewed => (bg: _kGreenBg, fg: _kGreen, text: '已批改'),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(ui(4)),
        ),
        child: Text(
          tone.text,
          style: TextStyle(
            fontSize: ui(12),
            color: tone.fg,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.name,
    required this.seed,
    this.size = 32,
    this.imageUrl,
  });

  final String name;
  final int seed;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final resolved = _resolveMediaUrl(imageUrl);
    final palettes = const [
      [Color(0xFFB68EFF), Color(0xFF8741FF)],
      [Color(0xFFFFB68E), Color(0xFFFF8741)],
      [Color(0xFF8EE0FF), Color(0xFF418EFF)],
    ];
    final palette = palettes[seed.abs() % palettes.length];
    final initial = name.isNotEmpty ? name.characters.first : '?';
    if (resolved != null) {
      return ClipOval(
        child: Image.network(
          resolved,
          width: ui(size),
          height: ui(size),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: ui(size),
            height: ui(size),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: ui(13),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: ui(size),
      height: ui(size),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(13),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 历史月考右抽屉（344 宽，与作业批改"历史发布记录"同款视觉）
// =============================================================================

class _HistoryDrawer extends StatelessWidget {
  const _HistoryDrawer({required this.items});

  final List<_ExamItem> items;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: ui(344),
        height: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(ui(16), ui(20), ui(16), ui(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: ui(3.25),
                    height: ui(14.85),
                    decoration: BoxDecoration(
                      color: _kPurple,
                      borderRadius: BorderRadius.circular(ui(6)),
                    ),
                  ),
                  SizedBox(width: ui(4)),
                  Text(
                    '历史月考',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Padding(
                    padding: EdgeInsets.only(top: ui(4)),
                    child: Text(
                      '共${items.length}条',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(20)),
              Container(height: 1, color: _kBorderSoft),
              SizedBox(height: ui(12)),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: SmartCampusEmptyState(
                          icon: Icons.history_rounded,
                          title: '暂无历史月考',
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                        itemBuilder: (ctx, i) => _HistoryCard(item: items[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final _ExamItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: ui(104)),
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.publishedRatio.submitted}',
                style: TextStyle(
                  fontSize: ui(28),
                  color: _kTextDark,
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              SizedBox(width: ui(2)),
              Padding(
                padding: EdgeInsets.only(bottom: ui(4)),
                child: Text(
                  '/${item.publishedRatio.total}',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextHint,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(2)),
          Text(
            '截止 ${item.deadline}',
            style: TextStyle(
              fontSize: ui(10),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            item.classLabel,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(6)),
          Row(
            children: [
              _SubjectTag(label: item.examLabel),
              SizedBox(width: ui(4)),
              _SubjectTag(label: item.subject),
            ],
          ),
          SizedBox(height: ui(6)),
          Text(
            item.title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextBlack,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 评分右抽屉（600 宽，与作业批改"作业点评"同款表单）
// =============================================================================

class _ScoreDrawer extends ConsumerStatefulWidget {
  const _ScoreDrawer({
    required this.item,
    required this.submission,
    required this.onScored,
  });

  final _ExamItem item;
  final _Submission submission;
  final Future<void> Function() onScored;

  @override
  ConsumerState<_ScoreDrawer> createState() => _ScoreDrawerState();
}

class _ScoreDrawerState extends ConsumerState<_ScoreDrawer> {
  late final TextEditingController _scoreCtrl;
  late final TextEditingController _commentCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _scoreCtrl = TextEditingController(
      text: widget.submission.score?.toString() ?? '',
    );
    _commentCtrl = TextEditingController(text: widget.submission.comment);
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final files = widget.submission.submitFiles.isNotEmpty
        ? widget.submission.submitFiles
        : (widget.submission.path.trim().isNotEmpty
              ? <String>[widget.submission.path]
              : const <String>[]);
    final hasAttachment = files.isNotEmpty;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: ui(600),
        height: double.infinity,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(20), ui(80)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DrawerTitleBar(title: '评分'),
                    SizedBox(height: ui(20)),
                    Container(height: 1, color: _kBorderSoft),
                    SizedBox(height: ui(16)),
                    _ScoreProfileRow(
                      submission: widget.submission,
                      item: widget.item,
                    ),
                    SizedBox(height: ui(16)),
                    if (hasAttachment)
                      for (var i = 0; i < files.length; i++) ...[
                        if (i > 0) SizedBox(height: ui(10)),
                        _attachmentCardFor(files[i], i, files.length),
                      ]
                    else
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(12),
                          vertical: ui(10),
                        ),
                        decoration: BoxDecoration(
                          color: _kPageGrey,
                          borderRadius: BorderRadius.circular(ui(8)),
                        ),
                        child: Text(
                          '该学生尚未提交考试文件',
                          style: TextStyle(
                            fontSize: ui(13),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.4,
                          ),
                        ),
                      ),
                    SizedBox(height: ui(20)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '评分与点评',
                          style: TextStyle(
                            fontSize: ui(16),
                            color: _kTextDark,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w600,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(width: ui(12)),
                        Expanded(
                          child: Container(height: 1, color: _kBorderSoft),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(16)),
                    _FieldLabel('分数/100'),
                    SizedBox(height: ui(8)),
                    _ScoreInput(controller: _scoreCtrl),
                    SizedBox(height: ui(16)),
                    _FieldLabel('评语（选填）'),
                    SizedBox(height: ui(8)),
                    _PlainTextArea(
                      hint: '请输入对该次考试的评分依据与点评内容…',
                      height: ui(96),
                      controller: _commentCtrl,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: ui(20),
              right: ui(20),
              bottom: ui(20),
              child: _PrimaryGradientButton(
                icon: Icons.check_circle_outline_rounded,
                label: _submitting
                    ? '提交中...'
                    : (widget.submission.state ==
                              TeacherExamSubmissionState.reviewed
                          ? '更新评分'
                          : '提交评分'),
                onTap: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (widget.submission.hasNoSubmission) {
      AppToast.show(context, '该学生尚未提交作品，请先催交', type: AppToastType.error);
      return;
    }
    final score = num.tryParse(_scoreCtrl.text.trim());
    if (score == null || score < 0 || score > 100) {
      AppToast.show(context, '请输入 0-100 的分数', type: AppToastType.error);
      return;
    }
    if (widget.item.id.isEmpty ||
        widget.item.subjectId == 0 ||
        widget.submission.studentId.isEmpty) {
      AppToast.show(context, '考试或学生信息不完整', type: AppToastType.error);
      return;
    }
    setState(() => _submitting = true);
    final response = await ref
        .read(teacherExamControllerProvider.notifier)
        .submitScore(
          examId: widget.item.id,
          subjectId: widget.item.subjectId,
          studentId: widget.submission.studentId,
          score: score,
          comment: _commentCtrl.text.trim(),
          path: widget.submission.path,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!response.isSuccess) {
      AppToast.show(context, response.displayMsg, type: AppToastType.error);
      return;
    }
    AppToast.show(context, '评分提交成功', type: AppToastType.success);
    await widget.onScored();
    if (mounted) Navigator.of(context).maybePop();
  }

  /// 单个上传文件的附件卡（在线科目可多次提交，逐个查看 / 播放）。
  Widget _attachmentCardFor(String rawPath, int index, int total) {
    final url = _resolveMediaUrl(rawPath) ?? '';
    final medium = teacherSubmitMediaLabel(rawPath);
    final baseName = _fileNameFromPath(
      rawPath,
      '${widget.submission.studentName}_${widget.item.title}.${_extOf(medium)}',
    );
    final label = total > 1 ? '第${index + 1}次 · $baseName' : baseName;
    return _AttachmentCard(
      filename: label,
      medium: medium,
      onPreview: () => showStudentHomeworkSubmissionPreview(
        context,
        ref: ref,
        fileUrl: url,
        title: baseName,
        typeTag: medium,
        mediumLabel: medium,
        attachmentName: baseName,
      ),
      onDownload: () => openCoursewareUrl(url),
    );
  }

  String _extOf(String medium) {
    switch (medium) {
      case '音频':
        return 'mp3';
      case '视频':
        return 'mp4';
      case '图片':
        return 'jpg';
      default:
        return 'pdf';
    }
  }
}

class _ScoreProfileRow extends StatelessWidget {
  const _ScoreProfileRow({required this.submission, required this.item});

  final _Submission submission;
  final _ExamItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AvatarCircle(
          name: submission.studentName,
          seed: _avatarSeedFor(submission.studentId, submission.studentName),
          size: 40,
          imageUrl: submission.avatarUrl,
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      submission.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: Colors.black,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  _StatusPill(state: submission.state.uiState),
                ],
              ),
              SizedBox(height: ui(4)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      submission.studentNo.isNotEmpty
                          ? '学号 ${submission.studentNo} · ${item.subject}'
                          : '${item.examLabel} · ${item.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Text(
                    submission.uploadAt,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.filename,
    required this.medium,
    required this.onPreview,
    required this.onDownload,
  });

  final String filename;
  final String medium;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final iconColors = switch (medium) {
      '音频' => const [Color(0xFFFFE3D7), Color(0xFFFFF8F4)],
      '视频' => const [Color(0xFFD7FFE9), Color(0xFFF4FFF8)],
      '图片' => const [Color(0xFFFFF1D7), Color(0xFFFFFCF4)],
      _ => const [Color(0xFFD7E2FF), Color(0xFFF9FBFF)],
    };
    final tagColor = switch (medium) {
      '音频' => const Color(0xFFFF8741),
      '视频' => const Color(0xFF12CE51),
      '图片' => const Color(0xFFE68D10),
      _ => const Color(0xFFFF5040),
    };
    final tagText = switch (medium) {
      '音频' => 'MP3',
      '视频' => 'MP4',
      '图片' => 'JPG',
      _ => 'PDF',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kPageGrey,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Container(
            width: ui(40),
            height: ui(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: iconColors,
              ),
              borderRadius: BorderRadius.circular(ui(8)),
              border: Border.all(color: const Color(0xFFE5EFFF)),
            ),
            alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(ui(2)),
              ),
              child: Text(
                tagText,
                style: TextStyle(
                  fontSize: ui(8),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(8)),
          _GhostButton(
            icon: Icons.file_download_outlined,
            label: '下载',
            onTap: onDownload,
          ),
          SizedBox(width: ui(8)),
          _GhostButton(
            icon: medium == '音频'
                ? Icons.headphones_rounded
                : Icons.remove_red_eye_outlined,
            label: medium == '音频' ? '试听' : '在线预览',
            onTap: onPreview,
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          height: ui(33),
          padding: EdgeInsets.symmetric(horizontal: ui(12)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: ui(14), color: _kPillIconColor),
              SizedBox(width: ui(4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreInput extends StatelessWidget {
  const _ScoreInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kPageGrey),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '请输入分数',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                ),
              ),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
          Text(
            ' / 100',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 抽屉里通用零件
// =============================================================================

class _DrawerTitleBar extends StatelessWidget {
  const _DrawerTitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: _kPurple,
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(4)),
        Text(
          title,
          style: TextStyle(
            fontSize: ui(16),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: Colors.black,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1.4,
      ),
    );
  }
}

class _PlainTextArea extends StatefulWidget {
  const _PlainTextArea({
    required this.hint,
    required this.height,
    this.controller,
  });

  final String hint;
  final double height;
  final TextEditingController? controller;

  @override
  State<_PlainTextArea> createState() => _PlainTextAreaState();
}

class _PlainTextAreaState extends State<_PlainTextArea> {
  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) {
      _ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: widget.height,
      padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kPageGrey),
      ),
      child: AppTextField(
        controller: _ctrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.4,
        ),
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(48),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [_kPurpleEnd, _kPurpleStart],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: ui(16), color: Colors.white),
            SizedBox(width: ui(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
