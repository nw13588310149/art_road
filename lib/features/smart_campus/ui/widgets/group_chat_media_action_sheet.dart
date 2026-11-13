import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../core/theme/app_font.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../services/group_chat_media_saver.dart';

const Color _kTextDark = Color(0xFF0B081A);
const Color _kDestructive = Color(0xFFFF323C);

class GroupChatMessageAction {
  const GroupChatMessageAction({
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final Future<void> Function() onSelected;
  final bool destructive;
}

Future<void> showGroupChatMessageActionSheet(
  BuildContext context, {
  required List<GroupChatMediaDownloadItem> downloadItems,
  List<GroupChatMessageAction> extraActions = const [],
}) async {
  if (downloadItems.isEmpty && extraActions.isEmpty) return;

  final scale = DashboardScaleScope.of(context);
  HapticFeedback.mediumImpact();

  Future<void> runDownload(GroupChatMediaDownloadItem item) async {
    final result = await saveGroupChatMediaItem(item);
    if (!context.mounted || result.cancelled) return;
    if (result.ok) {
      AppToast.show(context, '已保存');
      return;
    }
    AppToast.show(context, result.error ?? '保存失败');
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    isScrollControlled: true,
    builder: (sheetContext) {
      return DashboardScaleScope(
        data: scale,
        child: _GroupChatMessageActionSheet(
          downloadItems: downloadItems,
          extraActions: extraActions,
          onDownload: (item) async {
            Navigator.of(sheetContext).pop();
            await runDownload(item);
          },
          onExtraAction: (action) async {
            Navigator.of(sheetContext).pop();
            await action.onSelected();
          },
          onCancel: () => Navigator.of(sheetContext).pop(),
        ),
      );
    },
  );
}

class _GroupChatMessageActionSheet extends StatelessWidget {
  const _GroupChatMessageActionSheet({
    required this.downloadItems,
    required this.extraActions,
    required this.onDownload,
    required this.onExtraAction,
    required this.onCancel,
  });

  final List<GroupChatMediaDownloadItem> downloadItems;
  final List<GroupChatMessageAction> extraActions;
  final ValueChanged<GroupChatMediaDownloadItem> onDownload;
  final ValueChanged<GroupChatMessageAction> onExtraAction;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final actionRows = <Widget>[
      for (var i = 0; i < downloadItems.length; i++) ...[
        if (i > 0) const _SheetDivider(),
        _SheetItem(
          label: downloadItems[i].label,
          onTap: () => onDownload(downloadItems[i]),
        ),
      ],
      for (var i = 0; i < extraActions.length; i++) ...[
        if (downloadItems.isNotEmpty || i > 0) const _SheetDivider(),
        _SheetItem(
          label: extraActions[i].label,
          destructive: extraActions[i].destructive,
          onTap: () => onExtraAction(extraActions[i]),
        ),
      ],
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(ui(20), 0, ui(20), ui(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(377)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: ui(8)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actionRows,
                ),
              ),
            ),
            SizedBox(height: ui(8)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(377)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCancel,
                child: Container(
                  width: double.infinity,
                  height: ui(56),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ui(16)),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: _kTextDark,
                      fontSize: ui(20),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 24 / 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: ui(56),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: destructive ? _kDestructive : _kTextDark,
              fontSize: ui(20),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 24 / 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0x33000000));
  }
}
