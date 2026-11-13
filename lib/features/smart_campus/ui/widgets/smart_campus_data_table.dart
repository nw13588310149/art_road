import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../shell/ui/shell_layout.dart';

/// 原版数据表白卡：内距 12、圆角 16。
///
/// 对应 R `admin_notification_management_view.dart` 935–988（`_NotificationTable`）。
class SmartCampusDataTableCard extends StatelessWidget {
  const SmartCampusDataTableCard({
    required this.header,
    required this.rows,
    this.emptyLabel = '暂无数据',
    super.key,
  });

  final Widget header;
  final List<Widget> rows;
  final String emptyLabel;

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
          header,
          if (rows.isEmpty)
            Container(
              height: ui(120),
              alignment: Alignment.center,
              child: Text(
                emptyLabel,
                style: TextStyle(
                  fontSize: ui(13),
                  color: const Color(0xFFB6B5BB),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

/// 原版表头行：高 40、底 `#F9FAFB`、圆角 8；列间距用 [SmartCampusTableGap]。
///
/// 对应 R `admin_notification_management_view.dart` 991–1020。
class SmartCampusTableHeader extends StatelessWidget {
  const SmartCampusTableHeader({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(40),
      padding: EdgeInsets.symmetric(horizontal: ui(10)),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(children: children),
    );
  }
}

/// 表头单元格：13 号 `#71717A`。
///
/// 对应 R `admin_notification_management_view.dart` 1023–1044。
class SmartCampusTableHeaderCell extends StatelessWidget {
  const SmartCampusTableHeaderCell({
    required this.text,
    this.width,
    this.onTap,
    super.key,
  });

  final String text;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final child = Text(
      text,
      style: TextStyle(
        fontSize: ui(13),
        color: const Color(0xFF71717A),
        fontFamily: 'PingFang SC',
        fontWeight: AppFont.w400,
        height: 20 / 13,
      ),
    );
    final sized = width == null
        ? child
        : SizedBox(width: ui(width!), child: child);
    if (onTap == null) return sized;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: sized,
    );
  }
}

/// 原版表体行：高 60、底部分隔 `#F3F2F3`、列距 12。
///
/// 对应 R `admin_notification_management_view.dart` 1057–1118。
class SmartCampusTableRow extends StatelessWidget {
  const SmartCampusTableRow({
    required this.children,
    this.onTap,
    super.key,
  });

  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final row = Container(
      height: ui(60),
      padding: EdgeInsets.symmetric(horizontal: ui(10)),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F2F3))),
      ),
      child: Row(children: children),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(8)),
      child: row,
    );
  }
}

/// 表列间距 12。
class SmartCampusTableGap extends StatelessWidget {
  const SmartCampusTableGap({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(width: ui(12));
  }
}
