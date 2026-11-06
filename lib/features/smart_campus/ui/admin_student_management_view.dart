// 学生模型上的「专业 / 方向 / 行政班 / 住宿 / 电话 / 备注」均为带默认值的
// 命名参数，部分条目沿用默认值；analyzer 误报为 unused_element_parameter，整体忽略。
// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
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
import '../data/admin_student_exam_data.dart';
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
const Color _kPurpleSoft = Color(0xFFDAD2FF);
const Color _kBorder = Color(0xFFF3F2F3);

/// 与人脸库录入截取预览同比例（11:14），学籍档案内略放大展示。
const double _kFaceImgPreviewWidth = 104;
const double _kFaceImgPreviewHeight = 132;

// ============================================================================
// 数据模型 + 演示数据
// ============================================================================

enum _StudentStatus { enrolled, suspended, transferring, graduated }

/// 把后端 `status` 字段（数字 / 字符串 / 中文）兜底映射到本地枚举：
/// - 1 / 'enrolled' / '在籍' → enrolled
/// - 2 / 'suspended' / '休学' → suspended
/// - 3 / 'transferring' / '转学' → transferring
/// - 4 / 'graduated' / '毕业' → graduated
/// - 其它（含 null）→ enrolled（最常见，作为安全默认）
_StudentStatus _parseStudentStatus(dynamic raw) {
  if (raw == null) return _StudentStatus.enrolled;
  final s = raw.toString().toLowerCase();
  if (s == '1' || s == 'enrolled' || raw.toString().contains('在籍')) {
    return _StudentStatus.enrolled;
  }
  if (s == '2' || s == 'suspended' || raw.toString().contains('休学')) {
    return _StudentStatus.suspended;
  }
  if (s == '3' || s == 'transferring' || raw.toString().contains('转学')) {
    return _StudentStatus.transferring;
  }
  if (s == '4' || s == 'graduated' || raw.toString().contains('毕业')) {
    return _StudentStatus.graduated;
  }
  return _StudentStatus.enrolled;
}

extension on _StudentStatus {
  String get label {
    switch (this) {
      case _StudentStatus.enrolled:
        return '在籍';
      case _StudentStatus.suspended:
        return '休学';
      case _StudentStatus.transferring:
        return '退学';
      case _StudentStatus.graduated:
        return '毕业';
    }
  }

  Color get bg {
    switch (this) {
      case _StudentStatus.enrolled:
        return _kPurpleSoft;
      case _StudentStatus.suspended:
        return const Color(0xFFFFE7C2);
      case _StudentStatus.transferring:
        return const Color(0xFFD2EAFF);
      case _StudentStatus.graduated:
        return const Color(0xFFE0E0E0);
    }
  }

  Color get fg {
    switch (this) {
      case _StudentStatus.enrolled:
        return _kPurple;
      case _StudentStatus.suspended:
        return const Color(0xFFE89B30);
      case _StudentStatus.transferring:
        return const Color(0xFF1F77E0);
      case _StudentStatus.graduated:
        return const Color(0xFF6D6B75);
    }
  }
}

class _Student {
  const _Student({
    required this.name,
    required this.studentId,
    required this.classInfo,
    required this.dormInfo,
    required this.status,
    this.userId = '',
    this.avatarUrl = '',
    this.faceImgUrl = '',
    this.tags = const [],
    this.major = '—',
    this.direction = '民族唱法',
    this.adminClass = '高三音乐实验班',
    this.dorm = '女生公寓 A-602',
    this.phone = '17656287947',
    this.parentPhone = '17656287947',
    this.recentChange = '无',
    this.remark = '专业主项稳定，文化科需跟进英语作文。',
    this.gender = '',
  });

  /// 后端数据库主键（雪花 id），用于调用 studentDetail；
  /// 不同于 [studentId]（学号），两者含义不同。
  final String userId;
  final String name;
  final String studentId;
  final String classInfo;
  final String dormInfo;
  final _StudentStatus status;

  /// 后端 `headUrl` 经 [MediaUrl.resolve] 拼齐的完整 URL，空串表示走首字母兜底。
  final String avatarUrl;

  /// 人脸库采集照 `faceImg`（相对路径，展示时用 [MediaUrl.resolve]）。
  final String faceImgUrl;

  /// 学籍标签（`schoolStudent.tags`，逗号分隔）。
  final List<String> tags;

  final String major;
  final String direction;
  final String adminClass;
  final String dorm;
  final String phone;
  final String parentPhone;
  final String recentChange;
  final String remark;
  final String gender;

  /// 从后端 `studentList` 单条记录构造。
  ///
  /// 字段名做了若干兜底（`name` / `stuName` / `studentName`、
  /// `studentNo` / `studentId` / `stuNo` / `no`、`className` / `class` 等），
  /// 找不到时回退为占位串，避免空白卡片。
  factory _Student.fromJson(Map<String, dynamic> json) {
    final nickname = _pickString(json, ['nickname', 'nickName'], '');
    final realname = _pickString(json, ['realname', 'realName'], '');
    final name = nickname.isNotEmpty
        ? nickname
        : (realname.isNotEmpty
              ? realname
              : _pickString(json, ['name', 'stuName', 'studentName'], '未命名'));

    final headUrlRaw = _pickString(json, [
      'headUrl',
      'avatar',
      'avatarUrl',
    ], '');
    final avatarUrl = headUrlRaw.isNotEmpty ? MediaUrl.resolve(headUrlRaw) : '';

    final studentNo = _pickString(json, [
      'no',
      'studentNo',
      'studentId',
      'stuNo',
      'stuId',
      'code',
      'studentCode',
    ], '');

    var className = '';
    final bigClass = json['bigClass'];
    if (bigClass is Map) {
      className = _pickString(Map<String, dynamic>.from(bigClass), [
        'name',
        'className',
        'groupName',
        'fullName',
      ], '');
    }
    if (className.isEmpty) {
      className = _pickString(json, [
        'className',
        'class',
        'gradeName',
        'classFullName',
      ], '');
    }

    final majorName = _pickString(json, [
      'majorName',
      'major',
      'subject',
      'subjectName',
    ], '声乐');
    final directionName = _pickString(json, [
      'directionName',
      'direction',
      'directionText',
      'majorDirection',
    ], '民族唱法');

    final bedInfo = _pickString(json, ['bedInfo'], '');
    final bedIdRaw = json['bedId'];
    final hasBedId =
        bedIdRaw != null &&
        '$bedIdRaw'.trim().isNotEmpty &&
        '$bedIdRaw' != '0' &&
        bedIdRaw != 0;
    final isLiving = hasBedId || bedInfo.isNotEmpty;
    final dormName = bedInfo.isNotEmpty
        ? bedInfo
        : _pickString(json, [
            'dorm',
            'dormName',
            'roomName',
            'apartment',
            'dormitory',
          ], '');

    final phone = _pickString(json, [
      'phone',
      'mobile',
      'studentPhone',
      'stuPhone',
      'tel',
    ], '');
    final parentPhone = _pickString(json, [
      'parentPhone',
      'parentMobile',
      'fatherPhone',
      'motherPhone',
      'guardianPhone',
    ], phone);
    final remark = _pickString(json, [
      'remark',
      'comment',
      'description',
      'note',
      'introduce',
    ], '');
    final gender = _pickString(json, ['gender', 'sex'], '');

    final classInfo = className.isEmpty ? '—' : className;

    final dormInfo = isLiving
        ? (dormName.isEmpty ? '宿舍' : '宿舍·$dormName')
        : '走读';

    // 后端主键（雪花 long）→ 只接受 String，禁止 num.toString() 污染精度。
    final userId =
        readSnowflakeId(json['id'] ?? json['userId'] ?? json['stuId']) ?? '';

    return _Student(
      userId: userId,
      name: name,
      studentId: studentNo,
      classInfo: classInfo,
      dormInfo: dormInfo,
      status: _parseStudentStatus(
        json['studentStatus'] ?? json['status'] ?? json['stuStatus'],
      ),
      avatarUrl: avatarUrl,
      major: majorName,
      direction: directionName,
      adminClass: className.isEmpty ? '—' : className,
      dorm: isLiving ? (dormName.isEmpty ? '宿舍' : dormName) : '走读',
      phone: phone,
      parentPhone: parentPhone,
      recentChange: _pickString(json, [
        'lastChange',
        'recentChange',
        'changeDesc',
        'transferRemark',
      ], '无'),
      remark: remark.isEmpty ? '—' : remark,
      gender: gender,
    );
  }

  /// 从 `studentDetail` 嵌套结构构造（user / schoolStudent / schoolClass /
  /// dormitoryUser / parents）。
  factory _Student.fromDetailJson(Map<String, dynamic> json) {
    final user = _pickNestedMap(json, ['user']);
    final schoolStudent = _pickNestedMap(json, ['schoolStudent']);
    final schoolClass = _pickNestedMap(json, ['schoolClass']);
    final dormitoryUser = _pickNestedMap(json, ['dormitoryUser']);

    final nickname = _pickString(user, ['nickname', 'nickName'], '');
    final realname = _pickString(user, ['realname', 'realName'], '');
    final name = nickname.isNotEmpty
        ? nickname
        : (realname.isNotEmpty ? realname : '未命名');

    final headUrlRaw = _pickString(user, [
      'headUrl',
      'avatar',
      'avatarUrl',
    ], '');
    final avatarUrl = headUrlRaw.isNotEmpty ? MediaUrl.resolve(headUrlRaw) : '';

    final userId = readSnowflakeId(user['id'] ?? user['userId']) ?? '';
    final studentNo = _pickString(schoolStudent, ['no', 'studentNo'], '');

    final className = _pickString(schoolClass, [
      'name',
      'className',
      'groupName',
    ], '');

    final bedInfo = _pickString(dormitoryUser, ['bedInfo'], '');
    final bedId = _pickString(dormitoryUser, ['bedId'], '');
    final isLiving = bedInfo.isNotEmpty || (bedId.isNotEmpty && bedId != '0');
    final dormInfo = isLiving ? (bedInfo.isEmpty ? '宿舍' : '宿舍·$bedInfo') : '走读';
    final dorm = isLiving ? (bedInfo.isEmpty ? '宿舍' : bedInfo) : '走读';

    final phone = _pickString(user, ['mobile', 'phone'], '');
    final parentPhone = _pickParentPhone(json['parents']);

    final remarkRaw = schoolStudent['remark'];
    final remark = remarkRaw == null ? '' : remarkRaw.toString().trim();
    final faceImgRaw = _pickString(json, ['faceImg'], '');
    final tags = _parseTags(schoolStudent['tags']);
    var gender = _pickString(user, ['gender', 'sex'], '');
    if (gender.isEmpty) {
      gender = _pickString(schoolStudent, ['gender', 'sex'], '');
    }
    if (gender.isEmpty) {
      gender = _pickString(json, ['gender', 'sex'], '');
    }

    return _Student(
      userId: userId,
      name: name,
      studentId: studentNo,
      classInfo: className.isEmpty ? '—' : className,
      dormInfo: dormInfo,
      status: _parseStudentStatus(schoolStudent['studentStatus']),
      avatarUrl: avatarUrl,
      faceImgUrl: faceImgRaw,
      tags: tags,
      major: '—',
      direction: '—',
      adminClass: className.isEmpty ? '—' : className,
      dorm: dorm,
      phone: phone.isEmpty ? '—' : phone,
      parentPhone: parentPhone.isEmpty ? '—' : parentPhone,
      recentChange: '无',
      remark: remark.isEmpty ? '—' : remark,
      gender: gender,
    );
  }
}

/// 在 [json] 中按 [keys] 顺序找到第一个非空字符串值，否则返回 [fallback]。
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

String _pickParentPhone(dynamic parents) {
  if (parents is! List) return '';
  for (final item in parents) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final phone = _pickString(m, [
      'mobile',
      'phone',
      'parentPhone',
      'parentMobile',
    ], '');
    if (phone.isNotEmpty) return phone;
  }
  return '';
}

List<String> _parseTags(dynamic raw) {
  if (raw == null) return const [];
  final s = raw.toString().trim();
  if (s.isEmpty || s.toLowerCase() == 'null') return const [];
  return s
      .split(RegExp(r'[,，]'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

const _kAllClasses = '全部班级';

class _ClassFilterOption {
  const _ClassFilterOption({required this.id, required this.label});

  /// `null` = 全部班级。
  final String? id;
  final String label;

  static const all = _ClassFilterOption(id: null, label: _kAllClasses);

  @override
  bool operator ==(Object other) =>
      other is _ClassFilterOption && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// 从 `classList` 单条记录取下拉展示用的班级名称。
String _classListItemLabel(Map<String, dynamic> m) {
  return _pickString(m, [
    'name',
    'className',
    'class',
    'fullName',
    'classFullName',
  ], '');
}

/// 把 `classList` 转成 `(id, label)` 选项；label 仅显示班级名称。
List<_ClassFilterOption> _buildClassFilterOptions(List<dynamic> list) {
  final options = <_ClassFilterOption>[];
  for (final item in list) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final id =
        pickFirstSnowflakeId(m, ['id', 'classId', 'cId']) ??
        _pickString(m, ['id', 'classId', 'cId'], '');
    if (id.isEmpty || id == '0') continue;
    final label = _classListItemLabel(m);
    if (label.isEmpty) continue;
    options.add(_ClassFilterOption(id: id, label: label));
  }

  return [_ClassFilterOption.all, ...options];
}

/// 从 `classList` / `studentList` 等接口的 `data` 中提取数组。
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

const _kFallbackClassOptions = <_ClassFilterOption>[_ClassFilterOption.all];

// ============================================================================
// 入口视图
// ============================================================================

/// 管理员端「学生管理」总览页。
///
/// 自上而下：
/// 1. **顶部白色 banner**（970×62，白→#F9EDFF 微紫渐变 + 16 圆角）：
///    左 32 返回按钮 + 居中标题「学生管理」16/600 + 12 灰副标题。
/// 2. **4 张彩色渐变统计卡**（100 高 + 12 圆角）：
///    在籍学生 / 住校人数 / 非在籍·异动 / 名册总数；分别紫 / 橙 / 绿 / 红
///    渐变 (#E7DCFF / #FFF0DC / #DCFFE7 / #FFE2DC) + 14/500 标题
///    + 32/Barlow/500 大数字。
/// 3. **筛选行**：左侧白色 pill 容器内 5 个状态 tab（全部 / 在籍 / 休学 /
///    转学 / 毕业，黑底白字 active）；右侧并排 [PopupSelectorField]
///    「全部班级」+ 324×44 搜索框（占位 "搜索姓名、学号、手机、宿舍、家长"）。
/// 4. **结果条**：「当前结果 X 人」12 #0B081A。
/// 5. **学生卡 3 列网格**（315×88 白卡，12 gap）：左 40 头像 + 右上学号 +
///    名字 + 一句话班级·专业 + 灰色住宿。右上角 38×22 紫色「在籍」徽章
///    （cut-corner 形状，根据状态着色）。
///
/// 卡片整体可点 → 「学籍档案」`GradientHeaderDialog`：
/// 顶部 #D2C6FF→白渐变 + 头像 / 姓名 / 专业 / 学号；键值区紧贴头像下方
///（所在班级 / 学生性别 / 专业方向 / 所在宿舍 / 本人手机 / 家长手机 /
/// 最近异动 / 备注）；
/// 底部「导出学籍 / 取消」`AppDialogActionBar`。
///
/// 数据接入：进入页面立刻并发请求三条 v2 教务管理端接口
///   - `POST /app/school/v2/manager/classList`   → 「全部班级」dropdown
///   - `POST /app/school/v2/manager/studentSum`  → 顶部 4 张统计卡口径
///     (`normalCount` / `residentCount` / `abnormalCount` / `totalCount`)
///   - `POST /app/school/v2/manager/studentList` → 学生卡列表
///     (`SchoolStudentSearchReq`：`classId` 空串=全部班级 / 雪花字符串=指定班、
///     `current` / `keyword` / `size` / `studentStatus`)
///
/// 班级筛选 / 关键字 / 状态变化时只重新拉 `studentList`（带 classId /
/// keyword / studentStatus 参数）；统计卡口径来自 `studentSum`，不会被
/// 列表筛选反复触发。所有 mock / 兜底数据已移除，接口未返回 / 报错时
/// 列表显示为空，统计卡显示 0。
class AdminStudentManagementView extends ConsumerStatefulWidget {
  const AdminStudentManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminStudentManagementView> createState() =>
      _AdminStudentManagementViewState();
}

class _AdminStudentManagementViewState
    extends ConsumerState<AdminStudentManagementView> {
  /// `null` = 全部状态
  _StudentStatus? _statusFilter;

  /// `null` = 全部班级（请求 studentList 时传 classId: ""）。
  String? _selectedClassId;
  List<_ClassFilterOption> _classOptions = _kFallbackClassOptions;
  String _searchKw = '';

  /// `studentList` 拉到的学生（按当前 classId/status/keyword 过滤后的服务端
  /// 结果）。`null` = 还没拉到 / 接口失败 → 显示空态；空数组 = 接口成功但
  /// 当前条件下没有学生 → 也显示空态。不再使用任何本地 mock 兜底。
  List<_Student>? _serverStudents;

  /// `studentSum` 接口返回的整校口径统计：
  ///   normal / resident / abnormal / total。
  /// 任一值为 -1 表示尚未拉到 / 失败 → 顶部 4 卡回退到本地计算。
  int _sumNormal = -1;
  int _sumResident = -1;
  int _sumAbnormal = -1;
  int _sumTotal = -1;

  // 防抖：搜索框输入时用 token 控制最近一次请求；过期请求结果丢弃。
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    // 延后到 build 之后再触发，确保 ref 可读。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
      _loadSum();
      _loadStudents();
    });
  }

  Future<void> _loadClasses() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final resp = await repo.classList();
      if (!mounted) return;

      if (!resp.isSuccess || resp.data == null) return;

      // classList 的 data 为直接数组 [{ id, name, groupName, ... }, ...]
      final options = _buildClassFilterOptions(_extractApiList(resp.data));
      if (!mounted) return;
      setState(() {
        _classOptions = options.isEmpty ? _kFallbackClassOptions : options;
        if (_selectedClassId != null &&
            !options.any((o) => o.id == _selectedClassId)) {
          _selectedClassId = null;
        }
      });
    } catch (_) {
      // 班级下拉失败时保留「全部班级」，不阻断页面。
    }
  }

  /// 拉学生总览统计：4 张卡（在籍 / 住校 / 异动 / 总数）的口径来源。
  /// 与 [_loadStudents] 解耦，列表筛选不会触发它，避免无谓刷新。
  Future<void> _loadSum() async {
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.studentSum();
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
      _sumNormal = n(m['normalCount']) ?? 0;
      _sumResident = n(m['residentCount']) ?? 0;
      _sumAbnormal = n(m['abnormalCount']) ?? 0;
      _sumTotal = n(m['totalCount']) ?? 0;
    });
  }

  Future<void> _loadStudents() async {
    final token = ++_searchToken;

    try {
      final repo = ref.read(adminRepositoryProvider);
      final resp = await repo.studentList(
        // 全部班级：后端要求 classId 为 ""，不能省略也不能传 "0"。
        classId: _selectedClassId ?? '',
        size: 500,
        keyword: _searchKw.trim().isEmpty ? null : _searchKw.trim(),
        // studentStatus 传中文：在籍 / 休学 / 转学 / 毕业（与 tab 文案一致）。
        studentStatus: _statusFilter?.label,
      );
      if (!mounted || token != _searchToken) return;

      if (!resp.isSuccess || resp.data == null) {
        setState(() => _serverStudents = const []);
        return;
      }

      final parsed = <_Student>[];
      for (final item in _extractApiList(resp.data)) {
        try {
          parsed.add(_Student.fromJson(item));
        } catch (_) {
          // 单条解析失败跳过，整体继续。
        }
      }

      if (!mounted || token != _searchToken) return;
      setState(() => _serverStudents = parsed);
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() => _serverStudents = const []);
    }
  }

  /// 实际渲染用的学生列表：完全以服务端数据为准；服务端尚未返回时
  /// 显示为空。已经移除本地 mock 兜底。
  List<_Student> get _students => _serverStudents ?? const <_Student>[];

  /// 服务端已经按 classId / studentStatus / keyword 过滤过，直接渲染。
  List<_Student> get _filtered => _students;

  void _openProfile(_Student s) {
    showScaledDialog<void>(
      context: context,
      builder: (ctx) => _StudentProfileDialog(student: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final list = _filtered;

    // 4 个统计完全由 `studentSum` 接口给出；接口未返回 / 失败时显示 0。
    final enrolled = _sumNormal >= 0 ? _sumNormal : 0;
    final dormCount = _sumResident >= 0 ? _sumResident : 0;
    final inactive = _sumAbnormal >= 0 ? _sumAbnormal : 0;
    final total = _sumTotal >= 0 ? _sumTotal : 0;

    return SmartCampusSecondaryPageShell(
      backgroundColor: _kBg,
      bodyTopClipRadius: 8,
      header: _Banner(onBack: widget.onBack),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsRow(
              enrolled: enrolled,
              dormCount: dormCount,
              inactive: inactive,
              total: total,
            ),
            SizedBox(height: ui(16)),
            _FilterRow(
              statusFilter: _statusFilter,
              selectedClassId: _selectedClassId,
              classOptions: _classOptions,
              onStatusChanged: (s) {
                setState(() => _statusFilter = s);
                _loadStudents();
              },
              onClassChanged: (id) {
                setState(() => _selectedClassId = id);
                _loadStudents();
              },
              onSearchChanged: (kw) {
                setState(() => _searchKw = kw);
                _loadStudents();
              },
            ),
            SizedBox(height: ui(20)),
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
          _StudentGrid(students: list, onTap: _openProfile),
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
                  '学生管理',
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
                  '全量在籍视图：行政班、学籍状态、住宿与联系方式；支持检索与导出。与学生端名册同源口径。',
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
// 4 统计卡
// ============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.enrolled,
    required this.dormCount,
    required this.inactive,
    required this.total,
  });

  final int enrolled;
  final int dormCount;
  final int inactive;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminStudentManagementStatCard1,
            label: '在籍学生',
            value: enrolled,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminStudentManagementStatCard2,
            label: '住校人数',
            value: dormCount,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminStudentManagementStatCard3,
            label: '非在籍/异动',
            value: inactive,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminStudentManagementStatCard4,
            label: '名册总数',
            value: total,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 筛选行：状态 tabs + 班级 dropdown + 搜索：状态 tabs + 班级 dropdown + 搜索
// ============================================================================

class _FilterRow extends StatefulWidget {
  const _FilterRow({
    required this.statusFilter,
    required this.selectedClassId,
    required this.classOptions,
    required this.onStatusChanged,
    required this.onClassChanged,
    required this.onSearchChanged,
  });

  final _StudentStatus? statusFilter;
  final String? selectedClassId;
  final List<_ClassFilterOption> classOptions;
  final ValueChanged<_StudentStatus?> onStatusChanged;
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

    final tabs = <(String, _StudentStatus?)>[
      ('全部', null),
      ..._StudentStatus.values.map((s) => (s.label, s)),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: ui(44),
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in tabs)
                _StatusPill(
                  label: t.$1,
                  active: t.$2 == widget.statusFilter,
                  onTap: () => widget.onStatusChanged(t.$2),
                ),
            ],
          ),
        ),
        const Spacer(),
        _ClassFilterField(
          options: widget.classOptions,
          selectedClassId: widget.selectedClassId,
          onChanged: widget.onClassChanged,
        ),
        SizedBox(width: ui(12)),
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
                    hintText: '搜索姓名、学号、手机、宿舍、家长',
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
          color: active ? _kTextPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            height: 1,
            fontWeight: AppFont.w500,
            color: active ? Colors.white : _kTextSub,
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 学生卡 3 列网格
// ============================================================================

class _StudentGrid extends StatelessWidget {
  const _StudentGrid({required this.students, required this.onTap});

  final List<_Student> students;
  final ValueChanged<_Student> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (students.isEmpty) {
      return Container(
        height: ui(120),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Text(
          '暂无符合条件的学生',
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
            for (final s in students)
              SizedBox(
                width: cardWidth,
                child: _StudentCard(student: s, onTap: () => onTap(s)),
              ),
          ],
        );
      },
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.onTap});

  final _Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(88),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(46), ui(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(name: student.name, avatarUrl: student.avatarUrl),
                  SizedBox(width: ui(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                student.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textHeightBehavior: const TextHeightBehavior(
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
                            if (student.studentId.isNotEmpty) ...[
                              SizedBox(width: ui(8)),
                              Text(
                                student.studentId,
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
                          student.classInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            height: 1.2,
                            color: _kTextPrimary,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                        SizedBox(height: ui(6)),
                        Text(
                          student.dormInfo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(12),
                            height: 1.2,
                            color: _kTextSub,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 右上角状态徽章
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                height: ui(22),
                padding: EdgeInsets.symmetric(horizontal: ui(8)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: student.status.bg,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(ui(12)),
                    bottomLeft: Radius.circular(ui(12)),
                  ),
                ),
                child: Text(
                  student.status.label,
                  style: TextStyle(
                    fontSize: ui(12),
                    height: 1.0,
                    color: student.status.fg,
                    fontFamily: 'PingFang SC',
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.avatarUrl = '', this.size = 40});

  final String name;
  final String avatarUrl;
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
        color: _kPurpleSoft,
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
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

// ============================================================================
// 学籍档案 弹窗
// ============================================================================

/// 打开时立即以列表数据渲染，同时后台调用 `studentDetail` 接口补全详情。
/// [student.userId] 不为空时才会发起详情请求；为空时仅展示列表数据。
class _StudentProfileDialog extends ConsumerStatefulWidget {
  const _StudentProfileDialog({required this.student});

  final _Student student;

  @override
  ConsumerState<_StudentProfileDialog> createState() =>
      _StudentProfileDialogState();
}

class _StudentProfileDialogState extends ConsumerState<_StudentProfileDialog> {
  /// 详情接口返回的覆盖字段；null = 尚未返回 / 接口失败。
  _Student? _detail;
  bool _loadingDetail = false;
  bool _loadingExamRecords = false;
  List<AdminStudentExamRecord> _examRecords = const [];

  @override
  void initState() {
    super.initState();
    if (widget.student.userId.isNotEmpty) {
      _fetchDetail();
      _fetchExamRecords();
    }
  }

  Future<void> _fetchDetail() async {
    setState(() => _loadingDetail = true);
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.studentDetail(id: widget.student.userId);
    if (!mounted) return;

    if (resp.isSuccess && resp.data is Map) {
      try {
        final m = Map<String, dynamic>.from(resp.data as Map);
        setState(() {
          _detail = _Student.fromDetailJson(m);
          _loadingDetail = false;
        });
        return;
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingDetail = false);
  }

  Future<void> _fetchExamRecords() async {
    setState(() => _loadingExamRecords = true);
    final response = await ref
        .read(adminRepositoryProvider)
        .studentExamRecordList(studentId: widget.student.userId);
    if (!mounted) return;
    setState(() {
      _examRecords = response.isSuccess
          ? parseAdminStudentExamRecords(response.data)
          : const [];
      _loadingExamRecords = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 优先使用详情接口数据，未就绪时使用列表数据。
    final s = _detail ?? widget.student;

    return GradientHeaderDialog(
      title: '学籍档案',
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
                          name: s.name,
                          avatarUrl: s.avatarUrl,
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
                                      s.name,
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
                                    const AppLoadingIndicator(),
                                ],
                              ),
                              SizedBox(height: ui(4)),
                              Text(
                                s.adminClass != '—'
                                    ? s.adminClass
                                    : s.classInfo,
                                style: TextStyle(
                                  fontSize: ui(12),
                                  height: 1.2,
                                  color: _kTextSub,
                                  fontFamily: 'PingFang SC',
                                ),
                              ),
                              SizedBox(height: ui(2)),
                              Text(
                                s.studentId,
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
                    _ProfileRow(label: '所在班级：', value: s.adminClass),
                    _ProfileRow(
                      label: '学生性别：',
                      value: s.gender.isEmpty ? '—' : s.gender,
                    ),
                    _ProfileRow(
                      label: '专业方向：',
                      value: s.direction != '—' ? s.direction : '—',
                    ),
                    _ProfileRow(label: '所在宿舍：', value: s.dorm),
                    _ProfileRow(label: '本人手机：', value: s.phone),
                    _ProfileRow(label: '家长手机：', value: s.parentPhone),
                    _ProfileRow(label: '最近异动：', value: s.recentChange),
                    _ProfileRow(
                      label: '学生备注：',
                      value: s.remark,
                      multiline: true,
                    ),
                  ],
                ),
              ),
              SizedBox(width: ui(12)),
              _StudentFaceImgPreview(
                name: s.name,
                faceImgUrl: s.faceImgUrl,
                heroTag: 'student_face_${s.userId}',
              ),
            ],
          ),
          SizedBox(height: ui(8)),
          _StudentTagsSection(tags: s.tags),
          SizedBox(height: ui(16)),
          _StudentExamRecordsSection(
            records: _examRecords,
            loading: _loadingExamRecords,
          ),
        ],
      ),
    );
  }
}

class _StudentExamRecordsSection extends StatelessWidget {
  const _StudentExamRecordsSection({
    required this.records,
    required this.loading,
  });

  final List<AdminStudentExamRecord> records;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '考试记录',
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextHint,
                fontFamily: 'PingFang SC',
              ),
            ),
            if (loading) ...[
              SizedBox(width: ui(8)),
              Text(
                '加载中…',
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: ui(8)),
        if (!loading && records.isEmpty)
          Text(
            '暂无考试成绩',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: ui(220)),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < records.length; i++) ...[
                    if (i > 0) SizedBox(height: ui(8)),
                    _StudentExamRecordCard(record: records[i]),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StudentExamRecordCard extends StatelessWidget {
  const _StudentExamRecordCard({required this.record});

  final AdminStudentExamRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final subjects = record.subjectScores
        .map((item) => '${item.subjectName} ${item.score?.toString() ?? '--'}')
        .join(' · ');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4FF),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.examName,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: _kTextPrimary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
              ),
              Text(
                record.totalScore?.toString() ?? '--',
                style: TextStyle(
                  fontSize: ui(16),
                  color: _kPurple,
                  fontWeight: AppFont.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: ui(5)),
          Text(
            '${record.examDate.isEmpty ? '--' : record.examDate} · '
            '班级第 ${record.classRank == 0 ? '--' : record.classRank} · '
            '年级第 ${record.schoolRank == 0 ? '--' : record.schoolRank}',
            style: TextStyle(
              fontSize: ui(11),
              color: _kTextSub,
              fontFamily: 'PingFang SC',
            ),
          ),
          if (subjects.isNotEmpty) ...[
            SizedBox(height: ui(5)),
            Text(
              subjects,
              style: TextStyle(
                fontSize: ui(11),
                color: _kTextSub,
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 学籍档案右侧人脸采集照，比例与人脸库录入截取一致（88×112）。
class _StudentFaceImgPreview extends StatelessWidget {
  const _StudentFaceImgPreview({
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

class _StudentTagsSection extends StatelessWidget {
  const _StudentTagsSection({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学生标签',
          style: TextStyle(
            fontSize: ui(14),
            height: 1.4,
            color: _kTextHint,
            fontFamily: 'PingFang SC',
          ),
        ),
        SizedBox(height: ui(8)),
        if (tags.isEmpty)
          Text(
            '暂无标签',
            style: TextStyle(
              fontSize: ui(14),
              height: 1.4,
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
          )
        else
          Wrap(
            spacing: ui(8),
            runSpacing: ui(8),
            children: [
              for (final tag in tags)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(10),
                    vertical: ui(4),
                  ),
                  decoration: BoxDecoration(
                    color: _kPurpleSoft,
                    borderRadius: BorderRadius.circular(ui(6)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: ui(12),
                      height: 1.2,
                      color: _kPurple,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                    ),
                  ),
                ),
            ],
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
