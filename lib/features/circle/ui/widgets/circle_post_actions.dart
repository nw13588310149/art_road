import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_governance_state.dart';
import '../../state/circle_state.dart';

/// 动态「···」菜单里的操作。普通校圈：自己的动态可删除，别人的动态可举报
/// （管理员不举报，到「校圈治理」处理）；治理模式（[onGovernanceDelete] 非空）：
/// 任意动态都可删除，需写明原因。
class CirclePostMenuActions {
  const CirclePostMenuActions({
    required this.permissions,
    required this.controller,
    this.onGovernanceDelete,
  });

  final CirclePermissions permissions;
  final CircleController controller;
  final ValueChanged<CirclePost>? onGovernanceDelete;

  bool get governance => onGovernanceDelete != null;

  VoidCallback? deleteFor(BuildContext context, CirclePost post) {
    final governanceDelete = onGovernanceDelete;
    if (governanceDelete != null) return () => governanceDelete(post);
    if (!permissions.isOwnPost(post)) return null;
    return () => confirmDeleteOwnPost(context, controller, post);
  }

  VoidCallback? reportFor(BuildContext context, CirclePost post) {
    if (governance ||
        permissions.isAdmin ||
        permissions.currentUserId.isEmpty ||
        permissions.isOwnPost(post)) {
      return null;
    }
    return () => reportCirclePost(context, controller, post);
  }
}

/// 删除自己发布的动态。
Future<void> confirmDeleteOwnPost(
  BuildContext context,
  CircleController controller,
  CirclePost post,
) async {
  final ok = await showAppConfirm(
    context: context,
    title: '删除动态',
    message: '删除后这条动态和它的评论都不可恢复。',
    confirmLabel: '删除',
    danger: true,
  );
  if (!ok || !context.mounted) return;
  final message = await controller.deletePost(post.id);
  if (!context.mounted) return;
  if (message != null && message.isNotEmpty) {
    AppToast.showError(context, message);
  } else {
    AppToast.showSuccess(context, '动态已删除');
  }
}

/// 举报别人的动态：选原因（可补充说明）后提交给管理员。
Future<void> reportCirclePost(
  BuildContext context,
  CircleController controller,
  CirclePost post,
) async {
  final choice = await showCircleReasonDialog(
    context,
    title: '举报动态',
    message: '管理员核实后会处理，发布者看不到是谁举报的。',
    reasonLabel: '举报原因',
    confirmLabel: '提交举报',
  );
  if (choice == null || !context.mounted) return;
  final message = await controller.reportPost(
    post.id,
    reason: choice.reason,
    remark: choice.remark,
  );
  if (!context.mounted) return;
  if (message != null) {
    AppToast.showError(context, message.isEmpty ? '举报没有提交成功，请稍后重试' : message);
  } else {
    AppToast.showSuccess(context, '举报已提交，管理员核实后会处理');
  }
}

/// 治理删除：先选删除原因，再二次确认（危险），最后提交。
Future<void> runGovernanceDelete(
  BuildContext context, {
  required Future<String?> Function(String reason, String remark) submit,
}) async {
  final choice = await showCircleReasonDialog(
    context,
    title: '删除动态',
    message: '删除原因会记录在「已处理」，便于日后查看。',
    reasonLabel: '删除原因',
    confirmLabel: '下一步',
  );
  if (choice == null || !context.mounted) return;
  final ok = await showAppConfirm(
    context: context,
    title: '确定删除这条动态？',
    message: '删除原因：${choice.reason}。删除后作者和画室其他人都看不到这条动态，也不能恢复。',
    confirmLabel: '删除',
    danger: true,
  );
  if (!ok || !context.mounted) return;
  final message = await submit(choice.reason, choice.remark);
  if (!context.mounted || message == '') return;
  if (message != null) {
    AppToast.showError(context, message);
  } else {
    AppToast.showSuccess(context, '动态已删除，记录在「已处理」');
  }
}

/// 保留：举报不成立，动态继续展示。
Future<void> runGovernanceKeep(
  BuildContext context, {
  required Future<String?> Function() submit,
}) async {
  final ok = await showAppConfirm(
    context: context,
    title: '保留这条动态？',
    message: '举报将标记为不成立，动态继续在校圈展示。',
    confirmLabel: '保留',
  );
  if (!ok || !context.mounted) return;
  final message = await submit();
  if (!context.mounted || message == '') return;
  if (message != null) {
    AppToast.showError(context, message);
  } else {
    AppToast.showSuccess(context, '已保留，记录在「已处理」');
  }
}

/// 原因弹窗的结果。
class CircleReasonChoice {
  const CircleReasonChoice({required this.reason, required this.remark});

  final String reason;
  final String remark;
}

/// 选原因 + 补充说明（举报、治理删除共用）。原因必选；选「其他」时说明必填。
Future<CircleReasonChoice?> showCircleReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String reasonLabel,
  required String confirmLabel,
}) {
  return showAppDialog<CircleReasonChoice>(
    context: context,
    builder: (_) => _CircleReasonDialog(
      title: title,
      message: message,
      reasonLabel: reasonLabel,
      confirmLabel: confirmLabel,
    ),
  );
}

class _CircleReasonDialog extends StatefulWidget {
  const _CircleReasonDialog({
    required this.title,
    required this.message,
    required this.reasonLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String reasonLabel;
  final String confirmLabel;

  @override
  State<_CircleReasonDialog> createState() => _CircleReasonDialogState();
}

class _CircleReasonDialogState extends State<_CircleReasonDialog> {
  final _remark = TextEditingController();
  String? _reason;
  String? _reasonError;
  String? _remarkError;

  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  void _select(String reason) {
    setState(() {
      _reason = reason;
      _reasonError = null;
      if (reason != circleOtherReason) _remarkError = null;
    });
  }

  void _submit() {
    final reason = _reason;
    final remark = _remark.text.trim();
    if (reason == null) {
      setState(() => _reasonError = '请选择${widget.reasonLabel}');
      return;
    }
    if (reason == circleOtherReason && remark.isEmpty) {
      setState(() => _remarkError = '选择「其他」时请写明原因');
      return;
    }
    Navigator.of(
      context,
    ).pop(CircleReasonChoice(reason: reason, remark: remark));
  }

  @override
  Widget build(BuildContext context) {
    final other = _reason == circleOtherReason;
    final reasonError = _reasonError;
    return AppDialog(
      title: widget.title,
      message: widget.message,
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: widget.confirmLabel, onTap: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '* ',
                  style: AppText.body14.copyWith(color: AppColors.danger),
                ),
                TextSpan(text: widget.reasonLabel, style: AppText.body14),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final reason in circleReportReasons)
                AppChip(
                  label: reason,
                  selected: _reason == reason,
                  onTap: () => _select(reason),
                ),
            ],
          ),
          if (reasonError != null) ...[
            const SizedBox(height: AppSpace.s4),
            Text(
              reasonError,
              style: AppText.caption12.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          AppInputField(
            controller: _remark,
            label: '补充说明',
            required: other,
            hint: other ? '请写明具体原因' : '选填',
            errorText: _remarkError,
            maxLength: 200,
            multiline: true,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) {
              if (_remarkError != null) setState(() => _remarkError = null);
            },
          ),
        ],
      ),
    );
  }
}
