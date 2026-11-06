// =============================================================================
// 学生端「我的班级」独立页面
//
// 入口：学生 dashboard 快捷区「我的班级」按钮 → controller.openMyClass()
//      → mainView == myClass + role == student → SmartCampusPage 路由到本视图。
// 返回：顶部 banner 左上角返回按钮 → onBack（controller.backToDashboard）。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（高 62）：xiaoquanHeaderBg 背景图，左返回按钮，居中"我的班级"标题
//   2. 班级信息卡（高 163）：背景图 class_info_bg + 左上 班级名 + 副标题 + 三列信息
//      + 底部"教务与艺术实践办公室·列表展示12/42人"；右上 全班 / 男生 / 女生 三个
//      100×100 紫色数字统计盒
//   3. 班级通知：标题行（"班级通知" + "查看全部 >"）+ 白卡内响应式 Wrap 通知卡
//      （列表 `POST /app/school/v2/student/schoolClassNotice/list`；
//      点击查看 `POST /app/school/v2/student/schoolClassNotice/detail`）
//   4. 师资：三段（教务老师 / 班主任 / 任课老师），每段一张白卡内若干 308×171 灰底
//      老师卡（任课卡右上多一个粉色课程标签）
//   5. 同班同学：标题行（"同班同学" + 搜索框）+ 白卡内 124×124 学生卡 7 列网格，
//      第一格固定为"自己"
//
// 颜色：白卡 #FFFFFF / 灰底 #F5F6FA / 主紫 #8741FF / 软紫 #B98FFF / 紫底 #F0E8FC
//      / 粉签 #FFC8D9 / 自己卡片背景 #F7F2FF / 描述 #B6B5BB / 副字 #6D6B75
// 字体：PingFang SC（标题 18 / 正文 12~14 / 提示 11）+ Barlow（数字 24，紫色）
// =============================================================================

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/student_repository.dart';
import '../data/teacher_notice_data.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kCardBg = Colors.white;
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleAvatar = Color(0xFFB98FFF);
const Color _kAnnounceBg = Color(0xFFF0E8FC);
const Color _kCoursePink = Color(0xFFFFC8D9);
const Color _kSelfTagBg = Color(0xFFF7F2FF);
const Color _kPlaceholder = Color(0xFFD1D1D1);

class StudentMyClassView extends ConsumerStatefulWidget {
  const StudentMyClassView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<StudentMyClassView> createState() => _StudentMyClassViewState();
}

class _StudentMyClassViewState extends ConsumerState<StudentMyClassView> {
  String _classmateQuery = '';
  bool _loading = true;
  _ClassInfoData? _classInfo;
  List<_ClassNoticeItem> _notices = const [];
  List<_FacultySectionData> _facultySections = const [];
  List<_ClassmateData> _classmates = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage());
  }

  Future<void> _loadPage() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final repo = ref.read(studentRepositoryProvider);
    final currentUserId = ref.read(shellControllerProvider).user.id;

    try {
      final results = await Future.wait([
        repo.mySchoolClass(),
        repo.schoolClassNoticeList(current: 1, size: 10),
      ]);
      if (!mounted) return;

      final classResp = results[0];
      final noticeResp = results[1];

      if (!classResp.isSuccess && classResp.msg.isNotEmpty) {
        AppToast.show(context, classResp.msg);
      }
      if (!noticeResp.isSuccess && noticeResp.msg.isNotEmpty) {
        AppToast.show(context, noticeResp.msg);
      }

      _ClassInfoData? classInfo;
      List<_FacultySectionData> facultySections = const [];
      List<_ClassmateData> classmates = const [];
      if (classResp.isSuccess) {
        final parsed = _parseMySchoolClass(classResp.data, currentUserId);
        classInfo = parsed.classInfo;
        facultySections = parsed.facultySections;
        classmates = parsed.classmates;
      }

      setState(() {
        _loading = false;
        _classInfo = classInfo;
        _facultySections = facultySections;
        _classmates = classmates;
        _notices = noticeResp.isSuccess
            ? _parseClassNotices(noticeResp.data)
            : const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _classInfo = null;
        _notices = const [];
        _facultySections = const [];
        _classmates = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pageLoading = _loading;

    return SmartCampusSecondaryPageShell(
      backgroundColor: _kPageBg,
      header: _MyClassBanner(onBack: widget.onBack),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MainContentLoadingShell(
            loading: pageLoading,
            preserveChrome: true,
            child: Builder(
              builder: (context) {
                final classInfo = _classInfo;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (classInfo != null)
                      _ClassInfoCard(data: classInfo)
                    else
                      _EmptyHintCard(message: '暂无班级信息'),
                    SizedBox(height: ui(16)),
                    _AnnouncementSection(
                      notices: _notices,
                      onViewAll: _openNoticeDrawer,
                      onNoticeTap: _showNoticeDetail,
                    ),
                    if (_facultySections.isNotEmpty) ...[
                      SizedBox(height: ui(16)),
                      _FacultySection(sections: _facultySections),
                    ],
                    SizedBox(height: ui(16)),
                    _ClassmateSection(
                      classmates: _classmates,
                      query: _classmateQuery,
                      onQueryChanged: (v) => setState(() => _classmateQuery = v),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNoticeDrawer() async {
    final scaleData =
        DashboardScaleScope.maybeOf(context) ??
        DashboardScaleScope.fromSize(MediaQuery.sizeOf(context));
    await showGeneralDialog<void>(
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
              child: _ClassNoticeListDrawer(
                initialNotices: _notices,
                onClose: () => Navigator.of(ctx).maybePop(),
                onNoticeTap: _showNoticeDetail,
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

  Future<void> _showNoticeDetail(_ClassNoticeItem item) async {
    if (item.id.isEmpty) {
      AppToast.show(context, '通知 id 无效');
      return;
    }
    final resp = await ref
        .read(studentRepositoryProvider)
        .schoolClassNoticeDetail(id: item.id);
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(
        context,
        resp.msg.isNotEmpty ? resp.msg : '通知详情加载失败',
      );
      return;
    }
    final detail = _parseClassNoticeDetail(resp.data) ?? item;
    final ui = DashboardScaleScope.of(context).ui;
    await showNoticeDetailDialog<void>(
      context: context,
      builder: (ctx) => GradientHeaderDialog(
        title: detail.title.isNotEmpty ? detail.title : '班级通知',
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (detail.content.isNotEmpty)
              Text(
                detail.content,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 22 / 13,
                ),
              )
            else if (detail.title.isNotEmpty)
              Text(
                detail.title,
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 22 / 13,
                ),
              ),
            if (detail.fullDate.isNotEmpty) ...[
              SizedBox(height: ui(12)),
              Text(
                detail.fullDate,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyHintCard extends StatelessWidget {
  const _EmptyHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: ui(32)),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextHint,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
  }
}

class _ClassNoticeItem {
  const _ClassNoticeItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.fullDate,
    this.highlighted = false,
  });

  final String id;
  final String title;
  final String content;
  final String date;
  final String fullDate;
  final bool highlighted;
}

class _ParsedMySchoolClass {
  const _ParsedMySchoolClass({
    required this.classInfo,
    required this.facultySections,
    required this.classmates,
  });

  final _ClassInfoData? classInfo;
  final List<_FacultySectionData> facultySections;
  final List<_ClassmateData> classmates;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _userDisplayName(Map<String, dynamic>? user) {
  if (user == null) return '—';
  return _pickString(_flattenUserMap(user), [
    'nickname',
    'nickName',
    'realname',
    'realName',
  ], '—');
}

String _joinDormitoryTeacherNames(
  List<Map<String, dynamic>> dormitoryTeachers,
  Map<String, dynamic>? headTeacher,
) {
  final headTeacherId = headTeacher == null
      ? ''
      : _pickString(_flattenUserMap(headTeacher), ['id'], '');
  final names = <String>[
    for (final teacher in dormitoryTeachers)
      if (headTeacherId.isEmpty ||
          _pickString(_flattenUserMap(teacher), ['id'], '') != headTeacherId)
        if (_userDisplayName(teacher) != '—') _userDisplayName(teacher),
  ];
  return names.isEmpty ? '—' : names.join('，');
}

String _pickAvatarUrl(Map<String, dynamic>? user) {
  if (user == null) return '';
  final flat = _flattenUserMap(user);
  return _pickString(flat, ['headUrl', 'avatar', 'avatarUrl'], '');
}

Map<String, dynamic> _flattenUserMap(Map<String, dynamic> user) {
  final flat = Map<String, dynamic>.from(user);
  for (final key in ['teacher', 'user', 'student']) {
    final nested = _asMap(user[key]);
    if (nested == null) continue;
    nested.forEach((k, v) {
      if (v == null) return;
      final text = v.toString().trim();
      if (text.isEmpty) return;
      flat.putIfAbsent(k, () => v);
    });
  }
  return flat;
}

_ParsedMySchoolClass _parseMySchoolClass(dynamic raw, String currentUserId) {
  final map = _asMap(raw);
  if (map == null) {
    return const _ParsedMySchoolClass(
      classInfo: null,
      facultySections: [],
      classmates: [],
    );
  }

  final schoolClass = _asMap(map['schoolClass']);
  final schoolClassroom = _asMap(map['schoolClassroom']);
  final headTeacher = _asMap(map['headTeacher']);
  final dormitoryTeachers = _asMapList(map['dormitoryTeacherList']);
  final students = _asMapList(map['studentInfoList']);
  final teachers = _asMapList(map['teacherList']);
  final genderCounts = _asMapList(map['genderCountList']);

  var boyCount = 0;
  var girlCount = 0;
  for (final item in genderCounts) {
    final gender = _pickString(item, ['gender'], '');
    final count = int.tryParse(item['count']?.toString() ?? '') ?? 0;
    if (gender == '男') {
      boyCount += count;
    } else if (gender == '女') {
      girlCount += count;
    }
  }
  final totalCount = students.isNotEmpty
      ? students.length
      : (boyCount + girlCount > 0 ? boyCount + girlCount : 0);

  final className = _pickString(schoolClass ?? {}, [
    'name',
    'groupName',
  ], '我的班级');
  final typeRaw = schoolClass?['type'];
  final type = typeRaw is int
      ? typeRaw
      : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
  final typeLabel = type == 1 ? '小班' : '大班';
  final description = _pickString(schoolClass ?? {}, ['description'], '');
  final subtitleParts = <String>[typeLabel];
  if (description.isNotEmpty) subtitleParts.add(description);
  final classroom = _pickString(schoolClassroom ?? {}, ['name'], '—');
  final announcement = _pickString(schoolClass ?? {}, ['announcement'], '');
  final footer = announcement.isNotEmpty
      ? announcement
      : (totalCount > 0 ? '共 $totalCount 人' : '—');

  final classInfo = _ClassInfoData(
    name: className,
    subtitle: subtitleParts.join(' · '),
    headTeacher: _userDisplayName(headTeacher),
    counselor: _joinDormitoryTeacherNames(dormitoryTeachers, headTeacher),
    classroom: classroom,
    announcement: announcement,
    footer: footer,
    totalCount: totalCount,
    boyCount: boyCount,
    girlCount: girlCount,
  );

  final facultySections = <_FacultySectionData>[];
  if (headTeacher != null && _userDisplayName(headTeacher) != '—') {
    facultySections.add(
      _FacultySectionData(
        title: '班主任',
        members: [_facultyFromUser(headTeacher, role: '班主任')],
      ),
    );
  }
  if (teachers.isNotEmpty) {
    facultySections.add(
      _FacultySectionData(
        title: '任课老师',
        members: [
          for (final teacher in teachers)
            _facultyFromUser(teacher, role: '任课老师'),
        ],
      ),
    );
  }

  final classmates =
      <_ClassmateData>[
        for (final student in students)
          _classmateFromUser(
            student,
            isSelf: _pickString(student, ['id'], '') == currentUserId,
          ),
      ]..sort((a, b) {
        if (a.isSelf == b.isSelf) return 0;
        return a.isSelf ? -1 : 1;
      });

  return _ParsedMySchoolClass(
    classInfo: classInfo,
    facultySections: facultySections,
    classmates: classmates,
  );
}

_FacultyMember _facultyFromUser(
  Map<String, dynamic> user, {
  required String role,
}) {
  final flat = _flattenUserMap(user);
  final introduce = _pickString(flat, ['introduce'], '');
  final gender = _pickString(flat, ['gender'], '');
  final genderLabel = gender.isNotEmpty && gender != '未知' ? gender : '—';
  var courseTag = _pickString(user, [
    'courseTag',
    'subjectName',
    'courseName',
    'subject',
  ], '');
  if (courseTag.isEmpty) {
    courseTag = _pickString(flat, [
      'courseTag',
      'subjectName',
      'courseName',
      'subject',
    ], '');
  }
  return _FacultyMember(
    name: _userDisplayName(user),
    role: role,
    gender: genderLabel,
    description: introduce.isNotEmpty ? introduce : '—',
    phone: _pickString(flat, ['mobile'], '—'),
    email: _pickString(flat, ['email'], '—'),
    courseTag: courseTag.isEmpty ? null : courseTag,
    avatarUrl: _pickAvatarUrl(user),
  );
}

_ClassmateData _classmateFromUser(
  Map<String, dynamic> user, {
  required bool isSelf,
}) {
  final flat = _flattenUserMap(user);
  final targetSchool = _pickString(flat, ['targetSchool'], '');
  final gender = _pickString(flat, ['gender'], '');
  final major = targetSchool.isNotEmpty
      ? targetSchool
      : (gender.isNotEmpty && gender != '未知' ? gender : '—');
  return _ClassmateData(
    name: _userDisplayName(user),
    major: major,
    role: _pickString(flat, ['role', 'studentRole', 'identity'], ''),
    avatarUrl: _pickAvatarUrl(user),
    isSelf: isSelf,
  );
}

List<_ClassNoticeItem> _parseClassNotices(dynamic raw) {
  final map = _asMap(raw);
  final records = map == null
      ? const <Map<String, dynamic>>[]
      : _asMapList(map['records'] ?? map['list'] ?? map['data']);

  final items = <_ClassNoticeItem>[];
  for (var i = 0; i < records.length; i++) {
    final row = records[i];
    final title = _pickString(row, ['title'], '');
    final content = _pickString(row, ['content'], '');
    if (title.isEmpty && content.isEmpty) continue;
    final createTime = _pickString(row, ['createTime'], '');
    final date = createTime.length >= 10
        ? createTime.substring(5, 10)
        : createTime;
    items.add(
      _ClassNoticeItem(
        id: _pickString(row, ['id'], '$i'),
        title: title,
        content: content,
        date: date.isEmpty ? '—' : date,
        fullDate: createTime,
        highlighted: i == 0,
      ),
    );
  }
  return items;
}

_ClassNoticeItem? _parseClassNoticeDetail(dynamic raw) {
  final map = _asMap(raw);
  if (map == null) return null;
  final title = _pickString(map, ['title'], '');
  final content = _pickString(map, ['content'], '');
  if (title.isEmpty && content.isEmpty) return null;
  final createTime = _pickString(map, ['createTime'], '');
  final date = createTime.length >= 10
      ? createTime.substring(5, 10)
      : createTime;
  return _ClassNoticeItem(
    id: _pickString(map, ['id'], ''),
    title: title,
    content: content,
    date: date.isEmpty ? '—' : date,
    fullDate: createTime,
  );
}

// =============================================================================
// 顶部 banner：xiaoquanHeaderBg 背景图，左返回按钮 + 居中标题
// =============================================================================

class _MyClassBanner extends StatelessWidget {
  const _MyClassBanner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
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
          Center(
            child: Text(
              '我的班级',
              style: TextStyle(
                fontSize: ui(16),
                color: _kTextDark,
                fontWeight: AppFont.w600,
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

// =============================================================================
// 班级信息卡（高 163）
// =============================================================================

class _ClassInfoData {
  const _ClassInfoData({
    required this.name,
    required this.subtitle,
    required this.headTeacher,
    required this.counselor,
    required this.classroom,
    required this.announcement,
    required this.footer,
    required this.totalCount,
    required this.boyCount,
    required this.girlCount,
  });

  final String name;
  final String subtitle;
  final String headTeacher;
  final String counselor;
  final String classroom;

  /// 班级群公告正文；为空时底部展示 [footer] 占位文案。
  final String announcement;
  final String footer;
  final int totalCount;
  final int boyCount;
  final int girlCount;
}

class _ClassInfoCard extends StatelessWidget {
  const _ClassInfoCard({required this.data});

  final _ClassInfoData data;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(163),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        image: DecorationImage(
          image: AssetImage(AppAssets.studentMyClassInfoBg),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          // 标题
          Positioned(
            left: ui(16),
            top: ui(12),
            child: Text(
              data.name,
              style: TextStyle(
                fontSize: ui(18),
                color: _kTextDark,
                fontWeight: AppFont.w500,
                fontFamily: 'PingFang SC',
                height: 1,
              ),
            ),
          ),
          // 副标题
          Positioned(
            left: ui(16),
            top: ui(41),
            child: Text(
              data.subtitle,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontWeight: AppFont.w400,
                fontFamily: 'PingFang SC',
                height: 1,
              ),
            ),
          ),
          // 三列信息（班主任 / 宿管老师 / 教室）
          // 不再外包 SizedBox(height: 40)：固定 40 在系统 textScaler > 1.0
          // 时（label 14 + gap 8 + value 14 都按比例放大）会触发
          // "BOTTOM OVERFLOWED BY 8.0 PIXELS"。
          // 让 Row 自适应即可——_VDivider 自带 height:31，不依赖父级。
          Positioned(
            left: ui(16),
            top: ui(70),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _InfoPair(label: '班主任', value: data.headTeacher),
                SizedBox(width: ui(12)),
                _VDivider(),
                SizedBox(width: ui(12)),
                _InfoPair(label: '宿管老师', value: data.counselor),
                SizedBox(width: ui(12)),
                _VDivider(),
                SizedBox(width: ui(12)),
                _InfoPair(label: '教室', value: data.classroom),
              ],
            ),
          ),
          // 班级群公告 / 占位 footer
          Positioned(
            left: ui(16),
            right: ui(16),
            top: ui(134),
            child: data.announcement.isNotEmpty
                ? _ClassGroupAnnouncementRow(text: data.announcement)
                : Text(
                    data.footer,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontWeight: AppFont.w400,
                      fontFamily: 'PingFang SC',
                      height: 1.2,
                    ),
                  ),
          ),
          // 右上：三个数字盒
          Positioned(
            right: ui(20),
            top: ui(31),
            child: Row(
              children: [
                _StatBox(label: '全班', value: data.totalCount),
                SizedBox(width: ui(16)),
                _StatBox(label: '男生', value: data.boyCount),
                SizedBox(width: ui(16)),
                _StatBox(label: '女生', value: data.girlCount),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 班级信息卡底部群公告：与首页右侧通知列表一致的「通知」色块 + 黑色正文。
class _ClassGroupAnnouncementRow extends StatelessWidget {
  const _ClassGroupAnnouncementRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tagStyle = teacherNoticeTagStyle('通知');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
          decoration: BoxDecoration(
            color: tagStyle.background,
            borderRadius: BorderRadius.circular(ui(4)),
          ),
          child: Text(
            '群公告',
            style: TextStyle(
              fontSize: ui(10),
              height: 1.2,
              fontWeight: AppFont.w500,
              color: tagStyle.foreground,
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
        SizedBox(width: ui(6)),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextDark,
              fontWeight: AppFont.w400,
              fontFamily: 'PingFang SC',
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(160),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
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

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(width: 1, height: ui(31), color: _kBorderSoft);
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(100),
      height: ui(100),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: Colors.black,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(10)),
          Text(
            '$value',
            style: TextStyle(
              fontSize: ui(24),
              color: _kPurple,
              fontFamily: 'Barlow',
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 班级通知（`/student/schoolClassNotice/list`）
// =============================================================================

class _AnnouncementSection extends StatelessWidget {
  const _AnnouncementSection({
    required this.notices,
    required this.onViewAll,
    required this.onNoticeTap,
  });

  final List<_ClassNoticeItem> notices;
  final VoidCallback onViewAll;
  final ValueChanged<_ClassNoticeItem> onNoticeTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: '班级通知', actionLabel: '查看全部', onAction: onViewAll),
        SizedBox(height: ui(12)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: notices.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: ui(20)),
                  child: Center(
                    child: Text(
                      '暂无通知',
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
                        for (final item in notices)
                          SizedBox(
                            width: cardWidth,
                            child: _ClassNoticeCard(
                              item: item,
                              onTap: () => onNoticeTap(item),
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
}

/// 与班主任端「班级工作台 → 班级通知」卡片样式一致（学生端可点击查看详情）。
class _ClassNoticeCard extends StatelessWidget {
  const _ClassNoticeCard({required this.item, required this.onTap});

  final _ClassNoticeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Container(
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
                        decoration: const BoxDecoration(
                          color: _kPurple,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ui(6)),
                  Expanded(
                    child: Text(
                      item.title.isNotEmpty ? item.title : item.content,
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
              if (item.title.isNotEmpty && item.content.isNotEmpty) ...[
                SizedBox(height: ui(4)),
                Padding(
                  padding: EdgeInsets.only(left: ui(18)),
                  child: Text(
                    item.content,
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
                  item.date,
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
        ),
      ),
    );
  }
}

class _ClassNoticeListDrawer extends ConsumerStatefulWidget {
  const _ClassNoticeListDrawer({
    required this.initialNotices,
    required this.onClose,
    required this.onNoticeTap,
  });

  final List<_ClassNoticeItem> initialNotices;
  final VoidCallback onClose;
  final ValueChanged<_ClassNoticeItem> onNoticeTap;

  @override
  ConsumerState<_ClassNoticeListDrawer> createState() =>
      _ClassNoticeListDrawerState();
}

class _ClassNoticeListDrawerState
    extends ConsumerState<_ClassNoticeListDrawer> {
  bool _loading = true;
  List<_ClassNoticeItem> _notices = const [];

  @override
  void initState() {
    super.initState();
    _notices = widget.initialNotices;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotices());
  }

  Future<void> _loadNotices() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final resp = await ref
          .read(studentRepositoryProvider)
          .schoolClassNoticeList(current: 1, size: 50);
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _notices = _parseClassNotices(resp.data);
          _loading = false;
        });
        return;
      }
      if (resp.msg.isNotEmpty) {
        AppToast.show(context, resp.msg);
      }
    } catch (_) {
      // 保留 initialNotices。
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(520),
      height: double.infinity,
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClassNoticeDrawerHeader(title: '班级通知', onClose: widget.onClose),
          Expanded(
            child: _loading
                ? Center(
                    child: Text(
                      '加载中…',
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  )
                : _notices.isEmpty
                ? Center(
                    child: Text(
                      '暂无通知',
                      style: TextStyle(
                        fontSize: ui(14),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      ui(16),
                      ui(16),
                      ui(16),
                      ui(24),
                    ),
                    itemCount: _notices.length,
                    separatorBuilder: (_, _) => SizedBox(height: ui(12)),
                    itemBuilder: (context, index) {
                      final item = _notices[index];
                      return _ClassNoticeCard(
                        item: item,
                        onTap: () => widget.onNoticeTap(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClassNoticeDrawerHeader extends StatelessWidget {
  const _ClassNoticeDrawerHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
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
          const Spacer(),
          InkWell(
            onTap: onClose,
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
    );
  }
}

// =============================================================================
// 师资
// =============================================================================

class _FacultyMember {
  const _FacultyMember({
    required this.name,
    required this.role,
    required this.gender,
    required this.description,
    required this.phone,
    required this.email,
    this.courseTag,
    this.avatarUrl = '',
  });

  final String name;
  final String role;
  final String gender;
  final String description;
  final String phone;
  final String email;
  final String avatarUrl;

  /// 任课老师卡片右上角的课程标签（如"形体课"），其他段落为 null。
  final String? courseTag;
}

class _FacultySectionData {
  const _FacultySectionData({required this.title, required this.members});

  final String title;
  final List<_FacultyMember> members;
}

class _FacultySection extends StatelessWidget {
  const _FacultySection({required this.sections});

  final List<_FacultySectionData> sections;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('师资'),
        SizedBox(height: ui(12)),
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) SizedBox(height: ui(12)),
          _FacultyGroupCard(section: sections[i]),
        ],
      ],
    );
  }
}

class _FacultyGroupCard extends StatelessWidget {
  const _FacultyGroupCard({required this.section});

  final _FacultySectionData section;

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
          Text(
            section.title,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextSecondary,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(height: ui(8)),
          if (section.title == '任课老师')
            LayoutBuilder(
              builder: (context, constraints) {
                const cols = 3;
                final gap = ui(12);
                final cardWidth =
                    (constraints.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final m in section.members)
                      _FacultyCard(member: m, width: cardWidth),
                  ],
                );
              },
            )
          else
            Wrap(
              spacing: ui(12),
              runSpacing: ui(12),
              children: [
                for (final m in section.members) _FacultyCard(member: m),
              ],
            ),
        ],
      ),
    );
  }
}

class _FacultyCard extends StatelessWidget {
  const _FacultyCard({required this.member, this.width});

  final _FacultyMember member;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final cardWidth = width ?? ui(308);
    return Container(
      width: cardWidth,
      height: ui(171),
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserAvatarBox(
                name: member.name,
                avatarUrl: member.avatarUrl,
                size: ui(40),
              ),
              SizedBox(width: ui(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
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
                        Text(
                          member.role,
                          style: TextStyle(
                            fontSize: ui(12),
                            color: _kPurple,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui(8)),
                    Text(
                      member.gender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextDark,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (member.courseTag != null) ...[
                SizedBox(width: ui(8)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(4),
                    vertical: ui(2),
                  ),
                  decoration: BoxDecoration(
                    color: _kCoursePink,
                    borderRadius: BorderRadius.circular(ui(4)),
                  ),
                  child: Text(
                    member.courseTag!,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 15.24 / 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: ui(8)),
          Expanded(
            child: Text(
              member.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextHint,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: ui(2),
              vertical: ui(12),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ContactCol(label: '电话', value: member.phone),
                ),
                Expanded(
                  child: _ContactCol(label: '邮箱', value: member.email),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCol extends StatelessWidget {
  const _ContactCol({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(9)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(12),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 同班同学
// =============================================================================

class _ClassmateData {
  const _ClassmateData({
    required this.name,
    required this.major,
    this.role,
    this.isSelf = false,
    this.avatarUrl = '',
  });

  final String name;
  final String major;
  final String? role;
  final String avatarUrl;

  /// 第一格固定为"自己"，强制带紫色"自己"标签，且头像走文字方块占位。
  final bool isSelf;
}

class _ClassmateSection extends StatelessWidget {
  const _ClassmateSection({
    required this.classmates,
    required this.query,
    required this.onQueryChanged,
  });

  final List<_ClassmateData> classmates;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final filtered = query.trim().isEmpty
        ? classmates
        : classmates
              .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle('同班同学')),
            _ClassmateSearchBox(value: query, onChanged: onQueryChanged),
          ],
        ),
        SizedBox(height: ui(12)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: ui(40)),
                  child: Center(
                    child: Text(
                      '没有匹配的同学',
                      style: TextStyle(
                        fontSize: ui(13),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                )
              : Wrap(
                  spacing: ui(12),
                  runSpacing: ui(12),
                  children: [for (final c in filtered) _ClassmateCard(item: c)],
                ),
        ),
      ],
    );
  }
}

class _ClassmateSearchBox extends StatefulWidget {
  const _ClassmateSearchBox({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ClassmateSearchBox> createState() => _ClassmateSearchBoxState();
}

class _ClassmateSearchBoxState extends State<_ClassmateSearchBox> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _ClassmateSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父级以非用户输入的方式重置搜索词时（例如未来"清空"按钮），同步 controller。
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
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
    return Container(
      width: ui(324),
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
              controller: _controller,
              onChanged: widget.onChanged,
              cursorColor: _kPurple,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '搜索名字',
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: _kPlaceholder,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
              ),
              style: TextStyle(
                fontSize: ui(14),
                color: _kTextDark,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassmateCard extends StatelessWidget {
  const _ClassmateCard({required this.item});

  final _ClassmateData item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(124),
      height: ui(124),
      decoration: BoxDecoration(
        color: _kInnerGray,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        children: [
          SizedBox(height: ui(8)),
          _UserAvatarBox(
            name: item.name,
            avatarUrl: item.avatarUrl,
            size: ui(36),
          ),
          SizedBox(height: ui(8)),
          Text(
            item.name,
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
          Text(
            item.major,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 12,
            ),
          ),
          if (item.isSelf || (item.role != null && item.role!.isNotEmpty))
            Padding(
              padding: EdgeInsets.only(top: ui(4)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ui(8),
                  vertical: ui(2),
                ),
                decoration: BoxDecoration(
                  color: _kSelfTagBg,
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
                child: Text(
                  item.isSelf ? '自己' : item.role!,
                  style: TextStyle(
                    fontSize: ui(11),
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

class _UserAvatarBox extends StatelessWidget {
  const _UserAvatarBox({
    required this.name,
    required this.avatarUrl,
    required this.size,
  });

  final String name;
  final String avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final firstChar = name.isNotEmpty ? name.characters.first : '?';
    final raw = avatarUrl.trim();
    final resolvedUrl = raw.isEmpty ? '' : MediaUrl.resolve(raw);
    final useInitial = resolvedUrl.isEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: useInitial ? _kPurpleAvatar : Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: useInitial
          ? Text(
              firstChar,
              style: TextStyle(
                fontSize: ui(13),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            )
          : Image.network(
              resolvedUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(
                firstChar,
                style: TextStyle(
                  fontSize: ui(13),
                  color: Colors.white,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ),
    );
  }
}

// =============================================================================
// 通用：段标题、带 Action 的段标题
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(child: _SectionTitle(title)),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(ui(4)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(2), vertical: ui(2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: ui(16),
                  color: _kTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
