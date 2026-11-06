// =============================================================================
// 学生端「我的考试」独立页面
//
// 入口：学生 dashboard 快捷区「我的考试」按钮 → controller.openMyGrades()
//      → mainView == myGrades + role == student → SmartCampusPage 路由到
//      本视图。返回：banner 左上角返回按钮 → onBack。
//
// 顶部主 tab：
//   · 「全部考试」：所有考试（含未开始）的安排列表。点击考试 → 右侧抽屉
//     （上方本次考试信息，下方科目与座位），**按科目区分在线 / 离线**
//     （对齐机构管理端新建考试时按科目设置形式）：
//       - 离线科目：展示「时间 + 考场 + 座位」，无需上传；
//       - 在线科目（且考试正在进行）：学生自录上传视频 / 音频，最多 2 次，并展示提交状态
//         （未开放 / 待提交 / 已提交 X/2·可重传 / 次数用完 / 已截止·未提交）。
//     一场考试可同时含在线与离线科目（混合）。当前后端无「全部考试」列表与在线
//     提交接口，使用 student_exam_schedule_data 的模拟数据；文件选择走真实系统
//     选择器，提交结果暂存本地（待接口接入；科目在线/离线字段以建考接口为准）。
//   · 「我的成绩」：成绩与排名（examOverview + examRecordList 真实接口），即原页面。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 渐变，左 32 返回 + 中标题
//      "成绩与排名" 16px 600，右侧 "本学期/上学期" 双 tab pills（44 高
//      白色容器 + #F3F2F3 描边，激活态 #0B081A 黑底 / 白字）。
//   2. 4 张 100 高统计卡（一行平铺，gap 12）：
//      A. 白底「学年考试均分」14 + 数值 32 + 进度条（86/118 紫色填充）
//         + 灰小字 "各次月考/大考总均分平均"
//      B. 紫渐变「最近班级」14 + 数值 32 + "/42" + 紫"持平"tag（横线图标）
//      C. 绿渐变「最近年级」14 + 数值 32 + "/368" + 绿"上升3名"tag（上升箭头）
//      D. 白底「本学期最佳考试」14 + 紫色 20px "六月摸底考试" + 紫底
//         "均分 91分" tag
//   3. 双列卡：
//      左 640「6次考试 折线趋势」（496 高白卡）：
//         · 顶部科目 tabs（总均分 / 主项 / 副项 / 听写 / 乐理 / 视唱）
//         · 左 Y 轴标签 100/95/90/85/80/0（80→0 用一段压缩刻度）
//         · 6 个数据点（86/87/86.5/91/93/90），紫线 + 紫渐变填充
//         · 每点上方紫色数值标签
//         · 底部 X 轴 6 个月份标签（2月 / 3月 / 4月 / 5月 / 期中 / 6月）
//         · 下方"每场·总成绩排名 (班级/全校)" + 6 列紧凑统计单元
//      右 318「场次均分分布」（496 高白卡）：5 段灰底面板，
//         区间标签 + 占比% + 紫色渐变进度条 + 右下"X场"
//   4. 「考试记录与各科成绩」2 列 × 多行卡片网格（每张 477 宽）：
//      - 表头：「X月月考」16 + 日期灰字 + 折叠图标按钮
//      - 5 项一排统计 (12px)：总均分 / 及格科数 / 优秀科数 / 班级排名 / 全校排名
//      - 展开态：4 张科目子卡（声乐紫 / 器乐紫 / 视唱绿 / 乐理绿），
//        含 老师名 + 科目 tag + 班/全校排名 + 教师评语 + 录像/录音/无录制
//        tag + 蓝色右上角分数 + "查看详情"按钮
//      - 折叠态：仅头 + 统计行
//
// 颜色：白卡 / #F5F6FA 浅灰 / #8741FF 主紫 / #325BFF 蓝（科目分数）
//      / #0CAC40 绿 / #DFFCF0 绿底（视唱/乐理 tag） / #EAE5FF 紫底（声乐/器乐）
//      / #12CE51 上升绿 / #F4F4FF 进度条底 / #E2D0FF→#8741FF 进度条渐变
// 字体：PingFang SC（中文） + Barlow（数字 32 / 20）
// =============================================================================

import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/ui/shell_layout.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../../core/widgets/segment_toggle.dart';
import '../../../core/widgets/smooth_circle_network_avatar.dart';
import '../../courseware/state/cloud_drive_controller.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../data/student_academic_data.dart';
import '../data/student_exam_schedule_data.dart';
import '../data/student_repository.dart';
import 'student_homework_submission_preview.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_empty_state.dart';

const Color _kCardBg = Colors.white;
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kBorderHair = Color(0xFFE6E9F1);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleLight = Color(0xFFA773FF);
const Color _kPurpleSoftBg = Color(0xFFEAE5FF);
const Color _kPurpleBestBg = Color(0xFFF7F2FF);
const Color _kProgressBg = Color(0xFFF4F4FF);
const Color _kBlueScore = Color(0xFF325BFF);
const Color _kSubjectGreen = Color(0xFF0CAC40);
const Color _kSubjectGreenBg = Color(0xFFDFFCF0);
const Color _kRiseGreen = Color(0xFF12CE51);
const Color _kFallRed = Color(0xFFF04545);
const Color _kAxisLabel = Color(0xFFB6B5BB);

/// 标题栏右侧主切换控件统一高度（与查寝管理页一致）。
const double _kBannerControlHeight = 32;

// =============================================================================
// 顶级视图
// =============================================================================

class StudentMyGradesView extends ConsumerStatefulWidget {
  const StudentMyGradesView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StudentMyGradesView> createState() =>
      _StudentMyGradesViewState();
}

class _StudentMyGradesViewState extends ConsumerState<StudentMyGradesView> {
  _MainTab _mainTab = _MainTab.exams;
  _SemesterTab _semester = _SemesterTab.current;
  _ExamFilter _filter = _ExamFilter.all;
  StudentExamOverview? _overview;
  List<_ExamRecordData> _records = const [];
  List<StudentExamScheduleItem> _exams = const [];
  bool _loading = true;
  bool _examsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExams();
      _loadGrades();
    });
  }

  /// 拉取「全部考试」列表（`myExamList` tab=0 全部；待考/已考在前端按状态筛选）。
  Future<void> _loadExams() async {
    if (mounted) setState(() => _examsLoading = true);
    final res = await ref.read(studentRepositoryProvider).myExamList();
    if (!mounted) return;
    setState(() {
      _examsLoading = false;
      if (res.isSuccess) {
        _exams = parseStudentExamList(res.data);
      }
    });
  }

  Future<void> _loadGrades() async {
    final repository = ref.read(studentRepositoryProvider);
    final responses = await Future.wait([
      repository.examOverview(),
      repository.examRecordList(),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (responses[0].isSuccess) {
        _overview = StudentExamOverview.fromData(responses[0].data);
      }
      if (responses[1].isSuccess && responses[1].data is List) {
        _records = (responses[1].data as List)
            .whereType<Map<dynamic, dynamic>>()
            .map(StudentExamRecord.fromMap)
            .map(_examRecordFromApi)
            .toList(growable: false);
      }
    });
  }

  /// 当前学期序号：取已公布成绩中最新一场所在的学期（无数据时用今天）。
  int get _currentSemesterIndex {
    final indices = _records
        .map((r) => _semesterIndexOfDate(r.date))
        .where((i) => i >= 0);
    if (indices.isEmpty) return _semesterIndex(DateTime.now());
    return indices.reduce(math.max);
  }

  /// 按「本学期 / 上学期」筛选成绩记录；日期无法解析的记录归入本学期。
  List<_ExamRecordData> get _visibleRecords {
    if (_records.isEmpty) return const [];
    final target = _semester == _SemesterTab.current
        ? _currentSemesterIndex
        : _currentSemesterIndex - 1;
    return _records
        .where((r) {
          final idx = _semesterIndexOfDate(r.date);
          if (idx < 0) return _semester == _SemesterTab.current;
          return idx == target;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final visibleRecords = _visibleRecords;
    return SmartCampusSecondaryPageShell(
      backgroundColor: _kPageBg,
      header: _ExamPageBanner(
        onBack: widget.onBack,
        selected: _mainTab,
        onSelected: (v) => setState(() => _mainTab = v),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_mainTab == _MainTab.exams)
            _AllExamsSection(
              exams: _exams,
              filter: _filter,
              loading: _examsLoading,
              onFilterChanged: (v) => setState(() => _filter = v),
              onRefresh: _loadExams,
            )
          else ...[
            _GradesSemesterHeader(
              selected: _semester,
              onSelected: (v) => setState(() => _semester = v),
            ),
            SizedBox(height: ui(12)),
            _GradesStatsRow(overview: _overview),
            SizedBox(height: ui(16)),
            _DualPanelRow(overview: _overview),
            SizedBox(height: ui(16)),
            _ExamRecordsSection(
              records: visibleRecords,
              loading: _loading && _records.isEmpty,
              filteredEmpty: _records.isNotEmpty && visibleRecords.isEmpty,
            ),
          ],
        ],
      ),
    );
  }
}

/// 学期序号（连续整数，用于「本学期 / 上学期」对比）：
/// 春季学期(2-8 月) = year*2；秋季学期(9-12 月及次年 1 月) = year*2+1。
int _semesterIndex(DateTime d) {
  if (d.month >= 9) return d.year * 2 + 1;
  if (d.month <= 1) return (d.year - 1) * 2 + 1;
  return d.year * 2;
}

int _semesterIndexOfDate(String date) {
  final d = DateTime.tryParse(date.trim());
  return d == null ? -1 : _semesterIndex(d);
}

// =============================================================================
// Banner：返回 / 标题 / 主 tabs（全部考试 / 我的成绩）
// =============================================================================

enum _SemesterTab { current, previous }

/// 页面主切换：全部考试（考试安排 + 科目 + 座位）/ 我的成绩（成绩与排名）。
enum _MainTab { exams, grades }

/// 「全部考试」列表筛选。
enum _ExamFilter { all, pending, done }

class _ExamPageBanner extends StatelessWidget {
  const _ExamPageBanner({
    required this.onBack,
    required this.selected,
    required this.onSelected,
  });

  final VoidCallback onBack;
  final _MainTab selected;
  final ValueChanged<_MainTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: smartCampusPageBannerDecoration(ui),
      child: Row(
        children: [
          _BackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                '我的考试',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1,
                ),
              ),
            ),
          ),
          _MainTabs(selected: selected, onSelected: onSelected),
        ],
      ),
    );
  }
}

class _MainTabs extends StatelessWidget {
  const _MainTabs({required this.selected, required this.onSelected});

  final _MainTab selected;
  final ValueChanged<_MainTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      constraints: BoxConstraints(minHeight: ui(_kBannerControlHeight)),
      padding: EdgeInsets.all(ui(2)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BannerSectionTabItem(
            label: '全部考试',
            selected: selected == _MainTab.exams,
            onTap: () => onSelected(_MainTab.exams),
          ),
          _BannerSectionTabItem(
            label: '我的成绩',
            selected: selected == _MainTab.grades,
            onTap: () => onSelected(_MainTab.grades),
          ),
        ],
      ),
    );
  }
}

class _BannerSectionTabItem extends StatelessWidget {
  const _BannerSectionTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(7)),
        decoration: BoxDecoration(
          color: selected ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: selected ? Colors.white : _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: selected ? AppFont.w500 : AppFont.w400,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// 「我的成绩」tab 顶部：分区标题 + 本学期/上学期切换。
class _GradesSemesterHeader extends StatelessWidget {
  const _GradesSemesterHeader({
    required this.selected,
    required this.onSelected,
  });

  final _SemesterTab selected;
  final ValueChanged<_SemesterTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SectionTitle('成绩与排名'),
        const Spacer(),
        _SemesterTabs(selected: selected, onSelected: onSelected),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
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
          color: const Color(0xFF1C274C),
        ),
      ),
    );
  }
}

class _SemesterTabs extends StatelessWidget {
  const _SemesterTabs({required this.selected, required this.onSelected});

  final _SemesterTab selected;
  final ValueChanged<_SemesterTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentToggle(
      selectedIndex: selected == _SemesterTab.current ? 0 : 1,
      thumbColor: _kTextDark,
      options: const [
        SegmentToggleOption(label: '本学期'),
        SegmentToggleOption(label: '上学期'),
      ],
      onChanged: (i) =>
          onSelected(i == 0 ? _SemesterTab.current : _SemesterTab.previous),
    );
  }
}

// =============================================================================
// 4 张统计卡
// =============================================================================

class _GradesStatsRow extends StatelessWidget {
  const _GradesStatsRow({required this.overview});

  final StudentExamOverview? overview;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(720);
        if (isCompact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _AverageCard(score: overview?.avgScore ?? 0)),
                  SizedBox(width: ui(12)),
                  Expanded(child: _ClassRankCard(overview: overview)),
                ],
              ),
              SizedBox(height: ui(12)),
              Row(
                children: [
                  Expanded(child: _GradeRankCard(overview: overview)),
                  SizedBox(width: ui(12)),
                  Expanded(child: _BestExamCard(overview: overview)),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _AverageCard(score: overview?.avgScore ?? 0)),
            SizedBox(width: ui(12)),
            Expanded(child: _ClassRankCard(overview: overview)),
            SizedBox(width: ui(12)),
            Expanded(child: _GradeRankCard(overview: overview)),
            SizedBox(width: ui(12)),
            Expanded(child: _BestExamCard(overview: overview)),
          ],
        );
      },
    );
  }
}

// 卡 A：学年考试均分（白底 + 进度条）
class _AverageCard extends StatelessWidget {
  const _AverageCard({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(14)),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text(
              '学年考试均分',
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: ui(28),
            child: Text(
              _scoreLabel(score),
              style: smartCampusStatValueTextStyle(ui),
            ),
          ),
          Positioned(
            left: ui(64),
            right: 0,
            top: ui(36),
            child: Text(
              '各次月考/大考总均分平均',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(11),
                color: _kTextDivider,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(64),
            right: 0,
            bottom: ui(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ui(20)),
              child: Stack(
                children: [
                  Container(height: ui(8), color: _kProgressBg),
                  FractionallySizedBox(
                    widthFactor: (score / 100).clamp(0.0, 1.0),
                    child: Container(height: ui(8), color: _kPurpleLight),
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

// 卡 B / C：最近班级 / 最近年级（紫渐变 / 绿渐变 + 右上 tag）
class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.title,
    required this.value,
    required this.totalSuffix,
    required this.cornerGlowColor,
    required this.trend,
  });

  factory _RankCard.classRank({
    required int rank,
    required int total,
    required int? trend,
  }) => _RankCard(
    title: '最近班级',
    value: '$rank',
    totalSuffix: '/$total',
    cornerGlowColor: const Color(0x339346FF),
    trend: trend,
  );

  factory _RankCard.gradeRank({
    required int rank,
    required int total,
    required int? trend,
  }) => _RankCard(
    title: '最近年级',
    value: '$rank',
    totalSuffix: '/$total',
    cornerGlowColor: const Color(0x3346FF77),
    trend: trend,
  );

  final String title;
  final String value;
  final String totalSuffix;
  final Color cornerGlowColor;

  /// 名次变化（正=进步/名次变小，负=退步，0=持平）；null 时不展示徽章。
  final int? trend;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: Colors.white),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
              width: ui(88),
              height: ui(72),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1,
                    colors: [
                      cornerGlowColor,
                      cornerGlowColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: ui(16),
            top: ui(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(16),
            top: ui(44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: smartCampusStatValueTextStyle(ui),
                ),
                SizedBox(width: ui(2)),
                Padding(
                  padding: EdgeInsets.only(bottom: ui(2)),
                  child: Text(
                    totalSuffix,
                    style: TextStyle(
                      fontSize: ui(20),
                      color: _kTextDivider,
                      fontFamily: 'Barlow',
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (trend != null)
            Positioned(
              right: ui(12),
              top: ui(14),
              child: _RankBadge(trend: trend!),
            ),
        ],
      ),
    );
  }
}

class _ClassRankCard extends StatelessWidget {
  const _ClassRankCard({required this.overview});

  final StudentExamOverview? overview;

  @override
  Widget build(BuildContext context) => _RankCard.classRank(
    rank: overview?.latestClassRank ?? 0,
    total: overview?.latestClassTotal ?? 0,
    trend: overview?.classRankTrend,
  );
}

class _GradeRankCard extends StatelessWidget {
  const _GradeRankCard({required this.overview});

  final StudentExamOverview? overview;

  @override
  Widget build(BuildContext context) => _RankCard.gradeRank(
    rank: overview?.latestSchoolRank ?? 0,
    total: overview?.latestSchoolTotal ?? 0,
    trend: overview?.schoolRankTrend,
  );
}

/// 名次变化徽章：上升 N 名（绿↑）/ 下降 N 名（红↓）/ 持平（灰—）。
/// 数据来自 `examOverview.trendList` 最近两场有效排名对比。
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.trend});

  /// 名次变化：>0 进步（名次变小）、<0 退步、0 持平。
  final int trend;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final flat = trend == 0;
    final up = trend > 0;
    final color = flat ? _kTextSecondary : (up ? _kRiseGreen : _kFallRed);
    final text = flat ? '持平' : (up ? '上升$trend名' : '下降${-trend}名');
    return Container(
      height: ui(24),
      padding: EdgeInsets.symmetric(horizontal: ui(8)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flat)
            Container(width: ui(8), height: 1, color: color)
          else
            Icon(
              up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: ui(12),
              color: color,
            ),
          SizedBox(width: ui(4)),
          Text(
            text,
            style: TextStyle(
              fontSize: ui(11),
              color: color,
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

// 卡 D：本学期最佳考试
class _BestExamCard extends StatelessWidget {
  const _BestExamCard({required this.overview});

  final StudentExamOverview? overview;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(100),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            child: Text(
              '本学期最佳考试',
              style: TextStyle(
                fontSize: ui(14),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(16),
            top: ui(50),
            right: ui(12),
            child: Text(
              overview?.bestExamName.isNotEmpty == true
                  ? overview!.bestExamName
                  : '暂无考试',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(20),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          Positioned(
            right: ui(12),
            top: ui(14),
            child: Container(
              height: ui(24),
              padding: EdgeInsets.symmetric(horizontal: ui(8)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPurpleBestBg,
                borderRadius: BorderRadius.circular(ui(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '均分 ',
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kPurple,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                  Text(
                    '${_scoreLabel(overview?.bestExamScore ?? 0)}分',
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kPurple,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1,
                    ),
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

// =============================================================================
// 双列：折线趋势 + 分数段分布
// =============================================================================

class _DualPanelRow extends StatelessWidget {
  const _DualPanelRow({required this.overview});

  final StudentExamOverview? overview;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(820);
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('${overview?.trends.length ?? 0}次考试 成绩趋势'),
              SizedBox(height: ui(12)),
              _LineChartCard(
                trends: overview?.trends ?? const [],
                classTotal: overview?.latestClassTotal ?? 0,
                schoolTotal: overview?.latestSchoolTotal ?? 0,
              ),
              SizedBox(height: ui(20)),
              const _SectionTitle('场次均分分布'),
              SizedBox(height: ui(12)),
              _ScoreDistributionCard(
                distribution: overview?.distribution ?? const [],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('${overview?.trends.length ?? 0}次考试 成绩趋势'),
                  SizedBox(height: ui(12)),
                  _LineChartCard(
                    trends: overview?.trends ?? const [],
                    classTotal: overview?.latestClassTotal ?? 0,
                    schoolTotal: overview?.latestSchoolTotal ?? 0,
                  ),
                ],
              ),
            ),
            SizedBox(width: ui(12)),
            Expanded(
              flex: 318,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('场次均分分布'),
                  SizedBox(height: ui(12)),
                  _ScoreDistributionCard(
                    distribution: overview?.distribution ?? const [],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(18),
        color: _kTextSection,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1.2,
      ),
    );
  }
}

// =============================================================================
// 折线图卡（左 640 宽 / 496 高）
// =============================================================================

class _LineChartCard extends StatelessWidget {
  const _LineChartCard({
    required this.trends,
    required this.classTotal,
    required this.schoolTotal,
  });

  final List<StudentExamTrend> trends;
  final int classTotal;
  final int schoolTotal;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final visible = trends;
    final months = visible
        .map((e) => e.examName.isNotEmpty ? e.examName : e.examDate)
        .toList();
    final values = visible.map((e) => e.totalScore).toList();
    final classRanks = visible.map((e) => e.classRank).toList();
    final schoolRanks = visible.map((e) => e.schoolRank).toList();
    if (values.isEmpty) {
      months.add('暂无');
      values.add(0);
      classRanks.add(0);
      schoolRanks.add(0);
    }
    return Container(
      height: ui(496),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '总分趋势',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                ),
              ),
              const Spacer(),
              Text(
                '最近${trends.length}场',
                style: TextStyle(fontSize: ui(12), color: _kTextHint),
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          Expanded(
            child: _LineChartArea(months: months, values: values),
          ),
          SizedBox(height: ui(8)),
          _RankRowHeader(classTotal: classTotal, schoolTotal: schoolTotal),
          SizedBox(height: ui(6)),
          _RankCellRow(
            months: months,
            values: values,
            classRanks: classRanks,
            schoolRanks: schoolRanks,
          ),
        ],
      ),
    );
  }
}

// 折线图绘制区
class _LineChartArea extends StatelessWidget {
  const _LineChartArea({required this.months, required this.values});

  final List<String> months;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        const yAxisWidth = 32.0;
        const yAxisToPlotGap = 8.0;
        final yAxisWidthPx = ui(yAxisWidth);
        final yAxisToPlotGapPx = ui(yAxisToPlotGap);
        final xLabelH = ui(20);
        final chartW =
            (w - yAxisWidthPx - yAxisToPlotGapPx).clamp(0.0, double.infinity);
        final chartH = (h - xLabelH).clamp(0.0, double.infinity);
        const tickCount = 6;
        final tickGap = chartH / (tickCount - 1);
        final maxValue = values.fold<double>(0, math.max);
        final step = maxValue <= 100 ? 20.0 : 50.0;
        final axisMax = math.max(100.0, (maxValue / step).ceil() * step);
        final ticks = List<int>.generate(
          tickCount,
          (index) =>
              (axisMax * (tickCount - 1 - index) / (tickCount - 1)).round(),
        );
        final gridLineYs = List.generate(tickCount, (index) => index * tickGap);
        final axisLabelStyle = TextStyle(
          fontSize: ui(12),
          color: _kAxisLabel,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 12,
        );

        double yForValue(double value) =>
            chartH * (1 - (value / axisMax).clamp(0.0, 1.0));

        final n = values.length;
        final cellW = chartW / n;
        final points = <Offset>[
          for (var i = 0; i < n; i++)
            Offset(cellW * (i + 0.5), yForValue(values[i])),
        ];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: yAxisWidthPx,
              height: chartH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < tickCount; i++)
                    Positioned(
                      top: gridLineYs[i] - ui(10),
                      left: 0,
                      right: 0,
                      height: ui(20),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${ticks[i]}',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.right,
                          style: axisLabelStyle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: yAxisToPlotGapPx),
            Expanded(
              child: SizedBox(
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: chartH,
                      child: CustomPaint(
                        painter: _LinePainter(
                          points: points,
                          chartHeight: chartH,
                          gridLineYs: gridLineYs,
                        ),
                      ),
                    ),
                    for (var i = 0; i < points.length; i++)
                      Positioned(
                        left: points[i].dx - ui(20),
                        top: (points[i].dy - ui(22)).clamp(0.0, chartH - ui(18)),
                        width: ui(40),
                        child: Text(
                          values[i] == values[i].roundToDouble()
                              ? values[i].toInt().toString()
                              : values[i].toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            height: 20 / 12,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: xLabelH,
                      child: Row(
                        children: [
                          for (var i = 0; i < n; i++)
                            Expanded(
                              child: Center(
                                child: Text(
                                  months[i],
                                  style: TextStyle(
                                    fontSize: ui(12),
                                    color: _kTextSecondary,
                                    fontFamily: 'PingFang SC',
                                    fontWeight: AppFont.w400,
                                    height: 20 / 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.chartHeight,
    required this.gridLineYs,
  });

  final List<Offset> points;
  final double chartHeight;
  final List<double> gridLineYs;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = _kBorderHair
      ..strokeWidth = 1;
    for (final y in gridLineYs) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length >= 2) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final cx = (p0.dx + p1.dx) / 2;
        linePath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      }

      final fillPath = Path.from(linePath)
        ..lineTo(points.last.dx, chartHeight)
        ..lineTo(points.first.dx, chartHeight)
        ..close();

      final fillPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE7D9FF), Color(0x00E7D9FF)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
      canvas.drawPath(fillPath, fillPaint);

      final strokePaint = Paint()
        ..color = _kPurple
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, strokePaint);
    }

    // Dots
    final dotFill = Paint()..color = Colors.white;
    final dotBorder = Paint()
      ..color = _kPurple
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final p in points) {
      canvas.drawCircle(p, 4, dotFill);
      canvas.drawCircle(p, 4, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.chartHeight != chartHeight ||
      oldDelegate.gridLineYs != gridLineYs;
}

// 折线图下方：每场·总成绩排名（班级/全校）行头
class _RankRowHeader extends StatelessWidget {
  const _RankRowHeader({required this.classTotal, required this.schoolTotal});

  final int classTotal;
  final int schoolTotal;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(2)),
      child: Row(
        children: [
          Text(
            '每场·总成绩排名 (班级/全校)',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            '班级总人数：$classTotal',
            style: TextStyle(
              fontSize: ui(10),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(width: ui(20)),
          Text(
            '全校总人数：$schoolTotal',
            style: TextStyle(
              fontSize: ui(10),
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

class _RankCellRow extends StatelessWidget {
  const _RankCellRow({
    required this.months,
    required this.values,
    required this.classRanks,
    required this.schoolRanks,
  });

  final List<String> months;
  final List<double> values;
  final List<int> classRanks;
  final List<int> schoolRanks;

  static const _visibleCount = 5;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final itemW = ui(96);
    final gap = ui(8);
    final count = months.length;
    final visibleSlots = count.clamp(1, _visibleCount);
    final viewportW = itemW * visibleSlots + gap * (visibleSlots - 1);

    return SizedBox(
      height: ui(100),
      width: viewportW,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: count > _visibleCount
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, i) => SizedBox(
          width: itemW,
          child: _RankCell(
            month: months[i],
            value: values[i],
            classRank: classRanks[i],
            schoolRank: schoolRanks[i],
          ),
        ),
      ),
    );
  }
}

class _RankCell extends StatelessWidget {
  const _RankCell({
    required this.month,
    required this.value,
    required this.classRank,
    required this.schoolRank,
  });

  final String month;
  final double value;
  final int classRank;
  final int schoolRank;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      padding: EdgeInsets.fromLTRB(ui(8), ui(4), ui(8), ui(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            month,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            value == value.roundToDouble()
                ? value.toInt().toString()
                : value.toString(),
            style: TextStyle(
              fontSize: ui(20),
              color: _kPurple,
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          SizedBox(height: ui(4)),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(6)),
            ),
            padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(4)),
            child: Column(
              children: [
                _MiniStatRow(label: '班级：', value: '$classRank'),
                _MiniStatRow(label: '全校：', value: '$schoolRank'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatRow extends StatelessWidget {
  const _MiniStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 场次均分分布（右 318 宽 / 496 高）
// =============================================================================

class _ScoreDistributionCard extends StatelessWidget {
  const _ScoreDistributionCard({required this.distribution});

  final List<StudentScoreDistribution> distribution;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final segments = distribution
        .map(
          (e) => _ScoreSegment(
            label: e.range,
            percent: e.percent.round(),
            count: e.count,
          ),
        )
        .toList();
    if (segments.isEmpty) {
      return Container(
        height: ui(496),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        alignment: Alignment.center,
        child: const SmartCampusEmptyState(
          icon: Icons.bar_chart_rounded,
          title: '暂无分数段数据',
          subtitle: '完成更多有成绩的考试后，将自动生成分数段分布。',
        ),
      );
    }
    return Container(
      height: ui(496),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: segments.length,
        separatorBuilder: (_, _) => SizedBox(height: ui(10)),
        itemBuilder: (_, index) => _ScoreSegmentTile(segment: segments[index]),
      ),
    );
  }
}

class _ScoreSegment {
  const _ScoreSegment({
    required this.label,
    required this.percent,
    required this.count,
  });

  final String label;
  final int percent; // 0~100
  final int count;
}

class _ScoreSegmentTile extends StatelessWidget {
  const _ScoreSegmentTile({required this.segment});

  final _ScoreSegment segment;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final fraction = (segment.percent / 100).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                segment.label,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${segment.count}场  ·  ${segment.percent}%',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(10)),
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(11)),
            child: SizedBox(
              height: ui(8),
              child: Stack(
                children: [
                  Container(color: _kBorderHair),
                  if (fraction > 0)
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [_kPurple, Color(0xFFE2D0FF)],
                          ),
                        ),
                      ),
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

// =============================================================================
// 考试记录与各科成绩（2 列网格）
// =============================================================================

class _ExamRecordsSection extends StatelessWidget {
  const _ExamRecordsSection({
    required this.records,
    this.loading = false,
    this.filteredEmpty = false,
  });

  final List<_ExamRecordData> records;
  final bool loading;
  final bool filteredEmpty;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionTitle('考试记录与各科成绩'),
            if (records.isNotEmpty) ...[
              SizedBox(width: ui(8)),
              _CountBadge(count: records.length),
            ],
          ],
        ),
        SizedBox(height: ui(12)),
        _ExamRecordsGrid(
          records: records,
          loading: loading,
          filteredEmpty: filteredEmpty,
        ),
      ],
    );
  }
}

class _ExamRecordsGrid extends StatelessWidget {
  const _ExamRecordsGrid({
    required this.records,
    this.loading = false,
    this.filteredEmpty = false,
  });

  final List<_ExamRecordData> records;
  final bool loading;
  final bool filteredEmpty;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      if (loading) {
        return Container(
          height: ui(160),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(ui(12)),
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: ui(28),
            height: ui(28),
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
            ),
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: SmartCampusEmptyState(
          illustration: AppAssets.emptyExamPlaceholder,
          title: filteredEmpty ? '该学期暂无成绩记录' : '暂无考试记录',
          subtitle: filteredEmpty
              ? '切换到其他学期查看，或等待老师公布本学期成绩。'
              : '',
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(720);
        final cols = isCompact ? 1 : 2;
        final gap = ui(16);
        final cardW = (c.maxWidth - gap * (cols - 1)) / cols;

        final rows = <Widget>[];
        for (var i = 0; i < records.length; i += cols) {
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: ui(12)));
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) SizedBox(width: gap),
                  SizedBox(
                    width: cardW,
                    child: i + j < records.length
                        ? _ExamRecordCard(record: records[i + j])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

// =============================================================================
// 单张考试记录卡
// =============================================================================

class _ExamRecordCard extends ConsumerStatefulWidget {
  const _ExamRecordCard({required this.record});

  final _ExamRecordData record;

  @override
  ConsumerState<_ExamRecordCard> createState() => _ExamRecordCardState();
}

class _ExamRecordCardState extends ConsumerState<_ExamRecordCard> {
  bool _expanded = false;

  void _openSeat() {
    if (widget.record.examId.isEmpty) return;
    showExamSeatDialog(
      context,
      ref: ref,
      examId: widget.record.examId,
      examTitle: widget.record.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExamCardHeader(
            title: widget.record.title,
            date: widget.record.date,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
            onOpenSeat: widget.record.examId.isEmpty ? null : _openSeat,
          ),
          SizedBox(height: ui(8)),
          _ExamSummaryRow(record: widget.record),
          if (_expanded && widget.record.subjects.isNotEmpty) ...[
            for (final s in widget.record.subjects) ...[
              SizedBox(height: ui(8)),
              _ExamSubjectTile(data: s),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExamCardHeader extends StatelessWidget {
  const _ExamCardHeader({
    required this.title,
    required this.date,
    required this.expanded,
    required this.onToggle,
    this.onOpenSeat,
  });

  final String title;
  final String date;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onOpenSeat;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: ui(16),
            color: Colors.black,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.2,
          ),
        ),
        SizedBox(width: ui(12)),
        Text(
          date,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDivider,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.2,
          ),
        ),
        const Spacer(),
        if (onOpenSeat != null) ...[
          InkWell(
            onTap: onOpenSeat,
            borderRadius: BorderRadius.circular(ui(8)),
            child: Container(
              height: ui(32),
              padding: EdgeInsets.symmetric(horizontal: ui(10)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_seat_outlined,
                    size: ui(15),
                    color: _kPurple,
                  ),
                  SizedBox(width: ui(4)),
                  Text(
                    '考场座位',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: ui(8)),
        ],

        InkWell(
          onTap: onToggle,
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
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: ui(18),
              color: _kTextDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExamSummaryRow extends StatelessWidget {
  const _ExamSummaryRow({required this.record});

  final _ExamRecordData record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final stats = <(String, String)>[
      ('总均分', record.totalAvg),
      ('及格科数', '${record.passCount}'),
      ('优秀科数', '${record.excellentCount}'),
      ('班级排名', '${record.classRank}'),
      ('全校排名', '${record.schoolRank}'),
    ];
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) SizedBox(width: ui(4)),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  stats[i].$1,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(width: ui(4)),
                Text(
                  stats[i].$2,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kPurple,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// 考试卡内的科目子卡
// =============================================================================

class _ExamSubjectTile extends ConsumerWidget {
  const _ExamSubjectTile({required this.data});

  final _ExamSubjectData data;

  void _openDetail(BuildContext context, WidgetRef ref) {
    final url = MediaUrl.resolve(data.resourcePath);
    if (url.isEmpty) return;
    final medium = _resourceMediumLabel(data.resourcePath);
    showStudentHomeworkSubmissionPreview(
      context,
      ref: ref,
      fileUrl: url,
      title: '${data.subjectName}考试资源',
      typeTag: medium,
      mediumLabel: medium,
      attachmentName: '${data.subjectName}考试资源',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SmoothCircleNetworkAvatar(
                    url: MediaUrl.resolve(data.headUrl),
                    size: ui(24),
                  ),
                  SizedBox(width: ui(6)),
                  Text(
                    data.teacher,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  _SubjectTag(subject: data.subject),
                ],
              ),
              SizedBox(height: ui(8)),
              Row(
                children: [
                  Text(
                    '班级排名：${data.classRank}',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(width: ui(12)),
                  Container(width: 1, height: ui(10), color: _kTextHint),
                  SizedBox(width: ui(12)),
                  Text(
                    '全校排名：${data.schoolRank}',
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
              SizedBox(height: ui(6)),
              Text(
                data.comment,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
              SizedBox(height: ui(8)),
              _MediaTag(kind: data.media),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Text(
              data.scoreLabel,
              style: TextStyle(
                fontSize: ui(14),
                color: _kBlueScore,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _ViewDetailButton(
              enabled: data.hasResource,
              onTap: () => _openDetail(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTag extends StatelessWidget {
  const _SubjectTag({required this.subject});

  final _SubjectKind subject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isPurple =
        subject == _SubjectKind.vocal || subject == _SubjectKind.instrument;
    final bg = isPurple ? _kPurpleSoftBg : _kSubjectGreenBg;
    final fg = isPurple ? _kPurple : _kSubjectGreen;
    final label = switch (subject) {
      _SubjectKind.vocal => '声乐',
      _SubjectKind.instrument => '器乐',
      _SubjectKind.sightSinging => '视唱',
      _SubjectKind.theory => '乐理',
      _SubjectKind.dictation => '听写',
    };
    return Container(
      height: ui(16),
      padding: EdgeInsets.symmetric(horizontal: ui(4)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 15.24 / 12,
        ),
      ),
    );
  }
}

class _MediaTag extends StatelessWidget {
  const _MediaTag({required this.kind});

  final _ReplayMedia kind;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (bg, fg, label, icon) = switch (kind) {
      _ReplayMedia.video => (
        _kPurpleSoftBg,
        _kPurple,
        '可回看录像',
        Icons.videocam_outlined,
      ),
      _ReplayMedia.audio => (
        _kPurpleSoftBg,
        _kPurple,
        '可回听录音',
        Icons.mic_none_rounded,
      ),
      _ReplayMedia.none => (_kBorderHair, _kTextHint, '本场无回放录制', null),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: ui(12), color: fg),
            SizedBox(width: ui(2)),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: ui(11),
              color: fg,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 15.24 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewDetailButton extends StatelessWidget {
  const _ViewDetailButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(80),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF1F1F4),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Text(
          enabled ? '查看详情' : '暂无回放',
          style: TextStyle(
            fontSize: ui(12),
            color: enabled ? _kTextDark : _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 16 / 12,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 页面展示模型
// =============================================================================

enum _SubjectKind { vocal, instrument, sightSinging, theory, dictation }

enum _ReplayMedia { video, audio, none }

class _ExamSubjectData {
  const _ExamSubjectData({
    required this.teacher,
    required this.headUrl,
    required this.subject,
    required this.subjectName,
    required this.classRank,
    required this.schoolRank,
    required this.comment,
    required this.score,
    required this.media,
    this.resourcePath = '',
  });

  final String teacher;
  final String headUrl;
  final _SubjectKind subject;
  final String subjectName;
  final int classRank;
  final int schoolRank;
  final String comment;
  final int? score;
  final _ReplayMedia media;

  /// 该科目考试资源（录音/录像/图片/文档）相对路径；空表示本场无回放。
  final String resourcePath;

  bool get hasResource => resourcePath.trim().isNotEmpty;

  String get scoreLabel {
    if (score == null) return '暂无';
    final s = score!;
    return s == s.roundToDouble() ? '${s.toInt()}分' : '$s分';
  }
}

class _ExamRecordData {
  const _ExamRecordData({
    required this.examId,
    required this.title,
    required this.date,
    required this.totalAvg,
    required this.passCount,
    required this.excellentCount,
    required this.classRank,
    required this.schoolRank,
    required this.subjects,
  });

  final String examId;
  final String title;
  final String date;
  final String totalAvg;
  final int passCount;
  final int excellentCount;
  final int classRank;
  final int schoolRank;
  final List<_ExamSubjectData> subjects;
}

_ExamRecordData _examRecordFromApi(StudentExamRecord record) {
  return _ExamRecordData(
    examId: record.examId,
    title: record.examName.isEmpty ? '考试' : record.examName,
    date: record.examDate,
    totalAvg: _scoreLabel(record.totalScore),
    passCount: record.passSubjectCount,
    excellentCount: record.excellentSubjectCount,
    classRank: record.classRank,
    schoolRank: record.schoolRank,
    subjects: record.subjectScores.map(_examSubjectFromApi).toList(),
  );
}

_ExamSubjectData _examSubjectFromApi(StudentExamSubjectScore score) {
  final teacherName = score.nickname.isNotEmpty ? score.nickname : '任课老师';
  return _ExamSubjectData(
    teacher: teacherName,
    headUrl: score.headUrl,
    subject: _subjectKindFromName(score.subjectName),
    subjectName: score.subjectName,
    classRank: score.classRank,
    schoolRank: score.schoolRank,
    comment: score.comment.isEmpty ? '暂无评语' : score.comment,
    score: score.score?.round(),
    media: _mediaFromPath(score.path),
    resourcePath: score.path,
  );
}

/// 资源相对路径 → 预览用「介质标签」（音频 / 视频 / 图片 / 文档）。
String _resourceMediumLabel(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mp3') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.m4a') ||
      lower.endsWith('.aac')) {
    return '音频';
  }
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.webm')) {
    return '视频';
  }
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp')) {
    return '图片';
  }
  return '文档';
}

_SubjectKind _subjectKindFromName(String name) {
  if (name.contains('声乐')) return _SubjectKind.vocal;
  if (name.contains('器乐') || name.contains('钢琴')) {
    return _SubjectKind.instrument;
  }
  if (name.contains('视唱')) return _SubjectKind.sightSinging;
  if (name.contains('听写')) return _SubjectKind.dictation;
  return _SubjectKind.theory;
}

_ReplayMedia _mediaFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mp4') || lower.endsWith('.mov')) {
    return _ReplayMedia.video;
  }
  if (lower.endsWith('.mp3') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.m4a')) {
    return _ReplayMedia.audio;
  }
  return _ReplayMedia.none;
}

String _scoreLabel(double score) => score == score.roundToDouble()
    ? '${score.round()}'
    : score.toStringAsFixed(1);

/// 按文件名扩展名识别在线考评可提交的媒体类型；非视频 / 音频 / 图片返回 null。
StudentExamMediaKind? _examMediaKindFromName(String name) {
  final lower = name.toLowerCase();
  const videoExt = ['.mp4', '.mov', '.webm', '.avi', '.mkv', '.m4v', '.3gp'];
  const audioExt = ['.mp3', '.wav', '.m4a', '.aac', '.flac', '.ogg', '.amr'];
  const imageExt = [
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.heif',
  ];
  if (videoExt.any(lower.endsWith)) return StudentExamMediaKind.video;
  if (audioExt.any(lower.endsWith)) return StudentExamMediaKind.audio;
  if (imageExt.any(lower.endsWith)) return StudentExamMediaKind.image;
  return null;
}

/// iOS / iPad 考试作品上传类型；走对应 [CoursewarePickType] 以拉起系统相册。
enum _ExamUploadKind { video, audio, image }

extension _ExamUploadKindX on _ExamUploadKind {
  CoursewarePickType get pickType => switch (this) {
    _ExamUploadKind.video => CoursewarePickType.video,
    _ExamUploadKind.audio => CoursewarePickType.audio,
    _ExamUploadKind.image => CoursewarePickType.image,
  };

  String get sheetLabel => switch (this) {
    _ExamUploadKind.video => '从相册选择视频',
    _ExamUploadKind.audio => '选择音频文件',
    _ExamUploadKind.image => '从相册选择照片',
  };
}

/// iOS 上 [CoursewarePickType.any] 会打开 UIDocumentPicker；先选类型再进相册。
Future<CoursewarePickType?> _resolveExamUploadPickType(
  BuildContext context,
) async {
  if (kIsWeb || !Platform.isIOS) return CoursewarePickType.any;
  final scale = DashboardScaleScope.of(context);
  return showModalBottomSheet<CoursewarePickType>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    isScrollControlled: true,
    builder: (ctx) => DashboardScaleScope(
      data: scale,
      child: const _ExamUploadKindSheet(),
    ),
  );
}

class _ExamUploadKindSheet extends StatelessWidget {
  const _ExamUploadKindSheet();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final kinds = _ExamUploadKind.values;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(377)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: ui(8)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(16)),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < kinds.length; i++) ...[
                      if (i > 0)
                        Container(height: 1, color: const Color(0x33000000)),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(kinds[i].pickType),
                        child: SizedBox(
                          height: ui(56),
                          child: Center(
                            child: Text(
                              kinds[i].sheetLabel,
                              style: TextStyle(
                                color: _kTextDark,
                                fontSize: ui(20),
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w400,
                                height: 24 / 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: ui(8)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(377)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  height: ui(56),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ui(16)),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: _kTextDark,
                      fontSize: ui(20),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 24 / 20,
                    ),
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

// =============================================================================
// 我的考场座位弹窗（student/examSeat）
// =============================================================================

Future<void> showExamSeatDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String examId,
  required String examTitle,
}) {
  return showScaledDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (_) => _ExamSeatDialog(examId: examId, examTitle: examTitle),
  );
}

class _ExamSeatDialog extends ConsumerStatefulWidget {
  const _ExamSeatDialog({required this.examId, required this.examTitle});

  final String examId;
  final String examTitle;

  @override
  ConsumerState<_ExamSeatDialog> createState() => _ExamSeatDialogState();
}

class _ExamSeatDialogState extends ConsumerState<_ExamSeatDialog> {
  bool _loading = true;
  String _error = '';
  StudentExamSeat? _seat;

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
        .read(studentRepositoryProvider)
        .examSeat(examId: widget.examId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess) {
        _seat = StudentExamSeat.fromData(res.data);
      } else {
        _error = res.displayMsg.isNotEmpty ? res.displayMsg : '座位信息加载失败';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GradientHeaderDialog(
      title: '我的考场座位',
      width: 460,
      actionBar: SizedBox(
        width: double.infinity,
        height: ui(44),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _kBorderSoft),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ui(12)),
            ),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(
            '关闭',
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
            ),
          ),
        ),
      ),
      child: _buildBody(ui),
    );
  }

  Widget _buildBody(double Function(double) ui) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: SizedBox(
            width: ui(28),
            height: ui(28),
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
            ),
          ),
        ),
      );
    }
    if (_error.isNotEmpty) {
      return SmartCampusEmptyState(
        icon: Icons.cloud_off_rounded,
        title: '座位信息加载失败',
        subtitle: _error,
        actionLabel: '重新加载',
        onAction: _load,
      );
    }
    final seat = _seat;
    final items = seat?.seats ?? const <StudentExamSeatItem>[];
    if (items.isEmpty) {
      return const SmartCampusEmptyState(
        icon: Icons.event_seat_outlined,
        title: '暂未编排考场',
        subtitle: '教务完成本场考试的考场编排后，你的各科教室与座位号会显示在这里。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SeatExamMeta(
          name: (seat?.examName.isNotEmpty ?? false)
              ? seat!.examName
              : widget.examTitle,
          date: seat?.examDate ?? '',
          remark: seat?.remark ?? '',
        ),
        SizedBox(height: ui(12)),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: ui(10)),
          _SeatSubjectCard(item: items[i]),
        ],
      ],
    );
  }
}

class _SeatExamMeta extends StatelessWidget {
  const _SeatExamMeta({
    required this.name,
    required this.date,
    required this.remark,
  });

  final String name;
  final String date;
  final String remark;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name.isEmpty ? '考试' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(15),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                  height: 1.2,
                ),
              ),
            ),
            if (date.isNotEmpty) ...[
              SizedBox(width: ui(8)),
              Text(
                date,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
        if (remark.trim().isNotEmpty) ...[
          SizedBox(height: ui(6)),
          Text(
            remark.trim(),
            style: TextStyle(
              fontSize: ui(12),
              color: _kPurple,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _SeatSubjectCard extends StatelessWidget {
  const _SeatSubjectCard({required this.item});

  final StudentExamSeatItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final arranged = item.arranged;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(12)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        children: [
          Container(
            width: ui(40),
            height: ui(40),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB68EFF), Color(0xFF8741FF)],
              ),
              borderRadius: BorderRadius.circular(ui(10)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.event_seat_rounded,
              size: ui(20),
              color: Colors.white,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.subjectName.isEmpty ? '科目' : item.subjectName,
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
                SizedBox(height: ui(4)),
                Text(
                  arranged ? item.classroomName : '尚未编排考场',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: arranged ? _kTextHint : const Color(0xFFB6B5BB),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(10)),
          if (arranged)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.seatNo}',
                  style: TextStyle(
                    fontSize: ui(24),
                    color: _kPurple,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                SizedBox(height: ui(2)),
                Text(
                  '座位号',
                  style: TextStyle(
                    fontSize: ui(10),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ],
            )
          else
            Text(
              '待编排',
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFFB6B5BB),
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

// =============================================================================
// 「全部考试」分区：考试安排 + 我的科目 + 座位（含未开始考试，当前为模拟数据）
// =============================================================================

class _AllExamsSection extends StatelessWidget {
  const _AllExamsSection({
    required this.exams,
    required this.filter,
    required this.loading,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  final List<StudentExamScheduleItem> exams;
  final _ExamFilter filter;
  final bool loading;
  final ValueChanged<_ExamFilter> onFilterChanged;
  final VoidCallback onRefresh;

  List<StudentExamScheduleItem> get _filtered => switch (filter) {
    _ExamFilter.all => exams,
    _ExamFilter.pending =>
      exams.where((e) => e.phase.isPending).toList(growable: false),
    _ExamFilter.done =>
      exams.where((e) => e.phase.isDone).toList(growable: false),
  };

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionTitle('全部考试'),
            SizedBox(width: ui(8)),
            _CountBadge(count: filtered.length),
            const Spacer(),
            _ExamFilterTabs(selected: filter, onSelected: onFilterChanged),
          ],
        ),
        SizedBox(height: ui(12)),
        if (loading && exams.isEmpty)
          Container(
            height: ui(200),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: ui(28),
              height: ui(28),
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
              ),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: const SmartCampusEmptyState(
              illustration: AppAssets.emptyExamPlaceholder,
              title: '暂无考试',
            ),
          )
        else
          _ExamScheduleGrid(exams: filtered, onRefresh: onRefresh),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
      decoration: BoxDecoration(
        color: _kPurpleSoftBg,
        borderRadius: BorderRadius.circular(ui(20)),
      ),
      child: Text(
        '$count 场',
        style: TextStyle(
          fontSize: ui(12),
          color: _kPurple,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _ExamFilterTabs extends StatelessWidget {
  const _ExamFilterTabs({required this.selected, required this.onSelected});

  final _ExamFilter selected;
  final ValueChanged<_ExamFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget pill(_ExamFilter tab, String label) {
      final active = selected == tab;
      return GestureDetector(
        onTap: () => onSelected(tab),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: ui(32),
          padding: EdgeInsets.symmetric(horizontal: ui(14)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _kTextDark : Colors.transparent,
            borderRadius: BorderRadius.circular(ui(6)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(13),
              color: active ? Colors.white : _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      );
    }

    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill(_ExamFilter.all, '全部'),
          SizedBox(width: ui(6)),
          pill(_ExamFilter.pending, '待考'),
          SizedBox(width: ui(6)),
          pill(_ExamFilter.done, '已考'),
        ],
      ),
    );
  }
}

class _ExamScheduleGrid extends StatelessWidget {
  const _ExamScheduleGrid({required this.exams, required this.onRefresh});

  final List<StudentExamScheduleItem> exams;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(720);
        final cols = isCompact ? 1 : 2;
        final gap = ui(16);
        final cardW = (c.maxWidth - gap * (cols - 1)) / cols;

        final rows = <Widget>[];
        for (var i = 0; i < exams.length; i += cols) {
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: ui(12)));
          }
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) SizedBox(width: gap),
                  SizedBox(
                    width: cardW,
                    child: i + j < exams.length
                        ? _ExamScheduleCard(
                            exam: exams[i + j],
                            onRefresh: onRefresh,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

// =============================================================================
// 单张考试卡（考试安排概览 + 查看科目与座位入口）
// =============================================================================

class _ExamScheduleCard extends StatelessWidget {
  const _ExamScheduleCard({required this.exam, required this.onRefresh});

  final StudentExamScheduleItem exam;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final status = _examCardStatus(exam);
    final uploadable = exam.onlineSubjects.any((s) => s.serverCanSubmit);
    return GestureDetector(
      onTap: () => showExamDetailDrawer(context, exam, onSubmitted: onRefresh),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        padding: EdgeInsets.all(ui(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    exam.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(16),
                      color: Colors.black,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(width: ui(8)),
                _PhaseBadge(phase: exam.phase),
              ],
            ),
            SizedBox(height: ui(10)),
            Row(
              children: [
                _TypeTag(label: exam.typeLabel),
                SizedBox(width: ui(6)),
                _ModeTag(label: exam.modeLabel, online: exam.hasOnline),
                SizedBox(width: ui(8)),
                Icon(Icons.event_outlined, size: ui(13), color: _kTextHint),
                SizedBox(width: ui(4)),
                Expanded(
                  child: Text(
                    '${exam.dateLabel} ${exam.weekdayLabel} · ${exam.timeRange}',
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
              ],
            ),
            SizedBox(height: ui(12)),
            Wrap(
              spacing: ui(6),
              runSpacing: ui(6),
              children: [
                for (final s in exam.subjects)
                  _SubjectChip(label: s.subjectName, online: s.isOnline),
              ],
            ),
            SizedBox(height: ui(12)),
            Container(height: ui(1), color: _kBorderHair),
            SizedBox(height: ui(10)),
            Row(
              children: [
                Icon(status.icon, size: ui(15), color: status.color),
                SizedBox(width: ui(4)),
                Expanded(
                  child: Text(
                    status.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: status.color,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(width: ui(8)),
                _ExamActionButton(
                  label: uploadable ? '去提交' : '查看科目',
                  icon: uploadable
                      ? Icons.file_upload_outlined
                      : Icons.visibility_outlined,
                  onTap: () => showExamDetailDrawer(
                    context,
                    exam,
                    onSubmitted: onRefresh,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 考试形式概览标签（在线 / 离线 / 线上+线下）。
class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.label, required this.online});

  final String label;

  /// 含在线科目（在线或混合）时为 true，用蓝色高亮。
  final bool online;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final fg = online ? _kBlueScore : _kTextSecondary;
    final bg = online ? const Color(0xFFE7EEFF) : _kInnerGray;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.cloud_upload_outlined : Icons.location_on_outlined,
            size: ui(11),
            color: fg,
          ),
          SizedBox(width: ui(3)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(11),
              color: fg,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamActionButton extends StatelessWidget {
  const _ExamActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: _kPurpleBestBg,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kPurpleSoftBg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: ui(15), color: _kPurple),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.phase});

  final StudentExamPhase phase;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final palette = _phasePalette(phase);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(4)),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Text(
        phase.label,
        style: TextStyle(
          fontSize: ui(12),
          color: palette.fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(11),
          color: _kTextSecondary,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.label, this.online = false});

  final String label;

  /// 在线科目：用蓝色系并带上传图标；离线科目：紫色系。
  final bool online;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final fg = online ? _kBlueScore : _kPurple;
    final bg = online ? const Color(0xFFEAF1FF) : _kPurpleBestBg;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(5)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.cloud_upload_outlined : Icons.event_seat_outlined,
            size: ui(11),
            color: fg,
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: fg,
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

({Color fg, Color bg}) _phasePalette(StudentExamPhase phase) {
  switch (phase) {
    case StudentExamPhase.registering:
      return (fg: _kPurple, bg: _kPurpleSoftBg);
    case StudentExamPhase.upcoming:
      return (fg: _kBlueScore, bg: const Color(0xFFE7EEFF));
    case StudentExamPhase.ongoing:
      return (fg: _kSubjectGreen, bg: _kSubjectGreenBg);
    case StudentExamPhase.finished:
      return (fg: const Color(0xFFE8902A), bg: const Color(0xFFFFF1DF));
    case StudentExamPhase.scored:
      return (fg: _kTextSecondary, bg: const Color(0xFFF0F0F4));
  }
}

/// 考试卡底部「状态汇总」（按科目在线/离线综合，图标 / 颜色 / 文案）。
({IconData icon, Color color, String text}) _examCardStatus(
  StudentExamScheduleItem exam,
) {
  const red = Color(0xFFF04545);
  const orange = Color(0xFFE8902A);
  if (exam.phase == StudentExamPhase.scored) {
    if (exam.totalScore != null) {
      return (
        icon: Icons.emoji_events_outlined,
        color: _kPurple,
        text: '总均分 ${_scoreLabel(exam.totalScore!)}',
      );
    }
    return (
      icon: Icons.workspace_premium_outlined,
      color: _kPurple,
      text: '成绩已公布',
    );
  }
  final online = exam.onlineSubjects;
  final total = online.length;
  final submitted = exam.submittedOnlineCount;
  if (exam.phase == StudentExamPhase.finished) {
    if (total > 0) {
      final missed = total - submitted;
      if (missed > 0) {
        return (
          icon: Icons.error_outline_rounded,
          color: red,
          text: '$missed 科未提交 · 已截止',
        );
      }
      return (
        icon: Icons.check_circle_outline_rounded,
        color: _kSubjectGreen,
        text: '在线 $total 科已提交 · 待公布',
      );
    }
    return (icon: Icons.hourglass_bottom_rounded, color: orange, text: '成绩待公布');
  }
  // 待考（未开始 / 进行中）：在线科目优先展示后端上传进度
  if (total > 0) {
    if (exam.uploadProgress.isNotEmpty) {
      final allDone = submitted >= total;
      return (
        icon: allDone ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
        color: allDone ? _kSubjectGreen : _kBlueScore,
        text: exam.uploadProgress,
      );
    }
    if (exam.submittableOnlineCount > 0) {
      return (
        icon: Icons.cloud_upload_outlined,
        color: _kBlueScore,
        text: '可上传录制文件',
      );
    }
    return (
      icon: Icons.lock_clock_outlined,
      color: _kTextHint,
      text: '在线科目未到提交时间',
    );
  }
  // 全离线：考场座位在详情接口，列表态提示查看
  return (
    icon: Icons.event_seat_outlined,
    color: _kTextSecondary,
    text: '点击查看考场座位',
  );
}

/// 单个在线科目的提交状态（图标 / 颜色 / 文案），用于科目卡。
({IconData icon, Color color, String text}) _subjectSubmitStatus(
  StudentExamSubjectPlan subject,
  StudentExamPhase phase,
) {
  final ratio = '${subject.uploadCount}/${subject.maxUploads}';
  switch (subject.submitState(phase)) {
    case StudentExamSubmitState.notOpen:
      return (
        icon: Icons.lock_clock_outlined,
        color: _kTextHint,
        text: '未到提交时间',
      );
    case StudentExamSubmitState.pending:
      return (
        icon: Icons.cloud_upload_outlined,
        color: _kBlueScore,
        text: '待提交 · 可上传 $ratio',
      );
    case StudentExamSubmitState.submittedRetryable:
      return (
        icon: Icons.cloud_done_outlined,
        color: _kSubjectGreen,
        text: '已提交 $ratio · 可重传',
      );
    case StudentExamSubmitState.submittedFull:
      return (
        icon: Icons.check_circle_outline_rounded,
        color: _kSubjectGreen,
        text: '已提交 $ratio · 次数用完',
      );
    case StudentExamSubmitState.submittedClosed:
      return (
        icon: Icons.check_circle_outline_rounded,
        color: _kSubjectGreen,
        text: '已提交 $ratio',
      );
    case StudentExamSubmitState.missed:
      return (
        icon: Icons.error_outline_rounded,
        color: Color(0xFFF04545),
        text: '未提交 · 已截止',
      );
    case StudentExamSubmitState.notApplicable:
      return (icon: Icons.cloud_outlined, color: _kTextHint, text: '在线');
  }
}

// =============================================================================
// 考试详情右侧抽屉：上方「本次考试信息」；下方逐科目（离线 → 考场 + 座位；
// 在线且正在进行 → 自录上传视频/音频，最多 2 次）。
//
// 在线 / 离线按科目区分（对齐机构管理端新建考试时的科目设置）。文件选择走真实
// 系统选择器（pickCoursewareFiles），提交结果先暂存本地（模拟）；接口就绪后把
// [_ExamDetailDrawerState._upload] 改为「选择 → 上传服务器 → 写回提交记录」。
// =============================================================================

Future<void> showExamDetailDrawer(
  BuildContext context,
  StudentExamScheduleItem exam, {
  required VoidCallback onSubmitted,
}) {
  // showGeneralDialog 经 root Navigator 推 route，子树不在原 dashboard 祖先链上，
  // 必须显式把 DashboardScaleScope 注入 pageBuilder，否则抽屉内 ui() 取不到比例。
  final scaleData =
      DashboardScaleScope.maybeOf(context) ??
      DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: '关闭',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, animation, secondary) {
      return DashboardScaleScope(
        data: scaleData,
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: _ExamDetailDrawer(
              listItem: exam,
              onSubmitted: onSubmitted,
              onClose: () => Navigator.of(ctx).maybePop(),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondary, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      );
    },
  );
}

class _ExamDetailDrawer extends ConsumerStatefulWidget {
  const _ExamDetailDrawer({
    required this.listItem,
    required this.onSubmitted,
    required this.onClose,
  });

  /// 列表项（用于详情加载前展示头部信息）。
  final StudentExamScheduleItem listItem;

  /// 提交成功后通知外层刷新列表。
  final VoidCallback onSubmitted;
  final VoidCallback onClose;

  @override
  ConsumerState<_ExamDetailDrawer> createState() => _ExamDetailDrawerState();
}

class _ExamDetailDrawerState extends ConsumerState<_ExamDetailDrawer> {
  StudentExamScheduleItem? _detail;
  bool _loading = true;
  bool _busy = false;
  String _error = '';

  /// 当前正在上传的科目 id（null 表示无）；上传进度 0~1；提交阶段（examSubmit）。
  int? _uploadingSubjectId;
  double _uploadProgress = 0;
  bool _submitting = false;

  void _resetUpload() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _uploadingSubjectId = null;
      _uploadProgress = 0;
      _submitting = false;
    });
  }

  /// 展示用考试（详情已加载用详情，否则用列表项）。
  StudentExamScheduleItem get _exam => _detail ?? widget.listItem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    final res = await ref
        .read(studentRepositoryProvider)
        .myExamDetail(id: widget.listItem.examId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess) {
        _detail = parseStudentExamDetail(res.data);
      } else {
        _error = res.displayMsg.isNotEmpty ? res.displayMsg : '考试详情加载失败';
      }
    });
  }

  /// 在线科目：选文件（视频/音频/图片）→ 上传文件服务器（带进度）→ 调 examSubmit → 刷新。
  /// iOS / iPad 先选媒体类型再进相册；其它平台走通用文件选择器。
  Future<void> _upload(StudentExamSubjectPlan subject) async {
    if (_busy || !subject.serverCanSubmit) return;
    setState(() {
      _busy = true;
      _uploadingSubjectId = subject.subjectId;
      _uploadProgress = 0;
      _submitting = false;
    });
    try {
      final pickType = await _resolveExamUploadPickType(context);
      if (!mounted) return;
      if (pickType == null) {
        _resetUpload();
        return;
      }
      final files = await pickCoursewareFiles(
        allowMultiple: false,
        type: pickType,
      );
      if (!mounted) return;
      if (files.isEmpty) {
        _resetUpload();
        return;
      }
      final picked = files.first;
      if (!picked.canUpload) {
        _resetUpload();
        AppToast.show(context, '所选文件不可读，请重试', type: AppToastType.error);
        return;
      }
      final kind = _examMediaKindFromName(picked.name);
      if (kind == null) {
        _resetUpload();
        AppToast.show(context, '仅支持上传视频、音频或图片文件', type: AppToastType.error);
        return;
      }
      final uploader = ref.read(cloudDriveControllerProvider.notifier);
      void onProgress(double p) {
        if (mounted) setState(() => _uploadProgress = p.clamp(0.0, 1.0));
      }

      final String? path = picked.hasPath
          ? await uploader.uploadFilePathRaw(
              filePath: picked.path!,
              filename: picked.name,
              onProgress: onProgress,
            )
          : await uploader.uploadFileRaw(
              bytes: picked.bytes ?? Uint8List(0),
              filename: picked.name,
              onProgress: onProgress,
            );
      if (!mounted) return;
      if (path == null || path.isEmpty) {
        _resetUpload();
        AppToast.show(context, '文件上传失败，请重试', type: AppToastType.error);
        return;
      }
      // 文件已传完，进入「提交」阶段（examSubmit）。
      setState(() {
        _uploadProgress = 1;
        _submitting = true;
      });
      final res = await ref
          .read(studentRepositoryProvider)
          .examSubmit(
            examId: _exam.examId,
            subjectId: subject.subjectId,
            filePath: path,
            fileType: kind.fileType,
          );
      if (!mounted) return;
      if (res.isSuccess) {
        _resetUpload();
        AppToast.show(
          context,
          '${subject.subjectName} 提交成功',
          type: AppToastType.success,
        );
        widget.onSubmitted();
        await _loadDetail();
      } else {
        _resetUpload();
        AppToast.show(
          context,
          res.displayMsg.isNotEmpty ? res.displayMsg : '提交失败，请重试',
          type: AppToastType.error,
        );
      }
    } catch (_) {
      _resetUpload();
      if (mounted) {
        AppToast.show(context, '提交异常，请重试', type: AppToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final exam = _exam;
    return SizedBox(
      width: ui(560),
      height: double.infinity,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // 抽屉头部：左紫色竖条 + 标题 + 关闭
            Container(
              height: ui(62),
              padding: EdgeInsets.symmetric(horizontal: ui(12)),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _kBorderSoft)),
              ),
              child: Row(
                children: [
                  Container(
                    width: ui(3.25),
                    height: ui(15),
                    decoration: BoxDecoration(
                      color: _kPurple,
                      borderRadius: BorderRadius.circular(ui(6)),
                    ),
                  ),
                  SizedBox(width: ui(6)),
                  Text(
                    '考试详情',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(ui(8)),
                    child: Padding(
                      padding: EdgeInsets.all(ui(8)),
                      child: Icon(
                        Icons.close_rounded,
                        size: ui(18),
                        color: _kTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 上方：本次考试信息
                    _ExamInfoBlock(exam: exam),
                    SizedBox(height: ui(16)),
                    // 下方：科目（含考场座位 / 在线自录上传）
                    Row(
                      children: [
                        const _SectionTitle('考试科目'),
                        SizedBox(width: ui(8)),
                        _CountBadge(count: exam.subjectCount),
                      ],
                    ),
                    SizedBox(height: ui(12)),
                    if (_loading && _detail == null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: ui(36)),
                        decoration: BoxDecoration(
                          color: _kInnerGray,
                          borderRadius: BorderRadius.circular(ui(12)),
                        ),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: ui(26),
                          height: ui(26),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(_kPurple),
                          ),
                        ),
                      )
                    else if (_detail == null && _error.isNotEmpty)
                      _DrawerErrorBox(message: _error, onRetry: _loadDetail)
                    else if (exam.subjects.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: ui(28)),
                        decoration: BoxDecoration(
                          color: _kInnerGray,
                          borderRadius: BorderRadius.circular(ui(12)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '本场考试的科目尚未公布',
                          style: TextStyle(
                            fontSize: ui(13),
                            color: _kTextHint,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                          ),
                        ),
                      )
                    else
                      for (final s in exam.subjects)
                        Padding(
                          padding: EdgeInsets.only(bottom: ui(10)),
                          child: s.isOnline
                              ? _ExamSubjectSubmitCard(
                                  subject: s,
                                  phase: exam.phase,
                                  busy: _busy,
                                  uploading: _uploadingSubjectId == s.subjectId,
                                  progress: _uploadProgress,
                                  submitting: _submitting,
                                  onUpload: () => _upload(s),
                                )
                              : _ExamSubjectArrangeCard(plan: s),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉内详情加载失败提示 + 重试。
class _DrawerErrorBox extends StatelessWidget {
  const _DrawerErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(28), horizontal: ui(16)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: ui(28), color: _kTextDivider),
          SizedBox(height: ui(8)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
            ),
          ),
          SizedBox(height: ui(12)),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(ui(8)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(16),
                vertical: ui(8),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderSoft),
              ),
              child: Text(
                '重新加载',
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 抽屉上方：本次考试信息（名称 / 阶段 / 类型 / 形式 / 时间 / 备注）。
class _ExamInfoBlock extends StatelessWidget {
  const _ExamInfoBlock({required this.exam});

  final StudentExamScheduleItem exam;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(16)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7F2FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(ui(14)),
        border: Border.all(color: _kBorderHair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  exam.name,
                  style: TextStyle(
                    fontSize: ui(18),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1.3,
                  ),
                ),
              ),
              SizedBox(width: ui(8)),
              _PhaseBadge(phase: exam.phase),
            ],
          ),
          SizedBox(height: ui(10)),
          Wrap(
            spacing: ui(8),
            runSpacing: ui(8),
            children: [
              _TypeTag(label: exam.typeLabel),
              _ModeTag(label: exam.modeLabel, online: exam.hasOnline),
            ],
          ),
          SizedBox(height: ui(10)),
          _MetaLine(
            icon: Icons.event_outlined,
            text: '${exam.dateLabel} ${exam.weekdayLabel} · ${exam.timeRange}',
          ),
          if (exam.statusText.isNotEmpty) ...[
            SizedBox(height: ui(6)),
            _MetaLine(
              icon: Icons.flag_outlined,
              text: '考试状态：${exam.statusText}',
            ),
          ],
          if (exam.uploadProgress.isNotEmpty) ...[
            SizedBox(height: ui(6)),
            _MetaLine(
              icon: Icons.cloud_upload_outlined,
              text: '在线提交：${exam.uploadProgress}',
            ),
          ],
          if (exam.remark.trim().isNotEmpty) ...[
            SizedBox(height: ui(10)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: ui(10),
                vertical: ui(8),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: ui(13),
                    color: _kPurple,
                  ),
                  SizedBox(width: ui(6)),
                  Expanded(
                    child: Text(
                      exam.remark.trim(),
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.5,
                      ),
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

class _ExamSubjectArrangeCard extends StatelessWidget {
  const _ExamSubjectArrangeCard({required this.plan});

  final StudentExamSubjectPlan plan;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final arranged = plan.arranged;
    final scored = plan.score != null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(12)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ui(40),
            height: ui(40),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB68EFF), Color(0xFF8741FF)],
              ),
              borderRadius: BorderRadius.circular(ui(10)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.event_seat_rounded,
              size: ui(20),
              color: Colors.white,
            ),
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
                        plan.subjectName.isEmpty ? '科目' : plan.subjectName,
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
                    if (plan.score != null) ...[
                      SizedBox(width: ui(8)),
                      _ScorePill(score: plan.score!),
                    ],
                  ],
                ),
                SizedBox(height: ui(6)),
                _MetaLine(
                  icon: Icons.schedule_rounded,
                  text: plan.durationLabel.trim().isEmpty
                      ? plan.dateTimeLabel
                      : '${plan.dateTimeLabel} · ${plan.durationLabel}',
                ),
                SizedBox(height: ui(4)),
                _MetaLine(
                  icon: Icons.place_outlined,
                  text: arranged
                      ? plan.classroomName
                      : (scored ? '考试已结束 · 成绩已公布' : '考场待编排'),
                  muted: !arranged,
                ),
              ],
            ),
          ),
          SizedBox(width: ui(10)),
          if (arranged)
            _SeatNumberBlock(seatNo: plan.seatNo!)
          else if (!scored)
            Text(
              '待编排',
              style: TextStyle(
                fontSize: ui(12),
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

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text, this.muted = false});

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final color = muted ? const Color(0xFFB6B5BB) : _kTextHint;
    return Row(
      children: [
        Icon(icon, size: ui(13), color: color),
        SizedBox(width: ui(4)),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: color,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
      decoration: BoxDecoration(
        color: _kPurpleSoftBg,
        borderRadius: BorderRadius.circular(ui(20)),
      ),
      child: Text(
        '${_scoreLabel(score)} 分',
        style: TextStyle(
          fontSize: ui(12),
          color: _kPurple,
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

// =============================================================================
// 在线科目卡：状态 + 已上传文件 + 自录上传（视频/音频，最多 2 次）
//
// 文件选择走真实系统选择器；提交结果暂存本地（模拟），接口就绪后在外层
// [_ExamDetailDialogState._upload] 接入真实上传即可。
// =============================================================================

class _ExamSubjectSubmitCard extends StatelessWidget {
  const _ExamSubjectSubmitCard({
    required this.subject,
    required this.phase,
    required this.busy,
    required this.onUpload,
    this.uploading = false,
    this.progress = 0,
    this.submitting = false,
  });

  final StudentExamSubjectPlan subject;
  final StudentExamPhase phase;
  final bool busy;
  final VoidCallback onUpload;

  /// 本科目正在上传 / 提交（用于展示进度）。
  final bool uploading;

  /// 文件上传进度 0~1。
  final double progress;

  /// 文件已传完、正在调用 examSubmit。
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final status = _subjectSubmitStatus(subject, phase);
    final canSubmit = subject.canSubmit(phase);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: _kBorderHair),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头部：图标 + 科目信息（名称/状态/时间/考场）+ 右侧座位号
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: ui(30),
                    height: ui(30),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(ui(8)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      size: ui(16),
                      color: _kBlueScore,
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: ui(44)),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  subject.subjectName.isEmpty
                                      ? '科目'
                                      : subject.subjectName,
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
                              if (subject.score != null) ...[
                                SizedBox(width: ui(6)),
                                _ScorePill(score: subject.score!),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: ui(8)),
                        Row(
                          children: [
                            Icon(
                              status.icon,
                              size: ui(14),
                              color: status.color,
                            ),
                            SizedBox(width: ui(4)),
                            Expanded(
                              child: Text(
                                status.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: status.color,
                                  fontFamily: 'PingFang SC',
                                  fontWeight: AppFont.w500,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ui(8)),
                        _MetaLine(
                          icon: Icons.schedule_rounded,
                          text: subject.scheduleLabel,
                        ),
                        if (subject.classroomName.trim().isNotEmpty) ...[
                          SizedBox(height: ui(4)),
                          _MetaLine(
                            icon: Icons.place_outlined,
                            text: subject.classroomName,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (subject.arranged) ...[
                    SizedBox(width: ui(10)),
                    Padding(
                      padding: EdgeInsets.only(top: ui(22)),
                      child: _SeatNumberBlock(seatNo: subject.seatNo!),
                    ),
                  ],
                ],
              ),
              SizedBox(height: ui(10)),
              _UploadQuotaBar(
                used: subject.uploadCount,
                max: subject.maxUploads,
              ),
              SizedBox(height: ui(10)),
              if (subject.uploads.isEmpty)
                _UploadEmptyHint(open: canSubmit)
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < subject.uploads.length; i++) ...[
                      if (i > 0) SizedBox(height: ui(8)),
                      _UploadedFileTile(
                        upload: subject.uploads[i],
                        index: i + 1,
                      ),
                    ],
                  ],
                ),
              SizedBox(height: ui(12)),
              if (uploading)
                _UploadProgressBar(progress: progress, submitting: submitting)
              else if (canSubmit)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: _UploadButton(
                        icon: Icons.file_upload_outlined,
                        label: '上传文件',
                        busy: false,
                        enabled: !busy,
                        onTap: onUpload,
                      ),
                    ),
                    SizedBox(height: ui(8)),
                    Text(
                      '支持视频、音频或图片文件，最多 ${subject.maxUploads} 次，以最后一次为准。',
                      style: TextStyle(
                        fontSize: ui(11),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                )
              else
                _SubjectSubmitNotice(subject: subject, phase: phase),
            ],
          ),
        ),
        Positioned(top: 0, right: 0, child: const _OnlineCornerBadge()),
      ],
    );
  }
}

/// 右侧大号座位号（在线 / 离线科目复用）。
class _SeatNumberBlock extends StatelessWidget {
  const _SeatNumberBlock({required this.seatNo});

  final int seatNo;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$seatNo',
          style: TextStyle(
            fontSize: ui(24),
            color: _kPurple,
            fontFamily: 'Barlow',
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        SizedBox(height: ui(2)),
        Text(
          '座位号',
          style: TextStyle(
            fontSize: ui(10),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// 在线科目右上角角标。
class _OnlineCornerBadge extends StatelessWidget {
  const _OnlineCornerBadge();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(4)),
      decoration: BoxDecoration(
        color: _kBlueScore,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(ui(12)),
          bottomLeft: Radius.circular(ui(10)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: ui(11), color: Colors.white),
          SizedBox(width: ui(4)),
          Text(
            '在线',
            style: TextStyle(
              fontSize: ui(10),
              color: Colors.white,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectSubmitNotice extends StatelessWidget {
  const _SubjectSubmitNotice({required this.subject, required this.phase});

  final StudentExamSubjectPlan subject;
  final StudentExamPhase phase;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = subject.submitState(phase);
    final notice = switch (state) {
      StudentExamSubmitState.notOpen => '未到考试提交时间，请等待考试开始。',
      StudentExamSubmitState.submittedFull =>
        '已达最多上传次数（${subject.maxUploads} 次），不可再次上传。',
      StudentExamSubmitState.submittedClosed => '提交已截止，以上为你已提交的文件。',
      StudentExamSubmitState.missed => '提交已截止且未上传，如有疑问请联系任课老师。',
      _ => '当前不可上传。',
    };
    final isError = state == StudentExamSubmitState.missed;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFECEC) : _kInnerGray,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: ui(15),
            color: isError ? const Color(0xFFF04545) : _kTextHint,
          ),
          SizedBox(width: ui(6)),
          Expanded(
            child: Text(
              notice,
              style: TextStyle(
                fontSize: ui(12),
                color: isError ? const Color(0xFFF04545) : _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadQuotaBar extends StatelessWidget {
  const _UploadQuotaBar({required this.used, required this.max});

  final int used;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final remaining = (max - used) < 0 ? 0 : max - used;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPurpleBestBg,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_sync_outlined, size: ui(16), color: _kPurple),
          SizedBox(width: ui(8)),
          Expanded(
            child: Text(
              '最多可上传 $max 次 · 已上传 $used 次 · 剩余 $remaining 次',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(width: ui(8)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < max; i++) ...[
                if (i > 0) SizedBox(width: ui(4)),
                Container(
                  width: ui(8),
                  height: ui(8),
                  decoration: BoxDecoration(
                    color: i < used ? _kPurple : const Color(0xFFD8C9FF),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadEmptyHint extends StatelessWidget {
  const _UploadEmptyHint({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(18)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: ui(26), color: _kTextDivider),
          SizedBox(height: ui(6)),
          Text(
            open ? '尚未上传，点击下方按钮上传文件' : '尚未上传任何文件',
            style: TextStyle(
              fontSize: ui(12),
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

class _UploadedFileTile extends ConsumerWidget {
  const _UploadedFileTile({required this.upload, required this.index});

  final StudentExamUpload upload;
  final int index;

  void _preview(BuildContext context, WidgetRef ref) {
    final url = MediaUrl.resolve(upload.path);
    if (url.isEmpty) return;
    showStudentHomeworkSubmissionPreview(
      context,
      ref: ref,
      fileUrl: url,
      title: upload.fileName,
      typeTag: upload.kind.label,
      mediumLabel: upload.kind.label,
      attachmentName: upload.fileName,
    );
  }

  IconData _iconForKind() => switch (upload.kind) {
    StudentExamMediaKind.video => Icons.videocam_rounded,
    StudentExamMediaKind.image => Icons.image_rounded,
    StudentExamMediaKind.audio => Icons.audiotrack_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;
    final canPreview = upload.path.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canPreview ? () => _preview(context, ref) : null,
        borderRadius: BorderRadius.circular(ui(10)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
          decoration: BoxDecoration(
            color: _kInnerGray,
            borderRadius: BorderRadius.circular(ui(10)),
          ),
          child: Row(
            children: [
              Container(
                width: ui(34),
                height: ui(34),
                decoration: BoxDecoration(
                  color: _kPurpleSoftBg,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _iconForKind(),
                  size: ui(18),
                  color: _kPurple,
                ),
              ),
          SizedBox(width: ui(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  upload.fileName,
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
                SizedBox(height: ui(3)),
                Text(
                  '第 $index 次 · ${upload.kind.label} · ${upload.uploadedAt}',
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
            ),
          ),
          SizedBox(width: ui(8)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(3)),
            decoration: BoxDecoration(
              color: _kSubjectGreenBg,
              borderRadius: BorderRadius.circular(ui(20)),
            ),
            child: Text(
              '已上传',
              style: TextStyle(
                fontSize: ui(10),
                color: _kSubjectGreen,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = busy || !enabled;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(ui(10)),
        child: Container(
          height: ui(44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFB68EFF), Color(0xFF8741FF)],
            ),
            borderRadius: BorderRadius.circular(ui(10)),
          ),
          child: busy
              ? SizedBox(
                  width: ui(18),
                  height: ui(18),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: ui(17), color: Colors.white),
                    SizedBox(width: ui(6)),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 在线科目上传进度条：文件上传显示百分比，提交阶段显示「正在提交…」。
class _UploadProgressBar extends StatelessWidget {
  const _UploadProgressBar({required this.progress, required this.submitting});

  final double progress;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final clamped = progress.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kPurpleBestBg,
        borderRadius: BorderRadius.circular(ui(10)),
        border: Border.all(color: _kPurpleSoftBg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_outlined, size: ui(14), color: _kPurple),
              SizedBox(width: ui(6)),
              Text(
                submitting ? '正在提交…' : '上传中',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kPurple,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
              const Spacer(),
              if (!submitting)
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kPurple,
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(20)),
            child: LinearProgressIndicator(
              value: submitting ? null : clamped,
              minHeight: ui(6),
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(_kPurple),
            ),
          ),
        ],
      ),
    );
  }
}
