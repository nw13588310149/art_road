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

/// 校长的「全校学情」首屏：教学指标与近七天趋势、教学报表入口、近期作品。
///
/// 这里只放数据与报表。校长当天要处理的事（超时督办、校长信箱、审批、教学跟进）
/// 在「今日工作」里。
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
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '作品提交、点评超时、点评及时率及批改率仅统计已同步作品；复核池按实际复核记录统计。',
                style: AppText.body13,
              ),
            ),
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
                    // 上下两行正好占满一屏：上行是指标与趋势，下行是近期作品。
                    final height = math.max(580.0, box.maxHeight);
                    final lower = math.max(192.0, (height - 16) * .36);
                    final upper = height - 16 - lower;
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
                              _reports(data),
                              height: wide ? upper : 364,
                              wide: wide,
                            ),
                            _pair(
                              _artworks(data),
                              _management(),
                              height: wide ? lower : 224,
                              wide: wide,
                            ),
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
          const SizedBox(width: 8),
          AppIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: '刷新教学数据',
            size: AppButtonSize.sm,
            background: AppColors.surface,
            onTap: _refresh,
          ),
          const SizedBox(width: 8),
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

  /// 教学报表入口：每行一份报表，右侧带一个当前数字，点开看明细。
  Widget _reports(TeachingRow data) {
    final attendance = teachingRow(data['attendance']);
    String ratio(Object? present, Object? expected) =>
        '${_number(present)} / ${_number(expected)}';
    final rows = <(String, String, String, VoidCallback)>[
      (
        '班级学情',
        '各校区、各班的月考成绩',
        _number(data['examMean']),
        () => _open(TeachingReport.classes),
      ),
      (
        '老师履职',
        '点评及时率与课堂签课',
        _number(data['timelyReviewRate'], suffix: '%'),
        () => _open(TeachingReport.teachers),
      ),
      (
        '作品点评链',
        '提交、老师点评、组长复核的进度',
        '超时 ${_number(data['overdueReviews'])} 份',
        () => _open(TeachingReport.reviewChain),
      ),
      (
        '需要关注的学生',
        '成绩下滑、缺勤或长时间未交作品',
        '${_number(data['attentionCount'])} 人',
        () => _open(TeachingReport.attention),
      ),
      (
        '学生到校',
        '今日已签到 / 应到',
        ratio(attendance['studentPresent'], attendance['studentExpected']),
        () => _open(TeachingReport.attendance, 'students'),
      ),
      (
        '老师在岗',
        '今日已签课 / 有课老师',
        ratio(attendance['teacherPresent'], attendance['teacherExpected']),
        () => _open(TeachingReport.attendance, 'teachers'),
      ),
    ];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('教学报表', style: AppText.title16),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  Expanded(
                    child: AppPressable(
                      onTap: rows[i].$4,
                      semanticLabel: '${rows[i].$1} ${rows[i].$3}',
                      child: Container(
                        decoration: i < rows.length - 1
                            ? const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.lineSoft),
                                ),
                              )
                            : null,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    rows[i].$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.body14Strong,
                                  ),
                                  Text(
                                    rows[i].$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption12,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(rows[i].$3, style: AppText.number(size: 14)),
                            const SizedBox(width: 4),
                            _chevron,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  /// 与教学数据相关的管理入口。审批与信箱在「今日工作」里。
  Widget _management() {
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
        Icons.campaign_outlined,
        () => _campusView((c) => c.openNotificationManagement()),
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
    Widget tile((String, IconData, VoidCallback) item) => AppPressable(
      onTap: item.$3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br12,
        ),
        child: Row(
          children: [
            Icon(item.$2, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body13.copyWith(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('常用管理', style: AppText.title16),
          const SizedBox(height: 10),
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(entries[row * 2])),
                  const SizedBox(width: 8),
                  Expanded(child: tile(entries[row * 2 + 1])),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
