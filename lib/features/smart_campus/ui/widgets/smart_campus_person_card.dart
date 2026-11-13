import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../shell/ui/shell_layout.dart';
import 'smart_campus_square_avatar.dart';

/// 原版人员卡右上角状态角标：高 22、贴右上、对角圆角 12。
///
/// 对应 R `admin_teacher_management_view.dart` 1101–1140、
/// `admin_student_management_view.dart` 1286–1310。
class SmartCampusPersonStatusBadge extends StatelessWidget {
  const SmartCampusPersonStatusBadge({
    required this.label,
    required this.background,
    required this.foreground,
    this.showDot = false,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;

  /// 教师卡在岗等状态带 6px 圆点；学生卡纯文字。
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        height: ui(22),
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(ui(12)),
            bottomLeft: Radius.circular(ui(12)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(
                width: ui(6),
                height: ui(6),
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: ui(4)),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                height: 1.0,
                color: foreground,
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 原版人员卡：白底圆角 12；教师高 98、学生高 88；左方头像 + 姓名行 + 摘要。
///
/// 对应 R `admin_teacher_management_view.dart` 984–1146（`_TeacherCard`）、
/// `admin_student_management_view.dart` 1187–1316（`_StudentCard`）。
/// 网格列数由调用方 [LayoutBuilder] 决定（≥900 三列、≥600 两列、间距 12）。
class SmartCampusPersonCard extends StatelessWidget {
  const SmartCampusPersonCard({
    required this.name,
    required this.onTap,
    this.avatarUrl = '',
    this.idLabel = '',
    this.lines = const [],
    this.tags = const [],
    this.statusBadge,
    this.height = 98,
    this.contentRightPadding,
    super.key,
  });

  final String name;
  final VoidCallback onTap;
  final String avatarUrl;

  /// 姓名旁次要编号（工号 / 学号）。
  final String idLabel;

  /// 姓名下方摘要行（12 号）。
  final List<SmartCampusPersonCardLine> lines;

  /// 底部横向滚动标签区。
  final List<Widget> tags;

  final Widget? statusBadge;
  final double height;

  /// 内容右内边距；有角标时教师卡用 12+姓名区 42，学生卡整体 46。
  final double? contentRightPadding;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final rightPad = contentRightPadding ?? 12;
    // 教师卡内容右距 12、姓名区再留 42 避开角标；学生卡整列右距 46，不再叠 42。
    final nameRightInset =
        statusBadge != null && rightPad <= 12 ? ui(42) : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(height),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(ui(12), ui(8), ui(rightPad), ui(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartCampusSquareAvatar(name: name, url: avatarUrl),
                  SizedBox(width: ui(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: nameRightInset),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textHeightBehavior:
                                          const TextHeightBehavior(
                                        applyHeightToFirstAscent: false,
                                        applyHeightToLastDescent: false,
                                      ),
                                      style: TextStyle(
                                        fontSize: ui(14),
                                        height: 1.0,
                                        fontWeight: AppFont.w500,
                                        color: const Color(0xFF0B081A),
                                        fontFamily: 'PingFang SC',
                                      ),
                                    ),
                                  ),
                                  if (idLabel.isNotEmpty) ...[
                                    SizedBox(width: ui(8)),
                                    Text(
                                      idLabel,
                                      style: TextStyle(
                                        fontSize: ui(12),
                                        height: 1.2,
                                        color: const Color(0xFFB6B5BB),
                                        fontFamily: 'PingFang SC',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              for (final line in lines) ...[
                                SizedBox(height: ui(6)),
                                Text(
                                  line.text,
                                  maxLines: line.maxLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: ui(12),
                                    height: 1.2,
                                    color: line.color,
                                    fontFamily: 'PingFang SC',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (tags.isNotEmpty) ...[
                          SizedBox(height: ui(10)),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                for (var i = 0; i < tags.length; i++) ...[
                                  if (i > 0) SizedBox(width: ui(4)),
                                  tags[i],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ?statusBadge,
          ],
        ),
      ),
    );
  }
}

class SmartCampusPersonCardLine {
  const SmartCampusPersonCardLine(
    this.text, {
    this.color = const Color(0xFF0B081A),
    this.maxLines = 1,
  });

  final String text;
  final Color color;
  final int maxLines;
}
