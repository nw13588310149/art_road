import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_repository.dart';
import '../data/smart_campus_role_theme.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ============================================================================
// 颜色常量
// ============================================================================

const Color _kBg = Color(0xFFEFF3FC);
const Color _kCardBg = Colors.white;
const Color _kTextPrimary = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextSub = Color(0xFF6D6B75);
const Color _kPurple = Color(0xFF8741FF);
const Color _kGreen = Color(0xFF0CAC40);
const Color _kBorder = Color(0xFFF3F2F3);
const Color _kPurpleSoft = Color(0xFFDAD2FF);

/// 与人脸库录入截取同比例（11:14），档案弹窗内略放大。
const double _kFaceImgPreviewWidth = 104;
const double _kFaceImgPreviewHeight = 132;

// ============================================================================
// 数据模型
// ============================================================================

enum _TeacherStatus { onDuty, leave, maternity }

extension on _TeacherStatus {
  String get label {
    switch (this) {
      case _TeacherStatus.onDuty:
        return '在岗';
      case _TeacherStatus.leave:
        return '请假';
      case _TeacherStatus.maternity:
        return '产假';
    }
  }

  /// 右上角徽章背景：在岗用浅绿，其它两类共用浅灰。
  Color get tagBg {
    switch (this) {
      case _TeacherStatus.onDuty:
        return const Color(0xFFDFFCF0);
      case _TeacherStatus.leave:
      case _TeacherStatus.maternity:
        return const Color(0xFFF3F2F3);
    }
  }

  /// 圆点 / 文字色。
  Color get tagFg {
    switch (this) {
      case _TeacherStatus.onDuty:
        return _kGreen;
      case _TeacherStatus.leave:
      case _TeacherStatus.maternity:
        return _kTextHint;
    }
  }
}

_TeacherStatus _parseTeacherStatus(dynamic raw) {
  if (raw == null) return _TeacherStatus.onDuty;
  final s = raw.toString().toLowerCase();
  final cn = raw.toString();
  if (s == '1' || s == 'onduty' || s == 'normal' || cn.contains('在岗')) {
    return _TeacherStatus.onDuty;
  }
  if (s == '2' || s == 'leave' || cn.contains('请假')) {
    return _TeacherStatus.leave;
  }
  if (s == '3' || s == 'maternity' || cn.contains('产假')) {
    return _TeacherStatus.maternity;
  }
  return _TeacherStatus.onDuty;
}

class _Teacher {
  const _Teacher({
    required this.name,
    required this.teacherId,
    required this.summaryInfo,
    required this.status,
    this.userId = '',
    this.avatarUrl = '',
    this.faceImgUrl = '',
    this.roleLabels = const [],
    this.nickname = '',
    this.gender = '',
    this.introduce = '',
    this.campusName = '',
    this.phone = '',
    this.remark = '',
  });

  final String userId;
  final String name;

  /// 工号 / 教师编号。
  final String teacherId;

  final String avatarUrl;
  final String faceImgUrl;

  /// 卡片第二行：简介等摘要信息。
  final String summaryInfo;

  /// 身份标签（由 `roles` 解析）。
  final List<String> roleLabels;

  final _TeacherStatus status;

  final String nickname;
  final String gender;
  final String introduce;
  final String campusName;
  final String phone;
  final String remark;

  factory _Teacher.fromJson(Map<String, dynamic> json) {
    final nickname = _pickString(json, ['nickname', 'nickName'], '');
    final realname = _pickString(json, ['realname', 'realName'], '');
    final name = nickname.isNotEmpty
        ? nickname
        : (realname.isNotEmpty
              ? realname
              : _pickString(json, ['name', 'teacherName'], '未命名'));

    final no = _pickString(json, [
      'no',
      'teacherNo',
      'code',
      'workNo',
      'employeeNo',
    ], '');

    final introduce = _pickString(json, [
      'introduce',
      'intro',
      'bio',
      'description',
    ], '');
    final gender = _pickString(json, ['gender', 'sex'], '');
    final campusName = _pickString(json, [
      'schoolCampusName',
      'campusName',
    ], '');

    final rawHeadUrl = _pickString(json, [
      'headUrl',
      'avatarUrl',
      'avatar',
      'headImg',
    ], '');
    final avatarUrl = rawHeadUrl.isEmpty ? '' : MediaUrl.resolve(rawHeadUrl);

    final roleLabels = _parseTeacherRoles(json['roles']);

    final summaryBuf = StringBuffer();
    if (introduce.isNotEmpty) {
      summaryBuf.write(introduce);
    } else {
      if (gender.isNotEmpty) summaryBuf.write(gender);
      if (campusName.isNotEmpty) {
        if (summaryBuf.isNotEmpty) summaryBuf.write(' · ');
        summaryBuf.write(campusName);
      }
    }
    final summaryInfo =
        summaryBuf.isEmpty ? '—' : summaryBuf.toString().trim();

    final userId = readSnowflakeId(json['id'] ?? json['userId']) ?? '';

    return _Teacher(
      userId: userId,
      name: name,
      teacherId: no,
      avatarUrl: avatarUrl,
      summaryInfo: summaryInfo,
      roleLabels: roleLabels,
      status: _parseTeacherStatus(
        json['teacherStatus'] ?? json['status'] ?? json['workStatus'],
      ),
      nickname: nickname,
      gender: gender,
      introduce: introduce,
      campusName: campusName,
      phone: _pickString(json, ['phone', 'mobile', 'tel'], ''),
      remark: _pickString(json, ['remark', 'comment', 'note'], ''),
    );
  }

  /// 从 `teacherDetail` 嵌套结构构造。
  factory _Teacher.fromDetailJson(Map<String, dynamic> json) {
    final user = _pickNestedMap(json, ['user']);
    final schoolTeacher = _pickNestedMap(json, ['schoolTeacher']);
    final schoolCampus = _pickNestedMap(json, ['schoolCampus']);

    final nickname = _pickString(user, ['nickname', 'nickName'], '');
    final realname = _pickString(user, ['realname', 'realName'], '');
    final name = nickname.isNotEmpty
        ? nickname
        : (realname.isNotEmpty ? realname : '未命名');

    final headUrlRaw = _pickString(user, ['headUrl', 'avatar'], '');
    final avatarUrl = headUrlRaw.isNotEmpty ? MediaUrl.resolve(headUrlRaw) : '';
    final faceImgRaw = _pickString(json, ['faceImg'], '');

    final userId = readSnowflakeId(user['id'] ?? user['userId']) ?? '';
    final teacherNo = _pickString(schoolTeacher, ['no', 'teacherNo'], '');

    final introduce = _pickString(user, ['introduce'], '');
    var gender = _pickString(user, ['gender', 'sex'], '');
    if (gender.isEmpty) {
      gender = _pickString(schoolTeacher, ['gender', 'sex'], '');
    }
    if (gender.isEmpty) {
      gender = _pickString(json, ['gender', 'sex'], '');
    }
    final campus = _pickString(schoolCampus, ['name'], '');
    final campusName = campus.isNotEmpty
        ? campus
        : _pickString(json, ['schoolCampusName'], '');

    final roleLabels = _parseTeacherRoles(
      schoolTeacher['roles'] ?? json['roles'],
    );

    final summaryBuf = StringBuffer();
    if (introduce.isNotEmpty) {
      summaryBuf.write(introduce);
    } else {
      if (gender.isNotEmpty) summaryBuf.write(gender);
      if (campusName.isNotEmpty) {
        if (summaryBuf.isNotEmpty) summaryBuf.write(' · ');
        summaryBuf.write(campusName);
      }
    }

    final remarkRaw = schoolTeacher['remark'] ?? user['remark'];
    final remark = remarkRaw == null ? '' : remarkRaw.toString().trim();
    final mobile = _pickString(user, ['mobile', 'phone'], '');

    return _Teacher(
      userId: userId,
      name: name,
      teacherId: teacherNo,
      avatarUrl: avatarUrl,
      faceImgUrl: faceImgRaw,
      summaryInfo: summaryBuf.isEmpty ? '—' : summaryBuf.toString(),
      roleLabels: roleLabels,
      status: _parseTeacherStatus(
        schoolTeacher['teacherStatus'] ?? json['teacherStatus'],
      ),
      nickname: nickname,
      gender: gender,
      introduce: introduce.isEmpty ? '—' : introduce,
      campusName: campusName.isEmpty ? '—' : campusName,
      phone: mobile.isEmpty ? '—' : mobile,
      remark: remark.isEmpty ? '—' : remark,
    );
  }
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return fallback;
}

String _teacherRoleLabel(String token) {
  switch (token.trim().toLowerCase()) {
    case 'head_teacher':
    case 'headteacher':
      return '班主任';
    case 'course_teacher':
    case 'courseteacher':
    case 'teacher':
      return '任课老师';
    case 'manager':
      return '教务老师';
    case 'dormitory':
    case 'dorm':
      return '宿管';
    case 'headmaster':
      return '校长';
    default:
      final raw = token.trim();
      return raw.isEmpty ? '' : raw;
  }
}

List<String> _parseTeacherRoles(dynamic raw) {
  if (raw == null) return const [];
  final s = raw.toString().trim();
  if (s.isEmpty || s.toLowerCase() == 'null') return const [];
  final labels = <String>[];
  for (final part in s.split(',')) {
    final label = _teacherRoleLabel(part);
    if (label.isNotEmpty && !labels.contains(label)) {
      labels.add(label);
    }
  }
  return labels;
}

/// 教师身份标签配色（五身份主题色）。
({Color bg, Color fg}) _teacherRoleColors(String label) =>
    smartCampusRoleTagColors(label);

Map<String, dynamic> _pickNestedMap(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final k in keys) {
    final v = json[k];
    if (v is Map) return Map<String, dynamic>.from(v);
  }
  return const {};
}

List<Map<String, dynamic>> _extractApiList(dynamic raw) {
  final list = raw is List
      ? raw
      : (raw is Map && raw['records'] is List
            ? raw['records'] as List
            : (raw is Map && raw['list'] is List
                  ? raw['list'] as List
                  : (raw is Map && raw['data'] is List
                        ? raw['data'] as List
                        : const [])));
  return [
    for (final item in list)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

class _ClassFilterOption {
  const _ClassFilterOption({required this.id, required this.label});

  final String? id;
  final String label;

  static const all = _ClassFilterOption(id: null, label: _kAllClasses);

  @override
  bool operator ==(Object other) =>
      other is _ClassFilterOption && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

String _classListItemLabel(Map<String, dynamic> m) {
  return _pickString(m, [
    'name',
    'className',
    'class',
    'fullName',
    'classFullName',
  ], '');
}

List<_ClassFilterOption> _buildClassFilterOptions(List<dynamic> list) {
  final options = <_ClassFilterOption>[];
  for (final item in list) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final id = pickFirstSnowflakeId(m, ['id', 'classId', 'cId']) ??
        _pickString(m, ['id', 'classId', 'cId'], '');
    if (id.isEmpty || id == '0') continue;
    final label = _classListItemLabel(m);
    if (label.isEmpty) continue;
    options.add(_ClassFilterOption(id: id, label: label));
  }
  return [_ClassFilterOption.all, ...options];
}

const _kAllClasses = '全部班级';
const _kFallbackClassOptions = <_ClassFilterOption>[_ClassFilterOption.all];

// ============================================================================
// 入口视图
// ============================================================================

/// 管理员端「教师管理」总览页。
///
/// 自上而下：
/// 1. **顶部白色 banner**（970×62，白→#F9EDFF 微紫渐变 + 16 圆角）：
///    左 32 返回按钮 + 居中标题「教师管理」16/600 + 12 灰副标题。
/// 2. **5 张彩色渐变统计卡**（100 高 + 12 圆角）：
///    在岗 / 请假 / 产假 / 班主任 / 名册总数；分别紫 / 橙 / 绿 / 红 / 红
///    渐变 + 14/500 标题 + 32/Barlow/500 大数字。
/// 3. **筛选行**：[PopupSelectorField]「全部班级」+ 324×44 搜索框
///    （占位 "搜索姓名、工号、任课方向"），不带状态 tab。
/// 4. **结果条**：「当前结果 X 人」12 #0B081A。
/// 5. **教师卡 3 列网格**（315×98 白卡，12 gap）：左 40 头像 + 右上工号 +
///    名字 + 一句话部门·学科 + 灰色「任课·班主任·班级」/「任课」。
///    左下身份标签（统一紫色 #EAE5FF / #8741FF，高 17）；右上 cut-corner 状态徽章
///    （在岗 #DFFCF0 + #0CAC40，请假/产假 #F3F2F3 + #B6B5BB），
///    徽章内有一个圆点 + 状态文字。
///
/// 卡片整体可点 → 「教师档案」`GradientHeaderDialog`：
/// 顶部 #D2C6FF→白渐变 + 头像 / 姓名 / 部门 / 工号；行政班、任课方向、
/// 教研角色、手机、入职日期、状态、备注；底部「导出档案 / 取消」
/// `AppDialogActionBar`。
///
/// 数据接入：进入页面立即并发拉
///   - `POST /app/school/v2/manager/classList`  → 「全部班级」dropdown
///   - `POST /app/school/v2/manager/teacherList` → 教师卡列表
/// 班级 / 关键字变化时只重新拉 `teacherList`；不再注入任何模拟教师 / 班级
/// 兜底数据：接口失败或返回空数组直接走「暂无符合条件的教师」空态。
class AdminTeacherManagementView extends ConsumerStatefulWidget {
  const AdminTeacherManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminTeacherManagementView> createState() =>
      _AdminTeacherManagementViewState();
}

class _AdminTeacherManagementViewState
    extends ConsumerState<AdminTeacherManagementView> {
  String? _selectedClassId;
  List<_ClassFilterOption> _classOptions = _kFallbackClassOptions;
  String _searchKw = '';

  /// `teacherSum` 接口返回的统计；-1 表示尚未拉到。
  int _sumOnDuty = -1;
  int _sumOnLeave = -1;
  int _sumHeadTeacher = -1;
  int _sumTotal = -1;

  /// 服务端拉到的教师列表；初始 `null` 表示「还没拉到结果」，与「拉到了
  /// 但是空数组」做区分（前者不渲染统计/卡片，后者落到「暂无教师」空态）。
  List<_Teacher>? _serverTeachers;

  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
      _loadSum();
      _loadTeachers();
    });
  }

  Future<void> _loadClasses() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final resp = await repo.classList();
      if (!mounted) return;
      if (!resp.isSuccess || resp.data == null) return;

      final options = _buildClassFilterOptions(_extractApiList(resp.data));
      if (!mounted) return;
      setState(() {
        _classOptions = options.isEmpty ? _kFallbackClassOptions : options;
        if (_selectedClassId != null &&
            !options.any((o) => o.id == _selectedClassId)) {
          _selectedClassId = null;
        }
      });
    } catch (_) {}
  }

  /// 拉教师统计（在岗 / 请假 / 班主任 / 总数）。
  Future<void> _loadSum() async {
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.teacherSum();
    if (!mounted) return;

    if (!resp.isSuccess || resp.data is! Map) return;
    final m = (resp.data as Map).cast<String, dynamic>();
    int? n(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    setState(() {
      _sumOnDuty = n(m['onDutyCount']) ?? 0;
      _sumOnLeave = n(m['onLeaveCount']) ?? 0;
      _sumHeadTeacher = n(m['headTeacherCount']) ?? 0;
      _sumTotal = n(m['totalCount']) ?? 0;
    });
  }

  Future<void> _loadTeachers() async {
    final token = ++_searchToken;

    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.teacherList(
      classId: _selectedClassId ?? '',
      keyword: _searchKw.trim().isEmpty ? null : _searchKw.trim(),
    );
    if (!mounted || token != _searchToken) return;

    if (!resp.isSuccess || resp.data == null) {
      setState(() => _serverTeachers = const []);
      return;
    }

    final parsed = <_Teacher>[];
    for (final item in _extractApiList(resp.data)) {
      try {
        parsed.add(_Teacher.fromJson(item));
      } catch (_) {}
    }

    setState(() => _serverTeachers = parsed);
  }

  /// 当前生效的教师列表。`null` → 还没回包；空数组 → 接口返回 0 条。
  List<_Teacher> get _teachers => _serverTeachers ?? const <_Teacher>[];

  List<_Teacher> get _filtered => _teachers;

  void _openProfile(_Teacher t) {
    showScaledDialog<void>(
      context: context,
      builder: (ctx) => _TeacherProfileDialog(teacher: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final list = _filtered;

    // 统计数据完全来自 teacherSum 接口；接口未返回时显示 0。
    final onDuty = _sumOnDuty >= 0 ? _sumOnDuty : 0;
    final onLeave = _sumOnLeave >= 0 ? _sumOnLeave : 0;
    final headTeachers = _sumHeadTeacher >= 0 ? _sumHeadTeacher : 0;
    final total = _sumTotal >= 0 ? _sumTotal : 0;

    return SmartCampusSecondaryPageShell(
      backgroundColor: _kBg,
      bodyTopClipRadius: 8,
      header: _Banner(onBack: widget.onBack),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsRow(
              onDuty: onDuty,
              onLeave: onLeave,
              headTeachers: headTeachers,
              total: total,
            ),
            SizedBox(height: ui(16)),
            _FilterRow(
              selectedClassId: _selectedClassId,
              classOptions: _classOptions,
              onClassChanged: (id) {
                setState(() => _selectedClassId = id);
                _loadTeachers();
              },
              onSearchChanged: (kw) {
                setState(() => _searchKw = kw);
                _loadTeachers();
              },
            ),
            SizedBox(height: ui(10)),
            Text(
              '当前结果 ${list.length}人',
              style: TextStyle(
                fontSize: ui(12),
                height: 1.2,
                color: _kTextPrimary,
                fontFamily: 'PingFang SC',
              ),
            ),
            SizedBox(height: ui(12)),
          _TeacherGrid(teachers: list, onTap: _openProfile),
        ],
      ),
    );
  }
}

// ============================================================================
// Banner
// ============================================================================

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(62),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        image: DecorationImage(
          image: AssetImage(AppAssets.xiaoquanHeaderBg),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(12),
            top: ui(15),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: Container(
                width: ui(32),
                height: ui(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorder, width: 1),
                ),
                child: Icon(
                  Icons.chevron_left,
                  size: ui(20),
                  color: _kTextPrimary,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '教师管理',
                  style: TextStyle(
                    fontSize: ui(16),
                    height: 1.2,
                    fontWeight: AppFont.w600,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  '人事档案、部门归属、任课与角色；与教师端登录权限、班主任带班关系对齐',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(12),
                    height: 1.2,
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
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

// ============================================================================
// 5 列统计
// ============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.onDuty,
    required this.onLeave,
    required this.headTeachers,
    required this.total,
  });

  final int onDuty;
  final int onLeave;
  final int headTeachers;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminTeacherManagementStatCard1,
            label: '在岗',
            value: onDuty,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminTeacherManagementStatCard2,
            label: '请假',
            value: onLeave,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminTeacherManagementStatCard3,
            label: '班主任',
            value: headTeachers,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminTeacherManagementStatCard4,
            label: '名册总数',
            value: total,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 筛选行：班级 dropdown + 搜索（无状态 tab）
// ============================================================================

class _ClassFilterField extends StatefulWidget {
  const _ClassFilterField({
    required this.options,
    required this.selectedClassId,
    required this.onChanged,
  });

  final List<_ClassFilterOption> options;
  final String? selectedClassId;
  final ValueChanged<String?> onChanged;

  @override
  State<_ClassFilterField> createState() => _ClassFilterFieldState();
}

class _ClassFilterFieldState extends State<_ClassFilterField> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  _ClassFilterOption get _selected => widget.options.firstWhere(
    (o) => o.id == widget.selectedClassId,
    orElse: () => _ClassFilterOption.all,
  );

  Future<void> _openMenu() async {
    final fieldCtx = _fieldKey.currentContext;
    if (fieldCtx == null) return;
    setState(() => _open = true);
    final selected = await showAppPopupSelector<_ClassFilterOption>(
      anchorContext: fieldCtx,
      items: widget.options,
      value: _selected,
      itemLabel: (o) => o.label,
      width: DashboardScaleScope.of(fieldCtx).ui(280),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null) widget.onChanged(selected.id);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      key: _fieldKey,
      onTap: _openMenu,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: ui(220),
        height: ui(44),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorder),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selected.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.2,
                  color: _kTextPrimary,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(22),
                color: const Color(0xFFC6C6C6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatefulWidget {
  const _FilterRow({
    required this.selectedClassId,
    required this.classOptions,
    required this.onClassChanged,
    required this.onSearchChanged,
  });

  final String? selectedClassId;
  final List<_ClassFilterOption> classOptions;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ClassFilterField(
          options: widget.classOptions,
          selectedClassId: widget.selectedClassId,
          onChanged: widget.onClassChanged,
        ),
        const Spacer(),
        Container(
          width: ui(324),
          height: ui(44),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
          ),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          child: Row(
            children: [
              AppAssetGraphic(
                AppAssets.shellV2Search,
                width: ui(16),
                height: ui(16),
                fit: BoxFit.contain,
              ),
              SizedBox(width: ui(10)),
              Expanded(
                child: AppTextField(
                  controller: _searchCtrl,
                  onChanged: widget.onSearchChanged,
                  cursorColor: _kPurple,
                  cursorWidth: 1.5,
                  cursorHeight: ui(16),
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.2,
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '搜索姓名、工号',
                    hintStyle: TextStyle(
                      fontSize: ui(14),
                      color: const Color(0xFFD1D1D1),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 教师卡 3 列网格
// ============================================================================

class _TeacherGrid extends StatelessWidget {
  const _TeacherGrid({required this.teachers, required this.onTap});

  final List<_Teacher> teachers;
  final ValueChanged<_Teacher> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (teachers.isEmpty) {
      return Container(
        height: ui(120),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Text(
          '暂无符合条件的教师',
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final cols = constraints.maxWidth >= 900
            ? 3
            : (constraints.maxWidth >= 600 ? 2 : 1);
        final cardWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in teachers)
              SizedBox(
                width: cardWidth,
                child: _TeacherCard(teacher: t, onTap: () => onTap(t)),
              ),
          ],
        );
      },
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher, required this.onTap});

  final _Teacher teacher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(98),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              // 内容列右侧放宽到距卡片右边框 ui(12)，让底部标签滚动区更宽；
              // 姓名行/摘要行单独保留 ui(42) 右内边距，避开右上状态徽章。
              padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(12), ui(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: teacher.name, avatarUrl: teacher.avatarUrl),
                  SizedBox(width: ui(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: ui(42)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      teacher.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textHeightBehavior:
                                          const TextHeightBehavior(
                                        applyHeightToFirstAscent: false,
                                        applyHeightToLastDescent: false,
                                      ),
                                      style: TextStyle(
                                        fontSize: ui(14),
                                        height: 1.0,
                                        fontWeight: AppFont.w500,
                                        color: _kTextPrimary,
                                        fontFamily: 'PingFang SC',
                                      ),
                                    ),
                                  ),
                                  if (teacher.teacherId.isNotEmpty) ...[
                                    SizedBox(width: ui(8)),
                                    Text(
                                      teacher.teacherId,
                                      style: TextStyle(
                                        fontSize: ui(12),
                                        height: 1.2,
                                        color: _kTextHint,
                                        fontFamily: 'PingFang SC',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: ui(6)),
                              Text(
                                teacher.summaryInfo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  height: 1.2,
                                  color: _kTextPrimary,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (teacher.roleLabels.isNotEmpty) ...[
                          SizedBox(height: ui(10)),
                          // 标签滚动区使用内容列整宽，右边界距卡片右边框 ui(12)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                for (var i = 0;
                                    i < teacher.roleLabels.length;
                                    i++) ...[
                                  if (i > 0) SizedBox(width: ui(4)),
                                  _RoleTagChip(label: teacher.roleLabels[i]),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 右上状态徽章
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                height: ui(22),
                padding: EdgeInsets.symmetric(horizontal: ui(8)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: teacher.status.tagBg,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(ui(12)),
                    bottomLeft: Radius.circular(ui(12)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: ui(6),
                      height: ui(6),
                      decoration: BoxDecoration(
                        color: teacher.status.tagFg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: ui(4)),
                    Text(
                      teacher.status.label,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.0,
                        color: teacher.status.tagFg,
                        fontFamily: 'PingFang SC',
                      ),
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

class _RoleTagChip extends StatelessWidget {
  const _RoleTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final colors = _teacherRoleColors(label);
    return Container(
      height: ui(17),
      padding: EdgeInsets.symmetric(horizontal: ui(6)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(12),
          height: 15.24 / 12,
          color: colors.fg,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.avatarUrl = '', this.size = 40});

  final String name;

  /// 后端 `headUrl` 经 [MediaUrl.resolve] 解析的完整地址。空串走首字母兜底。
  final String avatarUrl;

  /// 默认 40 配卡片缩略图；档案弹窗里用 56 / 64 等也可复用。
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = name.isEmpty ? '·' : name.characters.first;
    final placeholder = Container(
      width: ui(size),
      height: ui(size),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDAD2FF),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(size * 0.4),
          height: 1.0,
          fontWeight: AppFont.w600,
          color: _kPurple,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
    if (avatarUrl.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: Image.network(
        avatarUrl,
        width: ui(size),
        height: ui(size),
        fit: BoxFit.cover,
        // 404 / CORS / 离线时退回首字母占位，避免出现"问号 / 黑块"。
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

// ============================================================================
// 教师档案 弹窗
// ============================================================================

class _TeacherProfileDialog extends ConsumerStatefulWidget {
  const _TeacherProfileDialog({required this.teacher});

  final _Teacher teacher;

  @override
  ConsumerState<_TeacherProfileDialog> createState() =>
      _TeacherProfileDialogState();
}

class _TeacherProfileDialogState extends ConsumerState<_TeacherProfileDialog> {
  _Teacher? _detail;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    if (widget.teacher.userId.isNotEmpty) {
      _fetchDetail();
    }
  }

  Future<void> _fetchDetail() async {
    setState(() => _loadingDetail = true);
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.teacherDetail(id: widget.teacher.userId);
    if (!mounted) return;

    if (resp.isSuccess && resp.data is Map) {
      try {
        final m = Map<String, dynamic>.from(resp.data as Map);
        setState(() {
          _detail = _Teacher.fromDetailJson(m);
          _loadingDetail = false;
        });
        return;
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingDetail = false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final t = _detail ?? widget.teacher;
    final phone = t.phone.isEmpty ? '—' : t.phone;

    return GradientHeaderDialog(
      title: '教师档案',
      titlePaddingTop: 28,
      width: 428,
      headerAsset: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _Avatar(
                          name: t.name,
                          avatarUrl: t.avatarUrl,
                          size: 56,
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
                                      t.name,
                                      style: TextStyle(
                                        fontSize: ui(16),
                                        height: 1.2,
                                        fontWeight: AppFont.w600,
                                        color: Colors.black,
                                        fontFamily: 'PingFang SC',
                                      ),
                                    ),
                                  ),
                                  if (_loadingDetail)
                                    Text(
                                      '加载中…',
                                      style: TextStyle(
                                        fontSize: ui(12),
                                        color: _kTextHint,
                                        fontFamily: 'PingFang SC',
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: ui(4)),
                              Text(
                                t.summaryInfo != '—'
                                    ? t.summaryInfo
                                    : t.campusName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  height: 1.2,
                                  color: _kTextSub,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                              SizedBox(height: ui(2)),
                              Text(
                                t.teacherId.isEmpty ? '—' : t.teacherId,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  height: 1.2,
                                  color: _kTextHint,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(10)),
                    _ProfileRow(
                      label: '教师工号：',
                      value: t.teacherId.isEmpty ? '—' : t.teacherId,
                    ),
                    _ProfileRow(
                      label: '教师性别：',
                      value: t.gender.isEmpty ? '—' : t.gender,
                    ),
                    _ProfileRow(label: '教师状态：', value: t.status.label),
                    _ProfileRow(label: '联系电话：', value: phone),
                    _ProfileRow(
                      label: '所在校区：',
                      value: t.campusName.isEmpty ? '—' : t.campusName,
                    ),
                    _ProfileRow(
                      label: '个人简介：',
                      value: t.introduce.isEmpty ? '—' : t.introduce,
                      multiline: true,
                    ),
                    _ProfileRow(
                      label: '教师备注：',
                      value: t.remark.isEmpty ? '—' : t.remark,
                      multiline: true,
                    ),
                  ],
                ),
              ),
              SizedBox(width: ui(12)),
              _TeacherFaceImgPreview(
                name: t.name,
                faceImgUrl: t.faceImgUrl,
                heroTag: 'teacher_face_${t.userId}',
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          _TeacherRolesSection(roleLabels: t.roleLabels),
        ],
      ),
    );
  }
}

class _TeacherFaceImgPreview extends StatelessWidget {
  const _TeacherFaceImgPreview({
    required this.name,
    required this.faceImgUrl,
    required this.heroTag,
  });

  final String name;
  final String faceImgUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasImage = faceImgUrl.trim().isNotEmpty;
    final resolvedUrl = hasImage ? MediaUrl.resolve(faceImgUrl) : '';

    Widget placeholder() {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.face_retouching_natural_outlined,
            size: ui(32),
            color: _kPurple.withValues(alpha: 0.45),
          ),
          SizedBox(height: ui(6)),
          Text(
            '暂未录入',
            style: TextStyle(
              fontSize: ui(10),
              height: 1.2,
              color: _kTextSub,
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: hasImage && resolvedUrl.isNotEmpty
          ? () => showImageGallery(
              context,
              images: [resolvedUrl],
              heroTagPrefix: heroTag,
            )
          : null,
      child: Container(
        width: ui(_kFaceImgPreviewWidth),
        height: ui(_kFaceImgPreviewHeight),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFEDE6FF),
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kPurpleSoft, width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage && resolvedUrl.isNotEmpty)
              Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder(),
              )
            else
              placeholder(),
            if (hasImage && resolvedUrl.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: ui(4)),
                  color: Colors.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Text(
                    '点击放大',
                    style: TextStyle(
                      fontSize: ui(10),
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1.0,
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

class _TeacherRolesSection extends StatelessWidget {
  const _TeacherRolesSection({required this.roleLabels});

  final List<String> roleLabels;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '教师身份',
          style: TextStyle(
            fontSize: ui(14),
            height: 1.4,
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
        SizedBox(height: ui(8)),
        if (roleLabels.isEmpty)
          Text(
            '暂无身份标签',
            style: TextStyle(
              fontSize: ui(14),
              height: 1.4,
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (var i = 0; i < roleLabels.length; i++) ...[
                  if (i > 0) SizedBox(width: ui(4)),
                  _RoleTagChip(label: roleLabels[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.only(bottom: ui(8)),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: ui(80),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ui(14),
                height: 1.4,
                color: _kTextHint,
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: ui(14),
                height: 1.4,
                color: _kTextPrimary,
                fontFamily: 'PingFang SC',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
