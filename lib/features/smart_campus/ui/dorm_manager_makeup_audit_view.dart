import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/dormitory_check_data.dart';
import '../state/dormitory_manager_controller.dart';
import 'widgets/dormitory_detail_dialog.dart';
import 'widgets/smart_campus_page_banner.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kRed = Color(0xFFFF323C);

class DormManagerMakeupAuditView extends ConsumerStatefulWidget {
  const DormManagerMakeupAuditView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<DormManagerMakeupAuditView> createState() =>
      _DormManagerMakeupAuditViewState();
}

class _DormManagerMakeupAuditViewState
    extends ConsumerState<DormManagerMakeupAuditView> {
  String? _buildingId;
  int? _status = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final controller = ref.read(dormitoryManagerControllerProvider.notifier);
      await Future.wait([controller.loadHome(), controller.loadMakeups()]);
    });
  }

  Future<void> _showMakeupDetail(DormitoryMakeupItem item) async {
    if (item.id.isEmpty) return;
    final fields = await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .loadMakeupDetail(item.id);
    if (!mounted) return;
    if (fields.isEmpty) {
      AppToast.show(context, '未获取到补卡详情');
      return;
    }
    await showDormitoryDetailDialog(
      context,
      title: '${item.studentName} · 补卡详情',
      fields: fields,
    );
  }

  Future<void> _audit(DormitoryMakeupItem item, {required bool approve}) async {
    var auditReason = '';
    if (!approve) {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => _RejectReasonDialog(studentName: item.studentName),
      );
      if (!mounted || reason == null) return;
      auditReason = reason;
    }
    final response = await ref
        .read(dormitoryManagerControllerProvider.notifier)
        .auditMakeup(id: item.id, approve: approve, auditReason: auditReason);
    if (!mounted) return;
    AppToast.show(
      context,
      response.isSuccess
          ? (approve
                ? '已通过 ${item.studentName} 的补卡申请'
                : '已驳回 ${item.studentName} 的补卡申请')
          : response.displayMsg,
    );
  }

  Future<void> _reload() {
    return ref
        .read(dormitoryManagerControllerProvider.notifier)
        .loadMakeups(buildingId: _buildingId, status: _status);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = ref.watch(dormitoryManagerControllerProvider);
    return Container(
      color: _kPageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: ui(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(onBack: widget.onBack),
            SizedBox(height: ui(16)),
            _MakeupFilters(
              buildings: state.managedBuildings,
              buildingId: _buildingId,
              status: _status,
              onBuildingChanged: (value) {
                setState(() => _buildingId = value);
                unawaited(_reload());
              },
              onStatusChanged: (value) {
                setState(() => _status = value);
                unawaited(_reload());
              },
            ),
            if (state.error.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(ui(12)),
                child: Text(state.error, style: TextStyle(color: _kRed)),
              )
            else if (state.makeupItems.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: ui(48)),
                child: Center(
                  child: Text(
                    _status == 0 ? '暂无待审补卡申请' : '暂无符合条件的补卡申请',
                    style: TextStyle(fontSize: ui(14), color: _kTextHint),
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(top: ui(16)),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gap = ui(16);
                    var columns = 3;
                    if (constraints.maxWidth < ui(720)) columns = 2;
                    if (constraints.maxWidth < ui(480)) columns = 1;
                    final cardWidth =
                        (constraints.maxWidth - gap * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final item in state.makeupItems)
                          SizedBox(
                            width: cardWidth,
                            child: _MakeupCard(
                              item: item,
                              submitting: state.submittingMakeupIds.contains(
                                item.id,
                              ),
                              onDetail: () => unawaited(_showMakeupDetail(item)),
                              onApprove: () =>
                                  unawaited(_audit(item, approve: true)),
                              onReject: () =>
                                  unawaited(_audit(item, approve: false)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MakeupFilters extends StatelessWidget {
  const _MakeupFilters({
    required this.buildings,
    required this.buildingId,
    required this.status,
    required this.onBuildingChanged,
    required this.onStatusChanged,
  });

  final List<DormitoryBuildingOption> buildings;
  final String? buildingId;
  final int? status;
  final ValueChanged<String?> onBuildingChanged;
  final ValueChanged<int?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const statuses = <(int?, String)>[
      (0, '待审批'),
      (1, '已通过'),
      (2, '已拒绝'),
      (3, '已撤销'),
      (null, '全部'),
    ];
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: ui(220),
            child: DropdownButtonFormField<String?>(
              initialValue: buildingId,
              decoration: const InputDecoration(
                labelText: '宿舍楼',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('全部宿舍楼'),
                ),
                for (final building in buildings)
                  if (building.id.isNotEmpty)
                    DropdownMenuItem<String?>(
                      value: building.id,
                      child: Text(
                        '${building.label} · ${building.assignedBedCount}人',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
              onChanged: onBuildingChanged,
            ),
          ),
          SizedBox(width: ui(16)),
          Expanded(
            child: Wrap(
              spacing: ui(8),
              children: [
                for (final entry in statuses)
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: status == entry.$1,
                    onSelected: (_) => onStatusChanged(entry.$1),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(62),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: smartCampusPageBannerDecoration(ui),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
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
              child: Icon(Icons.chevron_left_rounded, size: ui(20)),
            ),
          ),
          Expanded(
            child: Text(
              '补卡审核',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui(16),
                fontWeight: AppFont.w600,
                color: _kTextDark,
              ),
            ),
          ),
          SizedBox(width: ui(32)),
        ],
      ),
    );
  }
}

class _MakeupCard extends StatelessWidget {
  const _MakeupCard({
    required this.item,
    required this.submitting,
    required this.onDetail,
    required this.onApprove,
    required this.onReject,
  });

  final DormitoryMakeupItem item;
  final bool submitting;
  final VoidCallback onDetail;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAF0FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(ui(16)),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.studentName,
            style: TextStyle(
              fontSize: ui(16),
              fontWeight: AppFont.w600,
              color: _kTextDark,
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            item.statusText.isEmpty
                ? _makeupStatusText(item.status)
                : item.statusText,
            style: TextStyle(
              fontSize: ui(12),
              color: item.status == 0 ? _kPurple : _kTextSecondary,
              fontWeight: AppFont.w500,
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            '${item.dormName.isEmpty ? '宿舍' : item.dormName} · ${item.checkDate}',
            style: TextStyle(fontSize: ui(12), color: _kTextSecondary),
          ),
          SizedBox(height: ui(8)),
          Text(
            '${item.checkType} · ${item.reason}',
            style: TextStyle(fontSize: ui(12), color: _kTextHint),
          ),
          SizedBox(height: ui(12)),
          if (item.createTime.isNotEmpty)
            Text(
              '申请时间：${item.createTime}',
              style: TextStyle(fontSize: ui(11), color: _kTextHint),
            ),
          if (item.createTime.isNotEmpty) SizedBox(height: ui(8)),
          Row(
            children: [
              TextButton(
                onPressed: onDetail,
                child: Text('详情', style: TextStyle(color: _kPurple)),
              ),
              const Spacer(),
              if (item.status == 0) ...[
                SizedBox(
                  width: ui(72),
                  child: OutlinedButton(
                    onPressed: submitting ? null : onReject,
                    child: Text(
                      '驳回',
                      style: TextStyle(color: _kRed, fontSize: ui(12)),
                    ),
                  ),
                ),
                SizedBox(width: ui(8)),
                SizedBox(
                  width: ui(72),
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _kPurple),
                    onPressed: submitting ? null : onApprove,
                    child: Text('通过', style: TextStyle(fontSize: ui(12))),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _makeupStatusText(int status) {
  return switch (status) {
    0 => '待审批',
    1 => '已通过',
    2 => '已拒绝',
    3 => '已撤销',
    _ => '未知状态',
  };
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog({required this.studentName});

  final String studentName;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = '请填写驳回原因');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('驳回 ${widget.studentName} 的补卡申请'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: '填写驳回原因',
          errorText: _error.isEmpty ? null : _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确认驳回')),
      ],
    );
  }
}
