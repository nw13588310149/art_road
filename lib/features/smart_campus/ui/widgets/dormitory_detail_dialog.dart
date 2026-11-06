import 'package:flutter/material.dart';

import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../data/student_dormitory_data.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kBoardBg = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kPurple = Color(0xFF8741FF);

const _profileHiddenFieldLabels = {'学生姓名', '学生', '姓名', '学生学号', '学号'};

Future<void> showDormitoryDetailDialog(
  BuildContext context, {
  required String title,
  required List<DormitoryDetailField> fields,
  DormitoryDetailStudentProfile? studentProfile,
  List<Widget>? actions,
}) {
  final ui = DashboardScaleScope.of(context).ui;
  final showProfile =
      studentProfile != null && studentProfile.name.trim().isNotEmpty;
  final visibleFields = showProfile
      ? fields
            .where((field) => !_profileHiddenFieldLabels.contains(field.label))
            .toList(growable: false)
      : fields;
  return showScaledDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (ctx) => GradientHeaderDialog(
      title: title,
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProfile) ...[
            _StudentProfileHeader(profile: studentProfile),
            SizedBox(height: ui(12)),
          ],
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui(16)),
            decoration: BoxDecoration(
              color: _kBoardBg,
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < visibleFields.length; i++) ...[
                  if (i > 0) SizedBox(height: ui(6)),
                  _DetailRow(field: visibleFields[i]),
                ],
              ],
            ),
          ),
          if (actions != null && actions.isNotEmpty) ...[
            SizedBox(height: ui(16)),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) SizedBox(width: ui(8)),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
          SizedBox(height: ui(16)),
          SizedBox(
            width: double.infinity,
            height: ui(44),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kBorderSoft),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                '关闭',
                style: TextStyle(
                  fontSize: ui(14),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StudentProfileHeader extends StatelessWidget {
  const _StudentProfileHeader({required this.profile});

  final DormitoryDetailStudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StudentAvatar(name: profile.name, url: profile.avatarUrl),
        SizedBox(width: ui(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.name,
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
              if (profile.subtitle.trim().isNotEmpty) ...[
                SizedBox(height: ui(4)),
                Text(
                  profile.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextSecondary,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({required this.name, required this.url});

  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final size = ui(48);
    final radius = ui(8);
    final initial = name.isEmpty ? '·' : name.characters.first;

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFE7D9FF),
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: ui(18),
            color: _kPurple,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
            height: 1.0,
          ),
        ),
      );
    }

    if (url.trim().isEmpty) return fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.field});

  final DormitoryDetailField field;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: ui(13),
          height: 1.5,
          fontFamily: 'PingFang SC',
        ),
        children: [
          TextSpan(
            text: '${field.label}：',
            style: TextStyle(color: _kTextHint, fontWeight: AppFont.w400),
          ),
          TextSpan(
            text: field.value.isEmpty ? '—' : field.value,
            style: TextStyle(color: _kTextDark, fontWeight: AppFont.w400),
          ),
        ],
      ),
    );
  }
}
