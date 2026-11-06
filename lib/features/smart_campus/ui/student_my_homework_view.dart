// =============================================================================
// 学生端「我的作业」独立页面
//
// 入口：学生 dashboard 快捷区「我的作业」按钮 → controller.openMyHomework()
//      → mainView == myHomework + role == student → SmartCampusPage 路由到
//      本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：白→#F9EDFF 4deg 渐变，居中标题"我的作业" +
//      子标题"教师发布要求后提交视频、音频、照片或文档…"，左 32 返回。
//   2. 3 张 100 高统计卡（flex 1，gap 12）：
//      A. "学期考试均分" 32 + 进度条 + "各次月考/大考总均分平均"标签
//      B. 紫色渐变 "最近班级" 8 + "持平" 紫 tag
//      C. 绿色渐变 "最近年级" 62 + "上升3名" 绿 tag
//   3. 双列卡：
//      左 640 "均分柱形"（按科目/按老师 tabs + 4 根柱: 92/88/89/87
//                       + X 轴标签: 音乐/鉴赏/视唱/形体）
//      右 318 "分数段分布"（4 段 82 高灰底面板：90-100 33% 3场 / 80-90
//                        33% 3场 / 70-80 15% 1场 / <70 0% 0场）
//   4. 状态 tabs（全部 / 待提交 / 已提交 / 已批阅，44 高）
//   5. 作业卡 2 列网格（每行 2 张，紫色渐变 #FAF0FF→white，padding 12）
//      展示 6 张覆盖以下变体：
//        - 待提交 + 已逾期（橙红 tag、紫色截止时间 + 提交作业按钮）
//        - 已提交（批阅中：提交文件链接 + "教师批阅中"占位）
//        - 已批阅含语音点评（语音波形 + 点评卡）
//        - 已批阅含视频点评 + 88分
//        - 红色"声乐"tag + 语音 / 视频点评 ×2
//
// 颜色：白卡 / #F5F6FA 浅灰 / #8741FF 主紫 / #325BFF 蓝（提交链接 / 分数）
//      / #0CAC40 绿（已提交）/ #FF6A00 橙（待提交）/ #FF323C 红（已逾期）
//      / #12CE51 绿（上升）/ #FF386B 玫红（特殊"声乐"tag）
// 字体：PingFang SC + Barlow（数值 32 / 18）
//
// 弹窗：
//   · "提交作业"（_showSubmitDialog）：复用 [GradientHeaderDialog]（紫渐变
//     顶部 + 装饰图 + 24/500 标题），内含作业标题、提交类型 chips（视频/音频
//     /照片/文档）、上传文件区（走 [cloudDriveControllerProvider] 与 courseware
//     共享同一上传通道）、备注 textarea。提交成功后把卡片状态切到「已提交·
//     批阅中」并填充提交文件名。
//   · "作业详情"（_showDetailDialog）：同款 GradientHeaderDialog，只读展示
//     发布老师 / 截止时间 / 作业要求 / 提交情况 / 得分（已批阅）/ 教师反馈。
// =============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_refresh_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import 'widgets/homework_asset_icon.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import 'student_homework_submission_preview.dart';
import '../../courseware/state/cloud_drive_controller.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../../shell/ui/shell_layout.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../data/student_repository.dart';
import '../data/student_academic_data.dart';
import 'widgets/smart_campus_equal_height_grid.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stripe_bar_chart.dart';
import 'widgets/homework_voice_comment.dart';

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
const Color _kBlueLink = Color(0xFF325BFF);
const Color _kSubmittedGreen = Color(0xFF0CAC40);
const Color _kSubmittedGreenBg = Color(0xFFDFFCF0);
const Color _kPendingOrange = Color(0xFFFF6A00);
const Color _kPendingOrangeBg = Color(0xFFFFEDD3);
const Color _kOverdueRed = Color(0xFFFF323C);
const Color _kOverdueRedBg = Color(0xFFFFE4E5);
const Color _kRiseGreen = Color(0xFF12CE51);
const Color _kVocalTagBgRed = Color(0xFFFEE4E8);
const Color _kVocalTagFgRed = Color(0xFFFF386B);

DateTime? _tryParseStudentHwDate(String? raw) {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  final normalized = t.contains('T') ? t : t.replaceFirst(RegExp(r'\s+'), 'T');
  return DateTime.tryParse(normalized);
}

/// 列表分页：`data` 为 `records` / `list` / `rows` 或数组。
List<Map<dynamic, dynamic>> _extractStudentHomeworkRows(dynamic data) {
  if (data is List) {
    return data.whereType<Map<dynamic, dynamic>>().toList();
  }
  if (data is Map) {
    for (final key in ['records', 'list', 'rows']) {
      final v = data[key];
      if (v is List) {
        return v.whereType<Map<dynamic, dynamic>>().toList();
      }
    }
  }
  return [];
}

String _pickNonEmptyString(dynamic value) {
  return value?.toString().trim() ?? '';
}

String _nameFromTeacherObject(dynamic raw) {
  if (raw is! Map) return '';
  final m = Map<dynamic, dynamic>.from(raw);
  for (final key in [
    'teacherName',
    'teacherRealname',
    'realname',
    'realName',
    'name',
    'nickname',
  ]) {
    final text = _pickNonEmptyString(m[key]);
    if (text.isNotEmpty) return text;
  }
  return '';
}

/// 列表 / 详情中的发布老师姓名。优先读顶层 `teacherName`（studentHomeworkList 新增字段），
/// 再兼容嵌套 `homework` 与教师对象。
String _resolvePublishTeacherName(
  Map<dynamic, dynamic> m, {
  Map<dynamic, dynamic>? homework,
  String fallback = '—',
}) {
  for (final key in ['teacherName', 'teacherRealname', 'publishTeacherName']) {
    final text = _pickNonEmptyString(m[key]);
    if (text.isNotEmpty) return text;
  }
  final teacherRaw = m['teacher'];
  if (teacherRaw is Map) {
    final fromObj = _nameFromTeacherObject(teacherRaw);
    if (fromObj.isNotEmpty) return fromObj;
  }
  if (homework != null) {
    final nested = _resolvePublishTeacherName(homework, fallback: '');
    if (nested.isNotEmpty) return nested;
  }
  return fallback;
}

/// 学生作业行状态：`homeworkStudentStatus` 或嵌套 `homeworkStudent.status` 优先，
/// 否则回退顶层 `status`。
int _homeworkStudentRowStatus(Map<dynamic, dynamic> m) {
  final flat = m['homeworkStudentStatus'];
  if (flat != null) return int.tryParse(flat.toString()) ?? 0;
  final nested = m['homeworkStudent'];
  if (nested is Map && nested['status'] != null) {
    return int.tryParse(nested['status'].toString()) ?? 0;
  }
  return int.tryParse(m['status']?.toString() ?? '') ?? 0;
}

/// 仅「待提交且已过截止仍未交」计逾期；若在截止时间前（含同时刻前）已提交则不计逾期。
bool _studentHomeworkOverdue({
  required int rowStatus,
  required DateTime? deadline,
  required String submitTimeRaw,
}) {
  if (rowStatus != 0 || deadline == null) return false;
  final sub = _tryParseStudentHwDate(
    submitTimeRaw.trim().isEmpty ? null : submitTimeRaw,
  );
  if (sub != null) {
    return sub.isAfter(deadline);
  }
  return DateTime.now().isAfter(deadline);
}

/// 学生作业详情：`data` 含 `homework` + `homeworkStudent` 时合并为单层字段供 [mergeDetail] 使用。
/// 教师作业要求保留在 `description`；学生提交说明在 `studentSubmitDescription`。
Map<dynamic, dynamic> _flattenStudentHomeworkDetail(Map<dynamic, dynamic> m) {
  final hw = m['homework'];
  final hs = m['homeworkStudent'];
  final out = <dynamic, dynamic>{};

  if (hw is Map) {
    out.addAll(Map<dynamic, dynamic>.from(hw));
  }

  if (hs is Map) {
    final hsm = Map<dynamic, dynamic>.from(hs);
    final sid = hsm['id']?.toString().trim();
    if (sid != null && sid.isNotEmpty) {
      out['homeworkStudentId'] = sid;
    }
    if (hsm['status'] != null) {
      out['homeworkStudentStatus'] = hsm['status'];
    }
    if (hsm['submitTime'] != null) {
      out['submitTime'] = hsm['submitTime'];
    }
    if (hsm.containsKey('score')) out['score'] = hsm['score'];
    if (hsm.containsKey('feedback')) out['feedback'] = hsm['feedback'];
    if (hsm['studentParam1'] != null) {
      out['studentParam1'] = hsm['studentParam1'];
    }
    if (hsm['studentParam2'] != null) {
      out['studentParam2'] = hsm['studentParam2'];
    }
    if (hsm['studentParam3'] != null) {
      out['studentParam3'] = hsm['studentParam3'];
    }
    // 教师语音点评：teacherParam1=文件相对路径 / teacherParam2=时长（秒）。
    if (hsm['teacherParam1'] != null) {
      out['teacherParam1'] = hsm['teacherParam1'];
    }
    if (hsm['teacherParam2'] != null) {
      out['teacherParam2'] = hsm['teacherParam2'];
    }
    out['studentSubmitDescription'] = hsm['description']?.toString() ?? '';
  }

  final subj = m['subject'];
  if (subj is Map) {
    final sm = Map<dynamic, dynamic>.from(subj);
    final name = sm['name']?.toString();
    if (name != null && name.isNotEmpty) {
      out['subjectName'] = name;
    }
    if (sm['id'] != null) {
      out['subjectId'] = sm['id'];
    }
  }

  if (m['classInfo'] != null) {
    out['classInfo'] = m['classInfo'];
  }

  for (final e in m.entries) {
    final k = e.key;
    if (k == 'homework' ||
        k == 'homeworkStudent' ||
        k == 'subject' ||
        k == 'classInfo') {
      continue;
    }
    out.putIfAbsent(k, () => e.value);
  }

  if (out.isEmpty) {
    return m;
  }
  return out;
}

String _studentHwDeadlineLabel(String? endRaw) {
  final d = _tryParseStudentHwDate(endRaw);
  if (d == null) {
    return endRaw?.trim().isNotEmpty == true ? endRaw!.trim() : '—';
  }
  return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _expectedExtCn(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'audio':
      return '音频';
    case 'video':
      return '视频';
    case 'doc':
    case 'document':
      return '文档';
    case 'image':
      return '图片';
    default:
      final t = raw.trim();
      return t.isEmpty ? '附件' : t;
  }
}

_HomeworkSubject _subjectPillFromApi(String? subjectName, int? subjectId) {
  final n = (subjectName ?? '').toLowerCase();
  if (n.contains('声乐')) {
    final alt = (subjectId ?? 0) & 1;
    return alt == 0 ? _HomeworkSubject.vocal : _HomeworkSubject.vocalRed;
  }
  return _HomeworkSubject.music;
}

class StudentMyHomeworkView extends ConsumerStatefulWidget {
  const StudentMyHomeworkView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StudentMyHomeworkView> createState() =>
      _StudentMyHomeworkViewState();
}

class _StudentMyHomeworkViewState extends ConsumerState<StudentMyHomeworkView> {
  _StatusTab _selectedTab = _StatusTab.all;
  _ChartGroup _chartGroup = _ChartGroup.bySubject;
  List<_HomeworkData> _records = const [];
  StudentHomeworkSummary? _summary;
  bool _loadingList = false;
  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadList();
      _loadSummary();
    });
  }

  Future<void> _loadSummary() async {
    final res = await ref.read(studentRepositoryProvider).studentHomeworkSum();
    if (!mounted || !res.isSuccess) return;
    setState(() => _summary = StudentHomeworkSummary.fromData(res.data));
  }

  Future<void> _loadList() async {
    final showFullSpinner = _initialLoad && _records.isEmpty;
    if (showFullSpinner) {
      setState(() => _loadingList = true);
    }
    final int? statusParam = switch (_selectedTab) {
      _StatusTab.all => null,
      _StatusTab.pending => 0,
      _StatusTab.submitted => 1,
      _StatusTab.reviewed => 2,
    };
    final res = await ref
        .read(studentRepositoryProvider)
        .studentHomeworkList(current: 1, size: 50, status: statusParam);
    if (!mounted) return;
    if (res.isSuccess) {
      final rows = _extractStudentHomeworkRows(res.data);
      setState(() {
        _records = rows.map(_HomeworkData.fromStudentListMap).toList();
        _loadingList = false;
        _initialLoad = false;
      });
    } else {
      setState(() {
        _records = [];
        _loadingList = false;
        _initialLoad = false;
      });
      AppToast.show(context, res.msg.isNotEmpty ? res.msg : '作业列表加载失败');
    }
  }

  void _onStatusTabChanged(_StatusTab t) {
    if (t == _selectedTab) return;
    setState(() => _selectedTab = t);
    _loadList();
  }

  Future<void> _onSubmit(_HomeworkData data) async {
    if (data.recordId.isEmpty) {
      AppToast.show(context, '缺少作业记录编号，无法提交');
      return;
    }
    final ok = await showScaledDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogCtx) => _SubmitHomeworkDialog(data: data),
    );
    if (!mounted || ok != true) return;
    await _loadList();
    if (!mounted) return;
    AppToast.show(context, '作业已提交，等待教师批阅');
  }

  Future<void> _onDetail(_HomeworkData data) async {
    final snapshot = _latestHomeworkSnapshot(data);
    await showScaledDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogCtx) => _HomeworkDetailDialog(data: snapshot),
    );
  }

  /// 用列表中最新的项打开详情（提交后列表已刷新时可拿到最新状态）。
  _HomeworkData _latestHomeworkSnapshot(_HomeworkData data) {
    if (data.recordId.isEmpty) return data;
    for (final r in _records) {
      if (r.recordId == data.recordId) return r;
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pageLoading = _initialLoad && _loadingList;
    return SmartCampusSecondaryPageShell(
      backgroundColor: _kPageBg,
      bodyTopClipRadius: 8,
      bodyScrollable: false,
      header: _HomeworkBanner(onBack: widget.onBack),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadList(), _loadSummary()]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MainContentLoadingShell(
                loading: pageLoading,
                preserveChrome: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OverviewStatsRow(summary: _summary),
                    SizedBox(height: ui(16)),
                    _DualPanelRow(
                      chartGroup: _chartGroup,
                      onChartGroupChanged: (g) =>
                          setState(() => _chartGroup = g),
                      summary: _summary,
                    ),
                    SizedBox(height: ui(16)),
                    _StatusTabsRow(
                      selected: _selectedTab,
                      onSelected: _onStatusTabChanged,
                      summary: _summary,
                    ),
                    SizedBox(height: ui(10)),
                    if (!_loadingList && _records.isEmpty)
                      _HomeworkEmptyState(tab: _selectedTab)
                    else if (!pageLoading)
                      _HomeworkGrid(
                        records: _records,
                        onSubmit: _onSubmit,
                        onDetail: _onDetail,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Banner
// =============================================================================

class _HomeworkBanner extends StatelessWidget {
  const _HomeworkBanner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: smartCampusPageBannerDecoration(ui, borderRadius: 12),
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
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(60)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '我的作业',
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    '教师发布要求后提交视频、音频、照片或文档；批阅支持纯文字、语音、或视频/图片配合文字说明。',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 3 张统计卡
// =============================================================================

/// 作业页统计卡数值：Barlow 32 / w500（Figma 与成绩页排名卡一致）。
TextStyle _homeworkStatValueTextStyle(double Function(double) ui) {
  return TextStyle(
    fontSize: ui(32),
    color: const Color(0xFF0B081A),
    fontFamily: smartCampusStatValueFontFamily,
    fontWeight: FontWeight.w500,
    height: 1,
  );
}

class _OverviewStatsRow extends StatelessWidget {
  const _OverviewStatsRow({required this.summary});

  final StudentHomeworkSummary? summary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final s = summary;
    final overdue = s?.overdue ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _AverageScoreCard(avg: s?.overallAvgScore ?? 0)),
        SizedBox(width: ui(12)),
        Expanded(
          child: _HomeworkCountCard(
            backgroundAsset: AppAssets.studentHomeworkStatCard2,
            title: '已提交',
            value: '${s?.submitted ?? 0}',
            badgeText: '待提交 ${s?.pending ?? 0}',
            badgeColor: _kPendingOrange,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: _HomeworkCountCard(
            backgroundAsset: AppAssets.studentHomeworkStatCard3,
            title: '已批阅',
            value: '${s?.reviewed ?? 0}',
            badgeText: overdue > 0 ? '逾期 $overdue' : '无逾期',
            badgeColor: overdue > 0 ? _kOverdueRed : _kRiseGreen,
          ),
        ),
      ],
    );
  }
}

class _AverageScoreCard extends StatelessWidget {
  const _AverageScoreCard({required this.avg});

  /// 作业总体均分（0 表示暂无数据）。
  final double avg;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasData = avg > 0;
    final valueLabel = hasData
        ? (avg % 1 == 0 ? avg.toStringAsFixed(0) : avg.toStringAsFixed(1))
        : '—';
    return SmartCampusStatCard.custom(
      backgroundAsset: AppAssets.studentHomeworkStatCard1,
      contentPadding: EdgeInsets.zero,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: ui(16),
            top: ui(16),
            child: Text(
              '作业均分',
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
            child: Text(
              valueLabel,
              style: _homeworkStatValueTextStyle(ui),
            ),
          ),
        ],
      ),
    );
  }
}

/// 作业计数卡（已提交/已批阅等），右上角徽标显示次级计数（待提交/逾期）。
class _HomeworkCountCard extends StatelessWidget {
  const _HomeworkCountCard({
    required this.backgroundAsset,
    required this.title,
    required this.value,
    required this.badgeText,
    required this.badgeColor,
  });

  final String backgroundAsset;
  final String title;
  final String value;
  final String badgeText;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SmartCampusStatCard.custom(
      backgroundAsset: backgroundAsset,
      contentPadding: EdgeInsets.zero,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
            child: Text(
              value,
              style: _homeworkStatValueTextStyle(ui),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(6)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: ui(11),
                  color: badgeColor,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 双列：均分柱形 + 分数段分布
// =============================================================================

class _DualPanelRow extends StatelessWidget {
  const _DualPanelRow({
    required this.chartGroup,
    required this.onChartGroupChanged,
    required this.summary,
  });

  final _ChartGroup chartGroup;
  final ValueChanged<_ChartGroup> onChartGroupChanged;
  final StudentHomeworkSummary? summary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, c) {
        final isCompact = c.maxWidth < ui(720);
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle('均分柱形'),
              SizedBox(height: ui(12)),
              _AverageBarChartCard(
                group: chartGroup,
                onGroupChanged: onChartGroupChanged,
                bars: _summaryBars(summary, chartGroup),
              ),
              SizedBox(height: ui(20)),
              _SectionTitle('分数段分布'),
              SizedBox(height: ui(12)),
              _ScoreDistributionCard(items: _summaryRanges(summary)),
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
                  _SectionTitle('均分柱形'),
                  SizedBox(height: ui(12)),
                  _AverageBarChartCard(
                    group: chartGroup,
                    onGroupChanged: onChartGroupChanged,
                    bars: _summaryBars(summary, chartGroup),
                  ),
                ],
              ),
            ),
            SizedBox(width: ui(12)),
            Expanded(
              flex: 318,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle('分数段分布'),
                  SizedBox(height: ui(12)),
                  _ScoreDistributionCard(items: _summaryRanges(summary)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _ChartGroup { bySubject, byTeacher }

class _AverageBarChartCard extends StatelessWidget {
  const _AverageBarChartCard({
    required this.group,
    required this.onGroupChanged,
    required this.bars,
  });

  final _ChartGroup group;
  final ValueChanged<_ChartGroup> onGroupChanged;
  final List<_BarItem> bars;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(400),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SegmentedControl<_ChartGroup>(
            value: group,
            options: const [
              (_ChartGroup.bySubject, '按科目'),
              (_ChartGroup.byTeacher, '按老师'),
            ],
            onChanged: onGroupChanged,
          ),
          SizedBox(height: ui(24)),
          Expanded(
            child: SmartCampusStripeBarChart(
              ticks: const [100, 95, 90, 85, 80, 0],
              tickGap: 28,
              yAxisWidth: 20,
              yAxisToPlotGap: 22,
              barWidth: 35,
              columnGap: 28,
              bottomInset: 20,
              valueLabelGap: 24,
              plotTopInset: 0,
              chartHeight: 270,
              entries: bars
                  .map(
                    (b) => SmartCampusBarChartEntry(
                      label: b.label,
                      value: b.value,
                      labelIsHint: b.label == '暂无' && b.value == 0,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarItem {
  const _BarItem({required this.label, required this.value});

  final String label;
  final double value;
}

class _ScoreDistributionCard extends StatelessWidget {
  const _ScoreDistributionCard({required this.items});

  final List<_ScoreSegment> items;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(400),
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: items.isEmpty
          ? const _ScoreDistributionEmpty()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(16)),
                  _ScoreSegmentTile(item: items[i]),
                ],
              ],
            ),
    );
  }
}

class _ScoreDistributionEmpty extends StatelessWidget {
  const _ScoreDistributionEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: ui(40),
            color: _kTextHint,
          ),
          SizedBox(height: ui(10)),
          Text(
            '暂无分数段数据',
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 16 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

List<_BarItem> _summaryBars(StudentHomeworkSummary? summary, _ChartGroup group) {
  final rows = group == _ChartGroup.byTeacher
      ? (summary?.teacherAvgScores ?? const <StudentSubjectAverage>[])
      : (summary?.subjectAvgScores ?? const <StudentSubjectAverage>[]);
  if (rows.isEmpty) {
    return const [_BarItem(label: '暂无', value: 0)];
  }
  return rows
      .take(6)
      .map((e) => _BarItem(label: e.subjectName, value: e.score))
      .toList();
}

List<_ScoreSegment> _summaryRanges(StudentHomeworkSummary? summary) {
  final rows = summary?.scoreRanges ?? const <StudentScoreDistribution>[];
  return rows
      .map(
        (e) => _ScoreSegment(
          label: e.range,
          percent: e.percent.round(),
          count: e.count,
        ),
      )
      .toList();
}

class _ScoreSegment {
  const _ScoreSegment({
    required this.label,
    required this.percent,
    required this.count,
  });

  final String label;
  final int percent;
  final int count;
}

class _ScoreSegmentTile extends StatelessWidget {
  const _ScoreSegmentTile({required this.item});

  final _ScoreSegment item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(82),
      padding: EdgeInsets.fromLTRB(ui(16), ui(10), ui(16), ui(8)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ),
              Text(
                '${item.percent}%',
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
          SizedBox(height: ui(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(20)),
            child: Stack(
              children: [
                Container(height: ui(8), color: _kBorderHair),
                FractionallySizedBox(
                  widthFactor: (item.percent / 50).clamp(0.0, 1.0),
                  child: Container(
                    height: ui(8),
                    decoration: const BoxDecoration(
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
          SizedBox(height: ui(4)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${item.count}场',
              style: TextStyle(
                fontSize: ui(12),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 状态 tabs
// =============================================================================

enum _StatusTab { all, pending, submitted, reviewed }

class _StatusTabsRow extends StatelessWidget {
  const _StatusTabsRow({
    required this.selected,
    required this.onSelected,
    this.summary,
  });

  final _StatusTab selected;
  final ValueChanged<_StatusTab> onSelected;
  final StudentHomeworkSummary? summary;

  static const _options = <(_StatusTab, String)>[
    (_StatusTab.all, '全部'),
    (_StatusTab.pending, '待提交'),
    (_StatusTab.submitted, '已提交'),
    (_StatusTab.reviewed, '已评分'),
  ];

  int? _countOf(_StatusTab tab) {
    final s = summary;
    if (s == null) return null;
    return switch (tab) {
      _StatusTab.all => s.total,
      _StatusTab.pending => s.pending,
      _StatusTab.submitted => s.submitted,
      _StatusTab.reviewed => s.reviewed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: ui(44),
        padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(4)),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _options.length; i++) ...[
              if (i > 0) SizedBox(width: ui(16)),
              _TabChip(
                label: _options[i].$2,
                count: _countOf(_options[i].$1),
                active: _options[i].$1 == selected,
                onTap: () => onSelected(_options[i].$1),
                activeBg: _kTextDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.activeBg,
    this.count,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color activeBg;

  /// 该状态的数量；为 null 时不显示计数。
  final int? count;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final showCount = count != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeBg : null,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          showCount ? '$label $count' : label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 16 / 14,
          ),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      ),
    );
  }
}

class _HomeworkEmptyState extends StatelessWidget {
  const _HomeworkEmptyState({required this.tab});

  final _StatusTab tab;

  String get _message => switch (tab) {
    _StatusTab.all => '暂无作业',
    _StatusTab.pending => '暂无待提交作业',
    _StatusTab.submitted => '暂无已提交作业',
    _StatusTab.reviewed => '暂无已评分作业',
  };

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(48)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: ui(48),
            color: _kTextHint,
          ),
          SizedBox(height: ui(12)),
          Text(
            _message,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 16 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedControl<T> extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget pill(T tab, String label) {
      final active = tab == value;
      return GestureDetector(
        onTap: () => onChanged(tab),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: ui(36),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFFB5B5B5).withValues(alpha: 0.35),
                      offset: Offset(0, ui(8)),
                      blurRadius: ui(20),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: active ? _kTextDark : _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(ui(4), ui(4), ui(3), ui(4)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(width: ui(16)),
            pill(options[i].$1, options[i].$2),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 作业卡（数据 + 网格 + 单卡）
// =============================================================================

enum _HomeworkSubject { music, vocal, vocalRed }

enum _HomeworkStatus { pending, overdue, submitted, reviewed }

enum _HomeworkBodyType {
  // 待提交：占位文字 + 提交作业按钮
  pending,
  // 已提交（批阅中）：提交链接 + "教师批阅中，请留意通知"
  submittedReviewing,
  // 已批阅：提交链接 + 教师点评（语音/视频气泡）+ 可能含分数
  reviewed,
}

enum _ReviewMediaType { audio, video, none }

class _HomeworkData {
  const _HomeworkData({
    this.recordId = '',
    required this.title,
    required this.subject,
    required this.status,
    required this.bodyType,
    required this.teacher,
    required this.deadline,
    this.score,
    this.submittedFile,
    this.reviewMedia = _ReviewMediaType.none,
    this.reviewMediaDuration,
    this.reviewText,
    this.voiceCommentPath = '',
    this.voiceCommentDuration = 0,
    this.requirementText = '',
    this.teacherFeedback = '',
    this.submitTimeDisplay = '',
    this.mediumLabel = '',
    this.studentSubmitDescription = '',
    this.submitAttachmentName = '',
    this.submitTypeTag = '',
    this.submitFileUrl = '',
  });

  /// 学生作业记录 id（列表 **`homeworkStudentId`**），用于详情 / 提交接口。
  final String recordId;
  final String title;
  final _HomeworkSubject subject;
  final _HomeworkStatus status;
  final _HomeworkBodyType bodyType;
  final String teacher;
  final String deadline;
  final String? score;
  final String? submittedFile;
  final _ReviewMediaType reviewMedia;
  final String? reviewMediaDuration;
  final String? reviewText;

  /// 教师语音点评文件相对路径（详情接口 `teacherParam1`）。空字符串表示无语音点评。
  final String voiceCommentPath;

  /// 教师语音点评时长（秒，详情接口 `teacherParam2`）。
  final int voiceCommentDuration;

  /// 教师发布的作业要求（列表或详情接口 `description`）。
  final String requirementText;

  /// 教师评语（接口 `feedback` / `teacherFeedback`）。
  final String teacherFeedback;

  /// 提交时间展示字符串。
  final String submitTimeDisplay;

  /// 期望提交格式（`expectedExt` → 中文，如 音频 / 文档）。
  final String mediumLabel;

  /// 学生提交作业时在接口里填的说明（`homeworkStudent.description`，与教师 `homework.description` 不同）。
  final String studentSubmitDescription;

  /// 提交文件名 `studentParam2`。
  final String submitAttachmentName;

  /// 提交类型标签 `studentParam3`（如 音频）。
  final String submitTypeTag;

  /// 提交文件完整 URL（由 `studentParam1` 经 [MediaUrl.resolve] 得到），用于预览。
  final String submitFileUrl;

  static _HomeworkData fromStudentListMap(Map<dynamic, dynamic> m) {
    final recordId =
        m['homeworkStudentId']?.toString().trim() ??
        m['studentHomeworkId']?.toString().trim() ??
        '';
    final hw = m['homework'];
    Map<dynamic, dynamic>? hwm;
    if (hw is Map) {
      hwm = Map<dynamic, dynamic>.from(hw);
    }

    String pick(String k) {
      final top = m[k];
      if (top != null && top.toString().trim().isNotEmpty) {
        return top.toString();
      }
      final nested = hwm?[k];
      return nested?.toString() ?? '';
    }

    final title = pick('title').isNotEmpty ? pick('title') : '作业';
    final description = pick('description');
    final endRaw = pick('endTime');
    final deadline = _studentHwDeadlineLabel(endRaw.isNotEmpty ? endRaw : null);
    final teacher = _resolvePublishTeacherName(m, homework: hwm);

    final rowStatus = _homeworkStudentRowStatus(m);
    final submitTime = m['submitTime']?.toString().trim() ?? '';
    final hasSubmitTime = submitTime.isNotEmpty;

    final parsedEnd = _tryParseStudentHwDate(endRaw.isNotEmpty ? endRaw : null);
    final overdue = _studentHomeworkOverdue(
      rowStatus: rowStatus,
      deadline: parsedEnd,
      submitTimeRaw: submitTime,
    );

    late final _HomeworkStatus st;
    if (rowStatus == 2) {
      st = _HomeworkStatus.reviewed;
    } else if (rowStatus == 1) {
      st = _HomeworkStatus.submitted;
    } else if (overdue) {
      st = _HomeworkStatus.overdue;
    } else {
      st = _HomeworkStatus.pending;
    }

    late final _HomeworkBodyType body;
    if (rowStatus == 2) {
      body = _HomeworkBodyType.reviewed;
    } else if (rowStatus == 1) {
      body = _HomeworkBodyType.submittedReviewing;
    } else {
      body = _HomeworkBodyType.pending;
    }

    final scoreRaw = m['score'];
    final String? score =
        (scoreRaw != null && scoreRaw.toString().trim().isNotEmpty)
        ? '$scoreRaw分'
        : null;

    final subjName = pick('subjectName');
    final subjId = int.tryParse(pick('subjectId'));
    final subject = _subjectPillFromApi(
      subjName.isNotEmpty ? subjName : null,
      subjId,
    );

    final ext = pick('expectedExt');
    final mediumLabel = _expectedExtCn(ext);
    final fileName = pick('fileName').isNotEmpty
        ? pick('fileName')
        : (pick('studentParam2').isNotEmpty ? pick('studentParam2') : '');
    final String? submittedFile = fileName.isNotEmpty
        ? '${_expectedExtCn(ext)} ·$fileName'
        : (hasSubmitTime ? '${_expectedExtCn(ext)} ·已提交' : null);

    final fb = pick('feedback').isNotEmpty
        ? pick('feedback')
        : pick('teacherFeedback');
    final reviewText = fb.isNotEmpty ? fb : null;

    return _HomeworkData(
      recordId: recordId,
      title: title,
      subject: subject,
      status: st,
      bodyType: body,
      teacher: teacher,
      deadline: deadline,
      score: score,
      submittedFile: submittedFile,
      reviewMedia: _ReviewMediaType.none,
      reviewText: reviewText,
      requirementText: description,
      teacherFeedback: fb,
      submitTimeDisplay: submitTime,
      mediumLabel: mediumLabel,
    );
  }

  /// 用详情接口返回覆盖列表摘要。
  static _HomeworkData mergeDetail(
    _HomeworkData base,
    Map<dynamic, dynamic> raw,
  ) {
    final m = _flattenStudentHomeworkDetail(Map<dynamic, dynamic>.from(raw));
    String pick(String k) => m[k]?.toString() ?? '';

    final title = pick('title');
    final description = pick('description');
    final feedback = pick('feedback').isNotEmpty
        ? pick('feedback')
        : pick('teacherFeedback');
    final submitTime = pick('submitTime');
    final endRaw = pick('endTime');
    final deadline = endRaw.isNotEmpty
        ? _studentHwDeadlineLabel(endRaw)
        : base.deadline;
    final resolvedTeacher = _resolvePublishTeacherName(m, fallback: '');
    final teacher = resolvedTeacher.isNotEmpty ? resolvedTeacher : base.teacher;

    final rowStatus = _homeworkStudentRowStatus(m);
    final hasSubmitTime = submitTime.isNotEmpty;
    final parsedEnd = _tryParseStudentHwDate(endRaw.isNotEmpty ? endRaw : null);
    final overdue = _studentHomeworkOverdue(
      rowStatus: rowStatus,
      deadline: parsedEnd,
      submitTimeRaw: submitTime,
    );

    late final _HomeworkStatus st;
    if (rowStatus == 2) {
      st = _HomeworkStatus.reviewed;
    } else if (rowStatus == 1) {
      st = _HomeworkStatus.submitted;
    } else if (overdue) {
      st = _HomeworkStatus.overdue;
    } else {
      st = _HomeworkStatus.pending;
    }

    late final _HomeworkBodyType body;
    if (rowStatus == 2) {
      body = _HomeworkBodyType.reviewed;
    } else if (rowStatus == 1) {
      body = _HomeworkBodyType.submittedReviewing;
    } else {
      body = _HomeworkBodyType.pending;
    }

    final scoreRaw = m['score'];
    final String? score =
        (scoreRaw != null && scoreRaw.toString().trim().isNotEmpty)
        ? '$scoreRaw分'
        : base.score;

    final ext = pick('expectedExt');
    final fileName = pick('fileName').isNotEmpty
        ? pick('fileName')
        : (pick('studentParam2').isNotEmpty ? pick('studentParam2') : '');
    final String? submittedFile = fileName.isNotEmpty
        ? '${_expectedExtCn(ext)} ·$fileName'
        : (hasSubmitTime ? '${_expectedExtCn(ext)} ·已提交' : base.submittedFile);

    final subjName = pick('subjectName');
    final subjId = int.tryParse(pick('subjectId'));
    final subject = subjName.isNotEmpty || pick('subjectId').isNotEmpty
        ? _subjectPillFromApi(subjName.isNotEmpty ? subjName : null, subjId)
        : base.subject;

    final mergedFeedback = feedback.isNotEmpty
        ? feedback
        : base.teacherFeedback;
    final mergedReview = mergedFeedback.isNotEmpty
        ? mergedFeedback
        : base.reviewText;

    final hid = pick('homeworkStudentId');
    final extRaw = pick('expectedExt');
    final mediumFromDetail = extRaw.isNotEmpty ? _expectedExtCn(extRaw) : '';

    final studDesc = pick('studentSubmitDescription').trim();
    final p1 = pick('studentParam1').trim();
    final p2 = pick('studentParam2').trim();
    final p3 = pick('studentParam3').trim();
    final resolvedFile = p1.isNotEmpty ? MediaUrl.resolve(p1) : '';

    // 教师语音点评：teacherParam1=相对路径 / teacherParam2=时长（秒）。
    final voicePath = pick('teacherParam1').trim();
    final voiceDur = int.tryParse(pick('teacherParam2').trim()) ?? 0;

    // 仅 homeworkStudent 单条详情（无嵌套 homework）时，顶层 `description` 为学生提交说明。
    final studentOnlyFlat =
        pick('title').isEmpty && pick('endTime').isEmpty && p1.isNotEmpty;
    final studentNote = studDesc.isNotEmpty
        ? studDesc
        : (studentOnlyFlat ? description.trim() : '');

    return base.copyWith(
      recordId: hid.isNotEmpty ? hid : null,
      title: title.isNotEmpty ? title : null,
      subject: subject,
      status: st,
      bodyType: body,
      teacher: teacher,
      deadline: deadline,
      score: score,
      submittedFile: submittedFile,
      reviewText: mergedReview,
      requirementText: studentOnlyFlat
          ? null
          : (description.isNotEmpty ? description : null),
      teacherFeedback: mergedFeedback.isNotEmpty ? mergedFeedback : null,
      submitTimeDisplay: submitTime.isNotEmpty ? submitTime : null,
      mediumLabel: mediumFromDetail.isNotEmpty ? mediumFromDetail : null,
      studentSubmitDescription: studentNote.isNotEmpty ? studentNote : null,
      submitAttachmentName: p2.isNotEmpty ? p2 : null,
      submitTypeTag: p3.isNotEmpty ? p3 : null,
      submitFileUrl: resolvedFile.isNotEmpty ? resolvedFile : null,
      voiceCommentPath: voicePath.isNotEmpty ? voicePath : null,
      voiceCommentDuration: voicePath.isNotEmpty ? voiceDur : null,
    );
  }

  _HomeworkData copyWith({
    String? recordId,
    String? title,
    _HomeworkSubject? subject,
    _HomeworkStatus? status,
    _HomeworkBodyType? bodyType,
    String? teacher,
    String? deadline,
    String? score,
    String? submittedFile,
    _ReviewMediaType? reviewMedia,
    String? reviewMediaDuration,
    String? reviewText,
    String? voiceCommentPath,
    int? voiceCommentDuration,
    String? requirementText,
    String? teacherFeedback,
    String? submitTimeDisplay,
    String? mediumLabel,
    String? studentSubmitDescription,
    String? submitAttachmentName,
    String? submitTypeTag,
    String? submitFileUrl,
  }) {
    return _HomeworkData(
      recordId: recordId ?? this.recordId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      bodyType: bodyType ?? this.bodyType,
      teacher: teacher ?? this.teacher,
      deadline: deadline ?? this.deadline,
      score: score ?? this.score,
      submittedFile: submittedFile ?? this.submittedFile,
      reviewMedia: reviewMedia ?? this.reviewMedia,
      reviewMediaDuration: reviewMediaDuration ?? this.reviewMediaDuration,
      reviewText: reviewText ?? this.reviewText,
      voiceCommentPath: voiceCommentPath ?? this.voiceCommentPath,
      voiceCommentDuration: voiceCommentDuration ?? this.voiceCommentDuration,
      requirementText: requirementText ?? this.requirementText,
      teacherFeedback: teacherFeedback ?? this.teacherFeedback,
      submitTimeDisplay: submitTimeDisplay ?? this.submitTimeDisplay,
      mediumLabel: mediumLabel ?? this.mediumLabel,
      studentSubmitDescription:
          studentSubmitDescription ?? this.studentSubmitDescription,
      submitAttachmentName: submitAttachmentName ?? this.submitAttachmentName,
      submitTypeTag: submitTypeTag ?? this.submitTypeTag,
      submitFileUrl: submitFileUrl ?? this.submitFileUrl,
    );
  }
}

class _HomeworkGrid extends StatelessWidget {
  const _HomeworkGrid({
    required this.records,
    required this.onSubmit,
    required this.onDetail,
  });

  final List<_HomeworkData> records;
  final ValueChanged<_HomeworkData> onSubmit;
  final ValueChanged<_HomeworkData> onDetail;

  @override
  Widget build(BuildContext context) {
    return SmartCampusEqualHeightGrid(
      itemCount: records.length,
      spacing: 10,
      itemBuilder: (context, index) {
        final r = records[index];
        return _HomeworkCard(
          data: r,
          onSubmit: () => onSubmit(r),
          onDetail: () => onDetail(r),
        );
      },
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({
    required this.data,
    required this.onSubmit,
    required this.onDetail,
  });

  final _HomeworkData data;
  final VoidCallback onSubmit;
  final VoidCallback onDetail;

  static const _cardBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFAF0FF), Colors.white],
  );

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: _cardBgGradient,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: Colors.white),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: Transform.scale(
                scale: 1.14,
                child: Image.asset(
                  AppAssets.studentHomeworkCardBg,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(ui(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CardHeaderRow(data: data),
                  SizedBox(height: ui(8)),
                  _CardMetaRow(
                    teacher: data.teacher,
                    deadline: data.deadline,
                    mediumLabel: data.mediumLabel,
                    deadlineHighlight:
                        data.status == _HomeworkStatus.pending ||
                        data.status == _HomeworkStatus.overdue,
                  ),
                  SizedBox(height: ui(8)),
                  _CardBody(data: data),
                  SizedBox(height: ui(8)),
                  _CardActionRow(
                    showSubmit:
                        data.status == _HomeworkStatus.pending ||
                        data.status == _HomeworkStatus.overdue,
                    onSubmit: onSubmit,
                    onDetail: onDetail,
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

class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({required this.data});

  final _HomeworkData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        _SubjectTag(subject: data.subject),
        SizedBox(width: ui(4)),
        _StatusTag(status: data.status),
        if (data.score != null) ...[
          SizedBox(width: ui(8)),
          Text(
            data.score!,
            style: TextStyle(
              fontSize: ui(14),
              color: _kBlueLink,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _SubjectTag extends StatelessWidget {
  const _SubjectTag({required this.subject});

  final _HomeworkSubject subject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (bg, fg, text) = switch (subject) {
      _HomeworkSubject.music => (_kSubmittedGreenBg, _kSubmittedGreen, '乐理'),
      _HomeworkSubject.vocal => (_kPurpleSoftBg, _kPurple, '声乐'),
      _HomeworkSubject.vocalRed => (_kVocalTagBgRed, _kVocalTagFgRed, '声乐'),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        text,
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

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final _HomeworkStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final items = <(Color bg, Color fg, String text)>[];
    switch (status) {
      case _HomeworkStatus.pending:
        items.add((_kPendingOrangeBg, _kPendingOrange, '待提交'));
        break;
      case _HomeworkStatus.overdue:
        items.add((_kPendingOrangeBg, _kPendingOrange, '待提交'));
        items.add((_kOverdueRedBg, _kOverdueRed, '已逾期'));
        break;
      case _HomeworkStatus.submitted:
        items.add((_kSubmittedGreenBg, _kSubmittedGreen, '已提交'));
        break;
      case _HomeworkStatus.reviewed:
        items.add((_kSubmittedGreenBg, _kSubmittedGreen, '已评分'));
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: ui(4)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
            decoration: BoxDecoration(
              color: items[i].$1,
              borderRadius: BorderRadius.circular(ui(4)),
            ),
            child: Text(
              items[i].$3,
              style: TextStyle(
                fontSize: ui(12),
                color: items[i].$2,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 15.24 / 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CardMetaRow extends StatelessWidget {
  const _CardMetaRow({
    required this.teacher,
    required this.deadline,
    required this.deadlineHighlight,
    this.mediumLabel = '',
  });

  final String teacher;
  final String deadline;
  final String mediumLabel;
  final bool deadlineHighlight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final showMedium = mediumLabel.trim().isNotEmpty && mediumLabel != '附件';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '发布老师：',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
            Text(
              teacher,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
            SizedBox(width: ui(8)),
            Container(width: 1, height: ui(10), color: _kTextHint),
            SizedBox(width: ui(8)),
            HomeworkAssetIcon(
              AppAssets.homeworkDeadlineIcon,
              size: ui(12),
            ),
            SizedBox(width: ui(4)),
            Text(
              '截止时间：',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
            Text(
              deadline,
              style: TextStyle(
                fontSize: ui(12),
                color: deadlineHighlight ? _kPurple : _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ],
        ),
        if (showMedium) ...[
          SizedBox(height: ui(6)),
          Text(
            '建议提交：$mediumLabel',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.data});

  final _HomeworkData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final desc = data.requirementText.trim();
    final descStyle = TextStyle(
      fontSize: ui(12),
      color: _kTextDark,
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w400,
      height: 1.35,
    );
    final hintStyle = TextStyle(
      fontSize: ui(12),
      color: _kTextHint,
      fontFamily: 'PingFang SC',
      fontWeight: AppFont.w400,
      height: 1.35,
    );

    final Widget tail;
    switch (data.bodyType) {
      case _HomeworkBodyType.pending:
        tail = desc.isEmpty
            ? Text('暂无作业说明', style: hintStyle)
            : const SizedBox.shrink();
        break;
      case _HomeworkBodyType.submittedReviewing:
        tail = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((data.submittedFile ?? '').trim().isNotEmpty)
              _SubmittedFileRow(file: data.submittedFile!.trim()),
            if ((data.submittedFile ?? '').trim().isNotEmpty)
              SizedBox(height: ui(8)),
            Text(
              '教师批阅中，请留意通知',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ],
        );
        break;
      case _HomeworkBodyType.reviewed:
        final reviewText = data.reviewText?.trim() ?? '';
        final hasReviewContent =
            reviewText.isNotEmpty || data.reviewMedia != _ReviewMediaType.none;
        tail = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((data.submittedFile ?? '').trim().isNotEmpty)
              _SubmittedFileRow(file: data.submittedFile!.trim()),
            if (hasReviewContent) ...[
              SizedBox(height: ui(8)),
              _ReviewBubble(
                media: data.reviewMedia,
                duration: data.reviewMediaDuration ?? '',
                text: reviewText,
              ),
            ],
          ],
        );
        break;
    }

    return Padding(
      padding: EdgeInsets.only(top: ui(4), bottom: ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc.isNotEmpty) ...[
            Text(
              desc,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: descStyle,
            ),
            SizedBox(height: ui(8)),
          ],
          tail,
        ],
      ),
    );
  }
}

class _SubmittedFileRow extends StatelessWidget {
  const _SubmittedFileRow({required this.file});

  final String file;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '提交：',
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        Flexible(
          child: Text(
            file,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: _kBlueLink,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
              decoration: TextDecoration.underline,
              decorationColor: _kBlueLink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewBubble extends StatelessWidget {
  const _ReviewBubble({
    required this.media,
    required this.duration,
    required this.text,
  });

  final _ReviewMediaType media;
  final String duration;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewMediaTile(media: media),
              SizedBox(width: ui(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '教师点评',
                      style: TextStyle(
                        fontSize: ui(10),
                        color: _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: -ui(8),
            top: -ui(8),
            child: Container(
              height: ui(22),
              padding: EdgeInsets.symmetric(horizontal: ui(8)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPurpleSoftBg,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(ui(12)),
                  bottomLeft: Radius.circular(ui(12)),
                ),
              ),
              child: Text(
                '${switch (media) {
                  _ReviewMediaType.video => '视频',
                  _ReviewMediaType.audio => '语音',
                  _ReviewMediaType.none => '语音',
                }} $duration',
                style: TextStyle(
                  fontSize: ui(10),
                  color: _kPurple,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMediaTile extends StatelessWidget {
  const _ReviewMediaTile({required this.media});

  final _ReviewMediaType media;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (media == _ReviewMediaType.video) {
      return Container(
        width: ui(40),
        height: ui(40),
        decoration: BoxDecoration(
          color: const Color(0xFFEFE5FF),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        alignment: Alignment.center,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
          decoration: BoxDecoration(
            color: _kPurpleLight,
            borderRadius: BorderRadius.circular(ui(2)),
          ),
          child: Text(
            '视频',
            style: TextStyle(
              fontSize: ui(9),
              color: Colors.white,
              fontFamily: 'PingFang SC',
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: ui(40),
      height: ui(40),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: ui(6),
            right: ui(6),
            top: ui(6),
            bottom: ui(18),
            child: HomeworkAssetIcon.expand(AppAssets.homeworkReviewVoiceIcon),
          ),
          Positioned(
            left: ui(6),
            right: ui(6),
            bottom: ui(6),
            child: Container(
              height: ui(11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPurpleLight,
                borderRadius: BorderRadius.circular(ui(2)),
              ),
              child: Text(
                '语音',
                style: TextStyle(
                  fontSize: ui(8),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardActionRow extends StatelessWidget {
  const _CardActionRow({
    required this.showSubmit,
    required this.onSubmit,
    required this.onDetail,
  });

  final bool showSubmit;
  final VoidCallback onSubmit;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _SmallButton(
          label: '查看详情',
          background: _kInnerGray,
          foreground: _kTextDark,
          onTap: onDetail,
        ),
        if (showSubmit) ...[
          SizedBox(width: ui(12)),
          _SmallButton(
            label: '提交作业',
            useGradient: true,
            foreground: Colors.white,
            onTap: onSubmit,
          ),
        ],
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.foreground,
    required this.onTap,
    this.background,
    this.useGradient = false,
  });

  final String label;
  final Color foreground;
  final VoidCallback onTap;
  final Color? background;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(80),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: useGradient ? null : background,
          gradient: useGradient
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: foreground,
            fontFamily: 'PingFang SC',
            fontWeight: useGradient ? AppFont.w600 : AppFont.w500,
            height: 16 / 12,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 通用：段标题
// =============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        color: _kTextSection,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 1,
      ),
    );
  }
}

// =============================================================================
// 弹窗：提交作业
// =============================================================================

enum _SubmitKind { video, audio, photo, doc }

extension _SubmitKindX on _SubmitKind {
  /// 类型芯片 / 上传框文案。
  String get label => switch (this) {
    _SubmitKind.video => '视频',
    _SubmitKind.audio => '音频',
    _SubmitKind.photo => '照片',
    _SubmitKind.doc => '文档',
  };

  /// 选择文件时按类型过滤系统选择器（与「我的云盘」上传规则一致）。
  CoursewarePickType get pickType => switch (this) {
    _SubmitKind.video => CoursewarePickType.video,
    _SubmitKind.audio => CoursewarePickType.audio,
    _SubmitKind.photo => CoursewarePickType.image,
    _SubmitKind.doc => CoursewarePickType.any,
  };

  /// 「上传文件」标题右侧的格式提示。
  String get uploadTip => switch (this) {
    _SubmitKind.video => '*支持 mp4 / mov 等视频格式',
    _SubmitKind.audio => '*支持 mp3 / wav / m4a 等音频格式',
    _SubmitKind.photo => '*支持 jpg / png / gif / webp 等格式',
    _SubmitKind.doc => '*支持 PDF / Word / 图片 / HTML 等格式',
  };
}

class _SubmitHomeworkDialog extends ConsumerStatefulWidget {
  const _SubmitHomeworkDialog({required this.data});

  final _HomeworkData data;

  @override
  ConsumerState<_SubmitHomeworkDialog> createState() =>
      _SubmitHomeworkDialogState();
}

class _SubmitHomeworkDialogState extends ConsumerState<_SubmitHomeworkDialog> {
  _SubmitKind _kind = _SubmitKind.video;
  late final TextEditingController _noteCtrl;

  CoursewarePickedFile? _picked;
  double _progress = 0;
  String? _remotePath;
  String? _errorText;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _ready =>
      _picked != null && _remotePath != null && !_uploading && !_submitting;

  void _onKindChanged(_SubmitKind k) {
    if (k == _kind || _uploading) return;
    setState(() {
      _kind = k;
      _picked = null;
      _remotePath = null;
      _progress = 0;
      _errorText = null;
    });
  }

  Future<void> _pickFile() async {
    if (_uploading) return;
    final files = await pickCoursewareFiles(
      allowMultiple: false,
      type: _kind.pickType,
    );
    if (files.isEmpty) return;
    final f = files.first;
    if (!f.canUpload) {
      setState(() => _errorText = '所选文件不可读，请重试');
      return;
    }
    setState(() {
      _picked = f;
      _progress = 0;
      _remotePath = null;
      _errorText = null;
      _uploading = true;
    });
    try {
      final controller = ref.read(cloudDriveControllerProvider.notifier);
      String? saved;
      if (f.hasPath) {
        saved = await controller.uploadFilePathRaw(
          filePath: f.path!,
          filename: f.name,
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
        );
      } else {
        saved = await controller.uploadFileRaw(
          bytes: f.bytes ?? Uint8List(0),
          filename: f.name,
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
        );
      }
      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (saved == null || saved.isEmpty) {
          _errorText = '上传失败，请重试';
          _remotePath = null;
        } else {
          _remotePath = saved;
          _progress = 1;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _errorText = '上传异常，请重试';
        _remotePath = null;
      });
    }
  }

  void _removeFile() {
    if (_uploading) return;
    setState(() {
      _picked = null;
      _progress = 0;
      _remotePath = null;
      _errorText = null;
    });
  }

  Future<void> _submit() async {
    if (!_ready || _picked == null) return;
    if (widget.data.recordId.isEmpty) {
      AppToast.show(context, '缺少作业记录编号，无法提交');
      return;
    }
    setState(() => _submitting = true);
    final note = _noteCtrl.text.trim();
    final desc = note.isNotEmpty ? note : '提交了：${_picked!.name}';
    final kindLabel = _kind.label;
    final res = await ref
        .read(studentRepositoryProvider)
        .studentHomeworkSubmit(
          id: widget.data.recordId,
          description: desc,
          studentParam1: _remotePath ?? '',
          studentParam2: _picked!.name,
          studentParam3: kindLabel,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.isSuccess) {
      Navigator.of(context).pop(true);
    } else {
      AppToast.show(context, res.msg.isNotEmpty ? res.msg : '提交失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GradientHeaderDialog(
      title: '提交作业',
      width: 428,
      contentPadding: EdgeInsets.fromLTRB(ui(24), ui(60), ui(24), ui(20)),
      actionBar: AppDialogActionBar(
        cancelLabel: '取消',
        confirmLabel: _submitting ? '提交中…' : (_uploading ? '上传中…' : '确认'),
        confirmEnabled: _ready && !_submitting,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.data.title,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 20 / 14,
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            '${_subjectLabelOf(widget.data.subject)}·截止${widget.data.deadline}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 12,
            ),
          ),
          if (widget.data.mediumLabel.trim().isNotEmpty &&
              widget.data.mediumLabel != '附件') ...[
            SizedBox(height: ui(4)),
            Text(
              '建议提交：${widget.data.mediumLabel}',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 12,
              ),
            ),
          ],
          if (widget.data.requirementText.trim().isNotEmpty) ...[
            SizedBox(height: ui(6)),
            Text(
              widget.data.requirementText.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.35,
              ),
            ),
          ],
          SizedBox(height: ui(12)),
          _DialogLabel('提交类型'),
          SizedBox(height: ui(8)),
          _SubmitKindRow(
            value: _kind,
            onChanged: _onKindChanged,
          ),
          SizedBox(height: ui(12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _DialogLabel('上传文件'),
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  _kind.uploadTip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextDivider,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          if (_picked == null)
            _UploadDropZone(onTap: _pickFile, label: _kind.label)
          else
            _UploadFileTile(
              file: _picked!,
              progress: _progress,
              uploading: _uploading,
              errorText: _errorText,
              done: _remotePath != null,
              onRetry: _pickFile,
              onRemove: _removeFile,
            ),
          SizedBox(height: ui(12)),
          _DialogLabel('备注（选填）'),
          SizedBox(height: ui(8)),
          _NoteInput(controller: _noteCtrl),
        ],
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w500,
        height: 20 / 14,
      ),
    );
  }
}

class _SubmitKindRow extends StatelessWidget {
  const _SubmitKindRow({required this.value, required this.onChanged});

  final _SubmitKind value;
  final ValueChanged<_SubmitKind> onChanged;

  static const _items = <(_SubmitKind, String)>[
    (_SubmitKind.video, '视频'),
    (_SubmitKind.audio, '音频'),
    (_SubmitKind.photo, '照片'),
    (_SubmitKind.doc, '文档'),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) SizedBox(width: ui(12)),
          _SubmitKindChip(
            label: _items[i].$2,
            active: _items[i].$1 == value,
            onTap: () => onChanged(_items[i].$1),
          ),
        ],
      ],
    );
  }
}

class _SubmitKindChip extends StatelessWidget {
  const _SubmitKindChip({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(24)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kTextDark : _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _UploadDropZone extends StatelessWidget {
  const _UploadDropZone({required this.onTap, required this.label});
  final VoidCallback onTap;

  /// 当前提交类型文案（视频 / 音频 / 照片 / 文档），用于「点击将X在此处上传」。
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: double.infinity,
        height: ui(120),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4FF),
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppAssets.coursewareUploadFile,
              width: ui(48),
              height: ui(48),
              fit: BoxFit.contain,
            ),
            SizedBox(height: ui(8)),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1,
                ),
                children: <InlineSpan>[
                  const TextSpan(
                    text: '点击将',
                    style: TextStyle(color: _kTextHint),
                  ),
                  TextSpan(
                    text: label,
                    style: const TextStyle(color: _kTextDark),
                  ),
                  const TextSpan(
                    text: '在此处上传',
                    style: TextStyle(color: _kTextHint),
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

class _UploadFileTile extends StatelessWidget {
  const _UploadFileTile({
    required this.file,
    required this.progress,
    required this.uploading,
    required this.errorText,
    required this.done,
    required this.onRetry,
    required this.onRemove,
  });

  final CoursewarePickedFile file;
  final double progress;
  final bool uploading;
  final String? errorText;
  final bool done;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasError = errorText != null;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(12), ui(10), ui(8), ui(10)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kPurpleLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: ui(16),
                color: _kPurple,
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 13,
                  ),
                ),
              ),
              SizedBox(width: ui(8)),
              if (uploading)
                AppLoadingIndicator()
              else
                InkWell(
                  onTap: hasError ? onRetry : onRemove,
                  child: Padding(
                    padding: EdgeInsets.all(ui(2)),
                    child: Icon(
                      hasError ? Icons.refresh_rounded : Icons.close_rounded,
                      size: ui(16),
                      color: hasError ? _kPurple : _kTextHint,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ui(6)),
          ClipRRect(
            borderRadius: BorderRadius.circular(ui(20)),
            child: LinearProgressIndicator(
              minHeight: ui(4),
              value: hasError ? 0 : (uploading ? progress : (done ? 1 : 0)),
              backgroundColor: _kBorderHair,
              valueColor: AlwaysStoppedAnimation<Color>(
                hasError ? _kOverdueRed : _kPurple,
              ),
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            hasError
                ? errorText!
                : (uploading
                      ? '上传中 ${(progress * 100).toStringAsFixed(0)}%'
                      : (done ? '上传完成' : '准备上传')),
            style: TextStyle(
              fontSize: ui(11),
              color: hasError ? _kOverdueRed : _kTextHint,
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

class _NoteInput extends StatelessWidget {
  const _NoteInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft, width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      alignment: Alignment.center,
      child: AppTextField(
        controller: controller,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: '请输入',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextDivider,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 弹窗：作业详情
// =============================================================================

class _HomeworkDetailDialog extends ConsumerStatefulWidget {
  const _HomeworkDetailDialog({required this.data});

  final _HomeworkData data;

  @override
  ConsumerState<_HomeworkDetailDialog> createState() =>
      _HomeworkDetailDialogState();
}

class _HomeworkDetailDialogState extends ConsumerState<_HomeworkDetailDialog> {
  late _HomeworkData _d;

  @override
  void initState() {
    super.initState();
    _d = widget.data;
    if (widget.data.recordId.isNotEmpty) {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;
    final id = _d.recordId.isNotEmpty ? _d.recordId : widget.data.recordId;
    final res = await ref
        .read(studentRepositoryProvider)
        .studentHomeworkDetail(id: id);
    if (!mounted) return;
    if (res.isSuccess && res.data is Map) {
      setState(() {
        _d = _HomeworkData.mergeDetail(_d, res.data as Map);
      });
    } else {
      AppToast.show(context, res.msg.isNotEmpty ? res.msg : '详情加载失败');
    }
  }

  String _statusLabel(_HomeworkData data) => switch (data.status) {
    _HomeworkStatus.pending => '待提交',
    _HomeworkStatus.overdue => '已逾期',
    _HomeworkStatus.submitted => '已提交',
    _HomeworkStatus.reviewed => '已评分',
  };

  String? _submittedAt(_HomeworkData data) {
    if (data.bodyType == _HomeworkBodyType.pending) return null;
    if (data.submitTimeDisplay.isNotEmpty) return data.submitTimeDisplay;
    return null;
  }

  String _requirement(_HomeworkData data) {
    final t = data.requirementText.trim();
    return t.isNotEmpty ? t : '—';
  }

  String _feedback(_HomeworkData data) {
    if (data.teacherFeedback.isNotEmpty) return data.teacherFeedback;
    if (data.bodyType == _HomeworkBodyType.reviewed &&
        (data.reviewText?.isNotEmpty ?? false)) {
      return data.reviewText!;
    }
    return '无';
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GradientHeaderDialog(
      title: '作业详情',
      width: 428,
      contentPadding: EdgeInsets.fromLTRB(
        ui(24),
        ui(kAppDialogTitlePaddingTop),
        ui(24),
        ui(20),
      ),
      actionBar: AppDialogActionBar(
        cancelLabel: '取消',
        confirmLabel: '确认',
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _d.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 14,
                  ),
                ),
              ),
              SizedBox(width: ui(8)),
              _SubjectTag(subject: _d.subject),
              SizedBox(width: ui(8)),
              _DetailStatusTag(label: _statusLabel(_d)),
              if (_d.score != null) ...[
                SizedBox(width: ui(8)),
                Text(
                  _d.score!,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kBlueLink,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: ui(12)),
          _DetailKeyValueRow(label: '发布老师', value: _d.teacher),
          SizedBox(height: ui(12)),
          _DetailKeyValueRow(label: '截止时间', value: _d.deadline),
          if (_d.mediumLabel.trim().isNotEmpty && _d.mediumLabel != '附件') ...[
            SizedBox(height: ui(12)),
            _DetailKeyValueRow(label: '建议提交', value: _d.mediumLabel),
          ],
          SizedBox(height: ui(12)),
          _DetailGrayPanel(
            label: '作业要求',
            children: [_DetailGrayLine(text: _requirement(_d), primary: true)],
          ),
          SizedBox(height: ui(12)),
          _DetailGrayPanel(
            label: '提交情况',
            children: [
              _DetailGrayLine(
                text: _d.submittedFile?.isNotEmpty == true
                    ? _d.submittedFile!
                    : '尚未提交',
                primary: _d.submittedFile?.isNotEmpty == true,
              ),
              if (_submittedAt(_d) != null) ...[
                SizedBox(height: ui(6)),
                _DetailGrayLine(text: '提交时间：${_submittedAt(_d)!}'),
              ],
            ],
          ),
          if (_d.submitFileUrl.trim().isNotEmpty ||
              _d.submitAttachmentName.trim().isNotEmpty ||
              _d.submitTypeTag.trim().isNotEmpty ||
              _d.studentSubmitDescription.trim().isNotEmpty) ...[
            SizedBox(height: ui(12)),
            _DetailGrayPanel(
              label: '我的提交',
              children: [
                if (_d.submitTypeTag.trim().isNotEmpty)
                  _DetailGrayLine(
                    text: '提交类型：${_d.submitTypeTag}',
                    primary: true,
                  ),
                if (_d.submitAttachmentName.trim().isNotEmpty) ...[
                  SizedBox(height: ui(6)),
                  _DetailGrayLine(
                    text: '文件：${_d.submitAttachmentName}',
                    primary: true,
                  ),
                ],
                if (_d.studentSubmitDescription.trim().isNotEmpty) ...[
                  SizedBox(height: ui(6)),
                  _DetailGrayLine(
                    text: '说明：${_d.studentSubmitDescription}',
                    primary: false,
                  ),
                ],
                if (_d.submitFileUrl.trim().isNotEmpty) ...[
                  SizedBox(height: ui(8)),
                  InkWell(
                    onTap: () => showStudentHomeworkSubmissionPreview(
                      context,
                      ref: ref,
                      fileUrl: _d.submitFileUrl,
                      title: _d.submitAttachmentName,
                      typeTag: _d.submitTypeTag,
                      mediumLabel: _d.mediumLabel,
                      attachmentName: _d.submitAttachmentName,
                    ),
                    child: Row(
                      children: [
                        HomeworkAssetIcon(
                          AppAssets.homeworkReviewPreviewIcon,
                          size: ui(16),
                        ),
                        SizedBox(width: ui(6)),
                        Text(
                          '预览提交文件',
                          style: TextStyle(
                            fontSize: ui(13),
                            color: _kBlueLink,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: _kBlueLink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          SizedBox(height: ui(12)),
          _DetailGrayPanel(
            label: '教师反馈',
            children: [
              _DetailGrayLine(
                text: _feedback(_d),
                primary: _feedback(_d) != '无',
              ),
              if (_d.voiceCommentPath.trim().isNotEmpty) ...[
                SizedBox(height: ui(8)),
                Text(
                  '语音点评',
                  style: TextStyle(
                    fontSize: ui(11),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                ),
                SizedBox(height: ui(6)),
                HomeworkVoiceCommentBubble(
                  relativePath: _d.voiceCommentPath,
                  durationSec: _d.voiceCommentDuration,
                  scale: ui(1),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _subjectLabelOf(_HomeworkSubject s) => switch (s) {
  _HomeworkSubject.music => '乐理',
  _HomeworkSubject.vocal => '声乐',
  _HomeworkSubject.vocalRed => '声乐',
};

class _DetailStatusTag extends StatelessWidget {
  const _DetailStatusTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (bg, fg) = switch (label) {
      '已提交' || '已批阅' || '已评分' => (_kSubmittedGreenBg, _kSubmittedGreen),
      '已逾期' => (_kOverdueRedBg, _kOverdueRed),
      _ => (_kPendingOrangeBg, _kPendingOrange),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
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

class _DetailKeyValueRow extends StatelessWidget {
  const _DetailKeyValueRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}

class _DetailGrayPanel extends StatelessWidget {
  const _DetailGrayPanel({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          ...children,
        ],
      ),
    );
  }
}

class _DetailGrayLine extends StatelessWidget {
  const _DetailGrayLine({required this.text, this.primary = true});
  final String text;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(12),
        color: primary ? _kTextDark : _kTextHint,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1.5,
      ),
    );
  }
}
