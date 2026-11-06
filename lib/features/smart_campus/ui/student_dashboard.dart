part of 'teacher_dashboard.dart';

// =============================================================================
// 学生端智慧校园首页（独立 part，不修改教师端主列 / 课表解析逻辑）
// =============================================================================

class StudentDashboardLayout extends ConsumerStatefulWidget {
  const StudentDashboardLayout({
    super.key,
    required this.shellUser,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenMySchedule,
    required this.onOpenCheckIn,
    required this.onOpenMyHomework,
    required this.onOpenMyGrades,
    required this.onOpenGroupChat,
    required this.onOpenSchoolCircle,
    required this.onOpenLeaveManagement,
    required this.onOpenDormCheck,
  });

  final ShellUser shellUser;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenMySchedule;
  final VoidCallback onOpenCheckIn;
  final VoidCallback onOpenMyHomework;
  final VoidCallback onOpenMyGrades;
  final VoidCallback onOpenGroupChat;
  final VoidCallback onOpenSchoolCircle;
  final VoidCallback onOpenLeaveManagement;
  final VoidCallback onOpenDormCheck;

  @override
  ConsumerState<StudentDashboardLayout> createState() =>
      _StudentDashboardLayoutState();
}

class _StudentDashboardLayoutState extends ConsumerState<StudentDashboardLayout> {
  List<SmartCampusStatCardData> _stats = _placeholderStudentStats();
  List<SmartCampusQuickActionData> _actions =
      smartCampusDashboardDataForRole(SmartCampusRole.student).actions;
  String? _studentDormBedLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIndex());
  }

  @override
  void reassemble() {
    super.reassemble();
    assert(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadIndex();
      });
      return true;
    }());
  }

  Future<void> _loadIndex() async {
    if (!mounted) return;
    try {
      final repo = ref.read(studentRepositoryProvider);
      final responses = await Future.wait([
        repo.index(),
        repo.myDormitoryInfo(),
        repo.myExamList(tab: 1),
        repo.studentLeaveList(current: 1, size: 200),
      ]);
      if (!mounted) return;

      final indexResp = responses[0];
      final dormResp = responses[1];
      final examResp = responses[2];
      final leaveResp = responses[3];

      if (!indexResp.isSuccess && indexResp.msg.isNotEmpty) {
        AppToast.show(context, indexResp.msg);
      }

      final indexBadges = indexResp.isSuccess
          ? parseStudentDashboardBadgesFromIndex(indexResp.data)
          : const StudentDashboardBadges();
      final examPending = examResp.isSuccess
          ? parseStudentExamList(examResp.data).length
          : indexBadges.examPending;
      final leavePending = leaveResp.isSuccess
          ? parseStudentLeavePendingCount(leaveResp.data)
          : indexBadges.leavePending;
      final badges = indexBadges.merge(
        examPending: examPending,
        leavePending: leavePending,
      );
      final baseActions =
          smartCampusDashboardDataForRole(SmartCampusRole.student).actions;

      setState(() {
        if (indexResp.isSuccess) {
          _stats = _parseStudentIndexStats(indexResp.data);
        }
        _actions = applyStudentActionBadges(baseActions, badges);
        if (dormResp.isSuccess) {
          _studentDormBedLabel =
              StudentDormitoryInfo.fromJson(dormResp.data).displayLabel;
        } else {
          _studentDormBedLabel = '—';
        }
      });
    } catch (_) {
      // 保留占位符，避免首页空白。
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      smartCampusControllerProvider.select((s) => s.dashboardRefreshEpoch),
      (previous, next) {
        if (previous == null || previous == next) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadIndex();
        });
      },
    );

    final ui = DashboardScaleScope.of(context).ui;
    final data = smartCampusDashboardDataForRole(SmartCampusRole.student);
    final institutionName = ref.watch(shellControllerProvider).schoolName;

    return LayoutBuilder(
      builder: (context, constraints) {
        var cw = constraints.maxWidth;
        if (!cw.isFinite || cw == double.infinity || cw < 2) {
          final w = MediaQuery.sizeOf(context).width;
          cw = (w - ui(ShellLayoutSpec.sidebarWidth) - ui(16) * 2).clamp(
            240.0,
            20000.0,
          );
        }
        final isCompact = cw < ui(900);
        final sidebarWidth = ui(256);
        final contentGap = ui(16);
        final mainWidth = isCompact
            ? cw
            : math.max(0.0, cw - sidebarWidth - contentGap);

        if (isCompact) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: ui(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudentMainColumn(
                  data: data,
                  stats: _stats,
                  actions: _actions,
                  width: mainWidth,
                  fillRemaining: false,
                  onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                  onOpenMyClass: widget.onOpenMyClass,
                  onOpenMySchedule: widget.onOpenMySchedule,
                  onOpenCheckIn: widget.onOpenCheckIn,
                  onOpenMyHomework: widget.onOpenMyHomework,
                  onOpenMyGrades: widget.onOpenMyGrades,
                  onOpenGroupChat: widget.onOpenGroupChat,
                  onOpenSchoolCircle: widget.onOpenSchoolCircle,
                  onOpenLeaveManagement: widget.onOpenLeaveManagement,
                  onOpenDormCheck: widget.onOpenDormCheck,
                ),
                SizedBox(height: ui(16)),
                _TeacherSidebar(
                  data: data,
                  shellDisplayName: widget.shellUser.displayName,
                  avatarUrl: widget.shellUser.avatarUrl,
                  shellUser: widget.shellUser,
                  studentDormBedLabel: _studentDormBedLabel,
                  institutionName: institutionName,
                  fillHeight: false,
                ),
              ],
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: mainWidth,
              child: _StudentMainColumn(
                data: data,
                stats: _stats,
                actions: _actions,
                width: mainWidth,
                fillRemaining: true,
                onOpenPrincipalMailbox: widget.onOpenPrincipalMailbox,
                onOpenMyClass: widget.onOpenMyClass,
                onOpenMySchedule: widget.onOpenMySchedule,
                onOpenCheckIn: widget.onOpenCheckIn,
                onOpenMyHomework: widget.onOpenMyHomework,
                onOpenMyGrades: widget.onOpenMyGrades,
                onOpenGroupChat: widget.onOpenGroupChat,
                onOpenSchoolCircle: widget.onOpenSchoolCircle,
                onOpenLeaveManagement: widget.onOpenLeaveManagement,
                onOpenDormCheck: widget.onOpenDormCheck,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: sidebarWidth,
              child: _TeacherSidebar(
                data: data,
                shellDisplayName: widget.shellUser.displayName,
                avatarUrl: widget.shellUser.avatarUrl,
                shellUser: widget.shellUser,
                studentDormBedLabel: _studentDormBedLabel,
                institutionName: institutionName,
                fillHeight: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 学生端主列：统计卡 + 功能矩阵 + 当前课程/今日课表（与教师端视觉一致，逻辑独立）。
class _StudentMainColumn extends StatelessWidget {
  const _StudentMainColumn({
    required this.data,
    required this.stats,
    required this.actions,
    required this.width,
    required this.fillRemaining,
    required this.onOpenPrincipalMailbox,
    required this.onOpenMyClass,
    required this.onOpenMySchedule,
    required this.onOpenCheckIn,
    required this.onOpenMyHomework,
    required this.onOpenMyGrades,
    required this.onOpenGroupChat,
    required this.onOpenSchoolCircle,
    required this.onOpenLeaveManagement,
    required this.onOpenDormCheck,
  });

  final SmartCampusDashboardData data;
  final List<SmartCampusStatCardData> stats;
  final List<SmartCampusQuickActionData> actions;
  final double width;
  final bool fillRemaining;
  final VoidCallback onOpenPrincipalMailbox;
  final VoidCallback onOpenMyClass;
  final VoidCallback onOpenMySchedule;
  final VoidCallback onOpenCheckIn;
  final VoidCallback onOpenMyHomework;
  final VoidCallback onOpenMyGrades;
  final VoidCallback onOpenGroupChat;
  final VoidCallback onOpenSchoolCircle;
  final VoidCallback onOpenLeaveManagement;
  final VoidCallback onOpenDormCheck;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    final actionPanel = _TeacherActionPanel(
      data: data,
      actions: actions,
      onOpenPrincipalMailbox: onOpenPrincipalMailbox,
      onOpenMyClass: onOpenMyClass,
      onOpenClassWorkbench: () {},
      onOpenMySchedule: ({TeacherScheduleFocusTarget? focus}) =>
          onOpenMySchedule(),
      onOpenCheckIn: onOpenCheckIn,
      onOpenMyHomework: onOpenMyHomework,
      onOpenMyGrades: onOpenMyGrades,
      onOpenGroupChat: onOpenGroupChat,
      onOpenSchoolCircle: onOpenSchoolCircle,
      onOpenLeaveManagement: onOpenLeaveManagement,
      onOpenDormCheck: onOpenDormCheck,
    );

    final bottom = _StudentDashboardScheduleSection(
      fillRemaining: fillRemaining,
      onOpenCheckIn: onOpenCheckIn,
      onOpenMySchedule: onOpenMySchedule,
    );

    if (fillRemaining) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          _TeacherStatRow(stats: stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          Expanded(child: bottom),
        ],
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeacherStatRow(stats: stats, width: width),
          SizedBox(height: ui(16)),
          actionPanel,
          SizedBox(height: ui(16)),
          bottom,
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _StudentDashboardScheduleSection extends ConsumerStatefulWidget {
  const _StudentDashboardScheduleSection({
    this.fillRemaining = false,
    required this.onOpenCheckIn,
    required this.onOpenMySchedule,
  });

  final bool fillRemaining;
  final VoidCallback onOpenCheckIn;
  final VoidCallback onOpenMySchedule;

  @override
  ConsumerState<_StudentDashboardScheduleSection> createState() =>
      _StudentDashboardScheduleSectionState();
}

class _StudentDashboardScheduleSectionState
    extends ConsumerState<_StudentDashboardScheduleSection> {
  _LessonScheduleData? _currentLesson;
  List<_LessonScheduleData> _todayLessons = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchedule());
  }

  Future<void> _loadSchedule() async {
    if (!mounted) return;

    final studentRepo = ref.read(studentRepositoryProvider);
    final schoolRepo = ref.read(schoolRepositoryProvider);
    final today = DateTime.now();
    final todayIso = _studentIsoDate(today);

    var timeConfigs = _kDefaultDashboardTimeConfigs;
    try {
      final courseResp = await studentRepo.courseList(
        beginDate: todayIso,
        endDate: todayIso,
      );
      if (!mounted) return;

      if (!courseResp.isSuccess) {
        if (courseResp.msg.isNotEmpty) {
          AppToast.show(context, courseResp.msg);
        }
        setState(() {
          _currentLesson = null;
          _todayLessons = const [];
        });
        return;
      }

      final rows = _extractStudentCourseRows(courseResp);
      final classId = _studentClassIdFromRows(rows);
      if (classId != null && classId.isNotEmpty) {
        final tcResp =
            await schoolRepo.schoolTimeConfigList(classId: classId);
        if (tcResp.isSuccess) {
          final parsed = _parseDashboardTimeConfigs(tcResp);
          if (parsed.isNotEmpty) timeConfigs = parsed;
        }
      }

      if (!mounted) return;

      final built = _buildStudentDashboardSchedule(
        courseResp: courseResp,
        timeConfigs: timeConfigs,
        now: today,
      );
      setState(() {
        _currentLesson = built.current;
        _todayLessons = built.today;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLesson = null;
        _todayLessons = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    Widget sectionTitle(String title) => Text(
      title,
      style: TextStyle(
        fontSize: ui(18),
        height: 1.2,
        color: const Color(0xFF1A1A1A),
        fontWeight: AppFont.w500,
        fontFamily: 'PingFang SC',
      ),
    );

    final currentPanel = _CurrentLessonPanel(
      lesson: _currentLesson,
      fillHeight: widget.fillRemaining,
      onOpenSchedule: ({TeacherScheduleFocusTarget? focus}) =>
          widget.onOpenCheckIn(),
    );
    final todayPanel = _TodaySchedulePanel(
      lessons: _todayLessons,
      fillHeight: widget.fillRemaining,
      onOpenSchedule: ({TeacherScheduleFocusTarget? focus}) =>
          widget.onOpenMySchedule(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final stackVertically = !cw.isFinite || cw < ui(690);

        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              sectionTitle('当前课程'),
              SizedBox(height: ui(12)),
              currentPanel,
              SizedBox(height: ui(16)),
              sectionTitle('今日课表'),
              SizedBox(height: ui(12)),
              todayPanel,
            ],
          );
        }

        final cardsRow = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: currentPanel),
            SizedBox(width: ui(16)),
            Expanded(child: todayPanel),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: widget.fillRemaining ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sectionTitle('当前课程')),
                SizedBox(width: ui(16)),
                Expanded(child: sectionTitle('今日课表')),
              ],
            ),
            SizedBox(height: ui(12)),
            if (widget.fillRemaining)
              Expanded(child: cardsRow)
            else
              IntrinsicHeight(child: cardsRow),
          ],
        );
      },
    );
  }
}

List<SmartCampusStatCardData> _placeholderStudentStats() {
  return const [
    SmartCampusStatCardData(label: '今日课程', value: '0'),
    SmartCampusStatCardData(label: '待交作业', value: '0'),
    SmartCampusStatCardData(label: '学期均分', value: '0'),
    SmartCampusStatCardData(label: '未读通知', value: '0'),
    SmartCampusStatCardData(label: '最近考试', value: '0'),
    SmartCampusStatCardData(label: '距离省统考', value: '0'),
  ];
}

List<SmartCampusStatCardData> _parseStudentIndexStats(dynamic raw) {
  final map = raw is Map
      ? Map<String, dynamic>.from(raw)
      : <String, dynamic>{};

  num? avgScore;
  final avgRaw = map['avgScore'];
  if (avgRaw is num) {
    avgScore = avgRaw;
  } else {
    avgScore = num.tryParse(avgRaw?.toString() ?? '');
  }

  int? readInt(String key) {
    final v = map[key];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  String displayInt(String key) {
    final v = readInt(key);
    return '${v ?? 0}';
  }

  return [
    SmartCampusStatCardData(
      label: '今日课程',
      value: displayInt('todayCourseCount'),
    ),
    SmartCampusStatCardData(
      label: '待交作业',
      value: displayInt('homeworkCount'),
    ),
    SmartCampusStatCardData(
      label: '学期均分',
      value: avgScore == null ? '0' : avgScore.toStringAsFixed(1),
    ),
    SmartCampusStatCardData(
      label: '未读通知',
      value: displayInt('classNoticeCount'),
    ),
    SmartCampusStatCardData(
      label: '最近考试',
      value: _formatStudentExamWeekday(map['monthlyExamDate']?.toString()),
    ),
    SmartCampusStatCardData(
      label: '距离省统考',
      value: _formatStudentDaysUntil(map['unifiedExamDate']?.toString()),
    ),
  ];
}

String _formatStudentExamWeekday(String? isoDate) {
  if (isoDate == null || isoDate.trim().isEmpty) return '0';
  final d = DateTime.tryParse(isoDate.trim());
  if (d == null) return '0';
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return weekdays[d.weekday - 1];
}

String _formatStudentDaysUntil(String? isoDate) {
  if (isoDate == null || isoDate.trim().isEmpty) return '0';
  final d = DateTime.tryParse(isoDate.trim());
  if (d == null) return '0';
  final now = DateTime.now();
  final target = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = target.difference(today).inDays;
  if (days < 0) return '已过';
  if (days == 0) return '今天';
  return '$days天';
}

String _studentIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String? _studentClassIdFromRows(List<Map<String, dynamic>> rows) {
  for (final row in rows) {
    final id = _schedulePickString(row, ['classId'], '');
    if (id.isNotEmpty) return id;
  }
  return null;
}

Map<String, dynamic> _flattenStudentCourseRow(Map<String, dynamic> row) {
  final flat = Map<String, dynamic>.from(row);

  void mergeNested(
    String key,
    List<MapEntry<String, String>> fieldMap,
  ) {
    final nested = row[key];
    if (nested is! Map) return;
    final m = Map<String, dynamic>.from(nested);
    for (final entry in fieldMap) {
      final v = m[entry.key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      flat.putIfAbsent(entry.value, () => s);
    }
  }

  mergeNested('teacher', [
    const MapEntry('realname', 'teacherRealname'),
    const MapEntry('realName', 'teacherRealname'),
    const MapEntry('nickname', 'teacherNickname'),
    const MapEntry('name', 'teacherName'),
    const MapEntry('headUrl', 'teacherHeadUrl'),
    const MapEntry('avatar', 'teacherHeadUrl'),
    const MapEntry('avatarUrl', 'teacherHeadUrl'),
  ]);
  mergeNested('subject', [
    const MapEntry('name', 'subjectName'),
    const MapEntry('subjectName', 'subjectName'),
  ]);
  mergeNested('schoolClass', [
    const MapEntry('name', 'className'),
    const MapEntry('className', 'className'),
    const MapEntry('id', 'classId'),
  ]);
  mergeNested('schoolClassroom', [
    const MapEntry('name', 'classroomName'),
    const MapEntry('roomName', 'classroomName'),
  ]);

  return flat;
}

List<Map<String, dynamic>> _extractStudentCourseRows(ApiResponse resp) {
  final raw = resp.data;
  final list = <Map<String, dynamic>>[];
  if (raw is Map) {
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is List) {
        for (final item in v) {
          if (item is Map) {
            list.add(_flattenStudentCourseRow(Map<String, dynamic>.from(item)));
          }
        }
      }
    }
  } else if (raw is List) {
    for (final item in raw) {
      if (item is Map) {
        list.add(_flattenStudentCourseRow(Map<String, dynamic>.from(item)));
      }
    }
  }
  return list;
}

_BuiltDashboardSchedule _buildStudentDashboardSchedule({
  required ApiResponse courseResp,
  required List<_DashboardTimeConfig> timeConfigs,
  required DateTime now,
}) {
  final rows = _extractStudentCourseRows(courseResp);
  if (rows.isEmpty) {
    return const _BuiltDashboardSchedule(today: []);
  }

  final groups = <String, _DashboardSlotGroup>{};
  for (final row in rows) {
    final times = _resolveRowTimes(row, timeConfigs);
    if (times.start.isEmpty || times.end.isEmpty) continue;
    final key = '${times.lineNum}|${times.start}|${times.end}';
    groups.putIfAbsent(
      key,
      () => _DashboardSlotGroup(
        lineNum: times.lineNum,
        start: times.start,
        end: times.end,
        sortKey: _hmSortKey(times.start),
      ),
    ).rows.add(row);
  }

  final sorted = groups.values.toList()
    ..sort((a, b) {
      final byStart = a.sortKey.compareTo(b.sortKey);
      if (byStart != 0) return byStart;
      return a.lineNum.compareTo(b.lineNum);
    });

  final allLessons = <_LessonScheduleData>[];
  final phases = <_LessonSlotPhase>[];

  for (final group in sorted) {
    final phase = _slotPhase(now, group.start, group.end);
    allLessons.add(
      _LessonScheduleData(
        time: '${group.start} - ${group.end}',
        startTime: group.start,
        endTime: group.end,
        phase: phase,
        teachers: [
          for (final row in group.rows)
            _lessonRowFromStudentCourse(row, group.start, group.end),
        ],
        courseDate: DateTime(now.year, now.month, now.day),
        lineNum: group.lineNum,
      ),
    );
    phases.add(phase);
  }

  var currentIdx = -1;
  for (var i = 0; i < phases.length; i++) {
    if (phases[i] == _LessonSlotPhase.inProgress) {
      currentIdx = i;
      break;
    }
  }
  if (currentIdx < 0) {
    for (var i = 0; i < phases.length; i++) {
      if (phases[i] == _LessonSlotPhase.upcoming) {
        currentIdx = i;
        break;
      }
    }
  }
  if (currentIdx < 0) {
    for (var i = phases.length - 1; i >= 0; i--) {
      if (phases[i] == _LessonSlotPhase.ended) {
        currentIdx = i;
        break;
      }
    }
  }

  final current = currentIdx >= 0 ? allLessons[currentIdx] : null;
  final today = <_LessonScheduleData>[
    for (var i = 0; i < allLessons.length; i++)
      if (i != currentIdx) allLessons[i],
  ];

  return _BuiltDashboardSchedule(current: current, today: today);
}

_LessonRowData _lessonRowFromStudentCourse(
  Map<String, dynamic> row,
  String start,
  String end,
) {
  final flat = _flattenStudentCourseRow(row);
  final typeRaw = flat['type'];
  final type = typeRaw is int
      ? typeRaw
      : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
  final isSmall = type == 1;

  final className = _schedulePickString(flat, ['className', 'class'], '');
  final teacher = _schedulePickString(flat, [
    'teacherRealname',
    'teacherName',
    'realname',
    'realName',
    'teacherNickname',
    'teacher',
  ], '');
  final subjectName = _schedulePickString(flat, [
    'subjectName',
    'courseName',
    'subject',
    'name',
  ], '—');
  final classroom = _schedulePickString(flat, [
    'classroomName',
    'roomName',
    'classroom',
  ], '');

  final displayName = teacher.isNotEmpty
      ? teacher
      : (className.isNotEmpty ? className : '—');
  final avatarSeed = displayName.isEmpty ? '?' : displayName;

  var courseColor = isSmall
      ? const Color(0xFF0CAC40)
      : const Color(0xFF8741FF);
  var courseBg = isSmall
      ? const Color(0xFFDFFCF0)
      : const Color(0xFFEAE5FF);
  var tagDotColor = courseColor;

  final hex = _schedulePickString(flat, ['color'], '');
  final parsed = _parseDashboardHexColor(hex);
  if (parsed != null) {
    courseColor = parsed;
    courseBg = parsed.withValues(alpha: 0.14);
    tagDotColor = parsed;
  }

  final mins = _minutesBetweenHm(start, end);
  final hintParts = <String>[];
  if (mins > 0) hintParts.add('$mins分钟');
  if (classroom.isNotEmpty) hintParts.add(classroom);
  final hint = hintParts.isEmpty ? '—' : hintParts.join('·');

  return _LessonRowData(
    avatarSeed: avatarSeed,
    avatarUrl: resolveScheduleTeacherHeadUrl(flat),
    logoUrl: resolveScheduleLogoUrl(flat),
    teacherName: displayName,
    courseName: subjectName,
    courseColor: courseColor,
    courseBg: courseBg,
    tag: isSmall ? '小课' : '大课',
    tagDotColor: tagDotColor,
    hint: hint,
    isSmallCourse: isSmall,
  );
}
