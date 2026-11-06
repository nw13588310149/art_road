// =============================================================================
// 学生端「查寝管理」独立页面
//
// 入口：学生 dashboard 快捷区「查寝管理」按钮 → controller.openDormCheck()
//      → mainView == dormCheck + role == student → SmartCampusPage 路由到
//      本视图。返回：banner 左上角返回按钮 → onBack。
//
// 视觉（Figma 970 设计宽）：
//   1. 顶部 banner（62 高）：左→右白→#F9EEFF 渐变，左 32 返回 + 中
//      "查寝管理" 16/600 + 副标题（仅展示本人「<姓名>」的查寝记录;补卡需
//      宿管/班主任审核），其中名字段用紫色 #8741FF 高亮。
//   2. 4 张统计卡（距标题栏 16；一行平铺，gap 12，100 高）：
//      A. 「宿舍床位」内容与数字区底对齐
//      …
//   3. 标题栏右侧缩小版「查寝记录 / 补卡申请」切换；列表区距统计卡 20：
//      "我的查寝记录" 18/500 + 右侧白底 全部/异常 双 tab，距下方卡片 20。
//   4. 卡片网格（3 列，每张 312 宽，padding 12，白底 + 浅灰描边）：
//      - 头部：场次（晚查寝/晨查寝） 18/600 + 状态徽章
//        正常 #A773FF / 未打卡 #FF323C / 迟到 #325BFF。
//      - 副标题：宿舍 + 日期。
//      - 内嵌灰底 50 高小方块：规定时间 / 打卡时间（迟到时打卡时间用
//        #FF323C 高亮）。
//      - 备注：灰小字。
//   5. 顶部右上角浮按钮「申请补卡」12/600 + 紫色多日历图标 → 弹出
//      `GradientHeaderDialog` 表单（日期 / 补卡说明 + 取消/确认；场次默认晚打卡）。
//
// 颜色 / 字体：
//   主紫 #8741FF / Banner 渐变 white → #F9EEFF / 卡片白底；
//   字体 PingFang SC，数字 32 用 Barlow（与 Figma 一致）。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
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
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// —— 颜色 ————————————————————————————————————————————————————————
const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSection = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kPurpleStatus = Color(0xFFA773FF);
const Color _kRed = Color(0xFFFF323C);
const Color _kBlue = Color(0xFF325BFF);

/// 标题栏与统计块、统计块与补卡列表之间的统一间距（与 [SmartCampusSecondaryPageShell.headerGap] 一致）。
const double _kStatsBlockGap = 16;

/// 标题栏右侧「申请补卡 / 查寝记录·补卡申请」控件统一高度。
const double _kBannerControlHeight = 32;

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
      barrierColor: Colors.black.withValues(alpha: 0.8),
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
    final cancelling = ref.read(studentDormitoryControllerProvider).cancellingMakeupId == item.id;
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
      header: _DormBanner(
        onBack: widget.onBack,
        studentName: displayName,
        onApplyResubmit: state.submittingMakeup ? null : _openApplyDialog,
        section: state.listSection,
        onSection: (section) => ref
            .read(studentDormitoryControllerProvider.notifier)
            .selectListSection(section),
      ),
      body: PageInitLoadingShell(
        loading: state.loading &&
            ((state.listSection ==
                        StudentDormitoryListSection.checkRecords &&
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

class _DormBanner extends StatelessWidget {
  const _DormBanner({
    required this.onBack,
    required this.studentName,
    required this.onApplyResubmit,
    required this.section,
    required this.onSection,
  });

  final VoidCallback onBack;
  final String studentName;
  final VoidCallback? onApplyResubmit;
  final StudentDormitoryListSection section;
  final ValueChanged<StudentDormitoryListSection> onSection;

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
            child: _BackButton(onTap: onBack),
          ),
          Positioned(
            right: ui(12),
            top: ui(15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ApplyResubmitButton(onTap: onApplyResubmit),
                SizedBox(width: ui(8)),
                _MainSectionHeader(
                  section: section,
                  onSection: onSection,
                ),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(56)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '查寝管理',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ui(16),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  RichText(
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: ui(12),
                        color: _kTextHint,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.1,
                      ),
                      children: [
                        const TextSpan(text: '仅展示本人'),
                        TextSpan(
                          text: '「$studentName」',
                          style: const TextStyle(color: _kPurple),
                        ),
                        const TextSpan(text: '的查寝记录;补卡需宿管/班主任审核。'),
                      ],
                    ),
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
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
    );
  }
}

class _ApplyResubmitButton extends StatelessWidget {
  const _ApplyResubmitButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: Container(
        height: ui(_kBannerControlHeight),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: _kBorderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.dormCheckApplyMakeupIcon,
              width: ui(16),
              height: ui(16),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(6)),
            Text(
              '申请补卡',
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
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
              label: '异常（未打/晚归）',
              value: abnormal,
            ),
          ),
          SizedBox(width: ui(12)),
          Expanded(
            child: SmartCampusStatCard(
              backgroundAsset: AppAssets.dormCheckStatCard4,
              label: '补卡待审',
              value: pendingResubmits,
              valueSuffix: '共$pendingResubmits条申请',
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

class _MainSectionHeader extends StatelessWidget {
  const _MainSectionHeader({
    required this.section,
    required this.onSection,
  });

  final StudentDormitoryListSection section;
  final ValueChanged<StudentDormitoryListSection> onSection;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      constraints: BoxConstraints(minHeight: ui(_kBannerControlHeight)),
      padding: EdgeInsets.all(ui(2)),
      decoration: BoxDecoration(
        color: _kBoardBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MainSectionTabItem(
            label: '查寝记录',
            selected: section == StudentDormitoryListSection.checkRecords,
            onTap: () => onSection(StudentDormitoryListSection.checkRecords),
          ),
          _MainSectionTabItem(
            label: '补卡申请',
            selected: section == StudentDormitoryListSection.makeupApplications,
            onTap: () =>
                onSection(StudentDormitoryListSection.makeupApplications),
          ),
        ],
      ),
    );
  }
}

class _MainSectionTabItem extends StatelessWidget {
  const _MainSectionTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(7)),
        decoration: BoxDecoration(
          color: selected ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(12),
            color: selected ? Colors.white : _kTextHint,
            fontFamily: 'PingFang SC',
            fontWeight: selected ? AppFont.w500 : AppFont.w400,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

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
            fontSize: ui(18),
            color: _kTextSection,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Container(
          height: ui(44),
          padding: EdgeInsets.all(ui(4)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabPill(
                label: '全部',
                active: tab == _DormTab.all,
                onTap: () => onTab(_DormTab.all),
              ),
              SizedBox(width: ui(4)),
              _TabPill(
                label: '异常',
                active: tab == _DormTab.abnormal,
                onTap: () => onTab(_DormTab.abnormal),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kTextDark : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(14),
            color: active ? Colors.white : _kTextSecondary,
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
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: ui(40)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Text(
          '当前筛选下没有查寝记录',
          style: TextStyle(
            fontSize: ui(13),
            color: _kTextSecondary,
            fontFamily: 'PingFang SC',
          ),
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
                child: _DormCard(record: r, onTap: onTap == null ? null : () => onTap!(r)),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(16)),
      child: Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
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
                  fontSize: ui(18),
                  color: _kTextSection,
                  // Figma 在不同 cell 间混用了 Barlow / PingFang SC，这里
                  // 必须用 PingFang SC：Barlow 不含中文字形，
                  // CanvasKit 字体回退会触发 "table index is out of bounds"。
                  fontFamily: 'PingFang SC',
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
                    fontFamily: 'PingFang SC',
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
                  fontFamily: 'PingFang SC',
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
          SizedBox(height: ui(10)),
          Text(
            '备注：${record.note}',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
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
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: ui(48)),
        alignment: Alignment.center,
        child: Text(
          '暂无补卡申请',
          style: TextStyle(fontSize: ui(14), color: _kTextHint),
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
                child: _MakeupCard(
                  item: item,
                  onTap: () => onTap(item),
                ),
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
    final (Color bg, Color fg, String label) = switch (item.status) {
      0 => (const Color(0xFFFFF3E0), const Color(0xFFFF9800), '待审核'),
      1 => (const Color(0xFFE8F5E9), const Color(0xFF1CD097), '已通过'),
      2 => (const Color(0xFFFEE4E8), _kRed, '已驳回'),
      _ => (const Color(0xFFF5F6FA), _kTextSecondary, item.statusText.isEmpty ? '未知' : item.statusText),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(16)),
      child: Container(
        padding: EdgeInsets.all(ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(16)),
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
                      fontSize: ui(18),
                      color: _kTextSection,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 1.1,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(ui(4)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: ui(12), color: fg),
                  ),
                ),
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
    final ui = DashboardScaleScope.of(context).ui;
    final (Color bg, String label) = switch (status) {
      _DormStatus.normal => (_kPurpleStatus, '正常'),
      _DormStatus.missed => (_kRed, '未打卡'),
      _DormStatus.late => (_kBlue, '迟到'),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ui(12),
          color: Colors.white,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 15.24 / 12,
        ),
      ),
    );
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
            fontFamily: 'PingFang SC',
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
        fontFamily: 'PingFang SC',
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
          color: Colors.white,
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
                  color: isPlaceholder ? const Color(0xFFCECED1) : _kTextDark,
                  fontFamily: 'PingFang SC',
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
        color: Colors.white,
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
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          hintText: '请输入',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFCECED1),
            fontFamily: 'PingFang SC',
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
