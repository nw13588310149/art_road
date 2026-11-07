import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../state/shell_state.dart';

/// 通知分类与正文：内容以「【学情】」这类前缀开头时取括号里的词，否则按 targetType。
({String kind, String body}) parseShellNotice(ShellNoticeItem item) {
  final match = RegExp(r'^【([^】]{1,6})】\s*').firstMatch(item.content);
  if (match != null) {
    return (kind: match.group(1)!, body: item.content.substring(match.end));
  }
  final kind = switch (item.targetType) {
    1 => '学情',
    2 => '作品',
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
Future<void> showShellNoticeDrawer(
  BuildContext context, {
  required List<ShellNoticeItem> items,
  required int unreadCount,
  required Future<void> Function() onMarkAllRead,
}) {
  const scope = '学情、作品点评与系统消息';
  return showAppDrawer<void>(
    context: context,
    builder: (drawerContext) => AppDrawer(
      title: '通知',
      subtitle: unreadCount > 0 ? '$unreadCount 条未读 · $scope' : scope,
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      actions: [
        if (items.isNotEmpty)
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
                  _NoticeRow(item: items[i], divider: i < items.length - 1),
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
  const _NoticeRow({required this.item, required this.divider});

  final ShellNoticeItem item;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final notice = parseShellNotice(item);
    return Container(
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
              AppTag(label: notice.kind),
              const Spacer(),
              Text(
                formatShellNoticeTime(item.createTime, DateTime.now()),
                style: AppText.caption12,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(notice.body, style: AppText.body14),
        ],
      ),
    );
  }
}
