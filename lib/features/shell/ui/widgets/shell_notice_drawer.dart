import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../navigation/shell_notice_routes.dart';
import '../../state/shell_state.dart';

/// 通知分类与正文：内容以「【学情】」这类前缀开头时取括号里的词，否则按 targetType。
({String kind, String body}) parseShellNotice(ShellNoticeItem item) {
  final match = RegExp(r'^【([^】]{1,6})】\s*').firstMatch(item.content);
  if (match != null) {
    return (kind: match.group(1)!, body: item.content.substring(match.end));
  }
  final kind = switch (item.targetType) {
    ShellNoticeTargetType.study => '学情',
    ShellNoticeTargetType.artwork => '作品',
    ShellNoticeTargetType.ebook => '书刊',
    ShellNoticeTargetType.campus => '校园',
    ShellNoticeTargetType.toolbox => '工具箱',
    _ => '通知',
  };
  return (kind: kind, body: item.content);
}

/// 通知时间到分钟：今天 / 昨天 HH:mm，更早为 MM-DD HH:mm（跨年带年份）。
String formatShellNoticeTime(String raw, DateTime now) {
  final time = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  if (time == null) {
    return raw;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = '${two(time.hour)}:${two(time.minute)}';
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(time.year, time.month, time.day))
      .inDays;
  if (days == 0) {
    return '今天 $clock';
  }
  if (days == 1) {
    return '昨天 $clock';
  }
  final date = '${two(time.month)}-${two(time.day)}';
  return time.year == now.year ? '$date $clock' : '${time.year}-$date $clock';
}

/// 顶栏铃铛打开的通知抽屉：学情、作品点评与系统消息（班级与学校通知在智慧校园）。
///
/// 未读消息带红点；点一条消息会关闭抽屉，标为已读并打开对应页面（[onOpen]）。
Future<void> showShellNoticeDrawer(
  BuildContext context, {
  required List<ShellNoticeItem> items,
  required int unreadCount,
  required Future<void> Function() onMarkAllRead,
  ValueChanged<ShellNoticeItem>? onOpen,
}) {
  const scope = '学情、作品点评与系统消息';
  return showAppDrawer<void>(
    context: context,
    builder: (drawerContext) => AppDrawer(
      title: '通知',
      subtitle: unreadCount > 0 ? '$unreadCount 条未读 · $scope' : scope,
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      actions: [
        if (unreadCount > 0)
          AppButton(
            label: '全部标为已读',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () async {
              Navigator.of(drawerContext).pop();
              await onMarkAllRead();
            },
          ),
      ],
      child: items.isEmpty
          ? const SizedBox(
              height: 420,
              child: AppEmptyState(
                icon: Icons.notifications_none_rounded,
                title: '暂无新通知',
                description: '成绩发布、作品点评和系统消息会出现在这里',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++)
                  _NoticeRow(
                    item: items[i],
                    divider: i < items.length - 1,
                    onTap: onOpen == null
                        ? null
                        : () {
                            Navigator.of(drawerContext).pop();
                            onOpen(items[i]);
                          },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s24,
                    AppSpace.s16,
                    AppSpace.s24,
                    0,
                  ),
                  child: Text(
                    '班级与学校通知请到「智慧校园」查看',
                    style: AppText.caption12,
                  ),
                ),
              ],
            ),
    ),
  );
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.item, required this.divider, this.onTap});

  final ShellNoticeItem item;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final notice = parseShellNotice(item);
    final linked = shellNoticeDestination(item) != null;
    final row = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s24,
        vertical: AppSpace.s16,
      ),
      decoration: divider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!item.read) ...[
                const AppBadge.dot(),
                const SizedBox(width: AppSpace.s8),
              ],
              AppTag(label: notice.kind),
              const Spacer(),
              Text(
                formatShellNoticeTime(item.createTime, DateTime.now()),
                style: AppText.caption12,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  notice.body,
                  style: item.read
                      ? AppText.body14.copyWith(color: AppColors.textSecondary)
                      : AppText.body14,
                ),
              ),
              if (linked && onTap != null) ...[
                const SizedBox(width: AppSpace.s8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textPlaceholder,
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (onTap == null) {
      return row;
    }
    return AppPressable(onTap: onTap, child: row);
  }
}
