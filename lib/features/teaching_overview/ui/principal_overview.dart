import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/art/art_subject.dart';
import '../../../core/ui/ui.dart';
import '../../smart_campus/state/smart_campus_controller.dart';
import '../data/teaching_overview_repository.dart';
import '../state/teaching_overview_controller.dart';
import 'teaching_overview_page.dart';
import 'teaching_trend_chart.dart';

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

  TeachingRequest _request(TeachingReport report, [String parameter = '']) =>
      (report: report, campus: _campus, parameter: parameter);

  Future<void> _refresh() => Future.wait([
    ref
        .read(
          teachingOverviewProvider(_request(TeachingReport.overview)).notifier,
        )
        .refresh(),
    ref
        .read(
          teachingOverviewProvider(
            _request(TeachingReport.trend, _metric),
          ).notifier,
        )
        .refresh(),
  ]);

  Future<void> _open(TeachingReport report, [String parameter = '']) async {
    await openTeachingReport(
      context,
      report,
      campus: _campus,
      parameter: parameter,
    );
    if (mounted) await _refresh();
  }

  Future<void> _artwork(String id) async {
    await Navigator.of(
      context,
    ).pushNamed(RoutePaths.artworks, arguments: {'artworkId': id});
    if (mounted) await _refresh();
  }

  void _campusView(void Function(SmartCampusController) open) {
    open(ref.read(smartCampusControllerProvider.notifier));
    Navigator.of(context).pushNamed(RoutePaths.smartCampus);
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(
      teachingOverviewProvider(_request(TeachingReport.overview)),
    );
    final data = teachingRow(overview.asData?.value);
    if (data.isNotEmpty) _campuses = teachingRows(data['campuses']);
    final trend = ref.watch(
      teachingOverviewProvider(_request(TeachingReport.trend, _metric)),
    );
    return ColoredBox(
      color: AppColors.surfaceSubtle,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(data),
            const SizedBox(height: 16),
            Expanded(
              child: overview.when(
                loading: () => const Center(child: AppLoadingIndicator()),
                error: (error, _) => AppErrorState(
                  title: '教学数据加载失败',
                  description: '$error',
                  onRetry: _refresh,
                ),
                data: (_) => LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 740;
                    final height = math.max(612.0, box.maxHeight);
                  final lower = math.max(192.0, (height - 84) * .36);
                  final upper = height - 84 - lower;
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 16,
                          children: [
                            _pair(
                              _overview(data, trend),
                              _operations(data),
                              height: wide ? upper : 364,
                              wide: wide,
                            ),
                            _pair(
                              _artworks(data),
                              _followups(data),
                              height: wide ? lower : 224,
                              wide: wide,
                            ),
                            _shortcuts(wide),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(TeachingRow data) => LayoutBuilder(
    builder: (context, box) {
      final filters = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          AppChip(
            label: '全部校区',
            selected: _campus.isEmpty,
            onTap: () => setState(() => _campus = ''),
          ),
          for (final campus in _campuses)
            AppChip(
              label: teachingText(campus['name']),
              selected: campus['id'] == _campus,
              onTap: () => setState(() => _campus = teachingText(campus['id'])),
            ),
        ],
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_date(data['date']), style: AppText.body13),
          const SizedBox(width: 16),
          AppButton(
            label: '查看作品',
            icon: Icons.north_east,
            size: AppButtonSize.sm,
            onTap: () => _open(TeachingReport.reviewChain),
          ),
        ],
      );
      if (box.maxWidth < 680) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            filters,
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        );
      }
      return SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(child: filters),
            actions,
          ],
        ),
      );
    },
  );

  Widget _pair(
    Widget left,
    Widget right, {
    required double height,
    required bool wide,
  }) {
    if (!wide) {
      return Column(
        spacing: 16,
        children: [
          SizedBox(height: height, child: left),
          SizedBox(height: height, child: right),
        ],
      );
    }
    // Both rows use the same 65:35 split; no independent lower-row sizing.
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 65, child: left),
          const SizedBox(width: 16),
          Expanded(flex: 35, child: right),
        ],
      ),
    );
  }

  Widget _overview(TeachingRow data, AsyncValue<Object?> trend) => AppCard(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCell(
                '今日新交作品',
                _number(data['todaySubmissions']),
                '昨日 ${_number(data['yesterdaySubmissions'])}',
                () => _open(TeachingReport.reviewChain, 'date=${data['date']}'),
              ),
            ),
            _metricDivider(),
            Expanded(
              child: _metricCell(
                '点评及时率',
                _number(data['timelyReviewRate'], suffix: '%'),
                '近7天',
                () => _open(TeachingReport.teachers),
              ),
            ),
            _metricDivider(),
            Expanded(
              child: _metricCell(
                '模考均分',
                _number(data['examMean']),
                data['examChange'] == null
                    ? '暂无对比数据'
                    : '较上次 ${_change(data['examChange'])}',
                () => _open(TeachingReport.classes),
              ),
            ),
          ],
        ),
        const Divider(height: 20, color: AppColors.line),
        Row(
          children: [
            Expanded(child: Text('教学趋势', style: AppText.title16)),
            Text('近7天', style: AppText.body13),
          ],
        ),
        AppTabs<String>(
          value: _metric,
          gap: 24,
          tabs: const [
            AppTab(value: 'submissions', label: '作品提交量'),
            AppTab(value: 'timely', label: '点评及时率'),
            AppTab(value: 'attendance', label: '学生出勤率'),
          ],
          onChanged: (value) => setState(() => _metric = value),
        ),
        Expanded(
          child: trend.when(
            data: (raw) => TeachingTrendChart(
              rows: teachingRows(raw),
              percent: _metric != 'submissions',
              highlightLatest: true,
            ),
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (error, _) =>
                AppErrorState(title: '趋势加载失败', onRetry: _refresh),
          ),
        ),
        const Divider(height: 12, color: AppColors.line),
        SizedBox(
          height: 28,
          child: Row(
            children: [
              for (final label in ['学生提交', '任课老师点评', '组长点评', '校长查看']) ...[
                if (label != '学生提交')
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppText.caption12.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _metricDivider() => Container(
    width: 1,
    height: 48,
    color: AppColors.line,
    margin: const EdgeInsets.symmetric(horizontal: 12),
  );

  Widget _metricCell(
    String title,
    String value,
    String caption,
    VoidCallback onTap,
  ) => AppPressable(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.body13),
        Text(value, style: AppText.displayNumber(size: 32)),
        Text(caption, style: AppText.caption12),
      ],
    ),
  );

  Widget _operations(TeachingRow data) {
    final attendance = teachingRow(data['attendance']);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('今日待办', style: AppText.title16)),
              _link('查看全部', () => _open(TeachingReport.reviewChain)),
            ],
          ),
          const SizedBox(height: 4),
          _queue('待老师点评', data['overdueReviews'], 'overdue'),
          _queue('待组长点评', data['overdueLeadReviews'], 'leadOverdue'),
          const Divider(height: 12, color: AppColors.line),
          AppPressable(
            onTap: () => _open(TeachingReport.attention),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('需要关注的学生', style: AppText.body14Strong),
                Row(
                  children: [
                    Text(
                      _number(data['attentionCount']),
                      style: AppText.displayNumber(size: 24),
                    ),
                    Text(' 人', style: AppText.body13),
                    const Spacer(),
                    Text('查看学情', style: AppText.caption12),
                    const SizedBox(width: 6),
                    _chevron,
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 12, color: AppColors.line),
          Text('在校情况', style: AppText.body14Strong),
          _attendance(
            '学生到校',
            attendance['studentPresent'],
            attendance['studentExpected'],
            'students',
          ),
          _attendance(
            '老师在岗',
            attendance['teacherPresent'],
            attendance['teacherExpected'],
            'teachers',
          ),
          const Spacer(),
          const Divider(height: 12, color: AppColors.line),
          AppPressable(
            onTap: () => _campusView((c) => c.openPrincipalMailbox()),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('校长信箱', style: AppText.body14)),
                  _chevron,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _queue(String title, Object? count, String filter) => AppPressable(
    onTap: () => _open(TeachingReport.reviewChain, 'filter=$filter'),
    child: SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.body13.copyWith(color: AppColors.ink),
            ),
          ),
          AppTag(
            label: '超时 ${_number(count)} 份',
            tone: count is num && count > 0 ? AppTone.warning : AppTone.neutral,
          ),
          const SizedBox(width: 8),
          _chevron,
        ],
      ),
    ),
  );

  Widget _attendance(
    String title,
    Object? present,
    Object? expected,
    String kind,
  ) => AppPressable(
    onTap: () => _open(TeachingReport.attendance, kind),
    child: SizedBox(
      height: 30,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.body13.copyWith(color: AppColors.ink),
            ),
          ),
          Text(
            '${_number(present)} / ${_number(expected)}',
            style: AppText.number(),
          ),
        ],
      ),
    ),
  );

  Widget _artworks(TeachingRow data) {
    final items = teachingRows(data['recentArtworks']).take(3).toList();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('近期作品', style: AppText.title16)),
              _link('查看作品档案', () => _artwork('')),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: items.isEmpty
                ? const AppEmptyState(title: '当前校区暂无作品')
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: _workCard(items[i])),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _workCard(TeachingRow work) => AppPressable(
    semanticLabel: '查看作品 ${teachingText(work['title'])}',
    onTap: () => _artwork(teachingText(work['id'])),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AppImage(
            src: teachingText(work['coverUrl']),
            borderRadius: AppRadius.br8,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          teachingText(work['title']),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.body14Strong,
        ),
        Text(
          '${work['studentName']} · ${ArtSubject.tryParse(teachingText(work['subject']))?.label ?? work['subject']}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption12,
        ),
      ],
    ),
  );

  Widget _followups(TeachingRow data) {
    final alerts = teachingRows(data['alerts']);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('教学跟进', style: AppText.title16),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            Expanded(
              child: Center(child: Text('暂无需要跟进的事项', style: AppText.body13)),
            ),
          for (final alert in alerts.take(3))
            AppPressable(
              onTap: () => _openAlert(alert),
              child: Container(
                constraints: const BoxConstraints(minHeight: 42),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert['detail'] == null
                            ? teachingText(alert['label'])
                            : '${alert['name']} · ${alert['detail']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body13.copyWith(color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _chevron,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openAlert(TeachingRow alert) {
    final id = teachingText(alert['id']);
    switch (alert['target']) {
      case 'attention':
        _open(TeachingReport.attention, id);
      case 'classes':
        openTeachingReport(context, TeachingReport.classes, campus: id);
      default:
        _open(
          TeachingReport.reviewChain,
          'filter=${alert['target']}&teacherId=${Uri.encodeQueryComponent(id)}',
        );
    }
  }

  Widget _shortcuts(bool wide) {
    final entries = <(String, IconData, VoidCallback)>[
      (
        '集市',
        Icons.storefront_outlined,
        () => Navigator.of(context).pushNamed(RoutePaths.marketplace),
      ),
      ('老师履职', Icons.fact_check_outlined, () => _open(TeachingReport.teachers)),
      ('全校学情', Icons.show_chart, () => _open(TeachingReport.classes)),
      ('作品点评链', Icons.edit_outlined, () => _open(TeachingReport.reviewChain)),
      ('更多管理', Icons.layers_outlined, _more),
    ];
    Widget entry((String, IconData, VoidCallback) item) => AppPressable(
      onTap: item.$3,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.$2, size: 20),
            const SizedBox(width: 8),
            Text(item.$1, style: AppText.body13.copyWith(color: AppColors.ink)),
          ],
        ),
      ),
    );
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: wide
          ? Row(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    Container(width: 1, height: 24, color: AppColors.line),
                  Expanded(child: entry(entries[i])),
                ],
              ],
            )
          : Wrap(
              children: [
                for (final item in entries)
                  SizedBox(width: 150, child: entry(item)),
              ],
            ),
    );
  }

  Future<void> _more() async {
    final entries = <(String, IconData, VoidCallback)>[
      (
        '优秀作品墙',
        Icons.image_outlined,
        () => Navigator.of(context).pushNamed(
          RoutePaths.excellentArtworks,
          arguments: {'campusId': _campus},
        ),
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
      ('刷新教学数据', Icons.refresh, _refresh),
    ];
    final chosen = await showAppDialog<int>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: '更多管理',
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entries.length; i++)
              AppListRow(
                title: entries[i].$1,
                leading: Icon(entries[i].$2, size: 20),
                trailing: _chevron,
                onTap: () => Navigator.of(dialogContext).pop(i),
              ),
          ],
        ),
      ),
    );
    if (mounted && chosen != null) entries[chosen].$3();
  }

  Widget _link(String title, VoidCallback onTap) => AppPressable(
    onTap: onTap,
    child: SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.caption12),
          const SizedBox(width: 6),
          const Icon(
            Icons.arrow_forward,
            size: 14,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    ),
  );

  static const _chevron = Icon(
    Icons.chevron_right,
    size: 16,
    color: AppColors.textTertiary,
  );
  String _date(Object? value) {
    final parsed = DateTime.tryParse(teachingText(value));
    return parsed == null
        ? ''
        : '${parsed.year}年${parsed.month}月${parsed.day}日';
  }

  String _number(Object? value, {String suffix = ''}) => value is num
      ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$suffix'
      : '—';
  String _change(Object? value) =>
      value is num && value > 0 ? '+${_number(value)}' : _number(value);
}
