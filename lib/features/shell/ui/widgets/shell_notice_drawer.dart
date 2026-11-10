import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/theme/app_font.dart';
import '../shell_layout.dart';
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
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(time.year, time.month, time.day)).inDays;
  if (days == 0) {
    return '今天 $clock';
  }
  if (days == 1) {
    return '昨天 $clock';
  }
  final date = '${two(time.month)}-${two(time.day)}';
  return time.year == now.year ? '$date $clock' : '${time.year}-$date $clock';
}

Future<void> showShellNoticeDrawer(
  BuildContext context, {
  required List<ShellNoticeItem> items,
  required int unreadCount,
  required Future<void> Function() onMarkAllRead,
  ValueChanged<ShellNoticeItem>? onOpen,
}) {
  final scale = DashboardScaleScope.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.20),
    barrierDismissible: true,
    barrierLabel: '关闭通知',
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        DashboardScaleScope(
          data: scale,
          child: _NoticeDrawer(
            items: items,
            onMarkAllRead: () async {
              Navigator.of(dialogContext).pop();
              await onMarkAllRead();
            },
            onClose: () => Navigator.of(dialogContext).pop(),
            onOpen: onOpen == null
                ? null
                : (item) {
                    Navigator.of(dialogContext).pop();
                    onOpen(item);
                  },
          ),
        ),
    transitionBuilder: (context, animation, secondary, child) =>
        SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
  );
}

class _NoticeDrawer extends StatelessWidget {
  const _NoticeDrawer({
    required this.items,
    required this.onMarkAllRead,
    required this.onClose,
    this.onOpen,
  });

  final ValueChanged<ShellNoticeItem>? onOpen;
  final List<ShellNoticeItem> items;
  final Future<void> Function() onMarkAllRead;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        elevation: 32,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: SizedBox(
          width: ui(420),
          height: double.infinity,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(ui(20), ui(20), ui(12), ui(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NoticeDrawerHeader(
                    count: items.length,
                    onMarkAllRead: items.isEmpty ? null : onMarkAllRead,
                    onClose: onClose,
                  ),
                  SizedBox(height: ui(16)),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF3F2F3),
                  ),
                  SizedBox(height: ui(12)),
                  Expanded(
                    child: items.isEmpty
                        ? const _NoticeEmpty()
                        : ListView.separated(
                            padding: EdgeInsets.only(right: ui(8)),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => SizedBox(height: ui(8)),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return AppPressable(
                                onTap: onOpen == null
                                    ? null
                                    : () => onOpen!(item),
                                child: _NoticeRow(item: item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeDrawerHeader extends StatelessWidget {
  const _NoticeDrawerHeader({
    required this.count,
    required this.onMarkAllRead,
    required this.onClose,
  });

  final int count;
  final Future<void> Function()? onMarkAllRead;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Container(
          width: ui(3.25),
          height: ui(14.85),
          decoration: BoxDecoration(
            color: const Color(0xFF715EFE),
            borderRadius: BorderRadius.circular(ui(6)),
          ),
        ),
        SizedBox(width: ui(6)),
        Text(
          '通知($count)',
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(16),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w600,
            height: 1.2,
          ),
        ),
        const Spacer(),
        if (onMarkAllRead != null)
          InkWell(
            onTap: onMarkAllRead,
            borderRadius: BorderRadius.circular(ui(6)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(6)),
              child: Text(
                '批量已读',
                style: TextStyle(
                  color: const Color(0xFF715EFE),
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1.2,
                ),
              ),
            ),
          ),
        SizedBox(width: ui(2)),
        AppPressable(
          semanticLabel: '关闭通知',
          onTap: onClose,
          child: Padding(
            padding: EdgeInsets.all(ui(4)),
            child: Icon(
              Icons.close_rounded,
              size: ui(20),
              color: const Color(0xFF6D6B75),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.item});

  final ShellNoticeItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 1.0 通知接口的 targetType 图标素材尚未补齐（assets/images/shell/msg{1-4}.png
    // 未入库），先隐藏前导图标，仅保留文本 + 时间。素材到位后恢复 _NoticeRow 的
    // leading Image.asset 即可。
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(14),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.45,
            ),
          ),
          SizedBox(height: ui(6)),
          Text(
            item.createTime,
            style: TextStyle(
              color: const Color(0xFFB6B5BB),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeEmpty extends StatelessWidget {
  const _NoticeEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: ui(48),
            color: const Color(0xFFCECED1),
          ),
          SizedBox(height: ui(12)),
          Text(
            '暂无通知',
            style: TextStyle(
              color: const Color(0xFFB6B5BB),
              fontSize: ui(14),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}
