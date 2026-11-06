// =============================================================================
// 管理员端「通知管理」独立页面
//
// 入口：admin 首页快捷区「通知管理」按钮 →
//       controller.openNotificationManagement() →
//       mainView == notificationManagement + role == admin → SmartCampusPage
//       路由到本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. banner（62 高，4deg 白→#F9EDFF 渐变，圆角 16）：
//      - 左 12 返回按钮 32×32 白底 outline #F3F2F3。
//      - 居中标题 "通知管理" 16/600 + 副标题 12/#B6B5BB
//        「按类型维护校级通知，支持定时与即时发布，并配置推送范围
//        （学生 / 教师 / 宿管等）」。
//      - 右 12 「新建通知」按钮（白底 outline #F3F2F3，4 点九宫格 icon
//        + 12/600 黑字）→ 打开右侧 600 抽屉表单。
//   2. 4 张统计卡（100 高，flex 1 1 0，间距 12，196deg 渐变白底，圆角 12）：
//      - 已发布   紫渐变 #E7DCFF→white  显示 published 数量。
//      - 定时中   橙渐变 #FFF0DC→white  显示 scheduled 数量。
//      - 已撤回   红渐变 #FFE2DC→white  显示 withdrawn 数量。
//      - 全部     红渐变 #FFE2DC→white  显示总数。
//   3. 顶部一行筛选 / 搜索（44 高）：
//      - 左：「全部类型」+「全部状态」两个 120 宽下拉（白底 12 圆角，
//        #0B081A 14/400 + 下三角）。
//      - 右：324 宽搜索框（白底 12 圆角，圆形描边放大镜 +
//        占位「搜索标题、内容、作者」）。
//   4. 970 宽白底 16 圆角表格：12 padding，946×40 #F9FAFB 表头 +
//      多个 60 高数据行（底部 1px #F3F2F3 分隔）：
//      标题（200，title 13/500 + author 11/#6D6B75）/ 类型（flex）/
//      优先级（flex，3 根 2px 竖条信号 + 文字：普通=黑，重要=#325BFF，
//      紧急=#FF323C）/ 范围（120）/ 状态（flex，状态徽标
//      已通过=#E4FFED/#12CE51；定时中=
//      #FFEDD3/#FF6A00；已撤回=#FFE5E5/#E83A3A）/ 时间（120）/
//      操作（120，已发布=「查看」+「删除」；定时中=「编辑」+「删除」；已撤回=「查看」）。
//   5. 「新建通知 / 编辑通知」抽屉（右侧 600 宽，全高白底）：
//      - 头部 62 高（紫色竖条 + 16/600 标题 + 关闭按钮）。
//      - 表单（滚动）：标题（输入）/ 内容（多行）/
//        通知类型（PopupSelector：督导/通知/活动/会议/其他）/
//        优先级（信号条 segment：普通/重要/紧急）/
//        推送范围（多选 chip：学生/教师/班主任/宿管/家长/全校师生）/
//        发布方式（segment：立即发布 / 定时发布；
//        定时发布展开「定时时间」TextField + 日历 picker）。
//      - 底部 48 高紫渐变「提交保存」按钮，按选择的发布方式落库。
//   6. 「查看通知」详情弹窗：用 GradientHeaderDialog，列出全部字段。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/popup_selector_field.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/admin_notice_data.dart';
import '../data/admin_repository.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'widgets/smart_campus_stat_card.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kHairline = Color(0xFFF3F2F3);
const Color _kHeaderBg = Color(0xFFF9FAFB);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextMuted = Color(0xFF71717A);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kPurple = Color(0xFF8741FF);
const Color _kBlue = Color(0xFF325BFF);
const Color _kRed = Color(0xFFFF323C);
const Color _kOrange = Color(0xFFFF6A00);

// 状态徽标颜色
const Color _kPassedBg = Color(0xFFE4FFED);
const Color _kPassedFg = Color(0xFF12CE51);
const Color _kPendingBg = Color(0xFFFFEDD3);
const Color _kPendingFg = _kOrange;
const Color _kRejectedBg = Color(0xFFFFE5E5);
const Color _kRejectedFg = Color(0xFFE83A3A);

// =============================================================================
// 数据模型 —— 优先级 / 状态 / 类型
// =============================================================================

enum _NPriority { normal, important, urgent }

extension _NPriorityX on _NPriority {
  String get label => switch (this) {
    _NPriority.normal => '普通',
    _NPriority.important => '重要',
    _NPriority.urgent => '紧急',
  };
  Color get color => switch (this) {
    _NPriority.normal => _kTextDark,
    _NPriority.important => _kBlue,
    _NPriority.urgent => _kRed,
  };

  /// 信号条三段：(active1, active2, active3)
  /// - 普通：仅第 1 段亮
  /// - 重要：第 1、2 段亮
  /// - 紧急：三段全亮
  List<bool> get bars => switch (this) {
    _NPriority.normal => const [true, false, false],
    _NPriority.important => const [true, true, false],
    _NPriority.urgent => const [true, true, true],
  };
}

/// 优先级信号条（列表 / 表单 / 详情共用，保证尺寸一致）。
class _PrioritySignalBars extends StatelessWidget {
  const _PrioritySignalBars({
    required this.bars,
    required this.activeColor,
  });

  final List<bool> bars;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(ui(2), ui(4), bars[0] ? activeColor : _kTextDivider),
          SizedBox(width: ui(2)),
          _bar(ui(2), ui(6), bars[1] ? activeColor : _kTextDivider),
          SizedBox(width: ui(2)),
          _bar(ui(2), ui(8), bars[2] ? activeColor : _kTextDivider),
        ],
      ),
    );
  }

  Widget _bar(double w, double h, Color c) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

enum _NStatus { published, scheduled, withdrawn }

extension _NStatusX on _NStatus {
  String get label => switch (this) {
    _NStatus.published => '已通过',
    _NStatus.scheduled => '定时中',
    _NStatus.withdrawn => '已撤回',
  };

  Color get bg => switch (this) {
    _NStatus.published => _kPassedBg,
    _NStatus.scheduled => _kPendingBg,
    _NStatus.withdrawn => _kRejectedBg,
  };

  Color get fg => switch (this) {
    _NStatus.published => _kPassedFg,
    _NStatus.scheduled => _kPendingFg,
    _NStatus.withdrawn => _kRejectedFg,
  };
}

/// 通知类型：与新建抽屉里的下拉一一对应。
const List<String> _kNotificationTypes = <String>['督导', '通知', '活动', '会议', '其他'];

/// 推送范围：抽屉里的多选项；表格里展示拼接后的字符串。
const List<String> _kScopeOptions = <String>[
  '全校师生',
  '学生',
  '教师',
  '班主任',
  '宿管',
  '家长',
];

/// 类型筛选下拉项 / 状态筛选下拉项的 "全部" 标识。
const String _kAllType = '全部类型';
const String _kAllStatus = '全部状态';

class _NotificationRecord {
  _NotificationRecord({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.type,
    required this.priority,
    required this.scopes,
    required this.status,
    required this.time,
    this.scheduledAt,
  });

  String id;
  String title;
  String content;
  String author;
  String type;
  _NPriority priority;
  List<String> scopes;
  _NStatus status;

  /// 用于显示的时间字符串 `2026-03-24 10:05`。
  ///
  /// 已发布：发布时间；定时中：定时时间；已撤回：撤回时间。
  String time;

  /// 仅 [_NStatus.scheduled] 时使用：定时发布的时间。
  DateTime? scheduledAt;

  /// 推送范围展示文案。
  ///
  /// 「全选」（包含全部角色，或显式包含「全校师生」，或为空表示默认全员）
  /// 统一展示为「全校师生及访客端」；否则按角色顿号拼接。
  String get scopeLabel {
    final roleLabels = kAdminNoticeScopeLabelToApi.keys;
    final isAll =
        scopes.isEmpty ||
        scopes.contains('全校师生') ||
        roleLabels.every(scopes.contains);
    return isAll ? '全校师生及访客端' : scopes.join('、');
  }
}

// =============================================================================
// 主视图
// =============================================================================

class AdminNotificationManagementView extends ConsumerStatefulWidget {
  const AdminNotificationManagementView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<AdminNotificationManagementView> createState() =>
      _AdminNotificationManagementViewState();
}

class _AdminNotificationManagementViewState
    extends ConsumerState<AdminNotificationManagementView> {
  List<_NotificationRecord> _records = const [];
  int _loadToken = 0;

  String _typeFilter = _kAllType;
  String _statusFilter = _kAllStatus;
  String _query = '';
  late final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecords());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    if (v == _query) return;
    setState(() => _query = v);
  }

  // —— 筛选 ——————————————————————————————————————————————————————

  List<_NotificationRecord> get _filtered {
    final q = _query.trim().toLowerCase();
    return _records.where((r) {
      if (_typeFilter != _kAllType && r.type != _typeFilter) return false;
      if (_statusFilter != _kAllStatus && _statusFilter != r.status.label) {
        return false;
      }
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          r.content.toLowerCase().contains(q) ||
          r.author.toLowerCase().contains(q);
    }).toList();
  }

  int _countOf(_NStatus s) => _records.where((r) => r.status == s).length;

  _NotificationRecord _mapRecord(AdminNoticeRecord r) {
    return _NotificationRecord(
      id: r.id,
      title: r.title,
      content: r.content,
      author: r.deptName.isNotEmpty ? '${r.deptName} · ${r.author}' : r.author,
      type: r.type,
      priority: _mapPriority(r.priority),
      scopes: r.scopes,
      status: _mapStatus(r.status),
      time: r.time,
      scheduledAt: r.scheduledAt,
    );
  }

  _NPriority _mapPriority(AdminNoticePriority p) => switch (p) {
    AdminNoticePriority.normal => _NPriority.normal,
    AdminNoticePriority.important => _NPriority.important,
    AdminNoticePriority.urgent => _NPriority.urgent,
  };

  AdminNoticePriority _mapPriorityBack(_NPriority p) => switch (p) {
    _NPriority.normal => AdminNoticePriority.normal,
    _NPriority.important => AdminNoticePriority.important,
    _NPriority.urgent => AdminNoticePriority.urgent,
  };

  _NStatus _mapStatus(AdminNoticeStatus s) => switch (s) {
    AdminNoticeStatus.published => _NStatus.published,
    AdminNoticeStatus.scheduled => _NStatus.scheduled,
    AdminNoticeStatus.withdrawn => _NStatus.withdrawn,
    AdminNoticeStatus.draft => _NStatus.published,
  };

  Future<void> _loadRecords() async {
    final token = ++_loadToken;
    final repo = ref.read(adminRepositoryProvider);
    try {
      final typeParam = _typeFilter == _kAllType ? null : _typeFilter;
      final resp = await repo.noticeManageList(size: 500, type: typeParam);
      if (!mounted || token != _loadToken) return;
      if (!resp.isSuccess) {
        setState(() => _records = const []);
        AppToast.show(context, '通知列表加载失败：${resp.msg}');
        return;
      }
      final parsed = parseAdminNoticeList(resp.data)
          .where((r) => r.status != AdminNoticeStatus.draft)
          .map(_mapRecord)
          .toList(growable: false);
      setState(() => _records = parsed);
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() => _records = const []);
      AppToast.show(context, '通知列表加载失败：$e');
    }
  }

  Future<bool> _submitNotice({
    required String title,
    required String content,
    required String type,
    required _NPriority priority,
    required Set<String> scopes,
    required _PublishMode mode,
    DateTime? scheduledAt,
  }) async {
    final user = ref.read(shellControllerProvider).user;
    final publishMode = switch (mode) {
      _PublishMode.now => 1,
      _PublishMode.scheduled => 2,
    };
    final request = AdminNoticeSaveRequest(
      title: title,
      content: content,
      type: type,
      priority: _mapPriorityBack(priority),
      scopes: scopes,
      publishMode: publishMode,
      scheduledAt: scheduledAt,
      creator: user.displayName,
      deptName: user.school.isNotEmpty ? user.school : '校办',
    );
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.noticeSave(request.toJson());
    if (!mounted) return false;
    if (!resp.isSuccess) {
      AppToast.show(context, '保存失败：${resp.msg}');
      return false;
    }
    await _loadRecords();
    if (!mounted) return true;
    AppToast.show(
      context,
      _toastForStatus(switch (mode) {
        _PublishMode.now => _NStatus.published,
        _PublishMode.scheduled => _NStatus.scheduled,
      }, isCreate: true),
    );
    return true;
  }

  Future<_NotificationRecord?> _fetchNoticeDetail(String id) async {
    final repo = ref.read(adminRepositoryProvider);
    try {
      final resp = await repo.noticeDetail(id: id);
      if (!resp.isSuccess) return null;
      final detail = parseAdminNoticeDetail(resp.data);
      return detail == null ? null : _mapRecord(detail);
    } catch (_) {
      return null;
    }
  }

  // —— 行操作：查看 / 编辑 / 删除 / 新建 —————————————————————————————

  Future<void> _openCreateDrawer() async {
    final scale = DashboardScaleScope.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭新建通知',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) => Align(
        alignment: Alignment.centerRight,
        child: DashboardScaleScope(
          data: scale,
          child: _NotificationFormDrawer(
            initial: null,
            onCancel: () => Navigator.of(ctx).pop(),
            onSubmit: (params) =>
                _submitNotice(
                  title: params.title,
                  content: params.content,
                  type: params.type,
                  priority: params.priority,
                  scopes: params.scopes,
                  mode: params.mode,
                  scheduledAt: params.scheduledAt,
                ).then((ok) {
                  if (ok && ctx.mounted) Navigator.of(ctx).pop();
                  return ok;
                }),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, sec, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  Future<void> _openEditDrawer(_NotificationRecord origin) async {
    AppToast.show(context, 'APP端接口暂未提供通知更新能力');
  }

  Future<void> _onDeleteRecord(_NotificationRecord r) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除通知',
      content: '确认删除「${r.title}」？删除后该通知将不再可见，操作不可恢复。',
      confirmLabel: '删除',
    );
    if (!ok || !mounted) return;
    final repo = ref.read(adminRepositoryProvider);
    final resp = await repo.noticeDelete(id: r.id);
    if (!mounted) return;
    if (!resp.isSuccess) {
      AppToast.show(context, '删除失败：${resp.msg}');
      return;
    }
    AppToast.show(context, '已删除「${r.title}」');
    await _loadRecords();
  }

  Future<void> _onViewRecord(_NotificationRecord r) async {
    final detail = await _fetchNoticeDetail(r.id) ?? r;
    if (!mounted) return;
    return showNoticeDetailDialog<void>(
      context: context,
      builder: (ctx) => GradientHeaderDialog(
        title: '通知详情',
        width: 460,
        child: _NotificationDetailBody(record: detail),
      ),
    );
  }

  String _toastForStatus(_NStatus s, {required bool isCreate}) {
    final verb = isCreate ? '已新建' : '已更新';
    switch (s) {
      case _NStatus.published:
        return '$verb通知并发布';
      case _NStatus.scheduled:
        return '$verb通知，将按定时时间发送';
      case _NStatus.withdrawn:
        return '$verb通知（已撤回）';
    }
  }

  // —— 渲染 ——————————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final list = _filtered;
    return SmartCampusSecondaryPageShell(
      backgroundColor: _kPageBg,
      bodyTopClipRadius: 8,
      header: _Banner(onBack: widget.onBack, onCreate: _openCreateDrawer),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsRow(
            published: _countOf(_NStatus.published),
            scheduled: _countOf(_NStatus.scheduled),
            withdrawn: _countOf(_NStatus.withdrawn),
            total: _records.length,
          ),
          SizedBox(height: ui(16)),
          _ControlBar(
            typeValue: _typeFilter,
            statusValue: _statusFilter,
            onTypeChanged: (v) {
              setState(() => _typeFilter = v);
              unawaited(_loadRecords());
            },
            onStatusChanged: (v) => setState(() => _statusFilter = v),
            searchCtrl: _searchCtrl,
            onSearchChanged: _onSearchChanged,
          ),
          SizedBox(height: ui(12)),
          _NotificationTable(
            records: list,
            onView: _onViewRecord,
            onEdit: _openEditDrawer,
            onDelete: _onDeleteRecord,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// banner —— 返回 + 标题 + 副标题 + 新建通知按钮
// =============================================================================

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack, required this.onCreate});

  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        image: const DecorationImage(
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
              padding: EdgeInsets.symmetric(horizontal: ui(160)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '通知管理',
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
                    '按类型维护校级通知，支持定时与即时发布，并配置推送范围（学生 / 教师 / 宿管等）',
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
          Positioned(
            right: ui(12),
            top: ui(14),
            child: _CreateButton(onTap: onCreate),
          ),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(34),
        padding: EdgeInsets.symmetric(horizontal: ui(10)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              AppAssets.adminNotificationCreateNoticeIcon,
              width: ui(18),
              height: ui(18),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(4)),
            Text(
              '新建通知',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 4 张统计卡 —— 已发布 / 定时中 / 已撤回 / 全部
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.published,
    required this.scheduled,
    required this.withdrawn,
    required this.total,
  });

  final int published;
  final int scheduled;
  final int withdrawn;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminNotificationStatCard1,
            label: '已发布',
            value: published,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminNotificationStatCard2,
            label: '定时中',
            value: scheduled,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminNotificationStatCard3,
            label: '已撤回',
            value: withdrawn,
          ),
        ),
        SizedBox(width: ui(12)),
        Expanded(
          child: SmartCampusStatCard(
            backgroundAsset: AppAssets.adminNotificationStatCard4,
            label: '全部',
            value: total,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 筛选 / 搜索条
// =============================================================================

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.typeValue,
    required this.statusValue,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.searchCtrl,
    required this.onSearchChanged,
  });

  final String typeValue;
  final String statusValue;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _NotificationFilterField(
          width: ui(160),
          value: typeValue,
          items: <String>[_kAllType, ..._kNotificationTypes],
          onChanged: onTypeChanged,
        ),
        SizedBox(width: ui(12)),
        _NotificationFilterField(
          width: ui(160),
          value: statusValue,
          items: <String>[
            _kAllStatus,
            for (final s in _NStatus.values) s.label,
          ],
          onChanged: onStatusChanged,
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
                  controller: searchCtrl,
                  onChanged: onSearchChanged,
                  cursorColor: _kPurple,
                  cursorWidth: 1.5,
                  cursorHeight: ui(16),
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.2,
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '搜索标题、内容、作者',
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

class _NotificationFilterField extends StatefulWidget {
  const _NotificationFilterField({
    required this.width,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  State<_NotificationFilterField> createState() =>
      _NotificationFilterFieldState();
}

class _NotificationFilterFieldState extends State<_NotificationFilterField> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    final fieldCtx = _fieldKey.currentContext;
    if (fieldCtx == null) return;
    setState(() => _open = true);
    final selected = await showAppPopupSelector<String>(
      anchorContext: fieldCtx,
      items: widget.items,
      value: widget.value,
      itemLabel: (s) => s,
      width: DashboardScaleScope.of(fieldCtx).ui(280),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      key: _fieldKey,
      onTap: _openMenu,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: widget.width,
        height: ui(44),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.2,
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(21),
                color: _kTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 表格 —— 表头 + 数据行
// =============================================================================

class _NotificationTable extends StatelessWidget {
  const _NotificationTable({
    required this.records,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_NotificationRecord> records;
  final ValueChanged<_NotificationRecord> onView;
  final ValueChanged<_NotificationRecord> onEdit;
  final ValueChanged<_NotificationRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TableHeader(),
          if (records.isEmpty)
            Container(
              height: ui(120),
              alignment: Alignment.center,
              child: Text(
                '暂无通知',
                style: TextStyle(
                  fontSize: ui(13),
                  color: _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            )
          else
            for (final r in records)
              _TableRow(
                record: r,
                onTap: () => onView(r),
                onEdit: () => onEdit(r),
                onDelete: () => onDelete(r),
              ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(10)),
      decoration: BoxDecoration(
        color: _kHeaderBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        children: const [
          _HeaderCell(width: 200, text: '标题'),
          _HeaderGap(),
          Expanded(child: _HeaderCell(text: '类型')),
          _HeaderGap(),
          Expanded(child: _HeaderCell(text: '优先级')),
          _HeaderGap(),
          _HeaderCell(width: 120, text: '范围'),
          _HeaderGap(),
          Expanded(child: _HeaderCell(text: '状态')),
          _HeaderGap(),
          _HeaderCell(width: 120, text: '时间'),
          _HeaderGap(),
          _HeaderCell(width: 120, text: '操作'),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({this.width, required this.text});

  final double? width;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final child = Text(
      text,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextMuted,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 20 / 13,
      ),
    );
    if (width == null) return child;
    return SizedBox(width: ui(width!), child: child);
  }
}

class _HeaderGap extends StatelessWidget {
  const _HeaderGap();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(width: ui(12));
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.record,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final _NotificationRecord record;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(60),
        padding: EdgeInsets.symmetric(horizontal: ui(10)),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kHairline)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: ui(200),
              child: _TitleCell(title: record.title, author: record.author),
            ),
            const _HeaderGap(),
            Expanded(child: _TextCell(text: record.type)),
            const _HeaderGap(),
            Expanded(child: _PriorityCell(priority: record.priority)),
            const _HeaderGap(),
            SizedBox(
              width: ui(120),
              child: _TextCell(text: record.scopeLabel, maxLines: 2),
            ),
            const _HeaderGap(),
            Expanded(child: _StatusCell(status: record.status)),
            const _HeaderGap(),
            SizedBox(
              width: ui(120),
              child: _TextCell(text: record.time),
            ),
            const _HeaderGap(),
            SizedBox(
              width: ui(120),
              child: _ActionCell(
                status: record.status,
                onView: onTap,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleCell extends StatelessWidget {
  const _TitleCell({required this.title, required this.author});

  final String title;
  final String author;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
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
        Text(
          author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ui(11),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 11,
          ),
        ),
      ],
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({required this.text, this.maxLines = 1});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ui(13),
        color: _kTextDark,
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 20 / 13,
      ),
    );
  }
}

class _PriorityCell extends StatelessWidget {
  const _PriorityCell({required this.priority});

  final _NPriority priority;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PrioritySignalBars(bars: priority.bars, activeColor: priority.color),
        SizedBox(width: ui(4)),
        Flexible(
          child: Text(
            priority.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui(13),
              color: priority.color,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 20 / 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.status});

  final _NStatus status;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
        decoration: BoxDecoration(
          color: status.bg,
          borderRadius: BorderRadius.circular(ui(4)),
        ),
        child: Text(
          status.label,
          style: TextStyle(
            fontSize: ui(12),
            color: status.fg,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 15.24 / 12,
          ),
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.status,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final _NStatus status;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 已撤回：仅「查看」；已发布：「查看 + 删除」；定时中：「编辑 + 删除」。
    if (status == _NStatus.withdrawn) {
      return Row(
        children: [
          _actionText(text: '查看', color: _kBlue, onTap: onView, ui: ui),
        ],
      );
    }
    if (status == _NStatus.published) {
      return Row(
        children: [
          _actionText(text: '查看', color: _kBlue, onTap: onView, ui: ui),
          SizedBox(width: ui(12)),
          _actionText(text: '删除', color: _kRed, onTap: onDelete, ui: ui),
        ],
      );
    }
    return Row(
      children: [
        _actionText(text: '编辑', color: _kPurple, onTap: onEdit, ui: ui),
        SizedBox(width: ui(12)),
        _actionText(text: '删除', color: _kRed, onTap: onDelete, ui: ui),
      ],
    );
  }

  Widget _actionText({
    required String text,
    required Color color,
    required VoidCallback onTap,
    required double Function(num) ui,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(13),
          color: color,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 13,
        ),
      ),
    );
  }
}

// =============================================================================
// 通知详情弹窗
// =============================================================================

class _NotificationDetailBody extends StatelessWidget {
  const _NotificationDetailBody({required this.record});

  final _NotificationRecord record;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          record.title,
          style: TextStyle(
            fontSize: ui(15),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1.5,
          ),
        ),
        SizedBox(height: ui(8)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
              decoration: BoxDecoration(
                color: record.status.bg,
                borderRadius: BorderRadius.circular(ui(4)),
              ),
              child: Text(
                record.status.label,
                style: TextStyle(
                  fontSize: ui(12),
                  color: record.status.fg,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(width: ui(8)),
            Text(
              record.author,
              style: TextStyle(
                fontSize: ui(12),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.4,
              ),
            ),
          ],
        ),
        SizedBox(height: ui(16)),
        _DetailRow(label: '类型', value: record.type),
        _DetailPriorityRow(priority: record.priority),
        _DetailRow(label: '推送范围', value: record.scopeLabel),
        _DetailRow(label: '时间', value: record.time, isLast: true),
        SizedBox(height: ui(12)),
        Text(
          '内容：',
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 1.4,
          ),
        ),
        SizedBox(height: ui(6)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui(12)),
          decoration: BoxDecoration(
            color: _kInnerGray,
            borderRadius: BorderRadius.circular(ui(10)),
          ),
          child: Text(
            record.content.isEmpty ? '（暂无正文）' : record.content,
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 22 / 13,
            ),
          ),
        ),
        SizedBox(height: ui(8)),
      ],
    );
  }
}

class _DetailPriorityRow extends StatelessWidget {
  const _DetailPriorityRow({required this.priority});

  final _NPriority priority;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(10)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kHairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(72),
            child: Text(
              '优先级：',
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _PrioritySignalBars(
                  bars: priority.bars,
                  activeColor: priority.color,
                ),
                SizedBox(width: ui(4)),
                Text(
                  priority.label,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: priority.color,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 20 / 13,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(vertical: ui(10)),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kHairline)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ui(72),
            child: Text(
              '$label：',
              style: TextStyle(
                fontSize: ui(13),
                color: _kTextSecondary,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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
  }
}

// =============================================================================
// 新建 / 编辑通知 抽屉
// =============================================================================

class _NoticeFormSubmitParams {
  const _NoticeFormSubmitParams({
    required this.title,
    required this.content,
    required this.type,
    required this.priority,
    required this.scopes,
    required this.mode,
    this.scheduledAt,
  });

  final String title;
  final String content;
  final String type;
  final _NPriority priority;
  final Set<String> scopes;
  final _PublishMode mode;
  final DateTime? scheduledAt;
}

/// 当 [initial] 不为 null 时为「编辑」模式；否则为「新建」。
class _NotificationFormDrawer extends StatefulWidget {
  const _NotificationFormDrawer({
    required this.initial,
    required this.onCancel,
    required this.onSubmit,
  });

  final _NotificationRecord? initial;
  final VoidCallback onCancel;
  final Future<bool> Function(_NoticeFormSubmitParams params) onSubmit;

  @override
  State<_NotificationFormDrawer> createState() =>
      _NotificationFormDrawerState();
}

enum _PublishMode { now, scheduled }

extension _PublishModeX on _PublishMode {
  String get label => switch (this) {
    _PublishMode.now => '立即发布',
    _PublishMode.scheduled => '定时发布',
  };
}

class _NotificationFormDrawerState extends State<_NotificationFormDrawer> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late String _type;
  late _NPriority _priority;
  late Set<String> _scopes;
  late _PublishMode _mode;
  DateTime? _scheduledAt;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _contentCtrl = TextEditingController(text: init?.content ?? '');
    _type = init?.type ?? _kNotificationTypes.first;
    _priority = init?.priority ?? _NPriority.normal;
    _scopes = {...?init?.scopes};
    if (_scopes.isEmpty) _scopes.add('全校师生');
    _scheduledAt = init?.scheduledAt;
    _mode = switch (init?.status) {
      _NStatus.scheduled => _PublishMode.scheduled,
      _NStatus.published => _PublishMode.now,
      _NStatus.withdrawn => _PublishMode.now,
      null => _PublishMode.now,
    };
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // —— 选定时时间 —————————————————————————————————————————————————

  Future<void> _pickScheduledAt() async {
    final now = DateTime.now();
    final base = _scheduledAt ?? now.add(const Duration(hours: 1));
    final date = await showAppDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: '选择发布日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (date == null || !mounted) return;
    final time = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: '选择发布时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // —— 表单校验 + 提交 ——————————————————————————————————————————

  Future<void> _onSubmit() async {
    if (_submitting) return;
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      AppToast.show(context, '请填写通知标题');
      return;
    }
    if (content.isEmpty) {
      AppToast.show(context, '请填写通知内容');
      return;
    }
    if (_scopes.isEmpty) {
      AppToast.show(context, '请至少勾选一个推送范围');
      return;
    }
    if (encodeAdminNoticeScopes(_scopes).isEmpty) {
      AppToast.show(context, '请选择有效的推送范围（学生/教师/班主任/宿管/家长）');
      return;
    }
    if (_mode == _PublishMode.scheduled) {
      if (_scheduledAt == null) {
        AppToast.show(context, '请选择定时发布时间');
        return;
      }
      if (_scheduledAt!.isBefore(DateTime.now())) {
        AppToast.show(context, '定时时间需晚于当前时间');
        return;
      }
    }

    setState(() => _submitting = true);
    final ok = await widget.onSubmit(
      _NoticeFormSubmitParams(
        title: title,
        content: content,
        type: _type,
        priority: _priority,
        scopes: _scopes,
        mode: _mode,
        scheduledAt: _scheduledAt,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) return;
  }

  String _submitLabel() {
    if (_submitting) return '提交中…';
    return switch (_mode) {
      _PublishMode.now => '立即发布',
      _PublishMode.scheduled => '保存并定时',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isEdit = widget.initial != null;
    // 外层 [Material]：showGeneralDialog 走 root overlay，其内部并没有 Material
    // 祖先；抽屉里大量使用 [InkWell] / [TextField] 都依赖 Material（splash + 默认
    // 文本主题），少了它会直接抛 "No Material widget found" 异常。
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: ui(600),
        height: double.infinity,
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              _DrawerHeader(
                title: isEdit ? '编辑通知' : '新建通知',
                onClose: widget.onCancel,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(ui(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel(label: '通知标题', required: true),
                      SizedBox(height: ui(8)),
                      _TextField(
                        controller: _titleCtrl,
                        hint: '请输入通知标题（建议 ≤ 30 字）',
                        maxLength: 60,
                      ),
                      SizedBox(height: ui(20)),
                      const _SectionLabel(label: '通知内容', required: true),
                      SizedBox(height: ui(8)),
                      _TextField(
                        controller: _contentCtrl,
                        hint: '请输入正文，可包含时间、地点、参加人员等关键信息',
                        maxLines: 5,
                        maxLength: 500,
                      ),
                      SizedBox(height: ui(20)),
                      const _SectionLabel(label: '通知类型'),
                      SizedBox(height: ui(8)),
                      PopupSelectorField<String>(
                        value: _type,
                        items: _kNotificationTypes,
                        itemLabel: (s) => s,
                        onChanged: (v) => setState(() => _type = v),
                      ),
                      SizedBox(height: ui(20)),
                      const _SectionLabel(label: '优先级'),
                      SizedBox(height: ui(8)),
                      _PrioritySegment(
                        value: _priority,
                        onChanged: (v) => setState(() => _priority = v),
                      ),
                      SizedBox(height: ui(20)),
                      const _SectionLabel(label: '推送范围', required: true),
                      SizedBox(height: ui(8)),
                      _ScopeChips(
                        selected: _scopes,
                        onToggle: (s) => setState(() {
                          if (_scopes.contains(s)) {
                            _scopes.remove(s);
                          } else {
                            _scopes.add(s);
                          }
                        }),
                      ),
                      SizedBox(height: ui(20)),
                      const _SectionLabel(label: '发布方式'),
                      SizedBox(height: ui(8)),
                      _PublishModeSegment(
                        value: _mode,
                        onChanged: (v) => setState(() => _mode = v),
                      ),
                      if (_mode == _PublishMode.scheduled) ...[
                        SizedBox(height: ui(12)),
                        _ScheduledPickerField(
                          value: _scheduledAt,
                          onTap: _pickScheduledAt,
                        ),
                      ],
                      SizedBox(height: ui(8)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
                child: Row(
                  children: [
                    Expanded(
                      child: _SecondaryButton(
                        label: '取消',
                        onTap: _submitting ? null : widget.onCancel,
                      ),
                    ),
                    SizedBox(width: ui(12)),
                    Expanded(
                      child: _PrimaryButton(
                        label: _submitLabel(),
                        onTap: _submitting ? null : _onSubmit,
                      ),
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

// —— 抽屉内表单子组件 —————————————————————————————————————————————

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title, required this.onClose});

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
          SizedBox(width: ui(8)),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        if (required)
          Padding(
            padding: EdgeInsets.only(right: ui(2)),
            child: Text(
              '*',
              style: TextStyle(
                fontSize: ui(14),
                color: _kRed,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
        Text(
          label,
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

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(10)),
        border: Border.all(color: _kInnerGray, width: 1),
      ),
      child: AppTextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 22 / 14,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          counterText: '',
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 22 / 14,
          ),
        ),
      ),
    );
  }
}

class _PrioritySegment extends StatelessWidget {
  const _PrioritySegment({required this.value, required this.onChanged});

  final _NPriority value;
  final ValueChanged<_NPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (final p in _NPriority.values) ...[
          Expanded(
            child: InkWell(
              onTap: () => onChanged(p),
              borderRadius: BorderRadius.circular(ui(10)),
              child: Container(
                height: ui(44),
                decoration: BoxDecoration(
                  color: value == p
                      ? p.color.withValues(alpha: 0.10)
                      : _kInnerGray,
                  borderRadius: BorderRadius.circular(ui(10)),
                  border: value == p
                      ? Border.all(color: p.color, width: 1)
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _PrioritySignalBars(bars: p.bars, activeColor: p.color),
                    SizedBox(width: ui(4)),
                    Text(
                      p.label,
                      style: TextStyle(
                        fontSize: ui(13),
                        color: value == p ? p.color : _kTextSecondary,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 20 / 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (p != _NPriority.values.last) SizedBox(width: ui(8)),
        ],
      ],
    );
  }
}

class _ScopeChips extends StatelessWidget {
  const _ScopeChips({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Wrap(
      spacing: ui(8),
      runSpacing: ui(8),
      children: [
        for (final s in _kScopeOptions)
          InkWell(
            onTap: () => onToggle(s),
            borderRadius: BorderRadius.circular(ui(8)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(14),
                vertical: ui(8),
              ),
              decoration: BoxDecoration(
                color: selected.contains(s)
                    ? _kPurple.withValues(alpha: 0.10)
                    : _kInnerGray,
                borderRadius: BorderRadius.circular(ui(8)),
                border: selected.contains(s)
                    ? Border.all(color: _kPurple, width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected.contains(s))
                    Padding(
                      padding: EdgeInsets.only(right: ui(4)),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: ui(14),
                        color: _kPurple,
                      ),
                    ),
                  Text(
                    s,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: selected.contains(s) ? _kPurple : _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: selected.contains(s)
                          ? AppFont.w600
                          : AppFont.w400,
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

class _PublishModeSegment extends StatelessWidget {
  const _PublishModeSegment({required this.value, required this.onChanged});

  final _PublishMode value;
  final ValueChanged<_PublishMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (final m in _PublishMode.values) ...[
          Expanded(
            child: InkWell(
              onTap: () => onChanged(m),
              borderRadius: BorderRadius.circular(ui(10)),
              child: Container(
                height: ui(44),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: value == m
                      ? _kPurple.withValues(alpha: 0.10)
                      : _kInnerGray,
                  borderRadius: BorderRadius.circular(ui(10)),
                  border: value == m
                      ? Border.all(color: _kPurple, width: 1)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  m.label,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: value == m ? _kPurple : _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: value == m ? AppFont.w600 : AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (m != _PublishMode.values.last) SizedBox(width: ui(8)),
        ],
      ],
    );
  }
}

class _ScheduledPickerField extends StatelessWidget {
  const _ScheduledPickerField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(10)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: _kInnerGray, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded, size: ui(16), color: _kPurple),
            SizedBox(width: ui(8)),
            Expanded(
              child: Text(
                hasValue ? _formatDateTime(value!) : '请选择定时发布时间',
                style: TextStyle(
                  fontSize: ui(14),
                  color: hasValue ? _kTextDark : _kTextHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 22 / 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: ui(18), color: _kTextHint),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
          ),
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(15),
              color: Colors.white,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: ui(15),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 时间格式化工具
// =============================================================================

String _formatDateTime(DateTime d) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${pad(d.month)}-${pad(d.day)} '
      '${pad(d.hour)}:${pad(d.minute)}';
}
