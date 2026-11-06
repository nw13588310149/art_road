// =============================================================================
// 宿管端「查寝动态」独立页面
//
// 入口：宿管 dashboard 快捷区「查寝动态」按钮 → controller.openDormDynamic()
//      → mainView == dormDynamic + role == dormManager → SmartCampusPage
//      路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高, 4deg #F9EDFF→white 渐变, 圆角 16, 顶部居中"查寝动态"
//      16/600 + 副标题 12/#B6B5BB 说明本页不提供打卡入口；左 12 返回 32×32
//      白底 outline #F3F2F3）。
//   2. 4 张统计卡（100 高 + 各自 196deg 渐变 + 右下 54×54 装饰渐变方块 +
//      右上 32×32 白底图标）：
//      A. 「住宿生」橙渐变 rgba(255,168,70,.16)→0 + 绿色 home icon
//      B. 「今晚已归寝口径」绿渐变 rgba(70,255,119,.09)→0 + 同图标
//      C. 「异常（未打/晚归）」红渐变 rgba(255,70,70,.09)→0 + 紫色 alert
//      D. 「补卡待审」紫渐变 rgba(147,70,255,.14)→0 + "需协同审核" 12 副标题
//   3. Tabs row（44 高）：白底圆角 8 + 2 个 pill：本班查纪 / 补卡审核
//      （后者带 22×15 #F04545 红底徽章 "10+"）；右侧搜索框 324×44。
//   4. Sub-toolbar：「全部异常记录 N 条」(N 紫色) + 全部 / 异常 toggle。
//   5. 卡片网格 3 列（每张 312×width，padding 12，白底，圆角 16，gap 16）：
//      · 学生口径卡：头像 40 + 姓名 14/500 + 学号 12/#B6B5BB + "查寝"
//        12/#6D6B75 + 状态徽章 16 高（正常 #DAD2FF/#8741FF / 未打卡
//        #FEE4E8/#FF323C / 迟到 #DBE2FF/#325BFF）；下行 宿舍 12 + 日期；
//        灰底块 #F5F6FA H50 居中两列：规定时间 / 打卡时间；底部 备注。
//      · 宿舍口径卡：晨查寝 / 晚查寝 18 Barlow/600 标题 + 大色块状态徽章
//        正常 #A773FF / 未打卡 #FF323C / 迟到 #325BFF 全为白字；下行
//        宿舍 13/#6D6B75 + 日期；灰底块同；底部 备注。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../shell/ui/shell_layout.dart';
import 'widgets/smart_campus_stat_card.dart';
import '../data/smart_campus_count_badge.dart';
import '../data/student_dormitory_data.dart' show DormitoryDetailField;
import '../data/teacher_dormitory_data.dart';
import '../state/smart_campus_controller.dart';
import '../state/smart_campus_state.dart';
import '../state/dorm_class_dormitory_controller.dart';
import '../../school/data/school_config_data.dart';
import '../../school/state/school_config_controller.dart';
import 'widgets/dormitory_detail_dialog.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardGreyBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextPlaceholder = Color(0xFFD1D1D1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleSoftBg = Color(0xFFDAD2FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedSoftBg = Color(0xFFFEE4E8);
const Color _kBlue = Color(0xFF325BFF);
const Color _kBadgeRed = Color(0xFFF04545);

// —— 顶部 tab 枚举 ——————————————————————————————————————————————
enum _TopTab {
  classRoster('本班查纪'),
  punchAudit('补卡审核');

  const _TopTab(this.label);
  final String label;
}

// —— 全部 / 异常 toggle ————————————————————————————————————————————
enum _FilterTab {
  all('全部'),
  exception('异常');

  const _FilterTab(this.label);
  final String label;
}

// —— 学生口径状态 ——————————————————————————————————————————————————
// Figma 学生口径卡只出现 "正常 / 未打卡" 两种；如需扩展（如"迟到"），
// 可参考 _DormStatus 加入蓝底 _kBlue 配色。
enum _StudentStatus {
  normal('正常', _kPurpleSoftBg, _kPurple),
  late_('晚归', Color(0xFFDBE2FF), _kBlue),
  absent('未打卡', _kRedSoftBg, _kRed);

  const _StudentStatus(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  bool get isException => this != _StudentStatus.normal;
}

// —— 宿舍口径状态（实色徽章）—————————————————————————————————————
enum _DormStatus {
  normal('正常', Color(0xFFA773FF)),
  absent('未打卡', _kRed),
  late_('迟到', _kBlue);

  const _DormStatus(this.label, this.solidBg);
  final String label;
  final Color solidBg;

  bool get isException => this != _DormStatus.normal;
}

// —— 补卡审核状态 —————————————————————————————————————————————
// 待审核 / 已通过 / 已驳回；徽章为柔和底 + 实色字。
const Color _kOrange = Color(0xFFFF6A00);
const Color _kOrangeSoftBg = Color(0xFFFFEDD3);
const Color _kGreenAudit = Color(0xFF12CE51);
const Color _kGreenAuditSoftBg = Color(0xFFE4FFED);

enum _PunchAuditStatus {
  pending('待审核', _kOrangeSoftBg, _kOrange),
  approved('已通过', _kGreenAuditSoftBg, _kGreenAudit),
  rejected('已驳回', Color(0xFFFFE4E5), _kRed);

  const _PunchAuditStatus(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}

// —— 数据模型 ——————————————————————————————————————————————————
class _StudentRecord {
  const _StudentRecord({
    required this.studentName,
    required this.studentNo,
    required this.avatarUrl,
    required this.status,
    required this.dormName,
    required this.date,
    required this.requiredTime,
    required this.punchTime,
    required this.bedName,
  });

  final String studentName;
  final String studentNo;
  final String avatarUrl;
  final _StudentStatus status;
  final String dormName;
  final String date;
  final String requiredTime;
  final String punchTime;
  final String bedName;
}

class _DormRecord {
  const _DormRecord({
    required this.title,
    required this.status,
    required this.dormName,
    required this.date,
    required this.requiredTime,
    required this.punchTime,
    required this.note,
  });

  final String title;
  final _DormStatus status;
  final String dormName;
  final String date;
  final String requiredTime;
  final String punchTime;
  final String note;
}

class _PunchAuditRecord {
  const _PunchAuditRecord({
    required this.id,
    required this.studentName,
    required this.studentNo,
    required this.avatarUrl,
    required this.dormName,
    required this.date,
    required this.reason,
    required this.status,
  });

  final String id;
  final String studentName;
  final String studentNo;
  final String avatarUrl;
  final String dormName;
  final String date;
  final String reason;
  final _PunchAuditStatus status;
}

// —— 顶级视图 ——————————————————————————————————————————————————

class TeacherDormDynamicView extends ConsumerStatefulWidget {
  const TeacherDormDynamicView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<TeacherDormDynamicView> createState() =>
      _TeacherDormDynamicViewState();
}

class _TeacherDormDynamicViewState
    extends ConsumerState<TeacherDormDynamicView> {
  _TopTab _topTab = _TopTab.classRoster;
  _FilterTab _filterTab = _FilterTab.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final initialTab =
        ref.read(smartCampusControllerProvider).teacherDormDynamicInitialTab;
    if (initialTab == TeacherDormDynamicInitialTab.punchAudit) {
      _topTab = _TopTab.punchAudit;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(smartCampusControllerProvider.notifier)
          .clearTeacherDormDynamicInitialTab();
    });
    Future.microtask(
      () => ref.read(dormClassDormitoryControllerProvider.notifier).initialize(),
    );
  }

  Future<void> _showMakeupDetail(_PunchAuditRecord record) async {
    if (record.id.isEmpty) return;
    final rawFields = await ref
        .read(dormClassDormitoryControllerProvider.notifier)
        .loadMakeupDetail(record.id);
    if (!mounted) return;
    if (rawFields.isEmpty) {
      AppToast.show(context, '未获取到补卡详情');
      return;
    }
    const studentNameLabels = {'姓名', '学生', '学生姓名'};
    final fields = rawFields
        .map(
          (field) => studentNameLabels.contains(field.label)
              ? DormitoryDetailField('学生姓名', record.studentName)
              : field,
        )
        .toList(growable: false);
    await showDormitoryDetailDialog(
      context,
      title: '${record.studentName} · 补卡详情',
      fields: fields,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = ref.watch(dormClassDormitoryControllerProvider);
    final checkConfig =
        ref.watch(schoolDormitoryCheckConfigProvider).valueOrNull ??
        SchoolDormitoryCheckConfig.empty;
    final students = _studentRecords(state.dynamicItems, checkConfig);
    final dormRecords = const <_DormRecord>[];
    final punchAudits = _punchAuditRecords(state.makeupItems);
    final pendingPunchCount = punchAudits
        .where((record) => record.status == _PunchAuditStatus.pending)
        .length;
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(12)),
            _StatsRow(
              residentCount: state.overview.enrolledDormCount != 0
                  ? state.overview.enrolledDormCount
                  : state.stat.studentCount,
              returnedCount: state.overview.todayNormalCount,
              exceptionCount:
                  state.overview.todayAbsentCount +
                  state.overview.todayLateCount,
              auditCount: state.overview.pendingMakeupCount != 0
                  ? state.overview.pendingMakeupCount
                  : pendingPunchCount,
            ),
            SizedBox(height: ui(16)),
            _TabsRow(
              current: _topTab,
              pendingPunchCount: pendingPunchCount,
              searchValue: _searchQuery,
              onSearchChanged: (v) => setState(() => _searchQuery = v),
              onTap: (t) => setState(() => _topTab = t),
            ),
            SizedBox(height: ui(16)),
            // 「本班查纪」展示 全部 / 异常 toggle + 学生口径 / 宿舍口径卡片网格；
            // 「补卡审核」直接展示补卡申请卡片网格（无 toggle）。
            if (_topTab == _TopTab.classRoster) ...[
              _FilterToolbar(
                total: _exceptionTotal(students, dormRecords),
                current: _filterTab,
                onTap: (t) => setState(() => _filterTab = t),
              ),
              SizedBox(height: ui(12)),
              _CardsGrid(
                students: _filteredStudents(students),
                dormRecords: _filteredDormRecords(dormRecords),
                emptyMessage: _searchQuery.trim().isNotEmpty &&
                        (students.isNotEmpty || dormRecords.isNotEmpty)
                    ? '未找到匹配记录'
                    : '暂无相关记录',
              ),
            ] else ...[
              _PunchAuditGrid(
                records: _filteredPunchAudits(punchAudits),
                emptyMessage: _searchQuery.trim().isNotEmpty &&
                        punchAudits.isNotEmpty
                    ? '未找到匹配记录'
                    : '暂无补卡申请',
                onDetail: (record) => unawaited(_showMakeupDetail(record)),
                onApprove: _onApprovePunchAudit,
                onReject: _onRejectPunchAudit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _exceptionTotal(
    List<_StudentRecord> students,
    List<_DormRecord> dormRecords,
  ) {
    final s = students.where((r) => r.status.isException).length;
    final d = dormRecords.where((r) => r.status.isException).length;
    return s + d;
  }

  bool _matchesSearch(Iterable<String> fields) {
    final q = _searchQuery.trim();
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    for (final field in fields) {
      if (field.isEmpty || field == '--' || field == '—') continue;
      if (field.toLowerCase().contains(lower)) return true;
    }
    return false;
  }

  List<_StudentRecord> _filteredStudents(List<_StudentRecord> students) {
    var result = students;
    if (_filterTab == _FilterTab.exception) {
      result = result.where((r) => r.status.isException).toList();
    }
    return result
        .where(
          (r) => _matchesSearch([
            r.studentName,
            r.studentNo,
            r.dormName,
            r.bedName,
          ]),
        )
        .toList();
  }

  List<_DormRecord> _filteredDormRecords(List<_DormRecord> dormRecords) {
    var result = dormRecords;
    if (_filterTab == _FilterTab.exception) {
      result = result.where((r) => r.status.isException).toList();
    }
    return result
        .where(
          (r) => _matchesSearch([
            r.title,
            r.dormName,
            r.note,
          ]),
        )
        .toList();
  }

  List<_PunchAuditRecord> _filteredPunchAudits(
    List<_PunchAuditRecord> punchAudits,
  ) {
    return punchAudits
        .where(
          (r) => _matchesSearch([
            r.studentName,
            r.studentNo,
            r.dormName,
            r.reason,
          ]),
        )
        .toList();
  }

  Future<void> _onApprovePunchAudit(_PunchAuditRecord record) async {
    final response = await ref
        .read(dormClassDormitoryControllerProvider.notifier)
        .auditMakeup(id: record.id, approve: true);
    if (!mounted) return;
    AppToast.show(
      context,
      response.isSuccess
          ? '已通过 ${record.studentName} 的补卡申请'
          : response.displayMsg,
    );
  }

  Future<void> _onRejectPunchAudit(_PunchAuditRecord record) async {
    final response = await ref
        .read(dormClassDormitoryControllerProvider.notifier)
        .auditMakeup(id: record.id, approve: false);
    if (!mounted) return;
    AppToast.show(
      context,
      response.isSuccess
          ? '已驳回 ${record.studentName} 的补卡申请'
          : response.displayMsg,
    );
  }
}

List<_StudentRecord> _studentRecords(
  List<TeacherDormitoryDynamicItem> items,
  SchoolDormitoryCheckConfig checkConfig,
) {
  return [
    for (final item in items)
      _StudentRecord(
        studentName: item.studentName,
        studentNo: item.studentNo,
        avatarUrl: item.avatarUrl,
        status: switch (item.status) {
          TeacherDormitoryStatus.normal => _StudentStatus.normal,
          TeacherDormitoryStatus.late => _StudentStatus.late_,
          TeacherDormitoryStatus.absent => _StudentStatus.absent,
        },
        dormName: item.dormName.isEmpty ? '未分配宿舍' : item.dormName,
        date: item.checkDate.isEmpty ? '--' : item.checkDate,
        requiredTime: resolveDormitoryRequiredDeadline(
          recordDeadline: '',
          checkType: '晚查寝',
          config: checkConfig,
        ),
        punchTime: item.checkTime,
        bedName: item.bedName.isEmpty ? '无' : item.bedName,
      ),
  ];
}

List<_PunchAuditRecord> _punchAuditRecords(
  List<TeacherDormitoryMakeupItem> items,
) {
  return [
    for (final item in items)
      _PunchAuditRecord(
        id: item.id,
        studentName: item.studentName,
        studentNo: '--',
        avatarUrl: item.avatarUrl,
        dormName: item.checkType,
        date: item.checkDate,
        reason: item.reason,
        status: switch (item.status) {
          0 => _PunchAuditStatus.pending,
          1 => _PunchAuditStatus.approved,
          _ => _PunchAuditStatus.rejected,
        },
      ),
  ];
}

// —— Banner ————————————————————————————————————————————————————————

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

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
                  border: Border.all(color: _kBorderSoft, width: 1),
                ),
                alignment: Alignment.center,
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
              padding: EdgeInsets.symmetric(horizontal: ui(56)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '查寝动态',
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
                    '掌握本班住宿生归宿与晨检结果，协同处理补卡与异常跟进。现场刷脸/签到由查寝老师/宿管在专用端执行——本页不提供打卡入口。',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// —— 4 张统计卡 ——————————————————————————————————————————————————————

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.residentCount,
    required this.returnedCount,
    required this.exceptionCount,
    required this.auditCount,
  });

  final int residentCount;
  final int returnedCount;
  final int exceptionCount;
  final int auditCount;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SmartCampusStatCard(
              backgroundAsset: AppAssets.headTeacherDormDynamicStatResident,
              label: '住宿生',
              value: residentCount,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: SmartCampusStatCard(
              backgroundAsset: AppAssets.headTeacherDormDynamicStatReturned,
              label: '今晚已归寝口径',
              value: returnedCount,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: SmartCampusStatCard(
              backgroundAsset: AppAssets.headTeacherDormDynamicStatException,
              label: '异常（未打/晚归）',
              value: exceptionCount,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: SmartCampusStatCard(
              backgroundAsset: AppAssets.headTeacherDormDynamicStatPunchAudit,
              label: '补卡待审',
              value: auditCount,
              valueSuffix: '需协同审核',
            ),
          ),
        ],
      ),
    );
  }
}

// —— Tabs row + 搜索框 ——————————————————————————————————————————————

class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.current,
    required this.pendingPunchCount,
    required this.onTap,
    required this.searchValue,
    required this.onSearchChanged,
  });

  final _TopTab current;
  final int pendingPunchCount;
  final ValueChanged<_TopTab> onTap;
  final String searchValue;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 注意：tabs 容器和搜索框都不再写死 height，让其根据子 pill 的 padding
    // 自然撑高。中文（PingFang SC）在 line-height: 1.0 + 固定 44/32 高度
    // 容器内会出现 baseline 被裁、字体看上去"被压扁"的视觉错觉，因此采用
    // 内容驱动高度 + 较宽的 line-height(1.2) 的策略。
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(ui(4), ui(4), ui(3), ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _TopTab.values.length; i++) ...[
                if (i != 0) SizedBox(width: ui(16)),
                _TabPill(
                  tab: _TopTab.values[i],
                  active: _TopTab.values[i] == current,
                  pendingPunchCount: pendingPunchCount,
                  onTap: () => onTap(_TopTab.values[i]),
                ),
              ],
            ],
          ),
        ),
        Container(
          width: ui(324),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
          ),
          padding: EdgeInsets.symmetric(horizontal: ui(24), vertical: ui(12)),
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
                child: _DormDynamicSearchField(
                  value: searchValue,
                  onChanged: onSearchChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DormDynamicSearchField extends StatefulWidget {
  const _DormDynamicSearchField({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_DormDynamicSearchField> createState() => _DormDynamicSearchFieldState();
}

class _DormDynamicSearchFieldState extends State<_DormDynamicSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _DormDynamicSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: widget.value.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppTextField(
      controller: _controller,
      onChanged: widget.onChanged,
      cursorColor: _kPurple,
      cursorWidth: 1.5,
      cursorHeight: ui(16),
      style: TextStyle(
        fontSize: ui(14),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 1.2,
      ),
      decoration: InputDecoration(
        hintText: '搜索姓名、学号、手机、宿舍、家长',
        hintStyle: TextStyle(
          fontSize: ui(14),
          color: _kTextPlaceholder,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.tab,
    required this.active,
    required this.pendingPunchCount,
    required this.onTap,
  });

  final _TopTab tab;
  final bool active;
  final int pendingPunchCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: TextStyle(
                fontSize: ui(14),
                color: active ? Colors.white : _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
            if (tab == _TopTab.punchAudit && pendingPunchCount > 0) ...[
              SizedBox(width: ui(4)),
              _RedBadge(
                text: smartCampusCountBadgeLabel(pendingPunchCount)!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RedBadge extends StatelessWidget {
  const _RedBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(22),
      height: ui(15),
      decoration: BoxDecoration(
        color: _kBadgeRed,
        borderRadius: BorderRadius.circular(ui(20)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(10),
          color: Colors.white,
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

// —— 全部异常记录 + 全部 / 异常 toggle ————————————————————————————————

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({
    required this.total,
    required this.current,
    required this.onTap,
  });

  final int total;
  final _FilterTab current;
  final ValueChanged<_FilterTab> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
              children: [
                const TextSpan(text: '全部异常记录 '),
                TextSpan(
                  text: '$total',
                  style: const TextStyle(color: _kPurple),
                ),
                const TextSpan(text: ' 条'),
              ],
            ),
          ),
        ),
        SizedBox(width: ui(12)),
        Container(
          padding: EdgeInsets.fromLTRB(ui(4), ui(4), ui(3), ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _FilterTab.values.length; i++) ...[
                if (i != 0) SizedBox(width: ui(12)),
                _FilterPill(
                  tab: _FilterTab.values[i],
                  active: _FilterTab.values[i] == current,
                  onTap: () => onTap(_FilterTab.values[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _FilterTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(7)),
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
        ),
        child: Text(
          tab.label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// —— 卡片网格 ——————————————————————————————————————————————————————

class _CardsGrid extends StatelessWidget {
  const _CardsGrid({
    required this.students,
    required this.dormRecords,
    required this.emptyMessage,
  });

  final List<_StudentRecord> students;
  final List<_DormRecord> dormRecords;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasContent = students.isNotEmpty || dormRecords.isNotEmpty;
    if (!hasContent) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: Text(
            emptyMessage,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gap = ui(16);
        // Figma 设计 970 宽下 3 列 312；自适应：cw 不足时降到 2 / 1 列。
        var columns = 3;
        if (w < ui(720)) columns = 2;
        if (w < ui(480)) columns = 1;
        final cardWidth = (w - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in students)
              SizedBox(
                width: cardWidth,
                child: _StudentCard(record: r),
              ),
            for (final r in dormRecords)
              SizedBox(
                width: cardWidth,
                child: _DormCard(record: r),
              ),
          ],
        );
      },
    );
  }
}

// —— 卡片背景（共用）—————————————————————————————————————————————

BoxDecoration _cardDecoration(double radius) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
);

/// 查寝动态学生头像：相对路径经 [MediaUrl.resolve] 补全后加载。
class _DormStudentAvatar extends StatelessWidget {
  const _DormStudentAvatar({
    required this.rawHeadUrl,
    required this.name,
    required this.size,
  });

  final String rawHeadUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = ui(8);
    final raw = rawHeadUrl.trim();
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

  Widget _fallback(double Function(double) ui, double radius, String initial) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFA773FF),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: initial.isNotEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontSize: ui(size * 0.38),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            )
          : Icon(Icons.person_rounded, size: ui(size * 0.5), color: Colors.white),
    );
  }
}

// —— 学生口径卡 ——————————————————————————————————————————————————

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.record});

  final _StudentRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: _cardDecoration(ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 + 姓名 / 学号 + 状态徽章；姓名行下方 宿舍 + 日期。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DormStudentAvatar(
                rawHeadUrl: record.avatarUrl,
                name: record.studentName,
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
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: Row(
                              children: [
                                Text(
                                  record.studentName,
                                  style: TextStyle(
                                    fontSize: ui(14),
                                    color: _kTextDark,
                                    fontFamily: 'PingFang SC',
                                    fontWeight: AppFont.w500,
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(width: ui(4)),
                                Text(
                                  record.studentNo,
                                  style: TextStyle(
                                    fontSize: ui(12),
                                    color: _kTextHint,
                                    fontFamily: 'PingFang SC',
                                    fontWeight: AppFont.w400,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        Text(
                          '查寝',
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        _StudentStatusBadge(status: record.status),
                      ],
                    ),
                    SizedBox(height: ui(6)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.dormName,
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        Text(
                          record.date,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextHint,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          _TimeBlock(
            requiredTime: record.requiredTime,
            punchTime: record.punchTime,
          ),
          SizedBox(height: ui(10)),
          Text(
            '床位：${record.bedName}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// 学生口径状态徽章（柔和底）
class _StudentStatusBadge extends StatelessWidget {
  const _StudentStatusBadge({required this.status});

  final _StudentStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      alignment: Alignment.center,
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(12),
          color: status.fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

// —— 宿舍口径卡 ——————————————————————————————————————————————————

class _DormCard extends StatelessWidget {
  const _DormCard({required this.record});

  final _DormRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: _cardDecoration(ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record.title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
              _DormStatusBadge(status: record.status),
            ],
          ),
          SizedBox(height: ui(4)),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.dormName,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: ui(8)),
              Text(
                record.date,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(12)),
          _TimeBlock(
            requiredTime: record.requiredTime,
            punchTime: record.punchTime,
          ),
          SizedBox(height: ui(10)),
          Text(
            '备注：${record.note}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// 宿舍口径状态徽章（实色 + 白字）
class _DormStatusBadge extends StatelessWidget {
  const _DormStatusBadge({required this.status});

  final _DormStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.solidBg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      alignment: Alignment.center,
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(12),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

// —— 灰底时间块（规定时间 / 打卡时间 居中两列）—————————————————————

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.requiredTime, required this.punchTime});

  final String requiredTime;
  final String punchTime;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 注意：不再写死 height，让两行文字 + padding + 中间 5px 自然撑高
    // （PingFang SC 在 height: 1.0 时实际渲染高度仍可能 >12px，固定 50 会
    //  在不同字体回退情况下溢出 9px 左右）。
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(11), horizontal: ui(12)),
      decoration: BoxDecoration(
        color: _kCardGreyBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeColumn(label: '规定时间', value: requiredTime),
          ),
          Expanded(
            child: _TimeColumn(label: '打卡时间', value: punchTime),
          ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
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
        SizedBox(height: ui(4)),
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

// —— 补卡审核卡片网格 ————————————————————————————————————————————

class _PunchAuditGrid extends StatelessWidget {
  const _PunchAuditGrid({
    required this.records,
    required this.emptyMessage,
    required this.onDetail,
    required this.onApprove,
    required this.onReject,
  });

  final List<_PunchAuditRecord> records;
  final String emptyMessage;
  final ValueChanged<_PunchAuditRecord> onDetail;
  final ValueChanged<_PunchAuditRecord> onApprove;
  final ValueChanged<_PunchAuditRecord> onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        child: Center(
          child: Text(
            emptyMessage,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gap = ui(16);
        var columns = 3;
        if (w < ui(720)) columns = 2;
        if (w < ui(480)) columns = 1;
        final cardWidth = (w - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in records)
              SizedBox(
                width: cardWidth,
                child: _PunchAuditCard(
                  record: r,
                  onDetail: () => onDetail(r),
                  onApprove: () => onApprove(r),
                  onReject: () => onReject(r),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PunchAuditCard extends StatelessWidget {
  const _PunchAuditCard({
    required this.record,
    required this.onDetail,
    required this.onApprove,
    required this.onReject,
  });

  final _PunchAuditRecord record;
  final VoidCallback onDetail;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isPending = record.status == _PunchAuditStatus.pending;

    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: _cardDecoration(ui(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 + 姓名/学号 + 状态徽章；下行 宿舍 + 日期。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DormStudentAvatar(
                rawHeadUrl: record.avatarUrl,
                name: record.studentName,
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
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: Row(
                              children: [
                                Text(
                                  record.studentName,
                                  style: TextStyle(
                                    fontSize: ui(14),
                                    color: _kTextDark,
                                    fontFamily: 'PingFang SC',
                                    fontWeight: AppFont.w500,
                                    height: 1.2,
                                  ),
                                ),
                                if (record.studentNo.isNotEmpty &&
                                    record.studentNo != '--') ...[
                                  SizedBox(width: ui(4)),
                                  Text(
                                    record.studentNo,
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
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        Text(
                          '补卡',
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kTextSecondary,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        _PunchAuditStatusBadge(status: record.status),
                      ],
                    ),
                    SizedBox(height: ui(6)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.dormName,
                            style: TextStyle(
                              fontSize: ui(12),
                              color: _kTextDark,
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: ui(8)),
                        Text(
                          record.date,
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
          ),
          SizedBox(height: ui(12)),
          // 补卡说明：与时间块同款灰底圆角信息块，限制 2 行保持卡片等高。
          _ReasonBlock(reason: record.reason),
          SizedBox(height: ui(12)),
          // 底部操作：左侧"查看详情"链接；待审核时右侧显示 驳回 / 通过，
          // 已通过/已驳回时仅保留详情链接，使各状态卡片底部高度一致。
          Row(
            children: [
              _DetailLink(onTap: onDetail),
              const Spacer(),
              if (isPending) ...[
                _PunchActionButton(
                  label: '驳回',
                  isPrimary: false,
                  onTap: onReject,
                ),
                SizedBox(width: ui(12)),
                _PunchActionButton(
                  label: '通过',
                  isPrimary: true,
                  onTap: onApprove,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// 补卡说明块：复用学生卡灰底块视觉语言（#F5F6FA + 圆角 8）。
class _ReasonBlock extends StatelessWidget {
  const _ReasonBlock({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final text = reason.trim().isEmpty ? '无' : reason.trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(10)),
      decoration: BoxDecoration(
        color: _kCardGreyBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '补卡说明',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.2,
            ),
          ),
          SizedBox(height: ui(6)),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// "查看详情"幽灵链接：紫字 + 右箭头，无边框。
class _DetailLink extends StatelessWidget {
  const _DetailLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '查看详情',
              style: TextStyle(
                fontSize: ui(12),
                color: _kPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.2,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: ui(14), color: _kPurple),
          ],
        ),
      ),
    );
  }
}

// 补卡审核状态徽章（柔和底 + 实色字）
class _PunchAuditStatusBadge extends StatelessWidget {
  const _PunchAuditStatusBadge({required this.status});

  final _PunchAuditStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      alignment: Alignment.center,
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: ui(12),
          color: status.fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.2,
        ),
      ),
    );
  }
}

// 通过/驳回按钮：与学生端「我的作业」卡 _SmallButton 一致。
class _PunchActionButton extends StatelessWidget {
  const _PunchActionButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

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
          color: isPrimary ? null : _kCardGreyBg,
          gradient: isPrimary
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
            color: isPrimary ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: isPrimary ? AppFont.w600 : AppFont.w500,
            height: 16 / 12,
          ),
        ),
      ),
    );
  }
}

// —— Demo 数据 ——————————————————————————————————————————————————

// ignore: unused_element
List<_PunchAuditRecord> _demoPunchAudits() => const [
  _PunchAuditRecord(
    id: 'demo-1',
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    reason: '当晚在艺术楼排练至22:40，手机没电未能扫脸，回寝后已找宿管登记。',
    status: _PunchAuditStatus.pending,
  ),
  _PunchAuditRecord(
    id: 'demo-2',
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    reason: '当晚在艺术楼排练至22:40，手机没电未能扫脸，回寝后已找宿管登记。',
    status: _PunchAuditStatus.pending,
  ),
  _PunchAuditRecord(
    id: 'demo-3',
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    reason: '当晚在艺术楼排练至22:40，手机没电未能扫脸，回寝后已找宿管登记。',
    status: _PunchAuditStatus.pending,
  ),
];

// ignore: unused_element
List<_StudentRecord> _demoStudents() => const [
  _StudentRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    bedName: '无',
  ),
  _StudentRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    status: _StudentStatus.absent,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    bedName: '无',
  ),
  _StudentRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    bedName: '无',
  ),
  _StudentRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    bedName: '无',
  ),
  _StudentRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    status: _StudentStatus.absent,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    bedName: '无',
  ),
  _StudentRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    bedName: '无',
  ),
  _StudentRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    bedName: '无',
  ),
  _StudentRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    status: _StudentStatus.absent,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    bedName: '无',
  ),
  _StudentRecord(
    studentName: '王晴',
    studentNo: 'G3030201',
    avatarUrl: '',
    status: _StudentStatus.normal,
    dormName: '男生公寓 B-310',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    bedName: '无',
  ),
];

// ignore: unused_element
List<_DormRecord> _demoDormRecords() => const [
  _DormRecord(
    title: '晨查寝',
    status: _DormStatus.normal,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _DormRecord(
    title: '晨查寝',
    status: _DormStatus.absent,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '07:20前',
    punchTime: '07:18',
    note: '无',
  ),
  _DormRecord(
    title: '晚查寝',
    status: _DormStatus.late_,
    dormName: '女生宿舍3号楼 612',
    date: '2026-04-02',
    requiredTime: '21:20前',
    punchTime: '21:23',
    note: '教师拖堂',
  ),
];
