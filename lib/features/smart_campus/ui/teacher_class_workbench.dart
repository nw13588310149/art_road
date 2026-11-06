// =============================================================================
// 班主任端「班级工作台」独立页面
//
// 入口：班主任 dashboard 顶部「班级工作台」按钮 / 「班务 → 班级工作台 >」。
// 三个 Tab：
//   1. 概况   _OverviewTab   顶部「班级通知」(与学生「我的班级」共享 provider，
//      可发布/删除) + 双列布局：我的班级 + 待批请假 / 班级捷径 / 七日查寝 +
//      重点关注
//   2. 学生管理 _StudentsTab  标题副标题 + 搜索框 + 学生卡 3 列网格
//   3. 成绩   _GradesTab     班级成绩变化折线图 + 考试记录（分数+点评）
//
// 视觉：970 设计宽度自适应到容器宽度，左列约 0.5918，右列约 0.3959，gap 12。
// 颜色：白卡 #FFFFFF / 浅灰底 #F5F6FA / 紫色主色 #8741FF / 蓝色 #325BFF / 红色 #FF323C
// 字体：PingFang SC（标题 18 / 正文 12~14）+ Barlow（数字 20~24）
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/constants/app_assets.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_asset_graphic.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/data/shell_repository.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/state/shell_state.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/head_teacher_class_score_data.dart';
import '../data/head_teacher_index_data.dart';
import '../data/student_academic_data.dart';
import '../data/head_teacher_workbench_data.dart';
import '../data/student_leave_data.dart';
import '../data/teacher_repository.dart';
import 'student_homework_submission_preview.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stripe_bar_chart.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kPanelBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextHintLight = Color(0xFFD1D1D1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoft = Color(0xFFA773FF);
const Color _kBlue = Color(0xFF325BFF);
const Color _kRed = Color(0xFFFF323C);
const Color _kYellow = Color(0xFFDBEE49);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kAnnounceBg = Color(0xFFF0E8FC);

// ---- 班级通知数据模型（来自 API）----------------------------------------

class _NoticeItem {
  const _NoticeItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });

  final String id;
  final String title;
  final String content;
  final String date;

  factory _NoticeItem.fromMap(Map<dynamic, dynamic> m) {
    final raw = m['createTime']?.toString() ?? '';
    final date = raw.length >= 10 ? raw.substring(5, 10) : raw;
    return _NoticeItem(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      content: m['content']?.toString() ?? '',
      date: date,
    );
  }
}

// ---- 学生管理数据模型（来自 API）-----------------------------------------

String _studentGenderFromApi(dynamic raw) {
  final s = raw?.toString().trim() ?? '';
  switch (s) {
    case '1':
    case '男':
      return '男';
    case '0':
    case '2':
    case '女':
      return '女';
    case '':
      return '—';
    default:
      return s;
  }
}

class _StudentManageData {
  const _StudentManageData({
    required this.id,
    required this.name,
    required this.studentId,
    required this.dorm,
    required this.phone,
    required this.parentName,
    required this.parentPhone,
    required this.gender,
    this.role,
    this.remark,
    this.tags,
    this.tag,
    this.tagColor,
    this.tagTextColor,
    this.avatarUrl,
  });

  /// 学生主键（雪花 long 字符串），用于调用 studentDetail / studentUpdate。
  final String id;
  final String name;
  final String studentId;
  final String? role;
  final String dorm;
  final String phone;
  final String parentName;
  final String parentPhone;
  final String? remark;
  final String? tags;
  final String? tag;
  final Color? tagColor;
  final Color? tagTextColor;
  final String gender;
  final String? avatarUrl;

  factory _StudentManageData.fromMap(Map<dynamic, dynamic> m) {
    final tagsValue = m['tags'];
    final tagsRaw = tagsValue == null ? '' : tagsValue.toString().trim();
    final firstTag = tagsRaw
        .split(',')
        .where((t) => t.trim().isNotEmpty)
        .firstOrNull
        ?.trim();
    final bedInfo = m['bedInfo']?.toString().trim() ?? '';
    return _StudentManageData(
      id: readSnowflakeId(m['id']) ?? '',
      name: m['realname']?.toString().trim().isNotEmpty == true
          ? m['realname'].toString()
          : m['nickname']?.toString() ?? '—',
      studentId: m['no']?.toString() ??
          m['studentNo']?.toString() ??
          m['code']?.toString() ??
          '',
      gender: _studentGenderFromApi(m['gender']),
      dorm: bedInfo.isNotEmpty
          ? bedInfo
          : m['dormitory']?.toString() ?? m['dorm']?.toString() ?? '—',
      phone: m['mobile']?.toString() ?? m['phone']?.toString() ?? '—',
      parentName: m['parentName']?.toString() ?? m['guardianName']?.toString() ?? '—',
      parentPhone: m['parentMobile']?.toString() ?? m['guardianMobile']?.toString() ?? '—',
      role: m['classRole']?.toString() ?? m['role']?.toString(),
      remark: m['remark']?.toString(),
      tags: tagsRaw,
      tag: firstTag,
      tagColor: firstTag != null ? _kPurple : null,
      tagTextColor: firstTag != null ? Colors.white : null,
      avatarUrl: m['headUrl']?.toString() ?? m['avatar']?.toString(),
    );
  }

  _StudentManageData copyWith({String? remark, String? tags}) {
    return _StudentManageData(
      id: id,
      name: name,
      studentId: studentId,
      gender: gender,
      dorm: dorm,
      phone: phone,
      parentName: parentName,
      parentPhone: parentPhone,
      role: role,
      remark: remark ?? this.remark,
      tags: tags ?? this.tags,
      tag: (tags ?? this.tags)?.split(',').where((t) => t.trim().isNotEmpty).firstOrNull?.trim(),
      tagColor: tagColor,
      tagTextColor: tagTextColor,
      avatarUrl: avatarUrl,
    );
  }
}

enum _WorkbenchTab { overview, students, grades }

extension on _WorkbenchTab {
  String get label {
    switch (this) {
      case _WorkbenchTab.overview:
        return '概况';
      case _WorkbenchTab.students:
        return '学生管理';
      case _WorkbenchTab.grades:
        return '成绩';
    }
  }
}

class TeacherClassWorkbenchView extends ConsumerStatefulWidget {
  const TeacherClassWorkbenchView({
    super.key,
    required this.onBack,
    this.onOpenLeaveApproval,
    this.onOpenHomeSchool,
    this.onOpenGroupChat,
    this.onOpenDormHistory,
    this.onOpenPrincipalMailbox,
  });

  final VoidCallback onBack;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenHomeSchool;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenPrincipalMailbox;

  @override
  ConsumerState<TeacherClassWorkbenchView> createState() =>
      _TeacherClassWorkbenchViewState();
}

class _TeacherClassWorkbenchViewState
    extends ConsumerState<TeacherClassWorkbenchView> {
  _WorkbenchTab _tab = _WorkbenchTab.overview;

  // 当前班级（从 headTeacherIndex.classList 切换）；id 用字符串避免雪花精度丢失。
  String _classId = '0';
  int _selectedClassIndex = 0;
  HeadTeacherIndexRes _index = HeadTeacherIndexRes.zero;
  bool _loadingClass = true;
  String _classError = '';

  void _selectClass(int index) {
    if (index < 0 || index >= _index.classList.length) return;
    final item = _index.classList[index];
    setState(() {
      _selectedClassIndex = index;
      _classId = item.classId;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    final res = await ref.read(teacherRepositoryProvider).headTeacherIndex();
    if (!mounted) return;
    if (res.isSuccess) {
      final index = parseHeadTeacherIndexRes(res.data);
      if (index.classList.isNotEmpty) {
        final first = index.classList.first;
        setState(() {
          _index = index;
          _selectedClassIndex = 0;
          _classId = first.classId;
          _loadingClass = false;
        });
        return;
      }
      setState(() {
        _index = index;
        _loadingClass = false;
        _classError = '暂无绑定班级';
      });
      return;
    }
    if (mounted) {
      setState(() {
        _loadingClass = false;
        _classError = res.msg.isNotEmpty ? res.msg : '加载班级工作台失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final banner = _WorkbenchBanner(
      tab: _tab,
      onTabChanged: (t) => setState(() => _tab = t),
      onBack: widget.onBack,
    );

    if (_classError.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          banner,
          SizedBox(height: ui(60)),
          Center(
            child: Text(
              _classError,
              style: TextStyle(fontSize: ui(14), color: _kTextHint),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: ui(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          banner,
          SizedBox(height: ui(16)),
          // 不同 Tab 的主体——保持 banner 一致，下方切换内容。
          if (_loadingClass)
            const SizedBox.shrink()
          else
            switch (_tab) {
              _WorkbenchTab.overview =>
                _OverviewTab(
                  classId: _classId,
                  index: _index,
                  selectedClassIndex: _selectedClassIndex,
                  onClassChanged: _selectClass,
                  onOpenLeaveApproval: widget.onOpenLeaveApproval,
                  onOpenHomeSchool: widget.onOpenHomeSchool,
                    onOpenGroupChat: widget.onOpenGroupChat,
                    onOpenDormHistory: widget.onOpenDormHistory,
                    onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                  ),
              _WorkbenchTab.students => _StudentsTab(classId: _classId),
              _WorkbenchTab.grades => _GradesTab(classId: _classId),
            },
        ],
      ),
    );
  }
}

// =============================================================================
// 顶部 Banner：左侧返回按钮 / 居中「班级工作台」标题 / 右侧 3 段 Tab
// =============================================================================

class _WorkbenchBanner extends StatelessWidget {
  const _WorkbenchBanner({
    required this.tab,
    required this.onTabChanged,
    required this.onBack,
  });

  final _WorkbenchTab tab;
  final ValueChanged<_WorkbenchTab> onTabChanged;
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
          // 返回按钮
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
          // 居中标题
          Center(
            child: Text(
              '班级工作台',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextDark,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          // 右侧 Tab
          Positioned(
            right: ui(12),
            top: ui(15),
            child: _WorkbenchTabSegmented(tab: tab, onTabChanged: onTabChanged),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchTabSegmented extends StatelessWidget {
  const _WorkbenchTabSegmented({required this.tab, required this.onTabChanged});

  final _WorkbenchTab tab;
  final ValueChanged<_WorkbenchTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      // minHeight 而不是 fixed height：避免中文字 height:1 被切顶（与人脸库 banner tab 一致）。
      constraints: BoxConstraints(minHeight: ui(32)),
      padding: EdgeInsets.all(ui(2)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in _WorkbenchTab.values)
            _SegmentItem(
              label: t.label,
              selected: t == tab,
              onTap: () => onTabChanged(t),
            ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
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

// =============================================================================
// 概况 Tab
// =============================================================================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.classId,
    required this.index,
    required this.selectedClassIndex,
    required this.onClassChanged,
    this.onOpenLeaveApproval,
    this.onOpenHomeSchool,
    this.onOpenGroupChat,
    this.onOpenDormHistory,
    this.onOpenPrincipalMailbox,
  });

  final String classId;
  final HeadTeacherIndexRes index;
  final int selectedClassIndex;
  final ValueChanged<int> onClassChanged;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenHomeSchool;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenPrincipalMailbox;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NoticeSection(classId: classId),
        SizedBox(height: ui(20)),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final isCompact = w < ui(820);
            if (isCompact) {
              // 窄屏：单列堆叠展示。
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildLeftColumn(ui),
                  SizedBox(height: ui(20)),
                  ..._buildRightColumn(ui),
                ],
              );
            }
            const leftRatio = 574 / 970;
            const rightRatio = 384 / 970;
            final gap = ui(12);
            final leftW = (w - gap) * leftRatio / (leftRatio + rightRatio);
            final rightW = (w - gap) * rightRatio / (leftRatio + rightRatio);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildPairedSections(ui, leftW, rightW, gap),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildPairedSections(
    double Function(double) ui,
    double leftW,
    double rightW,
    double gap,
  ) {
    Widget section({
      required Widget leftTitle,
      required Widget rightTitle,
      required Widget leftBody,
      required Widget rightBody,
      required double bodyHeight,
    }) {
      return _OverviewPairedSection(
        leftWidth: leftW,
        rightWidth: rightW,
        gap: gap,
        bodyHeight: bodyHeight,
        leftTitle: leftTitle,
        rightTitle: rightTitle,
        leftBody: leftBody,
        rightBody: rightBody,
      );
    }

    return [
      section(
        leftTitle: const _SectionTitle('我的班级'),
        rightTitle: _SectionTitleWithAction(
          title: '待批请假',
          actionLabel: '全部',
          onActionTap: onOpenLeaveApproval,
        ),
        bodyHeight: 212,
        leftBody: _TeacherInfoCard(
          index: index,
          classes: index.classList,
          selectedClassIndex: selectedClassIndex,
          onClassChanged: onClassChanged,
          fillHeight: true,
        ),
        rightBody: _LeaveListCard(
          fillHeight: true,
          onOpenAll: onOpenLeaveApproval,
        ),
      ),
      SizedBox(height: ui(20)),
      section(
        leftTitle: const _SectionTitle('班级数据'),
        rightTitle: const _SectionTitle('班级捷径'),
        bodyHeight: 176,
        leftBody: _ShortcutStatGrid(
          index: index,
          fillHeight: true,
          onOpenLeaveApproval: onOpenLeaveApproval,
          onOpenDormHistory: onOpenDormHistory,
          onOpenHomeSchool: onOpenHomeSchool,
        ),
        rightBody: _QuickActionGrid(
          fillHeight: true,
          onOpenLeaveApproval: onOpenLeaveApproval,
          onOpenHomeSchool: onOpenHomeSchool,
          onOpenGroupChat: onOpenGroupChat,
          onOpenDormHistory: onOpenDormHistory,
          onOpenPrincipalMailbox: onOpenPrincipalMailbox,
        ),
      ),
      SizedBox(height: ui(20)),
      section(
        leftTitle: const _SectionTitle('七日查寝'),
        rightTitle: const _SectionTitle('重点关注'),
        bodyHeight: 312,
        leftBody: _DormNormalStatCard(fillHeight: true),
        rightBody: _AttentionListCard(
          classId: classId,
          fillHeight: true,
        ),
      ),
    ];
  }

  List<Widget> _buildLeftColumn(double Function(double) ui) {
    return [
      const _SectionTitle('我的班级'),
      SizedBox(height: ui(12)),
      _TeacherInfoCard(
        index: index,
        classes: index.classList,
        selectedClassIndex: selectedClassIndex,
        onClassChanged: onClassChanged,
      ),
      SizedBox(height: ui(20)),
      const _SectionTitle('班级捷径'),
      SizedBox(height: ui(12)),
      _ShortcutStatGrid(
        index: index,
        onOpenLeaveApproval: onOpenLeaveApproval,
        onOpenDormHistory: onOpenDormHistory,
        onOpenHomeSchool: onOpenHomeSchool,
      ),
      SizedBox(height: ui(20)),
      const _SectionTitle('七日查寝'),
      SizedBox(height: ui(12)),
      const _DormNormalStatCard(),
    ];
  }

  List<Widget> _buildRightColumn(double Function(double) ui) {
    return [
      _SectionTitleWithAction(
        title: '待批请假',
        actionLabel: '全部',
        onActionTap: onOpenLeaveApproval,
      ),
      SizedBox(height: ui(12)),
      _LeaveListCard(onOpenAll: onOpenLeaveApproval),
      SizedBox(height: ui(20)),
      const _SectionTitle('班级捷径'),
      SizedBox(height: ui(12)),
      _QuickActionGrid(
        onOpenLeaveApproval: onOpenLeaveApproval,
        onOpenHomeSchool: onOpenHomeSchool,
        onOpenGroupChat: onOpenGroupChat,
        onOpenDormHistory: onOpenDormHistory,
        onOpenPrincipalMailbox: onOpenPrincipalMailbox,
      ),
      SizedBox(height: ui(20)),
      const _SectionTitle('重点关注'),
      SizedBox(height: ui(12)),
      _AttentionListCard(classId: classId),
    ];
  }
}

/// 概况双列：同一行左右标题与内容区等高（固定设计高度，避免 IntrinsicHeight 断言）。
class _OverviewPairedSection extends StatelessWidget {
  const _OverviewPairedSection({
    required this.leftWidth,
    required this.rightWidth,
    required this.gap,
    required this.bodyHeight,
    required this.leftTitle,
    required this.rightTitle,
    required this.leftBody,
    required this.rightBody,
  });

  final double leftWidth;
  final double rightWidth;
  final double gap;
  final double bodyHeight;
  final Widget leftTitle;
  final Widget rightTitle;
  final Widget leftBody;
  final Widget rightBody;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: leftWidth, child: leftTitle),
            SizedBox(width: gap),
            SizedBox(width: rightWidth, child: rightTitle),
          ],
        ),
        SizedBox(height: ui(12)),
        SizedBox(
          height: ui(bodyHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: leftWidth,
                height: ui(bodyHeight),
                child: leftBody,
              ),
              SizedBox(width: gap),
              SizedBox(
                width: rightWidth,
                height: ui(bodyHeight),
                child: rightBody,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----- 通用：Section 标题 -----

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
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );
  }
}

class _SectionTitleWithAction extends StatelessWidget {
  const _SectionTitleWithAction({
    required this.title,
    required this.actionLabel,
    this.onActionTap,
  });
  final String title;
  final String actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(child: _SectionTitle(title)),
        InkWell(
          onTap: onActionTap,
          borderRadius: BorderRadius.circular(ui(6)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(2), vertical: ui(2)),
            child: Row(
              children: [
                Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextSecondary,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
                SizedBox(width: ui(2)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: ui(16),
                  color: const Color(0xFFCECED1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ----- 班级通知（班主任视角：发布 + 删除） -----
//
// 与学生「我的班级 → 班级通知」共享 classNoticeControllerProvider；这里
// 加一个"发布通知"按钮和卡片右上角"×"删除按钮。卡片样式与学生视角一致
// （紫底 #F0E8FC，左侧紫色方块 highlight，下方日期）。

class _NoticeSection extends ConsumerStatefulWidget {
  const _NoticeSection({required this.classId});

  final String classId;

  @override
  ConsumerState<_NoticeSection> createState() => _NoticeSectionState();
}

class _NoticeSectionState extends ConsumerState<_NoticeSection> {
  List<_NoticeItem> _notices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await ref.read(teacherRepositoryProvider).schoolClassNoticeList(
      classId: widget.classId,
      size: 20,
    );
    if (!mounted) return;
    if (res.isSuccess) {
      final raw = res.data;
      final list = (raw is Map ? raw['records'] ?? raw['list'] ?? raw : raw);
      if (list is List) {
        _notices = list
            .whereType<Map>()
            .map(_NoticeItem.fromMap)
            .toList();
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NoticeSectionHeader(
          onPublish: () => _showPublishNoticeDialog(
            context,
            ref,
            classId: widget.classId,
            onPublished: _loadNotices,
          ),
        ),
        SizedBox(height: ui(12)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: _kPanelBg,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: _loading
              ? const SizedBox.shrink()
              : _notices.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: ui(20)),
                  child: Center(
                    child: Text(
                      '暂无通知，点击右上角"发布通知"为本班发布第一条通知。',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 20 / 13,
                      ),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (ctx, c) {
                    final w = c.maxWidth;
                    final cols = w >= ui(820) ? 3 : w >= ui(560) ? 2 : 1;
                    final gap = ui(8);
                    final cardWidth = (w - gap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final n in _notices)
                          SizedBox(
                            width: cardWidth,
                            child: _NoticeCardEditable(
                              notice: n,
                              onDelete: () => _confirmDeleteNoticeItem(ctx, n),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmDeleteNoticeItem(BuildContext ctx, _NoticeItem notice) async {
    final ok = await showScaledDialog<bool>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.80),
      builder: (dialogContext) {
        final ui = DashboardScaleScope.of(dialogContext).ui;
        return GradientHeaderDialog(
          title: '删除班级通知',
          titlePaddingTop: 40,
          width: 420,
          contentPadding: EdgeInsets.fromLTRB(ui(40), ui(30), ui(40), ui(30)),
          actionBar: AppDialogActionBar(
            confirmLabel: '删除',
            cancelLabel: '取消',
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '删除后学生端「我的班级」也会同步移除该通知，操作不可撤回。',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 22 / 14,
                ),
              ),
              SizedBox(height: ui(12)),
              Container(
                padding: EdgeInsets.all(ui(10)),
                decoration: BoxDecoration(
                  color: _kAnnounceBg,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Text(
                  notice.title.isNotEmpty ? notice.title : notice.content,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    if (notice.id.isEmpty) {
      if (ctx.mounted) {
        AppToast.show(ctx, '通知 id 无效，无法删除');
      }
      return;
    }
    final res = await ref
        .read(teacherRepositoryProvider)
        .schoolClassNoticeDel(id: notice.id);
    if (!mounted || !ctx.mounted) return;
    if (res.isSuccess) {
      setState(() => _notices.removeWhere((n) => n.id == notice.id));
      AppToast.show(ctx, '班级通知已删除');
    } else {
      AppToast.show(ctx, res.msg.isNotEmpty ? res.msg : '删除失败，请重试');
    }
  }
}

class _NoticeSectionHeader extends StatelessWidget {
  const _NoticeSectionHeader({required this.onPublish});

  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(child: _SectionTitle('班级通知')),
        InkWell(
          onTap: onPublish,
          borderRadius: BorderRadius.circular(ui(8)),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(7)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [_kPurple, _kPurpleSoft],
              ),
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: ui(16), color: Colors.white),
                SizedBox(width: ui(4)),
                Text(
                  '发布通知',
                  style: TextStyle(
                    fontSize: ui(13),
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeCardEditable extends StatelessWidget {
  const _NoticeCardEditable({required this.notice, required this.onDelete});

  final _NoticeItem notice;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(8)),
      decoration: BoxDecoration(
        color: _kAnnounceBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: ui(12),
                height: ui(20),
                child: Center(
                  child: Container(
                    width: ui(8),
                    height: ui(8),
                    decoration: BoxDecoration(
                      color: _kPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              SizedBox(width: ui(6)),
              Expanded(
                child: Text(
                  notice.title.isNotEmpty ? notice.title : notice.content,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 13,
                  ),
                ),
              ),
              SizedBox(width: ui(4)),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(ui(10)),
                child: Container(
                  width: ui(20),
                  height: ui(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ui(10)),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: ui(14),
                    color: _kTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (notice.title.isNotEmpty && notice.content.isNotEmpty) ...[
            SizedBox(height: ui(4)),
            Padding(
              padding: EdgeInsets.only(left: ui(18)),
              child: Text(
                notice.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 16 / 12,
                ),
              ),
            ),
          ],
          SizedBox(height: ui(4)),
          Padding(
            padding: EdgeInsets.only(left: ui(18)),
            child: Text(
              notice.date,
              style: TextStyle(
                fontSize: ui(11),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 12 / 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// —— 发布通知弹窗 ——————————————————————————————————————————————————

Future<void> _showPublishNoticeDialog(
  BuildContext context,
  WidgetRef ref, {
  required String classId,
  required VoidCallback onPublished,
}) async {
  final titleCtrl = TextEditingController();
  final contentCtrl = TextEditingController();
  final result = await showScaledDialog<({String title, String content})>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return GradientHeaderDialog(
        title: '发布班级通知',
        titlePaddingTop: 40,
        width: 460,
        contentPadding: EdgeInsets.fromLTRB(ui(40), ui(40), ui(40), ui(30)),
        actionBar: AppDialogActionBar(
          confirmLabel: '发布',
          cancelLabel: '取消',
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () {
            final t = titleCtrl.text.trim();
            final c = contentCtrl.text.trim();
            if (t.isEmpty || c.isEmpty) return;
            Navigator.of(dialogContext).pop((title: t, content: c));
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '本通知将同步到学生「我的班级 → 班级通知」展示位，请精炼描述。',
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
            SizedBox(height: ui(16)),
            Text(
              '通知标题',
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 20 / 14,
              ),
            ),
            SizedBox(height: ui(8)),
            Container(
              height: ui(44),
              padding: EdgeInsets.symmetric(horizontal: ui(16)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderSoft, width: 1),
              ),
              alignment: Alignment.centerLeft,
              child: AppTextField(
                controller: titleCtrl,
                autofocus: true,
                maxLines: 1,
                cursorColor: _kPurple,
                cursorWidth: 1.5,
                cursorHeight: ui(16),
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
                decoration: InputDecoration(
                  hintText: '示例：本周五合唱排练通知',
                  hintStyle: TextStyle(
                    fontSize: ui(14),
                    color: _kTextHintLight,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            SizedBox(height: ui(12)),
            Text(
              '通知内容',
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 20 / 14,
              ),
            ),
            SizedBox(height: ui(8)),
            Container(
              height: ui(100),
              padding: EdgeInsets.symmetric(
                horizontal: ui(16),
                vertical: ui(12),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(8)),
                border: Border.all(color: _kBorderSoft, width: 1),
              ),
              child: AppTextField(
                controller: contentCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
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
                  hintText: '示例：本周五16:30合唱排练，地点音乐厅A201。',
                  hintStyle: TextStyle(
                    fontSize: ui(14),
                    color: _kTextHintLight,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 20 / 14,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  if (result != null && context.mounted) {
    final res = await ref.read(teacherRepositoryProvider).schoolClassNoticeSave(
      classId: classId,
      title: result.title,
      content: result.content,
    );
    if (!context.mounted) return;
    if (res.isSuccess) {
      AppToast.show(context, '班级通知已发布');
      onPublished();
    } else {
      AppToast.show(context, res.msg.isNotEmpty ? res.msg : '发布失败，请重试');
    }
  }
}


// ----- 我的班级 卡片 -----

/// 从 `/app/user/myInfo` 的 `user` 节点提取班主任个人信息。
class _MyInfoProfile {
  const _MyInfoProfile({
    required this.displayName,
    required this.avatarUrl,
    required this.identity,
    required this.introduce,
  });

  final String displayName;
  final String avatarUrl;
  final String identity;
  final String introduce;

  String get subtitle {
    if (identity.isNotEmpty) return identity;
    if (introduce.isNotEmpty) return introduce;
    return '班主任';
  }

  factory _MyInfoProfile.fromShellUser(ShellUser user) {
    return _MyInfoProfile(
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      identity: user.identity,
      introduce: '',
    );
  }

  factory _MyInfoProfile.fromUserMap(Map<dynamic, dynamic> map) {
    final nickname = map['nickname']?.toString().trim() ?? '';
    final realname = map['realname']?.toString().trim() ?? '';
    final displayName = nickname.isNotEmpty
        ? nickname
        : (realname.isNotEmpty ? realname : '用户');
    return _MyInfoProfile(
      displayName: displayName,
      avatarUrl: map['headUrl']?.toString().trim() ?? '',
      identity: map['identity']?.toString().trim() ?? '',
      introduce: map['introduce']?.toString().trim() ?? '',
    );
  }
}

Map<dynamic, dynamic>? _extractMyInfoUser(dynamic data) {
  if (data is! Map) return null;
  final user = data['user'];
  if (user is Map) return user;
  return data;
}

class _TeacherInfoCard extends ConsumerStatefulWidget {
  const _TeacherInfoCard({
    required this.index,
    required this.classes,
    required this.selectedClassIndex,
    required this.onClassChanged,
    this.fillHeight = false,
  });

  final HeadTeacherIndexRes index;
  final List<HeadTeacherClassItem> classes;
  final int selectedClassIndex;
  final ValueChanged<int> onClassChanged;
  final bool fillHeight;

  @override
  ConsumerState<_TeacherInfoCard> createState() => _TeacherInfoCardState();
}

class _TeacherInfoCardState extends ConsumerState<_TeacherInfoCard> {
  _MyInfoProfile? _profile;
  late PageController _pageController;

  int get _maxIndex =>
      widget.classes.isEmpty ? 0 : widget.classes.length - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.selectedClassIndex.clamp(0, _maxIndex),
    );
    _loadMyInfo();
  }

  @override
  void didUpdateWidget(covariant _TeacherInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedClassIndex != widget.selectedClassIndex &&
        _pageController.hasClients) {
      final target = widget.selectedClassIndex.clamp(0, _maxIndex);
      if ((_pageController.page ?? target).round() != target) {
        _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMyInfo() async {
    final shellUser = ref.read(shellControllerProvider).user;
    if (mounted) {
      setState(() => _profile = _MyInfoProfile.fromShellUser(shellUser));
    }

    final res = await ref.read(shellRepositoryProvider).getMyInfo();
    if (!mounted || !res.isSuccess) return;
    final userMap = _extractMyInfoUser(res.data);
    if (userMap == null) return;
    setState(() => _profile = _MyInfoProfile.fromUserMap(userMap));
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final shellUser = ref.watch(shellControllerProvider).user;
    final profile = _profile ?? _MyInfoProfile.fromShellUser(shellUser);
    final classes = widget.classes;
    final hasMultiple = classes.length > 1;
    // 单页内容高度：header + 班级信息 + 统计 + 内边距。
    final pageHeight = ui(212);

    if (classes.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        padding: EdgeInsets.all(ui(12)),
        child: Text(
          '暂无班级',
          style: TextStyle(fontSize: ui(12), color: _kTextHint),
        ),
      );
    }

    if (!widget.fillHeight) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _teacherInfoPanel(ui, pageHeight, classes, profile),
          if (hasMultiple) ...[
            SizedBox(height: ui(10)),
            _classPagerDots(ui, classes),
          ],
        ],
      );
    }

    // 配对行已给出固定高度；用 LayoutBuilder 分配面板与指示点，避免 Expanded 在无界父级下断言。
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final dotsBlock = hasMultiple ? ui(10) + ui(6) : 0.0;
        final panelH = maxH.isFinite
            ? math.max(0.0, maxH - dotsBlock)
            : pageHeight;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: panelH,
              child: _teacherInfoPanel(ui, panelH, classes, profile),
            ),
            if (hasMultiple) ...[
              SizedBox(height: ui(10)),
              _classPagerDots(ui, classes),
            ],
          ],
        );
      },
    );
  }

  Widget _classPagerDots(
    double Function(double) ui,
    List<HeadTeacherClassItem> classes,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < classes.length; i++) ...[
          if (i > 0) SizedBox(width: ui(6)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == widget.selectedClassIndex ? ui(14) : ui(6),
            height: ui(6),
            decoration: BoxDecoration(
              color: i == widget.selectedClassIndex
                  ? _kPurple
                  : const Color(0xFFD9D9DE),
              borderRadius: BorderRadius.circular(ui(3)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _teacherInfoPanel(
    double Function(double) ui,
    double panelHeight,
    List<HeadTeacherClassItem> classes,
    _MyInfoProfile profile,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: panelHeight,
        child: PageView.builder(
          controller: _pageController,
          itemCount: classes.length,
          onPageChanged: widget.onClassChanged,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.all(ui(8)),
              child: _ClassCardPage(
                profile: profile,
                classItem: classes[index],
                index: widget.index,
                compact: widget.fillHeight,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 单张班级卡内容（个人信息 + 当前班级 + 统计）。
class _ClassCardPage extends StatelessWidget {
  const _ClassCardPage({
    required this.profile,
    required this.classItem,
    required this.index,
    this.compact = false,
  });

  final _MyInfoProfile profile;
  final HeadTeacherClassItem classItem;
  final HeadTeacherIndexRes index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final stats = _TeacherInfoStats(
      index: index,
      boxHeight: ui(compact ? 70 : 78),
    );

    if (!compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeacherInfoHeader(
            profile: profile,
            enrolledCount: classItem.studentCount,
          ),
          SizedBox(height: ui(12)),
          _ClassMetaRow(classItem: classItem),
          SizedBox(height: ui(14)),
          stats,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        _TeacherInfoHeader(
          profile: profile,
          enrolledCount: classItem.studentCount,
        ),
        SizedBox(height: ui(10)),
        _ClassMetaRow(classItem: classItem),
        SizedBox(height: ui(10)),
        Expanded(child: stats),
      ],
    );
  }
}

class _ClassMetaRow extends StatelessWidget {
  const _ClassMetaRow({required this.classItem});

  final HeadTeacherClassItem classItem;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '带班：',
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
            Expanded(
              child: Text(
                classItem.className,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: ui(6)),
        Text(
          '${classItem.studentCount} 人',
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _TeacherInfoHeader extends StatelessWidget {
  const _TeacherInfoHeader({
    required this.profile,
    required this.enrolledCount,
  });

  final _MyInfoProfile profile;
  final int enrolledCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: ui(56),
          height: ui(56),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _WorkbenchAvatar(
                avatarUrl: profile.avatarUrl,
                size: ui(48),
                fallbackName: profile.displayName,
              ),
              Positioned(
                left: 0,
                top: ui(36),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(7),
                    vertical: ui(2),
                  ),
                  decoration: BoxDecoration(
                    color: _kYellow,
                    borderRadius: BorderRadius.circular(ui(10)),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '班主任',
                    style: TextStyle(
                      fontSize: ui(11),
                      color: _kTextDark,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
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
                  Flexible(
                    child: Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(16),
                        color: _kTextDark,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(width: ui(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui(8),
                      vertical: ui(4),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(4)),
                      border: Border.all(color: _kBorderSoft, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: ui(6),
                          height: ui(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF12C58A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        Text(
                          '运行中',
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextDark,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                profile.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        _HeaderStat(
          label: '在籍人数',
          value: enrolledCount.toString(),
        ),
      ],
    );
  }
}

class _WorkbenchAvatar extends StatelessWidget {
  const _WorkbenchAvatar({
    required this.avatarUrl,
    required this.size,
    this.fallbackName,
  });

  final String avatarUrl;
  final double size;
  final String? fallbackName;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final raw = avatarUrl.trim();
    final resolved = raw.isNotEmpty ? MediaUrl.resolve(raw) : '';
    Widget child;
    if (resolved.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          resolved,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(ui),
        ),
      );
    } else {
      child = _fallback(ui);
    }
    return SizedBox(width: size, height: size, child: child);
  }

  Widget _fallback(double Function(double) ui) {
    final name = fallbackName?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _kPurple,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      alignment: Alignment.center,
      child: name.isNotEmpty
          ? Text(
              name.characters.first,
              style: TextStyle(
                fontSize: ui(18),
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            )
          : Icon(Icons.person_rounded, size: ui(22), color: Colors.white),
    );
  }
}

/// 学生管理头像：相对路径经 [MediaUrl.resolve] 补全域名后加载。
class _StudentManageAvatar extends StatelessWidget {
  const _StudentManageAvatar({
    required this.rawHeadUrl,
    required this.name,
    required this.size,
  });

  final String? rawHeadUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = ui(8);
    final raw = rawHeadUrl?.trim() ?? '';
    final url = raw.isNotEmpty ? MediaUrl.resolve(raw) : '';
    final initial = name.trim().isNotEmpty ? name.characters.first : '';

    Widget child;
    if (url.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(ui, radius, initial),
        ),
      );
    } else {
      child = _fallback(ui, radius, initial);
    }
    return SizedBox(width: size, height: size, child: child);
  }

  Widget _fallback(
    double Function(double) ui,
    double radius,
    String initial,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _kPurpleSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: initial.isNotEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontSize: ui(size * 0.38),
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            )
          : Icon(Icons.person_rounded, size: ui(size * 0.5), color: Colors.white),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(4)),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(24),
            color: _kPurple,
            fontWeight: FontWeight.w500,
            fontFamily: 'Barlow',
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _TeacherInfoStats extends StatelessWidget {
  const _TeacherInfoStats({
    required this.index,
    this.boxHeight,
  });

  final HeadTeacherIndexRes index;
  final double? boxHeight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final h = boxHeight ?? ui(78);
    Widget box(String label, String value) => Expanded(
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: _kInnerGray,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
            SizedBox(height: ui(8)),
            Text(
              value,
              style: TextStyle(
                fontSize: ui(24),
                color: _kTextDark,
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        box('待批请假', index.pendingLeaveCount.toString()),
        SizedBox(width: ui(13)),
        box('待批补卡', index.pendingMakeupCount.toString()),
        SizedBox(width: ui(13)),
        box('家校未读', index.chatUnreadCount.toString()),
      ],
    );
  }
}

// ----- 班级捷径（左：4 张统计 + 操作链接） -----

class _ShortcutStatGrid extends StatelessWidget {
  const _ShortcutStatGrid({
    required this.index,
    this.fillHeight = false,
    this.onOpenLeaveApproval,
    this.onOpenDormHistory,
    this.onOpenHomeSchool,
  });

  final HeadTeacherIndexRes index;
  final bool fillHeight;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenHomeSchool;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    Widget cell({
      required String value,
      required String label,
      String? actionLabel,
      VoidCallback? onActionTap,
    }) {
      return Expanded(
        child: Container(
          height: ui(82),
          padding: EdgeInsets.fromLTRB(ui(24), ui(8), ui(24), ui(8)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(24),
                        color: _kTextDark,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextSecondary,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && onActionTap != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onActionTap,
                      borderRadius: BorderRadius.circular(ui(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: TextStyle(
                              fontSize: ui(14),
                              color: _kPurple,
                              fontWeight: FontWeight.w400,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: ui(2)),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: ui(16),
                            color: _kPurple,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final grid = Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Row(
          children: [
            cell(
              value: '92%',
              label: '今日出勤率',
            ),
            SizedBox(width: ui(12)),
            cell(
              value: index.pendingLeaveCount.toString(),
              label: '待批请假',
              actionLabel: index.pendingLeaveCount > 0 ? '去处理' : null,
              onActionTap: onOpenLeaveApproval,
            ),
          ],
        ),
        SizedBox(height: ui(12)),
        Row(
          children: [
            cell(
              value: index.todayAbnormalDormCount.toString(),
              label: '查寝异常',
              actionLabel: index.todayAbnormalDormCount > 0 ? '查看' : null,
              onActionTap: onOpenDormHistory,
            ),
            SizedBox(width: ui(12)),
            cell(
              value: index.chatUnreadCount.toString(),
              label: '家校未读',
              actionLabel: index.chatWaitingCount > 0 ? '回复' : null,
              onActionTap: onOpenHomeSchool,
            ),
          ],
        ),
      ],
    );
    if (!fillHeight) return grid;
    return Align(alignment: Alignment.center, child: grid);
  }
}

// ----- 班级捷径（右：紫色图标按钮，每行最多 3 个） -----

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    this.fillHeight = false,
    this.onOpenLeaveApproval,
    this.onOpenHomeSchool,
    this.onOpenGroupChat,
    this.onOpenDormHistory,
    this.onOpenPrincipalMailbox,
  });

  final bool fillHeight;
  final VoidCallback? onOpenLeaveApproval;
  final VoidCallback? onOpenHomeSchool;
  final VoidCallback? onOpenGroupChat;
  final VoidCallback? onOpenDormHistory;
  final VoidCallback? onOpenPrincipalMailbox;

  static const List<_QuickActionData> _items = [
    _QuickActionData(
      label: '校长信箱',
      imagePath:
          'assets/images/smartCampus/home_actions/head_teacher/principal_mailbox.png',
    ),
    _QuickActionData(
      label: '请假审批',
      imagePath:
          'assets/images/smartCampus/home_actions/head_teacher/leave_approval.png',
    ),
    _QuickActionData(
      label: '家校沟通',
      imagePath:
          'assets/images/smartCampus/home_actions/head_teacher/home_school_communication.png',
    ),
    _QuickActionData(
      label: '班级群聊',
      imagePath:
          'assets/images/smartCampus/home_actions/head_teacher/group_chat.png',
    ),
    _QuickActionData(
      label: '查寝历史',
      imagePath:
          'assets/images/smartCampus/home_actions/head_teacher/dorm_history.png',
    ),
  ];

  VoidCallback? _onTapForLabel(String label) {
    return switch (label) {
      '校长信箱' => onOpenPrincipalMailbox,
      '请假审批' => onOpenLeaveApproval,
      '家校沟通' => onOpenHomeSchool,
      '班级群聊' => onOpenGroupChat,
      '查寝历史' => onOpenDormHistory,
      _ => null,
    };
  }

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final rowCount = (_items.length + _columns - 1) ~/ _columns;
    return Container(
      width: double.infinity,
      height: fillHeight ? double.infinity : null,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      alignment: fillHeight ? Alignment.center : null,
      child: Column(
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment:
            fillHeight ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          for (var row = 0; row < rowCount; row++) ...[
            if (row > 0) SizedBox(height: ui(12)),
            Row(
              children: [
                for (var col = 0; col < _columns; col++) ...[
                  if (col > 0) SizedBox(width: ui(8)),
                  Expanded(
                    child: row * _columns + col < _items.length
                        ? _QuickActionTile(
                            data: _items[row * _columns + col],
                            onTap: _onTapForLabel(
                              _items[row * _columns + col].label,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({required this.label, required this.imagePath});
  final String label;
  final String imagePath;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data, this.onTap});

  final _QuickActionData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: ui(44),
              height: ui(44),
              decoration: BoxDecoration(
                color: const Color(0xFFEAE5FF),
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                data.imagePath,
                width: ui(28),
                height: ui(28),
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: ui(6)),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSection,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- 七日查寝 柱状图 -----

class _DormNormalStatCard extends ConsumerStatefulWidget {
  const _DormNormalStatCard({this.fillHeight = false});

  final bool fillHeight;

  @override
  ConsumerState<_DormNormalStatCard> createState() => _DormNormalStatCardState();
}

class _DormNormalStatCardState extends ConsumerState<_DormNormalStatCard> {
  List<DormNormalStatDay> _days = const [];
  List<int> _ticks = const [10, 8, 6, 4, 2, 0];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStat();
  }

  Future<void> _loadStat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final (beginDate, endDate) = headTeacherWorkbenchLastSevenDaysRange();
    final resp = await ref.read(teacherRepositoryProvider).dormNormalStat(
      beginDate: beginDate,
      endDate: endDate,
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _days = const [];
        _loading = false;
        _error = resp.displayMsg.isNotEmpty ? resp.displayMsg : '加载七日查寝失败';
      });
      return;
    }
    final days = parseDormNormalStat(
      resp.data,
      beginDate: beginDate,
      endDate: endDate,
    );
    final maxCount = days.fold<int>(
      0,
      (max, day) => day.normalCount > max ? day.normalCount : max,
    );
    setState(() {
      _days = days;
      _ticks = buildDormNormalStatAxisTicks(maxCount);
      _loading = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final maxValue = _ticks.first;

    return Container(
      width: double.infinity,
      height: widget.fillHeight ? double.infinity : null,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: _loading
          ? const SizedBox.shrink()
          : _days.isEmpty
              ? Center(
                  child: Text(
                    _error ?? '暂无查寝统计',
                    style: TextStyle(fontSize: ui(12), color: _kTextHint),
                  ),
                )
              : SmartCampusStripeBarChart(
                  ticks: _ticks,
                  yAxisUnit: '人',
                  maxValue: maxValue <= 0 ? 1 : maxValue.toDouble(),
                  entries: [
                    for (final day in _days)
                      SmartCampusBarChartEntry(
                        label: day.weekdayLabel,
                        value: day.normalCount.toDouble(),
                      ),
                  ],
                ),
    );
  }
}

// ----- 待批请假 列表 -----

class _LeaveListCard extends ConsumerStatefulWidget {
  const _LeaveListCard({
    this.fillHeight = false,
    this.onOpenAll,
  });

  final bool fillHeight;
  final VoidCallback? onOpenAll;

  @override
  ConsumerState<_LeaveListCard> createState() => _LeaveListCardState();
}

class _LeaveListCardState extends ConsumerState<_LeaveListCard> {
  List<_LeaveItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    final resp = await ref.read(teacherRepositoryProvider).headTeacherStudentLeaveList(
      current: 1,
      size: 10,
      statusList: const [0, 1],
    );
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _items = const [];
        _loading = false;
        _error = resp.displayMsg.isNotEmpty ? resp.displayMsg : '加载待批请假失败';
      });
      return;
    }
    final records = parseStudentLeaveList(resp.data);
    setState(() {
      _items = records.take(2).map(_mapLeaveRecord).toList();
      _loading = false;
      _error = null;
    });
  }

  _LeaveItem _mapLeaveRecord(StudentLeaveRecord record) {
    final (tagColor, tagTextColor) = switch (record.leaveType) {
      '病假' => (_kYellow, _kTextDark),
      '事假' => (_kPurple, Colors.white),
      _ => (_kInnerGray, _kTextSecondary),
    };
    return _LeaveItem(
      name: record.studentName,
      headUrl: record.headUrl,
      timeRange: _formatLeaveTimeRange(record.timeRange),
      submitted: record.appliedAt.isNotEmpty
          ? '提交于${_formatLeaveSubmitted(record.appliedAt)}'
          : '',
      tag: record.leaveType,
      tagColor: tagColor,
      tagTextColor: tagTextColor,
    );
  }

  String _formatLeaveTimeRange(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '—') return '—';
    return trimmed
        .replaceAllMapped(
          RegExp(r'(\d{4})-(\d{2})-(\d{2})'),
          (m) => '${int.parse(m.group(2)!)}月${int.parse(m.group(3)!)}日',
        )
        .replaceAll(' - ', '-');
  }

  String _formatLeaveSubmitted(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (trimmed.startsWith(today)) {
      final hm = trimmed.length >= 16 ? trimmed.substring(11, 16) : '';
      return hm.isNotEmpty ? '今天$hm' : '今天';
    }
    return trimmed.length >= 16 ? trimmed.substring(5, 16) : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: widget.fillHeight ? double.infinity : null,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: _loading
          ? const SizedBox.shrink()
          : _items.isEmpty
              ? Center(
                  child: Text(
                    _error ?? '暂无待批请假',
                    style: TextStyle(fontSize: ui(12), color: _kTextHint),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _items.length; i++) ...[
                      if (i > 0) SizedBox(height: ui(12)),
                      _PersonRowCard(
                        avatarSeed: _items[i].name.characters.first,
                        headUrl: _items[i].headUrl,
                        name: _items[i].name,
                        line2: _items[i].timeRange,
                        line3: _items[i].submitted,
                        tag: _items[i].tag,
                        tagColor: _items[i].tagColor,
                        tagTextColor: _items[i].tagTextColor,
                        onTap: widget.onOpenAll,
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _LeaveItem {
  const _LeaveItem({
    required this.name,
    this.headUrl,
    required this.timeRange,
    required this.submitted,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
  });
  final String name;
  final String? headUrl;
  final String timeRange;
  final String submitted;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
}

// ----- 重点关注 列表 -----

class _AttentionListCard extends ConsumerStatefulWidget {
  const _AttentionListCard({
    required this.classId,
    this.fillHeight = false,
  });

  final String classId;
  final bool fillHeight;

  @override
  ConsumerState<_AttentionListCard> createState() => _AttentionListCardState();
}

class _AttentionListCardState extends ConsumerState<_AttentionListCard> {
  List<FocusStudentItem> _items = const [];
  bool _loading = true;
  String? _error;
  String? _loadedClassId;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant _AttentionListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final resp = await ref.read(teacherRepositoryProvider).focusStudentList();
    if (!mounted) return;
    if (!resp.isSuccess) {
      setState(() {
        _items = const [];
        _loading = false;
        _error = resp.displayMsg.isNotEmpty ? resp.displayMsg : '加载重点关注失败';
        _loadedClassId = widget.classId;
      });
      return;
    }
    final all = parseFocusStudentList(resp.data);
    final filtered = widget.classId.isEmpty
        ? all
        : all
            .where((item) => item.classId.isEmpty || item.classId == widget.classId)
            .toList();
    setState(() {
      _items = filtered;
      _loading = false;
      _error = null;
      _loadedClassId = widget.classId;
    });
  }

  Future<void> _confirmRemove(FocusStudentItem item) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: '取消关注',
      content: '确定取消对「${item.studentName}」的重点关注吗？',
      confirmLabel: '取消关注',
      cancelLabel: '保留',
    );
    if (confirmed != true || !mounted) return;

    final resp = await ref.read(teacherRepositoryProvider).focusStudentRemove(
      id: item.studentId,
    );
    if (!mounted) return;
    if (resp.isSuccess) {
      AppToast.show(context, '已取消关注');
      await _loadItems();
    } else {
      AppToast.show(
        context,
        resp.displayMsg.isNotEmpty ? resp.displayMsg : '取消关注失败',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final displayItems = _items.take(3).toList();

    return Container(
      width: double.infinity,
      height: widget.fillHeight ? double.infinity : null,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      clipBehavior: widget.fillHeight ? Clip.antiAlias : Clip.none,
      child: _loading
          ? const SizedBox.shrink()
          : displayItems.isEmpty
              ? Center(
                  child: Text(
                    _error ??
                        (_loadedClassId == widget.classId
                            ? '暂无重点关注学生'
                            : '加载中…'),
                    style: TextStyle(fontSize: ui(12), color: _kTextHint),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < displayItems.length; i++) ...[
                      if (i > 0) SizedBox(height: ui(12)),
                      _PersonRowCard(
                        avatarSeed: displayItems[i].avatarChar,
                        headUrl: displayItems[i].studentHeadUrl,
                        name: displayItems[i].studentName,
                        line2: displayItems[i].reason.isNotEmpty
                            ? displayItems[i].reason
                            : displayItems[i].className,
                        line3: formatFocusStudentTime(displayItems[i].time),
                        tag: displayItems[i].tag.isNotEmpty
                            ? displayItems[i].tag
                            : '重点关注',
                        tagColor: focusStudentTagColors(displayItems[i].tag).$1,
                        tagTextColor:
                            focusStudentTagColors(displayItems[i].tag).$2,
                        onTap: () => _confirmRemove(displayItems[i]),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _PersonRowCard extends StatelessWidget {
  const _PersonRowCard({
    required this.avatarSeed,
    this.headUrl,
    required this.name,
    required this.line2,
    required this.line3,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
    this.onTap,
  });

  final String avatarSeed;
  final String? headUrl;
  final String name;
  final String line2;
  final String line3;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final card = Container(
      height: ui(88),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 主体
          Padding(
            padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPersonAvatar(ui),
                SizedBox(width: ui(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(14),
                          color: _kTextDark,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: ui(6)),
                      Text(
                        line2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextSecondary,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: ui(6)),
                      Text(
                        line3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(10),
                          color: _kTextHint,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 右上角标签
          Positioned(
            right: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(ui(12)),
                bottomLeft: Radius.circular(ui(12)),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(10),
                  vertical: ui(3),
                ),
                color: tagColor,
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: tagTextColor,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(12)),
        child: card,
      ),
    );
  }

  Widget _buildPersonAvatar(double Function(double) ui) {
    final size = ui(40);
    final radius = ui(20);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _kPurpleSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        avatarSeed,
        style: TextStyle(
          fontSize: ui(15),
          color: Colors.white,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
    final url = headUrl?.trim() ?? '';
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

// =============================================================================
// 学生管理 Tab
// =============================================================================

class _StudentsTab extends ConsumerStatefulWidget {
  const _StudentsTab({required this.classId});

  final String classId;

  @override
  ConsumerState<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<_StudentsTab> {
  String _query = '';
  List<_StudentManageData> _allStudents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final res = await ref.read(teacherRepositoryProvider).studentList(
      classId: widget.classId,
      size: 1000,
    );
    if (!mounted) return;
    if (res.isSuccess) {
      final raw = res.data;
      final list = (raw is Map ? raw['records'] ?? raw['list'] ?? raw : raw);
      if (list is List) {
        _allStudents = list
            .whereType<Map>()
            .map(_StudentManageData.fromMap)
            .toList();
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _openStudentDetail(_StudentManageData student) async {
    final saved = await _showStudentDetail(
      context,
      student,
      classId: widget.classId,
    );
    if (saved == true) {
      await _loadStudents(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final filtered = _query.trim().isEmpty
        ? _allStudents
        : _allStudents.where((s) {
            final q = _query.toLowerCase();
            return s.name.toLowerCase().contains(q) ||
                s.studentId.toLowerCase().contains(q) ||
                s.dorm.toLowerCase().contains(q) ||
                s.phone.contains(q) ||
                s.parentPhone.contains(q);
          }).toList();

    final pageLoading = _loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StudentsHeader(
          total: pageLoading ? 0 : _allStudents.length,
          onQueryChanged: (v) => setState(() => _query = v),
        ),
        SizedBox(height: ui(16)),
        if (pageLoading && _allStudents.isEmpty)
          const SizedBox.shrink()
        else if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: ui(40)),
              child: Text(
                _query.isEmpty ? '暂无学生数据' : '未找到匹配学生',
                style: TextStyle(fontSize: ui(14), color: _kTextHint),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final gap = ui(12);
              final minCardW = ui(280);
              final cols = math.max(
                1,
                math.min(3, ((c.maxWidth + gap) / (minCardW + gap)).floor()),
              );
              final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final s in filtered)
                    SizedBox(
                      width: cardW,
                      child: _StudentManageCard(
                        data: s,
                        onTap: () => _openStudentDetail(s),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _StudentsHeader extends StatelessWidget {
  const _StudentsHeader({required this.onQueryChanged, required this.total});
  final ValueChanged<String> onQueryChanged;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SectionTitle('学生管理'),
              SizedBox(height: ui(4)),
              Text(
                total > 0
                    ? '共 $total 名学生 · 学生及家长信息仅查看，可编辑标签与备注'
                    : '学生及家长信息仅查看，可编辑标签与备注',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: ui(12)),
        // 搜索框
        SizedBox(
          width: ui(324),
          child: Container(
            height: ui(40),
            padding: EdgeInsets.symmetric(horizontal: ui(16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Row(
              children: [
                AppAssetGraphic(
                  AppAssets.shellV2Search,
                  width: ui(16),
                  height: ui(16),
                  fit: BoxFit.contain,
                ),
                SizedBox(width: ui(8)),
                Expanded(
                  child: AppTextField(
                    onChanged: onQueryChanged,
                    cursorColor: _kPurple,
                    cursorWidth: 1.5,
                    cursorHeight: ui(16),
                    decoration: InputDecoration(
                      hintText: '搜索姓名、学号、手机、宿舍、家长',
                      hintStyle: TextStyle(
                        fontSize: ui(14),
                        color: const Color(0xFFD1D1D1),
                        fontWeight: FontWeight.w400,
                      ),
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: ui(14), color: _kTextSection),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _StudentManageCard extends StatelessWidget {
  const _StudentManageCard({required this.data, this.onTap});
  final _StudentManageData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = BorderRadius.circular(ui(12));
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius: radius,
        ),
        child: SizedBox(
          height: ui(156),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Padding(
                padding: EdgeInsets.all(ui(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 头像 + 姓名 + 性别 icon + 职务
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StudentManageAvatar(
                          rawHeadUrl: data.avatarUrl,
                          name: data.name,
                          size: ui(40),
                        ),
                        SizedBox(width: ui(8)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    data.name,
                                    style: TextStyle(
                                      fontSize: ui(14),
                                      color: _kTextDark,
                                      fontWeight: FontWeight.w500,
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(width: ui(4)),
                                  Image.asset(
                                    data.gender == '男'
                                        ? AppAssets.iconGenderMale
                                        : AppAssets.iconGenderFemale,
                                    width: ui(14),
                                    height: ui(14),
                                    fit: BoxFit.contain,
                                  ),
                                  if (data.role != null) ...[
                                    SizedBox(width: ui(8)),
                                    Text(
                                      data.role!,
                                      style: TextStyle(
                                        fontSize: ui(12),
                                        color: _kPurple,
                                        fontWeight: FontWeight.w400,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: ui(6)),
                              Text(
                                data.dorm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextDark,
                                  fontWeight: FontWeight.w400,
                                  height: 1,
                                ),
                              ),
                              SizedBox(height: ui(6)),
                              Text(
                                data.studentId,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  color: _kTextHint,
                                  fontWeight: FontWeight.w400,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(12)),
                    // 电话信息
                    Container(
                      padding: EdgeInsets.symmetric(vertical: ui(12)),
                      decoration: BoxDecoration(
                        color: _kInnerGray,
                        borderRadius: BorderRadius.circular(ui(8)),
                      ),
                      child: Row(
                        children: [
                          _phoneCell('本人电话', data.phone),
                          _phoneCell(
                            '家长电话',
                            data.parentPhone,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 右上角标签
              if (data.tag != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(ui(12)),
                      bottomLeft: Radius.circular(ui(12)),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(12),
                        vertical: ui(3),
                      ),
                      color: data.tagColor ?? _kPurple,
                      child: Text(
                        data.tag!,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: data.tagTextColor ?? Colors.white,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneCell(String label, String value) => Builder(
    builder: (context) {
      final ui = DashboardScaleScope.of(context).ui;
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
            SizedBox(height: ui(8)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
          ],
        ),
      );
    },
  );
}

// =============================================================================
// 成绩 Tab
// =============================================================================

class _GradesTab extends ConsumerStatefulWidget {
  const _GradesTab({required this.classId});

  final String classId;

  @override
  ConsumerState<_GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends ConsumerState<_GradesTab> {
  HeadTeacherClassScoreOverview _overview = HeadTeacherClassScoreOverview.zero;
  int _examIdx = 0;
  String? _selectedExamId;
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  void didUpdateWidget(covariant _GradesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _loadOverview();
    }
  }

  Future<void> _loadOverview({
    String? examId,
    int pageNum = 1,
    bool append = false,
  }) async {
    if (widget.classId.isEmpty || widget.classId == '0') {
      setState(() {
        _loading = false;
        _overview = HeadTeacherClassScoreOverview.zero;
        _error = '暂无绑定班级';
      });
      return;
    }

    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    final res = await ref.read(teacherRepositoryProvider).headTeacherClassScoreOverview(
      classId: widget.classId,
      examId: examId ?? _selectedExamId,
      pageNum: pageNum,
      pageSize: 10,
    );
    if (!mounted) return;

    if (!res.isSuccess) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (!append) {
          _overview = HeadTeacherClassScoreOverview.zero;
          _error = res.msg.isNotEmpty ? res.msg : '加载成绩数据失败';
        }
      });
      return;
    }

    final parsed = HeadTeacherClassScoreOverview.fromData(res.data);
    setState(() {
      if (append) {
        final merged = [
          ..._overview.studentScores.records,
          ...parsed.studentScores.records,
        ];
        _overview = HeadTeacherClassScoreOverview(
          examAxis: parsed.examAxis,
          trendLines: parsed.trendLines,
          examTabs: parsed.examTabs,
          currentExamId: parsed.currentExamId,
          studentScores: HeadTeacherStudentScoresPage(
            records: merged,
            total: parsed.studentScores.total,
            pageNum: parsed.studentScores.pageNum,
            pageSize: parsed.studentScores.pageSize,
          ),
        );
      } else {
        _overview = parsed;
        _examIdx = parsed.indexOfCurrentExam();
        _selectedExamId = parsed.examTabs.isNotEmpty
            ? parsed.examTabs[_examIdx].examId
            : parsed.currentExamId;
      }
      _loading = false;
      _loadingMore = false;
      _error = '';
    });
  }

  void _onExamSelected(int index) {
    if (index < 0 || index >= _overview.examTabs.length) return;
    final examId = _overview.examTabs[index].examId;
    setState(() => _examIdx = index);
    _selectedExamId = examId;
    _loadOverview(examId: examId);
  }

  Future<void> _loadMoreScores() async {
    if (_loadingMore || !_overview.studentScores.hasMore) return;
    await _loadOverview(
      examId: _selectedExamId,
      pageNum: _overview.studentScores.pageNum + 1,
      append: true,
    );
  }

  void _openScoreDetail(HeadTeacherStudentScoreRecord record) {
    if (_overview.examTabs.isEmpty) return;
    final exam =
        _overview.examTabs[_examIdx.clamp(0, _overview.examTabs.length - 1)];
    _showScoreDetail(context, record: record, exam: exam);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    if (_loading && _overview.examTabs.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: ui(40)),
        child: const Center(child: AppLoadingIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: ui(40)),
          child: Text(
            _error,
            style: TextStyle(fontSize: ui(14), color: _kTextHint),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('班级成绩变化'),
        SizedBox(height: ui(12)),
        _GradesLineChartCard(overview: _overview),
        SizedBox(height: ui(20)),
        const _SectionTitle('考试记录'),
        SizedBox(height: ui(12)),
        _GradesExamRecordCard(
          examTabs: _overview.examTabs,
          records: _overview.studentScores.records,
          selectedIdx: _examIdx,
          loadingMore: _loadingMore,
          hasMore: _overview.studentScores.hasMore,
          onSelect: _onExamSelected,
          onLoadMore: _loadMoreScores,
          onOpenScoreDetail: _openScoreDetail,
        ),
      ],
    );
  }
}

// ----- 班级成绩变化（折线图） -----

class _GradesLineChartCard extends StatelessWidget {
  const _GradesLineChartCard({required this.overview});

  final HeadTeacherClassScoreOverview overview;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final axisLabels = overview.examAxis.map((item) => item.axisLabel).toList();
    final series = overview.trendLines
        .map((line) => line.avgScores)
        .where((scores) => scores.isNotEmpty)
        .toList();
    final labels = overview.trendLines
        .where((line) => line.avgScores.isNotEmpty)
        .map((line) => line.subjectName.isNotEmpty ? line.subjectName : '科目')
        .toList();
    final colors = [
      for (var i = 0; i < series.length; i++)
        kHeadTeacherScoreTrendColors[i % kHeadTeacherScoreTrendColors.length],
    ];
    final hasChart = overview.hasChartData && series.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '平均分',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
              ),
              const Spacer(),
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) SizedBox(width: ui(20)),
                _LegendItem(color: colors[i], label: labels[i]),
              ],
            ],
          ),
          SizedBox(height: ui(8)),
          if (!hasChart)
            SizedBox(
              height: ui(180),
              child: Center(
                child: Text(
                  '暂无足够考试数据生成趋势图',
                  style: TextStyle(fontSize: ui(12), color: _kTextHint),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: ui(220),
              child: _GradesMultiLineChart(
                series: series,
                colors: colors,
                periods: axisLabels,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: ui(7), height: ui(2), color: color),
        SizedBox(width: ui(2)),
        Container(width: ui(7), height: ui(2), color: color),
        SizedBox(width: ui(4)),
        Container(
          width: ui(8),
          height: ui(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1),
          ),
        ),
        SizedBox(width: ui(4)),
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// 折线图 plot 区坐标。布局样式对齐 roster [_ScoreLineChart]；
/// 班级均分跨度较大，Y 轴采用 0~100 线性映射（非 roster 单科的 78~100 压缩）。
/// 刻度须与线性映射一致（等距 20 分），勿复用 roster 的 100/95/90/85/80 压缩刻度。
class _GradesChartPlotMetrics {
  static const double innerLeftRatio = 0.04;
  static const double innerRightRatio = 0.96;
  static const double plotTopRatio = 0.05;
  static const List<int> yTicks = [100, 80, 60, 40, 20, 0];

  static double plotTop(double height) => height * plotTopRatio;

  /// 线性 0~100 映射时 plot 区底 = canvas 底（与 Y 轴 "0" 对齐）。
  static double plotBottom(double height) => height;

  static double plotHeight(double height) => plotBottom(height) - plotTop(height);

  static double pointX(int index, int count, double width) {
    if (count <= 0) return width / 2;
    if (count == 1) return width / 2;
    final innerLeft = width * innerLeftRatio;
    final innerWidth = width * (innerRightRatio - innerLeftRatio);
    return innerLeft + innerWidth * (index / (count - 1));
  }

  static double labelAlignmentX(int index, int count, double width) {
    final x = pointX(index, count, width);
    return -1 + 2 * x / width;
  }

  /// 分数 → Y（100 在 plotTop，0 在 canvas 底，与 Y 轴刻度一致）。
  static double yForScore(double score, double height) {
    final t = (score / 100).clamp(0.0, 1.0);
    return plotTop(height) + plotHeight(height) * (1 - t);
  }

  /// 刻度线 Y：与 [yForScore] 相同映射。
  static double yForTick(int tick, double height) {
    return yForScore(tick.toDouble(), height);
  }

  static double normalizeScore(double value) {
    return 1 - (value / 100).clamp(0.0, 1.0);
  }
}

/// 班级成绩折线图：Y 轴 / X 轴布局与任课老师学生名册档案弹窗中的分数走势折线图一致。
class _GradesMultiLineChart extends StatelessWidget {
  const _GradesMultiLineChart({
    required this.series,
    required this.colors,
    required this.periods,
  });

  final List<List<double>> series;
  final List<Color> colors;
  final List<String> periods;

  static const List<int> _kYLabels = _GradesChartPlotMetrics.yTicks;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: ui(28),
          child: Padding(
            padding: EdgeInsets.only(bottom: ui(28)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                final labelH = ui(12);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final tick in _kYLabels)
                      Positioned(
                        right: 0,
                        top: (_GradesChartPlotMetrics.yForTick(tick, height) -
                                labelH / 2)
                            .clamp(0.0, math.max(0.0, height - labelH)),
                        child: Text(
                          '$tick',
                          style: TextStyle(
                            fontSize: labelH,
                            color: _kTextHint,
                            fontFamily: 'PingFang SC',
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: _GradesMultiLineChartPainter(
                      series: series,
                      colors: colors,
                      ui: ui,
                    ),
                  ),
                ),
              ),
              SizedBox(height: ui(8)),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final count = periods.length;
                  return SizedBox(
                    height: ui(20),
                    width: width,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < count; i++)
                          Align(
                            alignment: Alignment(
                              _GradesChartPlotMetrics.labelAlignmentX(
                                i,
                                count,
                                width,
                              ),
                              0,
                            ),
                            child: Text(
                              periods[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ui(12),
                                color: _kTextSecondary,
                                fontFamily: 'PingFang SC',
                                fontWeight: FontWeight.w400,
                                height: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradesMultiLineChartPainter extends CustomPainter {
  _GradesMultiLineChartPainter({
    required this.series,
    required this.colors,
    required this.ui,
  });

  final List<List<double>> series;
  final List<Color> colors;
  final double Function(num) ui;

  static void _paintDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segEnd = math.min(drawn + dashWidth, total);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * segEnd,
        paint,
      );
      drawn += dashWidth + dashSpace;
    }
  }

  void _paintYAxisGrid(Canvas canvas, Size size) {
    final innerLeft = size.width * _GradesChartPlotMetrics.innerLeftRatio;
    final innerRight = size.width * _GradesChartPlotMetrics.innerRightRatio;
    final gridPaint = Paint()
      ..color = const Color(0xFFE6E9F1)
      ..strokeWidth = 1;

    for (final tick in _GradesChartPlotMetrics.yTicks) {
      final y = _GradesChartPlotMetrics.yForTick(tick, size.height);
      final start = Offset(innerLeft, y);
      final end = Offset(innerRight, y);
      if (tick == 0) {
        canvas.drawLine(start, end, gridPaint);
      } else {
        _paintDashedLine(canvas, start, end, gridPaint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    _paintYAxisGrid(canvas, size);

    final pointCount = series.map((s) => s.length).fold<int>(0, math.max);
    if (pointCount < 2) return;

    final plotTop = _GradesChartPlotMetrics.plotTop(size.height);
    final plotHeight = _GradesChartPlotMetrics.plotHeight(size.height);

    for (var s = 0; s < series.length; s++) {
      final values = series[s];
      if (values.length < 2) continue;

      final color = colors[s % colors.length];
      final xs = List<double>.generate(
        values.length,
        (i) => _GradesChartPlotMetrics.pointX(i, values.length, size.width),
      );
      final ys = values
          .map(
            (v) =>
                plotTop + plotHeight * _GradesChartPlotMetrics.normalizeScore(v),
          )
          .toList();

      final linePath = Path()..moveTo(xs[0], ys[0]);
      for (var i = 1; i < values.length; i++) {
        linePath.lineTo(xs[i], ys[i]);
      }
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = ui(2)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, linePaint);

      final dotFill = Paint()..color = Colors.white;
      final dotBorder = Paint()
        ..color = color
        ..strokeWidth = ui(1)
        ..style = PaintingStyle.stroke;
      final dotR = ui(4);
      for (var i = 0; i < values.length; i++) {
        canvas.drawCircle(Offset(xs[i], ys[i]), dotR, dotFill);
        canvas.drawCircle(Offset(xs[i], ys[i]), dotR, dotBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GradesMultiLineChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.colors != colors;
  }
}

// ----- 考试记录卡（含日期 Tab + 学生分数+点评） -----

class _GradesExamRecordCard extends StatelessWidget {
  const _GradesExamRecordCard({
    required this.examTabs,
    required this.records,
    required this.selectedIdx,
    required this.onSelect,
    required this.onLoadMore,
    required this.onOpenScoreDetail,
    this.loadingMore = false,
    this.hasMore = false,
  });

  final List<HeadTeacherScoreExamTab> examTabs;
  final List<HeadTeacherStudentScoreRecord> records;
  final int selectedIdx;
  final ValueChanged<int> onSelect;
  final VoidCallback onLoadMore;
  final ValueChanged<HeadTeacherStudentScoreRecord> onOpenScoreDetail;
  final bool loadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (examTabs.isEmpty)
            Text(
              '暂无考试记录',
              style: TextStyle(fontSize: ui(12), color: _kTextHint),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < examTabs.length; i++) ...[
                    if (i > 0) SizedBox(width: ui(11)),
                    _ExamSessionChip(
                      session: examTabs[i],
                      selected: i == selectedIdx,
                      onTap: () => onSelect(i),
                    ),
                  ],
                ],
              ),
            ),
          SizedBox(height: ui(12)),
          if (records.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: ui(24)),
                child: Text(
                  '本场考试暂无学生成绩',
                  style: TextStyle(fontSize: ui(12), color: _kTextHint),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final gap = ui(12);
                final minCardW = ui(360);
                final cols = math.max(
                  1,
                  ((c.maxWidth + gap) / (minCardW + gap)).floor(),
                );
                final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final item in records)
                          SizedBox(
                            width: cardW,
                            child: _ExamScoreCard(
                              item: item,
                              onOpenDetail: () => onOpenScoreDetail(item),
                            ),
                          ),
                      ],
                    ),
                    if (hasMore) ...[
                      SizedBox(height: ui(12)),
                      Center(
                        child: TextButton(
                          onPressed: loadingMore ? null : onLoadMore,
                          child: loadingMore
                              ? SizedBox(
                                  width: ui(18),
                                  height: ui(18),
                                  child: const AppLoadingIndicator(),
                                )
                              : Text(
                                  '加载更多',
                                  style: TextStyle(
                                    fontSize: ui(14),
                                    color: _kBlue,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ExamSessionChip extends StatelessWidget {
  const _ExamSessionChip({
    required this.session,
    required this.selected,
    required this.onTap,
  });
  final HeadTeacherScoreExamTab session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(8)),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F4FF) : _kInnerGray,
          borderRadius: BorderRadius.circular(ui(8)),
          border: selected ? Border.all(color: _kPurpleSoft, width: 1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.name.isNotEmpty ? session.name : '考试',
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            if (session.examDate.isNotEmpty) ...[
              SizedBox(height: ui(2)),
              Text(
                session.examDate,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExamScoreCard extends StatelessWidget {
  const _ExamScoreCard({
    required this.item,
    required this.onOpenDetail,
  });
  final HeadTeacherStudentScoreRecord item;
  final VoidCallback onOpenDetail;

  List<Widget> _buildTags() {
    final tags = <Widget>[];
    void addTag(String text, Color color, Color textColor) {
      tags.add(_MiniTag(text: text, color: color, textColor: textColor));
    }

    if (item.hasStudentAudio) {
      addTag('学生录音', const Color(0xFFE6E9F1), _kTextSecondary);
    }
    if (item.hasStudentVideo) {
      addTag('学生录像', const Color(0xFFE6E9F1), _kTextSecondary);
    }
    if (item.hasVideoComment) {
      addTag('视频点评', _kPurpleSoft, Colors.white);
    }
    if (item.hasAudioComment) {
      addTag('语音点评', _kPurpleSoft, Colors.white);
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final avatarUrl = item.headUrl.isNotEmpty
        ? MediaUrl.resolve(item.headUrl)
        : '';
    final tags = _buildTags();

    return Container(
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.all(ui(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(right: ui(56)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ui(8)),
                      child: avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              width: ui(40),
                              height: ui(40),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _ScoreAvatarFallback(
                                label: item.avatarChar,
                                size: ui(40),
                              ),
                            )
                          : _ScoreAvatarFallback(
                              label: item.avatarChar,
                              size: ui(40),
                            ),
                    ),
                    SizedBox(width: ui(8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.displayName,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: _kTextDark,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                ),
                              ),
                              SizedBox(width: ui(8)),
                              Expanded(
                                child: Text(
                                  item.no,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: ui(12),
                                    color: _kTextHint,
                                    fontWeight: FontWeight.w400,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (tags.isNotEmpty) ...[
                            SizedBox(height: ui(4)),
                            Wrap(
                              spacing: ui(4),
                              runSpacing: ui(4),
                              children: tags,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: ui(2),
                child: _DetailLink(onTap: onOpenDetail),
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          Container(
            height: ui(45),
            padding: EdgeInsets.symmetric(horizontal: ui(8)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.teacherName.isNotEmpty
                            ? '任课 ${item.teacherName}:'
                            : '任课点评:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextHint,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: ui(6)),
                      Text(
                        item.comment.isNotEmpty ? item.comment : '暂无评语',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: _kTextDark,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ui(8)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.score.toString(),
                      style: TextStyle(
                        fontSize: ui(20),
                        color: _kTextDark,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Barlow',
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ui(4)),
                    Text(
                      item.subjectName.isNotEmpty ? item.subjectName : '—',
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreAvatarFallback extends StatelessWidget {
  const _ScoreAvatarFallback({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _kPurpleSoft,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(15),
          color: Colors.white,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.text,
    required this.color,
    required this.textColor,
  });
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(11),
          color: textColor,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

class _DetailLink extends StatelessWidget {
  const _DetailLink({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '详情',
            style: TextStyle(
              fontSize: ui(14),
              color: _kBlue,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: ui(16), color: _kBlue),
        ],
      ),
    );
  }
}

// =============================================================================
// 成绩详情面板（点击成绩卡「详情」时从右侧滑出）
// =============================================================================

List<StudentExamRecord> _parseStudentExamRecords(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((item) => StudentExamRecord.fromMap(item))
        .toList();
  }
  if (raw is Map) {
    for (final key in ['records', 'list', 'data', 'rows']) {
      final nested = raw[key];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((item) => StudentExamRecord.fromMap(item))
            .toList();
      }
    }
  }
  return const [];
}

StudentExamSubjectScore? _matchSubjectScore(
  StudentExamRecord exam,
  HeadTeacherStudentScoreRecord record,
) {
  for (final subject in exam.subjectScores) {
    if (record.subjectId > 0 && subject.subjectId == record.subjectId) {
      return subject;
    }
  }
  for (final subject in exam.subjectScores) {
    if (record.subjectName.isNotEmpty &&
        subject.subjectName == record.subjectName) {
      return subject;
    }
  }
  return exam.subjectScores.isEmpty ? null : exam.subjectScores.first;
}

String _scoreResourceMediumLabel(String path) {
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

Future<void> _showScoreDetail(
  BuildContext context, {
  required HeadTeacherStudentScoreRecord record,
  required HeadTeacherScoreExamTab exam,
}) {
  final scaleData = DashboardScaleScope.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭成绩详情',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => DashboardScaleScope(
      data: scaleData,
      child: _ScoreDetailPanel(record: record, exam: exam),
    ),
    transitionBuilder: (context, animation, _, child) {
      final t = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(t),
        child: child,
      );
    },
  );
}

class _ScoreDetailPanel extends ConsumerStatefulWidget {
  const _ScoreDetailPanel({
    required this.record,
    required this.exam,
  });

  final HeadTeacherStudentScoreRecord record;
  final HeadTeacherScoreExamTab exam;

  @override
  ConsumerState<_ScoreDetailPanel> createState() => _ScoreDetailPanelState();
}

class _ScoreDetailPanelState extends ConsumerState<_ScoreDetailPanel> {
  bool _loading = true;
  StudentExamRecord? _examRecord;
  StudentExamSubjectScore? _subjectDetail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (widget.record.studentId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final resp = await ref.read(teacherRepositoryProvider).studentExamRecordList(
      studentId: widget.record.studentId,
    );
    if (!mounted) return;
    StudentExamRecord? matchedExam;
    StudentExamSubjectScore? matchedSubject;
    if (resp.isSuccess) {
      final records = _parseStudentExamRecords(resp.data);
      for (final item in records) {
        if (widget.exam.examId.isNotEmpty && item.examId == widget.exam.examId) {
          matchedExam = item;
          matchedSubject = _matchSubjectScore(item, widget.record);
          break;
        }
      }
      matchedExam ??= records.isNotEmpty ? records.first : null;
      if (matchedExam != null && matchedSubject == null) {
        matchedSubject = _matchSubjectScore(matchedExam, widget.record);
      }
    }
    setState(() {
      _examRecord = matchedExam;
      _subjectDetail = matchedSubject;
      _loading = false;
    });
  }

  String get _teacherName {
    if (widget.record.teacherName.isNotEmpty) return widget.record.teacherName;
    final nickname = _subjectDetail?.nickname.trim() ?? '';
    return nickname.isNotEmpty ? nickname : '任课老师';
  }

  String get _teacherHeadUrl {
    final fromSubject = _subjectDetail?.headUrl.trim() ?? '';
    return fromSubject;
  }

  String get _comment {
    final fromSubject = _subjectDetail?.comment.trim() ?? '';
    if (fromSubject.isNotEmpty) return fromSubject;
    return widget.record.comment.isNotEmpty ? widget.record.comment : '暂无评语';
  }

  int? get _scoreValue {
    final fromSubject = _subjectDetail?.score;
    if (fromSubject != null) return fromSubject.round();
    return widget.record.score;
  }

  void _previewResource() {
    final path = _subjectDetail?.path.trim() ?? '';
    if (path.isEmpty) return;
    final url = MediaUrl.resolve(path);
    if (url.isEmpty) return;
    showStudentHomeworkSubmissionPreview(
      context,
      ref: ref,
      fileUrl: url,
      title: '${widget.record.subjectName}考试资源',
      typeTag: _scoreResourceMediumLabel(path),
      mediumLabel: _scoreResourceMediumLabel(path),
      attachmentName: '${widget.record.subjectName}考试资源',
    );
  }

  List<Widget> _buildMediaTags() {
    final tags = <Widget>[];
    void add(String text, Color bg, Color fg) {
      tags.add(_MiniTag(text: text, color: bg, textColor: fg));
    }

    if (widget.record.hasStudentAudio) {
      add('学生录音', const Color(0xFFE6E9F1), _kTextSecondary);
    }
    if (widget.record.hasStudentVideo) {
      add('学生录像', const Color(0xFFE6E9F1), _kTextSecondary);
    }
    if (widget.record.hasVideoComment) {
      add('视频点评', _kPurpleSoft, Colors.white);
    }
    if (widget.record.hasAudioComment) {
      add('语音点评', _kPurpleSoft, Colors.white);
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final mq = MediaQuery.sizeOf(context);
    final panelW = math.min(ui(600), mq.width);
    final record = widget.record;
    final exam = widget.exam;
    final avatarUrl = record.headUrl.isNotEmpty
        ? MediaUrl.resolve(record.headUrl)
        : '';
    final teacherAvatarUrl = _teacherHeadUrl.isNotEmpty
        ? MediaUrl.resolve(_teacherHeadUrl)
        : '';
    final resourcePath = _subjectDetail?.path.trim() ?? '';
    final mediaTags = _buildMediaTags();

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: panelW,
          height: mq.height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: ui(62),
                child: Stack(
                  children: [
                    Positioned(
                      left: ui(12),
                      top: ui(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                            '成绩详情',
                            style: TextStyle(
                              fontSize: ui(18),
                              color: _kTextDark,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: ui(12),
                      top: ui(12),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.close_rounded, size: ui(22)),
                        color: _kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: AppLoadingIndicator())
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(24)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(ui(12)),
                                  child: avatarUrl.isNotEmpty
                                      ? Image.network(
                                          avatarUrl,
                                          width: ui(56),
                                          height: ui(56),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              _ScoreAvatarFallback(
                                            label: record.avatarChar,
                                            size: ui(56),
                                          ),
                                        )
                                      : _ScoreAvatarFallback(
                                          label: record.avatarChar,
                                          size: ui(56),
                                        ),
                                ),
                                SizedBox(width: ui(12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record.displayName,
                                        style: TextStyle(
                                          fontSize: ui(18),
                                          color: _kTextDark,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: ui(6)),
                                      Text(
                                        record.no.isNotEmpty
                                            ? '学号 ${record.no}'
                                            : '学号 —',
                                        style: TextStyle(
                                          fontSize: ui(12),
                                          color: _kTextHint,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: ui(20)),
                            _ScoreDetailSection(
                              title: '考试信息',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exam.name.isNotEmpty ? exam.name : '考试',
                                    style: TextStyle(
                                      fontSize: ui(14),
                                      color: _kTextDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (exam.examDate.isNotEmpty) ...[
                                    SizedBox(height: ui(6)),
                                    Text(
                                      exam.examDate,
                                      style: TextStyle(
                                        fontSize: ui(12),
                                        color: _kTextHint,
                                      ),
                                    ),
                                  ],
                                  if (_examRecord != null) ...[
                                    SizedBox(height: ui(10)),
                                    Wrap(
                                      spacing: ui(12),
                                      runSpacing: ui(6),
                                      children: [
                                        _ScoreDetailMeta(
                                          label: '总均分',
                                          value: _examRecord!.totalScore
                                                  .roundToDouble() ==
                                              _examRecord!.totalScore
                                              ? '${_examRecord!.totalScore.round()}'
                                              : _examRecord!.totalScore
                                                  .toStringAsFixed(1),
                                        ),
                                        _ScoreDetailMeta(
                                          label: '班级排名',
                                          value: _examRecord!.classRank > 0
                                              ? '${_examRecord!.classRank}'
                                              : '—',
                                        ),
                                        _ScoreDetailMeta(
                                          label: '全校排名',
                                          value: _examRecord!.schoolRank > 0
                                              ? '${_examRecord!.schoolRank}'
                                              : '—',
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(height: ui(16)),
                            _ScoreDetailSection(
                              title: '科目成绩',
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(ui(12)),
                                decoration: BoxDecoration(
                                  color: _kInnerGray,
                                  borderRadius: BorderRadius.circular(ui(12)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(ui(8)),
                                          child: teacherAvatarUrl.isNotEmpty
                                              ? Image.network(
                                                  teacherAvatarUrl,
                                                  width: ui(40),
                                                  height: ui(40),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) =>
                                                      _ScoreAvatarFallback(
                                                    label: _teacherName
                                                            .characters
                                                            .isNotEmpty
                                                        ? _teacherName
                                                            .characters.first
                                                        : '师',
                                                    size: ui(40),
                                                  ),
                                                )
                                              : _ScoreAvatarFallback(
                                                  label: _teacherName
                                                          .characters
                                                          .isNotEmpty
                                                      ? _teacherName
                                                          .characters.first
                                                      : '师',
                                                  size: ui(40),
                                                ),
                                        ),
                                        SizedBox(width: ui(8)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _teacherName,
                                                style: TextStyle(
                                                  fontSize: ui(14),
                                                  color: _kTextDark,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(height: ui(4)),
                                              Text(
                                                record.subjectName.isNotEmpty
                                                    ? record.subjectName
                                                    : '—',
                                                style: TextStyle(
                                                  fontSize: ui(12),
                                                  color: _kTextHint,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${_scoreValue ?? '--'}',
                                          style: TextStyle(
                                            fontSize: ui(24),
                                            color: _kTextDark,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Barlow',
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_subjectDetail != null &&
                                        (_subjectDetail!.classRank > 0 ||
                                            _subjectDetail!.schoolRank > 0)) ...[
                                      SizedBox(height: ui(10)),
                                      Row(
                                        children: [
                                          if (_subjectDetail!.classRank > 0)
                                            Text(
                                              '班级排名：${_subjectDetail!.classRank}',
                                              style: TextStyle(
                                                fontSize: ui(12),
                                                color: _kTextSecondary,
                                              ),
                                            ),
                                          if (_subjectDetail!.classRank > 0 &&
                                              _subjectDetail!.schoolRank > 0)
                                            SizedBox(width: ui(12)),
                                          if (_subjectDetail!.schoolRank > 0)
                                            Text(
                                              '全校排名：${_subjectDetail!.schoolRank}',
                                              style: TextStyle(
                                                fontSize: ui(12),
                                                color: _kTextSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                    SizedBox(height: ui(10)),
                                    Text(
                                      _comment,
                                      style: TextStyle(
                                        fontSize: ui(12),
                                        color: _kTextDark,
                                        height: 1.5,
                                      ),
                                    ),
                                    if (mediaTags.isNotEmpty) ...[
                                      SizedBox(height: ui(10)),
                                      Wrap(
                                        spacing: ui(4),
                                        runSpacing: ui(4),
                                        children: mediaTags,
                                      ),
                                    ],
                                    if (resourcePath.isNotEmpty) ...[
                                      SizedBox(height: ui(12)),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _previewResource,
                                          child: Text(
                                            '查看考试资源',
                                            style: TextStyle(
                                              fontSize: ui(14),
                                              color: _kBlue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
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

class _ScoreDetailSection extends StatelessWidget {
  const _ScoreDetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextSection,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: ui(10)),
        child,
      ],
    );
  }
}

class _ScoreDetailMeta extends StatelessWidget {
  const _ScoreDetailMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label：',
          style: TextStyle(fontSize: ui(12), color: _kTextSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(12),
            color: _kPurple,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

String _pickDetailString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
  }
  return fallback;
}

Map<String, dynamic> _pickDetailNestedMap(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final k in keys) {
    final v = json[k];
    if (v is Map) return Map<String, dynamic>.from(v);
  }
  return const {};
}

String _parentDisplayName(Map<String, dynamic> parent) {
  final nickname = _pickDetailString(parent, ['nickname', 'nickName']);
  if (nickname.isNotEmpty) return nickname;
  return _pickDetailString(parent, ['realname', 'realName', 'name']);
}

/// 将 `studentDetail` 嵌套响应（user / parents / dormitoryUser / schoolStudent）
/// 展平为详情面板可直接读取的字段。
Map<String, dynamic> _flattenStudentDetailJson(Map<String, dynamic> json) {
  if (json['user'] is! Map) {
    return Map<String, dynamic>.from(json);
  }

  final user = _pickDetailNestedMap(json, ['user']);
  final schoolStudent = _pickDetailNestedMap(json, ['schoolStudent']);
  final dormitoryUser = _pickDetailNestedMap(json, ['dormitoryUser']);
  final parents = json['parents'] is List ? json['parents'] as List : const [];

  final bedInfo = _pickDetailString(dormitoryUser, ['bedInfo']);
  final bedId = _pickDetailString(dormitoryUser, ['bedId']);
  final isLiving = bedInfo.isNotEmpty || (bedId.isNotEmpty && bedId != '0');
  final dormitory = isLiving ? (bedInfo.isEmpty ? '宿舍' : bedInfo) : '走读';

  final extra = <String, dynamic>{
    'gender': _pickDetailString(user, ['gender', 'sex']),
    'mobile': _pickDetailString(user, ['mobile', 'phone']),
    'headUrl': _pickDetailString(user, ['headUrl', 'avatar', 'avatarUrl']),
    'targetSchool': _pickDetailString(user, ['targetSchool']),
    'dormitory': dormitory,
    'tags': _pickDetailString(schoolStudent, ['tags']),
    'remark': _pickDetailString(schoolStudent, ['remark']),
  };

  for (var i = 0; i < parents.length && i < 2; i++) {
    if (parents[i] is! Map) continue;
    final parent = Map<String, dynamic>.from(parents[i] as Map);
    final name = _parentDisplayName(parent);
    final relation = _pickDetailString(parent, ['relation', 'parentRelation']);
    final mobile = _pickDetailString(parent, [
      'mobile',
      'phone',
      'parentMobile',
      'parentPhone',
    ]);
    if (i == 0) {
      if (name.isNotEmpty) extra['guardianName'] = name;
      if (relation.isNotEmpty) extra['guardianRelation'] = relation;
      if (mobile.isNotEmpty) extra['guardianMobile'] = mobile;
      if (name.isNotEmpty) extra['parentName'] = name;
      if (mobile.isNotEmpty) extra['parentMobile'] = mobile;
    } else {
      if (name.isNotEmpty) extra['guardian2Name'] = name;
      if (relation.isNotEmpty) extra['guardian2Relation'] = relation;
      if (mobile.isNotEmpty) extra['guardian2Mobile'] = mobile;
    }
  }

  return extra;
}

// =============================================================================
// 学生档案详情面板（点击学生卡时从右侧滑出，20% 黑底蒙层覆盖左侧）
// =============================================================================

Future<bool?> _showStudentDetail(
  BuildContext context,
  _StudentManageData data, {
  required String classId,
}) {
  // showGeneralDialog 会把内容挂到根 Navigator 的 overlay 上，那条 widget 树
  // 里没有 DashboardScaleScope；这里先把当前 scale 数据捕获下来，进 dialog
  // 后再用一个新的 DashboardScaleScope 包一层，保证面板里的 ui(...) 仍然可用。
  final scaleData = DashboardScaleScope.of(context);
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭学生档案',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => DashboardScaleScope(
      data: scaleData,
      child: _StudentDetailPanel(data: data, classId: classId),
    ),
    transitionBuilder: (context, animation, _, child) {
      final t = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(t),
        child: child,
      );
    },
  );
}

class _StudentDetailPanel extends ConsumerStatefulWidget {
  const _StudentDetailPanel({
    required this.data,
    required this.classId,
  });
  final _StudentManageData data;
  final String classId;

  @override
  ConsumerState<_StudentDetailPanel> createState() =>
      _StudentDetailPanelState();
}

class _StudentDetailPanelState extends ConsumerState<_StudentDetailPanel> {
  // 班主任标签集合；来自 API tags 字段（逗号分隔），合并已知预设。
  static const List<String> _kPresetTags = [
    '合唱团',
    '声乐部',
    '钢琴组',
    '艺术节',
    '校宣部',
    '社团骨干',
  ];

  late List<String> _selectedTags;
  late final TextEditingController _remarkCtrl;
  late final TextEditingController _customTagCtrl;
  late final TextEditingController _focusReasonCtrl;
  bool _saving = false;
  bool _loadingDetail = false;
  bool _loadingFocus = false;
  bool _focusSubmitting = false;
  FocusStudentItem? _focusItem;
  String _selectedFocusTag = kFocusStudentPresetTags.first;

  // 从 API 补充的详细信息（覆盖 widget.data 中的占位数据）
  Map<String, dynamic> _detailExtra = {};

  @override
  void initState() {
    super.initState();
    final tagsStr = widget.data.tags ?? '';
    _selectedTags = tagsStr
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    _remarkCtrl = TextEditingController(text: widget.data.remark ?? '');
    _customTagCtrl = TextEditingController();
    _focusReasonCtrl = TextEditingController();
    if (widget.data.id.isNotEmpty) {
      _loadDetail();
      _loadFocusStatus();
    }
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    _customTagCtrl.dispose();
    _focusReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFocusStatus() async {
    setState(() => _loadingFocus = true);
    final resp = await ref.read(teacherRepositoryProvider).focusStudentList();
    if (!mounted) return;
    FocusStudentItem? matched;
    if (resp.isSuccess) {
      final items = parseFocusStudentList(resp.data);
      for (final item in items) {
        if (item.studentId == widget.data.id) {
          matched = item;
          break;
        }
      }
    }
    setState(() {
      _focusItem = matched;
      _loadingFocus = false;
      if (matched != null) {
        _selectedFocusTag = matched.tag.isNotEmpty
            ? matched.tag
            : kFocusStudentPresetTags.first;
        _focusReasonCtrl.text = matched.reason;
      }
    });
  }

  Future<void> _addFocusStudent() async {
    if (widget.data.id.isEmpty || widget.classId.isEmpty) {
      AppToast.show(context, '缺少学生或班级信息');
      return;
    }
    final reason = _focusReasonCtrl.text.trim();
    if (reason.isEmpty) {
      AppToast.show(context, '请填写关注原因');
      return;
    }
    setState(() => _focusSubmitting = true);
    final resp = await ref.read(teacherRepositoryProvider).focusStudentAdd(
      studentId: widget.data.id,
      classId: widget.classId,
      tag: _selectedFocusTag,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _focusSubmitting = false);
    if (resp.isSuccess) {
      AppToast.show(context, '已加入重点关注');
      await _loadFocusStatus();
    } else {
      AppToast.show(
        context,
        resp.displayMsg.isNotEmpty ? resp.displayMsg : '加入重点关注失败',
      );
    }
  }

  Future<void> _removeFocusStudent() async {
    if (_focusItem == null) return;
    final confirmed = await showConfirmDialog(
      context: context,
      title: '取消关注',
      content: '确定取消对「${widget.data.name}」的重点关注吗？',
      confirmLabel: '取消关注',
      cancelLabel: '保留',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _focusSubmitting = true);
    final resp = await ref.read(teacherRepositoryProvider).focusStudentRemove(
      id: _focusItem!.studentId,
    );
    if (!mounted) return;
    setState(() => _focusSubmitting = false);
    if (resp.isSuccess) {
      AppToast.show(context, '已取消关注');
      _focusReasonCtrl.clear();
      await _loadFocusStatus();
    } else {
      AppToast.show(
        context,
        resp.displayMsg.isNotEmpty ? resp.displayMsg : '取消关注失败',
      );
    }
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    final res = await ref.read(teacherRepositoryProvider).studentDetail(
      id: widget.data.id,
    );
    if (!mounted) return;
    if (res.isSuccess && res.data is Map) {
      setState(() {
        _detailExtra = _flattenStudentDetailJson(
          Map<String, dynamic>.from(res.data as Map),
        );
        final tagsRaw = _detailExtra['tags']?.toString() ?? '';
        if (tagsRaw.isNotEmpty) {
          _selectedTags = tagsRaw
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();
        }
        final remarkRaw = _detailExtra['remark']?.toString() ?? '';
        if (remarkRaw.isNotEmpty) {
          _remarkCtrl.text = remarkRaw;
        }
      });
    }
    if (mounted) setState(() => _loadingDetail = false);
  }

  Future<void> _saveChanges() async {
    if (widget.data.id.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _saving = true);
    final tags = _selectedTags.join(',');
    final remark = _remarkCtrl.text.trim();
    final res = await ref.read(teacherRepositoryProvider).studentUpdate(
      studentId: widget.data.id,
      remark: remark,
      tags: tags,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.isSuccess) {
      AppToast.show(context, '修改已保存');
      Navigator.of(context).maybePop(true);
    } else {
      AppToast.show(context, res.msg.isNotEmpty ? res.msg : '保存失败，请重试');
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _addCustomTag() {
    final tag = _customTagCtrl.text.trim();
    if (tag.isEmpty) return;
    if (tag.length > 20) {
      AppToast.show(context, '标签最多 20 个字');
      return;
    }
    setState(() {
      if (!_selectedTags.contains(tag)) {
        _selectedTags.add(tag);
      }
      _customTagCtrl.clear();
    });
  }

  String _detailField(String apiKey, String fallback) {
    final v = _detailExtra[apiKey]?.toString().trim() ?? '';
    return v.isNotEmpty ? v : fallback;
  }

  String _avatarRawUrl() {
    final fromDetail = _detailExtra['headUrl']?.toString().trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    return widget.data.avatarUrl?.trim() ?? '';
  }

  late final String _classRole = widget.data.role ?? '';

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final mq = MediaQuery.sizeOf(context);
    final panelW = math.min(ui(600), mq.width);
    final data = widget.data;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: panelW,
          height: mq.height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----- 顶部：紫色竖条 + 学生档案 标题 + 关闭按钮 -----
              SizedBox(
                height: ui(62),
                child: Stack(
                  children: [
                    Positioned(
                      left: ui(12),
                      top: ui(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                            '学生档案',
                            style: TextStyle(
                              fontSize: ui(16),
                              color: _kTextDark,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: ui(12),
                      top: ui(15),
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(ui(8)),
                        child: Container(
                          width: ui(32),
                          height: ui(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(ui(8)),
                            border: Border.all(color: _kBorderSoft),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close_rounded,
                            size: ui(18),
                            color: const Color(0xFF1C274C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(20)),
                child: Container(height: 1, color: _kBorderSoft),
              ),
              // ----- 头像 + 姓名 + 学号 -----
              Padding(
                padding: EdgeInsets.fromLTRB(ui(20), ui(16), ui(20), 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _StudentManageAvatar(
                      rawHeadUrl: _avatarRawUrl(),
                      name: data.name,
                      size: ui(40),
                    ),
                    SizedBox(width: ui(12)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.name,
                          style: TextStyle(
                            fontSize: ui(16),
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: ui(8)),
                        Text(
                          data.studentId,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextHint,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ----- 滚动主体 -----
              Expanded(
                child: _loadingDetail
                    ? Center(
                        child: AppLoadingIndicator(),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          ui(20),
                          ui(16),
                          ui(20),
                          ui(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailGroupCard(
                              title: '本人信息',
                              children: [
                                _DetailFieldRow(
                                  children: [
                                    _DetailField(
                                      label: '性别：',
                                      value: _detailField('gender', data.gender),
                                    ),
                                    _DetailField(
                                      label: '住宿：',
                                      value: _detailField('dormitory', data.dorm),
                                    ),
                                    _DetailField(
                                      label: '本人手机：',
                                      value: _detailField('mobile', data.phone),
                                    ),
                                    _DetailField(
                                      label: '目标院校：',
                                      value: _detailField('targetSchool', '—'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: ui(12)),
                            _DetailGroupCard(
                              title: '家长与监护人',
                              children: [
                                _DetailFieldRow(
                                  children: [
                                    _DetailField(
                                      label: '监护人：',
                                      value: _detailField(
                                        'guardianName',
                                        _detailField('parentName', data.parentName),
                                      ),
                                    ),
                                    _DetailField(
                                      label: '关系：',
                                      value: _detailField('guardianRelation', '—'),
                                    ),
                                    _DetailField(
                                      label: '手机：',
                                      value: _detailField(
                                        'guardianMobile',
                                        _detailField('parentMobile', data.parentPhone),
                                      ),
                                    ),
                                    const _DetailField(
                                      label: '',
                                      value: '',
                                      invisible: true,
                                    ),
                                  ],
                                ),
                                if (_detailExtra['guardian2Name'] != null) ...[
                                  SizedBox(height: ui(8)),
                                  _DetailFieldRow(
                                    children: [
                                      _DetailField(
                                        label: '监护人二：',
                                        value: _detailField('guardian2Name', '—'),
                                      ),
                                      _DetailField(
                                        label: '关系：',
                                        value: _detailField('guardian2Relation', '—'),
                                      ),
                                      _DetailField(
                                        label: '手机：',
                                        value: _detailField('guardian2Mobile', '—'),
                                      ),
                                      const _DetailField(
                                        label: '',
                                        value: '',
                                        invisible: true,
                                      ),
                                    ],
                                  ),
                                ],
                                if (_detailExtra['emergencyContact'] != null) ...[
                                  SizedBox(height: ui(8)),
                                  _DetailFieldRow(
                                    children: [
                                      _DetailField(
                                        label: '紧急联系人：',
                                        value: _detailField('emergencyContact', '—'),
                                      ),
                                      const _DetailField(
                                        label: '',
                                        value: '',
                                        invisible: true,
                                      ),
                                      _DetailField(
                                        label: '手机：',
                                        value: _detailField(
                                          'emergencyMobile',
                                          '—',
                                        ),
                                      ),
                                      const _DetailField(
                                        label: '',
                                        value: '',
                                        invisible: true,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: ui(16)),
                            _detailLabel(context, '班主任备注'),
                            SizedBox(height: ui(8)),
                            Container(
                              constraints: BoxConstraints(minHeight: ui(60)),
                              padding: EdgeInsets.fromLTRB(
                                ui(16),
                                ui(12),
                                ui(16),
                                ui(12),
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(ui(8)),
                                border: Border.all(color: _kInnerGray),
                              ),
                              child: AppTextField(
                                controller: _remarkCtrl,
                                maxLines: null,
                                cursorColor: _kPurple,
                                cursorWidth: 1.5,
                                cursorHeight: ui(16),
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: _kTextDark,
                                  fontWeight: FontWeight.w400,
                                  height: 20 / 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: '为该学生添加备注…',
                                  hintStyle: TextStyle(
                                    fontSize: ui(14),
                                    color: _kTextHint,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_classRole.isNotEmpty) ...[
                              SizedBox(height: ui(16)),
                              _detailLabel(context, '班级职务'),
                              SizedBox(height: ui(8)),
                              Container(
                                height: ui(48),
                                padding: EdgeInsets.symmetric(
                                  horizontal: ui(16),
                                  vertical: ui(14),
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ui(8)),
                                  border: Border.all(color: _kInnerGray),
                                ),
                                child: Text(
                                  _classRole,
                                  style: TextStyle(
                                    fontSize: ui(14),
                                    color: _kTextDark,
                                    fontWeight: FontWeight.w400,
                                    height: 20 / 14,
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: ui(16)),
                            _detailLabel(context, '重点关注'),
                            SizedBox(height: ui(8)),
                            _FocusStudentSection(
                              loading: _loadingFocus,
                              submitting: _focusSubmitting,
                              isFocused: _focusItem != null,
                              selectedTag: _selectedFocusTag,
                              reasonCtrl: _focusReasonCtrl,
                              onTagChanged: (tag) =>
                                  setState(() => _selectedFocusTag = tag),
                              onAdd: _addFocusStudent,
                              onRemove: _removeFocusStudent,
                            ),
                            SizedBox(height: ui(16)),
                            _StudentTagEditorPanel(
                              presetTags: _kPresetTags,
                              selectedTags: _selectedTags,
                              customTagCtrl: _customTagCtrl,
                              onToggleTag: _toggleTag,
                              onAddCustomTag: _addCustomTag,
                            ),
                            SizedBox(height: ui(20)),
                            InkWell(
                              onTap: _saving ? null : _saveChanges,
                              borderRadius: BorderRadius.circular(ui(12)),
                              child: Container(
                                width: double.infinity,
                                height: ui(48),
                                padding: EdgeInsets.all(ui(10)),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(ui(12)),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    colors: _saving
                                        ? [
                                            const Color(0xFFB68EFF)
                                                .withValues(alpha: 0.5),
                                            const Color(0xFF8640FF)
                                                .withValues(alpha: 0.5),
                                          ]
                                        : const [
                                            Color(0xFFB68EFF),
                                            Color(0xFF8640FF),
                                          ],
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_saving)
                                      const AppLoadingIndicator(size: 16, color: Colors.white)
                                    else
                                      Icon(
                                        Icons.check_rounded,
                                        size: ui(16),
                                        color: Colors.white,
                                      ),
                                    SizedBox(width: ui(8)),
                                    Text(
                                      _saving ? '保存中…' : '确认修改',
                                      style: TextStyle(
                                        fontSize: ui(14),
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        height: 24 / 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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

class _DetailGroupCard extends StatelessWidget {
  const _DetailGroupCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: ui(16),
              color: _kTextDark,
              fontWeight: FontWeight.w600,
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

class _DetailFieldRow extends StatelessWidget {
  const _DetailFieldRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: ui(8)),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.invisible = false,
  });
  final String label;
  final String value;

  /// 占位用：spec 里部分单元格 opacity:0，仅用于撑列宽。
  final bool invisible;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final col = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        SizedBox(height: ui(2)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
    if (invisible) {
      return Opacity(opacity: 0, child: col);
    }
    return col;
  }
}

Widget _detailLabel(BuildContext context, String text) {
  final ui = DashboardScaleScope.of(context).ui;
  return Text(
    text,
    style: TextStyle(
      fontSize: ui(14),
      color: Colors.black,
      fontWeight: FontWeight.w500,
      height: 20 / 14,
    ),
  );
}

/// 班主任重点关注编辑区：标签 + 原因 + 加入/取消关注。
class _FocusStudentSection extends StatelessWidget {
  const _FocusStudentSection({
    required this.loading,
    required this.submitting,
    required this.isFocused,
    required this.selectedTag,
    required this.reasonCtrl,
    required this.onTagChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final bool loading;
  final bool submitting;
  final bool isFocused;
  final String selectedTag;
  final TextEditingController reasonCtrl;
  final ValueChanged<String> onTagChanged;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (loading) {
      return SizedBox(
        height: ui(88),
        child: Center(child: AppLoadingIndicator(size: ui(20))),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: ui(8),
            runSpacing: ui(8),
            children: [
              for (final tag in kFocusStudentPresetTags)
                _FocusTagChip(
                  label: tag,
                  selected: selectedTag == tag,
                  onTap: submitting ? null : () => onTagChanged(tag),
                ),
            ],
          ),
          SizedBox(height: ui(12)),
          Container(
            constraints: BoxConstraints(minHeight: ui(48)),
            padding: EdgeInsets.fromLTRB(ui(16), ui(12), ui(16), ui(12)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(8)),
              border: Border.all(color: _kBorderSoft),
            ),
            child: AppTextField(
              controller: reasonCtrl,
              enabled: !submitting,
              maxLines: null,
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontWeight: FontWeight.w400,
                height: 20 / 14,
              ),
              decoration: InputDecoration(
                hintText: '填写关注原因，如考前焦虑筛查跟进中…',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: _kTextHint,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          SizedBox(height: ui(12)),
          InkWell(
            onTap: submitting
                ? null
                : (isFocused ? onRemove : onAdd),
            borderRadius: BorderRadius.circular(ui(8)),
            child: Container(
              width: double.infinity,
              height: ui(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ui(8)),
                color: isFocused ? Colors.white : _kPurple,
                border: Border.all(
                  color: isFocused ? _kRed : _kPurple,
                ),
              ),
              child: submitting
                  ? AppLoadingIndicator(
                      size: ui(16),
                      color: isFocused ? _kRed : Colors.white,
                    )
                  : Text(
                      isFocused ? '取消重点关注' : '加入重点关注',
                      style: TextStyle(
                        fontSize: ui(14),
                        color: isFocused ? _kRed : Colors.white,
                        fontWeight: FontWeight.w500,
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

class _FocusTagChip extends StatelessWidget {
  const _FocusTagChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final colors = focusStudentTagColors(label);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(6)),
        decoration: BoxDecoration(
          color: selected ? colors.$1 : Colors.white,
          borderRadius: BorderRadius.circular(ui(6)),
          border: Border.all(
            color: selected ? colors.$1 : _kBorderSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: selected ? colors.$2 : _kTextSecondary,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// 班主任标签编辑区：预设 + 自定义标签与输入框合并在同一边框容器内。
class _StudentTagEditorPanel extends StatelessWidget {
  const _StudentTagEditorPanel({
    required this.presetTags,
    required this.selectedTags,
    required this.customTagCtrl,
    required this.onToggleTag,
    required this.onAddCustomTag,
  });

  final List<String> presetTags;
  final List<String> selectedTags;
  final TextEditingController customTagCtrl;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onAddCustomTag;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final customTags =
        selectedTags.where((t) => !presetTags.contains(t)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailLabel(context, '班主任标签'),
        SizedBox(height: ui(8)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(ui(12), ui(10), ui(12), ui(10)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: const Color(0xFFEDEFF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: ui(8),
                runSpacing: ui(8),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tag in presetTags)
                    _TeacherTagChip(
                      text: tag,
                      selected: selectedTags.contains(tag),
                      compact: true,
                      onTap: () => onToggleTag(tag),
                    ),
                  for (final tag in customTags)
                    _TeacherTagChip(
                      text: tag,
                      selected: true,
                      compact: true,
                      removable: true,
                      onTap: () => onToggleTag(tag),
                      onRemove: () => onToggleTag(tag),
                    ),
                ],
              ),
              SizedBox(height: ui(8)),
              Container(
                height: ui(36),
                padding: EdgeInsets.symmetric(horizontal: ui(10)),
                decoration: BoxDecoration(
                  color: _kInnerGray,
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sell_outlined,
                      size: ui(16),
                      color: _kTextHint,
                    ),
                    SizedBox(width: ui(6)),
                    Expanded(
                      child: AppTextField(
                        controller: customTagCtrl,
                        cursorColor: _kPurple,
                        cursorWidth: 1.5,
                        cursorHeight: ui(14),
                        style: TextStyle(
                          fontSize: ui(13),
                          color: _kTextDark,
                          fontWeight: FontWeight.w400,
                          height: 18 / 13,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onAddCustomTag(),
                        decoration: InputDecoration(
                          hintText: '输入自定义标签，回车添加',
                          hintStyle: TextStyle(
                            fontSize: ui(13),
                            color: _kTextHint,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    SizedBox(width: ui(6)),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onAddCustomTag,
                        borderRadius: BorderRadius.circular(ui(6)),
                        child: Container(
                          width: ui(28),
                          height: ui(28),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _kPurple,
                            borderRadius: BorderRadius.circular(ui(6)),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: ui(18),
                            color: Colors.white,
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
      ],
    );
  }
}

class _TeacherTagChip extends StatelessWidget {
  const _TeacherTagChip({
    required this.text,
    this.selected = false,
    this.compact = false,
    this.removable = false,
    this.onTap,
    this.onRemove,
  });
  final String text;
  final bool selected;
  final bool compact;
  final bool removable;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final Color bg;
    final Color textColor;
    if (selected) {
      bg = _kPurpleSoft;
      textColor = Colors.white;
    } else {
      bg = _kInnerGray;
      textColor = _kTextSecondary;
    }
    final hPad = compact ? ui(10) : ui(12);
    final vPad = compact ? ui(5) : ui(8);
    final fontSize = compact ? ui(12) : ui(12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  color: textColor,
                  fontWeight: FontWeight.w400,
                  height: 15.24 / 12,
                ),
              ),
              if (removable && selected) ...[
                SizedBox(width: ui(4)),
                GestureDetector(
                  onTap: onRemove ?? onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    Icons.close_rounded,
                    size: ui(14),
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
