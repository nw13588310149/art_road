import 'package:flutter/material.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../data/course_sign_data.dart';
import '../../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPageBg = Color(0xFFF5F6FA);
const Color _kGreen = Color(0xFF0CAC40);
const Color _kGreenBg = Color(0xFFDFFCF0);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kOrangeBg = Color(0xFFFFF7E6);
const Color _kRed = Color(0xFFFF323C);
const Color _kRedBg = Color(0xFFFFEEEF);
const Color _kGrayBg = Color(0xFFF0F0F0);
const Color _kBorderSoft = Color(0xFFF3F2F3);

/// 管理员 / 任课老师签课：统一「修改签到状态」弹窗（与 [showTextInputDialog] 同款壳）。
Future<CourseSignStatus?> showCourseSignStatusPicker(
  BuildContext context, {
  required String studentName,
  required String studentNo,
  String headUrl = '',
  required CourseSignStatus? current,
}) {
  return showScaledDialog<CourseSignStatus>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      CourseSignStatus? selected = current ?? CourseSignStatus.present;

      return StatefulBuilder(
        builder: (ctx, setLocalState) {
          final ui = DashboardScaleScope.of(ctx).ui;
          final options = CourseSignStatus.selectable;

          return GradientHeaderDialog(
            title: '修改签到状态',
            headerHeight: 169,
            gradientMidStop: 0.35,
            actionBar: AppDialogActionBar(
              confirmLabel: '确认',
              cancelLabel: '取消',
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () {
                if (selected == null) return;
                Navigator.of(dialogContext).pop(selected);
              },
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(ui(14)),
                  decoration: BoxDecoration(
                    color: _kPageBg,
                    borderRadius: BorderRadius.circular(ui(12)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _StudentInfoAvatar(
                        seed: studentName,
                        size: ui(48),
                        imageUrl: headUrl,
                      ),
                      SizedBox(width: ui(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              studentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ui(16),
                                color: _kTextDark,
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w600,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: ui(4)),
                            Text(
                              studentNo.isEmpty || studentNo == '--'
                                  ? '学号 --'
                                  : '学号 $studentNo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ui(12),
                                color: _kTextHint,
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w400,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: ui(8)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '当前状态',
                                  style: TextStyle(
                                    fontSize: ui(12),
                                    color: _kTextHint,
                                    fontFamily: 'PingFang SC',
                                    fontWeight: AppFont.w400,
                                    height: 1,
                                  ),
                                ),
                                SizedBox(width: ui(6)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ui(8),
                                    vertical: ui(3),
                                  ),
                                  decoration: BoxDecoration(
                                    color: courseSignStatusBg(current),
                                    borderRadius: BorderRadius.circular(ui(6)),
                                  ),
                                  child: Text(
                                    courseSignStatusLabel(current),
                                    style: TextStyle(
                                      fontSize: ui(12),
                                      color: courseSignStatusFg(current),
                                      fontFamily: 'PingFang SC',
                                      fontWeight: AppFont.w500,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ui(16)),
                for (var i = 0; i < options.length; i++) ...[
                  _SignStatusListTile(
                    status: options[i],
                    isSelected: selected == options[i],
                    onTap: () => setLocalState(() => selected = options[i]),
                  ),
                  if (i < options.length - 1) SizedBox(height: ui(8)),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

class _SignStatusListTile extends StatelessWidget {
  const _SignStatusListTile({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  final CourseSignStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final (fg, bg) = _statusColors(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: ui(48),
          padding: EdgeInsets.symmetric(horizontal: ui(14)),
          decoration: BoxDecoration(
            color: isSelected ? bg : Colors.white,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(
              color: isSelected ? fg : _kBorderSoft,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: ui(8),
                height: ui(8),
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
              SizedBox(width: ui(10)),
              Expanded(
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: isSelected ? fg : _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: isSelected ? AppFont.w600 : AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: ui(18), color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentInfoAvatar extends StatelessWidget {
  const _StudentInfoAvatar({
    required this.seed,
    required this.size,
    this.imageUrl = '',
  });

  final String seed;
  final double size;
  final String imageUrl;

  Widget _fallback(String initial) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFB98FFF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
          height: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = seed.isEmpty ? '?' : seed.characters.first.toUpperCase();
    final resolved = imageUrl.trim().isEmpty
        ? ''
        : MediaUrl.resolve(imageUrl.trim());
    if (resolved.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          resolved,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(initial),
        ),
      );
    }
    return _fallback(initial);
  }
}

(Color fg, Color bg) _statusColors(CourseSignStatus status) {
  switch (status) {
    case CourseSignStatus.present:
      return (_kGreen, _kGreenBg);
    case CourseSignStatus.absent:
      return (_kRed, _kRedBg);
    case CourseSignStatus.late:
      return (_kOrange, _kOrangeBg);
    case CourseSignStatus.leave:
      return (const Color(0xFF6D6B75), _kGrayBg);
  }
}

Color courseSignStatusFg(CourseSignStatus? status) {
  if (status == null) return _kTextHint;
  return _statusColors(status).$1;
}

Color courseSignStatusBg(CourseSignStatus? status) {
  if (status == null) return const Color(0xFFF5F6FA);
  return _statusColors(status).$2;
}

String courseSignStatusLabel(CourseSignStatus? status) {
  return status?.label ?? '未签到';
}
