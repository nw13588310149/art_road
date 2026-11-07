// =============================================================================
// 学生端「我的查寝」独立页面
//
// 入口：学生 dashboard 快捷区「我的查寝」按钮 → controller.openDormCheck()
//      → mainView == dormCheck + role == student → SmartCampusPage 路由到
//      本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：左→右白→#F9EEFF 渐变，左 32 返回 + 中
//      "查寝管理" 16/600 + 副标题（仅展示本人「<姓名>」的查寝记录;补卡需
//      宿管/班主任审核），其中名字段用紫色 #715EFE 高亮。
//   2. 4 张统计卡（距标题栏 16；一行平铺，gap 12，100 高）：
//      A. 「宿舍床位」内容与数字区底对齐
//      …
//   3. 标题栏右侧缩小版「查寝记录 / 补卡申请」切换；列表区距统计卡 20：
//      "我的查寝记录" 18/500 + 右侧白底 全部/异常 双 tab，距下方卡片 20。
//   4. 卡片网格（3 列，每张 312 宽，padding 12，白底 + 浅灰描边）：
//      - 头部：场次（晚查寝/晨查寝） 18/600 + 状态徽章
//        正常 #8E7FFF / 未打卡 #FF323C / 迟到 #325BFF。
//      - 副标题：宿舍 + 日期。
//      - 内嵌灰底 50 高小方块：规定时间 / 打卡时间（迟到时打卡时间用
//        #FF323C 高亮）。
//      - 备注：灰小字。
//   5. 顶部右上角浮按钮「申请补卡」12/600 + 紫色多日历图标 → 弹出
//      `GradientHeaderDialog` 表单（日期 / 补卡说明 + 取消/确认；场次默认晚打卡）。
//
// 颜色 / 字体：
//   主紫 #715EFE / Banner 渐变 white → #F9EEFF / 卡片白底；
//   字体 PingFang SC，数字 32 用 Barlow（与 Figma 一致）。
// =============================================================================

import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import 'widgets/smart_campus_stat_card.dart';
import '../data/student_dormitory_data.dart';
import '../data/dormitory_check_data.dart';
import '../state/student_dormitory_controller.dart';
import '../state/student_dormitory_state.dart';
import '../../school/data/school_config_data.dart';
import '../../school/state/school_config_controller.dart';
import 'widgets/dormitory_detail_dialog.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = AppColors.page;
const Color _kBoardBg = AppColors.surfaceSubtle;
const Color _kBorderSoft = AppColors.lineSoft;
const Color _kTextDark = AppColors.ink;
const Color _kTextSection = AppColors.ink;
const Color _kTextSecondary = AppColors.textSecondary;
const Color _kTextHint = AppColors.textPlaceholder;
const Color _kPurple = AppColors.brand;
const Color _kRed = AppColors.danger;

/// 标题栏与统计块、统计块与补卡列表之间的统一间距（与 [SmartCampusSecondaryPageShell.headerGap] 一致）。
const double _kStatsBlockGap = 16;

/// 标题栏右侧「申请补卡 / 查寝记录·补卡申请」控件统一高度。

// —— 顶级视图 ——————————————————————————————————————————————————————

class StudentDormCheckView extends ConsumerStatefulWidget {
  const StudentDormCheckView({
    super.key,
    required this.onBack,
    this.studentName = '',
  });

  final VoidCallback onBack;
  final String studentName;

  @override
  ConsumerState<StudentDormCheckView> createState() =>
      _StudentDormCheckViewState();
}

class _StudentDormCheckViewState extends ConsumerState<StudentDormCheckView> {
  _DormTab _tab = _DormTab.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(studentDormitoryControllerProvider.notifier).initialize(),
    );
  }

  List<_DormCheckRecord> _recordsFromState(
    List<StudentDormitoryCheckItem> items,
    SchoolDormitoryCheckConfig checkConfig,
  ) {
    return [
      for (final item in items)
        _DormCheckRecord(
          id: item.id,
          session: item.checkType,
          status: _mapStatus(item.status),
          dorm: item.dormName.isEmpty ? '—' : item.dormName,
          date: item.checkDate,
          requiredTime: resolveDormitoryRequiredDeadline(
            recordDeadline: item.deadline,
            checkType: item.checkType,
            config: checkConfig,
          ),
          stampedTime: item.checkTime == '—' ? null : item.checkTime,
          note: item.remark,
        ),
    ];
  }

  _DormStatus _mapStatus(StudentDormitoryCheckStatus status) {
    return switch (status) {
      StudentDormitoryCheckStatus.normal => _DormStatus.normal,
      StudentDormitoryCheckStatus.late => _DormStatus.late,
      StudentDormitoryCheckStatus.absent => _DormStatus.missed,
    };
  }

  Future<void> _openApplyDialog() async {
    final result = await showScaledDialog<_DormResubmitFormResult>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.8),
      builder: (ctx) => const _DormResubmitDialog(),
    );
    if (!mounted || result == null) return;
    final response = await ref
        .read(studentDormitoryControllerProvider.notifier)
        .submitMakeup(
          date: result.date,
          sceneLabel: _DormResubmitFormResult.defaultScene,
          reason: result.note,
        );
    if (!mounted) return;
    if (response.isSuccess) {
      AppToast.show(
        context,
        '已提交补卡申请：${result.dateLabel} · ${_DormResubmitFormResult.defaultScene}',
      );
    } else {
      AppToast.show(context, response.displayMsg);
    }
  }

  List<_DormCheckRecord> _visibleRecords(List<_DormCheckRecord> records) {
    switch (_tab) {
      case _DormTab.all:
        return records;
      case _DormTab.abnormal:
        return records
            .where(
              (r) =>
                  r.status == _DormStatus.missed ||
                  r.status == _DormStatus.late,
            )
            .toList();
    }
  }

  Future<void> _showCheckDetail(String id, String title) async {
    if (id.isEmpty) return;
    final fields = await ref
        .read(studentDormitoryControllerProvider.notifier)
        .loadCheckDetail(id);
    if (!mounted) return;
    if (fields.isEmpty) {
      AppToast.show(context, '未获取到查寝详情');
      return;
    }
    final checkConfig =
        ref.read(schoolDormitoryCheckConfigProvider).valueOrNull ??
        SchoolDormitoryCheckConfig.empty;
    final record = ref
        .read(studentDormitoryControllerProvider)
        .records
        .where((item) => item.id == id)
        .firstOrNull;
    final enrichedFields = enrichDormitoryDetailRequiredTime(
      fields: fields,
      checkType: record?.checkType ?? '晚查寝',
      recordDeadline: record?.deadline ?? '',
      config: checkConfig,
    );
    await showDormitoryDetailDialog(
      context,
      title: title,
      fields: enrichedFields,
    );
  }

  Future<void> _showMakeupDetail(StudentDormitoryMakeupItem item) async {
    final fields = await ref
        .read(studentDormitoryControllerProvider.notifier)
        .loadMakeupDetail(item.id);
    if (!mounted) return;
    if (fields.isEmpty) {
      AppToast.show(context, '未获取到补卡详情');
      return;
    }
    final cancelling =
        ref.read(studentDormitoryControllerProvider).cancellingMakeupId ==
        item.id;
    await showDormitoryDetailDialog(
      context,
      title: '补卡申请 · ${item.checkType}',
      fields: fields,
      actions: item.canCancel
          ? [
              OutlinedButton(
                onPressed: cancelling
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        final response = await ref
                            .read(studentDormitoryControllerProvider.notifier)
                            .cancelMakeup(item.id);
                        if (!mounted) return;
                        AppToast.show(
                          context,
                          response.isSuccess ? '已撤销补卡申请' : response.displayMsg,
                        );
                      },
                child: Text('撤销申请', style: TextStyle(color: _kRed)),
              ),
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = ref.watch(studentDormitoryControllerProvider);
    final checkConfig =
        ref.watch(schoolDormitoryCheckConfigProvider).valueOrNull ??
        SchoolDormitoryCheckConfig.empty;
    final records = _recordsFromState(state.records, checkConfig);
    final visible = _visibleRecords(records);
    final dormLabel = state.dormInfo.displayLabel;
    final normalCount = state.stat.normalCount;
    final abnormalCount = state.stat.lateCount + state.stat.absentCount;
    final pendingMakeups = state.pendingMakeupCount > 0
        ? state.pendingMakeupCount
        : state.stat.pendingMakeupCount;
    final displayName = widget.studentName.isEmpty ? '我' : widget.studentName;
    return SmartCampusSecondaryPageShell(
      backgroundColor: _kPageBg,
      bodyTopClipRadius: 8,
      headerGap: _kStatsBlockGap,
      header: AppPageHeader(
        centerTitle: true,
        title: '我的查寝',
        subtitle: '只显示$displayName的查寝记录；漏打卡可申请补卡，由宿管或班主任审核',
        onBack: widget.onBack,
        actions: [
          AppButton(
            label: '申请补卡',
            icon: Icons.event_available_outlined,
            size: AppButtonSize.sm,
            onTap: state.submittingMakeup ? null : _openApplyDialog,
          ),
        ],
        bottom: AppTabs<StudentDormitoryListSection>(
          tabs: [
            const AppTab(
              value: StudentDormitoryListSection.checkRecords,
              label: '查寝记录',
            ),
            AppTab(
              value: StudentDormitoryListSection.makeupApplications,
              label: '补卡申请',
              count: state.makeupItems.isEmpty
                  ? null
                  : state.makeupItems.length,
            ),
          ],
          value: state.listSection,
          onChanged: (section) => ref
              .read(studentDormitoryControllerProvider.notifier)
              .selectListSection(section),
        ),
      ),
      body: PageInitLoadingShell(
        loading:
            state.loading &&
            ((state.listSection == StudentDormitoryListSection.checkRecords &&
                    records.isEmpty) ||
                (state.listSection !=
                        StudentDormitoryListSection.checkRecords &&
                    state.makeupItems.isEmpty)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.error.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: ui(8)),
                child: Text(
                  state.error,
                  style: TextStyle(fontSize: ui(12), color: _kRed),
                ),
              ),
            _DormStatsRow(
              dorm: dormLabel,
              normal: normalCount,
              abnormal: abnormalCount,
              pendingResubmits: pendingMakeups,
            ),
            if (state.loading &&
                ((state.listSection ==
                            StudentDormitoryListSection.checkRecords &&
                        records.isEmpty) ||
                    (state.listSection !=
                            StudentDormitoryListSection.checkRecords &&
                        state.makeupItems.isEmpty)))
              const SizedBox.shrink()
            else if (state.listSection ==
                StudentDormitoryListSection.checkRecords) ...[
              SizedBox(height: ui(8)),
              _SectionHeader(tab: _tab, onTab: (t) => setState(() => _tab = t)),
              SizedBox(height: ui(8)),
              _DormCardsGrid(
                records: visible,
                onTap: (record) => unawaited(
                  _showCheckDetail(record.id, '${record.session} · 查寝详情'),
                ),
              ),
            ] else ...[
              SizedBox(height: ui(_kStatsBlockGap)),
              _MakeupCardsGrid(
                items: state.makeupItems,
                onTap: (item) => unawaited(_showMakeupDetail(item)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner：返回 + 标题 + 副标题 + 申请补卡按钮
// =============================================================================

// =============================================================================
// 4 张统计卡
// =============================================================================

class _DormStatsRow extends StatelessWidget {
  const _DormStatsRow({
    required this.dorm,
    required this.normal,
    required this.abnormal,
    required this.pendingResubmits,
  });

  final String dorm;
  final int normal;
  final int abnormal;
  final int pendingResubmits;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SmartCampusStatCard(
              backgroundAsset: AppAssets.dormCheckStatCard1,
              label: '宿舍床位',
              value: 0,
              valueLabel: dorm,
              valueIsText: true,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: SmartCampusStatCard(
              backgroundAsset: AppAssets.dormCheckStatCard2,
              label: '正常打卡',
              value: normal,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: SmartCampusStatCard(
              backgroundAsset: AppAssets.dormCheckStatCard3,
              label: '异常（未打卡 / 晚归）',
              value: abnormal,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: SmartCampusStatCard(
              backgroundAsset: AppAssets.dormCheckStatCard4,
              label: '补卡待审',
              value: pendingResubmits,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 章节头：我的查寝记录 + 全部 / 异常 tabs
// =============================================================================

enum _DormTab { all, abnormal }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.tab, required this.onTab});

  final _DormTab tab;
  final ValueChanged<_DormTab> onTab;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Text(
          '我的查寝记录',
          style: TextStyle(
            fontSize: ui(16),
            color: _kTextSection,
            fontWeight: AppFont.w500,
            height: 1.1,
          ),
        ),
        const Spacer(),
        AppSegmented<_DormTab>(
          size: AppControlSize.sm,
          segments: const [
            AppSegment(value: _DormTab.all, label: '全部'),
            AppSegment(value: _DormTab.abnormal, label: '异常'),
          ],
          value: tab,
          onChanged: onTab,
        ),
      ],
    );
  }
}

// =============================================================================
// 卡片网格 + 单张卡片
// =============================================================================

class _DormCardsGrid extends StatelessWidget {
  const _DormCardsGrid({required this.records, this.onTap});

  final List<_DormCheckRecord> records;
  final ValueChanged<_DormCheckRecord>? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (records.isEmpty) {
      return const AppCard(
        child: AppEmptyState(
          icon: Icons.bedtime_outlined,
          title: '没有符合条件的查寝记录',
          description: '宿管查寝后，结果会出现在这里',
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final gap = ui(16);
        final cols = c.maxWidth >= ui(960)
            ? 3
            : c.maxWidth >= ui(640)
            ? 2
            : 1;
        final cardWidth = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in records)
              SizedBox(
                width: cardWidth,
                child: _DormCard(
                  record: r,
                  onTap: onTap == null ? null : () => onTap!(r),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DormCard extends StatelessWidget {
  const _DormCard({required this.record, this.onTap});

  final _DormCheckRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final note = record.note.trim();
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(ui(12)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br12,
          border: Border.all(color: _kBorderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  record.session,
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextSection,
                    // Figma 在不同 cell 间混用了 Barlow / PingFang SC，这里
                    // 必须用 PingFang SC：Barlow 不含中文字形，
                    // CanvasKit 字体回退会触发 "table index is out of bounds"。
                    fontWeight: AppFont.w600,
                    height: 1.1,
                  ),
                ),
                const Spacer(),
                _StatusBadge(status: record.status),
              ],
            ),
            SizedBox(height: ui(4)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.dorm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextSecondary,
                      fontWeight: AppFont.w400,
                      height: 20 / 13,
                    ),
                  ),
                ),
                Text(
                  record.date,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontWeight: AppFont.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: ui(12)),
            _TimePanel(
              requiredTime: record.requiredTime,
              stampedTime: record.stampedTime,
              stampedHighlight: record.status == _DormStatus.late,
            ),
            if (note.isNotEmpty && note != '无') ...[
              SizedBox(height: ui(10)),
              Text(
                '备注：$note',
                style: AppText.caption12.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MakeupCardsGrid extends StatelessWidget {
  const _MakeupCardsGrid({required this.items, required this.onTap});

  final List<StudentDormitoryMakeupItem> items;
  final ValueChanged<StudentDormitoryMakeupItem> onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (items.isEmpty) {
      return const AppCard(
        child: AppEmptyState(
          icon: Icons.event_available_outlined,
          title: '还没有补卡申请',
          description: '漏打卡时点右上角「申请补卡」',
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final gap = ui(16);
        final cols = c.maxWidth >= ui(960)
            ? 3
            : c.maxWidth >= ui(640)
            ? 2
            : 1;
        final cardWidth = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: cardWidth,
                child: _MakeupCard(item: item, onTap: () => onTap(item)),
              ),
          ],
        );
      },
    );
  }
}

class _MakeupCard extends StatelessWidget {
  const _MakeupCard({required this.item, required this.onTap});

  final StudentDormitoryMakeupItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final status = switch (item.status) {
      0 => const AppStatusTag(label: '待审核', tone: AppTone.warning),
      1 => const AppStatusTag(label: '已通过', tone: AppTone.success),
      2 => const AppStatusTag(label: '已驳回', tone: AppTone.danger),
      _ => AppStatusTag(
        label: item.statusText.isEmpty ? '处理中' : item.statusText,
      ),
    };
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(ui(12)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br12,
          border: Border.all(color: _kBorderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.checkType,
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextSection,
                      fontWeight: AppFont.w600,
                      height: 1.1,
                    ),
                  ),
                ),
                status,
              ],
            ),
            SizedBox(height: ui(4)),
            Text(
              item.checkDate,
              style: TextStyle(fontSize: ui(12), color: _kTextHint),
            ),
            SizedBox(height: ui(10)),
            Text(
              item.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: ui(12), color: _kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _DormStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      _DormStatus.normal => const AppTag(label: '正常', tone: AppTone.success),
      _DormStatus.missed => const AppTag(label: '未打卡', tone: AppTone.danger),
      _DormStatus.late => const AppTag(label: '迟到', tone: AppTone.warning),
    };
  }
}

class _TimePanel extends StatelessWidget {
  const _TimePanel({
    required this.requiredTime,
    required this.stampedTime,
    required this.stampedHighlight,
  });

  final String requiredTime;
  final String? stampedTime;
  final bool stampedHighlight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // Figma 的 50 高对应 11+12+5+12+11=51（因为 Text 含 leading），
    // 这里改成自适应内容高度并保留 padding，避免 1px overflow。
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kBoardBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: ui(10)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _TimeCell(label: '规定时间', value: requiredTime),
              ),
              Expanded(
                child: _TimeCell(
                  label: '打卡时间',
                  value: stampedTime ?? '—',
                  valueColor: stampedHighlight ? _kRed : _kTextDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.value,
    this.valueColor = _kTextDark,
  });

  final String label;
  final String value;
  final Color valueColor;

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
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
        SizedBox(height: ui(5)),
        Text(
          value,
          style: TextStyle(
            fontSize: ui(12),
            color: valueColor,
            fontWeight: AppFont.w400,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 申请查寝补卡 dialog
// =============================================================================

class _DormResubmitFormResult {
  const _DormResubmitFormResult({
    required this.date,
    required this.dateLabel,
    required this.note,
  });

  static const defaultScene = '晚打卡';

  final DateTime date;
  final String dateLabel;
  final String note;
}

class _DormResubmitDialog extends StatefulWidget {
  const _DormResubmitDialog();

  @override
  State<_DormResubmitDialog> createState() => _DormResubmitDialogState();
}

class _DormResubmitDialogState extends State<_DormResubmitDialog> {
  DateTime? _date;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _canConfirm => _date != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确认',
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  String _dateText() {
    final d = _date;
    if (d == null) return '年/月/日';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}/$mm/$dd';
  }

  void _submit() {
    if (!_canConfirm || _date == null) return;
    Navigator.of(context).pop(
      _DormResubmitFormResult(
        date: _date!,
        dateLabel: _dateText(),
        note: _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GradientHeaderDialog(
      title: '申请查寝补卡',
      titlePaddingTop: 39,
      width: 428,
      actionBar: AppDialogActionBar(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmEnabled: _canConfirm,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _FieldLabel('日期'),
            SizedBox(height: ui(10)),
            _DatePickerField(text: _dateText(), onTap: _pickDate),
            SizedBox(height: ui(15)),
            _FieldLabel('补卡说明'),
            SizedBox(height: ui(10)),
            _NoteField(controller: _noteCtrl),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        fontSize: ui(14),
        color: _kTextDark,
        fontWeight: AppFont.w500,
        height: 20 / 14,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isPlaceholder = text == '年/月/日';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(48),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: ui(14),
                  color: isPlaceholder ? AppColors.textTertiary : _kTextDark,
                  fontWeight: AppFont.w400,
                  height: 20 / 14,
                ),
              ),
            ),
            AppPickerAssetIcon(
              AppAssets.iconScheduleCalendar,
              imageSize: ui(18),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(80),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: AppTextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: _kPurple,
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: _kTextDark,
          fontWeight: AppFont.w400,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          hintText: '请输入',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: AppColors.textTertiary,
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: ui(16),
            vertical: ui(12),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// =============================================================================
// 数据模型
// =============================================================================

enum _DormStatus { normal, missed, late }

class _DormCheckRecord {
  const _DormCheckRecord({
    required this.id,
    required this.session,
    required this.status,
    required this.dorm,
    required this.date,
    required this.requiredTime,
    required this.stampedTime,
    required this.note,
  });

  final String id;
  final String session;
  final _DormStatus status;
  final String dorm;
  final String date;
  final String requiredTime;
  final String? stampedTime;
  final String note;
}
