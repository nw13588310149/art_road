import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/art/art_subject.dart';
import '../../../core/ui/ui.dart';
import '../../artworks/data/artwork_models.dart';
import '../../smart_campus/state/smart_campus_controller.dart';
import '../../smart_campus/ui/widgets/smart_campus_page_banner.dart';
import '../../study_center/ui/growth/student_artwork_growth_view.dart';
import '../data/teaching_overview_repository.dart';
import '../state/teaching_overview_controller.dart';

TeachingRequest _request(
  TeachingReport report,
  String campus, [
  String parameter = '',
]) => (report: report, campus: campus, parameter: parameter);

Future<void> openTeachingReport(
  BuildContext context,
  TeachingReport report, {
  String campus = '',
  String parameter = '',
}) async {
  await Navigator.of(context).pushNamed(
    RoutePaths.teachingOverview,
    arguments: _request(report, campus, parameter),
  );
}

class PrincipalOverview extends ConsumerStatefulWidget {
  const PrincipalOverview({required this.name, super.key});

  final String name;

  @override
  ConsumerState<PrincipalOverview> createState() => _PrincipalOverviewState();
}

class _PrincipalOverviewState extends ConsumerState<PrincipalOverview> {
  String _campus = '';
  String _metric = 'submissions';
  List<TeachingRow> _campuses = const [];

  void _open(TeachingReport report, [String parameter = '']) async {
    await openTeachingReport(
      context,
      report,
      campus: _campus,
      parameter: parameter,
    );
    if (mounted) _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref
          .read(
            teachingOverviewProvider(
              _request(TeachingReport.overview, _campus),
            ).notifier,
          )
          .refresh(),
      ref
          .read(
            teachingOverviewProvider(
              _request(TeachingReport.trend, _campus, _metric),
            ).notifier,
          )
          .refresh(),
    ]);
  }

  void _artwork(String id) async {
    await Navigator.of(
      context,
    ).pushNamed(RoutePaths.artworks, arguments: {'artworkId': id});
    if (mounted) _refresh();
  }

  void _campusView(void Function(SmartCampusController) open) {
    open(ref.read(smartCampusControllerProvider.notifier));
    Navigator.of(context).pushNamed(RoutePaths.smartCampus);
  }

  @override
  Widget build(BuildContext context) {
    final provider = teachingOverviewProvider(
      _request(TeachingReport.overview, _campus),
    );
    final state = ref.watch(provider);
    final data = teachingRow(state.asData?.value);
    if (data.isNotEmpty) _campuses = teachingRows(data['campuses']);
    final trend = ref.watch(
      teachingOverviewProvider(
        _request(TeachingReport.trend, _campus, _metric),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        spacing: AppSpace.s16,
        children: [
          SmartCampusPageBanner(title: '校长驾驶舱', subtitle: '教学与出勤概览'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scope = _buildScope(data);
                final board = state.when(
                  loading: () => const Center(child: AppLoadingIndicator()),
                  error: (error, _) => AppErrorState(
                    title: '驾驶舱加载失败',
                    description: '$error',
                    onRetry: _refresh,
                  ),
                  data: (_) => _buildBoard(data, trend),
                );
                if (constraints.maxWidth < 730) {
                  return ListView(
                    children: [
                      scope,
                      const SizedBox(height: AppSpace.s16),
                      board,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpace.s16,
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [board],
                        ),
                      ),
                    ),
                    SizedBox(width: 256, child: scope),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScope(TeachingRow data) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s12,
      children: [
        AppListRow(
          leading: AppAvatar(name: widget.name, size: 44),
          title: widget.name.isEmpty ? '校长' : widget.name,
          subtitle: '示范画室 · 校长',
        ),
        Text('校区', style: AppText.body14Strong),
        Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s8,
          children: [
            AppChip(
              label: '全部',
              selected: _campus.isEmpty,
              onTap: () => setState(() => _campus = ''),
            ),
            for (final campus in _campuses)
              AppChip(
                label: teachingText(campus['name']).replaceFirst('校区', ''),
                selected: campus['id'] == _campus,
                onTap: () =>
                    setState(() => _campus = teachingText(campus['id'])),
              ),
          ],
        ),
        if (data['date'] != null)
          Text('${data['date']} · 演示数据', style: AppText.caption12),
      ],
    ),
  );

  Widget _buildBoard(TeachingRow data, AsyncValue<Object?> trend) {
    final attendance = teachingRow(data['attendance']);
    final metrics = [
      (
        label: '今日到校学生',
        value:
            '${attendance['studentPresent']} / ${attendance['studentExpected']}',
        secondary: '',
        report: TeachingReport.attendance,
        parameter: 'students',
        alert: false,
      ),
      (
        label: '今日在岗老师',
        value:
            '${attendance['teacherPresent']} / ${attendance['teacherExpected']}',
        secondary: '',
        report: TeachingReport.attendance,
        parameter: 'teachers',
        alert: false,
      ),
      (
        label: '今日新交作品',
        value: _number(data['todaySubmissions']),
        secondary: '昨日 ${data['yesterdaySubmissions']}',
        report: TeachingReport.reviewChain,
        parameter: 'date=${data['date']}',
        alert: false,
      ),
      (
        label: '超时待点评',
        value: _number(data['overdueReviews']),
        secondary: '',
        report: TeachingReport.reviewChain,
        parameter: 'filter=overdue',
        alert: (data['overdueReviews'] as int? ?? 0) > 0,
      ),
      (
        label: '点评及时率',
        value: _number(data['timelyReviewRate'], suffix: '%'),
        secondary: '近 7 天',
        report: TeachingReport.teachers,
        parameter: '',
        alert: false,
      ),
      (
        label: '超时待复核',
        value: _number(data['overdueLeadReviews']),
        secondary: '',
        report: TeachingReport.reviewChain,
        parameter: 'filter=leadOverdue',
        alert: (data['overdueLeadReviews'] as int? ?? 0) > 0,
      ),
      (
        label: '模考均分',
        value: _number(data['examMean']),
        secondary: data['examChange'] == null
            ? ''
            : '较上次 ${_change(data['examChange'])}',
        report: TeachingReport.classes,
        parameter: '',
        alert: false,
      ),
      (
        label: '需要关注的学生',
        value: _number(data['attentionCount']),
        secondary: '',
        report: TeachingReport.attention,
        parameter: '',
        alert: false,
      ),
    ];
    final actions = <(String, IconData, VoidCallback)>[
      ('老师履职', Icons.fact_check_outlined, () => _open(TeachingReport.teachers)),
      ('全校学情', Icons.show_chart, () => _open(TeachingReport.classes)),
      ('作品点评链', Icons.brush_outlined, () => _open(TeachingReport.reviewChain)),
      (
        '优秀作品墙',
        Icons.image_outlined,
        () => Navigator.of(context).pushNamed(
          RoutePaths.excellentArtworks,
          arguments: {'campusId': _campus},
        ),
      ),
      ('需要关注的学生', Icons.people_outline, () => _open(TeachingReport.attention)),
      (
        '校长信箱',
        Icons.mail_outline,
        () => _campusView((c) => c.openPrincipalMailbox()),
      ),
      (
        '通知管理',
        Icons.notifications_none,
        () => _campusView((c) => c.openNotificationManagement()),
      ),
      (
        '教师请假审批',
        Icons.event_busy_outlined,
        () => _campusView((c) => c.openDormLeaveApproval()),
      ),
      (
        '学生管理',
        Icons.school_outlined,
        () => _campusView((c) => c.openStudentManagement()),
      ),
      (
        '教师管理',
        Icons.badge_outlined,
        () => _campusView((c) => c.openTeacherManagement()),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s16,
      children: [
        GridView.count(
          crossAxisCount: 4,
          mainAxisExtent: 79,
          mainAxisSpacing: AppSpace.s12,
          crossAxisSpacing: AppSpace.s12,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            for (final metric in metrics)
              AppCard(
                onTap: () => _open(metric.report, metric.parameter),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4,
                  vertical: AppSpace.s4,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      metric.value,
                      style: AppText.displayNumber(
                        size: 24,
                        color: metric.alert ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                    Text(
                      metric.label,
                      style: AppText.caption12,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (metric.secondary.isNotEmpty)
                      Text(
                        metric.secondary,
                        style: AppText.caption12,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
          ],
        ),
        AppCard(
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 5,
            mainAxisExtent: 58,
            mainAxisSpacing: AppSpace.s8,
            crossAxisSpacing: AppSpace.s4,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (label, icon, onTap) in actions)
                AppPressable(
                  onTap: onTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: AppSpace.s4,
                    children: [
                      Icon(icon, size: 24, color: AppColors.ink),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppText.caption12Strong,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AppCard(
          title: '数据看板',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpace.s12,
            children: [
              AppSegmented<String>(
                value: _metric,
                segments: const [
                  AppSegment(value: 'submissions', label: '作品提交量'),
                  AppSegment(value: 'timely', label: '点评及时率'),
                  AppSegment(value: 'attendance', label: '学生出勤率'),
                ],
                onChanged: (value) => setState(() => _metric = value),
              ),
              SizedBox(
                height: 155,
                child: trend.when(
                  data: (raw) => _TrendChart(
                    rows: teachingRows(raw),
                    percent: _metric != 'submissions',
                  ),
                  loading: () => const Center(child: AppLoadingIndicator()),
                  error: (error, _) => AppErrorState(
                    title: '趋势加载失败',
                    description: '$error',
                    onRetry: _refresh,
                  ),
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final alerts = _buildAlerts(data);
            final activity = _buildActivity(data);
            if (constraints.maxWidth < 490) {
              return Column(
                spacing: AppSpace.s12,
                children: [alerts, activity],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s12,
              children: [
                Expanded(child: alerts),
                Expanded(child: activity),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAlerts(TeachingRow data) {
    final alerts = teachingRows(data['alerts']);
    return AppCard(
      title: '预警',
      child: Column(
        children: [
          if (alerts.isEmpty) Text('暂无预警', style: AppText.body13),
          for (final alert in alerts.take(6))
            AppListRow(
              title: teachingText(alert['label']),
              onTap: () {
                final id = teachingText(alert['id']);
                switch (alert['target']) {
                  case 'attention':
                    _open(TeachingReport.attention, id);
                  case 'classes':
                    openTeachingReport(
                      context,
                      TeachingReport.classes,
                      campus: id,
                    );
                  default:
                    _open(
                      TeachingReport.reviewChain,
                      'filter=${alert['target']}&teacherId=${Uri.encodeQueryComponent(id)}',
                    );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActivity(TeachingRow data) {
    final items = teachingRows(data['activity']);
    return AppCard(
      title: '动态',
      child: Column(
        children: [
          if (items.isEmpty) Text('暂无动态', style: AppText.body13),
          for (final item in items.take(6))
            AppListRow(
              title: teachingText(item['title']),
              subtitle: '${item['name']} · ${_activity(item['type'])}',
              onTap: () => _artwork(teachingText(item['artworkId'])),
            ),
        ],
      ),
    );
  }
}

class TeachingReportPage extends ConsumerStatefulWidget {
  const TeachingReportPage({this.initial, super.key});

  final TeachingRequest? initial;

  @override
  ConsumerState<TeachingReportPage> createState() => _TeachingReportPageState();
}

class _TeachingReportPageState extends ConsumerState<TeachingReportPage> {
  TeachingRequest? _base;
  String? _date;
  String _subject = '';
  String _sort = '';
  bool _descending = true;
  int _page = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    _base ??=
        widget.initial ??
        (args is TeachingRequest ? args : _request(TeachingReport.classes, ''));
  }

  @override
  Widget build(BuildContext context) {
    final base = _base!;
    final filter =
        base.report == TeachingReport.reviewChain && base.parameter.isNotEmpty
        ? Uri.splitQueryString(base.parameter)
        : <String, String>{};
    final request = base.report == TeachingReport.reviewChain
        ? _request(
            base.report,
            base.campus,
            Uri(
              queryParameters: {...filter, 'date': ?_date, 'current': '$_page'},
            ).query,
          )
        : base;
    final provider = teachingOverviewProvider(request);
    final state = ref.watch(provider);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.s16,
        children: [
          SmartCampusPageBanner(
            title: base.report.title,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (error, _) => AppErrorState(
                title: '数据加载失败',
                description: '$error',
                onRetry: ref.read(provider.notifier).refresh,
              ),
              data: (raw) => ListView(
                children: [
                  switch (base.report) {
                    TeachingReport.attendance => _attendance(
                      teachingRow(raw),
                      base.parameter,
                    ),
                    TeachingReport.teachers || TeachingReport.groupTeachers =>
                      _teachers(teachingRows(raw), base),
                    TeachingReport.teacher ||
                    TeachingReport.myPerformance => _teacher(teachingRow(raw)),
                    TeachingReport.classes ||
                    TeachingReport.groupClasses => _classes(teachingRows(raw)),
                    TeachingReport.attention ||
                    TeachingReport.myAttention ||
                    TeachingReport.myStudents => _people(
                      teachingRows(raw),
                      base.parameter,
                    ),
                    TeachingReport.reviewChain => _chain(
                      teachingRow(raw),
                      base,
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendance(TeachingRow data, String category) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpace.s12,
    children: [
      if (category != 'teachers')
        AppCard(
          title:
              '今日未到校学生 · ${(data['studentExpected'] as int? ?? 0) - (data['studentPresent'] as int? ?? 0)} 人',
          child: _people(teachingRows(data['students']), ''),
        ),
      if (category != 'students')
        AppCard(
          title:
              '今日未签到老师 · ${(data['teacherExpected'] as int? ?? 0) - (data['teacherPresent'] as int? ?? 0)} 人',
          child: Column(
            children: [
              if (teachingRows(data['teachers']).isEmpty)
                Text('暂无未签到老师', style: AppText.body13),
              for (final teacher in teachingRows(data['teachers']))
                AppListRow(
                  title: teachingText(teacher['name']),
                  subtitle: teachingText(teacher['subject']),
                  onTap: () => openTeachingReport(
                    context,
                    TeachingReport.teacher,
                    campus: _base!.campus,
                    parameter: teachingText(teacher['id']),
                  ),
                ),
            ],
          ),
        ),
    ],
  );

  static const _metrics = <(String, String, String)>[
    ('timely', '点评及时率', '%'),
    ('quality', '点评质量', ' 星'),
    ('punctual', '签到准时率', '%'),
    ('taskCount', '作业数', ' 份'),
    ('taskReviewRate', '批改率', '%'),
    ('scoreChange', '成绩变化', ' 分'),
    ('studentRating', '学生评价', ' 分'),
    ('adjustRate', '调分率', '%'),
  ];

  Widget _teachers(List<TeachingRow> rows, TeachingRequest base) {
    final columns = base.report == TeachingReport.groupTeachers
        ? [
            ..._metrics.where(
              (metric) =>
                  ['timely', 'quality', 'adjustRate'].contains(metric.$1),
            ),
            ('reviewCount', '本周点评', ' 份'),
            ('adjustAverage', '平均调分', ' 分'),
          ]
        : _metrics;
    final filtered = rows
        .where((row) => _subject.isEmpty || row['subject'] == _subject)
        .toList();
    if (_sort.isNotEmpty) {
      filtered.sort((a, b) {
        final first = a[_sort] as num?;
        final second = b[_sort] as num?;
        if (first == null) return second == null ? 0 : 1;
        if (second == null) return -1;
        return _descending ? second.compareTo(first) : first.compareTo(second);
      });
    }
    return AppCard(
      title: '履职概览',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpace.s12,
        children: [
          Wrap(
            spacing: AppSpace.s8,
            children: [
              AppChip(
                label: '全部科目',
                selected: _subject.isEmpty,
                onTap: () => setState(() => _subject = ''),
              ),
              for (final subject in <String>{
                ...ArtSubject.values.map((subject) => subject.label),
                ...rows.map((row) => teachingText(row['subject'])),
              })
                AppChip(
                  label: subject,
                  selected: subject == _subject,
                  onTap: () => setState(() => _subject = subject),
                ),
            ],
          ),
          if (filtered.isEmpty)
            Text('暂无履职数据', style: AppText.body13)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: AppSpace.s8,
                columnSpacing: AppSpace.s12,
                sortColumnIndex: _sort.isEmpty
                    ? null
                    : columns.indexWhere((metric) => metric.$1 == _sort) + 1,
                sortAscending: !_descending,
                columns: [
                  const DataColumn(label: Text('老师')),
                  for (final (key, label, _) in columns)
                    DataColumn(
                      label: Text(label),
                      numeric: true,
                      onSort: (_, ascending) => setState(() {
                        _sort = key;
                        _descending = !ascending;
                      }),
                    ),
                ],
                rows: [
                  for (final row in filtered)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(teachingText(row['name'])),
                          onTap: base.report == TeachingReport.teachers
                              ? () => openTeachingReport(
                                  context,
                                  TeachingReport.teacher,
                                  campus: base.campus,
                                  parameter: teachingText(row['id']),
                                )
                              : null,
                        ),
                        for (final (key, _, suffix) in columns)
                          DataCell(Text(_number(row[key], suffix: suffix))),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _teacher(TeachingRow row) => Column(
    spacing: AppSpace.s12,
    children: [
      AppCard(
        title: '${row['name']} · ${row['subject']}',
        child: Wrap(
          spacing: AppSpace.s12,
          runSpacing: AppSpace.s8,
          children: [
            for (final (key, label, suffix) in _metrics)
              AppTag(label: '$label ${_number(row[key], suffix: suffix)}'),
          ],
        ),
      ),
      AppCard(
        title: '近 7 天点评及时率',
        child: SizedBox(
          height: 172,
          child: _TrendChart(rows: teachingRows(row['trend']), percent: true),
        ),
      ),
      AppCard(
        title: '点评质量',
        child: Wrap(
          spacing: AppSpace.s12,
          runSpacing: AppSpace.s8,
          children: [
            AppTag(label: '评语字数 ${_number(row['commentLength'])}'),
            AppTag(label: '批注率 ${_number(row['annotationRate'], suffix: '%')}'),
            AppTag(
              label: '分项填写率 ${_number(row['dimensionRate'], suffix: '%')}',
            ),
          ],
        ),
      ),
      AppCard(
        title: '点评样本',
        child: Column(
          children: [
            for (final work in teachingRows(row['reviews']))
              _workCard(ArtworkSummary.fromJson(work)),
          ],
        ),
      ),
      AppCard(
        title: '课堂签到记录',
        child: Column(
          children: [
            for (final sign in teachingRows(row['signs']))
              AppListRow(
                title: '${sign['date']} · ${sign['course']}',
                subtitle: '开课 ${sign['start']} · 签到 ${sign['time'] ?? '—'}',
              ),
          ],
        ),
      ),
    ],
  );

  Widget _classes(List<TeachingRow> rows) => Column(
    spacing: AppSpace.s12,
    children: [
      for (final row in rows)
        AppCard(
          title: '${row['name']} · ${row['campus']}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.s12,
            children: [
              SizedBox(
                height: 180,
                child: _TrendChart(
                  rows: [
                    for (final exam in teachingRows(row['exams']))
                      {...exam, 'value': exam['mean']},
                  ],
                ),
              ),
              for (final subject in teachingRows(row['dimensions']))
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  children: [
                    AppTag.subject(teachingText(subject['subject'])),
                    for (final dimension in teachingRows(subject['items']))
                      AppTag(
                        label:
                            '${dimension['name']} ${_number(dimension['level'])}',
                      ),
                  ],
                ),
              if (row['students'] != null)
                AppButton(
                  label: '查看班级学生',
                  variant: AppButtonVariant.secondary,
                  onTap: () => showAppDrawer<void>(
                    context: context,
                    builder: (context) => AppDrawer(
                      title: teachingText(row['name']),
                      child: ListView(
                        children: [_people(teachingRows(row['students']), '')],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _people(List<TeachingRow> rows, String selected) {
    final visible = selected.isEmpty
        ? rows
        : rows.where((row) => row['id'] == selected).toList();
    return Column(
      children: [
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Text('暂无学生', style: AppText.body13),
          ),
        for (final row in visible) _studentListRow(row),
      ],
    );
  }

  Widget _studentListRow(TeachingRow row) {
    final preview = teachingRows(row['dimensions'])
        .where((subject) => subject['subject'] == row['previewSubject'])
        .firstOrNull;
    return AppListRow(
      leading: AppAvatar(name: teachingText(row['name']), size: 40),
      title: teachingText(row['name']),
      subtitle: [
        teachingText(row['className']),
        if (row['teacher'] != null) '负责老师 ${row['teacher']}',
        if (row['previewSubject'] != null) '近次提交 ${row['latestWork'] ?? '—'}',
        ..._strings(row['reasons']),
      ].join(' · '),
      trailing: row['reasons'] == null && row['unresolvedCount'] != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpace.s12,
              children: [
                if (preview != null)
                  ArtworkDimensionRadar(
                    levels: ArtworkDimensionLevels.fromJson(preview),
                    size: 44,
                  ),
                AppTag(label: '待改善 ${row['unresolvedCount']} 项'),
              ],
            )
          : null,
      onTap: () => _showStudent(row),
    );
  }

  void _showStudent(TeachingRow row) {
    showAppDrawer<void>(
      context: context,
      builder: (context) => AppDrawer(
        title: teachingText(row['name']),
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s16),
          children: [
            Text(
              '${row['className']} · ${row['campus']}',
              style: AppText.body14,
            ),
            const SizedBox(height: AppSpace.s12),
            Text('已提交作品 ${row['workCount']} 份', style: AppText.body14Strong),
            if (row['latestWork'] != null)
              AppListRow(
                title: '近次提交',
                subtitle: teachingText(row['latestWork']),
              ),
            if (row['goalTarget'] != null)
              AppListRow(
                title: '目标综合分 ${_number(row['goalTarget'], suffix: ' 分')}',
                subtitle: row['goalGap'] == null
                    ? '暂无综合分预估'
                    : '目标与预估相差 ${_change(row['goalGap'])} 分',
              ),
            const SizedBox(height: AppSpace.s12),
            SizedBox(
              height: 160,
              child: _TrendChart(
                rows: [
                  for (final exam in teachingRows(row['exams']))
                    {...exam, 'value': exam['mean']},
                ],
              ),
            ),
            for (final exam in teachingRows(row['exams']).reversed)
              AppListRow(
                title: teachingText(exam['name']),
                subtitle: '${exam['date']} · 总排名 ${exam['rank'] ?? '—'}',
                trailing: Text(
                  _number(exam['mean'], suffix: ' 分'),
                  style: AppText.body14,
                ),
              ),
            for (final subject in teachingRows(row['dimensions']))
              AppCard(
                title: teachingText(subject['subject']),
                child: Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  children: [
                    for (final dimension in teachingRows(subject['items']))
                      AppTag(
                        label:
                            '${dimension['name']} ${_number(dimension['level'])}',
                      ),
                  ],
                ),
              ),
            for (final work in teachingRows(row['works']))
              _workCard(ArtworkSummary.fromJson(work)),
          ],
        ),
      ),
    );
  }

  Widget _chain(TeachingRow data, TeachingRequest base) {
    final records = teachingRows(data['records']);
    final total = data['total'] as int? ?? 0;
    final size = data['size'] as int? ?? 24;
    final date = teachingText(data['date']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.s12,
      children: [
        AppCard(
          title: '点评链概览',
          child: Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              AppTag(label: '提交 $total 份'),
              AppTag(label: '已点评 ${data['reviewed']}'),
              AppTag(label: '复核中 ${data['inReview']}'),
              AppTag(label: '已复核 ${data['done']}'),
              AppTag(label: '点评超时 ${data['overdue']}', tone: AppTone.danger),
              AppTag(
                label: '复核超时 ${data['leadOverdue']}',
                tone: AppTone.danger,
              ),
            ],
          ),
        ),
        Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s4,
          children: [
            AppChip(
              label: '全部日期',
              selected: date.isEmpty,
              onTap: () => _selectDate(''),
            ),
            for (final day in _strings(data['dates']))
              AppChip(
                label: _shortDay(day),
                selected: date == day,
                onTap: () => _selectDate(day),
              ),
          ],
        ),
        if (records.isEmpty)
          const AppEmptyState(
            icon: Icons.brush_outlined,
            title: '暂无作品',
            description: '可以切换日期查看其他作品',
          ),
        for (final work in records) _workCard(ArtworkSummary.fromJson(work)),
        Center(
          child: Wrap(
            spacing: AppSpace.s12,
            children: [
              AppButton(
                label: '上一页',
                variant: AppButtonVariant.secondary,
                onTap: _page > 1 ? () => setState(() => _page--) : null,
              ),
              AppButton(
                label: '下一页',
                variant: AppButtonVariant.secondary,
                onTap: _page * size < total
                    ? () => setState(() => _page++)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectDate(String date) => setState(() {
    _date = date;
    _page = 1;
  });

  Widget _workCard(ArtworkSummary work) => AppCard(
    onTap: () async {
      await Navigator.of(
        context,
      ).pushNamed(RoutePaths.artworks, arguments: {'artworkId': work.id});
      if (mounted) ref.invalidate(teachingOverviewProvider);
    },
    child: AppListRow(
      leading: SizedBox.square(
        dimension: 64,
        child: AppImage(src: work.coverUrl, borderRadius: AppRadius.br8),
      ),
      title: work.title,
      subtitle: '${work.studentName} · ${work.subject} · ${work.teacherName}',
      trailing: AppTag(
        label: work.overdue
            ? '点评超时'
            : work.leadOverdue
            ? '复核超时'
            : work.reviewed
            ? '已点评'
            : '待点评',
      ),
    ),
  );
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.rows, this.percent = false});
  final List<TeachingRow> rows;
  final bool percent;

  @override
  Widget build(BuildContext context) {
    final values = [for (final row in rows) (row['value'] as num?)?.toDouble()];
    if (values.whereType<double>().isEmpty) {
      return Center(child: Text('暂无趋势数据', style: AppText.body13));
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      percent ? '100%' : _number(_maximum(values)),
                      style: AppText.caption12,
                    ),
                    Text('0', style: AppText.caption12),
                  ],
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _TrendPainter(
                    values,
                    percent ? 100 : _maximum(values),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 38, top: 8),
          child: Row(
            children: [
              for (final row in rows)
                Expanded(
                  child: Tooltip(
                    message:
                        '${row['date']} · ${_number(row['value'], suffix: percent ? '%' : '')}',
                    child: Text(
                      _shortDay(teachingText(row['date'])),
                      textAlign: TextAlign.center,
                      style: AppText.caption12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  double _maximum(List<double?> values) => values
      .whereType<double>()
      .fold(1.0, (a, b) => a > b ? a : b)
      .ceilToDouble();
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values, this.maximum);
  final List<double?> values;
  final double maximum;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = AppColors.line;
    for (var i = 0; i <= 4; i++) {
      final y = 4 + (size.height - 8) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 2;
    Offset? previous;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        previous = null;
        continue;
      }
      final point = Offset(
        size.width * (i + 0.5) / values.length,
        4 + (size.height - 8) * (1 - value / maximum),
      );
      if (previous != null) canvas.drawLine(previous, point, line);
      canvas.drawCircle(point, 4, line);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maximum != maximum;
}

List<String> _strings(Object? raw) =>
    raw is List ? raw.whereType<String>().toList() : const [];
String _shortDay(String date) =>
    date.length >= 10 ? date.substring(5, 10) : date;
String _number(Object? raw, {String suffix = ''}) {
  if (raw is! num) return '—';
  return '${raw.toStringAsFixed(raw % 1 == 0 ? 0 : 1)}$suffix';
}

String _change(Object? raw) =>
    raw is num && raw > 0 ? '+${_number(raw)}' : _number(raw);
String _activity(Object? type) => switch (type) {
  'LEAD_KEEP' || 'LEAD_ADJUST' || 'LEAD_SUPPLEMENT' => '复核',
  'PRINCIPAL_COMMENT' => '校长点评',
  'FEATURE' => '推优',
  _ => '点评',
};
